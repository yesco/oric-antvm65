;;; AntVM: interpreter, command dispatch; note calculation

;;; Summary:

;;; (+ 36 38) = 74 B old atnvm 36 "interpret+dispatch"+notes 38
;;; (+ 42 28) = 70 B NEW 42 "interpret+dispatch"+ notes 28


;;;===NOTES ONLY:
;;; 40 B 32c - lo in A makes addition faster and saves 4 bytes
;;; 37 B 12c - rol sequence is more compact than 4 lsr
;;; 35 B 30c - Y instead of PHA/PLA saves 2 bytes
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - hi in A at shifts saves 1 byte,6c/loop
;;; 31 B 26c - %NNNNNOOO + register-only logic -4 bytes
;;; 
;;;===INTERPRET+NOTES:
;;; 51 B 54c - Optimized Command Path: No X-store, direct A masking
;;; 64 B 66c - NMOS 6502 RTS-dispatch with specific named cmd groups
;;; 67 B 68c - Updated PCC bits to map 11PCCIII format correctly
;;; 146 B Total Size (98 B code, 48 B table)


;;; Interpreter dispatch to commands/notes
;;; 
;;; Input: ipy (stream index), detune_lo/hi
;;; 
;;; Comamnnd structure:
;;;   nnnnn ooo (Note 0-23, Octave 0-7)
;;;   11pgg iii (P=Param flag, gg=Group, iii=instr/data)
;;; 
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
        and #%00111110      ; 2B | Mask for Note*2 or CmdBits*2
        tax                 ; 1B | X = index

        cpx #48             ; 2B | Check if Note index >= 48
        bcc cmdNOTE         ; 2B | If lower, it's a Note

command:
        eor #48             ; A = 0000PCC0
        lsr                 ; A = 00000PCC (0-7)
        tax
        cmp #4              ; Carry set if P=1
        lda offset_table, x
        sta dispatch_br+1
        bcc no_param
        ldy ipy
        lda (stream),y      ; Fetch Parameter into A
        inc ipy
no_param:
        sec
dispatch_br:
        bcs *               ; Jumps directly to cmd via SMC offset

                                ; --- Data Tables ---
offset_table:
        .byte cmdWAIT-dispatch_br-2
        .byte cmdCTRL-dispatch_br-2
        .byte cmdSETAY-dispatch_br-2
        .byte cmdVALUE-dispatch_br-2
        .byte cmdLocalCALL-dispatch_br-2
        .byte cmdLangCALL-dispatch_br-2
        .byte cmdFlowDrums-dispatch_br-2
        .byte cmdModSet-dispatch_br-2


;;; 48 bytes (Octave 0-3 base)
period_table:
        .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
        .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
        .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967

;;; 24 bytes (Octave 4 base - 8-bit)
oct4_table:
        .byte 238, 232, 225, 219, 212, 206, 200, 195
        .byte 189, 184, 178, 173, 168, 164, 159, 154
        .byte 150, 146, 142, 138, 134, 130, 126, 122

;;; Input from dispatch: X=A=nnnnn0 Y=octave(0-7)
;;; 28B shift 0-7 steps
;;; 51B optimize by second byte array for oct>=4 (hip=0)
;;; 37B tight dual-table shifter
cmdNOTE:
        cpy #4              ; 2B | Check if Octave 4+
        bcs .high_oct       ; 2B | Branch to 8-bit logic
        
        lda period_table+1, x ; 3B | Load High Octave 0-3
        sta tmp_high          ; 3B
        lda period_table, x   ; 3B | A = Low Byte
        
        cpy #0              ; 2B | Skip loop if Octave 0
        beq pitch_done      ; 2B
.low_loop:
        lsr tmp_high        ; 5B | 16-bit shift
        ror                 ; 1B
        dey                 ; 1B
        bne .low_loop       ; 2B
        beq pitch_done      ; 2B

.high_oct:
        lsr                 ; 1B | A = nnnnn (Index)
        tax                 ; 1B | X = nnnnn
        lda #0              ; 2B | High byte is 0 for Octave 4+
        sta tmp_high        ; 3B
        lda oct4_table, x   ; 4B | Load the 8-bit base note
        cpy #4              ; 2B | Check if Octave 4
        beq pitch_done      ; 2B | If Octave 4, no shifts needed
.high_loop:
        lsr                 ; 1B | 8-bit shift
        dey                 ; 1B
        cpy #4              ; 2B | Loop until we hit Octave 4
        bne .high_loop      ; 2B

pitch_done:
        clc                 ; 1B
        adc detune_lo       ; 3B
        tay                 ; 1B | Final Low in Y
        lda tmp_high        ; 3B
        adc detune_hi       ; 3B | Final High in A
        tax                 ; 1B | Final High in X
        tya                 ; 1B | Final Low in A
        rts                 ; 1B
