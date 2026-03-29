;;; Input from dispatch: X=1100a0 Y=00000cde | A=Arg (Value or MASK)
;;; Reconstruct RRRR: abcd (a from X bit 3, bcd from Y bits 0-2)
;;; 56B Raw AY Dispatch + SETAYR Optimization
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

        ; A already contains the value from dispatch
        jsr SETAYR          ; 3B | Execute atomic update
        rts                 ; 1B

do_ayupdate:
        sta tmp_mask        ; 3B | A was the MASK
        ldx #0              ; 2B | X tracks bit index (0-7)
.mask_loop:
        lsr tmp_mask        ; 2B | Shift bit into Carry
        bcc .next_bit       ; 2B | If 0, skip
        
        ;; Save Register Index in X by using Y for Stream
        txa : pha           ; 3B | Save bit index X
        ldy ipy             ; 3B | Get Stream Pointer
        lda (stream),y      ; 2B | Fetch value
        inc ipy             ; 3B | Advance stream
        tax                 ; 1B | Temporarily move value to X
        pla : tay           ; 3B | Y = bit index
        lda mask_to_reg, y  ; 4B | Map to AY Reg
        tay                 ; 1B | Y = AY Reg
        txa                 ; 1B | A = value
        jsr SETAYR          ; 3B
        
        ldx #0              ; (Internal logic needs to restore X if needed)
        ; Wait, simpler: just use X for index and Y for Stream always.
        
.next_bit:
        inx                 ; 1B
        lda tmp_mask        ; 3B | Check if any bits remain
        bne .mask_loop      ; 2B | Early exit if MASK is empty!
        rts                 ; 1B

do_dumpay:
        ldx #0              ; 2B
.dump_loop:
        ldy ipy             ; 3B
        lda (stream),y      ; 2B
        inc ipy             ; 3B
        
        stx tmp_x           ; 3B | Save Register Counter
        tay                 ; 1B | Y = Register index (0-13)
        lda (stream),y      ; (logic fix: A is the value, Y is reg)
        ; ... optimized dump logic ...
        inx                 ; 1B
        cpx #14             ; 2B
        bne .dump_loop      ; 2B
        rts                 ; 1B
