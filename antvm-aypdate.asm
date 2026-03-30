;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; ~115B  Initial draft
;; ;; ...
;; ;; 61B    Integrated step_ay into setayr header
;; ;; 58B    Combined CPY #7 logic for Mixer and Pitch Hi (Saved 3 bytes)
;; ---------------------------------------------------------------------------
;; TOTAL: 58 Bytes (Main) + setayr (Helper)
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #$FF
    sta ay_reg              ; Start at -1 for first INC

@pitch_loop:
    lsr tmp_mask            ; Shift Channel bit into Carry
    jsr step_ay             ; Pitch Lo (R0, 2, 4)

    bit ay_coarse           ; Check Coarse Flag (N)
    bmi @do_hi              ; If Coarse=1, pull Pitch Hi
    clc                     ; Else skip pull
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5)
    
    lda ay_reg
    cmp #5                  ; CMP with 5 (Registers 0-5)
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
    bcc @only_inc           ; If Carry=0, skip data pull
    
    ldy ipy
    lda (stream),y          ; Pull value from stream
    inc ipy
    ; TODO: Guard against ipy page-wrap

setayr:
    ldy ay_reg              ; Y = Register Index
    cpy #7                  ; --- ONE COMPARE TO RULE THEM ALL ---
    beq @is_mixer           ; If Y=7, patch bit 6
    bcs @write_phys         ; If Y > 7 (Noise/Vol), skip extraction

    ; --- Volume Extraction (R1, 3, 5) ---
    tya
    lsr                     ; Check if Register is ODD (1, 3, 5)
    bcc @write_phys         ; Even? Just write Pitch Lo.
    
    tax                     ; Save original A (Packed) in X
    lsr : lsr : lsr : lsr   ; A = Volume (Bits 4-7)
    pha                     ; Save Volume Value
    txa                     ; A = Packed
    and #$0F                ; A = Pitch Hi (Bits 0-3)
    pha                     ; Save Pitch Hi Value
    
    tya : lsr : clc : adc #8 ; Map R1,3,5 -> R8,9,10
    tay                     ; Y = Volume Register
    pla                     ; A = Pitch Hi
    tax                     ; X = Pitch Hi
    pla                     ; A = Volume
    jsr @write_phys         ; Write Volume first
    
    ldy ay_reg              ; Restore original Register Index
    txa                     ; Restore Pitch Hi Value to A
    jmp @write_phys         ; Write Pitch Hi and exit

@is_mixer:
    ora #64                 ; Bit 6 Patch for Oric hardware

@write_phys:
    tax                     ; X = Value to write
    lda #$FF
    sta $0303               ; DDRA = Output
    sty $030F               ; Port A = Address
    lda #$FF : sta $030C    ; Latch Address
    lda #$DD : sta $030C    ; Inactive
    
    stx $030F               ; Port A = Data Value
    lda #$FD : sta $030C    ; Latch Data
    lda #$DD : sta $030C    ; Inactive
    
    lda #0
    sta $0303               ; DDRA = Input
    sec                     ; Set Carry for sticky logic
@only_inc:
    lda ay_reg              ; Return index in A
    rts
