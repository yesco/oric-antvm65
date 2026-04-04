;;; ==============================================================
;;; cmdAYUPDATE (Oric Atmos 6502A)
;;; --------------------------------------------------------------
;;; EVOLUTION HISTORY:
;;;
;;;~115  Initial draft (logic for A, B, C channels, many JMPs)
;;; 102  Switched to X-index loop (Saved ~13)
;;;  82 + 15? Unified Pitch Lo/Hi via step_ay helper (Saved 12)
;;;  76 + 15? Streamlined Mask bit-order (N-M-V) (Saved 6)
;;;  72 + 15?  "Sticky Carry" logic (Removed PHP/PLP) (Saved 4)
;;;  68 + 15? Final linear flow (no manual inc/lda/jmp) (Saved 4)
;;;  68 + 15? Unified step_ay
;;; --- combined with SETAYR (cmdAYPDATE + pull_ay + setay)
;;;  64 + 15 + 43 Tail-call & moved index to X (naive setay)
;;;  52 + 10 + 75 hi pitchy vol, hw "Dirty Write" + Fixup
;;;  52 + 10 + 70 Constant-X & ORA #8 optimizations
;;;  52 + 15 + 66 Constant-X & ORA #8 optimizations
;;; --------------------------------------------------------------
;;; CURRENT: 133 Bytes
;;; ==============================================================

;;; aypdate, Update a partial frame from (stream), bitmask
;;; determines what type of data comes.
;;; 
;;; A= MASK (coarse, A,B,C, noise, mixer, vol, RESERVED)
;;; 
;;; 
aypdate:
        lsr                     ; 1 bit 0 (Coarse) -> C
        ror ay_coarse           ; 2 bit 0 -> N flag
        sta antvm_tmp           ; 2 save bits 1-7
        
        lda #$FF                ; 2
        sta ay_reg              ; 2 cursor = -1

@pitch_loop:
        lsr antvm_tmp           ; 2 shift Ch bit
        jsr pull_ay             ; 3 R0, 2, 4
        bit ay_coarse           ; 2 check N
        bmi @do_hi              ; 2
        clc                     ; 1 fine only
@do_hi:
        jsr pull_ay             ; 3 R1, 3, 5
        ldy ay_reg              ; 2
        cpy #5                  ; 2
        bcc @pitch_loop         ; 2

        lsr antvm_tmp           ; 2 R6 Noise
        jsr pull_ay             ; 3
        lsr antvm_tmp           ; 2 R7 Mixer
        jsr pull_ay             ; 3

        lsr antvm_tmp           ; 2 Vol bit
        bcc @done               ; 2
@vol_loop:
        sec                     ; 1 force update
        jsr pull_ay             ; 3
        ldy ay_reg              ; 2
        cpy #10                 ; 2
        bcc @vol_loop           ; 2
@done:
        rts                     ; 1 (52 Bytes)

;;; ----------------------------------------------------------------
;;; pull_ay (15 Bytes)
;;; ----------------------------------------------------------------
pull_ay:
        inc ay_reg              ; 2
        bcc @only_inc           ; 2
        ldy ipy                 ; 2
        lda (stream),y          ; 2
        inc ipy                 ; 2
                                ; TODO: Guard against ipy page-wrap
        ldy ay_reg              ; 2
        jmp setayr              ; 3 (into the helper)
@only_inc:
;;; Used by setayr to exit and make sure C set!
Csetdone:
        sec
        rts                     ; 1

;;; ----------------------------------------------------------------
;;; setayr (41 Bytes)
;;; Writes A value to Y AY register
;;;   Y = Register Index (modified), A = Value (maybe modified)
;;; 
;;; Note: If Y=R1,R3,R5: 4 hi-bits are also written to resp VOL
;;; 
;;; Output:
;;;   All value is potentially trashed:
;;;   Do NOT use them after, including Y! (may become vol for R1,3,5)
;;; ----------------------------------------------------------------
setayr:
        cpy #7                  ; 2 Mixer?
        bne :+
        ora #64                 ; 2 Bit 6 Patch
:       
@write_phys:
        sta ayshadow,Y

        ldx #$FF                ; 2
        stx $0303               ; 3 DDRA Output
        sty $030F               ; 3 Port A Address
        stx $030C               ; 3 Latch Address ($FF)
        ldx #$DD                ; 2
        stx $030C               ; 3 Inactive ($DD)
        sta $030F               ; 3 Write Value (X)
        ldx #$FD                ; 2
        stx $030C               ; 3 Latch Data ($FD)
        ldx #$DD                ; 2
        stx $030C               ; 3 Inactive ($DD)
        ldx #$00                ; 2
        stx $0303               ; 3 DDRA Input

        ;; --- ? Pitch regsiters - maybe fixup ---
;;; TODO: ???? what???
        cpy #6                  ; 2 R0-R5?
        bcs Csetdone

        ;; --- ? Post-Write Fixup of volume from hi-pitch? ---
@write_vol:
        tax                     ; 1 STASH value in X

        tya                     ; 1 A = 1, 3, or 5
        lsr                     ; 1 C=1 if Odd, A=0, 1, or 2
        bcc Csetdone

        ;; --- Fix register 1,3,5 => 8,9,10 ---
        ora #8                  ; 2 map to Vol R8, 9, 10
        tay                     ; 1 target register

        ;; --- Fixup vol and write again ---
        txa                     ; 1 RESTORE packed value from X
        lsr                     ; 4 extract volume bits
        lsr
        lsr
        lsr   

        ;; Don't write 0 volume for caompat
        beq Csetdone

        jmp @write_phys         ; 3 tail call back to write volume
