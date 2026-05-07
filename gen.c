#include <stdio.h>
#include <stdint.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882
#define YM_CLOCK 1000000.0

static double countdown[3] = {0, 0, 0};
static int16_t out_state[3] = {1, 1, 1};
static uint32_t noise_rng = 1; 
static double noise_countdown = 0;
static int16_t noise_state = 1;

void fill_buffer_with_ym(unsigned char *regs, int16_t *buffer) {
    uint16_t periods[3];
    periods[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    periods[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    periods[2] = regs[4] | ((regs[5] & 0x0F) << 8);

    uint8_t noise_per = regs[6] & 0x1F;
    uint8_t mixer = regs[7]; 
    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        // 1. Noise Generator
        double n_eff_p = (noise_per < 1) ? 1.0 : (double)noise_per * 16.0;
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += n_eff_p;
            if (((noise_rng & 1) ^ ((noise_rng >> 3) & 1))) noise_state = -noise_state;
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 1)) & 1) << 16);
        }

        // 2. Tones and Mix
        int32_t mixed_sample = 0;
        for (int ch = 0; ch < 3; ch++) {
            int16_t vol = (regs[8 + ch] & 0x0F) * 1200;
            double t_eff_p = (double)periods[ch] * 16.0;
            
            if (periods[ch] > 0) {
                countdown[ch] -= ticks_per_sample;
                while (countdown[ch] <= 0) {
                    countdown[ch] += t_eff_p;
                    out_state[ch] = -out_state[ch];
                }
            }

            int tone_out = (mixer & (1 << ch)) ? 1 : (out_state[ch] > 0);
            int noise_out = (mixer & (1 << (ch + 3))) ? 1 : (noise_state > 0);
            
            if (tone_out && noise_out) mixed_sample += vol;
            else mixed_sample -= vol;
        }

        if (mixed_sample > 32000) mixed_sample = 32000;
        if (mixed_sample < -32000) mixed_sample = -32000;
        buffer[i] = (int16_t)mixed_sample;
    }
}

int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    unsigned char r[14] = {0};
    int16_t buf[SAMPLES_PER_FRAME];
    int frame = 0;
    uint16_t melody[] = {478, 426, 379, 319, 478, 426, 379, 284};
    int kick_timer = 0;

    while (1) {
        r[7] = 0b00111111; // All off (bits 0-5 = 1)

        // Lead Melody (Ch A)
        uint16_t pA = melody[(frame/12)%8];
        r[0] = pA & 0xFF; r[1] = pA >> 8;
        r[8] = 10; r[7] &= ~(1 << 0);

        // Harmonic (Ch B)
        uint16_t pB = 638;
        r[2] = pB & 0xFF; r[3] = pB >> 8;
        r[9] = 6; r[7] &= ~(1 << 1);

        // Kick Drum (Ch C) - Every 40 frames
        if (frame % 40 == 0) kick_timer = 6; // Trigger 6-frame slide
        if (kick_timer > 0) {
            uint16_t kick_p = 200 + (6 - kick_timer) * 300; // Slide from low to high period
            r[4] = kick_p & 0xFF; r[5] = kick_p >> 8;
            r[10] = 15; r[7] &= ~(1 << 2);
            kick_timer--;
        }

        // Snare (Ch C Noise) - Every 40 frames, offset by 20
        if (frame % 40 == 20) {
            r[6] = 20; r[10] = 12; r[7] &= ~(1 << 5);
        }

        fill_buffer_with_ym(r, buf);
        fwrite(buf, 2, SAMPLES_PER_FRAME, audio_pipe);
        fflush(audio_pipe);
        frame++;
    }
    return 0;
}
