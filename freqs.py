import subprocess
import numpy as np
import sys

np.seterr(divide='ignore', invalid='ignore')

def extract_ay_final(input_file):
    fs = 44100
    target_fps = 50
    step_size = int(fs / target_fps)
    window_size = 4096

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
            
            # 1. TRANSIENT DETECTION (The "Punch")
            current_energy = np.sum(np.abs(new_samples))
            # Increase sensitivity: lower number = more noise triggers
            energy_surge = current_energy / (prev_energy + 1e-6)
            prev_energy = max(1.0, current_energy)

            windowed = buffer * np.hanning(window_size)
            fft_res = np.abs(np.fft.rfft(windowed))
            
            # 2. NOISE ANALYSIS
            # Focus on the 2kHz-8kHz range where snares/hats live
            hf_region = fft_res[200:800] 
            is_percussive = (energy_surge > 1.8) # Quick attack detect
            
            noise_period = 0
            if is_percussive:
                # Map noise to a "tighter" AY range (8-16 sounds like a classic snare)
                # High energy in HF -> Lower period (Higher pitch)
                hf_peak = np.argmax(hf_region)
                noise_period = int(np.clip(20 - (hf_peak / 30), 4, 28))

            # 3. TONE EXTRACTION
            search_data = fft_res[3:370] 
            top_3_sub = np.argsort(search_data)[-3:][::-1]
            
            parts = []
            for idx, i_sub in enumerate(top_3_sub):
                i = i_sub + 3
                raw_mag = fft_res[i]
                vol_db = 20 * np.log10(raw_mag / 10 + 1e-10)

#                ay_vol = int(np.clip(vol_db / 5, 0, 15))

                # Stretches the range so only the absolute peaks hit v15
                ay_vol = int(np.clip((13 * np.log10(raw_mag + 1e-10) - 40) / 4, 0, 15))

                ay_vol *= 3
                
                # Precise Frequency
                y0, y1, y2 = np.log(fft_res[i-1:i+2] + 1e-10)
                p = (y0 - y2) / (2 * (y0 - 2 * y1 + y2))
                precise_freq = (i + p) * (fs / window_size)

                if ay_vol < 4:
                    parts.append("    ---      ")
                else:
                    # Only apply noise to Channel C if a surge is detected
                    if idx == 2 and is_percussive:
                        # Output format for your YM parser
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
