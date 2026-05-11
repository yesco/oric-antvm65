#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>
#include <math.h>

#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME 882
#define YM_CLOCK 1000000.0

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

int frame = 0;

// Song1 state and data

uint16_t scale_high[] = {239, 213, 190, 159, 142}; 
uint16_t scale_mid[]  = {478, 426, 379, 319, 284}; 

int prog = 0, leadStyle = 0, rhythmStyle = 0, durA = 0, durB = 0;
int octShiftA = 0, octShiftB = 0, trans = 0;

uint16_t pA_base = 0;


void do_song1_tick(char* r) {
  if (frame % 512 == 1) trans = 0; // Clear transition flag after reset

  r[7] = 0x3F;
  int step = frame % 64;
  int bar = (frame / 64) % 4;
        
  // Every 512 frames: Change Progression and Potentially Shift
  if (frame % 512 == 0) {
    prog = rand() % 5;
    leadStyle = (rand() % 10 < 8) ? 0 : (rand() % 3);
    rhythmStyle = rand() % 3;

    // Decoupled Shift: If a transition just finished, force a change in both
    if (trans > 0) {
      octShiftA = (rand() % 5) - 2;
      octShiftB = (rand() % 5) - 2;
      printf("[BLOCK RESET - TRANS] Both Shifts Updated! ");
    } else if (rand() % 3 < 2) {
      // Normal logic: only change one at a time
      if (rand() % 2 == 0) octShiftA = (rand() % 5) - 2;
      else octShiftB = (rand() % 5) - 2;
    }

    printf("[BLOCK] Prog:%d LStyle:%d RStyle:%d ShiftA:%d ShiftB:%d\n", 
	   prog, leadStyle, rhythmStyle, octShiftA, octShiftB);
  }

  if (frame % 256 == 0 && frame % 512 != 0) {
    trans = (rand() % 4 == 0) ? (rand() % 5 + 1) : 0;
    if (trans > 0) printf("  -> Transition Triggered: Type %d (Shifts will rotate next block)\n", trans);
  }

  int mute_melody = (bar == 3 && (trans == 2 || trans == 4 || trans == 5));

  // --- B Rhythm ---
  if (!mute_melody) {
    if (step == 0 || step == 32) durB = 12;
    else if (rhythmStyle == 1 && (step == 4 || step == 36)) durB = 4;
    else if (rhythmStyle == 2 && step == 48) durB = 10;

    if (durB > 0) {
      uint16_t pB = scale_high[prog];
      if (octShiftB > 0) pB <<= octShiftB; else if (octShiftB < 0) pB >>= (-octShiftB);
      if (pB < 1) pB = 1;
      r[2] = pB & 0xFF; r[3] = (pB >> 8) & 0x0F;
      r[9] = (step < 32) ? 14 : 10; r[7] &= ~(1 << 1);
      durB--;
    }
  }

  // --- A Lead ---
  if (!mute_melody) {
    int trigger = 0, offset = 0;
    if (leadStyle == 0 && (step == 8 || step == 12 || step == 24 || step == 48)) { trigger = 1; durA = 6; }
    else if (leadStyle == 1 && (step % 12 == 4)) { trigger = 1; durA = 4; offset = (step/12); }
    else if (leadStyle == 2 && (step == 10 || step == 26)) { trigger = 1; durA = 12; offset = 1; }

    if (trigger) pA_base = scale_mid[(prog + offset) % 5];
    if (durA > 0) {
      uint16_t pA = pA_base;
      if (octShiftA > 0) pA <<= octShiftA; else if (octShiftA < 0) pA >>= (-octShiftA);
      if (pA < 1) pA = 1;
      pA += (int)(6.0 * sin(frame * 0.55));
      r[0] = pA & 0xFF; r[1] = (pA >> 8) & 0x0F;
      r[8] = 15; r[7] &= ~(1 << 0);
      durA--;
    }
  }

  // --- C Drums ---
  if (bar == 3 && trans == 5) { 
    uint16_t s_p = 400 - (step * 5); s_p += (int)(20.0 * sin(frame * 1.2)); 
    r[4] = s_p & 0xFF; r[5] = (s_p >> 8) & 0x0F; r[10] = 13; r[7] &= ~(1 << 2);
  } else if (bar == 3 && trans == 1 && step > 32) { 
    r[6] = 20 - (step-32)/2; r[10] = 8 + (step-32)/4; if (step % 4 == 0) r[7] &= ~(1 << 5);
  } else {
    if (step % 16 == 0) { r[6] = 2; r[10] = 11; r[7] &= ~(1 << 5); } 
    if (step == 32) { r[4] = 0; r[5] = 0x08; r[6] = 12; r[11] = 0; r[12] = 0x08; r[13] = 0; r[10] = 0x10; r[7] &= ~0x24; env_level = 31; env_holding = 0; }
  }
}


int main() {
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    unsigned char r[14];
    int16_t buf[SAMPLES_PER_FRAME];

    while (1) {
        for(int i=0; i<14; i++) r[i] = 0;

	do_song1_tick(r);

        fill_buffer_with_ym(r, buf);

        if (fwrite(buf, 2, SAMPLES_PER_FRAME, audio_pipe) < SAMPLES_PER_FRAME) break;
        fflush(audio_pipe);

        frame++;
    }
    pclose(audio_pipe);
    return 0;
}
