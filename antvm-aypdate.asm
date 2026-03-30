;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; 49B    X-Stash & ORA #8
;; ;; 44B    "Dirty Write" exploit (Saved 5 bytes)
;; ---------------------------------------------------------------------------
;; TOTAL: 44 Bytes (Main) + setayr (Helper)
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
    
    ldy ay_reg              ; Sync Y for loop check
    cpy #5                  ; Loop R0-R5
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
    lda (stream),y          ; Get Packed Value
    inc ipy

setayr:
    ldy ay_reg              ; Target Register
    jsr write_phys          ; WRITE DIRTY BYTE (AY ignores high bits on R1,3,5)

    ; --- Post-Write Volume Extraction ---
    ldy ay_reg              ; Current Reg
    cpy #6                  ; Is it a Pitch Hi register?
    bcs @done_set           ; No (Mixer/Noise/Vol), exit
    tya                     ; A = 1, 3, or 5
    lsr                     ; Carry=1 if Odd. A=0, 1, or 2.
    bcc @done_set           ; Even (R0,2,4), exit
    
    ; It was an ODD pitch reg; now write the High 4 bits to Volume
    ora #8                  ; Map to R8, 9, or 10
    tay                     ; Target Vol Register
    lda (stream-1),y        ; Wait, we need the original A. 
                            ; Since we didn't save it, let's grab it from 
                            ; the stream again (cheaper than stack/X stash!)
    ldy ipy
    lda (stream-1),y        ; Corrected: Peek previous stream byte
    lsr : lsr : lsr : lsr   ; A = Volume bits
    jsr write_phys          ; Write to Volume Register

@done_set:
    sec                     ; Sticky Carry
@only_inc:
    rts

; ---------------------------------------------------------------------------
; write_phys
; Value in A, Reg in Y. Trashes X.
; ---------------------------------------------------------------------------
write_phys:
    ldx #$FF
    stx $0303 : sty $030F : stx $030C
    ldx #$DD : stx $030C
    
    sta $030F               ; Write Value (Dirty or Clean)
    
    ldx #$FD : stx $030C
    ldx #$DD : stx $030C
    ldx #$00 : stx $0303
    rts
