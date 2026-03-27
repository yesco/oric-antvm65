;;; Size: 65 bytes (Code: 17, Table: 48)
;;; Cycles: ~45-120 (approx 9 cycles per octave shift)

; Input: A = %OOONNNNN (Octave 0-7, Note 0-23)
; Output: tmp_low/high (12-bit AY period)
calc_pitch:
    asl                 ; A = %OONNNNN0, bit 7 -> C
    tay                 ; Save to Y
    and #%00111110      ; Mask note index (0-46)
    tax                 ; X = table offset
    
    tya                 ; Restore %OONNNNN0
    rol                 ; Pull bit 7 into bit 0
    rol                 ; Next octave bit into bit 0
    rol                 ; Final octave bit into bit 0
    and #%00000111      ; A = Octave (0-7)
    tay                 ; Y = loop counter

    lda period_table, x
    sta tmp_low
    lda period_table+1, x
    sta tmp_high

octave_loop:
    dey                 ; Decrement counter
    bmi done            ; If Y was 0, it's now $FF (negative), so exit
    lsr tmp_high        ; 16-bit shift right (Halve period)
    ror tmp_low
    jmp octave_loop     ; Note: BNE octave_loop would also work if Y starts 1-8

done:
    rts

; 24-TET Period Table (Octave 0) - Oric Atmos 1MHz
; F_ay = 1,000,000 / 16 = 62,500Hz
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
