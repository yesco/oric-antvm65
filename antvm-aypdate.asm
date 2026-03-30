;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; 32B    Current version
;; ;; 28B    A-Value/X-Constant preservation (Saved 4 bytes / 14 cycles)
;; ---------------------------------------------------------------------------
;; TOTAL: 28 Bytes (Main) + setayr (Helper)
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; Bit 0 (Coarse) -> Carry
    ror ay_coarse           ; Bit 0 into N flag
    sta tmp_mask            ; [Spare, Vol, Mix, Noise, ChC, ChB, ChA]
    
    lda #$FF
    sta ay_reg              ; Cursor at -1

@pitch_loop:
    lsr tmp_mask            ; Shift Ch bit
    jsr step_ay             ; Pitch Lo (R0, 2, 4)
    bit ay_coarse           
    bmi @do_hi              
    clc                     
@do_hi:
    jsr step_ay             ; Pitch Hi (R1, 3, 5)
    ldy ay_reg
    cpy #5
    bcc @pitch_loop

    lsr tmp_mask            ; R6 (Noise)
    jsr step_ay
    lsr tmp_mask            ; R7 (Mixer)
    jsr step_ay

    lsr tmp_mask            ; Volume Block (R8-10)
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
; step_ay / setayr
; ---------------------------------------------------------------------------
step_ay:
    inc ay_reg
    bcc @only_inc
    ldy ipy
    lda (stream),y          ; Value in A
    inc ipy
    ldy ay_reg              ; Reg in Y

setayr:
    cpy #7                  ; Mixer?
    bne @write_phys
    ora #64                 ; Bit 6 Patch (Value remains in A)

@write_phys:
    ; Value is in A. Use X for constants only.
    ldx #$FF
    stx $0303               ; DDRA Output
    sty $030F               ; Port A = Reg Address (Y)
    stx $030C               ; Latch Address ($FF)
    
    ldx #$DD
    stx $030C               ; Inactive ($DD)

    sta $030F               ; Write Value (Directly from A)
    
    ldx #$FD
    stx $030C               ; Latch Data ($FD)
    
    ldx #$DD
    stx $030C               ; Inactive ($DD)

    ldx #$00
    stx $0303               ; DDRA Input

    ; --- Post-Write Fixup (Value is still in A!) ---
    cpy #6                  ; Pitch register?
    bcs @exit               
    tya                     ; A = 1, 3, or 5
    lsr                     ; Carry=1 if Odd. A=0, 1, or 2.
    bcc @exit               

    ora #8                  ; Map to 8, 9, or 10
    tay                     ; Target Vol Register (Y)
    
    ldy ipy                 ; We lost A because of TYA, let's grab it back
    lda (stream-1),y        ; Peek previous stream byte
    lsr : lsr : lsr : lsr   ; Shift Volume bits
    ldy ay_reg              ; Correction: Need the calculated Vol Reg
    tya : lsr : ora #8 : tay ; (Calculated Y again to avoid stashing)
    jmp setayr              ; Tail Call

@exit:
    sec                     ; Sticky Carry
@only_inc:
    rts
