import struct

def get_sparkbox(v):
    chars = " ▂▃▄▅▆▇█"
    return chars[int((v/15)*7)] if v > 0 else "."

def get_sparkline(p):
    chars = "  ▂▃▄▅▆▇█"
    return chars[int(((p+128)/256)*8)]

def parse_asc_unlocked(file_path):
    note_names = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]
    
    with open(file_path, 'rb') as f:
        data = f.read()

    def print_row(offset, items):
        formatted = "".join(item.ljust(9) for item in items)
        print(f"{offset:04X}:  {formatted}")

    # --- 1. HEADER ---
    pos_ptr, orn_ptr = struct.unpack('>HH', data[1:5])
    song_loop = data[orn_ptr - 1]
    
    print("=== HEADER ===")
    print(f"0000:  Speed:{data[0]}  PosPtr:0x{pos_ptr:04X}  OrnPtr:0x{orn_ptr:04X}  SongLoopIdx:{song_loop}")
    title = data[32:96].decode('ascii', errors='ignore').strip()
    print(f"0020:  Title: \"{title}\"\n")

    # --- 2. SAMPLE DEFINITIONS (Unlocked 64-byte Scan) ---
    print("=== SAMPLE / INSTRUMENT DEFINITIONS ===")
    sample_map = data[10:32]
    for idx, mult in enumerate(sample_map):
        if mult == 0: continue
        addr = 0x60 + (mult * 64)
        if addr >= len(data): continue
        
        print(f"\n{addr:04X}:  === SAM INDEX: {idx:X} ===")
        v_s, p_s = "", ""
        
        # Parse all 21 possible triplets in the 64-byte block (63 bytes total)
        for t in range(21):
            off = addr + (t * 3)
            if off + 2 >= len(data): break
            
            v, n = data[off] & 0x0F, data[off+1] & 0x1F
            p = struct.unpack('b', data[off+2:off+3])[0]
            
            print(f"{off:04X}:  Tick {t:02d}: Vol:{v:X}  Nois:{n:02X}  Pit:{p:+04d}")
            v_s += get_sparkbox(v)
            p_s += get_sparkline(p)

        print(f"        Visual: {v_s} (Vol)")
        print(f"        Visual: {p_s} (Pit)")
        
        # Show the 64th byte (often the loop-to-tick pointer)
        loop_byte_off = addr + 63
        if loop_byte_off < len(data):
            print(f"{loop_byte_off:04X}:  --- End of Block Byte: 0x{data[loop_byte_off]:02X} ---")

    # --- 3. ORNAMENT DEFINITIONS ---
    print("\n=== ORNAMENT DEFINITIONS (1 byte/tick) ===")
    for o_idx in range(16):
        o_addr = orn_ptr + (o_idx * 32)
        if o_addr >= len(data): break
        print(f"\n{o_addr:04X}:  === ORN INDEX: {o_idx:X} ===")
        p_s = ""
        for t in range(32):
            off = o_addr + t
            if off >= len(data) or data[off] == 0xFF: break
            p = struct.unpack('b', data[off:off+1])[0]
            p_s += get_sparkline(p)
        print(f"{o_addr:04X}:  Visual: {p_s} (Arp/Pit)")

    # --- 4. INDEX TABLE ---
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

    # --- 5. DATA STREAM SCAN ---
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
        elif 0x90 <= b <= 0xDF: line.append(f"V+O:0x{b:02X}")
        elif b == 0xE0: line.append("BRK")
        elif 0xE1 <= b <= 0xEF:
            p = data[i+1] if i+1 < len(data) else 0
            line.append(f"JMP:0x{p:02X}"); i += 1
        elif 0xF0 <= b <= 0xFD: line.append(f"WAIT:{b&0xF:X}")
        else: line.append(f"0x{b:02X}")
        if len(line) >= 8:
            print_row(line_start, line); line = []; line_start = i + 1
        i += 1

    # --- 6. LEGEND ---
    print("\n" + "="*45 + "\nCOMMAND REFERENCE\n" + "-"*45)
    legend_items = [
        "0xFF       End of pattern marker",
        "0xXX       Raw hex byte (unknown)",
        "[REST]     Silence / Note stop",
        "BRK        Pattern Break (move to next index)",
        "CHAN:N     Select Tone Generator (Channel) 1, 2, or 3",
        "JMP:XX     Jump to Song Position Index XX",
        "NOTE       Musical pitch (e.g., C-4, D#5)",
        "ORN:N      Apply Ornament (Vibrato) macro N",
        "SAM:N      Switch to Sample (Instrument) N",
        "V+O:0xXX   Volume + Ornament combined command",
        "VOL:N      Set Volume level N (0-F)",
        "WAIT:N     Wait/Delay N ticks before next command"
    ]
    for item in sorted(legend_items): print(item)
    print("="*45)

parse_asc_unlocked('Over The Top (last part).asc')
