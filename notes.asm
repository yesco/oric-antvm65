; Period table for Octave 4 (24 entries, 16-bit words)
; Calculated as: 62500 / (440 * 2^(n/24))
period_table:
    .word 142, 138, 134, 130, 126, 123, 119, 116, 112, 109, 106, 103
    .word 100, 97, 94, 91, 89, 86, 84, 81, 79, 77, 74, 72

calc_pitch:
    ; Input: A = note (3 bits octave, 5 bits note)
    pha             ; Save original
    and #%00011111  ; Mask note (0-23)
    asl             ; Multiply by 2 for word index
    tax
    lda period_table, x
    sta tmp_low
    lda period_table+1, x
    sta tmp_high

    pla             ; Get original back
    lsr             ; Shift to get octave
    lsr
    lsr
    lsr
    lsr             ; A now has octave (0-7)
    
    ; If note is Octave 4, we use table as is.
    ; If higher, we LSR (halve period). If lower, we ASL (double period).
    ; Simpler approach: normalize all notes to Octave 0 and shift down.
    ; Adjust the logic below based on your table's base octave.
    
    ; Example: Shift right for each octave > base
    ; ... bit manipulation logic here ...
    rts
