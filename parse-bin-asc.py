import struct
import math

def get_sparkbox(v):
    chars = " ▂▃▄▅▆▇█"
    v = max(0, min(int(v), 15))
    return chars[int((v/15)*7)] if v > 0 else "."

def get_sparkline(p):
    chars = "  ▂▃▄▅▆▇█"
    p = max(-128, min(int(p), 127))
    return chars[int(((p+128)/256)*8)]

def get_spark_up(v, max_val=15):
    """Vertical growth from bottom=0 using a sqrt-scale for better visibility."""
    chars = " .▂▃▄▅▆▇█"
    v = max(0, min(int(v), max_val))
    if v == 0: return "."
    idx = int(math.sqrt(v / max_val) * 8)
    return chars[max(1, min(idx, 8))]

def get_bipolar_sparks(p, scale=128):
    """Returns (up_str, down_str) using sqrt-mapping and ANSI inversion for negative swing."""
    chars = " .▂▃▄▅▆▇█"
    inv_map = [" ", "▇", "▆", "▅", "▄", "▃", "▂", " ", " "]
    val = max(-scale, min(int(p), scale))
    if val == 0: return ".", " "
    mag = int(math.sqrt(abs(val) / scale) * 8)
    mag = max(1, min(mag, 8))
    if val > 0:
        return chars[mag], " "
    else:
        return " ", f"\x1b[7m{inv_map[mag]}\x1b[0m"

def parse_asc_complete(file_path):
    note_names = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]
    with open(file_path, 'rb') as f:
        data = f.read()

    def print_row(items):
        formatted = " | ".join(item.ljust(15) for item in items)
        print(f"{formatted} | +")

    # --- 1. HEADER ---
    pos_ptr, orn_ptr = struct.unpack('>HH', data[1:5])
    song_loop = data[orn_ptr - 1]
    print(f"=== HEADER ===\n0000: Speed:{data[0]:02X} | PosPtr:0x{pos_ptr:04X} | OrnPtr:0x{orn_ptr:04X} | LoopIdx:{song_loop}")
    title = data[32:96].decode('ascii', errors='ignore').strip()
    print(f"0020: Title: \"{title}\"\n")

    # --- 2. SAMPLE / OSCILLATOR DEFINITIONS ---
    print("=== SAMPLE / INSTRUMENT DEFINITIONS (OSC) ===")
    sample_map = data[10:32]
    for idx, mult in enumerate(sample_map):
        if mult == 0: continue
        addr = 0x60 + (mult * 64)
        if addr >= len(data): continue
        print(f"\n{addr:04X}: === SAM INDEX: {idx:X} ===")
        v_s, n_s, pu_s, pd_s = "", "", "", ""
        for t in range(21):
            off = addr + (t * 3)
            if off + 2 >= len(data): break
            v, n = data[off] & 0x0F, data[off+1] & 0x1F
            p = struct.unpack('b', data[off+2:off+3])[0]
            print(f"{off:04X}: T{t:02d} | Vol:{v:X} | Nois:{n:02X} | Pit:{p:+04d}")
            v_s += get_spark_up(v, 15)
            n_s += get_spark_up(n, 31)
            u, d = get_bipolar_sparks(p, 128)
            pu_s += u; pd_s += d
        print(f"Visual Vol:  {v_s}\nVisual Nois: {n_s}\nVisual Pit+: {pu_s}\nVisual Pit-: {pd_s}")

    # --- 3. ORNAMENT DEFINITIONS (ARPEGGIO) ---
    print("\n=== ORNAMENT DEFINITIONS (ARPEGGIO) ===")
    for o_idx in range(16):
        o_addr = orn_ptr + (o_idx * 32)
        if o_addr >= len(data): break
        print(f"\n{o_addr:04X}: === ORN INDEX: {o_idx:X} ===")
        au_s, ad_s = "", ""
        for t in range(32):
            off = o_addr + t
            if off >= len(data) or data[off] == 0xFF: break
            p = struct.unpack('b', data[off:off+1])[0]
            print(f"{off:04X}: T{t:02d} | Offs:{p:+04d}")
            u, d = get_bipolar_sparks(p, 48)
            au_s += u; ad_s += d
        if au_s: print(f"Visual Arp+: {au_s}\nVisual Arp-: {ad_s}")

    # --- 4. INDEX TABLE ---
    addr_to_indices = {}
    curr, idx_id = pos_ptr, 0
    print(f"\n{pos_ptr:04X}: === INDEX TABLE ===")
    while curr + 1 < (orn_ptr - 1):
        p_addr = struct.unpack('<H', data[curr:curr+2])[0]
        print(f"{curr:04X}: i{idx_id:02d} -> Pattern 0x{p_addr:04X}")
        if 0 < p_addr < len(data):
            if p_addr not in addr_to_indices: addr_to_indices[p_addr] = []
            addr_to_indices[p_addr].append(idx_id)
        curr += 2; idx_id += 1

    # --- 5. DATA STREAM SCAN ---
    print(f"\n0060: === DATA STREAM ===")
    i, line = 0x60, []
    while i < len(data):
        if i in addr_to_indices:
            if line: print_row(line); line = []
            for idx in addr_to_indices[i]: print(f"\n{i:04X}: === START i{idx} ===")
        
        ad, b = f"{i:04X}:", data[i]
        if b == 0xFF:
            line.append(f"{ad} 0xFF"); print_row(line); line = []
            print(f"{i:04X}: --- END PATTERN ---\n"); i += 1; continue
        elif b == 0xFE: line.append(f"{ad} [REST]")
        elif b <= 0x5F: line.append(f"{ad} [{note_names[b%12]}{b//12+1}]")
        elif 0x60 <= b <= 0x6F: line.append(f"{ad} SAM:{b&0xF:X}")
        elif 0x70 <= b <= 0x7F: line.append(f"{ad} ORN:{b&0xF:X}")
        elif 0x80 <= b <= 0x8F: line.append(f"{ad} VOL:{b&0xF:X}")
        elif 0x90 <= b <= 0xDF:
            v, o = (b-0x90) >> 2, (b-0x90) & 0x03
            line.append(f"{ad} V{v:X}+O{o:X}")
        elif b == 0xE0: line.append(f"{ad} BRK")
        elif 0xE1 <= b <= 0xEF:
            p = data[i+1] if i+1 < len(data) else 0
            line.append(f"{ad} EFF:{b:02X}:{p:02X}"); i += 1 
        elif 0xF0 <= b <= 0xFD: line.append(f"{ad} WAIT:0x{b&0xF:X}")
        else: line.append(f"{ad} 0x{b:02X}")
        if len(line) >= 4: print_row(line); line = []
        i += 1

    return data, addr_to_indices, note_names, orn_ptr

# --- EXECUTION ---
from trace_bin_asc import trace
file_data, indices, names, ornaments_address = parse_asc_complete('Over The Top (last part).asc')
trace(file_data, indices, names, ornaments_address)
