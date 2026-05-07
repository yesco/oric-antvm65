#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882
#define YM_CLOCK 1000000.0

static const int16_t YM_VOL_TABLE[16] = {
    0, 175, 250, 360, 520, 750, 1080, 1550, 2250, 3250, 4700, 6800, 9800, 14200, 20500, 29000
};

/* Global Synthesis State */
static double countdown[3] = {0,0,0};
static int16_t out_state[3] = {1, 1, 1};
static uint32_t noise_rng = 1; 
static double noise_countdown = 0;
static int16_t noise_state = 1;

/* Envelope State */
static double env_countdown = 0;
static int32_t env_level = 0;
static int8_t env_holding = 1;

void fill_buffer_with_ym(unsigned char *regs, int16_t *buffer) {
    uint16_t periods[3];
    periods[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    periods[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    periods[2] = regs[4] | ((regs[5] & 0x0F) << 8);

    uint16_t env_period = regs[11] | (regs[12] << 8);
    uint8_t shape = regs[13] & 0x0F;
    uint8_t mixer = regs[7];
    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        /* 1. Envelope Engine */
        if (!env_holding) {
            double env_step_ticks = (env_period < 1) ? 256.0 : (double)env_period * 256.0;
            env_countdown -= ticks_per_sample;
            while (env_countdown <= 0) {
                env_countdown += env_step_ticks;
                env_level--;
                if (env_level < 0) {
                    env_level = 0;
                    env_holding = 1; // Single decay (simplified for drums)
                }
            }
        }

        /* 2. Noise Engine */
        double n_eff_p = (regs[6] < 1) ? 16.0 : (double)regs[6] * 16.0;
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += n_eff_p;
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 3)) & 1) << 16);
            noise_state = (noise_rng & 1) ? 1 : -1;
        }

        /* 3. Tone Mixing */
        int32_t mixed_sample = 0;
        for (int ch = 0; ch < 3; ch++) {
            if (periods[ch] > 0) {
                countdown[ch] -= ticks_per_sample;
                while (countdown[ch] <= 0) {
                    countdown[ch] += (double)periods[ch] * 16.0;
                    out_state[ch] = -out_state[ch];
                }
            }

            // Determine volume for this channel
            int32_t vol;
            if (regs[8+ch] & 0x10) {
                // Use Envelope: Map 0-31 to 0-32767
                vol = (env_level * 1000); 
            } else {
                vol = YM_VOL_TABLE[regs[8+ch] & 0x0F];
            }

            int tone_en = !(mixer & (1 << ch));
            int noise_en = !(mixer & (1 << (ch + 3)));
            int16_t sig = 0;
            if (tone_en && noise_en) sig = (out_state[ch] > 0 && noise_state > 0) ? 1 : -1;
            else if (tone_en)        sig = (out_state[ch] > 0) ? 1 : -1;
            else if (noise_en)       sig = (noise_state > 0) ? 1 : -1;
            
            mixed_sample += (sig * vol);
        }
        buffer[i] = (int16_t)(mixed_sample > 32767 ? 32767 : (mixed_sample < -32768 ? -32768 : mixed_sample));
    }
}

int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    unsigned char r[14];
    int16_t buf[SAMPLES_PER_FRAME];
    int frame = 0, prog = 0;
    uint16_t scale[] = {478, 426, 379, 358, 319, 284, 268, 253};

    while (1) {
        for(int i=0; i<14; i++) r[i] = 0;
        r[7] = 0x3F; // Mixer OFF
        
        int step = frame % 32; 
        if (frame % 128 == 0) prog = rand() % 8;

        // BASS (Ch B)
        uint16_t pB = scale[prog % 8] * 2;
        r[2] = pB & 0xFF; r[3] = pB >> 8;
        r[9] = 10; r[7] &= ~(1 << 1);

        // SKANK (Ch A)
        if ((step >= 8 && step <= 10) || (step >= 24 && step <= 26)) {
            uint16_t pA = scale[prog % 8];
            r[0] = pA & 0xFF; r[1] = pA >> 8;
            r[8] = 12; r[7] &= ~(1 << 0);
        }

        // ENVELOPE DRUMS (Ch C)
        if (step == 16) {
            // Trigger Kick Drum
            r[4] = 0xA0; r[5] = 0x0F; // Low thump period
            r[6] = 25;                // Noise "crack"
            r[11] = 0x80; r[12] = 0x05; // Envelope speed (~0.3s)
            r[13] = 0x00;             // Shape: Single Decay
            r[10] = 0x10;             // USE ENVELOPE
            r[7] &= ~0x24;            // Enable Tone + Noise
            
            // Internal trigger for our synth engine
            env_level = 31; env_holding = 0; env_countdown = 0;
        }

        fill_buffer_with_ym(r, buf);
        fwrite(buf, 2, SAMPLES_PER_FRAME, audio_pipe);
        fflush(audio_pipe);
        frame++;
        usleep(20000);
    }
    return 0;
}
