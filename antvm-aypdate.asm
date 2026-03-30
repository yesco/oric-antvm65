;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; 44B    "Dirty Write" exploit
;; ;; 41B    Tail-drop & Post-write fixup (Saved 3 bytes)
;; ---------------------------------------------------------------------------
;; TOTAL: 41 Bytes (Main) + setayr (Helper)
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #$FF
    sta ay_reg              ; Cursor at -1

@pitch_loop:
    lsr tmp_mask            ; Shift Ch bit
    jsr step_ay             ; R0, 2, 4
    bit ay_coarse           
    bmi @do_hi              
    clc                     
@do_hi:
    jsr step_ay             ; R1, 3, 5
    ldy ay_reg
    cpy #5
    bcc @pitch_loop

    lsr tmp_mask            ; R6
    jsr step_ay
    lsr tmp_mask            ; R7
    jsr step_ay

    lsr tmp_mask            ; Volume Block
    bcc @done
@vol_loop:
    sec
    jsr step_ay
    ldy ay_reg
    cpy #10
    bcc @vol_loop
@done:
    rts

; ---------------------------------------------------------------------------
; step_ay
; ---------------------------------------------------------------------------
step_ay:
    inc ay_reg
    bcc @only_inc
    ldy ipy
    lda (stream),y          ; Get Value (A)
    inc ipy
    ldy ay_reg              ; Prep Reg (Y)
setayr:
    ; Fall through to write_phys
; ---------------------------------------------------------------------------
; write_phys (The "Dirty Write" Bit-Banger)
; ---------------------------------------------------------------------------
write_phys:
    cpy #7                  ; Is it the Mixer?
    bne @not_mixer
    ora #64                 ; Bit 6 Patch
@not_mixer:
    ldx #$FF
    stx $0303               ; Output
    sty $030F               ; Address
    stx $030C               ; Latch Address
    ldx #$DD
    stx $030C               ; Inactive
    sta $030F               ; Value (Dirty or Clean)
    ldx #$FD
    stx $030C               ; Latch Data
    ldx #$DD
    stx $030C               ; Inactive
    ldx #$00
    stx $0303               ; Input

    ; --- Post-Write Fixup logic ---
    cpy #6                  ; Was it a pitch register?
    bcs @exit               ; No (Mixer/Vol/Noise), just leave
    tya                     
    lsr                     ; Is it Odd (1, 3, 5)?
    bcc @exit               ; No (0, 2, 4), just leave

    ; Extract Volume from the same A value and write to R8-10
    lsr
    lsr
    lsr                     ; Top 4 bits to bottom 4
    tax                     ; Stash Volume in X
    tya                     ; Reg 1, 3, 5
    lsr                     ; 0, 1, 2
    ora #8                  ; Map to 8, 9, 10
    tay                     ; New Register
    txa                     ; New Value (Volume)
    jmp write_phys          ; Tail Call to write Volume

@exit:
    sec                     ; Sticky Carry
@only_inc:
    rts
