#include <stdio.h>
#include <stdint.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882
#define YM_CLOCK 1000000.0

/* Oscillator & Envelope States */
static double countdown[3] = {0, 0, 0};
static int16_t out_state[3] = {1, 1, 1};

/* Envelope State */
static double env_countdown = 0;
static int32_t env_level = 0;      /* 0 to 31 (internal YM resolution) */
static int8_t env_direction = -1;  /* -1 for down, 1 for up */
static int8_t env_holding = 0;     /* 1 if envelope has reached a hold state */

void fill_buffer_with_ym(unsigned char *regs, int16_t *buffer) {
    // Tone Periods (Regs 0-5)
    uint16_t periods[3];
    periods[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    periods[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    periods[2] = regs[4] | ((regs[5] & 0x0F) << 8);

    // Envelope Period (Regs 11-12)
    uint16_t env_period = regs[11] | (regs[12] << 8);
    // Envelope Shape (Reg 13) - Only lower 4 bits
    uint8_t shape = regs[13] & 0x0F;

    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        /* --- 1. Update Envelope --- */
        double env_step_ticks = (env_period < 1) ? 1.0 : (double)env_period * 256.0;
        env_countdown -= ticks_per_sample;

        if (env_countdown <= 0 && !env_holding) {
            env_countdown += env_step_ticks;
            env_level += env_direction;

            // Handle Shape Logic (Simplified logic for common shapes like Saw/Triangle)
            if (env_level < 0 || env_level > 31) {
                int hold = shape & 0x01;
                int alternate = shape & 0x02;
                int attack = shape & 0x04;
                int continue_bit = shape & 0x08;

                if (!continue_bit) {
                    env_level = 0;
                    env_holding = 1;
                } else {
                    if (alternate) {
                        env_direction = -env_direction;
                        env_level += env_direction;
                    } else if (hold) {
                        env_level = (env_direction > 0) ? 31 : 0;
                        env_holding = 1;
                    } else {
                        env_level = (env_direction > 0) ? 0 : 31;
                    }
                }
            }
        }

        /* --- 2. Generate and Mix Channels --- */
        int32_t mixed_sample = 0;
        for (int ch = 0; ch < 3; ch++) {
            uint8_t v_reg = regs[8 + ch];
            int16_t current_vol;

            // If bit 4 of volume reg is set, use envelope
            if (v_reg & 0x10) {
                current_vol = (env_level * 1000); 
            } else {
                current_vol = (v_reg & 0x0F) * 1500;
            }

            if (periods[ch] > 0) {
                double eff_p = (double)periods[ch] * 16.0;
                countdown[ch] -= ticks_per_sample;
                while (countdown[ch] <= 0) {
                    countdown[ch] += eff_p;
                    out_state[ch] = -out_state[ch];
                }
                mixed_sample += (out_state[ch] > 0) ? current_vol : -current_vol;
            }
        }

        if (mixed_sample > 32767) mixed_sample = 32767;
        if (mixed_sample < -32768) mixed_sample = -32768;
        buffer[i] = (int16_t)mixed_sample;
    }
}

int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    if (!audio_pipe) return 1;

    unsigned char ym_regs[14] = {0};
    int16_t audio_buffer[SAMPLES_PER_FRAME];

    // Setup Test: Channel A with Envelope
    ym_regs[0] = 454 & 0xFF; ym_regs[1] = (454 >> 8); // Note C
    ym_regs[8] = 0x10;                               // Use Envelope
    ym_regs[11] = 0x00; ym_regs[12] = 0x20;          // Slowish envelope
//    ym_regs[13] = 0x08;                              // Sawtooth shape (Continue, Attack=0)
    ym_regs[13] = 0x08;

    while (1) {
        fill_buffer_with_ym(ym_regs, audio_buffer);
        if (fwrite(audio_buffer, sizeof(int16_t), SAMPLES_PER_FRAME, audio_pipe) < SAMPLES_PER_FRAME) break;
        fflush(audio_pipe);
    }
    pclose(audio_pipe);
    return 0;
}
