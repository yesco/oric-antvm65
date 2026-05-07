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
        // 1. Noise Gen
        double n_eff_p = (noise_per < 1) ? 16.0 : (double)noise_per * 16.0;
        noise_countdown -= ticks_per_sample;
        while (noise_countdown <= 0) {
            noise_countdown += n_eff_p;
            noise_rng = (noise_rng >> 1) | (((noise_rng ^ (noise_rng >> 3)) & 1) << 16);
            noise_state = (noise_rng & 1) ? 1 : -1;
        }

        // 2. Tone Gen & Simple Additive Mix
        int32_t mixed_sample = 0;
        for (int ch = 0; ch < 3; ch++) {
            // Update Tone
            double t_eff_p = (double)periods[ch] * 16.0;
            if (periods[ch] > 0) {
                countdown[ch] -= ticks_per_sample;
                while (countdown[ch] <= 0) {
                    countdown[ch] += t_eff_p;
                    out_state[ch] = -out_state[ch];
                }
            }

            // Simple additive logic: 
            // If bit is 0, channel is ON. We check Tone bit (0-2) and Noise bit (3-5).
            int tone_en = !(mixer & (1 << ch));
            int noise_en = !(mixer & (1 << (ch + 3)));
            
            int16_t val = 0;
            if (tone_en && noise_en) val = (out_state[ch] > 0 && noise_state > 0) ? 1 : -1;
            else if (tone_en)        val = (out_state[ch] > 0) ? 1 : -1;
            else if (noise_en)       val = (noise_state > 0) ? 1 : -1;

            if (val != 0) mixed_sample += (val * YM_VOL_TABLE[regs[8 + ch] & 0x0F]);
        }

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

    while (1) {
        // Reg 7: 0x3F = All Off, 0x3E = Tone A On, 0x3D = Tone B On, etc.
        r[7] = 0x3F; 

        // Lead (A)
        uint16_t pA = melody[(frame/10)%8];
        r[0] = pA & 0xFF; r[1] = pA >> 8;
        r[8] = 12; r[7] &= ~(1 << 0);

        // Sub (B)
        uint16_t pB = 638;
        r[2] = pB & 0xFF; r[3] = pB >> 8;
        r[9] = 8; r[7] &= ~(1 << 1);

        // Beat (C)
        if (frame % 20 == 0) { // Kick
            r[4] = 180; r[5] = 1; r[10] = 15; r[7] &= ~(1 << 2);
        } else if (frame % 20 == 10) { // Snare
            r[6] = 20; r[10] = 10; r[7] &= ~(1 << 5);
        } else {
            r[10] = 0;
        }

        fill_buffer_with_ym(r, buf);
        fwrite(buf, 2, SAMPLES_PER_FRAME, audio_pipe);
        fflush(audio_pipe);
        
        frame++;
        usleep(20000); // Maintain 50Hz timing
    }
    return 0;
}
