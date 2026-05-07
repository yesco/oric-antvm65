#include <stdio.h>
#include <stdint.h>
#include <unistd.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882
#define YM_CLOCK 1000000.0

static const int16_t YM_VOL_TABLE[16] = {
    0, 175, 250, 360, 520, 750, 1080, 1550, 
    2250, 3250, 4700, 6800, 9800, 14200, 20500, 29000
};

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
        double n_eff_p = (noise_per < 1) ? 16.0 : (double)noise_per * 16.0;
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += n_eff_p;
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 3)) & 1) << 16);
            noise_state = (noise_rng & 1) ? 1 : -1;
        }

        // 2. Additive Mixer
        int32_t mixed_sample = 0;
        for (int ch = 0; ch < 3; ch++) {
            double t_eff_p = (double)periods[ch] * 16.0;
            if (periods[ch] > 0) {
                countdown[ch] -= ticks_per_sample;
                while (countdown[ch] <= 0) {
                    countdown[ch] += t_eff_p;
                    out_state[ch] = -out_state[ch];
                }
            }

            int tone_en = !(mixer & (1 << ch));
            int noise_en = !(mixer & (1 << (ch + 3)));
            int16_t val = 0;
            
            if (tone_en && noise_en) val = (out_state[ch] > 0 && noise_state > 0) ? 1 : -1;
            else if (tone_en)        val = (out_state[ch] > 0) ? 1 : -1;
            else if (noise_en)       val = (noise_state > 0) ? 1 : -1;

            if (val != 0) mixed_sample += (val * YM_VOL_TABLE[regs[8 + ch] & 0x0F]);
        }
        
        // Simple Low-pass to reduce "whine"
        if (mixed_sample > 32767) mixed_sample = 32767;
        if (mixed_sample < -32768) mixed_sample = -32768;
        buffer[i] = (int16_t)mixed_sample;
    }
}

int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    unsigned char r[14] = {0};
    int16_t buf[SAMPLES_PER_FRAME];
    int frame = 0;

    // Reggae Chords (C Major, G Major)
    uint16_t chords[2][2] = {{478, 379}, {638, 506}}; 
    
    printf("Playing One-Drop Reggae... Ctrl+C to stop.\n");

    while (1) {
        r[7] = 0x3F; // Reset mixer (All OFF)
        int step = frame % 32; // 32-frame loop

        // --- Lead Stabs (Off-beat: frames 8-10 and 24-26) ---
        if ((step >= 8 && step <= 10) || (step >= 24 && step <= 26)) {
            int chord_idx = (frame / 64) % 2;
            r[0] = chords[chord_idx][0] & 0xFF; r[1] = chords[chord_idx][0] >> 8;
            r[2] = chords[chord_idx][1] & 0xFF; r[3] = chords[chord_idx][1] >> 8;
            r[8] = 12; r[9] = 10;
            r[7] &= ~0x03; // Enable Tone A and B
        } else {
            r[8] = 0; r[9] = 0;
        }

        // --- The "One Drop" (Drum + Snare on frame 16) ---
        if (step >= 16 && step <= 18) {
            // Kick Drum (Tone slide)
            uint16_t kick_p = 400 + (step - 16) * 400;
            r[4] = kick_p & 0xFF; r[5] = kick_p >> 8;
            // Snare (Noise)
            r[6] = 22; 
            r[10] = 15;
            r[7] &= ~0x24; // Enable Tone C (Kick) and Noise C (Snare)
        } else {
            r[10] = 0;
        }

        fill_buffer_with_ym(r, buf);
        fwrite(buf, 2, SAMPLES_PER_FRAME, audio_pipe);
        fflush(audio_pipe);
        frame++;
        usleep(20000);
    }
    pclose(audio_pipe);
    return 0;
}
