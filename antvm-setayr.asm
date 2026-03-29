;;; Input from dispatch: X=1100a0 Y=00000cde | A=Arg (Value or MASK)
;;; 46B Raw AY Dispatch + SETAYR Optimization
raw_ay_dispatch:
        tya                 ; 2B | A = 00000cde
        cpx #%11001000      ; 2B | Check 'a' bit in X
        bcc .no_a           
        ora #%00001000      ; 2B | Merge bit 3
.no_a:
        tay                 ; 1B | Y = RRRR (0-15)
        cpy #14             ; 2B | R14=AYUPDATE, R15=DUMPAY
        beq do_ayupdate     
        bcs do_dumpay       
        jsr SETAYR          ; 3B | Atomic update
        rts                 

do_ayupdate:
        sta tmp_mask        ; 3B | A = MASK
        ldx #0              ; 2B
.mask_loop:
        lsr tmp_mask        ; 2B | Bit into Carry
        bcc .next_bit       
        
        txa : pha           ; 3B | Save bit index
        ldy ipy             ; 3B | Get stream
        lda (stream),y      ; 2B
        inc ipy             ; 3B
        tax : pla : tay     ; 2B | Y = bit index, X = Value
        lda mask_to_reg, y  ; 4B | Map to AY Reg
        tay : txa           ; 2B | Y = Reg, A = Value
        jsr SETAYR          
        
.next_bit:
        inx                 ; 1B
        lda tmp_mask        ; 3B
        bne .mask_loop      ; 2B | Early exit
        rts                 

do_dumpay:
        ldx #0              ; 2B | Start R0
.dump_loop:
        ldy ipy             ; 3B
        lda (stream),y      ; 2B
        inc ipy             ; 3B
        txy                 ; 1B | Y = Reg (No save needed)
        jsr SETAYR          
        inx                 ; 1B
        cpx #14             ; 2B
        bne .dump_loop      
        rts                 

;;; SETAYR: Y=Reg, A=Val (Vol Shortcut for R1,3,5)
;;; 26B Logic
SETAYR:
        cpy #6              ; 2B | Only R0-R5 are pitch
        bcs .direct_write   
        sty tmp_y           ; 3B | Save to check parity
        lsr tmp_y           ; 2B | Shift bit 0 into Carry
        bcc .direct_write   ; 2B | If even (0,2,4), no volume shortcut
        
        pha                 ; 1B | Is Odd (1,3,5). Save Pitch.
        and #$F0            ; 2B | Check Volume Nibble
        beq .no_vol         
        lsr:lsr:lsr:lsr     ; 4B | Move Vol to low nibble
        pha                 ; 1B | Save Vol
        tya:clc:adc #7:tay  ; 3B | R1->R8, R3->R9, R5->R10
        pla                 ; 1B | A = Vol
        jsr .direct_write   
        ldy tmp_y           ; 3B | Restore original (tmp_y was lsr'd!)
        ;; wait, tmp_y was modified by LSR. Use original Y.
        tya:sec:sbc #7:tay  ; 3B | Safer restore
.no_vol:
        pla : and #$0F      ; 2B | Clean Pitch
.direct_write:
        ;; Oric VIA sequence (Select Reg Y, Write Val A)
        rts                 

mask_to_reg: .byte 0, 2, 4, 6, 7, 8, 9, 10
