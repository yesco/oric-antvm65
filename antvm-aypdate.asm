; ===========================================================================
; cmdAYUPDATE
; A = Mask ("Baseball" Header)
; ===========================================================================
cmdAYUPDATE:
    sta tmp_mask            ; Store header
    lsr                     ; Shift Bit 0 (Coarse) into Carry
    ror ay_coarse           ; Push it into Bit 7 of ay_coarse (N flag)
    
    lda #0
    sta ay_reg              ; Start at AY Register 0 (Pitch Lo A)

@pitch_loop:
    lsr tmp_mask            ; Shift Bits 1, 2, 3 (A, B, C) into Carry
    bcc @skip_channel       ; If bit not set, skip this channel's pitch

    ; --- Pitch Lo ---
    jsr pull_setayr         ; Updates R0, R2, or R4. ay_reg now points to Hi.

    ; --- Check Coarse (N flag of ay_coarse) ---
    bit ay_coarse           ; Check Bit 7
    bpl @skip_hi            ; If Bit 7=0 (Low Update), skip Pitch Hi

    ; --- Pitch Hi (Coarse Update) ---
    jsr pull_setayr         ; Updates R1, R3, or R5. ay_reg now points to next Lo.
    jmp @next_ch

@skip_hi:
    inc ay_reg              ; Skip the Pitch Hi register index

@skip_channel:
    ; If we skipped the channel, we must move ay_reg past both Lo and Hi
    ; Note: pull_setayr already INCs once, so we adjust accordingly.
    ; Since we got here via BCC or BPL, we need to manually step ay_reg.
    lda ay_reg
    clc
    adc #2
    and #%11111110          ; Ensure we land on an even register (0, 2, 4)
    sta ay_reg

@next_ch:
    lda ay_reg
    cmp #6                  ; Done with Pitch A, B, and C?
    bcc @pitch_loop

    ; --- Bit 4: Volume (Global) ---
    lda tmp_mask
    and #%00010000          ; Original Bit 4 (shifted)
    beq @mixer_check
    
    lda #8
    sta ay_reg
@vol_loop:
    jsr pull_setayr
    lda ay_reg
    cmp #11
    bne @vol_loop

@mixer_check:
    lda tmp_mask
    and #%00100000          ; Original Bit 5 (shifted)
    beq @noise_check
    lda #7
    sta ay_reg
    jsr pull_setayr

@noise_check:
    lda tmp_mask
    and #%01000000          ; Original Bit 6 (shifted)
    beq @done
    lda #6
    sta ay_reg
    jsr pull_setayr

@done:
    rts

; ---------------------------------------------------------------------------
; pull_setayr
; Helper: Pulls byte from stream, calls setayr with register Y, then INCs ay_reg
; ---------------------------------------------------------------------------
pull_setayr:
    ldy ipy                 ; Current stream offset
    lda (stream),y          ; Get data
    inc ipy                 ; Advance stream
    ; (If ipy can wrap 255->0, add page-cross logic here)
    ldy ay_reg              ; Get target AY register
    jsr setayr              ; Update chip
    inc ay_reg              ; Point to next AY register
    rts
