import subprocess
import numpy as np
import sys

np.seterr(divide='ignore', invalid='ignore')

def extract_ay_final(input_file):
    fs = 44100
    target_fps = 50
    step_size = int(fs / target_fps)  # Exactly 882 samples
    window_size = 4096                 # 10.76 Hz per bin

    command = ['ffmpeg', '-i', str(input_file), '-f', 's16le', '-ac', '1', '-ar', str(fs), '-']
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    buffer = np.zeros(window_size, dtype=np.int16)
    
    prev_energy = 1.0
    
    try:
        while True:
            raw_data = process.stdout.read(step_size * 2)
            if len(raw_data) < step_size * 2: break
            
            new_samples = np.frombuffer(raw_data, dtype=np.int16)
            buffer = np.roll(buffer, -step_size)
            buffer[-step_size:] = new_samples
            
            # 1. TRANSIENT DETECTION
            current_energy = np.sum(np.abs(new_samples))
            energy_surge = current_energy / (prev_energy + 1e-6)
            prev_energy = max(1.0, current_energy)

            windowed = buffer * np.hanning(window_size)
            fft_res = np.abs(np.fft.rfft(windowed))
            
            # 2. NOISE ANALYSIS
            hf_region = fft_res[200:800] 
            is_percussive = (energy_surge > 1.8)
            noise_period = 0
            if is_percussive:
                hf_peak = np.argmax(hf_region)
                noise_period = int(np.clip(20 - (hf_peak / 30), 4, 28))

            # 3. DIRECT PEAK EXTRACTION
            working_fft = np.copy(fft_res)
            
            # Target boundaries
            working_fft[:4] = 0.0
            working_fft[368:] = 0.0
            
            top_3_sub = []
            for _ in range(3):
                i = np.argmax(working_fft)
                if working_fft[i] < 1e-5:
                    break
                    
                top_3_sub.append(i)
                # Clear neighbor bins to prevent duplicate frequency rows
                working_fft[max(0, i-4):min(len(working_fft), i+5)] = 0.0

            # 4. OUTPUT FORMATTING
            parts = []
            for idx, i in enumerate(top_3_sub):
                raw_mag = fft_res[i]
                
                # Precise Linear Interpolation
                alpha = fft_res[i-1]
                beta = fft_res[i]
                gamma = fft_res[i+1]
                denom = alpha + beta + gamma
                p = 0.5 * (alpha - gamma) / (alpha - 2*beta + gamma + 1e-10) if denom > 1e-10 else 0.0
                precise_freq = (i + p) * (fs / window_size)

                # Safe Volume Scaling
                ay_vol = int(np.clip((13 * np.log10(raw_mag + 1e-10) - 40) / 3.5 * 1.15, 0, 15))

                if ay_vol < 2:  # Relaxed slightly to catch quiet high notes
                    parts.append("    ---      ")
                else:
                    if idx == 2 and is_percussive:
                        parts.append(f"v{ay_vol:02d}N{noise_period:02d} {precise_freq:>6.1f}Hz")
                    else:
                        parts.append(f"v{ay_vol:02d}    {precise_freq:>6.1f}Hz")
            
            while len(parts) < 3:
                parts.append("    ---      ")
                
            print(" | ".join(parts))
            
    except KeyboardInterrupt:
        process.terminate()
    finally:
        process.wait()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 script.py <audio_file>")
    else:
        extract_ay_final(sys.argv[1])
