#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define POPULATION_SIZE   64
#define GENOME_SIZE       14
#define GENERATIONS       30        
#define TICK_RATE         50        
#define AY_CLOCK          1789772   
#define CACHE_SIZE        64        

int sample_rate = 44100;
int window_size = 0;              
int total_wav_samples = 0;

float* full_target_waveform = NULL;
float* current_window_spectrum = NULL;

uint8_t winner_cache[CACHE_SIZE][GENOME_SIZE];
int cache_count = 0;

typedef struct {
    uint16_t tone_period[3];      
    uint8_t  noise_period;
    uint8_t  mixer;
    uint8_t  amplitude[3];        
    uint16_t env_period;
    uint8_t  env_shape;
    
    uint32_t tone_counter[3];
    int8_t   tone_state[3];
    uint32_t env_counter;
    int32_t  env_step;
    uint8_t  env_holding;
    uint8_t  env_direction;
} AY_Chip;

uint32_t xorshift32() {
    static uint32_t x = 2463534242U;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    return x;
}

int load_full_wav(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) {
        printf("[!] Could not open input file: %s\n", filename);
        return 0;
    }
    uint8_t header[44];
    if (fread(header, 1, 44, f) != 44) { 
        fclose(f); return 0; 
    }
    
    memcpy(&sample_rate, &header[24], 4);
    if (sample_rate <= 0) sample_rate = 44100;

    fseek(f, 12, SEEK_SET); 
    uint32_t chunk_id = 0;
    uint32_t data_size = 0;

    while (fread(&chunk_id, 4, 1, f) == 1) {
        uint32_t chunk_size = 0;
        if (fread(&chunk_size, 4, 1, f) != 1) break;
        if (memcmp(&chunk_id, "data", 4) == 0) {
            data_size = chunk_size;
            break;
        }
        fseek(f, chunk_size, SEEK_CUR);
    }

    if (data_size <= 0) {
        printf("[!] Failed to locate a valid 'data' subchunk header inside file.\n");
        fclose(f); return 0;
    }

    total_wav_samples = data_size / sizeof(int16_t);
    window_size = sample_rate / TICK_RATE; 

    full_target_waveform = (float*)calloc(total_wav_samples, sizeof(float));
    current_window_spectrum = (float*)calloc(window_size / 2, sizeof(float));

    int16_t sample;
    for (int i = 0; i < total_wav_samples; i++) {
        if (fread(&sample, sizeof(int16_t), 1, f) == 1) {
            full_target_waveform[i] = (float)sample / 32768.0f;
        } else {
            total_wav_samples = i; 
            break;
        }
    }
    fclose(f);
    return 1;
}

void write_output_wav(const char* filename, float* buffer, int num_samples) {
    FILE* f = fopen(filename, "wb");
    if (!f) return;
    int32_t sub_chunk2_size = num_samples * sizeof(int16_t);
    int32_t chunk_size = 36 + sub_chunk2_size;
    int32_t byte_rate = sample_rate * sizeof(int16_t);
    int16_t format = 1, channels = 1, bits = 16;
    int16_t align = channels * (bits / 8);
    
    fwrite("RIFF", 1, 4, f); fwrite(&chunk_size, 4, 1, f);
    fwrite("WAVEfmt ", 1, 8, f);
    int32_t chunk1_size = 16;
    fwrite(&chunk1_size, 4, 1, f); fwrite(&format, 2, 1, f);
    fwrite(&channels, 2, 1, f); fwrite(&sample_rate, 4, 1, f);
    fwrite(&byte_rate, 4, 1, f); fwrite(&align, 2, 1, f);
    fwrite(&bits, 2, 1, f); fwrite("data", 1, 4, f);
    fwrite(&sub_chunk2_size, 4, 1, f);
    
    for (int i = 0; i < num_samples; i++) {
        float val = buffer[i];
        if (val > 1.0f) val = 1.0f; if (val < -1.0f) val = -1.0f;
        int16_t pcm = (int16_t)(val * 32767.0f);
        fwrite(&pcm, sizeof(int16_t), 1, f);
    }
    fclose(f);
}

void run_ay_emulator_flexible(uint8_t* regs, float* out_buffer, int num_samples) {
    AY_Chip chip;
    memset(&chip, 0, sizeof(AY_Chip));
    
    chip.tone_period[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    chip.tone_period[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    chip.tone_period[2] = regs[4] | ((regs[5] & 0x0F) << 8);
    chip.noise_period   = regs[6] & 0x1F;
    chip.mixer          = regs[7];
    chip.amplitude[0]   = regs[8] & 0x1F; 
    chip.amplitude[1]   = regs[9] & 0x1F;
    chip.amplitude[2]   = regs[10] & 0x1F;
    chip.env_period     = regs[11] | (regs[12] << 8);
    chip.env_shape      = regs[13] & 0x0F;

    chip.env_direction = (chip.env_shape & 0x04) ? 1 : 0;
    chip.env_step      = (chip.env_direction) ? 0 : 15;
    
    for (int c = 0; c < 3; c++) chip.tone_state[c] = 1;

    double ticks_per_sample = (double)AY_CLOCK / (16.0 * sample_rate);
    double env_ticks_per_sample = (double)AY_CLOCK / (256.0 * sample_rate);

    for (int s = 0; s < num_samples; s++) {
        if (!chip.env_holding && chip.env_period > 0) {
            chip.env_counter++;
            if (chip.env_counter >= chip.env_period * env_ticks_per_sample) {
                chip.env_counter = 0;
                if (chip.env_direction) {
                    chip.env_step++;
                    if (chip.env_step > 15) {
                        if (chip.env_shape & 0x08) {
                            if (chip.env_shape & 0x02) { chip.env_direction = 0; chip.env_step = 15; }
                            else { chip.env_step = 0; }
                        } else { chip.env_holding = 1; chip.env_step = 0; }
                    }
                } else {
                    chip.env_step--;
                    if (chip.env_step < 0) {
                        if (chip.env_shape & 0x08) {
                            if (chip.env_shape & 0x02) { chip.env_direction = 1; chip.env_step = 0; }
                            else { chip.env_step = 15; }
                        } else { chip.env_holding = 1; chip.env_step = 0; }
                    }
                }
            }
        }

        float mix = 0.0f;
        int active_channels = 0;

        for (int c = 0; c < 3; c++) {
            if (chip.tone_period[c] > 0) {
                chip.tone_counter[c]++;
                if (chip.tone_counter[c] >= chip.tone_period[c] * ticks_per_sample) {
                    chip.tone_counter[c] = 0;
                    chip.tone_state[c] = -chip.tone_state[c];
                }
            }
            
            int tone_enabled = !((chip.mixer >> c) & 1);
            if (tone_enabled && chip.tone_period[c] > 0) {
                active_channels++;
                float current_vol = (chip.amplitude[c] & 0x10) ? (float)chip.env_step : (float)(chip.amplitude[c] & 0x0F);
                mix += ((float)chip.tone_state[c] * (current_vol / 15.0f));
            }
        }
        
        if (active_channels > 0) {
            out_buffer[s] = mix / (float)active_channels;
        } else {
            out_buffer[s] = 0.0f; 
        }
    }
}

void compute_simplified_spectrum(float* signal, float* spectrum) {
    int limit = window_size / 2;
    for (int k = 0; k < limit; k += 4) { 
        float real = 0.0f, imag = 0.0f;
        for (int n = 0; n < window_size; n += 2) {
            float angle = (2.0f * M_PI * k * n) / window_size;
            real += signal[n] * cosf(angle);
            imag += signal[n] * sinf(angle);
        }
        spectrum[k] = sqrtf(real * real + imag * imag);
        for(int m=1; m<4; m++) if(k+m < limit) spectrum[k+m] = spectrum[k];
    }
}

float evaluate_fitness(uint8_t* genome) {
    float* candidate_waveform = (float*)malloc(window_size * sizeof(float));
    float* candidate_spectrum = (float*)malloc((window_size / 2) * sizeof(float));
    
    run_ay_emulator_flexible(genome, candidate_waveform, window_size);
    compute_simplified_spectrum(candidate_waveform, candidate_spectrum);
    
    float error = 0.0f;
    for (int i = 0; i < window_size / 2; i += 4) {
        float diff = current_window_spectrum[i] - candidate_spectrum[i];
        error += diff * diff;
    }
    
    free(candidate_waveform); free(candidate_spectrum);
    return 100000.0f / (error + 1.0f);
}

int main(int argc, char** argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    
    int is_silent = 0;
    int skip_ms = 0; 
    char* wav_filename = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-silent") == 0) {
            is_silent = 1;
        } else if (strcmp(argv[i], "-skip_ms") == 0 && (i + 1 < argc)) {
            skip_ms = atoi(argv[++i]);
        } else {
            wav_filename = argv[i];
        }
    }

    if (!wav_filename) {
        printf("Usage: %s <target.wav> [-silent] [-skip_ms <ms>]\n", argv[0]); 
        return 1;
    }
    
    if (!load_full_wav(wav_filename)) {
        printf("[!] Failed to parse WAV metadata structure.\n"); 
        return 1;
    }

    printf("[*] Configuration: Rate=%dHz, Samples=%d, Window Size=%d samples\n", 
           sample_rate, total_wav_samples, window_size);

    float* complete_assembled_preview = (float*)calloc(total_wav_samples, sizeof(float));
    float* frame_waveform = (float*)malloc(window_size * sizeof(float));
    
    int play_buffer_samples = sample_rate * 0.5;
    float* play_buffer = (float*)malloc(play_buffer_samples * sizeof(float));

    int frame_index = 0;
    int sample_stride = (skip_ms > 0) ? (sample_rate * skip_ms / 1000) : window_size;

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        printf("\n============================================================\n");
        printf("Frame #%04d (Time Offset: %06.2fs)\n", frame_index, (float)offset / sample_rate);
        printf("============================================================\n");
        
        compute_simplified_spectrum(&full_target_waveform[offset], current_window_spectrum);

        // --- FIXED: ALIAS-PROOF ZERO CROSSING ALGORITHM ---
        int zero_crossings = 0;
        for (int i = 1; i < window_size; i++) {
            if ((full_target_waveform[offset + i - 1] >= 0 && full_target_waveform[offset + i] < 0) ||
                (full_target_waveform[offset + i - 1] < 0 && full_target_waveform[offset + i] >= 0)) {
                zero_crossings++;
            }
        }
        
        float duration = (float)window_size / (float)sample_rate;
        float target_frequency = ((float)zero_crossings / 2.0f) / duration;
        if (target_frequency < 40.0f) target_frequency = 440.0f; 
        
        uint16_t calculated_ay_period = (uint16_t)((double)AY_CLOCK / (32.0 * target_frequency));
        if (calculated_ay_period > 4095) calculated_ay_period = 4095;
        if (calculated_ay_period < 2) calculated_ay_period = 2;

        uint8_t population[POPULATION_SIZE][GENOME_SIZE];
        float fitness[POPULATION_SIZE];

        int idx = 0;
        uint8_t sweep_tracking_seed[GENOME_SIZE] = {
            calculated_ay_period & 0xFF, (calculated_ay_period >> 8) & 0x0F, 
            0x00, 0x00, 0x00, 0x00,                                         
            0x00,                                                           
            0x3E,                                                           
            0x0F, 0x00, 0x00,                                               
            0x00, 0x00, 0x00                                                
        };
        
        memcpy(population[idx++], sweep_tracking_seed, GENOME_SIZE);

        int available_seeds = (cache_count < CACHE_SIZE) ? cache_count : CACHE_SIZE;
        for (int i = 0; i < available_seeds && idx < POPULATION_SIZE; i++) {
            memcpy(population[idx++], winner_cache[i], GENOME_SIZE);
        }

        while (idx < POPULATION_SIZE) {
            for (int j = 0; j < GENOME_SIZE; j++) {
                population[idx][j] = sweep_tracking_seed[j];
            }
            // FIXED: Apply minor tone period mutations without overwriting the parent array types
            population[idx][0] = (calculated_ay_period + (xorshift32() % 16) - 8) & 0xFF;
            population[idx][1] = ((calculated_ay_period >> 8) + (xorshift32() % 4) - 2) & 0x0F;
            idx++;
        }

        for (int g = 0; g < GENERATIONS; g++) {
            float max_fit = -1.0f; int best_idx = 0;
            for (int i = 0; i < POPULATION_SIZE; i++) {
                fitness[i] = evaluate_fitness(population[i]);
                if (fitness[i] > max_fit) { max_fit = fitness[i]; best_idx = i; }
            }

            if (g % 6 == 0) {
                printf("  Gen [%02d/%02d] -> Current Best Fitness Factor: %12.4f\n", g, GENERATIONS, max_fit);
            }

            uint8_t next_gen[POPULATION_SIZE][GENOME_SIZE];
            memcpy(next_gen, population[best_idx], GENOME_SIZE); 

            for (int i = 1; i < POPULATION_SIZE; i++) {
                int p1 = xorshift32() % POPULATION_SIZE;
                int p2 = xorshift32() % POPULATION_SIZE;
                int parent = (fitness[p1] > fitness[p2]) ? p1 : p2;
                memcpy(next_gen[i], population[parent], GENOME_SIZE);

                // FIXED: Explicit structural array mapping prevents compiler memory smashing
                if ((xorshift32() % 100) < 35) {
                    int mutate_coarse = xorshift32() % 2;
                    if (mutate_coarse == 0) {
                        next_gen[i][0] = (next_gen[i][0] + (xorshift32() % 6) - 3) & 0xFF;
                    } else {
                        next_gen[i][1] = (next_gen[i][1] + (xorshift32() % 2) - 1) & 0x0F;
                    }
                }
            }
            memcpy(population, next_gen, sizeof(population));
        }

        float final_fit = -1.0f; int winner = 0;
        for (int i = 0; i < POPULATION_SIZE; i++) {
            float f = evaluate_fitness(population[i]);
            if (f > final_fit) { final_fit = f; winner = i; }
        }

        uint8_t final_ay[GENOME_SIZE];
        memcpy(final_ay, population[winner], GENOME_SIZE);

        printf("\t\tAY:");
        for (int j = 0; j < GENOME_SIZE; j++) {
            printf(" %02x", final_ay[j]);
        }
        printf("\n");

        memcpy(winner_cache[cache_count % CACHE_SIZE], final_ay, GENOME_SIZE);
        cache_count++;

        run_ay_emulator_flexible(final_ay, frame_waveform, window_size);
        if (offset + window_size <= total_wav_samples) {
            memcpy(&complete_assembled_preview[offset], frame_waveform, window_size * sizeof(float));
        }

        if (!is_silent) {
            run_ay_emulator_flexible(final_ay, play_buffer, play_buffer_samples);
            write_output_wav(".tick_preview.wav", play_buffer, play_buffer_samples);
            
            char sys_cmd[256];
            snprintf(sys_cmd, sizeof(sys_cmd), "aplay -q .tick_preview.wav > /dev/null 2>&1 & pid=$!; sleep 0.5; kill $pid >/dev/null 2>&1");
            int ret = system(sys_cmd);
            (void)ret;
        }

        frame_index++;
    }

    printf("\n[*] Done! Output match generated: match_preview.wav\n");
    write_output_wav("match_preview.wav", complete_assembled_preview, total_wav_samples);

    free(frame_waveform); free(play_buffer); free(complete_assembled_preview);
    free(full_target_waveform); free(current_window_spectrum);
    unlink(".tick_preview.wav");
    return 0;
}
