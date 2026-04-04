;;; Input from dispatch: X=1100a0 Y=00000cde | A=Arg (Value or MASK)
;;; 64B Raw AY Dispatch + Zero-Carry Optimized SETAYR
raw_ay_dispatch:
        tya                 ; 2B | Reconstruct Reg Index
        cpx #%11001000      ; 2B | Merge bit 3 from X
        bcc .no_a           
        ora #%00001000      ; 2B 
.no_a:
        tay                 ; 1B | Y = RRRR (0-15)
        cpy #14             ; 2B | R14=AYUPDATE, R15=DUMPAY
        beq do_ayupdate     
        bcs do_dumpay       
        jsr SETAYR          ; 3B 
        rts                 

do_ayupdate:
        sta tmp_mask        ; 3B | A = MASK
        ldx #0              ; 2B
.mask_loop:
        lsr tmp_mask        ; 2B | Bit into Carry
        bcc .next_bit       
        txa
        pha                 ; 3B | Save bit index
        ldy ipy             ; 3B | Get stream
        lda (stream),y      ; 2B
        inc ipy             ; 3B
        tax
        pla
        tay                 ; 2B | Y = bit index, X = Value
        lda mask_to_reg, y  ; 4B | Map to AY Reg
        tay
        txa                 ; 2B | Y = Reg, A = Value
        jsr SETAYR          
.next_bit:
        inx                 ; 1B
        lda tmp_mask        ; 3B
        bne .mask_loop      ; 2B | Early exit
        rts                 

do_dumpay:
        ldx #0              ; 2B
.dump_loop:
        ldy ipy             ; 3B
        lda (stream),y      ; 2B
        inc ipy             ; 3B
        txa
        tay                 ; 2B | Y = Reg index
        jsr SETAYR          
        inx                 ; 1B
        cpx #14             ; 2B
        bne .dump_loop      
        rts                 

;;; SETAYR: Y=Reg, A=Val
;;; 19B Zero-Carry Volume Shortcut
SETAYR:
        pha                 ; 1B | Save for potential volume nibble
        jsr .direct_write   ; 3B | Write Pitch/Reg first
        tya                 ; 1B | Move Reg to A
        lsr                 ; 1B | C is now 0 for even, 1 for odd
        bcc .exit           ; 2B | If even, Carry=0, exit immediately
        ;; C is 1 here. Math: (Y/2)*2 + 8. 
        cmp #3              ; 2B | If A >= 3 (Reg >= 7), exit
        bcs .exit           
        asl                 ; 1B | A = 0, 2, 4 (Carry now 0)
        adc #8              ; 2B | A = 8, 9, 10 (Carry was 0, so no CLC needed)
        tay                 ; 1B
        pla                 ; 1B | Restore original value
        lsr:lsr:lsr:lsr     ; 4B | Move Volume to low nibble
        beq .done           ; 2B | If volume was 0, skip
        jmp .direct_write   ; 3B | Tail-call write
.exit:
        pla                 ; 1B | Clean stack
.done:
        rts                 ; 1B

.direct_write:
        ;; Oric VIA hardware write (Select Reg Y, Write Val A)
        rts                 

mask_to_reg: .byte 0, 2, 4, 6, 7, 8, 9, 10
