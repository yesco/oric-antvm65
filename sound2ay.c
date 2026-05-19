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
#define EVAL_WINDOW_MS    20        
#define AY_CLOCK          1000000   // 1 MHz Target Hardware
#define CACHE_SIZE        64        

int sample_rate = 44100;
int window_size = 0;              
int total_wav_samples = 0;
float* full_target_waveform = NULL;

uint8_t winner_cache[CACHE_SIZE][GENOME_SIZE];
int cache_count = 0;

const float ay_vol_table[16] = {
    0.0000f, 0.0137f, 0.0205f, 0.0291f, 
    0.0423f, 0.0618f, 0.0847f, 0.1269f,
    0.1716f, 0.2442f, 0.3445f, 0.4672f, 
    0.6190f, 0.7745f, 0.9161f, 1.0000f
};

typedef struct {
    uint16_t tone_period;      
    uint8_t  noise_period;
    uint8_t  mixer;
    uint8_t  amplitude;        
    uint16_t env_period;
    uint8_t  env_shape;
    double   tone_counter;     
    int8_t   tone_state;
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
    
    chip.tone_period = regs[0] | ((regs[1] & 0x0F) << 8);
    chip.mixer       = regs[7];
    chip.amplitude   = regs[8] & 0x0F; 
    
    chip.tone_state = 1;
    double ay_ticks_per_sample = (double)AY_CLOCK / sample_rate;

    for (int s = 0; s < num_samples; s++) {
        if (chip.tone_period > 0) {
            chip.tone_counter += ay_ticks_per_sample;
            uint32_t step_threshold = 16 * chip.tone_period; 
            while (chip.tone_counter >= step_threshold) {
                chip.tone_counter -= step_threshold;
                chip.tone_state = -chip.tone_state;
            }
        }
        int tone_enabled = !((chip.mixer >> 0) & 1);
        if (tone_enabled && chip.tone_period > 0) {
            out_buffer[s] = ((float)chip.tone_state * ay_vol_table[chip.amplitude]);
        } else {
            out_buffer[s] = 0.0f;
        }
    }
}

// CHANGED: Evaluates fitness using absolute shape correlation to ignore phase shifts
float evaluate_fitness_fast(uint8_t* genome, float* target_segment, float* scratchpad) {
    run_ay_emulator_flexible(genome, scratchpad, window_size);
    
    float error = 0.0f;
    for (int i = 0; i < window_size; i++) { 
        float diff = fabsf(target_segment[i]) - fabsf(scratchpad[i]);
        error += diff * diff;
    }
    return 1000.0f / (error + 0.0001f);
}

// NEW: Ultra-stable time-domain pitch extraction based on zero-crossing intervals
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

    fprintf(stderr, "[*] Target Wave Loaded: Rate=%dHz, Samples=%d\n", sample_rate, total_wav_samples);

    int sample_stride = (sample_rate * 20) / 1000; 
    
    float* complete_assembled_preview = (float*)calloc(total_wav_samples, sizeof(float));
    float* play_buffer = (float*)malloc(sample_stride * sizeof(float));
    float* fitness_scratchpad = (float*)malloc(window_size * sizeof(float)); 

    int frame_index = 0;
    uint8_t last_valid_ay[GENOME_SIZE] = {0x0e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3e, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00};

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        fprintf(stderr, "\n============================================================\n");
        fprintf(stderr, "Frame #%04d (Time Offset: %06.2fs)\n", frame_index, (float)offset / sample_rate);
        fprintf(stderr, "============================================================\n");
        
        float total_frame_energy = 0.0f;
        for (int i = 0; i < window_size; i++) {
            total_frame_energy += fabsf(full_target_waveform[offset + i]);
        }

        if (total_frame_energy < 0.05f && frame_index > 0) {
            fprintf(stderr, "[Notice] Silent audio gap. Preserving states.\n");
            fprintf(stdout, "\t\tAY:"); fprintf(stderr, "\t\tAY:");
            for (int j = 0; j < GENOME_SIZE; j++) {
                fprintf(stdout, " %02x", last_valid_ay[j]); fprintf(stderr, " %02x", last_valid_ay[j]);
            }
            fprintf(stdout, "\n"); fprintf(stderr, "\n");

            run_ay_emulator_flexible(last_valid_ay, play_buffer, sample_stride);
            if (offset + sample_stride <= total_wav_samples) {
                memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
            }
            frame_index++;
            continue;
        }

        // CHANGED: Replaced buggy AMDF loop with bulletproof ZCD mathematical tracker
        float target_frequency = calculate_zcd_frequency(&full_target_waveform[offset], window_size, sample_rate);
        
        // FIXED: Maps with complete precision to 1 MHz boundaries 
        uint16_t period = (uint16_t)((double)AY_CLOCK / (16.0 * target_frequency));
        if (period > 4095) period = 4095;
        if (period < 1) period = 1; 

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
            int variance = (period < 10) ? 1 : 8;
            uint16_t mutated_period = (period + (xorshift32() % (variance * 2)) - variance) & 0x0FFF;
            population[idx][0] = mutated_period & 0xFF;
            population[idx][1] = (mutated_period >> 8) & 0x0F;
            idx++;
        }

        for (int g = 0; g < GENERATIONS; g++) {
            float max_fit = -1.0f; int best_idx = 0;
            for (int i = 0; i < POPULATION_SIZE; i++) {
                fitness[i] = evaluate_fitness_fast(population[i], &full_target_waveform[offset], fitness_scratchpad);
                if (fitness[i] > max_fit) { max_fit = fitness[i]; best_idx = i; }
            }

            if (g % 5 == 0) {
                fprintf(stderr, "  Gen [%02d/%02d] -> Target Track Pitch: %7.1fHz, Top Fitness: %8.2f\n", g, GENERATIONS, target_frequency, max_fit);
            }

            uint8_t next_gen[POPULATION_SIZE][GENOME_SIZE];
            memcpy(next_gen, population[best_idx], GENOME_SIZE); 

            for (int i = 1; i < POPULATION_SIZE; i++) {
                int p1 = xorshift32() % POPULATION_SIZE, p2 = xorshift32() % POPULATION_SIZE;
                int parent = (fitness[p1] > fitness[p2]) ? p1 : p2;
                memcpy(next_gen[i], population[parent], GENOME_SIZE);

                if ((xorshift32() % 100) < 40) {
                    uint16_t current_p = next_gen[i][0] | ((next_gen[i][1] & 0x0F) << 8);
                    int mutation_spread = (target_frequency > 1500.0f) ? 1 : 6;
                    current_p = (current_p + (xorshift32() % (mutation_spread * 2)) - mutation_spread) & 0x0FFF;
                    if (current_p < 1) current_p = 1;
                    next_gen[i][0] = current_p & 0xFF;        
                    next_gen[i][1] = (current_p >> 8) & 0x0F; 
                }
            }
            memcpy(population, next_gen, sizeof(population));
        }

        float final_fit = -1.0f; int winner = 0;
        for (int i = 0; i < POPULATION_SIZE; i++) {
            float f = evaluate_fitness_fast(population[i], &full_target_waveform[offset], fitness_scratchpad);
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
    free(play_buffer); free(fitness_scratchpad); free(complete_assembled_preview); free(full_target_waveform);
    return 0;
}
