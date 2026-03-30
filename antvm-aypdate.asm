;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; Final Optimized Logic (63 Bytes)
;; ===========================================================================
cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #0
    sta ay_reg              ; Start at AY R0

@pitch_loop:
    lsr tmp_mask            ; Shift Ch bit into Carry
    jsr step_ay             ; Pitch Lo (R0, 2, 4)

    bit ay_coarse           ; Check Coarse Flag (N)
    bmi @do_hi              ; If Coarse=1, pull Pitch Hi
    clc                     ; Else skip pull
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5)
    
    lda ay_reg              ; Return index for CMP
    cmp #6
    bcc @pitch_loop

    lsr tmp_mask            ; Bit 4: Noise (R6)
    jsr step_ay

    lsr tmp_mask            ; Bit 5: Mixer (R7)
    jsr step_ay

    lsr tmp_mask            ; Bit 6: Volume Block (R8-10)
    bcc @done
@vol_loop:
    sec
    jsr step_ay
    lda ay_reg
    cmp #11
    bcc @vol_loop

@done:
    rts

; ---------------------------------------------------------------------------
; step_ay (16 Bytes)
; ---------------------------------------------------------------------------
step_ay:
    bcc @only_inc
    ldy ipy                 ; Get stream pointer
    lda (stream),y
    inc ipy
    ; TODO: Guard against ipy page-wrap
    ldy ay_reg              ; Y = Register index
    inc ay_reg
    sec                     ; Set Carry for sticky logic
    jmp setayr              ; TAIL CALL

@only_inc:
    inc ay_reg
    rts

; ---------------------------------------------------------------------------
; setayr (Oric VIA bit-bang)
; Y = Register Index
; A = Value
; Trashes A, X. Preserves Y (optional, but safer for stream index).
; ---------------------------------------------------------------------------
setayr:
    tax                     ; X = Value to write
    cpy #7                  ; Is this the Mixer?
    bne @skip_r7
    txa
    ora #64                 ; Bit 6 MUST be 1 for Oric Mixer (Keyboard/Tape)
    tax
@skip_r7:

    ; 1. Select Register (Y)
    lda #$FF
    sta $0303               ; Port A to OUTPUT
    sty $030F               ; Port A = Register Number
    
    lda #$FF                ; Latch Address
    sta $030C
    lda #$DD                ; Inactive
    sta $030C

    ; 2. Write Value (X)
    stx $030F               ; Port A = Value
    lda #$FD                ; Latch Data
    sta $030C
    lda #$DD                ; Inactive
    sta $030C

    ; 3. Cleanup
    lda #0
    sta $0303               ; Port A to INPUT (Crucial for IRQ)
    rts
