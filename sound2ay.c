#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define POPULATION_SIZE   32        
#define GENOME_SIZE       14
#define GENERATIONS       15        
#define TICK_RATE         50        
#define EVAL_WINDOW_MS    50        
#define AY_CLOCK          1789772   
#define CACHE_SIZE        64        

int sample_rate = 44100;
int window_size = 0;              
int total_wav_samples = 0;
float* full_target_waveform = NULL;

uint8_t winner_cache[CACHE_SIZE][GENOME_SIZE];
int cache_count = 0;

// FIXED: Converted to arrays to handle independent 3-channel architecture parameters
typedef struct {
    uint16_t tone_period[3];      
    uint8_t  noise_period;
    uint8_t  mixer;
    uint8_t  amplitude[3];        
    uint16_t env_period;
    uint8_t  env_shape;
    uint32_t tone_counter[3];
    int8_t   tone_state[3];
} AY_Chip;

uint32_t xorshift32() {
    static uint32_t x = 2463534242U;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    return x;
}

int load_full_wav(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "[!] Could not open input file: %s\n", filename);
        return 0;
    }
    uint8_t header[44];
    if (fread(header, 1, 44, f) != 44) { 
        fclose(f); return 0; 
    }
    
    memcpy(&sample_rate, &header[24], 4);
    if (sample_rate <= 0) sample_rate = 44100;

    fseek(f, 12, SEEK_SET); 
    uint32_t chunk_id = 0, data_size = 0;

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
        fprintf(stderr, "[!] Failed to locate a valid 'data' block.\n");
        fclose(f); return 0;
    }

    total_wav_samples = data_size / sizeof(int16_t);
    window_size = (sample_rate * EVAL_WINDOW_MS) / 1000; 

    full_target_waveform = (float*)calloc(total_wav_samples, sizeof(float));
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
    
    // FIXED: Formatted register offsets to map uniquely onto 3 channels arrays cleanly
    chip.tone_period[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    chip.tone_period[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    chip.tone_period[2] = regs[4] | ((regs[5] & 0x0F) << 8);
    chip.noise_period   = regs[6] & 0x1F;
    chip.mixer          = regs[7];
    chip.amplitude[0]   = regs[8] & 0x1F; 
    chip.amplitude[1]   = regs[9] & 0x1F; 
    chip.amplitude[2]   = regs[10] & 0x1F; 
    
    for (int c = 0; c < 3; c++) chip.tone_state[c] = 1;
    double ticks_per_sample = (double)AY_CLOCK / (16.0 * sample_rate);

    for (int s = 0; s < num_samples; s++) {
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
                mix += ((float)chip.tone_state[c] * ((float)(chip.amplitude[c] & 0x0F) / 15.0f));
            }
        }
        out_buffer[s] = (active_channels > 0) ? (mix / (float)active_channels) : 0.0f;
    }
}

float evaluate_fitness_fast(uint8_t* genome, float* target_segment) {
    float* candidate = (float*)malloc(window_size * sizeof(float));
    run_ay_emulator_flexible(genome, candidate, window_size);
    
    float error = 0.0f;
    for (int i = 0; i < window_size; i += 4) {
        float diff = target_segment[i] - candidate[i];
        error += diff * diff;
    }
    
    free(candidate);
    return 1000.0f / (error + 1.0f);
}

int main(int argc, char** argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    
    int pipe_audio = 0;
    int skip_ms = 0; 
    char* wav_filename = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-pipe") == 0) pipe_audio = 1;
        else if (strcmp(argv[i], "-skip_ms") == 0 && (i + 1 < argc)) skip_ms = atoi(argv[++i]);
        else wav_filename = argv[i];
    }

    if (!wav_filename || !load_full_wav(wav_filename)) {
        fprintf(stderr, "Usage: %s <target.wav> [-pipe] [-skip_ms <ms>]\n", argv[0]); 
        return 1;
    }

    fprintf(stderr, "[*] Processing: Rate=%dHz, Samples=%d\n", sample_rate, total_wav_samples);

    int sample_stride = (skip_ms > 0) ? (sample_rate * skip_ms / 1000) : ((sample_rate * 20) / 1000); 
    
    float* complete_assembled_preview = (float*)calloc(total_wav_samples, sizeof(float));
    float* play_buffer = (float*)malloc(sample_stride * sizeof(float));
    float* norm_window = (float*)malloc(window_size * sizeof(float));

    int frame_index = 0;

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        fprintf(stderr, "\nFrame #%04d (Time Offset: %06.2fs)\n", frame_index, (float)offset / sample_rate);
        
        float peak_amp = 0.0001f;
        for (int i = 0; i < window_size; i++) {
            float abs_val = fabsf(full_target_waveform[offset + i]);
            if (abs_val > peak_amp) peak_amp = abs_val;
        }
        for (int i = 0; i < window_size; i++) norm_window[i] = full_target_waveform[offset + i] / peak_amp;

        int max_tau = window_size / 2;
        int best_tau = 0;
        float min_amdf = 1e10f;

        for (int tau = 4; tau < max_tau; tau += 2) {
            float amdf = 0.0f;
            for (int t = 0; t < max_tau; t += 4) {
                amdf += fabsf(norm_window[t] - norm_window[t + tau]);
            }
            if (amdf < min_amdf) {
                min_amdf = amdf;
                best_tau = tau;
            }
        }

        float target_frequency = (best_tau > 0) ? ((float)sample_rate / (float)best_tau) : 440.0f;
        uint16_t period = (uint16_t)((double)AY_CLOCK / (32.0 * target_frequency));
        if (period > 4095) period = 4095;
        if (period < 2) period = 2; 

        uint8_t population[POPULATION_SIZE][GENOME_SIZE];
        float fitness[POPULATION_SIZE];

        int idx = 0;
        uint8_t sweep_tracking_seed[GENOME_SIZE] = {
            period & 0xFF, (period >> 8) & 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3E, 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00
        };
        memcpy(population[idx++], sweep_tracking_seed, GENOME_SIZE);

        int available_seeds = (cache_count < CACHE_SIZE) ? cache_count : CACHE_SIZE;
        for (int i = 0; i < available_seeds && idx < POPULATION_SIZE; i++) {
            memcpy(population[idx++], winner_cache[i], GENOME_SIZE);
        }

        while (idx < POPULATION_SIZE) {
            for (int j = 0; j < GENOME_SIZE; j++) population[idx][j] = sweep_tracking_seed[j];
            population[idx][0] = (period + (xorshift32() % 8) - 4) & 0xFF;
            population[idx][1] = ((period >> 8) + (xorshift32() % 2) - 1) & 0x0F;
            idx++;
        }

        for (int g = 0; g < GENERATIONS; g++) {
            float max_fit = -1.0f; int best_idx = 0;
            for (int i = 0; i < POPULATION_SIZE; i++) {
                fitness[i] = evaluate_fitness_fast(population[i], norm_window);
                if (fitness[i] > max_fit) { max_fit = fitness[i]; best_idx = i; }
            }

            if (g % 5 == 0) {
                fprintf(stderr, "  Gen [%02d/%02d] -> Top Fitness Match: %8.2f\n", g, GENERATIONS, max_fit);
            }

            uint8_t next_gen[POPULATION_SIZE][GENOME_SIZE];
            memcpy(next_gen, population[best_idx], GENOME_SIZE); 

            for (int i = 1; i < POPULATION_SIZE; i++) {
                int p1 = xorshift32() % POPULATION_SIZE, p2 = xorshift32() % POPULATION_SIZE;
                int parent = (fitness[p1] > fitness[p2]) ? p1 : p2;
                memcpy(next_gen[i], population[parent], GENOME_SIZE);

                if ((xorshift32() % 100) < 30) {
                    next_gen[i][0] = (next_gen[i][0] + (xorshift32() % 4) - 2) & 0xFF;
                    next_gen[i][1] = (next_gen[i][1] + (xorshift32() % 2) - 1) & 0x0F;
                }
            }
            memcpy(population, next_gen, sizeof(population));
        }

        float final_fit = -1.0f; int winner = 0;
        for (int i = 0; i < POPULATION_SIZE; i++) {
            float f = evaluate_fitness_fast(population[i], norm_window);
            if (f > final_fit) { final_fit = f; winner = i; }
        }

        uint8_t final_ay[GENOME_SIZE];
        memcpy(final_ay, population[winner], GENOME_SIZE);

        // STREAMS REDIRECTION FIX: Log status checks to stderr, print tracker string exclusively to stdout 
        fprintf(stdout, "\t\tAY:");
        fprintf(stderr, "\t\tAY:");
        for (int j = 0; j < GENOME_SIZE; j++) {
            fprintf(stdout, " %02x", final_ay[j]);
            fprintf(stderr, " %02x", final_ay[j]);
        }
        fprintf(stdout, "\n");
        fprintf(stderr, "\n");

        memcpy(winner_cache[cache_count % CACHE_SIZE], final_ay, GENOME_SIZE);
        cache_count++;

        run_ay_emulator_flexible(final_ay, play_buffer, sample_stride);
        
        // Save the sustained audio block segment cleanly to render memory
        if (offset + sample_stride <= total_wav_samples) {
            memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
        }

        // Handle raw pipe parameters if the -pipe flag is given
        if (pipe_audio) {
            for (int k = 0; k < sample_stride; k++) {
                int16_t pcm_sample = (int16_t)(play_buffer[k] * 0.15f * 32767.0f);
                fwrite(&pcm_sample, sizeof(int16_t), 1, stdout);
            }
        }
        frame_index++;
    }

    fprintf(stderr, "[*] Saving complete audio timeline track directly out to preview asset file...\n");
    write_output_wav("match_preview.wav", complete_assembled_preview, total_wav_samples);

    fprintf(stderr, "[*] Processing Complete!\n");
    free(play_buffer); free(norm_window); free(complete_assembled_preview); free(full_target_waveform);
    return 0;
}
