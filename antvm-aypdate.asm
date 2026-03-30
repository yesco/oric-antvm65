; ===========================================================================
; cmdAYUPDATE
; A = Mask ("Baseball" Header)
; ===========================================================================
cmdAYUPDATE:
    sta tmp_mask            ; Store header
    lda #0
    sta ay_reg              ; Start at AY Register 0 (Pitch Lo A)

@pitch_loop:
    lsr tmp_mask            ; Shift Bits 1, 2, 3 (A, B, C) into Carry
    bcc @skip_channel       ; If bit 1-3 not set, no pitch update

    ; --- Pitch Lo ---
    jsr pull_setayr         ; Uses ay_reg, then INCs ay_reg

    ; --- Check Coarse (Bit 0) ---
    lda tmp_mask
    lsr                     ; Shift Bit 0 into Carry
    bcc @skip_hi            ; Bit 0=0: Low Update (skip Pitch Hi)
    
    ; --- Pitch Hi (Coarse Update) ---
    jsr pull_setayr         ; Register is already ay_reg (1, 3, or 5)
    
    ; Since we shifted Bit 0 out to check it, we must put it BACK
    ; so the next channel in the loop can see it!
    sec                     ; Set carry to put Bit 0 back
    ror tmp_mask            ; Rotate it back into position
    jmp @next_ch

@skip_hi:
    inc ay_reg              ; Skip the Pitch Hi register index
    clc
    ror tmp_mask            ; Put a 0 back into Bit 0 for next channel

@skip_channel:
    inc ay_reg              ; Move past Pitch Lo
    inc ay_reg              ; Move past Pitch Hi

@next_ch:
    lda ay_reg
    cmp #6                  ; Done with Pitch A, B, and C?
    bcc @pitch_loop

    ; --- Bit 4: Volume (Global) ---
    lda tmp_mask
    and #%00010000          ; Check original Bit 4 (now shifted)
    beq @mixer_check
    
    lda #8
    sta ay_reg              ; Volume Registers 8, 9, 10
@vol_loop:
    jsr pull_setayr
    lda ay_reg
    cmp #11
    bne @vol_loop

@mixer_check:
    lda tmp_mask
    and #%00100000          ; Bit 5
    beq @noise_check
    lda #7
    sta ay_reg
    jsr pull_setayr

@noise_check:
    lda tmp_mask
    and #%01000000          ; Bit 6
    beq @done
    lda #6
    sta ay_reg
    jsr pull_setayr

@done:
    rts

; ---------------------------------------------------------------------------
; pull_setayr
; Helper: Pulls byte using IPY, updates AY register in ay_reg, then INCs ay_reg
; ---------------------------------------------------------------------------
pull_setayr:
    ldy ipy                 ; Current stream offset
    lda (stream),y          ; Get data
    inc ipy                 ; Advance stream
    ldy ay_reg              ; Get target AY register
    jsr setayr              ; Update chip
    inc ay_reg              ; Point to next AY register
    rts

