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
    lsr tmp_mask            ; Shift Ch bit into Carry (1=Update, 0=Skip)
    
    ; --- Pitch Lo (R0, 2, 4) ---
    jsr step_ay             ; Updates if Carry=1. RE-SETS CARRY ON EXIT.

    ; --- Pitch Hi (R1, 3, 5) ---
    ; We check the same bit we just used for Lo (now restored in C)
    bcc @skip_hi            ; If Ch bit was 0, skip Pitch Hi entirely
    bit ay_coarse           ; Is Coarse bit (Bit 7) set?
    bpl @skip_hi            ; If Coarse=0, skip Pitch Hi data pull
    
    sec                     ; Ch=1 and Coarse=1: Force Carry for data pull
    jsr step_ay             ; Updates Pitch Hi (R1, 3, 5)
    jmp @next_ch

@skip_hi:
    inc ay_reg              ; Skip Pitch Hi register index

@next_ch:
    lda ay_reg              ; Loaded by step_ay or inc ay_reg
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
    cmp #11                 ; A = ay_reg
    bne @vol_loop

@done:
    rts

; ---------------------------------------------------------------------------
; step_ay
; Carry 1 = Pull & Update. Carry 0 = Just Increment Index.
; RETURNS: A = ay_reg, C = 1 (Forces carry for "sticky" decisions)
; ---------------------------------------------------------------------------
step_ay:
    bcc @only_inc
    ldy ipy
    lda (stream),y
    inc ipy
    ldy ay_reg
    jsr setayr              ; Update AY chip
    sec                     ; RE-SET CARRY for the caller (Pitch Hi check)
@only_inc:
    inc ay_reg
    lda ay_reg              ; Prepare A for caller's CMP check
    rts

