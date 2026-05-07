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
        // 1. Envelope Decay
        if (!env_holding) {
            double env_step_ticks = (env_period < 1) ? 256.0 : (double)env_period * 256.0;
            static double env_sub = 0;
            env_sub -= ticks_per_sample;
            while (env_sub <= 0) {
                env_sub += env_step_ticks;
                if (--env_level < 0) { env_level = 0; env_holding = 1; }
            }
        }
        // 2. Noise Engine
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += (regs[6] < 1 ? 16.0 : (double)regs[6] * 16.0);
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 3)) & 1) << 16);
            noise_state = (noise_rng & 1) ? 1 : -1;
        }
        // 3. Mixing
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
            int16_t sig = 0;
            if (t_on && n_on) sig = (out_state[ch] > 0 && noise_state > 0) ? 1 : -1;
            else if (t_on)    sig = (out_state[ch] > 0) ? 1 : -1;
            else if (n_on)    sig = (noise_state > 0) ? 1 : -1;
            mixed += (sig * vol);
        }
        buffer[i] = (int16_t)(mixed > 32767 ? 32767 : (mixed < -32768 ? -32768 : mixed));
    }
}

int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    unsigned char r[14];
    int16_t buf[SAMPLES_PER_FRAME];
    int frame = 0, prog = 0, durA = 0, durB = 0;
    uint16_t mel[] = {478, 426, 379, 319, 284};

    while (1) {
        for(int i=0; i<14; i++) r[i] = 0;
        r[7] = 0x3F; // Mixer Off
        
        int step = frame % 64;
        if (frame % 256 == 0) prog = rand() % 5;

        // BASS (B) Sustain
        if (step == 16 || step == 32 || step == 56) durB = 8;
        if (durB > 0) {
            uint16_t pB = mel[prog] * 2;
            r[2] = pB & 0xFF; r[3] = pB >> 8; r[9] = 11; r[7] &= ~(1 << 1);
            durB--;
        }

        // LEAD SKANK (A) Sustain
        if (step == 8 || step == 24 || step == 40) durA = 6;
        if (durA > 0) {
            uint16_t pA = mel[prog];
            r[0] = pA & 0xFF; r[1] = pA >> 8; r[8] = 12; r[7] &= ~(1 << 0);
            durA--;
        }

        // CHUGGA-CHICK (C)
        if (step % 8 == 0) { r[6] = 28; r[10] = 7; r[7] &= ~(1 << 5); }
        if (step == 32) {
            r[4] = 0x00; r[5] = 0x08; // Kick
            r[6] = 12; r[11] = 0x00; r[12] = 0x08; // Snare/Env
            r[10] = 0x10; r[7] &= ~0x24; // Env + Tone + Noise
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
