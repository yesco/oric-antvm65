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
    uint8_t mixer = regs[7];
    double ticks_per_sample = YM_CLOCK / SAMPLE_RATE;

    for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
        // 1. Envelope (Drum Decay)
        if (!env_holding) {
            double env_step_ticks = (env_period < 1) ? 256.0 : (double)env_period * 256.0;
            env_countdown -= ticks_per_sample;
            while (env_countdown <= 0) {
                env_countdown += env_step_ticks;
                if (--env_level < 0) { env_level = 0; env_holding = 1; }
            }
        }
        // 2. Noise
        double n_eff_p = (regs[6] < 1) ? 16.0 : (double)regs[6] * 16.0;
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += n_eff_p;
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 3)) & 1) << 16);
            noise_state = (noise_rng & 1) ? 1 : -1;
        }
        // 3. Mix
        int32_t mixed = 0;
        for (int ch = 0; ch < 3; ch++) {
            if (periods[ch] > 0) {
                countdown[ch] -= ticks_per_sample;
                while (countdown[ch] <= 0) {
                    countdown[ch] += (double)periods[ch] * 16.0;
                    out_state[ch] = -out_state[ch];
                }
            }
            int32_t vol = (regs[8+ch] & 0x10) ? (env_level * 900) : YM_VOL_TABLE[regs[8+ch] & 0x0F];
            int t_on = !(mixer & (1 << ch)), n_on = !(mixer & (1 << (ch + 3)));
            int16_t sig = (t_on && n_on) ? (out_state[ch] > 0 && noise_state > 0 ? 1 : -1) :
                          (t_on ? (out_state[ch] > 0 ? 1 : -1) : (n_on ? (noise_state > 0 ? 1 : -1) : 0));
            mixed += (sig * vol);
        }
        buffer[i] = (int16_t)(mixed > 32767 ? 32767 : (mixed < -32768 ? -32768 : mixed));
    }
}

int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    unsigned char r[14];
    int16_t buf[SAMPLES_PER_FRAME];
    int frame = 0, prog = 0;
    // C-Pentatonic: C, D, E, G, A
    uint16_t mel[] = {478, 426, 379, 319, 284};

    while (1) {
        for(int i=0; i<14; i++) r[i] = 0;
        r[7] = 0x3F;
        int step = frame % 32;
        if (frame % 128 == 0) prog = rand() % 5;

        // BASS (Ch B): Walking Reggae Line
        int b_step = (step / 8);
        uint16_t pB = (b_step == 0) ? 0 : (mel[(prog + b_step) % 5] * 2);
        if(pB > 0) { r[2] = pB & 0xFF; r[3] = pB >> 8; r[9] = 11; r[7] &= ~(1 << 1); }

        // LEAD SKANK (Ch A): Off-beats
        if (step == 8 || step == 24) {
            uint16_t pA = mel[prog];
            r[0] = pA & 0xFF; r[1] = pA >> 8; r[8] = 13; r[7] &= ~(1 << 0);
        }

        // DRUMS (Ch C): The One Drop (Step 16)
        if (step == 16) {
            r[4] = 0x00; r[5] = 0x06; // Deep Kick
            r[6] = 22;               // Snare Crispness
            r[11] = 0x00; r[12] = 0x0A; // Longer Decay (~0.5s)
            r[13] = 0x00; r[10] = 0x10; // Use Env
            r[7] &= ~0x24;           // Tone + Noise
            env_level = 31; env_holding = 0;
        }

        fill_buffer_with_ym(r, buf);
        fwrite(buf, 2, SAMPLES_PER_FRAME, audio_pipe);
        fflush(audio_pipe);
        frame++;
        usleep(20000);
    }
    return 0;
}
