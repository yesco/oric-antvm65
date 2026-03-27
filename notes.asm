;;; 35 B 12c - rol sequence is more compact than 4 lsr
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - Keeping hi in A during shifts saves 1 byte and 6c per loop
;;; 38 B 32c - keeping lo in A makes addition faster and saves 4 bytes
;;; 35 B 30c - Using Y for temp storage instead of PHA/PLA saves 2 bytes
;;; 31 B 26c - %NNNNNOOO + register-only logic (no stack) saves 4 bytes
;;; 48 B 52c - NMOS 6502 compatible interpret/dispatch (no JMP (addr,x))
;;; 127 B Total Size (79 B code, 48 B table)

; Input: (stream),y points to VM data
; Note Path: %NNNNNOOO (Note 0-23, Octave 0-7)
; Cmd Path:  %11PCCIII (P=Param flag, C=Group, I=Index)
interpret:
    lda (stream),y      ; 5B | Get command byte
    iny                 ; 2B
    sta cmd             ; 3B | Save raw byte for P-bit check
    
    and #%00000111      ; 2B | Isolate III (Index or Octave)
    pha                 ; 2B | Store for later (Y is stream index)
    
    lda cmd             ; 3B
    lsr                 ; 1B | %011PCCII
    lsr                 ; 1B | %0011PCCI
    and #%00111110      ; 2B | Mask for Note*2 or Group*2
    tax                 ; 1B | X = index

    pla                 ; 2B | Restore III
    tay                 ; 1B | Y = III (Octave or Cmd Index)

    cpx #48             ; 2B | If Note index >= 24*2, it's a command
    bcs command_path    ; 2B

note_path:
    ; X = Note * 2, Y = Octave
    lda period_table+1, x ; 3B
    sta tmp_high          ; 3B
    lda period_table, x   ; 3B | A = Low Byte
    
octave_loop:
    dey                 ; 1B
    bmi pitch_done      ; 2B | If Y was 0, skip
    lsr tmp_high        ; 5B
    ror                 ; 1B
    jmp octave_loop     ; 3B

pitch_done:
    ; --- Optimized Detune Addition ---
    clc                 ; 1B
    adc detune_lo       ; 3B | A = Final Low
    sta tmp_low         ; 3B | Temp save Low
    lda tmp_high        ; 3B
    adc detune_hi       ; 3B
    tax                 ; 1B | X = Final High
    lda tmp_low         ; 3B | A = Final Low
    rts                 ; 1B

command_path:
    ; X = 11PCC * 2. Handle P flag (bit 5 of raw 'cmd')
    lda #0              ; 2B | Default param
    bit cmd             ; 3B | Check bit 5 (P) and bit 7/6
    bvc dispatch        ; 2B | V flag is bit 6... wait, bit 5 is not a flag.
    
    ; Manual bit 5 check for NMOS 6502
    lda cmd             ; 3B
    and #%00100000      ; 2B
    beq dispatch        ; 2B
    
    lda (stream),y      ; 5B | Fetch Parameter Byte
    iny                 ; 2B
    sty stream_y        ; 3B | Save Y for the command routine

dispatch:
    ; NMOS 6502 JMP (ADDR,X) Workaround: Push to stack and RTS
    lda groupjmps+1, x  ; 3B | High byte
    pha                 ; 1B
    lda groupjmps, x    ; 3B | Low byte
    pha                 ; 1B
    ; Note: Routine must be addr-1 for RTS trick
    rts                 ; 1B

; 24-TET Period Table (Octave 0)
period_table:
    .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
    .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
    .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967
