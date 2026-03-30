; ===========================================================================
; cmdAYUPDATE (Oric Atmos 6502A)
; A = Mask ("Baseball" Header)
; ===========================================================================
cmdAYUPDATE:
    lsr                     ; Shift Bit 0 (Coarse) into Carry
    ror ay_coarse           ; Bit 0 is now in Bit 7 of ay_coarse (N Flag)
    sta tmp_mask            ; Store remaining bits
    
    lda #0
    sta ay_reg              ; Start at R0

@pitch_loop:
    lsr tmp_mask            ; Shift Bit 1, 2, or 3 into Carry
    bcc @skip_pitch         ; If 0, don't pull from stream

    ; --- Pitch Lo ---
    jsr pull_setayr         ; Updates R0, R2, or R4

    ; --- Pitch Hi Check ---
    bit ay_coarse           ; Check Bit 7 (Coarse Flag)
    bpl @skip_hi            ; If 0, only Lo was in stream
    jsr pull_setayr         ; Updates R1, R3, or R5
    jmp @next_ch            ; Already at next even reg

@skip_hi:
    inc ay_reg              ; Manual skip to next even reg
    jmp @next_ch

@skip_pitch:
    inc ay_reg              ; Skip Lo
    inc ay_reg              ; Skip Hi

@next_ch:
    lda ay_reg
    cmp #6                  ; Loop for Channels A, B, C
    bcc @pitch_loop

    ; --- Global Volume (Bit 4) ---
    lsr tmp_mask
    bcc @mixer_check
    lda #8
    sta ay_reg
@vol_loop:
    jsr pull_setayr
    lda ay_reg
    cmp #11
    bne @vol_loop

@mixer_check:
    lsr tmp_mask            ; Bit 5
    bcc @noise_check
    lda #7
    sta ay_reg
    jsr pull_setayr

@noise_check:
    lsr tmp_mask            ; Bit 6
    bcc @done
    lda #6
    sta ay_reg
    jsr pull_setayr

@done:
    rts

; ---------------------------------------------------------------------------
; pull_setayr
; Helper: Pulls byte from stream, calls setayr with reg Y, then INCs ay_reg
; ---------------------------------------------------------------------------
pull_setayr:
    ldy ipy
    lda (stream),y
    inc ipy                 ; (Oric Atmos page-cross check here if needed)
    ldy ay_reg
    jsr setayr              ; X is assumed saved by setayr or not used
    inc ay_reg
    rts
