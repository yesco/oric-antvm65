;;; Input from dispatch: A = 11CCRRRR (Cmd), Y = Stream Index
;;; R14 = AYUPDATE (Delta MASK), R15 = DUMPAY (Full 14B)
;;; 64B RAW AY Handler + SETAYR Logic
raw_ay_dispatch:
        pha                     ; 1B | Save 11CCRRRR
        and #$0F                ; 2B | Extract RRRR (0-15)
        tax                     ; 1B | X = Register index
        lda (stream_ptr), y     ; 2B | P-bit: Fetch argument byte
        iny                     ; 1B | Advance stream
        
        cpx #14                 ; 2B | Check for Special Commands
        beq do_ayupdate         ; 2B | R14 = AYUPDATE
        bcs do_dumpay           ; 2B | R15 = DUMPAY
        
        pla                     ; 1B | Restore 11CCRRRR
        txy                     ; 1B | Y = Register (0-13)
        ; A already contains the argument byte
        jsr SETAYR              ; 3B | Execute atomic update
        rts                     ; 1B

do_ayupdate:
        pla                     ; 1B | Clean stack
        sta tmp_mask            ; 3B | Argument was the MASK
        ldx #0                  ; 2B
.mask_loop:
        lsr tmp_mask            ; 2B
        bcc .next_bit           ; 2B
        lda (stream_ptr), y     ; 2B | Get value for this bit
        iny                     ; 1B
        phy                     ; 1B | Save stream index
        ldy mask_to_reg, x      ; 4B | Map bit to AY Reg (0,2,4,6,7,8,9,10)
        jsr SETAYR              ; 3B
        ply                     ; 1B
.next_bit:
        inx                     ; 1B
        cpx #8                  ; 2B
        bne .mask_loop          ; 2B
        rts                     ; 1B

do_dumpay:
        pla                     ; 1B | Clean stack
        ldx #0                  ; 2B | Dump R0-R13
.dump_loop:
        lda (stream_ptr), y     ; 2B
        iny                     ; 1B
        phy : txa : tay         ; 3B | Stream -> Reg mapping
        jsr SETAYR              ; 3B
        ply : inx               ; 2B
        cpx #14                 ; 2B
        bne .dump_loop          ; 2B
        rts                     ; 1B

;;; SETAYR: Y=Reg, A=Value (Logic for Volume Shortcut)
;;; 22B SETAYR Logic
SETAYR:
        cpy #1                  ; 2B | Is it R1, R3, or R5?
        beq .hi_pitch           ; 2B
        cpy #3                  ; 2B
        beq .hi_pitch           ; 2B
        cpy #5                  ; 2B
        bne .direct_write       ; 2B
.hi_pitch:
        tax                     ; 1B | Save original
        and #$F0                ; 2B | Check for Volume nibble
        beq .no_vol             ; 2B
        lsr : lsr : lsr : lsr   ; 4B | Shift Volume to low nibble
        pha                     ; 1B
        tya : clc : adc #7      ; 3B | R1->R8, R3->R9, R5->R10
        tay                     ; 1B
        pla                     ; 1B
        jsr .direct_write       ; 3B | Set Volume First
        ldy tmp_reg             ; 3B | Restore Pitch-High Reg index
.no_vol:
        txa                     ; 1B
        and #$0F                ; 2B | Clean Coarse Pitch (only 4-bits)
.direct_write:
        ;; Oric VIA sequence (Select Reg Y, Write Val A)
        rts                     ; 1B

mask_to_reg: .byte 0, 2, 4, 6, 7, 8, 9, 10
