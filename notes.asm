;;; 35 B 12c - rol sequence is more compact than 4 lsr
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - Keeping hi in A during shifts saves 1 byte and 6c per loop
;;; 80 B 39-114c - Total Size (32 B code, 48 B table)

; Input: A = %OOONNNNN (Octave 0-7, Note 0-23)
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
    sta tmp_high        ; 3B | Save final High byte from A
    rts                 ; 1B

; 24-TET Period Table (Octave 0) - Oric Atmos 1MHz
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
