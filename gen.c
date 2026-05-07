#include <stdio.h>
#include <stdint.h>
#include <unistd.h>

/* Oric Atmos Specs */
#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882   /* 44100Hz / 50Hz */
#define YM_CLOCK 1000000.0      /* 1 MHz */

/* Audio State */
static double countdown_a = 0;
static int16_t output_state_a = 1;

/**
 * Synthesizes 1/50s of audio for Channel A.
 * Mimics YM2149 latching: the period is reloaded only when the counter expires.
 */
void fill_buffer_from_ym(unsigned char *regs, int16_t *buffer) {
    /* Extract 12-bit period: Reg 0 (fine) + Reg 1 (coarse, 4 bits) */
    uint16_t period = regs[0] | ((regs[1] & 0x0F) << 8);
    
    /* Extract Volume: Reg 8 (4 bits) */
    int16_t amplitude = (regs[8] & 0x0F) * 1500; 

    /* Internal YM divider: Tone freq = Clock / (16 * Period) */
    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;
    double effective_period = (period < 1) ? 1 : (double)period * 16.0;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        if (amplitude == 0) {
            buffer[i] = 0;
            continue;
        }

        countdown_a -= ticks_per_sample;
        
        while (countdown_a <= 0) {
            /* Latch the period and flip the state */
            countdown_a += effective_period;
            output_state_a = -output_state_a;
        }

        buffer[i] = (output_state_a > 0) ? amplitude : -amplitude;
    }
}

int main() {
    /* Open pipe to PulseAudio (standard in Termux) */
    /* --latency-msec=20 ensures we stay close to the 50Hz frame rate */
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    
    if (!audio_pipe) {
        fprintf(stderr, "Error: Could not open audio pipe. Is pulseaudio running?\n");
        return 1;
    }

    unsigned char ym_regs[14];
    int16_t audio_buffer[SAMPLES_PER_FRAME];

    /* 
       Reads 14 bytes at a time from stdin. 
       This assumes your 'autoframe' filter is outputting raw binary bytes.
    */
    while (fread(ym_regs, 1, 14, stdin) == 14) {
        
        fill_buffer_from_ym(ym_regs, audio_buffer);

        if (fwrite(audio_buffer, sizeof(int16_t), SAMPLES_PER_FRAME, audio_pipe) < SAMPLES_PER_FRAME) {
            break; 
        }
        
        /* Push the frame to the sound server immediately */
        fflush(audio_pipe);
    }

    pclose(audio_pipe);
    return 0;
}
