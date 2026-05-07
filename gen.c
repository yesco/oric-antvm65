#include <stdio.h>
#include <stdint.h>

/* Oric Atmos Specs */
#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882   /* 44100Hz / 50Hz */
#define YM_CLOCK 1000000.0      /* 1 MHz */

/* Oscillator States for 3 Channels */
static double countdown[3] = {0, 0, 0};
static int16_t out_state[3] = {1, 1, 1};

/**
 * Synthesizes 1/50s of audio for 3 channels and mixes them.
 */
void fill_buffer_with_chord(unsigned char *regs, int16_t *buffer) {
    /* 1. Extract 12-bit periods for A, B, and C */
    uint16_t periods[3];
    periods[0] = regs[0] | ((regs[1] & 0x0F) << 8); // Ch A
    periods[1] = regs[2] | ((regs[3] & 0x0F) << 8); // Ch B
    periods[2] = regs[4] | ((regs[5] & 0x0F) << 8); // Ch C
    
    /* 2. Extract Volumes (Regs 8, 9, 10) */
    int16_t volumes[3];
    volumes[0] = (regs[8] & 0x0F) * 1000;
    volumes[1] = (regs[9] & 0x0F) * 1000;
    volumes[2] = (regs[10] & 0x0F) * 1000;

    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        int32_t mixed_sample = 0;

        for (int ch = 0; ch < 3; ch++) {
            if (volumes[ch] == 0 || periods[ch] < 1) continue;

            double effective_period = (double)periods[ch] * 16.0;
            countdown[ch] -= ticks_per_sample;
            
            while (countdown[ch] <= 0) {
                countdown[ch] += effective_period;
                out_state[ch] = -out_state[ch];
            }
            
            // Add channel output to the mix
            mixed_sample += (out_state[ch] > 0) ? volumes[ch] : -volumes[ch];
        }

        /* 3. Simple Clipping/Clamping to prevent 16-bit overflow */
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

    /* Setup a Test Chord (C Major-ish) */
    // Channel A: Period 478 (~130Hz) Vol 8
    ym_regs[0] = 478 & 0xFF; ym_regs[1] = (478 >> 8); ym_regs[8] = 8;
    // Channel B: Period 379 (~165Hz) Vol 8
    ym_regs[2] = 379 & 0xFF; ym_regs[3] = (379 >> 8); ym_regs[9] = 8;
    // Channel C: Period 319 (~196Hz) Vol 8
    ym_regs[4] = 319 & 0xFF; ym_regs[5] = (319 >> 8); ym_regs[10] = 8;

    printf("Playing mixed A+B+C chord. Ctrl+C to stop.\n");

    while (1) {
        fill_buffer_with_chord(ym_regs, audio_buffer);
        if (fwrite(audio_buffer, sizeof(int16_t), SAMPLES_PER_FRAME, audio_pipe) < SAMPLES_PER_FRAME) break;
        fflush(audio_pipe);
    }

    pclose(audio_pipe);
    return 0;
}
