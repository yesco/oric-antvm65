;; ===========================================================================
;; cmdAYUPDATE (Oric Atmos 6502A)
;; ---------------------------------------------------------------------------
;; EVOLUTION HISTORY:
;; ;; 115 + 18 + 24 = 157B Initial draft
;; ;; 102 + 15 + 24 = 141B X-index loop
;; ;; 82 + 15 + 22  = 119B Unified step_ay
;; ;; 64 + 15 + 20  = 99B  Tail-call & moved index to X
;; ;; 52 + 10 + 44  = 106B Hardware "Dirty Write" + Fixup
;; ;; 52 + 10 + 41  = 103B Constant-X & ORA #8 optimizations
;; ---------------------------------------------------------------------------
;; CURRENT: 52B (cmd) + 10B (pull) + 41B (set) = 103 Bytes Total
;; ===========================================================================

cmdAYUPDATE:
    lsr                     ; 1 bit 0 (Coarse) -> C
    ror ay_coarse           ; 2 bit 0 -> N flag
    sta tmp_mask            ; 2 save bits 1-7
    
    lda #$FF                ; 2
    sta ay_reg              ; 2 cursor = -1

@pitch_loop:
    lsr tmp_mask            ; 2 shift Ch bit
    jsr pull_ay             ; 3 R0, 2, 4
    bit ay_coarse           ; 2 check N
    bmi @do_hi              ; 2
    clc                     ; 1 fine only
@do_hi:
    jsr pull_ay             ; 3 R1, 3, 5
    ldy ay_reg              ; 2
    cpy #5                  ; 2
    bcc @pitch_loop         ; 2

    lsr tmp_mask            ; 2 R6 Noise
    jsr pull_ay             ; 3
    lsr tmp_mask            ; 2 R7 Mixer
    jsr pull_ay             ; 3

    lsr tmp_mask            ; 2 Vol bit
    bcc @done               ; 2
@vol_loop:
    sec                     ; 1 force update
    jsr pull_ay             ; 3
    ldy ay_reg              ; 2
    cpy #10                 ; 2
    bcc @vol_loop           ; 2
@done:
    rts                     ; 1 (52 Bytes)

; ---------------------------------------------------------------------------
; pull_ay (10 Bytes)
; ---------------------------------------------------------------------------
pull_ay:
    inc ay_reg              ; 2
    bcc @only_inc           ; 2
    ldy ipy                 ; 2
    lda (stream),y          ; 2
    inc ipy                 ; 2
    ; TODO: Guard against ipy page-wrap
    jmp setayr              ; 3 (into the helper)
@only_inc:
    rts                     ; 1

; ---------------------------------------------------------------------------
; setayr (41 Bytes)
; Y = Register Index, A = Value
; ---------------------------------------------------------------------------
setayr:
    ldy ay_reg              ; 2
    cpy #7                  ; 2 Mixer?
    bne @write_phys         ; 2
    ora #64                 ; 2 Bit 6 Patch
@write_phys:
    tax                     ; 1 STASH value in X
    ldy ay_reg              ; 2 target reg in Y
    lda #$FF                ; 2
    sta $0303               ; 3 DDRA Output
    sty $030F               ; 3 Port A Address
    sta $030C               ; 3 Latch Address ($FF)
    lda #$DD                ; 2
    sta $030C               ; 3 Inactive ($DD)
    stx $030F               ; 3 Write Value (X)
    lda #$FD                ; 2
    sta $030C               ; 3 Latch Data ($FD)
    lda #$DD                ; 2
    sta $030C               ; 3 Inactive ($DD)
    lda #$00                ; 2
    sta $0303               ; 3 DDRA Input

    ; --- Post-Write Fixup ---
    cpy #6                  ; 2 R0-R5?
    bcs @exit               ; 2
    tya                     ; 1 A = 1, 3, or 5
    lsr                     ; 1 C=1 if Odd, A=0, 1, or 2
    bcc @exit               ; 2

    ora #8                  ; 2 map to Vol R8, 9, 10
    tay                     ; 1 target register
    txa                     ; 1 RESTORE packed value from X
    lsr : lsr : lsr : lsr   ; 4 extract volume bits
    jmp setayr              ; 3 tail call back to write volume

@exit:
    sec                     ; 1 sticky carry
    rts                     ; 1
