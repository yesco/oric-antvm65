import subprocess
import numpy as np
import sys

np.seterr(divide='ignore', invalid='ignore')

def extract_ay_final(input_file):
    fs = 44100
    target_fps = 50
    step_size = int(fs / target_fps)  # Exactly 882 samples (20ms step)
    window_treble = 4096              # High time resolution for arpeggios

    command = ['ffmpeg', '-i', str(input_file), '-f', 's16le', '-ac', '1', '-ar', str(fs), '-']
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    
    buffer_treble = np.zeros(window_treble, dtype=np.int16)
    prev_energy = 1.0
    
    try:
        while True:
            raw_data = process.stdout.read(step_size * 2)
            if len(raw_data) < step_size * 2: break
            
            new_samples = np.frombuffer(raw_data, dtype=np.int16)
            
            buffer_treble = np.roll(buffer_treble, -step_size)
            buffer_treble[-step_size:] = new_samples
            
            # 1. TRANSIENT DETECTION
            current_energy = np.sum(np.abs(new_samples))
            energy_surge = current_energy / (prev_energy + 1e-6)
            prev_energy = max(1.0, current_energy)

            # 2. RUN FFT ON TREBLE
            windowed_treble = buffer_treble * np.hanning(window_treble)
            fft_treble = np.abs(np.fft.rfft(windowed_treble))
            
            # 3. NOISE ANALYSIS
            hf_region = fft_treble[200:800] 
            is_percussive = (energy_surge > 1.8)
            
            noise_period = 0
            if is_percussive:
                hf_peak = np.argmax(hf_region)
                noise_period = int(np.clip(20 - (hf_peak / 30), 4, 28))

            # 4. EXTRACT ALL DOMINANT TREBLE FREQUENCIES
            treble_search_data = fft_treble[3:370] # Include lower bins to catch mid-range overtones
            top_indices = np.argsort(treble_search_data)[::-1][:6] # Look at top 6 peaks
            
            detected_tones = []
            for idx in top_indices:
                i = idx + 3
                raw_mag = fft_treble[i]
                
                # Precise Frequency
                y0, y1, y2 = np.log(fft_treble[i-1:i+2] + 1e-10)
                p = (y0 - y2) / (2 * (y0 - 2 * y1 + y2))
                freq = (i + p) * (fs / window_treble)
                
                detected_tones.append({'freq': freq, 'mag': raw_mag})

            # 5. DIRECT OVERTONE MAPPING TO BASE TONE
            # Find the loudest tone that looks like an overtone of a deep bass note (30Hz - 150Hz)
            base_freq = 0.0
            accumulated_bass_mag = 0.0
            overtone_indices_to_remove = []

            for target_sub in range(len(detected_tones)):
                t_freq = detected_tones[target_sub]['freq']
                t_mag = detected_tones[target_sub]['mag']

                # Test possible sub-harmonics (octaves down: /2, /3, /4)
                for divisor in [2, 3, 4]:
                    possible_base = t_freq / divisor
                    if 30.0 <= possible_base <= 150.0:
                        # Found a valid bass candidate! Let's lock onto it.
                        base_freq = possible_base
                        accumulated_bass_mag += t_mag
                        overtone_indices_to_remove.append(target_sub)
                        break
                if base_freq > 0.0:
                    break # Locked onto the primary base generator

            # Accumulate any other overtones that fit this base tone
            if base_freq > 0.0:
                for idx, tone in enumerate(detected_tones):
                    if idx in overtone_indices_to_remove:
                        continue
                    ratio = tone['freq'] / base_freq
                    if abs(ratio - round(ratio)) < 0.15:
                        accumulated_bass_mag += tone['mag']
                        overtone_indices_to_remove.append(idx)

            # Filter out the hijacked overtones from the melody pool
            melody_tones = [t for idx, t in enumerate(detected_tones) if idx not in overtone_indices_to_remove]

            # 6. CONVERT ACCUMULATED MAGNITUDES TO AY VOLUMES
            selected_notes = []

            # Channel A: Pure Base Tone (with added overtone volumes)
            if base_freq > 0.0:
                bass_vol = int(np.clip((13 * np.log10(accumulated_bass_mag + 1e-10) - 40) / 3.5 * 1.15, 0, 15))
                if bass_vol >= 4:
                    selected_notes.append((base_freq, bass_vol))
                else:
                    selected_notes.append((0.0, 0))
            else:
                selected_notes.append((0.0, 0))

            # Channels B and C: Remaining Melodies
            for tone in melody_tones:
                if len(selected_notes) >= 3:
                    break
                ay_vol = int(np.clip((13 * np.log10(tone['mag'] + 1e-10) - 40) / 3.5 * 1.15, 0, 15))
                if ay_vol >= 4:
                    selected_notes.append((tone['freq'], ay_vol))

            # Pad output array if insufficient frequencies found
            while len(selected_notes) < 3:
                selected_notes.append((0.0, 0))

            # 7. PRINT CHIP VALUE OUTPUT
            parts = []
            for idx, (freq, vol) in enumerate(selected_notes):
                if vol < 4 or freq == 0:
                    parts.append("    ---      ")
                else:
                    if idx == 2 and is_percussive: 
                        parts.append(f"v{vol:02d}N{noise_period:02d} {freq:>6.1f}Hz")
                    else:
                        parts.append(f"v{vol:02d}    {freq:>6.1f}Hz")
            
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
