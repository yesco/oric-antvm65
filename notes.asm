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

.zeropage

ticks:          .res 2

;;; IP for interpration
;;; TODO: ABCN
stream:         .res 2
ipy:            .res 1

tmp_high:       .res 1

.data

detune:         .word 0

.code


;;; summary:
;;; 
;;; bitshift: 102 b  59c-111c   work-horse
;;; (possibly use big 64 b table for dipatch)
;;; 
;;; BIGLUT:   814 b  30c- 47c   use too much mem
;;; SMALLLUT: 413 b  34c- 51c   only double fast

;;; BITSHIFT:102 b, data=72 b,  decode=33c cmd=26c note=36-78c
;;; 
;;; BIGLUT:   36 b, data=768 b, decode=30c cmd= 0c note=16c
;;; SMALLLUT: 51 b, data=352 b, decode=20c cmd=14c note=15-31c
;;;  (param) +10 b                            +17c
;;; (parameter decoding not included in lut: add 10 b  17 c)


.ifdef SUPERFAST

;;; SMALLLUT: bytes=
;;;    (+ (* 2 96) 96     64) = 352 
;;;       lower    higher commands

.ifdef BIGLUT


;;; use lut for everything!
;;; (in this case older command bit pattern
;;;  use less lut tables!)

.data

hifreq:         .res 256
lofreq:         .res 256

cmdaddr:        .res 256
        ;; TODO: populate with:
        ;; .byte note-jmpcmd-2
        ;; .byte cmdwait-jmpcmd-2
        ;; ...
        ;; .byte cmdwait-jmpcmd-2
.code



;;; 34 b  30-46c
interpret:
;;; 27c+3c(jmp next)
        ldy ipy
        lda (stream),y
        inc ipy
        
        tax
        lda cmdaddr,x
        sta dispatch+1
dispatch:       
        sec
        bcs dispatch            ; lol
        
note:   
;;; 1+15c
        ;; play channel A, lol
        ldy #0                  ; TODO: fix
        lda lofreq,x
        jsr SETAYR

        iny
        lda hifreq,x
        jsr SETAYR

        jmp interpret

cmdwait:        

.else ; SMALLLUT (!BIGLUT)

;;; use lut for everything!
;;; (in this case older command bit pattern
;;;  use less lut tables!)

;;; TODO: actually oct 0-3: 96 words = 192 !
;;; TODO:          oct 4-7: 96 bytes =  96 !

hifreq:         .res 192
lofreq:         .res 192

cmdaddr:        .res 64

        ;; TODO: populate with:
        ;; .byte note-jmpcmd-2
        ;; .byte cmdwait-jmpcmd-2
        ;; ...
        ;; .byte cmdwait-jmpcmd-2


;;; decode=17c+3c command=14c  notes=15-31c

;;; 53 b  30-48c
interpret:
;;; 17c+3c(jmp next)
        ldy ipy
        lda (stream),y
        inc ipy
        
        cmp #%11000000
        bcc note
;;; 14c
        ;; COMMAND
        tax
        lda cmdaddr,x
        sta dispatch+1
dispatch:       
        sec
        bcs dispatch            ; lol
        
note:   
;;; 1+ 14--31c
        ;; ? oct: 0-3: use byte pitch?
        and #%111
        cmp #4
        bcs :+

        ;; yes byte pitches
        ldy #0
        lda bytepitch,x
        jsr setayr

        lda #0
        ;; always
        beq @sethi
:       

        ;; play channel A, lol
        ldy #0                  ; todo: fix
        lda lopitch,x
        jsr setayr

        lda hipitch,x
@sethi:  
        ldy #1
        jsr setayr

        jmp interpret

cmdwait:        

        
.endif ; !BIGLUT = SMALLLUT



.else ; BITSHIFT = !SUPERFAST



.data

offset_table:
        ;; no parameters
        .byte cmdWAIT-dispatch_br-2
        .byte cmdVALUE-dispatch_br-2
        .byte cmdCALLpnm-dispatch_br-2
        .byte cmdCHANNEL-dispatch_br-2
        ;; with parameter(s)
        .byte cmdSETAY-dispatch_br-2
        .byte cmdSETAY-dispatch_br-2
        .byte cmdCALLlang-dispatch_br-2
        .byte cmdDRUMEXTEND-dispatch_br-2

.ifdef ANTTRACE
        ;; Single letter MNEMOIC
        ;;     12345678
cmd_char:       
        .byte "SWWWWWWW"
        .byte "swhqestl"
        .byte "01234567"
        .byte "ABCNxYQK"

        .byte "aabbccnm"
        .byte "vvvppeUD"
        .byte "language"
        .byte "kscoXBWR"


;;; JSK-notation, LOL: ABC-notation uses ^/C and _/C !

note_char1:      
        ;;     0123456789012345678901234
        .byte "CCCDDDDEEEFFFFGGGGAAAABBB"
note_char2:      
        .byte " -#+ -#+ + -#+ -#+ -#+ -#"

.endif ; ANTTRACE

;;; 48 bytes (Octave 0-3 base)
WORDTABLE=1

.ifdef WORDTABLE
period_table:
        .word 3822, 3713, 3608, 3505, 3405, 3308, 3214, 3123
        .word 3034, 2947, 2863, 2782, 2703, 2626, 2551, 2478
        .word 2408, 2339, 2273, 2208, 2145, 2084, 2025, 1967

.else ; BYTE TABLES HI/LO

; Hexadecimal High/Low Byte Split
hi_oct:       
        .byte $0E, $0E, $0E, $0D, $0D, $0C, $0C, $0C
        .byte $0B, $0B, $0B, $0A, $0A, $0A, $09, $09
        .byte $09, $09, $08, $08, $08, $08, $07, $07

lo_oct: 
        .byte $EE, $81, $18, $B1, $4D, $EC, $8E, $33
        .byte $DA, $83, $2F, $DE, $8F, $42, $F7, $AE
        .byte $68, $23, $E1, $A0, $61, $24, $E9, $AF
.endif

;;; 24 bytes (Octave 4 base - 8-bit)
.ifdef OCT4DEC
oct4_table:
        .byte 238, 232, 225, 219, 212, 206, 200, 195
        .byte 189, 184, 178, 173, 168, 164, 159, 154
        .byte 150, 146, 142, 138, 134, 130, 126, 122
.else
oct4_table:
        .byte $EE, $E8, $E1, $DB, $D4, $CE, $C8, $C3
        .byte $BD, $B8, $B2, $AD, $A8, $A4, $9F, $9A
        .byte $96, $92, $8E, $8A, $86, $82, $7E, $7A
.endif

.code


interpret:
;;; 20 B  33c
:       

.ifdef ANTTRACE
        NL
        putc 9
        putc 9
        putc '@'
        LDAX stream
        jsr puth
        putc '.'
        tya
        lda ipy
        jsr put2h
        putc ':'
.endif ; ANTTRACE

        ldy ipy             ; 3B | Load stream index
        lda (stream),y      ; 5B | Get command byte
        inc ipy             ; 3B | inc pointer

.ifdef ANTTRACE
        ;; print CMD in hex
        pha
        jsr put2h
        SPC
        pla
        ;; print CMD in bin
        pha
        jsr putb
        SPC
        SPC
        pla
.endif ; ANTTRACE

        tax                 ; 1B | X = raw byte
        and #%00000111      ; 2B | Isolate III (Index or Octave)
        tay                 ; 1B | Y = III

        txa                 ; 1B
        lsr                 ; 1B | %011PCCII
        lsr                 ; 1B | %0011PCCI
        and #%00111110      ; 2B | Mask for Note*2 or CmdBits*2
        tax                 ; 1B | X = index

        cpx #%00110000      ; 2B | Check if Note index >= 48
        bcs command         ; 2B | If lower, it's a Note
        jmp cmdNOTE
command:

.ifdef ANTTRACE
        ;; print CMD char
        pha
        asl
        asl
        sty savey
        ora savey
        and #%111111
        tay
        lda cmd_char,Y
        jsr putchar
        putc ':'
        pla
.endif ; ANTTRACE

;;; 23 B  26c
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
.ifdef ANTTRACE
        SPC
        jsr put2h
.endif ; ANTTRACE

no_param:
        sec
dispatch_br:
        bcs *               ; Jumps directly to cmd via SMC offset

                                ; --- Data Tables ---

;;; --- no parameters

cmdWAIT:        
        ;; Y=value parameter

        ;; TODO: speech mode?

        ;; TODO: share with cmdVALUE?
        ;; (- (* 2 8) (+ 8 1 (* 2 3)))
        ;; (would save 1 byte if used only 2 places)
        lda #WHOLETICKS
:       
        dey
        bmi :+
        lsr
        ;; "always" (except zero==don't matter)
        bne :-
:       
        sta delayA
        
        ;; YIELD
        rts

cmdVALUE:       
        ;; Y=value parameter
        lda #WHOLETICKS
        ;; TODO for all seleted channels
:       
        dey
        bmi :+
        lsr
        ;; "always" (except zero==don't matter)
        bne :-
:       
        sta valueA

        ;; Calculate "prooportional" rest ticks
        ldy restRatioA
:       
        dey
        bmi :+
        lsr
        ;; "always" (except zero==don't matter)
        bne :-
        ;; bottomed out, maybe make it one tick?
        lda #1
:       
        sta restA

        ;; subtract from value ticks
        eor #$ff
        sec
        adc valueA
        bpl :+
        ;; safetey valve if underflow
        ;; TODO: revise? tones take at lesat 2 ticks
        lda #1
:       
        sta valueA

        jmp interpret

cmdCALLpnm:     
        ;; ...
        jmp interpret

cmdCHANNEL:
        ;; ...
        jmp interpret


;;; --- with parameter(s)

;;; (2 entries point here)
cmdSETAY:       
        ;; ...
        jmp interpret

cmdCALLlang:    
        ;; ...
        jmp interpret

cmdDRUMEXTEND:
        cpx #%111
        bne :+
        ;; RETURN

;;; TODO: pop if have left or make zero/disable
        lda #0
        sta stream+1

        ;; YIELD 
        ;; -- LOL?
;        pla
;        pla

        rts
:       
        
        

        ;; ...
        jmp interpret


;;; Playing a NOTE command
;;;   X=A=nnnnn0 Y=octave(0-7) (from dispatch)
;;; 
;;; Cycle Counts (Absolute addressing, no page crossing, includes RTS):
;;; Oct 0: 42c | Oct 1: 54c | Oct 2: 66c | Oct 3: 78c
;;; Oct 4: 36c | Oct 5: 47c | Oct 6: 58c | Oct 7: 69c
;;;
;;; 28B shift 0-7 steps, 17-122cycles (SLOW for high oct)
;;; 67B optimize by second byte array for oct>=4 (hip=0)
;;; 55B tight dual-table shifter
;;; 51B tightest opt (X=High, A=Low, No re-loads)
cmdNOTE:
.ifdef ANTTRACE
        SAVEAXY
        putc 'N'
        putc ':'
        SPC

        ;; Show note 2 char
        lda savex
        lsr
        pha
        tax
        lda note_char1,x
        jsr putchar

        pla
        tax
        lda note_char2,x
        jsr putchar

        SPC
        putc 'o'
        lda savey
        clc
        adc #'0'
        jsr putchar

        LOADAXY
.endif ; ANTTRACE
        cpy #4              ; 2
        bcs @high_oct       ; 2/3 | Branch to 8-bit logic
        
        lda period_table+1, x ; 4
        sta tmp_high          ; 3
        lda period_table, x   ; 4
        
        cpy #0              ; 2
        beq @low_done       ; 2/3
@low_loop:
        lsr tmp_high        ; 5  | 16-bit shift loop (9c per iter)
        ror                 ; 2
        dey                 ; 2
        bne @low_loop       ; 2/3
@low_done:
        ldx tmp_high        ; 3
        jmp @pitch_done      ; 3

@high_oct:
        lsr                 ; 2 | A = nnnnn (Index)
        tax                 ; 2
        lda oct4_table, x   ; 4
@high_loop:
        cpy #4              ; 2 | 8-bit shift loop (6c per iter)
        beq @high_done      ; 2/3
        lsr                 ; 2
        dey                 ; 2
        ;; always
        bne @high_loop      ; 2/3
@high_done:
        ldx #0              ; 2

@pitch_done:
        clc                 ; 2
        adc detune          ; 3
        tay                 ; 2
        txa                 ; 2
        adc detune+1        ; 3
        tax                 ; 2
        tya                 ; 2
        rts                 ; 6



.endif ; !SUPERFAST

