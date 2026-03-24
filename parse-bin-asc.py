import struct

def get_sparkbox(val):
    """Visualizes volume (0-15) using block characters."""
    chars = " ▂▃▄▅▆▇█"
    idx = int((val / 15) * (len(chars) - 1))
    return chars[idx] if val > 0 else "."

def get_sparkline(val):
    """Visualizes signed pitch offsets using sparklines."""
    chars = "  ▂▃▄▅▆▇█"
    # Normalize -128...127 to 0...8
    normalized = (val + 128) / 256
    idx = int(normalized * (len(chars) - 1))
    return chars[idx]

def parse_asc_final(file_path):
    note_names = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]
    
    with open(file_path, 'rb') as f:
        data = f.read()

    def print_row(offset, items):
        formatted = "".join(item.ljust(9) for item in items)
        print(f"{offset:04X}:  {formatted}")

    # --- 1. HEADER (Big-Endian structural pointers) ---
    pos_ptr = struct.unpack('>H', data[1:3])[0]
    orn_ptr = struct.unpack('>H', data[3:5])[0]
    loop_idx = data[orn_ptr - 1]
    
    print("=== HEADER ===")
    print(f"0000:  Speed:{data[0]}  PosPtr:0x{pos_ptr:04X}  OrnPtr:0x{orn_ptr:04X}  LoopIdx:{loop_idx}")
    title = data[32:96].decode('ascii', errors='ignore').strip()
    print(f"0020:  Title: \"{title}\"\n")

    # --- 2. SAMPLE EXTRACTION & VISUALIZATION ---
    print("=== SAMPLE / INSTRUMENT DEFINITIONS ===")
    sample_map = data[10:32]
    for idx, mult in enumerate(sample_map):
        if mult == 0: continue
        addr = 0x60 + (mult * 64) 
        if addr >= len(data): continue
        
        print(f"\nSAM INDEX: {idx:X} (Addr: 0x{addr:04X})")
        v_sparks = ""
        p_sparks = ""
        
        # Print raw data lines first
        for t in range(16):
            base = addr + (t * 3)
            if base + 2 >= len(data): break
            v = data[base] & 0x0F
            p = struct.unpack('b', data[base+2:base+3])[0]
            n = data[base+1] & 0x1F
            
            print(f"  Tick {t:02d}: Vol:{v:X}  Noise:{n:02X}  Pitch:{p:+04d}")
            
            v_sparks += get_sparkbox(v)
            p_sparks += get_sparkline(p)
            if v == 0 and t > 0: break 
            
        # Aligned Sparkline footer
        print(f"  Visual: {v_sparks} (Volume)")
        print(f"          {p_sparks} (Pitch)")

    # --- 3. INDEX TABLE (Little-Endian position list) ---
    addr_to_indices = {}
    curr, idx_id = pos_ptr, 0
    print(f"\n{pos_ptr:04X}:  === INDEX TABLE ===")
    while curr + 1 < orn_ptr - 1:
        p_addr = struct.unpack('<H', data[curr:curr+2])[0]
        print(f"{curr:04X}:  Index[{idx_id}] -> Pattern at 0x{p_addr:04X}")
        if 0 < p_addr < len(data):
            if p_addr not in addr_to_indices: addr_to_indices[p_addr] = []
            addr_to_indices[p_addr].append(idx_id)
        curr += 2; idx_id += 1

    # --- 4. DATA STREAM ---
    print(f"\n0060:  === DATA STREAM ===")
    i, line = 0x60, []
    line_start = i
    while i < len(data):
        if i in addr_to_indices:
            if line: print_row(line_start, line); line = []
            for idx in addr_to_indices[i]:
                print(f"\n{i:04X}:  === START PATTERN INDEX: {idx} ===")
            line_start = i

        b = data[i]
        if b == 0xFF:
            line.append("0xFF")
            print_row(line_start, line); print(f"{i:04X}:  --- END PATTERN ---\n")
            line = []; i += 1; line_start = i; continue
        elif b == 0xFE: line.append("[REST]")
        elif 0x01 <= b <= 0x03: line.append(f"CHAN:{b}")
        elif b <= 0x5F: line.append(f"{note_names[b%12]}{b//12+1}")
        elif 0x60 <= b <= 0x6F: line.append(f"SAM:{b&0xF:X}")
        elif 0x70 <= b <= 0x7F: line.append(f"ORN:{b&0xF:X}")
        elif 0x80 <= b <= 0x8F: line.append(f"VOL:{b&0xF:X}")
        elif 0x90 <= b <= 0xDF: line.append(f"V+O:{b:02X}")
        elif b == 0xE0: line.append("BRK")
        elif 0xE1 <= b <= 0xEF:
            p = data[i+1] if i+1 < len(data) else 0
            line.append(f"JMP:{p:02X}"); i += 1
        elif 0xF0 <= b <= 0xFD: line.append(f"WAIT:{b&0xF:X}")
        else: line.append(f"0x{b:02X}")

        if len(line) >= 8:
            print_row(line_start, line)
            line = []; line_start = i + 1
        i += 1
    
    if line: print_row(line_start, line)

    # --- 5. COMMAND REFERENCE ---
    print("\n" + "="*45 + "\nCOMMAND REFERENCE\n" + "-"*45)
    ref = [
        "0xFF       End of pattern marker",
        "0xXX       Raw hex byte (unknown)",
        "[REST]     Silence / Note stop",
        "BRK        Pattern Break (move to next index)",
        "CHAN:N     Select Tone Generator (Channel) 1, 2, or 3",
        "JMP:XX     Jump to Song Position Index XX",
        "NOTE       Musical pitch (e.g., C-4, D#5)",
        "ORN:N      Apply Ornament (Vibrato) macro N",
        "SAM:N      Switch to Sample (Instrument) N",
        "V+O:XX     Volume + Ornament combined command",
        "VOL:N      Set Volume level N (0-F)",
        "WAIT:N     Wait/Delay N ticks before next command"
    ]
    for item in sorted(ref): print(item)
    print("="*45)

parse_asc_final('Over The Top (last part).asc')
