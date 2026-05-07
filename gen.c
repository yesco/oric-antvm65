#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>
#include <math.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882
#define YM_CLOCK 1000000.0
#define DELAY_FRAMES 12 // Slightly longer echo for better dub feel

static const int16_t YM_VOL_TABLE[] = {
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
        if (!env_holding) {
            double env_step_ticks = (env_period < 1) ? 256.0 : (double)env_period * 256.0;
            static double env_sub = 0;
            env_sub -= ticks_per_sample;
            while (env_sub <= 0) {
                env_sub += env_step_ticks;
                if (--env_level < 0) { env_level = 0; env_holding = 1; }
            }
        }
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += (regs[6] < 1 ? 16.0 : (double)regs[6] * 16.0);
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 3)) & 1) << 16);
            noise_state = (noise_rng & 1) ? 1 : -1;
        }
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
    // Open the pipe with a small latency to let PulseAudio handle the timing
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=40", "w");
    if (!audio_pipe) return 1;

    unsigned char r[14];
    int16_t buf[SAMPLES_PER_FRAME];
    int frame = 0, prog = 0, durA = 0, durB = 0;
    
    uint16_t echo_pitch[DELAY_FRAMES] = {0};
    uint8_t  echo_vol[DELAY_FRAMES]   = {0};
    int echo_ptr = 0;

    uint16_t scale_high[] = {239, 213, 190, 159, 142}; 
    uint16_t scale_mid[]  = {478, 426, 379, 319, 284}; 

    while (1) {
        for(int i=0; i<14; i++) r[i] = 0;
        r[7] = 0x3F;
        int step = frame % 64;
        if (frame % 256 == 0) prog = rand() % 5;

        // --- RHYTHM CHORD B ---
        if (step == 0 || step == 32) durB = 16; 
        
        uint16_t current_pB = 0;
        uint8_t current_vB = 0;

        if (durB > 0) {
            current_pB = scale_high[prog];
            current_vB = (step < 32) ? 14 : 10;
            durB--;
        }

        // Echo Logic
        uint16_t out_pB = current_pB;
        uint8_t  out_vB = current_vB;

        if (out_vB == 0 && echo_vol[echo_ptr] > 0) {
            out_pB = echo_pitch[echo_ptr];
            out_vB = echo_vol[echo_ptr] > 4 ? echo_vol[echo_ptr] - 4 : 0;
        }

        echo_pitch[echo_ptr] = current_pB;
        echo_vol[echo_ptr] = current_vB;
        echo_ptr = (echo_ptr + 1) % DELAY_FRAMES;

        if (out_vB > 0) {
            r[2] = out_pB & 0xFF; r[3] = out_pB >> 8;
            r[9] = out_vB;
            r[7] &= ~(1 << 1);
        }

        // --- LEAD A ---
        if (step == 8 || step == 12 || step == 24 || step == 48) durA = 6;
        if (durA > 0) {
            uint16_t pA = scale_mid[prog];
            if (durA > 4) pA += (int)(4.0 * sin(frame * 0.6));
            r[0] = pA & 0xFF; r[1] = pA >> 8;
            r[8] = 13; r[7] &= ~(1 << 0);
            durA--;
        }

        // --- DRUMS C ---
        if (step % 16 == 0) { r[6] = 2; r[10] = 12; r[7] &= ~(1 << 5); } 
        if (step == 32) {
            r[4] = 0x00; r[5] = 0x08; r[6] = 12;
            r[11] = 0x00; r[12] = 0x08; r[13] = 0x00;
            r[10] = 0x10; r[7] &= ~0x24; 
            env_level = 31; env_holding = 0;
        }

        fill_buffer_with_ym(r, buf);
        
        // fwrite is a blocking call when the pipe buffer is full.
        // This ensures the code only runs exactly as fast as the sound card plays.
        if (fwrite(buf, sizeof(int16_t), SAMPLES_PER_FRAME, audio_pipe) < SAMPLES_PER_FRAME) break;
        fflush(audio_pipe);
        
        frame++;
        // No usleep() here! Timing is now hardware-driven.
    }
    pclose(audio_pipe);
    return 0;
}
