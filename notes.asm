;;; 35 B 12c - rol sequence is more compact than 4 lsr
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - Keeping hi in A during shifts saves 1 byte and 6c per loop
;;; 38 B 32c - keeping lo in A makes addition faster and saves 4 bytes
;;; 37 B 35c - Output in AX: A=Lo, X=Hi
;;; 35 B 30c - Using Y for temp storage instead of PHA/PLA saves 2 bytes
;;; 83 B 63-138c - Total Size (35 B code, 48 B table)

; Input: 
;   A = %OOONNNNN (Octave 0-7, Note 0-23)
;   detune_lo/hi = 16-bit signed offset
; Output: 
;   A = Pitch Low Byte
;   X = Pitch High Byte
calc_pitch:
    asl                 ; 2B | Note * 2, Bit 7 -> Carry
    tay                 ; 1B | Save Note*2
    and #%00111110      ; 2B | Mask Note index (0-46)
    tax                 ; 1B | X = table offset
    
    tya                 ; 1B | Restore note info
    rol                 ; 1B | Pull bits 7, 6, 5 into low 3 bits
    rol                 ; 1B 
    rol                 ; 1B 
    and #%00000111      ; 2B | A = Octave (0-7)
    tay                 ; 1B | Y = loop counter (0-7)

    lda period_table+1, x ; 3B | Load High byte first
    sta tmp_high          ; 3B | Store high byte to shift in memory
    lda period_table, x   ; 3B | Load Low byte into A for loop
    
octave_loop:
    dey                 ; 1B
    bmi pitch_done      ; 2B | If Y was 0, skip shifts
    lsr tmp_high        ; 5B | Shift high byte in memory
    ror                 ; 1B | Rotate Carry into A (low byte)
    jmp octave_loop     ; 3B

pitch_done:
    ; --- Optimized Detune Addition ---
    clc                 ; 1B
    adc detune_lo       ; 3B | A = Final Low Byte
    tay                 ; 1B | Use Y as temp for Low Byte
    lda tmp_high        ; 3B
    adc detune_hi       ; 3B | A = Final High Byte
    tax                 ; 1B | Move High Byte to X
    tya                 ; 1B | Move Low Byte back to A
    rts                 ; 1B

; 24-TET Period Table (Octave 0) - Oric Atmos 1MHz
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
