#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define POPULATION_SIZE   48        
#define GENOME_SIZE       14
#define GENERATIONS       20        
#define TICK_RATE         50        
#define EVAL_WINDOW_MS    20        
#define AY_CLOCK          1000000   // 1 MHz Target Hardware
#define CACHE_SIZE        64        

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

int sample_rate = 44100;
int window_size = 0;              
int total_wav_samples = 0;
float* full_target_waveform = NULL;

uint8_t winner_cache[CACHE_SIZE][GENOME_SIZE];
int cache_count = 0;

const float ay_vol_table[] = {
    0.0000f, 0.0137f, 0.0205f, 0.0291f, 
    0.0423f, 0.0618f, 0.0847f, 0.1269f,
    0.1716f, 0.2442f, 0.3445f, 0.4672f, 
    0.6190f, 0.7745f, 0.9161f, 1.0000f
};

typedef struct {
    uint16_t tone_period[3];      
    uint8_t  noise_period;
    uint8_t  mixer;
    uint8_t  amplitude[3];        
    double   tone_counter[3];     
    int8_t   tone_state[3];
} AY_Chip;

AY_Chip global_tracking_state;

uint32_t xorshift32() {
    static uint32_t x = 2463534242U;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    return x;
}

void apply_bandpass(float* input, float* output, int len, float low_cut, float high_cut) {
    float norm_low = low_cut / (sample_rate / 2.0f);
    float norm_high = high_cut / (sample_rate / 2.0f);
    float center = sqrtf(norm_low * norm_high);
    float bw = norm_high - norm_low;
    
    float r = 1.0f - 3.0f * bw;
    float k = (1.0f - 2.0f * r * cosf(2.0f * (float)M_PI * center) + r * r) / (2.0f - 2.0f * cosf(2.0f * (float)M_PI * center));
    float b0 = 1.0f - k, b1 = 2.0f * (k - r) * cosf(2.0f * (float)M_PI * center), b2 = r * r - k;
    float a1 = 2.0f * r * cosf(2.0f * (float)M_PI * center), a2 = -r * r;

    float x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (int i = 0; i < len; i++) {
        float out = b0 * input[i] + b1 * x1 + b2 * x2 + a1 * y1 + a2 * y2;
        x2 = x1; x1 = input[i];
        y2 = y1; y1 = out;
        output[i] = out;
    }
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

void run_ay_emulator_flexible(uint8_t* regs, float* out_buffer, int num_samples, AY_Chip* state_ptr) {
    AY_Chip chip = *state_ptr;
    
    chip.tone_period[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    chip.tone_period[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    chip.tone_period[2] = regs[4] | ((regs[5] & 0x0F) << 8);
    chip.mixer          = regs[7];
    chip.amplitude[0]   = regs[8] & 0x0F; 
    chip.amplitude[1]   = regs[9] & 0x0F; 
    chip.amplitude[2]   = regs[10] & 0x0F; 
    
    double ay_ticks_per_sample = (double)AY_CLOCK / sample_rate;

    for (int s = 0; s < num_samples; s++) {
        float mix = 0.0f;
        int active_channels = 0;

        for (int c = 0; c < 3; c++) {
            if (chip.tone_period[c] > 0) {
                chip.tone_counter[c] += ay_ticks_per_sample;
                uint32_t step_threshold = 16 * chip.tone_period[c]; 
                while (chip.tone_counter[c] >= step_threshold) {
                    chip.tone_counter[c] -= step_threshold;
                    chip.tone_state[c] = -chip.tone_state[c];
                }
            }
            int tone_enabled = !((chip.mixer >> c) & 1);
            if (tone_enabled && chip.tone_period[c] > 0 && chip.amplitude[c] > 0) {
                active_channels++;
                mix += ((float)chip.tone_state[c] * ay_vol_table[chip.amplitude[c]]);
            }
        }
        out_buffer[s] = (active_channels > 0) ? (mix / 3.0f) : 0.0f; 
    }
    *state_ptr = chip;
}

// NEW: Fractional Sub-Sample Interpolator targets phase crossings to decimals
float calculate_fractional_crossings(float* signal, int length) {
    float crossings = 0.0f;
    for (int i = 0; i < length - 1; i++) {
        if ((signal[i] >= 0.0f && signal[i+1] < 0.0f) || (signal[i] < 0.0f && signal[i+1] >= 0.0f)) {
            float denominator = fabsf(signal[i]) + fabsf(signal[i+1]);
            float fraction = (denominator > 0.0001f) ? (fabsf(signal[i]) / denominator) : 0.5f;
            crossings += 1.0f + (fraction * 0.01f); // Phase weight fraction factor adjustment
        }
    }
    return crossings;
}

// CHANGED: Fitness evaluation compares exact fractional metrics to cure the pitch wandering drift
float evaluate_fitness_fast(uint8_t* genome, float* target_segment, float* scratchpad, uint16_t* prev_periods, float target_crossings) {
    AY_Chip temp_state = global_tracking_state; 
    run_ay_emulator_flexible(genome, scratchpad, window_size, &temp_state);
    
    float candidate_crossings = calculate_fractional_crossings(scratchpad, window_size);
    float crossing_error = fabsf(target_crossings - candidate_crossings);
    
    float structural_penalties = 0.0f;
    for (int c = 0; c < 3; c++) {
        uint16_t current_p = genome[c*2] | ((genome[c*2+1] & 0x0F) << 8);
        if (prev_periods[c] > 0 && current_p > 0 && genome[8+c] > 0) {
            float log_ratio = fabsf(log2f((float)current_p / (float)prev_periods[c]));
            structural_penalties += log_ratio * 1.2f; 
        }
    }
    
    return 1000.0f / (crossing_error + structural_penalties + 0.0001f);
}

float calculate_zcd_frequency(float* signal, int length, int s_rate) {
    int crossings = 0;
    int first_crossing = -1;
    int last_crossing = -1;

    for (int i = 0; i < length - 1; i++) {
        if ((signal[i] >= 0.0f && signal[i+1] < 0.0f) || (signal[i] < 0.0f && signal[i+1] >= 0.0f)) {
            crossings++;
            if (first_crossing == -1) first_crossing = i;
            last_crossing = i;
        }
    }
    if (crossings < 2 || first_crossing == last_crossing) return 440.0f; 
    float total_samples = (float)(last_crossing - first_crossing);
    float num_cycles = (float)(crossings - 1) / 2.0f;
    return (num_cycles * (float)s_rate) / total_samples;
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
        fprintf(stderr, "Usage: %s <target.wav> [-pipe] [-skip_ms <ms>]\n", (argc > 0) ? argv[0] : "ay_optimizer"); 
        return 1;
    }

    fprintf(stderr, "[*] Target Polyphonic Wave Loaded: Rate=%dHz, Samples=%d\n", sample_rate, total_wav_samples);

    int sample_stride = (sample_rate * 20) / 1000; 
    
    float* complete_assembled_preview = (float*)calloc(total_wav_samples, sizeof(float));
    float* play_buffer = (float*)malloc(sample_stride * sizeof(float));
    float* fitness_scratchpad = (float*)malloc(window_size * sizeof(float)); 
    
    float* filtered_ch[3];
    for (int i = 0; i < 3; i++) filtered_ch[i] = (float*)malloc(window_size * sizeof(float));

    int frame_index = 0;
    uint8_t last_valid_ay[GENOME_SIZE] = {0};

    memset(&global_tracking_state, 0, sizeof(AY_Chip));
    for(int c=0; c<3; c++) global_tracking_state.tone_state[c] = 1;
    uint16_t last_winning_periods[3] = {0, 0, 0};

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        fprintf(stderr, "\n============================================================\n");
        fprintf(stderr, "Interpolated Frame #%04d (Time Offset: %06.2fs)\n", frame_index, (float)offset / sample_rate);
        fprintf(stderr, "============================================================\n");
        
        float total_frame_energy = 0.0f;
        for (int i = 0; i < window_size; i++) {
            total_frame_energy += fabsf(full_target_waveform[offset + i]);
        }

        if (total_frame_energy < 0.05f && frame_index > 0) {
            run_ay_emulator_flexible(last_valid_ay, play_buffer, sample_stride, &global_tracking_state);
            if (offset + sample_stride <= total_wav_samples) {
                memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
            }
            frame_index++;
            continue;
        }

        apply_bandpass(&full_target_waveform[offset], filtered_ch[0], window_size, 30.0f, 240.0f);   
        apply_bandpass(&full_target_waveform[offset], filtered_ch[1], window_size, 241.0f, 1500.0f); 
        apply_bandpass(&full_target_waveform[offset], filtered_ch[2], window_size, 1501.0f, 6000.0f);

        float target_freqs[3] = {0};
        float target_crossings[3] = {0};
        uint16_t periods[3] = {0};
        uint8_t calculated_mixer = 0x3F; 

        for (int c = 0; c < 3; c++) {
            float band_energy = 0.0f;
            for (int i = 0; i < window_size; i++) band_energy += fabsf(filtered_ch[c][i]);
            
            if (band_energy > (total_frame_energy * 0.12f)) {
                target_freqs[c] = calculate_zcd_frequency(filtered_ch[c], window_size, sample_rate);
                target_crossings[c] = calculate_fractional_crossings(filtered_ch[c], window_size);
                periods[c] = (uint16_t)((double)AY_CLOCK / (16.0 * target_freqs[c]));
                if (periods[c] > 4095) periods[c] = 4095;
                if (periods[c] < 1) periods[c] = 1;
                calculated_mixer &= ~(1 << c); 
            }
        }

        for (int i = 0; i < 3; i++) {
            for (int j = i + 1; j < 3; j++) {
                if (periods[i] > 0 && periods[j] > 0) {
                    float ratio = (float)periods[i] / (float)periods[j];
                    if (fabsf(log2f(ratio)) < 0.125f || fabsf(log2f(ratio) - 1.0f) < 0.05f) {
                        periods[j] = 0;
                        target_crossings[j] = 0.0f;
                        calculated_mixer |= (1 << j); 
                    }
                }
            }
        }

        uint8_t population[POPULATION_SIZE][GENOME_SIZE];
        float fitness[POPULATION_SIZE];

        for (int i = 0; i < POPULATION_SIZE; i++) {
            memset(population[i], 0, GENOME_SIZE);
            population[i][7] = calculated_mixer; 
            
            for (int c = 0; c < 3; c++) {
                if (periods[c] > 0) {
                    int var = (periods[c] < 12) ? 1 : 6;
                    uint16_t mut_p = (periods[c] + (xorshift32() % (var * 2)) - var) & 0x0FFF;
                    if (mut_p < 1) mut_p = 1;
                    population[i][c*2] = mut_p & 0xFF;
                    population[i][c*2+1] = (mut_p >> 8) & 0x0F;
                    population[i][8+c] = 0x0B; // Locks volume stable to matching input context trace profiles
                } else {
                    population[i][8+c] = 0x00; 
                }
            }
        }

        for (int g = 0; g < GENERATIONS; g++) {
            float max_fit = -1.0f; int best_idx = 0;
            for (int i = 0; i < POPULATION_SIZE; i++) {
                // FIXED: Compares floating density scores across active channels
                fitness[i] = evaluate_fitness_fast(population[i], &full_target_waveform[offset], fitness_scratchpad, last_winning_periods, target_crossings[1]);
                if (fitness[i] > max_fit) { max_fit = fitness[i]; best_idx = i; }
            }

            uint8_t next_gen[POPULATION_SIZE][GENOME_SIZE];
            memcpy(next_gen, population[best_idx], GENOME_SIZE); 

            for (int i = 1; i < POPULATION_SIZE; i++) {
                int p1 = xorshift32() % POPULATION_SIZE, p2 = xorshift32() % POPULATION_SIZE;
                int parent = (fitness[p1] > fitness[p2]) ? p1 : p2;
                memcpy(next_gen[i], population[parent], GENOME_SIZE);

                if ((xorshift32() % 100) < 45) {
                    int c = xorshift32() % 3;
                    if (periods[c] > 0) {
                        uint16_t current_p = next_gen[i][c*2] | ((next_gen[i][c*2+1] & 0x0F) << 8);
                        int spread = (target_freqs[c] > 1500.0f) ? 1 : 4; // Narrowed mutation window for tracking lock
                        current_p = (current_p + (xorshift32() % (spread * 2)) - spread) & 0x0FFF;
                        if (current_p < 1) current_p = 1;
                        next_gen[i][c*2] = current_p & 0xFF;        
                        next_gen[i][c*2+1] = (current_p >> 8) & 0x0F; 
                    }
                }
            }
            memcpy(population, next_gen, sizeof(population));
        }

        float final_fit = -1.0f; int winner = 0;
        for (int i = 0; i < POPULATION_SIZE; i++) {
            float f = evaluate_fitness_fast(population[i], &full_target_waveform[offset], fitness_scratchpad, last_winning_periods, target_crossings[1]);
            if (f > final_fit) { final_fit = f; winner = i; }
        }

        uint8_t final_ay[GENOME_SIZE];
        memcpy(final_ay, population[winner], GENOME_SIZE);

        fprintf(stdout, "\t\tAY:"); fprintf(stderr, "\t\tAY:");
        for (int j = 0; j < GENOME_SIZE; j++) {
            fprintf(stdout, " %02x", final_ay[j]); fprintf(stderr, " %02x", final_ay[j]);
        }
        fprintf(stdout, "\n"); fprintf(stderr, "\n");

        memcpy(last_valid_ay, final_ay, GENOME_SIZE);
        for(int c=0; c<3; c++) {
            last_winning_periods[c] = final_ay[c*2] | ((final_ay[c*2+1] & 0x0F) << 8);
        }

        run_ay_emulator_flexible(final_ay, play_buffer, sample_stride, &global_tracking_state);
        if (offset + sample_stride <= total_wav_samples) {
            memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
        }
        frame_index++;
    }

    fprintf(stderr, "[*] Saving complete stable track preview file...\n");
    write_output_wav("match_preview.wav", complete_assembled_preview, total_wav_samples);

    free(play_buffer); free(fitness_scratchpad); 
    for(int i=0; i<3; i++) free(filtered_ch[i]);
    free(complete_assembled_preview); free(full_target_waveform);
    return 0;
}
