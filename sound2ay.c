#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define TICK_RATE         50        
#define EVAL_WINDOW_MS    60        // 60ms window cushion remains intact to natively support low bass parameters
#define AY_CLOCK          1000000   // 1 MHz Target Hardware
#define GENOME_SIZE       14

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

int sample_rate = 44100;
int window_size = 0;              
int total_wav_samples = 0;
float* full_target_waveform = NULL;

const float ay_vol_table[] = {
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
    double   tone_counter;     
    int8_t   tone_state;
} AY_Chip;

AY_Chip global_tracking_state;

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
    
    chip.tone_period = regs[0] | ((regs[1] & 0x0F) << 8);
    chip.mixer       = regs[7];
    chip.amplitude   = regs[8] & 0x0F; 
    
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
        if (tone_enabled && chip.tone_period > 0 && chip.amplitude > 0) {
            out_buffer[s] = ((float)chip.tone_state * ay_vol_table[chip.amplitude]);
        } else {
            out_buffer[s] = 0.0f;
        }
    }
    *state_ptr = chip;
}

// CHANGED: Upgraded the pitch engine to clean YIN-style Cumulative Mean Normalized Difference math
float calculate_yin_frequency(float* signal, int length, int s_rate, float min_f, float max_f) {
    int max_shift = (int)(s_rate / min_f);
    int min_shift = (int)(s_rate / max_f);
    if (max_shift > length / 2) max_shift = length / 2;
    if (min_shift < 2) min_shift = 2;

    float* diff_buffer = (float*)calloc(max_shift + 1, sizeof(float));

    // Step 1: Compute raw absolute difference array values
    for (int tau = 1; tau <= max_shift; tau++) {
        float sq_diff = 0.0f;
        for (int t = 0; t < length / 2; t++) {
            float d = signal[t] - signal[t + tau];
            sq_diff += d * d;
        }
        diff_buffer[tau] = sq_diff;
    }

    // Step 2: Apply Cumulative Mean Normalization algorithm blocks
    diff_buffer[0] = 1.0f;
    float running_sum = 0.0f;
    for (int tau = 1; tau <= max_shift; tau++) {
        running_sum += diff_buffer[tau];
        if (running_sum > 0.0001f) {
            diff_buffer[tau] = diff_buffer[tau] / (running_sum / (float)tau);
        } else {
            diff_buffer[tau] = 1.0f;
        }
    }

    // Step 3: Absolute Threshold Selection pass to isolate the fundamental period trough
    int best_tau = -1;
    float threshold = 0.15f; // Standard YIN fundamental cut-off threshold value container
    for (int tau = min_shift; tau <= max_shift; tau++) {
        if (diff_buffer[tau] < threshold) {
            best_tau = tau;
            break;
        }
    }

    // Fallback: If no point crosses the threshold grid cleanly, pick the absolute local minimum
    if (best_tau < 0) {
        float min_val = 1e10f;
        for (int tau = min_shift; tau <= max_shift; tau++) {
            if (diff_buffer[tau] < min_val) {
                min_val = diff_buffer[tau];
                best_tau = tau;
            }
        }
    }

    // Step 4: High-precision sub-sample parabolic interpolation calculation loop pass
    float exact_tau = (float)best_tau;
    if (best_tau > min_shift && best_tau < max_shift) {
        float y1 = diff_buffer[best_tau - 1];
        float y2 = diff_buffer[best_tau];
        float y3 = diff_buffer[best_tau + 1];
        float denom = y3 - 2.0f * y2 + y1;
        if (fabsf(denom) > 0.0001f) {
            exact_tau = (float)best_tau + (y1 - y3) / (2.0f * denom);
        }
    }

    free(diff_buffer);
    if (best_tau < 0 || exact_tau <= 0.0f) return 0.0f;
    return (float)s_rate / exact_tau;
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
    
    int frame_index = 0;
    uint8_t out_ay_regs[GENOME_SIZE] = {0};
    uint16_t last_period = 0;

    memset(&global_tracking_state, 0, sizeof(AY_Chip));
    global_tracking_state.tone_state = 1;

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        float total_frame_energy = 0.0f;
        for (int i = 0; i < sample_stride; i++) {
            total_frame_energy += fabsf(full_target_waveform[offset + i]);
        }

        memset(out_ay_regs, 0, GENOME_SIZE);
        out_ay_regs[7] = 0x3F; 

        if (total_frame_energy < 0.01f) {
            last_period = 0; 
            run_ay_emulator_flexible(out_ay_regs, play_buffer, sample_stride, &global_tracking_state);
            if (offset + sample_stride <= total_wav_samples) {
                memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
            }
            frame_index++;
            continue;
        }

        // FIXED: Invokes the new YIN normalization engine to completely stop subharmonic octave lock errors
        float freq = calculate_yin_frequency(&full_target_waveform[offset], window_size, sample_rate, 30.0f, 4000.0f);
        uint16_t raw_period = 0;

        if (freq > 30.0f && freq < 4000.0f) {
            raw_period = (uint16_t)round((double)AY_CLOCK / (16.0 * (double)freq));
        }

        if (raw_period > 0) {
            if (last_period > 0 && abs((int)raw_period - (int)last_period) <= 1) {
                raw_period = last_period; 
            }
            
            if (raw_period > 4095) raw_period = 4095;
            if (raw_period < 1) raw_period = 1;

            out_ay_regs[0] = raw_period & 0xFF;
            out_ay_regs[1] = (raw_period >> 8) & 0x0F;
            out_ay_regs[7] = 0x3E; 
            out_ay_regs[8] = 0x0F; 
            last_period = raw_period;
        } else {
            last_period = 0;
        }

        printf("AY:");
        for (int j = 0; j < GENOME_SIZE; j++) printf(" %02x", out_ay_regs[j]);
        printf("\n");

        run_ay_emulator_flexible(out_ay_regs, play_buffer, sample_stride, &global_tracking_state);
        if (offset + sample_stride <= total_wav_samples) {
            memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
        }
        frame_index++;
    }

    fprintf(stderr, "[*] Saving complete stable track preview file...\n");
    write_output_wav("match_preview.wav", complete_assembled_preview, total_wav_samples);

    free(play_buffer);
    free(complete_assembled_preview); free(full_target_waveform);
    return 0;
}
