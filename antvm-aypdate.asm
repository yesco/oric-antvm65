; --- Optimized Stream Puller ---
pull_byte:
    ldy ipy
    lda (stream),y
    inc ipy
    rts

cmdAYUPDATE:
    sta tmp_mask            ; Header in A
    
    ; --- Bits 1, 2, 3: Pitch Updates ---
    ldx #0                  ; X = Channel (0, 1, 2)
@pitch_loop:
    lda tmp_mask
    and bit_table,x         ; Check bits 1, 2, or 3
    beq @skip_pitch
    
    ; Pull Pitch Lo
    jsr pull_byte
    pha                     ; Save Pitch Lo value
    txa
    asl                     ; A = 0, 2, 4
    tay                     ; Y = Target Reg
    pla                     ; Restore Pitch Lo value
    jsr setayr

    ; Check Coarse Flag (Bit 0)
    lda tmp_mask
    lsr                     ; Bit 0 -> Carry
    bcc @skip_pitch         ; If Coarse=0, Pitch Hi is NOT in stream

    ; Pull Pitch Hi + Vol (Coarse Update)
    jsr pull_byte
    pha
    txa
    asl
    clc
    adc #1                  ; A = 1, 3, 5
    tay                     ; Y = Target Reg
    pla
    jsr setayr

@skip_pitch:
    inx
    cpx #3
    bne @pitch_loop

    ; --- Bit 4: Global Volume Update ---
    lda tmp_mask
    and #%00010000          ; Vol bit set?
    beq @mixer_check
    
    ldx #8                  ; Volume Registers start at 8
@vol_loop:
    jsr pull_byte
    tay                     ; Y = 8, 9, 10
    jsr setayr
    inx
    txa
    tay                     ; Prep Y for next loop/setayr
    cpx #11
    bne @vol_loop

@mixer_check:
    ; --- Bit 5: Mixer (R7) ---
    lda tmp_mask
    and #%00100000
    beq @noise_check
    jsr pull_byte
    ldy #7
    jsr setayr

@noise_check:
    ; --- Bit 6: Noise (R6) ---
    lda tmp_mask
    and #%01000000
    beq @done
    jsr pull_byte
    ldy #6
    jsr setayr

@done:
    rts

bit_table: .byte %00000010, %00000100, %00001000
