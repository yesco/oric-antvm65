; ===========================================================================
; cmdAYUPDATE
; A = Mask ("Baseball" Header)
; ===========================================================================
cmdAYUPDATE:
    lsr                     ; Shift Bit 0 (Coarse) into Carry
    ror ay_coarse           ; Bit 0 is now in Bit 7 of ay_coarse (N Flag)
    sta tmp_mask            ; Store remaining bits (A, B, C, Vol, Mix, Noise)
    
    lda #0
    sta ay_reg              ; Start at AY Register 0 (Pitch Lo A)

@pitch_loop:
    lsr tmp_mask            ; Shift next bit (A, then B, then C) into Carry
    bcc @skip_channel       ; If Carry=0, no pitch update for this channel

    ; --- Pitch Lo ---
    jsr pull_setayr         ; Updates R0, 2, or 4. INCs ay_reg.

    ; --- Check Coarse (N flag of ay_coarse) ---
    bit ay_coarse           ; Test Bit 7
    bpl @skip_hi            ; If Bit 7=0 (Low Update), skip Pitch Hi

    ; --- Pitch Hi (Coarse Update) ---
    jsr pull_setayr         ; Updates R1, 3, or 5. INCs ay_reg.
    jmp @next_ch

@skip_hi:
    inc ay_reg              ; Skip Pitch Hi register index

@skip_channel:
    ; We need to ensure ay_reg points to the NEXT Pitch Lo (0->2, 2->4)
    ; Since pull_setayr and skip_hi might have moved it, we force alignment.
    lda ay_reg
    clc
    adc #1
    and #%11111110          ; Force to next even register (0, 2, 4)
    sta ay_reg

@next_ch:
    lda ay_reg
    cmp #6                  ; Done with Pitch A, B, and C?
    bcc @pitch_loop

    ; --- Bit 4: Volume (Global) ---
    lsr tmp_mask            ; Shift Bit 4 (Volume) into Carry
    bcc @mixer_check
    
    lda #8
    sta ay_reg
@vol_loop:
    jsr pull_setayr
    lda ay_reg
    cmp #11
    bne @vol_loop

@mixer_check:
    lsr tmp_mask            ; Shift Bit 5 (Mixer) into Carry
    bcc @noise_check
    lda #7
    sta ay_reg
    jsr pull_setayr

@noise_check:
    lsr tmp_mask            ; Shift Bit 6 (Noise) into Carry
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
    inc ipy                 ; Oric: Add page-cross check here if needed!
    ldy ay_reg
    jsr setayr
    inc ay_reg
    rts
