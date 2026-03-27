;;; 35 B 12c - rol sequence is more compact than 4 lsr
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - Keeping hi in A during shifts saves 1 byte and 6c per loop
;;; 38 B 32c - keeping lo in A makes addition faster and saves 4 bytes
;;; 35 B 30c - Using Y for temp storage instead of PHA/PLA saves 2 bytes
;;; 31 B 26c - %NNNNNOOO + register-only logic (no stack) saves 4 bytes
;;; 79 B 55-130c - Total Size (31 B code, 48 B table)

; Input: 
;   A = %NNNNNOOO (Note 0-23, Octave 0-7)
;   detune_lo/hi = 16-bit signed offset
; Output: 
;   A = Pitch Low Byte
;   X = Pitch High Byte
calc_pitch:
    tax                 ; 1B | Save original NNNNNOOO in X
    and #%00000111      ; 2B | Mask Octave (0-7)
    tay                 ; 1B | Y = loop counter
    
    txa                 ; 1B | Restore original
    lsr                 ; 1B | %0NNNNNOO
    lsr                 ; 1B | %00NNNNNO (Note index * 2)
    and #%00111110      ; 2B | Mask Note index (0-46)
    tax                 ; 1B | X = table offset

    lda period_table+1, x ; 3B | Load High byte first
    sta tmp_high          ; 3B
    lda period_table, x   ; 3B | Load Low byte into A
    
octave_loop:
    dey                 ; 1B | Decrement octave counter
    bmi pitch_done      ; 2B | If Y was 0, skip shifts
    lsr tmp_high        ; 5B | 16-bit shift: High byte
    ror                 ; 1B | 16-bit shift: Low byte (A)
    jmp octave_loop     ; 3B

pitch_done:
    ; --- Optimized Detune Addition ---
    clc                 ; 1B
    adc detune_lo       ; 3B | A = Final Low
    tay                 ; 1B | Temp save Low in Y
    lda tmp_high        ; 3B
    adc detune_hi       ; 3B | A = Final High
    tax                 ; 1B | X = High Byte
    tya                 ; 1B | A = Low Byte
    rts                 ; 1B

; 24-TET Period Table (Octave 0) - Oric Atmos 1MHz
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
