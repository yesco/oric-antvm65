;;; 35 B 12c - rol sequence is more compact than 4 lsr
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - Keeping hi in A during shifts saves 1 byte and 6c per loop
;;; 38 B 32c - keeping lo in A makes addition faster and saves 4 bytes
;;; 35 B 30c - Using Y for temp storage instead of PHA/PLA saves 2 bytes
;;; 31 B 26c - %NNNNNOOO + register-only logic (no stack) saves 4 bytes
;;; 52 B 58c - NMOS 6502 Interpret: ipy pointer (no stack), RTS dispatch
;;; 55 B 62c - Swapped order: Command path first, then note path
;;; 134 B Total Size (86 B code, 48 B table)

; Input: ipy (stream index), detune_lo/hi
; Note Path: %NNNNNOOO (Note 0-23, Octave 0-7)
; Cmd Path:  %11PCCIII (P=Param flag, C=Group, I=Index)
interpret:
    ldy ipy             ; 3B | Load stream index
    lda (stream),y      ; 5B | Get command byte
    inc ipy             ; 3B | inc pointer
    tax                 ; 1B | X = raw byte
    
    and #%00000111      ; 2B | Isolate III (Index or Octave)
    tay                 ; 1B | Y = III

    txa                 ; 1B
    lsr                 ; 1B | %011PCCII
    lsr                 ; 1B | %0011PCCI
    and #%00111110      ; 2B | Mask for Note*2 or Group*2
    tax                 ; 1B | X = index

    cpx #48             ; 2B | Check if Note index >= 48
    bcc note_path       ; 2B | If lower, it's a Note

command_path:
    ; Handle P flag (bit 5 of original byte, which is bit 3 of shifted X)
    stx tmp_group       ; 3B | Save shifted index
    txa                 ; 1B
    and #%00001000      ; 2B | Check bit 3 (the shifted P bit)
    beq no_param        ; 2B
    
    ldy ipy             ; 3B
    lda (stream),y      ; 5B | Fetch Param
    inc ipy             ; 3B
    
no_param:
    lda tmp_group       ; 3B
    and #%00000110      ; 2B | Isolate PCC * 2 (Group index)
    tax                 ; 1B
    ; RTS dispatch trick for NMOS 6502 (TargetAddr-1)
    lda groupjmps+1, x  ; 3B
    pha                 ; 1B
    lda groupjmps, x    ; 3B
    pha                 ; 1B
    rts                 ; 1B

note_path:
    ; X = Note * 2, Y = Octave
    lda period_table+1, x ; 3B
    sta tmp_high          ; 3B
    lda period_table, x   ; 3B | A = Low Byte
    
octave_loop:
    dey                 ; 1B | Decrement octave
    bmi pitch_done      ; 2B | Exit if Y was 0
    lsr tmp_high        ; 5B | 16-bit shift
    ror                 ; 1B
    jmp octave_loop     ; 3B

pitch_done:
    clc                 ; 1B
    adc detune_lo       ; 3B | A = Final Low
    tay                 ; 1B | Temp save Low in Y
    lda tmp_high        ; 3B
    adc detune_hi       ; 3B | A = Final High
    tax                 ; 1B | X = Final High
    tya                 ; 1B | A = Final Low
    rts                 ; 1B

; 24-TET Period Table (Octave 0)
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
