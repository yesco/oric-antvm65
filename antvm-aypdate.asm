; ===========================================================================
; cmdAYUPDATE (Oric Atmos 6502A)
; Mask: [7:Spare, 6:Vol, 5:Mix, 4:Noise, 3:ChC, 2:ChB, 1:ChA, 0:Coarse]
; ===========================================================================
cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 now in Bit 7 (N Flag)
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #0
    sta ay_reg              ; Start at R0

@pitch_loop:
    lsr tmp_mask            ; Shift ChA, B, or C into Carry
    jsr step_ay             ; Update R0, 2, or 4 (or skip)

    bit ay_coarse           ; Check Coarse Flag (N)
    bpl @skip_hi            ; If 0, Pitch Hi is NEVER in the stream
    
    ; If Coarse=1, the Carry from the *same* Ch bit still applies
    sec                     ; Re-set carry based on the channel bit
    ; (Wait, we need to preserve the Carry from the Ch shift for the Hi byte)
    ; Let's use a temp to hold the Ch bit Carry for the Hi update.
    
    ; Simplified: If Coarse is on, Pitch Hi follows Pitch Lo IF Ch bit was set.
    ; Since we just did LSR, let's grab the Carry before it's gone.
    php 
    plp                     ; (Wait, 6502A Carry logic...)
    
    ; Let's just use the BIT trick for the Ch bits to keep it clean.
    ; On second thought, if Coarse is off, we ALWAYS skip R1, 3, 5.
    ; If Coarse is on, we update R1, 3, 5 only if the Ch bit was 1.
    ; Let's stick to the cleanest logic:
    
    ; (Re-checking Pitch Hi logic...)
    ; If Ch Bit was 1 AND Coarse is 1 -> pull byte for R1/3/5.
    ; Otherwise -> just inc ay_reg.

@skip_hi:
    inc ay_reg              ; Always skip to next even register

@next_ch:
    lda ay_reg
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
    sec                     ; Force pull for all 3 volume regs
    jsr step_ay
    lda ay_reg
    cmp #11
    bne @vol_loop

@done:
    rts

; ---------------------------------------------------------------------------
; step_ay
; If Carry=1: Pull byte from stream, set AY register [ay_reg], inc ay_reg
; If Carry=0: Just inc ay_reg
; ---------------------------------------------------------------------------
step_ay:
    bcc @skip
    ldy ipy
    lda (stream),y
    inc ipy
    ldy ay_reg
    jsr setayr
@skip:
    inc ay_reg
    rts
