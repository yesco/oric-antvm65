#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define POPULATION_SIZE   32        
#define GENOME_SIZE       14
#define GENERATIONS       10        
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

// Accurate AY-3-8910 logarithmic voltage volume mapping table
const float ay_vol_table[16] = {
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
    uint16_t env_period;
    uint8_t  env_shape;
    double   tone_counter[3];     // CHANGED: Double precision for phase scaling stability
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
    
    chip.tone_period[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    chip.tone_period[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    chip.tone_period[2] = regs[4] | ((regs[5] & 0x0F) << 8);
    chip.noise_period   = regs[6] & 0x1F;
    chip.mixer          = regs[7];
    chip.amplitude[0]   = regs[8] & 0x1F; 
    chip.amplitude[1]   = regs[9] & 0x1F; 
    chip.amplitude[2]   = regs[10] & 0x1F; 
    
    for (int c = 0; c < 3; c++) chip.tone_state[c] = 1;
    
    // FIXED: True hardware cycle step increments map tracking values linearly per sound frame loop
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
            if (tone_enabled && chip.tone_period[c] > 0) {
                active_channels++;
                // FIXED: Now maps to the correct vintage logarithmic hardware step structure
                mix += ((float)chip.tone_state[c] * ay_vol_table[chip.amplitude[c] & 0x0F]);
            }
        }
        out_buffer[s] = (active_channels > 0) ? (mix / (float)active_channels) : 0.0f;
    }
}

// FIXED: Added pre-allocated candidate window scratchpad pointer to eliminate inner loop malloc/free calls completely
float evaluate_fitness_fast(uint8_t* genome, float* target_segment, float* scratchpad, float peak_amp) {
    run_ay_emulator_flexible(genome, scratchpad, window_size);
    
    float error = 0.0f;
    for (int i = 0; i < window_size; i += 2) { 
        // FIXED: Scaling candidate to target's normalized space using local window peak amplitude matching
        float scaled_candidate = scratchpad[i] * peak_amp;
        float diff = target_segment[i] - scaled_candidate;
        error += diff * diff;
    }
    
    return 1000.0f / (error + 0.0001f);
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

    // FIXED: Correct usage print configuration argument error tracking pass structural crash guard
    if (!wav_filename || !load_full_wav(wav_filename)) {
        fprintf(stderr, "Usage: %s <target.wav> [-pipe] [-skip_ms <ms>]\n", (argc > 0) ? argv[0] : "ay_optimizer"); 
        return 1;
    }

    fprintf(stderr, "[*] Processing Target Content: Rate=%dHz, Samples=%d\n", sample_rate, total_wav_samples);

    int sample_stride = (skip_ms > 0) ? (sample_rate * skip_ms / 1000) : ((sample_rate * 20) / 1000); 
    
    float* complete_assembled_preview = (float*)calloc(total_wav_samples, sizeof(float));
    float* play_buffer = (float*)malloc(sample_stride * sizeof(float));
    float* norm_window = (float*)malloc(window_size * sizeof(float));
    float* amdf_array = (float*)calloc(window_size / 2, sizeof(float));
    float* fitness_scratchpad = (float*)malloc(window_size * sizeof(float)); // New persistent allocations block container

    int frame_index = 0;
    uint8_t last_valid_ay[GENOME_SIZE] = {0x0e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3e, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00};

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        fprintf(stderr, "\n============================================================\n");
        fprintf(stderr, "Frame #%04d (Time Offset: %06.2fs)\n", frame_index, (float)offset / sample_rate);
        fprintf(stderr, "============================================================\n");
        
        float peak_amp = 0.0001f;
        float total_frame_energy = 0.0f;
        for (int i = 0; i < window_size; i++) {
            float abs_val = fabsf(full_target_waveform[offset + i]);
            total_frame_energy += abs_val;
            if (abs_val > peak_amp) peak_amp = abs_val;
        }

        if (total_frame_energy < 0.05f && frame_index > 0) {
            fprintf(stderr, "[Notice] Silent audio gap encountered. Preserving tracking states.\n");
            
            fprintf(stdout, "\t\tAY:"); fprintf(stderr, "\t\tAY:");
            for (int j = 0; j < GENOME_SIZE; j++) {
                fprintf(stdout, " %02x", last_valid_ay[j]); fprintf(stderr, " %02x", last_valid_ay[j]);
            }
            fprintf(stdout, "\n"); fprintf(stderr, "\n");

            run_ay_emulator_flexible(last_valid_ay, play_buffer, sample_stride);
            if (offset + sample_stride <= total_wav_samples) {
                memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
            }
            if (pipe_audio) {
                for (int k = 0; k < sample_stride; k++) {
                    int16_t pcm_sample = (int16_t)(play_buffer[k] * 0.15f * 32767.0f);
                    fwrite(&pcm_sample, sizeof(int16_t), 1, stdout);
                }
            }
            frame_index++;
            continue;
        }

        for (int i = 0; i < window_size; i++) norm_window[i] = full_target_waveform[offset + i] / peak_amp;

        int max_tau = window_size / 2;
        int best_tau = 0;
        float min_namdf = 1e10f;

        for (int tau = 2; tau < max_tau; tau++) {
            float amdf = 0.0f;
            float energy_scale = 0.0001f;
            
            for (int t = 0; t < max_tau; t += 2) {
                amdf += fabsf(norm_window[t] - norm_window[t + tau]);
                energy_scale += fabsf(norm_window[t]) + fabsf(norm_window[t + tau]);
            }
            
            float namdf = amdf / energy_scale;
            amdf_array[tau] = namdf;
            
            if (namdf < min_namdf && tau > 2) {
                min_namdf = namdf;
                best_tau = tau;
            }
        }

        float exact_tau = (float)best_tau;
        if (best_tau > 3 && best_tau < max_tau - 1) {
            float y1 = amdf_array[best_tau - 1];
            float y2 = amdf_array[best_tau];
            float y3 = amdf_array[best_tau + 1];
            float denominator = (y3 - 2.0f * y2 + y1);
            if (fabsf(denominator) > 0.0001f) {
                exact_tau = (float)best_tau + (y1 - y3) / (2.0f * denominator);
            }
        }

        float target_frequency = (exact_tau > 0.0f) ? ((float)sample_rate / exact_tau) : 440.0f;
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
            uint16_t mutated_period = (period + (xorshift32() % 16) - 8) & 0x0FFF;
            population[idx][0] = mutated_period & 0xFF;
            population[idx][1] = (mutated_period >> 8) & 0x0F;
            idx++;
        }

        for (int g = 0; g < GENERATIONS; g++) {
            float max_fit = -1.0f; int best_idx = 0;
            for (int i = 0; i < POPULATION_SIZE; i++) {
                // FIXED: Now passing scratchpad tracking arrays and current peak metrics dynamically inside loop parameters
                fitness[i] = evaluate_fitness_fast(population[i], norm_window, fitness_scratchpad, peak_amp);
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

                if ((xorshift32() % 100) < 35) {
                    uint16_t current_p = next_gen[i][0] | ((next_gen[i][1] & 0x0F) << 8);
                    current_p = (current_p + (xorshift32() % 10) - 5) & 0x0FFF;
                    next_gen[i][0] = current_p & 0xFF;        
                    next_gen[i][1] = (current_p >> 8) & 0x0F; 
                }
            }
            memcpy(population, next_gen, sizeof(population));
        }

        float final_fit = -1.0f; int winner = 0;
        for (int i = 0; i < POPULATION_SIZE; i++) {
            // FIXED: Passing persistent execution layout boundaries
            float f = evaluate_fitness_fast(population[i], norm_window, fitness_scratchpad, peak_amp);
            if (f > final_fit) { final_fit = f; winner = i; }
        }

        uint8_t final_ay[GENOME_SIZE];
        memcpy(final_ay, population[winner], GENOME_SIZE);

        // FIXED: Dropped the raw manual variable overrides that were discarding genetic fine-tuning optimizations

        fprintf(stdout, "\t\tAY:"); fprintf(stderr, "\t\tAY:");
        for (int j = 0; j < GENOME_SIZE; j++) {
            fprintf(stdout, " %02x", final_ay[j]); fprintf(stderr, " %02x", final_ay[j]);
        }
        fprintf(stdout, "\n"); fprintf(stderr, "\n");

        memcpy(last_valid_ay, final_ay, GENOME_SIZE);
        memcpy(winner_cache[cache_count % CACHE_SIZE], final_ay, GENOME_SIZE);
        cache_count++;

        run_ay_emulator_flexible(final_ay, play_buffer, sample_stride);
        
        if (offset + sample_stride <= total_wav_samples) {
            memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
        }

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
    free(play_buffer); free(norm_window); free(amdf_array); 
    free(fitness_scratchpad); free(complete_assembled_preview); free(full_target_waveform);
    return 0;
}
