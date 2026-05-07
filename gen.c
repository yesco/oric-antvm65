#include <stdio.h>
#include <stdint.h>

/* Oric Atmos Specs */
#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882   /* 44100Hz / 50Hz */
#define YM_CLOCK 1000000.0      /* 1 MHz */

/* Oscillator States for 3 Channels */
static double countdown[3] = {0, 0, 0};
static int16_t out_state[3] = {1, 1, 1};

/* Noise Generator State */
static uint32_t noise_rng = 1; 
static double noise_countdown = 0;
static int16_t noise_state = 1;

void fill_buffer_with_ym(unsigned char *regs, int16_t *buffer) {
    uint16_t periods[3];
    periods[0] = regs[0] | ((regs[1] & 0x0F) << 8);
    periods[1] = regs[2] | ((regs[3] & 0x0F) << 8);
    periods[2] = regs[4] | ((regs[5] & 0x0F) << 8);

    uint8_t noise_per = regs[6] & 0x1F;
    uint8_t mixer = regs[7]; // Bits: 5-3 Noise (CBA), 2-0 Tone (CBA). 0 = ON.
    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        /* 1. Update Noise Generator */
        double n_eff_p = (noise_per < 1) ? 1.0 : (double)noise_per * 16.0;
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += n_eff_p;
            // Simple LFSR for noise
            if (((noise_rng & 1) ^ ((noise_rng >> 3) & 1))) noise_state = -noise_state;
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 1)) & 1) << 16);
        }

        /* 2. Update Tones and Mix */
        int32_t mixed_sample = 0;
        for (int ch = 0; ch < 3; ch++) {
            int16_t vol = (regs[8 + ch] & 0x0F) * 1200;
            double t_eff_p = (double)periods[ch] * 16.0;
            
            // Tone generator
            if (periods[ch] > 0) {
                countdown[ch] -= ticks_per_sample;
                while (countdown[ch] <= 0) {
                    countdown[ch] += t_eff_p;
                    out_state[ch] = -out_state[ch];
                }
            }

            // Logic: bit=0 means ENABLED. 
            // Result = (Tone OR Tone_Disabled) AND (Noise OR Noise_Disabled)
            int tone_out = (mixer & (1 << ch)) ? 1 : (out_state[ch] > 0);
            int noise_out = (mixer & (1 << (ch + 3))) ? 1 : (noise_state > 0);
            
            if (tone_out && noise_out) mixed_sample += vol;
            else mixed_sample -= vol;
        }

        /* Clipping */
        if (mixed_sample > 32767) mixed_sample = 32767;
        if (mixed_sample < -32768) mixed_sample = -32768;
        buffer[i] = (int16_t)mixed_sample;
    }
}

int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    if (!audio_pipe) return 1;

    unsigned char r[14] = {0};
    int16_t buf[SAMPLES_PER_FRAME];
    int frame = 0;
    uint16_t melody[] = {478, 426, 379, 319, 478, 426, 379, 284};

    printf("Playing Oric-style loop... Ctrl+C to stop.\n");

    while (1) {
        // Clear mixer (all off = 1)
        r[7] = 0b00111111; 

        // Lead Melody Ch A
        uint16_t pA = melody[(frame/15)%8];
        r[0] = pA & 0xFF; r[1] = pA >> 8;
        r[8] = 10;
        r[7] &= ~(1 << 0); // Enable Tone A

        // Harmonic Ch B
        uint16_t pB = 638;
        r[2] = pB & 0xFF; r[3] = pB >> 8;
        r[9] = 7;
        r[7] &= ~(1 << 1); // Enable Tone B

        // Snare Beat on Ch C
        if (frame % 20 < 2) {
            r[6] = 25;         // Noise Pitch
            r[10] = 12;        // Vol
            r[7] &= ~(1 << 5); // Enable Noise C
        } else {
            r[10] = 0;
        }

        fill_buffer_with_ym(r, buf);
        fwrite(buf, sizeof(int16_t), SAMPLES_PER_FRAME, audio_pipe);
        fflush(audio_pipe);
        
        frame++;
        // Optional: usleep(20000); // Only if not driven by an external stream
    }

    pclose(audio_pipe);
    return 0;
}
