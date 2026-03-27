;;; 35 B 12c - rol sequence is more compact than 4 lsr
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - Keeping hi in A during shifts saves 1 byte and 6c per loop
;;; 42 B 35c - Added 16-bit signed detune/pitch-bend (A = detune_lo, Y = detune_hi)
;;; 90 B 74-149c - Total Size (42 B code, 48 B table)

; Input: 
;   A = %OOONNNNN (Octave 0-7, Note 0-23)
;   detune_lo/hi = 16-bit signed offset to add to the period
; Output: tmp_low/high (12-bit AY period)
calc_pitch:
    asl                 ; 2B | A = %OONNNNN0, Octave bit 7 -> Carry
    tay                 ; 1B | Save for later
    and #%00111110      ; 2B | Mask Note index (0-46)
    tax                 ; 1B | X = table offset
    
    tya                 ; 1B | Restore note info
    rol                 ; 1B | Pull bits 7, 6, 5 into low 3 bits
    rol                 ; 1B 
    rol                 ; 1B 
    and #%00000111      ; 2B | A = Octave (0-7)
    tay                 ; 1B | Y = loop counter

    lda period_table, x   ; 3B
    sta tmp_low           ; 3B
    lda period_table+1, x ; 3B | Load High byte into A for loop
    
octave_loop:
    dey                 ; 1B | Decrement counter
    bmi done            ; 2B | If Y was 0, it's now $FF, so exit
    lsr                 ; 1B | Shift A (hi byte)
    ror tmp_low         ; 3B | Rotate into low byte
    jmp octave_loop     ; 3B | Repeat

done:
    ; --- Detune / Pitch Bend Section ---
    clc                 ; 1B
    adc detune_hi       ; 3B | Add signed high byte
    sta tmp_high        ; 3B
    lda tmp_low         ; 3B
    adc detune_lo       ; 3B | Add signed low byte
    sta tmp_low         ; 3B
    bcc skip_inc        ; 2B | Handle carry to high byte
    inc tmp_high        ; 3B
skip_inc:
    rts                 ; 1B

; 24-TET Period Table (Octave 0) - Oric Atmos 1MHz (62.5kHz AY clock)
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
