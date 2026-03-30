; ===========================================================================
; cmdAYUPDATE (Oric Atmos 6502A)
; Header Mask: [7:Spare, 6:Vol, 5:Mix, 4:Noise, 3:ChC, 2:ChB, 1:ChA, 0:Coarse]
; ===========================================================================
cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag (Bit 7) of ay_coarse
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #0
    sta ay_reg              ; Start at AY R0

@pitch_loop:
    lsr tmp_mask            ; Shift Channel bit (A, B, or C) into Carry
    jsr step_ay             ; Pitch Lo (R0, 2, 4) - pulls if C=1. Returns C=1 if pull.

    ; --- Pitch Hi Filter ---
    bcc @skip_hi            ; If Ch bit was 0, skip Pitch Hi entirely
    bit ay_coarse           ; Is Coarse bit (Bit 7) set?
    bmi @do_hi              ; If Coarse=1, we keep C=1 and pull Pitch Hi
    clc                     ; If Coarse=0, KILL Carry to skip Pitch Hi pull
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5) - pulls if C=1, else skips
    
@skip_hi:
    cmp #6                  ; A = ay_reg from step_ay
    bcc @pitch_loop

    ; --- R6: Noise (Bit 4) ---
    lsr tmp_mask
    jsr step_ay             ; A = 7

    ; --- R7: Mixer (Bit 5) ---
    lsr tmp_mask
    jsr step_ay             ; A = 8

    ; --- R8-10: Volume Block (Bit 6) ---
    lsr tmp_mask
    bcc @done
@vol_loop:
    sec                     ; Force pull for all 3 volume registers
    jsr step_ay
    cmp #11                 ; A = ay_reg
    bcc @vol_loop

@done:
    rts

; ---------------------------------------------------------------------------
; step_ay
; Carry 1 = Pull byte from stream & Update AY register [ay_reg]
; Carry 0 = Just Increment Index (Skip data pull)
; ALWAYS: Increments ay_reg, Returns A = new ay_reg
; ---------------------------------------------------------------------------
step_ay:
    bcc @only_inc
    ldy ipy
    lda (stream),y
    inc ipy
    ; TODO: Guard against ipy page-wrap (inc stream+1) if needed here.
    ldy ay_reg
    jsr setayr              ; Update AY chip (Assumes X is preserved)
    sec                     ; Set Carry for the caller (Pitch Hi check)
@only_inc:
    inc ay_reg
    lda ay_reg              ; Return current index in A
    rts

