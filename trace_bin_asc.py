import math
import struct
import pianola

def get_base_note(note_str, note_names):
    if not note_str or "---" in note_str or "===" in note_str: return -1
    try:
        clean = note_str.strip("[] ")
        name, octave = clean[:-1], int(clean[-1])
        return note_names.index(name) + (octave * 12)
    except: return -1

def get_orn_offset(data, orn_ptr, orn_idx, tick):
    if orn_idx == "-" or orn_idx == " ": return 0
    try:
        o_addr = orn_ptr + (int(orn_idx, 16) * 32)
        off = o_addr + (tick % 32)
        if off >= len(data) or data[off] == 0xFF: return 0
        return struct.unpack('b', data[off:off+1])[0]
    except: return 0

def trace(data, addr_to_indices, note_names, orn_ptr):
    def _get_volume_staple(v):
        chars = " ▏▎▍▌▋▊▉█"
        v = max(0, min(int(v), 15))
        if v == 0: return "."
        idx = int((v / 15) * 8)
        return chars[max(1, min(idx, 8))]

    addr_to_idx_num = {addr: min(idxs) for addr, idxs in addr_to_indices.items()}
    row_tmpl = "{tick:<4} | {addr:<4} | {pos:<7} | {v0:<14} | {v1:<14} | {v2:<14} |"
    sum_tmpl = "{tick:<4} = {addr:<4} | {pos:<7} | {v0:<14} | {v1:<14} | {v2:<14} |"
    
    print("\n" + "="*75 + "\n" + row_tmpl.format(tick="TICK", addr="ADDR", pos="IDX:POS", v0="VOICE A", v1="VOICE B", v2="VOICE C"))

    cur_note, cur_vol_raw = ["---"]*3, [0]*3
    cur_orn, cur_sam = ["-"]*3, ["-"]*3
    global_tick = 0
    
    playlist = sorted([(i, addr) for addr, idxs in addr_to_indices.items() for i in idxs])

    for pos_idx, p_addr in playlist:
        ptr, v_active = p_addr, [True, True, True]
        idx_label = f"i{addr_to_idx_num.get(p_addr, '??')}:{pos_idx:02d}"
        
        while any(v_active) and ptr < len(data):
            tick_start_ptr, control_events = ptr, [] 
            
            for v_idx in range(3):
                if not v_active[v_idx]: continue
                while ptr < len(data):
                    curr_ptr, b = ptr, data[ptr]; ptr += 1
                    if b == 0xFF:
                        control_events.append((curr_ptr, v_idx, "END"))
                        v_active[v_idx] = False; break
                    elif b == 0xFE: cur_note[v_idx], cur_vol_raw[v_idx] = "===", 0
                    elif b == 0xE0: break 
                    elif b <= 0x5F: cur_note[v_idx] = f"[{note_names[b%12]}{b//12+1}]"
                    elif 0x60 <= b <= 0x6F: cur_sam[v_idx] = f"{b&0xF:X}"
                    elif 0x70 <= b <= 0x7F: cur_orn[v_idx] = f"{b&0xF:X}"
                    elif 0x80 <= b <= 0x8F: cur_vol_raw[v_idx] = b & 0x0F
                    elif 0x90 <= b <= 0xDF:
                        cur_vol_raw[v_idx] = (b-0x90) >> 2
                        cur_orn[v_idx] = f"{(b-0x90) & 0x03:X}"
                    elif 0xF0 <= b <= 0xFD: break 
                    elif 0xE1 <= b <= 0xEF:
                        p = data[ptr] if ptr < len(data) else 0; ptr += 1
                        control_events.append((curr_ptr, v_idx, f"EFF {b:02X}:{p:02X}"))

            # Calculate Live Pitches (Base + Trill)
            live_pitches = []
            for i in range(3):
                base = get_base_note(cur_note[i], note_names)
                offset = get_orn_offset(data, orn_ptr, cur_orn[i], global_tick)
                live_pitches.append(base + offset if base != -1 else -1)

            # --- DISPLAY WITH * UNPACKING FIX ---
            v_det = [f"{cur_note[i].ljust(6)} {cur_vol_raw[i]:X} {cur_orn[i]}:{cur_sam[i]}" for i in range(3)]
            print(row_tmpl.format(tick=f"{global_tick:04d}", addr=f"{tick_start_ptr:04X}", pos=idx_label, v0=v_det[0], v1=v_det[1], v2=v_det[2]))
            
            for e_addr, e_v_idx, e_desc in control_events:
                cols = ["", "", ""]
                cols[e_v_idx] = e_desc
                print(row_tmpl.format(tick="", addr=f"{e_addr:04X}", pos="", v0=cols[0], v1=cols[1], v2=cols[2]))

            v_sum = [f"{cur_note[i].ljust(6)} {_get_volume_staple(cur_vol_raw[i])} {cur_vol_raw[i]:X}" for i in range(3)]
            print(sum_tmpl.format(tick=f"{global_tick:04d}", addr="=", pos="", v0=v_sum[0], v1=v_sum[1], v2=v_sum[2]))

            # --- PIANOLA CALL ---
            if global_tick % 16 == 0: print(pianola.get_piano_ruler())
            # Use current sam as noise indicator
            try: 
                ns = int(cur_sam[0], 16) if cur_sam[0] != "-" else 0
            except: ns = 0
            print(pianola.draw_pianola_row(global_tick, live_pitches, cur_vol_raw, noise_val=ns))

            global_tick += 1
