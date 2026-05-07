#include <stdio.h>
#include <stdint.h>

#define SAMPLE_RATE 44100
#define FRAME_RATE 50
#define SAMPLES_PER_FRAME (SAMPLE_RATE / FRAME_RATE) // 882 samples

int main() {
    // Open a pipe to the audio server. 
    // --raw: expect headerless PCM
    // --latency-msec=20: roughly matches our 1/50s frame rate
    FILE *audio_pipe = popen("pacat --raw --format=s16le --rate=44100 --channels=1 --latency-msec=20", "w");
    
    if (!audio_pipe) {
        perror("Failed to open audio pipe");
        return 1;
    }

    int16_t buffer[SAMPLES_PER_FRAME];
    int total_samples = 0;
    int frequency_divider = 50; // Pitch control
    int amplitude = 12000;      // Volume control

    printf("Starting real-time generation. Press Ctrl+C to stop.\n");

    // Loop simulating your "autoframe" capture
    while (1) {
        // 1. Generate 1/50s of a square wave
        for (int i = 0; i < SAMPLES_PER_FRAME; i++) {
            buffer[i] = ((total_samples / frequency_divider) % 2) ? amplitude : -amplitude;
            total_samples++;
        }

        // 2. Write the frame to the pipe
        size_t written = fwrite(buffer, sizeof(int16_t), SAMPLES_PER_FRAME, audio_pipe);
        
        if (written < SAMPLES_PER_FRAME) {
            break; // Pipe closed or error
        }

        // 3. Ensure data is sent to the server immediately
        fflush(audio_pipe);

        // In your real program, the timing is controlled by the emulator output.
        // For this test, you can add a usleep(20000) if it runs too fast.
    }

    pclose(audio_pipe);
    return 0;
}
