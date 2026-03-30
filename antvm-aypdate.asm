; ===========================================================================
; cmdAYUPDATE (Oric Atmos 6502A)
; A = Mask ("Baseball" Header)
; Bit 0: Coarse, Bit 1-3: A,B,C, Bit 4: Vol, Bit 5: Noise (R6), Bit 6: Mixer (R7)
; ===========================================================================
cmdAYUPDATE:
    lsr                     ; Shift Bit 0 (Coarse) into Carry
    ror ay_coarse           ; Bit 0 now in Bit 7 (N Flag)
    sta tmp_mask            ; Store remaining bits
    
    lda #0
    sta ay_reg              ; Start at R0

@pitch_loop:
    lsr tmp_mask            ; Shift Bit 1, 2, or 3 into Carry
    bcc @skip_pitch         ; No update for this channel

    jsr pull_setayr         ; Updates Pitch Lo (R0, R2, or R4)
    bit ay_coarse           ; Check Coarse Flag (N)
    bpl @skip_hi            ; If 0, only Lo was in stream
    jsr pull_setayr         ; Updates Pitch Hi (R1, R3, or R5)
    jmp @next_ch

@skip_hi:
    inc ay_reg              ; Manual skip to next even reg index
    jmp @next_ch

@skip_pitch:
    inc ay_reg              ; Skip Lo index
    inc ay_reg              ; Skip Hi index

@next_ch:
    lda ay_reg
    cmp #6                  ; Loop for Channels A, B, C
    bcc @pitch_loop

    ; --- Global Volume (Bit 4) ---
    lsr tmp_mask
    bcc @noise_check        ; Skip volume block
    lda #8
    sta ay_reg
@vol_loop:
    jsr pull_setayr
    lda ay_reg
    cmp #11
    bne @vol_loop

@noise_check:
    lda #6                  ; Start at Noise (R6)
    sta ay_reg
    lsr tmp_mask            ; Bit 5 (Noise)
    bcc @mixer_check
    jsr pull_setayr         ; Updates R6, ay_reg becomes 7

@mixer_check:
    lsr tmp_mask            ; Bit 6 (Mixer)
    bcc @done
    jsr pull_setayr         ; Updates R7

@done:
    rts

; ---------------------------------------------------------------------------
; pull_setayr
; ---------------------------------------------------------------------------
pull_setayr:
    ldy ipy
    lda (stream),y
    inc ipy
    ldy ay_reg
    jsr setayr              ; Write A to Register Y
    inc ay_reg
    rts
