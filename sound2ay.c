#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define TICK_RATE         50        
#define EVAL_WINDOW_MS    100       
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
    double   noise_counter;
    uint32_t noise_rng;
    int8_t   noise_state;
} AY_Chip;

AY_Chip global_tracking_state;

typedef struct {
    float freq;
    float depth;
} PitchCandidate;

int compare_candidates(const void* a, const void* b);

int compare_candidates(const void* a, const void* b) {
    float depthA = ((PitchCandidate*)a)->depth;
    float depthB = ((PitchCandidate*)b)->depth;
    return (depthA < depthB) ? 1 : -1; 
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
    
    uint16_t num_channels = header[22] | (header[23] << 8);
    uint32_t r_rate = header[24] | (header[25] << 8) | (header[26] << 16) | (header[27] << 24);
    uint16_t bits_per_sample = header[34] | (header[35] << 8);
    
    if (r_rate > 0) sample_rate = r_rate;
    if (num_channels < 1) num_channels = 1;
    
    fseek(f, 12, SEEK_SET);
    uint32_t chunk_id, chunk_size, data_size = 0;
    while (fread(&chunk_id, 4, 1, f) == 1) {
        if (fread(&chunk_size, 4, 1, f) != 1) break;
        if (memcmp(&chunk_id, "data", 4) == 0) {
            data_size = chunk_size;
            break;
        }
        fseek(f, chunk_size, SEEK_CUR);
    }
    
    if (data_size == 0) {
        fprintf(stderr, "[!] Corrupt data segment layouts.\n");
        fclose(f); return 0;
    }
    
    int sample_bytes = bits_per_sample / 8;
    int frame_bytes = sample_bytes * num_channels;
    total_wav_samples = data_size / frame_bytes;
    window_size = (sample_rate * EVAL_WINDOW_MS) / 1000;
    
    full_target_waveform = (float*)calloc(total_wav_samples, sizeof(float));
    uint8_t* raw_frame = (uint8_t*)malloc(frame_bytes);
    
    for (int i = 0; i < total_wav_samples; i++) {
        if (fread(raw_frame, 1, frame_bytes, f) != (size_t)frame_bytes) break;
        
        if (bits_per_sample == 16) {
            int16_t val = (int16_t)(raw_frame[0] | (raw_frame[1] << 8));
            full_target_waveform[i] = (float)val / 32768.0f;
        } else {
            full_target_waveform[i] = ((float)raw_frame[0] - 128.0f) / 128.0f;
        }
    }
    
    free(raw_frame);
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
    chip.noise_period   = regs[6] & 0x1F;
    chip.mixer          = regs[7];
    chip.amplitude[0]   = regs[8] & 0x0F; 
    chip.amplitude[1]   = regs[9] & 0x0F; 
    chip.amplitude[2]   = regs[10] & 0x0F; 
    
    double ay_ticks_per_sample = (double)AY_CLOCK / sample_rate;
    if (chip.noise_rng == 0) chip.noise_rng = 1;

    for (int s = 0; s < num_samples; s++) {
        float mix = 0.0f;
        int active_channels = 0;

        chip.noise_counter += ay_ticks_per_sample;
        uint32_t noise_threshold = 16 * (chip.noise_period == 0 ? 1 : chip.noise_period);
        while (chip.noise_counter >= noise_threshold) {
            chip.noise_counter -= noise_threshold;
            if ((chip.noise_rng & 1) ^ ((chip.noise_rng >> 2) & 1)) {
                chip.noise_state = !chip.noise_state;
            }
            chip.noise_rng = (chip.noise_rng >> 1) | (((chip.noise_rng & 1) ^ ((chip.noise_rng >> 3) & 1)) << 16);
        }

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
            int noise_enabled = !((chip.mixer >> (c + 3)) & 1);
            
            int chan_out = 1;
            if (tone_enabled && chip.tone_period[c] > 0) chan_out &= (chip.tone_state[c] > 0);
            if (noise_enabled) chan_out &= chip.noise_state;

            if ((tone_enabled || noise_enabled) && chip.amplitude[c] > 0) {
                active_channels++;
                mix += (chan_out ? ay_vol_table[chip.amplitude[c]] : -ay_vol_table[chip.amplitude[c]]);
            }
        }
        out_buffer[s] = (active_channels > 0) ? (mix / 3.0f) : 0.0f; 
    }
    *state_ptr = chip;
}

int calculate_polyphonic_yin_frequencies(float* signal, int length, int s_rate, float* out_freqs, float* primary_peak_depth) {
    int max_shift = (int)(s_rate / 30.0f); 
    int min_shift = (int)(s_rate / 4000.0f); 
    if (max_shift > length / 2) max_shift = length / 2;

    float* autocorr = (float*)calloc(max_shift + 1, sizeof(float));

    float energy_base = 0.0001f;
    for (int t = 0; t < length / 2; t++) {
        energy_base += signal[t] * signal[t];
    }

    for (int tau = min_shift; tau <= max_shift; tau++) {
        float sum = 0.0f;
        float energy_offset = 0.0001f;
        for (int t = 0; t < length / 2; t++) {
            sum += signal[t] * signal[t + tau];
            energy_offset += signal[t + tau] * signal[t + tau];
        }
        autocorr[tau] = sum / sqrtf(energy_base * energy_offset);
    }

    PitchCandidate candidates[32];
    int candidate_count = 0;
    float threshold = 0.20f; 

    for (int tau = min_shift + 1; tau < max_shift && candidate_count < 32; tau++) {
        if (autocorr[tau] > autocorr[tau - 1] && autocorr[tau] > autocorr[tau + 1]) {
            if (autocorr[tau] > threshold) {
                float exact_tau = (float)tau;
                float y1 = autocorr[tau - 1];
                float y2 = autocorr[tau];
                float y3 = autocorr[tau + 1];
                float denom = 2.0f * y2 - y1 - y3;
                if (fabsf(denom) > 0.0001f) {
                    exact_tau = (float)tau + (y1 - y3) / (2.0f * denom);
                }

                float found_freq = (float)s_rate / exact_tau;
                if (found_freq >= 30.0f && found_freq <= 4000.0f) {
                    int is_subharmonic = 0;
                    for (int i = 0; i < candidate_count; i++) {
                        float ratio = candidates[i].freq / found_freq;
                        float rounded_ratio = roundf(ratio);
                        if (rounded_ratio >= 2.0f && fabsf(ratio - rounded_ratio) < 0.03f) {
                            is_subharmonic = 1;
                            break;
                        }
                    }

                    if (!is_subharmonic) {
                        candidates[candidate_count].freq = found_freq;
                        candidates[candidate_count].depth = autocorr[tau];
                        candidate_count++;

                        int blank_width = (int)(exact_tau * 0.50f);
                        for (int b = tau - blank_width / 2; b <= tau + blank_width && b <= max_shift; b++) {
                            if (b >= 0) autocorr[b] *= 0.1f;
                        }
                    }
                }
            }
        }
    }

    int peak_count = 0;
    *primary_peak_depth = 0.0f;
    if (candidate_count > 0) {
        *primary_peak_depth = candidates[0].depth;
        if (candidates[0].depth > 0.82f) {
            out_freqs[peak_count++] = candidates[0].freq;
        } else {
            qsort(candidates, candidate_count, sizeof(PitchCandidate), compare_candidates);
            for(int i = 0; i < candidate_count && peak_count < 3; i++) {
                out_freqs[peak_count++] = candidates[i].freq;
            }
        }
    }

    free(autocorr);
    return peak_count;
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

    // FIXED: Formally anchored to argv[0] to address compilation block safely
    if (!wav_filename || !load_full_wav(wav_filename)) {
        fprintf(stderr, "Usage: %s <target.wav> [-pipe] [-skip_ms <ms>]\n", (argc > 0) ? argv[0] : "ay_optimizer"); 
        return 1;
    }

    int sample_stride = (sample_rate * 20) / 1000; 
    float* complete_assembled_preview = (float*)calloc(total_wav_samples, sizeof(float));
    float* play_buffer = (float*)malloc(sample_stride * sizeof(float));
    
    uint8_t out_ay_regs[GENOME_SIZE] = {0};
    uint16_t last_periods[] = {0, 0, 0};

    memset(&global_tracking_state, 0, sizeof(AY_Chip));
    for(int c=0; c<3; c++) global_tracking_state.tone_state[c] = 1;
    global_tracking_state.noise_rng = 0x0001;

    for (int offset = 0; offset + window_size <= total_wav_samples; offset += sample_stride) {
        float total_frame_energy = 0.0f;
        int zero_crossings = 0;
        float prev_val = 0.0f;

        for (int i = 0; i < sample_stride; i++) {
            float cur_val = full_target_waveform[offset + i];
            total_frame_energy += fabsf(cur_val);
            if (i > 0 && ((prev_val < 0.0f && cur_val >= 0.0f) || (prev_val >= 0.0f && cur_val < 0.0f))) {
                zero_crossings++;
            }
            prev_val = cur_val;
        }

        memset(out_ay_regs, 0, GENOME_SIZE);
        out_ay_regs[7] = 0x3F; 

        if (total_frame_energy < 0.001f) {
            memset(last_periods, 0, sizeof(last_periods));
            run_ay_emulator_flexible(out_ay_regs, play_buffer, sample_stride, &global_tracking_state);
            if (offset + sample_stride <= total_wav_samples) {
                memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
            }
            continue;
        }

        float primary_peak_depth = 0.0f;
        float detected_freqs[] = {0.0f, 0.0f, 0.0f};
        int pitches_found = calculate_polyphonic_yin_frequencies(&full_target_waveform[offset], window_size, sample_rate, detected_freqs, &primary_peak_depth);

        int noise_drum_active = 0;
        uint8_t detected_noise_period = 0;
        
        float crossings_ratio = (float)zero_crossings / sample_stride;
        if ((total_frame_energy > 0.04f && primary_peak_depth < 0.48f) || (crossings_ratio > 0.28f)) {
            noise_drum_active = 1;
            uint32_t estimated_noise_freq = (zero_crossings * sample_rate) / (2 * sample_stride);
            if (estimated_noise_freq > 0) {
                uint32_t n_div = (uint32_t)round((double)AY_CLOCK / (16.0 * estimated_noise_freq));
                if (n_div > 31) n_div = 31;
                if (n_div < 1) n_div = 1;
                detected_noise_period = n_div;
            }
        }

        uint16_t raw_periods[] = {0, 0, 0};
        int validated_count = 0;

        for (int p = 0; p < pitches_found; p++) {
            if (detected_freqs[p] > 30.0f && detected_freqs[p] < 4000.0f) {
                uint16_t p_val = (uint16_t)round((double)AY_CLOCK / (16.0 * (double)detected_freqs[p]));
                int duplicate = 0;
                for (int i = 0; i < validated_count; i++) {
                    float ratio = (float)raw_periods[i] / (float)p_val;
                    if (fabsf(log2f(ratio)) < 0.04f || 
                        fabsf(log2f(ratio) - 1.0f) < 0.012f || 
                        fabsf(log2f(ratio) + 1.0f) < 0.012f ||
                        fabsf(ratio - 2.0f) < 0.012f ||
                        fabsf(ratio - 0.5f) < 0.012f) {
                        duplicate = 1;
                        break;
                    }
                }
                if (!duplicate) {
                    raw_periods[validated_count++] = p_val;
                }
            }
        }

        uint16_t target_periods[] = {0, 0, 0};
        int assigned_peaks[] = {0, 0, 0};

        for (int c = 0; c < 3; c++) {
            if (last_periods[c] > 0) {
                int best_idx = -1;
                float best_diff = 999999.0f;
                for (int p = 0; p < validated_count; p++) {
                    if (!assigned_peaks[p]) {
                        float diff = fabsf((float)raw_periods[p] - (float)last_periods[c]);
                        if (diff < best_diff) {
                            best_diff = diff;
                            best_idx = p;
                        }
                    }
                }
                if (best_idx != -1 && best_diff / (float)last_periods[c] < 0.15f) {
                    target_periods[c] = raw_periods[best_idx];
                    assigned_peaks[best_idx] = 1;
                }
            }
        }

        for (int p = 0; p < validated_count; p++) {
            if (!assigned_peaks[p]) {
                for (int c = 0; c < 3; c++) {
                    if (target_periods[c] == 0) {
                        target_periods[c] = raw_periods[p];
                        assigned_peaks[p] = 1;
                        break;
                    }
                }
            }
        }

        uint8_t current_mixer = 0x3F;
        for (int c = 0; c < 3; c++) {
            if (target_periods[c] > 0) {
                if (last_periods[c] > 0) {
                    int diff = abs((int)target_periods[c] - (int)last_periods[c]);
                    if (diff <= 1 || (float)diff / (float)last_periods[c] < 0.012f) {
                        target_periods[c] = last_periods[c];
                    }
                }
                
                if (target_periods[c] > 4095) target_periods[c] = 4095;
                if (target_periods[c] < 1) target_periods[c] = 1;

                out_ay_regs[c * 2] = target_periods[c] & 0xFF;
                out_ay_regs[c * 2 + 1] = (target_periods[c] >> 8) & 0x0F;
                current_mixer &= ~(1 << c);   
                out_ay_regs[8 + c] = 0x0F;    
                last_periods[c] = target_periods[c];
            } else {
                last_periods[c] = 0;
            }
        }

        if (noise_drum_active) {
            out_ay_regs[6] = detected_noise_period;
            current_mixer &= ~(1 << 5); 
            out_ay_regs[10] = 0x0F;     
        }

        out_ay_regs[7] = current_mixer; 

        printf("AY:");
        for (int j = 0; j < GENOME_SIZE; j++) printf(" %02x", out_ay_regs[j]);
        printf("\n");

        run_ay_emulator_flexible(out_ay_regs, play_buffer, sample_stride, &global_tracking_state);
        if (offset + sample_stride <= total_wav_samples) {
            memcpy(&complete_assembled_preview[offset], play_buffer, sample_stride * sizeof(float));
        }
    }

    fprintf(stderr, "[*] Saving complete stable track preview file...\n");
    write_output_wav("match_preview.wav", complete_assembled_preview, total_wav_samples);

    free(play_buffer);
    free(complete_assembled_preview); full_target_waveform = NULL;
    return 0;
}
