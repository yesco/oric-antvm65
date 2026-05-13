import subprocess
import numpy as np
import sys

np.seterr(divide='ignore', invalid='ignore')

def extract_ay_final(input_file):
    fs = 44100
    target_fps = 50
    step_size = int(fs / target_fps)  # Exactly 882 samples (20ms step)
    
    # Dual-Band Window Sizes
    window_treble = 4096              # High time resolution for arpeggios
    window_bass = 16384               # High frequency resolution for low bass

    command = ['ffmpeg', '-i', str(input_file), '-f', 's16le', '-ac', '1', '-ar', str(fs), '-']
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    
    # Separate parallel audio rolling buffers
    buffer_treble = np.zeros(window_treble, dtype=np.int16)
    buffer_bass = np.zeros(window_bass, dtype=np.int16)
    
    prev_energy = 1.0
    
    try:
        while True:
            raw_data = process.stdout.read(step_size * 2)
            if len(raw_data) < step_size * 2: break
            
            new_samples = np.frombuffer(raw_data, dtype=np.int16)
            
            # Roll and update treble buffer
            buffer_treble = np.roll(buffer_treble, -step_size)
            buffer_treble[-step_size:] = new_samples
            
            # Roll and update parallel bass buffer
            buffer_bass = np.roll(buffer_bass, -step_size)
            buffer_bass[-step_size:] = new_samples
            
            # 1. TRANSIENT DETECTION (The "Punch")
            current_energy = np.sum(np.abs(new_samples))
            energy_surge = current_energy / (prev_energy + 1e-6)
            prev_energy = max(1.0, current_energy)

            # 2. RUN PARALLEL FFTS
            windowed_treble = buffer_treble * np.hanning(window_treble)
            fft_treble = np.abs(np.fft.rfft(windowed_treble))
            
            windowed_bass = buffer_bass * np.hanning(window_bass)
            fft_bass = np.abs(np.fft.rfft(windowed_bass))
            
            # 3. NOISE ANALYSIS
            hf_region = fft_treble[200:800] 
            is_percussive = (energy_surge > 1.8)
            
            noise_period = 0
            if is_percussive:
                hf_peak = np.argmax(hf_region)
                noise_period = int(np.clip(20 - (hf_peak / 30), 4, 28))

            # 4. BASS EXTRACTION WITH INTEGRATED SIDE-BAND ENERGY BOOST
            # Bin resolution is ~2.69 Hz per bin. Look from bin 10 (~27 Hz) to bin 65 (~175 Hz).
            bass_search_data = fft_bass[10:65]
            bass_i_sub = np.argmax(bass_search_data)
            bass_i = bass_i_sub + 10
            
            # Boost: Sum energy of the peak bin + neighboring bins to reclaim leaked power
            bass_mag_boosted = np.sum(fft_bass[bass_i-2:bass_i+3])
            
            # Parabolic interpolation for fine tuning frequency
            y0, y1, y2 = np.log(fft_bass[bass_i-1:bass_i+2] + 1e-10)
            p_bass = (y0 - y2) / (2 * (y0 - 2 * y1 + y2))
            bass_freq = (bass_i + p_bass) * (fs / window_bass)
            
            # Separate volume profile for bass to prevent it dropping below the gate floor
            bass_vol = int(np.clip((14 * np.log10(bass_mag_boosted + 1e-10) - 35) / 3.5 * 1.25, 0, 15))
            
            # Base variables for accumulating captured ghost-harmonic energy
            harvested_harmonic_magnitude = 0.0

            # 5. EXTRACT MID/TREBLE TONES & HARMONIC RECLAMATION
            treble_search_data = fft_treble[14:370]
            top_treble_sub = np.argsort(treble_search_data)[::-1]
            
            valid_treble_notes = []
            
            for idx in top_treble_sub:
                i = idx + 14
                raw_mag = fft_treble[i]
                
                # Interpolate precise treble frequency
                y0, y1, y2 = np.log(fft_treble[i-1:i+2] + 1e-10)
                p = (y0 - y2) / (2 * (y0 - 2 * y1 + y2))
                precise_freq = (i + p) * (fs / window_treble)
                
                # HARMONIC GHOST FILTER WITH MAGNITUDE HARVESTING
                if bass_vol >= 4 and bass_freq > 0:
                    ratio = precise_freq / bass_freq
                    if abs(ratio - round(ratio)) < 0.16 and ratio > 1.2:
                        # Reclaim this removed frequency's energy and feed it back to the base tone
                        harvested_harmonic_magnitude += raw_mag
                        continue 
                
                ay_vol = int(np.clip((13 * np.log10(raw_mag + 1e-10) - 40) / 3.5 * 1.15, 0, 15))
                if ay_vol >= 4:
                    valid_treble_notes.append((precise_freq, ay_vol))

            # 6. APPLY HARVESTED ENERGY TO THE FINAL BASS VOLUME
            if harvested_harmonic_magnitude > 0 and bass_vol >= 4:
                # Add harvested mid-range harmonic energy directly to the fundamental bass weight
                boosted_bass_mag = bass_mag_boosted + (harvested_harmonic_magnitude * 0.5)
                bass_vol = int(np.clip((14 * np.log10(boosted_bass_mag + 1e-10) - 35) / 3.5 * 1.25, 0, 15))

            # 7. CHANNELS MAPPING
            selected_notes = []
            
            # Lock Channel A to the boosted Bass pipeline
            if bass_vol >= 4:
                selected_notes.append((bass_freq, bass_vol))
            else:
                selected_notes.append((0.0, 0))
                
            # Assign remaining melodic channels from filtered treble list
            for note in valid_treble_notes:
                if len(selected_notes) >= 3:
                    break
                selected_notes.append(note)

            # Pad output array if insufficient frequencies found
            while len(selected_notes) < 3:
                selected_notes.append((0.0, 0))

            # 8. PRINT CHIP VALUE OUTPUT
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
