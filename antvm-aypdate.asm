cmdAYUPDATE:
    sta tmp_mask            ; Store the "Baseball" header
    ldx #0                  ; X = Channel offset (0, 2, 4)

@channel_loop:
    lda tmp_mask
    bit bit_table,x         ; Check if Channel A, B, or C bit is set (Bits 1,2,3)
    beq @next_ch            ; Skip if bit not set

    ; --- Pitch Low ---
    txy                     ; Y = 0, 2, or 4 (Pitch Lo Reg)
    jsr pull_setayr

    ; --- High Update vs Low Update ---
    lda tmp_mask
    lsr                     ; Shift Bit 0 (Coarse) into Carry
    bcc @low_update

@high_update:
    txy
    iny                     ; Y = 1, 3, or 5 (Pitch Hi/Vol Reg)
    jsr pull_setayr
    jmp @next_ch

@low_update:
    lda tmp_mask
    and #%00010000          ; Check Bit 4 (Volume Flag)
    beq @next_ch
    
    ; Map X(0,2,4) to Y(8,9,10) for Volume
    txa
    lsr                     ; A = 0, 1, 2
    clc
    adc #8                  ; A = 8, 9, 10
    tay
    jsr pull_setayr

@next_ch:
    inx
    cpx #3                  ; Loop 3 times (for bits 1, 2, 3)
    bne @channel_loop

    ; --- Mixer (Bit 5) ---
    lda tmp_mask
    and #%00100000
    beq @check_noise
    ldy #7
    jsr pull_setayr

@check_noise:
    ; --- Noise (Bit 6) ---
    lda tmp_mask
    and #%01000000
    beq @done
    ldy #6
    jsr pull_setayr

@done:
    rts

; Table to check bits 1, 2, 3 (A, B, C) based on X=0,1,2
bit_table: .byte %00000010, %00000100, %00001000
