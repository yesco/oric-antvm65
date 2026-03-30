;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; ~115B  Initial draft
;; ;; ...
;; ;; 58B    Combined CPY #7 logic
;; ;; 52B    Constant-X optimization in setayr (Saved 6 bytes)
;; ---------------------------------------------------------------------------
;; TOTAL: 52 Bytes (Main) + setayr (Helper)
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #$FF
    sta ay_reg              ; Start at -1

@pitch_loop:
    lsr tmp_mask            ; Shift Channel bit -> Carry
    jsr step_ay             ; Pitch Lo (R0, 2, 4)

    bit ay_coarse           ; Check Coarse Flag (N)
    bmi @do_hi              ; If Coarse=1, pull Pitch Hi
    clc                     ; Else skip pull
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5)
    
    lda ay_reg
    cmp #5                  ; Loop R0-R5
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
; step_ay / setayr
; ---------------------------------------------------------------------------
step_ay:
    inc ay_reg
    bcc @only_inc
    
    ldy ipy
    lda (stream),y          ; Value in A
    inc ipy
    ; TODO: Guard against ipy page-wrap

setayr:
    ldy ay_reg
    cpy #7                  ; Carry set if >= 7
    beq @is_mixer
    bcs @write_phys         ; Jump if R6, R8, R9, R10

    ; --- Volume Extraction (R1, 3, 5) ---
    tya
    lsr                     ; Odd? (1, 3, 5)
    bcc @write_phys         ; No, write Pitch Lo
    
    ; Split A (Packed) into Pitch (X) and Volume (A)
    pha                     ; Save Packed
    and #$0F                ; A = Pitch Hi
    tax                     ; X = Pitch Hi
    pla                     ; A = Packed
    lsr : lsr : lsr : lsr   ; A = Volume
    pha                     ; Save Volume
    
    tya : lsr : clc : adc #8 ; Map to R8,9,10
    tay                     ; Y = Volume Register
    pla                     ; A = Volume
    jsr @write_phys         ; Recursive write
    
    ldy ay_reg              ; Restore R1, 3, or 5
    txa                     ; A = Pitch Hi
    jmp @write_phys

@is_mixer:
    ora #64                 ; Bit 6 Patch

@write_phys:
    ; Value is in A. Use X for constants to save bytes.
    ldx #$FF
    stx $0303               ; Port A to Output
    sty $030F               ; Port A = Address
    stx $030C               ; Latch Address ($FF)
    
    ldx #$DD                ; Inactive state
    stx $030C               

    sta $030F               ; Port A = Value (from A)
    
    ldx #$FD                ; Latch Data
    stx $030C               
    
    ldx #$DD                ; Inactive state
    stx $030C               

    ldx #$00
    stx $0303               ; Port A to Input
    sec                     ; Sticky Carry
@only_inc:
    lda ay_reg              ; For CMP
    rts
