;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; 52B    Constant-X optimization
;; ;; 49B    X-Stash & ORA #8 optimization (Saved 3 bytes / 10+ cycles)
;; ---------------------------------------------------------------------------
;; TOTAL: 49 Bytes (Main) + setayr (Helper)
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #$FF
    sta ay_reg              ; Start cursor at -1

@pitch_loop:
    lsr tmp_mask            ; Shift Ch bit -> Carry
    jsr step_ay             ; Pitch Lo (R0, 2, 4)

    bit ay_coarse           ; Check Coarse Flag (N)
    bmi @do_hi              ; If Coarse=1, pull Pitch Hi
    clc                     ; Else skip pull
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5)
    
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
    lda (stream),y          ; Packed Value in A
    inc ipy
    ; TODO: Guard against ipy page-wrap

setayr:
    ldy ay_reg
    cpy #7                  ; Carry set if >= 7
    beq @is_mixer
    bcs @write_phys         ; Jump if R6, R8, R9, R10

    ; --- Volume Extraction (R1, 3, 5) ---
    tax                     ; STASH packed value in X
    tya                     ; Reg index (1, 3, 5)
    lsr                     ; Carry=1 if odd. A=0, 1, or 2.
    bcc @restore_and_write  ; Even? Restore A from X and write Pitch Lo
    
    ; Calculate Vol Reg (8, 9, 10)
    ora #8                  ; A = 8, 9, or 10. (ORA saves 1 byte over CLC/ADC)
    tay                     ; Y = Volume Register
    
    txa                     ; Get packed back
    lsr : lsr : lsr : lsr   ; A = Volume bits (4-7)
    jsr @write_phys         ; Write Volume to R8, 9, or 10
    
    ldy ay_reg              ; Restore original Register (1, 3, or 5)
    txa                     ; Get packed back
    and #$0F                ; A = Pitch Hi (0-3)
    jmp @write_phys         ; Write Pitch Hi and exit

@restore_and_write:
    txa                     ; Restore original value from X
    jmp @write_phys

@is_mixer:
    ora #64                 ; Bit 6 Patch

@write_phys:
    ; Value is in A.
    ldx #$FF
    stx $0303               ; DDRA Output
    sty $030F               ; Port A = Reg Address
    stx $030C               ; Latch Address ($FF)
    
    ldx #$DD                ; Inactive state
    stx $030C               

    sta $030F               ; Port A = Value
    
    ldx #$FD                ; Latch Data
    stx $030C               
    
    ldx #$DD                ; Inactive state
    stx $030C               

    ldx #$00
    stx $0303               ; DDRA Input
    sec                     ; Sticky Carry
@only_inc:
    lda ay_reg              ; Return index in A
    rts
