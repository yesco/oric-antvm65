#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define TICK_RATE         50        
#define EVAL_WINDOW_MS    20        
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
    uint16_t tone_period[3];      
    uint8_t  noise_period;
    uint8_t  mixer;
    uint8_t  amplitude[3];        
    double   tone_counter[3];     
    int8_t   tone_state[3];
} AY_Chip;

AY_Chip global_tracking_state;

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

// Sub-sample linear interpolation pitch analyzer
float calculate_precise_frequency(float* signal, int length, int s_rate) {
    int crossings = 0;
    double first_crossing_time = -1.0;
    double last_crossing_time = -1.0;

    for (int i = 1; i < length - 1; i++) {
        if ((signal[i] >= 0.0f && signal[i-1] < 0.0f) || (signal[i] < 0.0f && signal[i-1] >= 0.0f)) {
            double left = fabsf(signal[i-1]);
            double right = fabsf(signal[i]);
            double total_dist = left + right;
            double fraction = (total_dist > 0.0001) ? (left / total_dist) : 0.5;
            
            double exact_sample_idx = (double)(i - 1) + fraction;
            double timestamp = exact_sample_idx / (double)s_rate;

            crossings++;
            if (first_crossing_time < 0.0) first_crossing_time = timestamp;
            last_crossing_time = timestamp;
        }
    }

    if (crossings < 2 || first_crossing_time == last_crossing_time) return 0.0f; 

    double total_duration = last_crossing_time - first_crossing_time;
    double total_cycles = (double)(crossings - 1) / 2.0;
    return (float)(total_cycles / total_duration);
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
    
    float* filtered_ch[3];
    for (int i = 0; i < 3; i++) filtered_ch[i] = (float*)malloc(window_size * sizeof(float));

    int frame_index = 0;
    uint8_t out_ay_regs[GENOME_SIZE] = {0};
    uint16_t last_periods[3] = {0, 0, 0};

    memset(&global_tracking_state, 0, sizeof(AY_Chip));
    for(int c=0; c<3; c++) global_tracking_state.tone_state[c] = 1;

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        float total_frame_energy = 0.0f;
        for (int i = 0; i < window_size; i++) {
            total_frame_energy += fabsf(full_target_waveform[offset + i]);
        }

        memset(out_ay_regs, 0, GENOME_SIZE);
        out_ay_regs[7] = 0x3F; // Default: All channels muted

        if (total_frame_energy < 0.05f) {
            run_ay_emulator_flexible(out_ay_regs, play_buffer, sample_stride, &global_tracking_state);
            if (offset + sample_stride <= total_wav_samples) {
                memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
            }
            frame_index++;
            continue;
        }

        apply_bandpass(&full_target_waveform[offset], filtered_ch[0], window_size, 30.0f, 240.0f);   
        apply_bandpass(&full_target_waveform[offset], filtered_ch[1], window_size, 241.0f, 1500.0f); 
        apply_bandpass(&full_target_waveform[offset], filtered_ch[2], window_size, 1501.0f, 6000.0f);

        uint16_t raw_periods[3] = {0, 0, 0};

        for (int c = 0; c < 3; c++) {
            float band_energy = 0.0f;
            for (int i = 0; i < window_size; i++) band_energy += fabsf(filtered_ch[c][i]);
            
            if (band_energy > (total_frame_energy * 0.15f)) {
                float freq = calculate_precise_frequency(filtered_ch[c], window_size, sample_rate);
                if (freq > 15.0f && freq < 6000.0f) {
                    raw_periods[c] = (uint16_t)round((double)AY_CLOCK / (16.0 * (double)freq));
                }
            }
        }

        // Cross-channel deduplication logic pass
        for (int i = 0; i < 3; i++) {
            for (int j = i + 1; j < 3; j++) {
                if (raw_periods[i] > 0 && raw_periods[j] > 0) {
                    float ratio = (float)raw_periods[i] / (float)raw_periods[j];
                    if (fabsf(log2f(ratio)) < 0.125f || fabsf(log2f(ratio) - 1.0f) < 0.05f) {
                        raw_periods[j] = 0;
                    }
                }
            }
        }

        // Apply 1-sample Dead-Band Hysteresis Filter directly to the register assignments
        for (int c = 0; c < 3; c++) {
            if (raw_periods[c] > 0) {
                if (last_periods[c] > 0 && abs((int)raw_periods[c] - (int)last_periods[c]) <= 1) {
                    raw_periods[c] = last_periods[c]; // Prevent integer rattling tremors completely
                }
                
                if (raw_periods[c] > 4095) raw_periods[c] = 4095;
                if (raw_periods[c] < 1) raw_periods[c] = 1;

                out_ay_regs[c * 2] = raw_periods[c] & 0xFF;
                out_ay_regs[c * 2 + 1] = (raw_periods[c] >> 8) & 0x0F;
                out_ay_regs[7] &= ~(1 << c);   // Un-mute channel bit safely
                out_ay_regs[8 + c] = 0x0F;    // Lock clean full volume output context
                last_periods[c] = raw_periods[c];
            } else {
                last_periods[c] = 0;
            }
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
    for(int i=0; i<3; i++) free(filtered_ch[i]);
    free(complete_assembled_preview); free(full_target_waveform);
    return 0;
}
