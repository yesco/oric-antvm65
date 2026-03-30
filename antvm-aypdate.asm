;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; ~115B  Initial draft
;; ;; ...
;; ;; 64B    Moved index to X for step_ay tail-call
;; ;; 61B    Integrated step_ay into setayr header (Saved 3 bytes)
;; ---------------------------------------------------------------------------
;; TOTAL: 61 Bytes (Main) + setayr (Helper)
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #$FF
    sta ay_reg              ; Start at -1 so first INC hits 0

@pitch_loop:
    lsr tmp_mask            ; Shift Ch bit into Carry
    jsr step_ay             ; Pitch Lo (R0, 2, 4)

    bit ay_coarse           ; Check Coarse Flag (N)
    bmi @do_hi              ; If Coarse=1, pull Pitch Hi
    clc                     ; Else skip pull
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5)
    
    lda ay_reg
    cmp #5                  ; CMP with 5 because we're at R5 after 3 loops
    bcc @pitch_loop

    lsr tmp_mask            ; Bit 4: Noise (R6)
    jsr step_ay

    lsr tmp_mask            ; Bit 5: Mixer (R7)
    jsr step_ay

    lsr tmp_mask            ; Bit 6: Volume Block (R8-10)
    bcc @done
@vol_loop:
    sec                     ; Force pull
    jsr step_ay
    lda ay_reg
    cmp #10
    bcc @vol_loop

@done:
    rts

; ---------------------------------------------------------------------------
; step_ay / setayr entry
; ---------------------------------------------------------------------------
step_ay:
    inc ay_reg              ; Move to next register index
    bcc @only_inc           ; If Carry=0, we are just skipping the data pull
    
    ldy ipy
    lda (stream),y          ; Pull value from stream
    inc ipy
    ; TODO: Guard against ipy page-wrap
    
    ; --- Fall through to setayr ---
setayr:
    pha                     ; Save Value
    ldy ay_reg              ; Y = Register Index
    
    ; --- Volume Extraction for Coarse Hi-bytes (R1, 3, 5) ---
    cpy #6
    bcs @not_pitch_hi
    tya
    lsr                     ; Is it odd? (1, 3, or 5)
    bcc @not_pitch_hi
    
    pla                     ; Get Value
    pha                     ; Keep copy
    lsr : lsr : lsr : lsr   ; Extract Vol bits (4-7)
    tax                     ; X = Volume Value
    tya                     ; A = 1, 3, or 5
    lsr                     ; A = 0, 1, or 2
    clc : adc #8            ; A = 8, 9, or 10
    tay                     ; Y = Target Volume Register
    txa                     ; A = Volume Value
    jsr @write_phys         ; Write Volume
    
    pla                     ; Get original value
    and #$0F                ; Keep Pitch bits (0-3)
    pha
    ldy ay_reg              ; Restore original Register Index

@not_pitch_hi:
    pla                     ; Final Value to write
    cpy #7                  ; Mixer?
    bne @write_phys
    ora #64                 ; Bit 6 Patch

@write_phys:
    tax                     ; X = Value
    lda #$FF
    sta $0303               ; DDRA = Output
    sty $030F               ; Port A = Address
    lda #$FF : sta $030C    ; Latch Address
    lda #$DD : sta $030C    ; Inactive
    
    stx $030F               ; Port A = Value
    lda #$FD : sta $030C    ; Latch Data
    lda #$DD : sta $030C    ; Inactive
    
    lda #0
    sta $0303               ; DDRA = Input
    sec                     ; PRESERVE CARRY for the caller!
@only_inc:
    lda ay_reg              ; Return index in A for CMPs
    rts
