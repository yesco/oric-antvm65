import subprocess
import numpy as np
import sys

np.seterr(divide='ignore', invalid='ignore')

def extract_ay_final(input_file):
    fs = 44100
    target_fps = 50
    step_size = int(fs / target_fps)  # 882 samples
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

            # 3. TONE EXTRACTION (Scanning from 32 Hz upwards)
            search_data = fft_res[3:370] 
            top_3_sub = np.argsort(search_data)[-3:][::-1]
            
            parts = []
            for idx, i_sub in enumerate(top_3_sub):
                i = i_sub + 3
                
                # PARABOLIC INTERPOLATION 
                # This calculates the TRUE peak frequency and TRUE maximum magnitude
                # even if the note falls exactly between two FFT bins.
                y0, y1, y2 = np.log(fft_res[i-1:i+2] + 1e-10)
                p = (y0 - y2) / (2 * (y0 - 2 * y1 + y2))
                precise_freq = (i + p) * (fs / window_size)
                
                # Reconstruct the real magnitude at the true interpolated peak position
                # This prevents low bass notes from dropping below the volume gate floor.
                actual_mag = fft_res[i] * np.exp((p**2) * (y0 - 2*y1 + y2) / 2.0)
                if np.isnan(actual_mag) or np.isinf(actual_mag):
                    actual_mag = fft_res[i]

                # Stretch the range using the corrected true magnitude
                ay_vol = int(np.clip((13 * np.log10(actual_mag + 1e-10) - 40) / 3.5 * 1.15, 0, 15))

                if ay_vol < 4:
                    parts.append("    ---      ")
                else:
                    if idx == 2 and is_percussive:
                        parts.append(f"v{ay_vol:02d}N{noise_period:02d} {precise_freq:>6.1f}Hz")
                    else:
                        parts.append(f"v{ay_vol:02d}    {precise_freq:>6.1f}Hz")
            
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
