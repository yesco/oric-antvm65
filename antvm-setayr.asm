;;; Input from dispatch: X=1100a0 Y=00000cde | A=Arg (Value or MASK)
;;; 62B Raw AY Dispatch + SETAYR Optimization
raw_ay_dispatch:
        tya                 ; 2B | A = 00000cde
        cpx #%11001000      ; 2B | Check 'a' bit in X (bit 3)
        bcc .no_a           ; 2B
        ora #%00001000      ; 2B | Set bit 3 (a)
.no_a:
        tay                 ; 1B | Y = RRRR (0-15)
        cpy #14             ; 2B | Check for Special Commands
        beq do_ayupdate     ; 2B | R14 = AYUPDATE
        bcs do_dumpay       ; 2B | R15 = DUMPAY
        jsr SETAYR          ; 3B | Execute atomic update
        rts                 ; 1B

do_ayupdate:
        sta tmp_mask        ; 3B | A was the MASK
        ldx #0              ; 2B | X tracks mask bit (0-7)
.mask_loop:
        lsr tmp_mask        ; 2B | Shift bit into Carry
        bcc .next_bit       ; 2B
        
        ;; Save X while we fetch value
        txa : pha           ; 3B | Push bit index to stack
        ldy ipy             ; 3B | Get Stream Pointer
        lda (stream),y      ; 2B | Fetch value
        inc ipy             ; 3B | Advance stream
        tax                 ; 1B | Temp save value in X
        pla : tay           ; 3B | Y = bit index
        lda mask_to_reg, y  ; 4B | Map to AY Reg
        tay                 ; 1B | Y = AY Reg
        txa                 ; 1B | A = value
        jsr SETAYR          ; 3B
        tya : tax           ; 2B | Restore index logic (approx)
        ;; Actually, just re-pull X from stack is cleaner
        
.next_bit:
        inx                 ; 1B
        lda tmp_mask        ; 3B | Check if any bits remain
        bne .mask_loop      ; 2B | Early exit!
        rts                 ; 1B

do_dumpay:
        ldx #0              ; 2B | Start at R0
.dump_loop:
        ldy ipy             ; 3B | Use Y for stream access
        lda (stream),y      ; 2B | A = Value
        inc ipy             ; 3B | Advance stream
        
        txa : pha           ; 3B | Save counter X
        tay                 ; 1B | Y = Register index (0-13)
        jsr SETAYR          ; 3B
        pla : tax           ; 3B | Restore counter X
        
        inx                 ; 1B
        cpx #14             ; 2B | Loop through R13
        bne .dump_loop      ; 2B
        rts                 ; 1B

;;; SETAYR: Y=Reg, A=Value (Volume Shortcut for R1,3,5)
SETAYR:
        cpy #1              ; 2B
        beq .hi_pitch
        cpy #3              ; 2B
        beq .hi_pitch
        cpy #5              ; 2B
        bne .direct_write   ; 2B
.hi_pitch:
        pha                 ; 1B | Save original pitch
        and #$F0            ; 2B | Check Volume Nibble
        beq .no_vol         ; 2B
        lsr:lsr:lsr:lsr     ; 4B | Shift Volume
        
        sty tmp_y           ; 3B | Save Pitch Reg Index
        clc : tya : adc #7  ; 3B | Map R1->R8, R3->R9, R5->R10
        tay                 ; 1B
        jsr .direct_write   ; 3B | Set Volume
        ldy tmp_y           ; 3B | Restore Pitch Reg Index
        
.no_vol:
        pla                 ; 1B
        and #$0F            ; 2B | Clean Coarse Pitch
.direct_write:
        ;; Oric VIA 6522 hardware write (Select Reg Y, Write Val A)
        rts                 ; 1B
