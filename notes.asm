;;; Size: 24 bytes (excluding table and setup)
;;; This approach is faster than the previous version because it uses 
;;; TAY/TAX to avoid extra PHA/PLA and uses a compact loop for octave scaling.

calc_pitch:
    ; Input: A = %OOONNNNN (3-bit Octave, 5-bit Note)
    asl             ; A = %OONNNNN0
    tay             ; Save shifted value to Y
    and #%00111110  ; Mask note index (0-46)
    tax             ; X = table index
    
    tya             ; Retrieve shifted value
    lsr             ; Shift Octave bits into position
    lsr
    lsr
    lsr
    and #%00000111  ; A = Octave (0-7)
    tay             ; Y = Loop counter for octave scaling

    lda period_table, x
    sta tmp_low
    lda period_table+1, x
    sta tmp_high

    ; Since table is Octave 0 (highest values), 
    ; we shift right (halve) for each octave.
octave_loop:
    cpy #0          ; If Octave 0, skip shifting
    beq done
    lsr tmp_high    ; Divide 16-bit period by 2
    ror tmp_low
    dey
    jmp octave_loop

done:
    rts
