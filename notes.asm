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
;;; 
;;; DECODE: 33c -> NOTES/COMMAND
;;; 
;;; NOTES: 26c-78c
;;;   Oct 0: 42c | Oct 1: 54c | Oct 2: 66c | Oct 3: 78c
;;;   Oct 4: 36c | Oct 5: 47c | Oct 6: 58c | Oct 7: 69c
;;; 
;;; COMMAND: 26c + 3c(go next)

interpret:
;;; 33c
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
;;; 26c
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

;;; Playing a NOTE command
;;;   X=A=nnnnn0 Y=octave(0-7) (from dispatch)
;;; 
, 130, 126, 122

;;; Cycle Counts (Absolute addressing, no page crossing, includes RTS):
;;; Oct 0: 42c | Oct 1: 54c | Oct 2: 66c | Oct 3: 78c
;;; Oct 4: 36c | Oct 5: 47c | Oct 6: 58c | Oct 7: 69c
;;;
;;; 28B shift 0-7 steps, 17-122cycles (SLOW for high oct)
;;; 67B optimize by second byte array for oct>=4 (hip=0)
;;; 55B tight dual-table shifter
;;; 51B tightest opt (X=High, A=Low, No re-loads)
cmdNOTE:
        cpy #4              ; 2
        bcs .high_oct       ; 2/3 | Branch to 8-bit logic
        
        lda period_table+1, x ; 4
        sta tmp_high          ; 3
        lda period_table, x   ; 4
        
        cpy #0              ; 2
        beq .low_done       ; 2/3
.low_loop:
        lsr tmp_high        ; 5  | 16-bit shift loop (9c per iter)
        ror                 ; 2
        dey                 ; 2
        bne .low_loop       ; 2/3
.low_done:
        ldx tmp_high        ; 3
        jmp pitch_done      ; 3

.high_oct:
        lsr                 ; 2 | A = nnnnn (Index)
        tax                 ; 2
        lda oct4_table, x   ; 4
.high_loop:
        cpy #4              ; 2 | 8-bit shift loop (6c per iter)
        beq .high_done      ; 2/3
        lsr                 ; 2
        dey                 ; 2
        ;; always
        bne .high_loop      ; 2/3
.high_done:
        ldx #0              ; 2

pitch_done:
        clc                 ; 2
        adc detune_lo       ; 3
        tay                 ; 2
        txa                 ; 2
        adc detune_hi       ; 3
        tax                 ; 2
        tya                 ; 2
        rts                 ; 6
