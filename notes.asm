;;; Size: 67 bytes (Code: 19, Table: 48)
;;; Cycles: ~50-130 (Highly dependent on Octave value)

; Input: A = %OOONNNNN (Octave 0-7, Note 0-23)
; Output: tmp_low/high contain 12-bit AY period
calc_pitch:
    asl                 ; 2 cyc | A = %OONNNNN0, C = Octave bit 2
    tay                 ; 2 cyc | Save for octave extraction
    and #%00111110      ; 2 cyc | Mask Note index (0-46)
    tax                 ; 2 cyc | X = table offset
    
    tya                 ; 2 cyc | Restore
    rol                 ; 2 cyc | C -> bit 0, Octave bit 1 -> C
    rol                 ; 2 cyc | C -> bit 0, Octave bit 0 -> C
    rol                 ; 2 cyc | C -> bit 0. A bits 0-2 = Octave
    and #%00000111      ; 2 cyc | Clean A
    tay                 ; 2 cyc | Y = shift counter (0-7)

    lda period_table, x   ; 4 cyc
    sta tmp_low           ; 3 cyc
    lda period_table+1, x ; 4 cyc
    sta tmp_high          ; 3 cyc

octave_loop:
    cpy #0              ; 2 cyc
    beq done            ; 2/3 cyc
    lsr tmp_high        ; 5 cyc | 16-bit shift right
    ror tmp_low         ; 5 cyc
    dey                 ; 2 cyc
    jmp octave_loop     ; 3 cyc
done:
    rts                 ; 6 cyc

; 24-TET Period Table for Oric (1MHz) - Octave 0
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
