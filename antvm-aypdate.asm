; ===========================================================================
; cmdAYUPDATE
; A = Mask ("Baseball" Header)
; ===========================================================================
cmdAYUPDATE:
    sta tmp_mask            ; Store header
    ldx #0                  ; Start at AY Register 0 (Pitch Lo A)

@pitch_loop:
    lsr tmp_mask            ; Shift Bits 1, 2, 3 (A, B, C) into Carry
    bcc @skip_channel       ; If bit 1-3 not set, no pitch update for this ch

    ; --- Pitch Lo ---
    txa
    tay                     ; Y = Target Register (0, 2, or 4)
    jsr pull_setayr

    ; --- Check Coarse (Bit 0) ---
    lda tmp_mask
    bit #%00000001          ; Check original Bit 0 (now at bit 0 of shifted)
    beq @skip_channel       ; Bit 0=0: Step 2 (Skip Pitch Hi)

    ; --- Pitch Hi (Coarse Update) ---
    txa
    clc
    adc #1                  ; Target 1, 3, or 5
    tay
    jsr pull_setayr

@skip_channel:
    inx
    inx                     ; Step by 2 (Registers 0, 2, 4)
    cpx #6
    bne @pitch_loop

    ; --- Bit 4: Volume (Global) ---
    lda tmp_mask
    and #%00010000          ; Bit 4 (was 5, shifted right once)
    beq @mixer_check
    
    ldy #8                  ; Start Volume at R8
@vol_loop:
    jsr pull_setayr
    iny                     ; Next Vol Register
    cpy #11
    bne @vol_loop

@mixer_check:
    lda tmp_mask
    and #%00100000          ; Bit 5 (was 6)
    beq @noise_check
    ldy #7
    jsr pull_setayr

@noise_check:
    lda tmp_mask
    and #%01000000          ; Bit 6 (was 7)
    beq @done
    ldy #6
    jsr pull_setayr

@done:
    rts

; ---------------------------------------------------------------------------
; pull_setayr
; Helper: Pulls byte from stream, calls setayr with register Y
; ---------------------------------------------------------------------------
pull_setayr:
    stx tmp_x               ; Save X (6502A has no PHX)
    ldy ipy
    lda (stream),y
    inc ipy
    ldy tmp_y_target        ; We need to pass the target reg in Y
    jsr setayr
    ldx tmp_x               ; Restore X
    rts

; ---------------------------------------------------------------------------
; Note: Since pull_setayr needs Y for the register index AND the 
; (stream),y indirect access, we'll swap them via a temp variable.
; ---------------------------------------------------------------------------

pull_setayr:
    sty tmp_reg             ; Save the target AY register
    ldy ipy
    lda (stream),y
    inc ipy
    ldy tmp_reg             ; Load target AY register for setayr
    jsr setayr
    rts
