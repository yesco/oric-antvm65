;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; ~115B  Initial draft (Separate logic for A, B, C channels, many JMPs)
;; ;; 102B   Switched to X-index loop (Saved ~13 bytes)
;; ;; 94B    Replaced Bit-Table with LSR mask-shifting (Saved 8 bytes)
;; ;; 82B    Unified Pitch Lo/Hi calls via step_ay helper (Saved 12 bytes)
;; ;; 76B    Streamlined Mask bit-order (Noise -> Mixer -> Vol) (Saved 6 bytes)
;; ;; 72B    Refined "Sticky Carry" logic (Removed PHP/PLP) (Saved 4 bytes)
;; ;; 68B    Final linearized flow (Removed manual inc/lda/jmp) (Saved 4 bytes)
;; ---------------------------------------------------------------------------
;; TOTAL: 68 Bytes (plus helper)
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag (Bit 7) of ay_coarse
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #0
    sta ay_reg              ; Start at AY R0

@pitch_loop:
    lsr tmp_mask            ; Shift Channel bit (A, B, or C) into Carry
    jsr step_ay             ; Pitch Lo (R0, 2, 4). Pulls if C=1. Sets C=1 if pull.

    ; --- Pitch Hi Filter ---
    bit ay_coarse           ; Check Coarse Flag (N)
    bmi @do_hi              ; If Coarse=1, keep current Carry (the Ch status)
    clc                     ; If Coarse=0, KILL Carry to skip Pitch Hi data pull
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5). Pulls if C=1, else just INCs.
    
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
    sec                     ; Force pull for Volume block
    jsr step_ay
    cmp #11                 ; A = ay_reg
    bcc @vol_loop

@done:
    rts

; ---------------------------------------------------------------------------
; step_ay (16 Bytes)
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
    sec                     ; Set Carry for sticky logic (Pitch Hi check)
@only_inc:
    inc ay_reg
    lda ay_reg              ; Return current index in A
    rts
