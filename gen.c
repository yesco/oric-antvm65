#include <stdio.h>
#include <stdint.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882
#define YM_CLOCK 1000000.0

static double countdown[3] = {0, 0, 0};
static int16_t out_state[3] = {1, 1, 1};

/* Envelope State */
static double env_countdown = 0;
static int32_t env_level = 31;     /* Start at max volume */
static int8_t env_holding = 0;

void fill_buffer_with_ym(unsigned char *regs, int16_t *buffer) {
    uint16_t periods[3];
    periods[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    periods[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    periods[2] = regs[4] | ((regs[5] & 0x0F) << 8);

    uint16_t env_period = regs[11] | (regs[12] << 8);
    uint8_t shape = regs[13] & 0x0F;

    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        /* 1. Update Envelope */
        double env_step_ticks = (env_period < 1) ? 1.0 : (double)env_period * 256.0;
        
        if (!env_holding) {
            env_countdown -= ticks_per_sample;
            while (env_countdown <= 0) {
                env_countdown += env_step_ticks;
                env_level--; 
                if (env_level <= 0) {
                    env_level = 0;
                    env_holding = 1; // Stop at silence for shape 0x08
                }
            }
        }

        /* 2. Mix Channels */
        int32_t mixed_sample = 0;
        for (int ch = 0; ch < 3; ch++) {
            uint8_t v_reg = regs[8 + ch];
            int16_t current_vol;

            // Use envelope if bit 4 is set
            if (v_reg & 0x10) {
                current_vol = env_level * 800; // Scaled for 0-31
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

    // Note Setup (Middle C approx)
    ym_regs[0] = 0xC6; ym_regs[1] = 0x01; 
    
    // Enable Envelope on Channel A
    ym_regs[8] = 0x10; 

    // Envelope Period: 244 (0x00F4) for ~2s decay on 1MHz clock
    ym_regs[11] = 0xF4; 
    ym_regs[12] = 0x00; 

    // Shape 0x08: Start High, Decay to Low, then Hold
    ym_regs[13] = 0x08; 

    printf("Playing 2-second fade... Ctrl+C to stop.\n");

    while (1) {
        fill_buffer_with_ym(ym_regs, audio_buffer);
        if (fwrite(audio_buffer, sizeof(int16_t), SAMPLES_PER_FRAME, audio_pipe) < SAMPLES_PER_FRAME) break;
        fflush(audio_pipe);
    }

    pclose(audio_pipe);
    return 0;
}
