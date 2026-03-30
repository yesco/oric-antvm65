; ===========================================================================
; cmdAYUPDATE (Oric Atmos 6502A)
; Mask: [7:Spare, 6:Vol, 5:Mix, 4:Noise, 3:ChC, 2:ChB, 1:ChA, 0:Coarse]
; ===========================================================================
cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag (Bit 7) of ay_coarse
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #0
    sta ay_reg              ; Start at R0

@pitch_loop:
    lsr tmp_mask            ; Shift Ch bit (A, B, or C) into Carry
    php                     ; SAVE CARRY (The "Update this Channel" decision)
    
    ; --- Pitch Lo (R0, 2, 4) ---
    jsr step_ay             ; Uses Carry, updates R0/2/4, INCs ay_reg

    ; --- Pitch Hi (R1, 3, 5) ---
    plp                     ; RESTORE CARRY (Was this channel updated?)
    bcc @skip_hi            ; If Ch bit was 0, skip Pitch Hi
    
    bit ay_coarse           ; Is Coarse bit set?
    bpl @skip_hi            ; If Coarse=0, skip Pitch Hi
    
    sec                     ; Both Ch bit and Coarse are 1: Pull Pitch Hi
    jsr step_ay             ; Updates R1/3/5, INCs ay_reg
    jmp @next_ch

@skip_hi:
    inc ay_reg              ; Manual skip to next Even register

@next_ch:
    lda ay_reg              ; Loaded by step_ay or manually here
    cmp #6
    bcc @pitch_loop

    ; --- R6: Noise (Bit 4) ---
    lsr tmp_mask
    jsr step_ay

    ; --- R7: Mixer (Bit 5) ---
    lsr tmp_mask
    jsr step_ay

    ; --- R8-10: Volume Block (Bit 6) ---
    lsr tmp_mask
    bcc @done
@vol_loop:
    sec                     ; Force pull for Volume block
    jsr step_ay
    cmp #11                 ; A is already ay_reg from step_ay
    bne @vol_loop

@done:
    rts

; ---------------------------------------------------------------------------
; step_ay
; Carry 1 = Pull & Update. Carry 0 = Skip.
; Returns: A = ay_reg (for easy CMP testing)
; ---------------------------------------------------------------------------
step_ay:
    bcc @only_inc
    ldy ipy
    lda (stream),y
    inc ipy
    ldy ay_reg
    jsr setayr              ; Update AY chip
@only_inc:
    inc ay_reg
    lda ay_reg              ; Prepare A for caller's CMP check
    rts
