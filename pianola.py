import math
import random

def get_ansi_mix(v_bits):
    """
    Mixes A(1:Green), B(2:Blue), C(4:Red).
    Returns the ANSI color code for the mix.
    """
    # Bitmask to ANSI: 1=G, 2=B, 3=Cyan, 4=R, 5=Yellow, 6=Magenta, 7=White
    colors = {0:"0", 1:"92", 2:"94", 3:"96", 4:"91", 5: "93", 6:"95", 7:"97"}
    return f"\x1b[{colors.get(v_bits, '0')}m"

def get_piano_ruler():
    """
    A 64-character ruler marking C positions (every 6 chars/12 notes).
    Useful as a 'header' every 16 or 32 ticks.
    """
    ruler = "C     .     " * 6 # 12 notes per octave = 6 chars
    return f"\x1b[90m{ruler[:64]}\x1b[0m"

def draw_pianola_row(pitches, volumes, noise_val=0):
    """
    Renders a single rising row of the pianola.
    pitches: [p0, p1, p2] (0-127)
    volumes: [v0, v1, v2] (0-15)
    noise_val: Current noise period (0-31)
    """
    # 128-slot bitboard for the row
    bitboard = [0] * 128
    for i in range(3):
        p = pitches[i]
        # Only plot if volume is > 0 and pitch is in range
        if 0 <= p < 128 and volumes[i] > 0:
            bitboard[int(p)] |= (1 << i)

    row_output = ""
    # 2 notes per character width = 64 characters total
    for i in range(0, 128, 2):
        L_bits = bitboard[i]
        R_bits = bitboard[i+1]
        
        # Rendering logic for 2x1 'pixels'
        if L_bits and R_bits:
            # Both notes active: Solid block with mixed color
            row_output += get_ansi_mix(L_bits | R_bits) + "█"
        elif L_bits:
            # Left note only: Left half-block
            row_output += get_ansi_mix(L_bits) + "▌"
        elif R_bits:
            # Right note only: Right half-block
            row_output += get_ansi_mix(R_bits) + "▐"
        elif noise_val > 0 and (random.random() * 32 < noise_val):
            # Noise 'grain' background
            row_output += "\x1b[90m.\x1b[0m"
        else:
            # Silence
            row_output += " "
            
    return row_output + "\x1b[0m"
