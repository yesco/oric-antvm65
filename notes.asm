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

NDATASTART:     

hifreq:         .res 256
lofreq:         .res 256

NDATAEND:       
IDATASTART:     

cmdaddr:        .res 256
        ;; TODO: populate with:
        ;; .byte note-jmpcmd-2
        ;; .byte cmdwait-jmpcmd-2
        ;; ...
        ;; .byte cmdwait-jmpcmd-2

IDATAEND:       

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
        lda lofreq,x
        sta ayshadow+0          ; TODO: A ... B C

        lda hifreq,x
        sta ayshadow+1          ; TODO: A ... B C

        jmp interpret

cmdwait:        

.else ; SMALLLUT (!BIGLUT)

;;; use lut for everything!
;;; (in this case older command bit pattern
;;;  use less lut tables!)

;;; TODO: actually oct 0-3: 96 words = 192 !
;;; TODO:          oct 4-7: 96 bytes =  96 !

NDATASTART:     

hifreq:         .res 192
lofreq:         .res 192

NDATAEND:       
IDATASTART:     

cmdaddr:        .res 64

        ;; TODO: populate with:
        ;; .byte note-jmpcmd-2
        ;; .byte cmdwait-jmpcmd-2
        ;; ...
        ;; .byte cmdwait-jmpcmd-2

IDATAEND:       

INTERPSTART:    

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
        
INTERPEND:      
NOTESTART:      

note:   
;;; 1+ 14--31c
        ;; ? oct: 0-3: use byte pitch?
        and #%111
        cmp #4
        bcs :+

        ;; yes byte pitches
        lda bytepitch,x
        sta ayshadow+0          ; TODO: A...

        lda #0
        jmp @sethi
:       

        ;; play channel A, lol
        lda lopitch,x
        sta ayshadow+0          ; TODO: A...

        lda hipitch,x
@sethi:  
        sta ayshadow+1          ; TODO: A...

        jmp interpret

cmdwait:        

NOTEEND:        

        
.endif ; !BIGLUT = SMALLLUT



.else ; BITSHIFT = !SUPERFAST



.data

.if ANTTRACE & AT_CMD
.data
        ;; Single letter MNEMOIC
        ;;     12345678
cmd_char:       
        ;; Stop Wait...
        .byte "SWWWWWWW"
        ;; sustain whole half quarter eight 16th 32th legato
        .byte "swhqestl"
        ;; CALL local.num
        .byte "12345678"
        ;; CHANNEL A; B; C; Noise; ex)tenedd Yield Quiet Kill
        .byte "ABCNxYQK"

        ;; SETAY: A.lo/hi B.lo/hi C.lo/hi noise mixer
        .byte "aabbccnm"
        ;; SETAY: vol x 3; ENV: pitch env (AY)Update DumpAY
        .byte "vvvppeUD"
        ;; CALL.lang(0-7( phonem (0-255)
        .byte "LLLLLLLL"
        ;; kick, snare, close/opne (hihat), Byte Word Return
        .byte "kscoXBWR"

;;; JSK-notation, LOL: ABC-notation uses ^/C and _/C !

note_char1:      
        ;;     0123456789012345678901234
        .byte "CCCDDDDEEEFFFFGGGGAAAABBB"
note_char2:      
        .byte " qst qst q qst qst qst qs"

.code
.endif ; ANTTRACE & AT_CMD


pow2:   
        .byte 1,2,4,8,16,32,64,128

;;; 48 bytes (Octave 0-3 base)
WORDTABLE=1

NDATASTART:     

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

NDATAEND:       

.code


;;; --- BEFORE Command Handlers ---

.macro DOYIELD
        rts
.endmacro


INTERPSTART:    


WAITSTART:      

cmdSTOP:          ; 11 000 000
        ;; TODO: ... set high delay?
        lda processmap
        ;; TODO: use "x" (hannel number)
        and #%01111111
        sta processmap

        ;; crashes???

        DOYIELD



cmdWAIT:          ; 11 000 www / 11 000 ppp
        ;; Y=value parameter

        ;; TODO: speech mode?

        ;; TODO: use a lookup table!!!
        ;; (but for different BPM???)

        ;; TODO: share code with cmdVALUE?
        ;; (- (* 2 8) (+ 8 1 (* 2 3)))
        ;; (would save 1 byte if used only 2 places)

        ;; TODO: settable "global" (/task?) parameter!
        lda #WHOLETICKS
:       
        dey
        bmi :+
        lsr
        ;; "always" (except zero==don't matter)
        bne :-

        ;; underflow => at least 1 tick!
        lda #1
:       
        sta delayA
        
        ;; Fall-through

cmdYIELD:         ; 11 011 101
        ;; Yield does RTS finishing this interpreation round
        DOYIELD


WAITEND:        


MISCSTART:     

cmdSELECT_A:      ; 11 011 000
cmdSELECT_B:      ; 11 011 001
cmdSELECT_C:      ; 11 011 010
cmdSELECT_N:      ; 11 011 011
        ldx #0
        stx channels
        tya
;;; Process several SELECT following!
@gotone:
        ;; set bit n
        tay
        lda pow2,Y
        ora channels
        sta channels
        ;; check next cmd
        ldy ipy
        lda (stream),Y
        ;; ? not SELECT -> done
        and #%11111000
        eor #%11011000
        beq @gotone

        jmp interpret



cmdEXTENDED:      ; 11 011 100|CTRL
        ;; Extended commands (no paarmeters
        jmp interpret


cmdQUIET:         ; 11 011 110
;;; TODO: only for one channel?
;;;   this is too "expensive" command for use so seldome!
        lda #0
        sta ayshadow+8+0
        sta ayshadow+8+1
        sta ayshadow+8+2

        jmp interpret


cmdKILL:          ; 11 011 111
;;; TODO: kill all
        jmp interpret

;;; TODO: put common command here to save same,
;;;   cmdNOTE? but it's so big...


MISCEND:        

;;; ^^^^ no-aram subroutines BRA backwardx!

JUMPSTART:      

interpret:
;;; 20 B  27-29c (jump to cmdNOTE or "command")


.if ANTTRACE & AT_CMD
        jsr traceCMD1
.endif ; ANTTRACE & AT_CMD

.if ANTTRACE
;;; TODO: crashes
  CHECKIPY_OVERFLOW=1
.endif ; ANTTRACE

.ifdef CHECKIPY_OVERFLOW
        jsr checkOverflow
.endif ; CHECKIPY_OVERFLOW

        ldy ipy             ; 3B | Load stream index
        lda (stream),y      ; 5B | Get command byte
        inc ipy             ; 3B | inc pointer

.if ANTTRACE & AT_CMD
        jsr traceCMD2
.endif ; ANTTRACE & AT_CMD

        ;; Extract Y=iii from "11 ccc iii"
        tax
        and #%00000111
        tay

        ;; >= 11 xxx xxx => COMMAND! otherwise NOTE!
        txa
        cmp #%11000000      ; 2B | Check if Note index >= 

        bcs command         ; 2B | If =>, it's a command
;;; TODO: maybe put note inline?
        jmp cmdNOTE


command:

.if ANTTRACE & AT_CMD
        jsr traceCMD3
.endif ; ANTTRACE & AT_CMD

;;; 23 B  26c
        ;; extract low 6 bits for command
        and #%00111111
        tax

        ;; get dispatch offset
        lda command_table, x
        sta dispatch_br+1

.if ANTTRACE & AT_CMD
        jsr traceCMD4
.endif ; ANTTRACE & AT_CMD

        ;; ? get paramter? (if X== 1cc xxx )
        cpx #%100000
        bcc no_param

        ;; A= parameter byte from stream
        sty savey

        ldy ipy
        lda (stream),y
        inc ipy

        ldy savey

.if ANTTRACE & AT_CMD
        SPC
        jsr put2h
.endif ; ANTTRACE & AT_CMD

no_param:

        ;; Do relative BRANCH
        sec
dispatch_br:
        bcs cmdRET              ; Jumps directly to cmd via SMC offset


JUMPEND:


;;; vvv param subroutines BRA forwards!





;;; --- AFTER Command Handlers ---



CALLSTART:      

cmdCALL_LOCAL:    ; 11 010 pnm
        iny
        tya       ; pnm
        ldy #antlang

        ;; fall-through

cmdCALL_LNG:      ; 11 110 lng|PHONEM
        ;; A= PHONEM Y= lng
        pha

        ;; (doesn't disturbe Y)
        jsr pushStream
        
        ;; set new "default" language
        sty antlang

;;; TODO: seems to be limited to 0--(256-2) entries, lol

;;; TODO: do something w lang vector (>128)
        pla
lda #1
        asl
        ;; skip 4 bytes header
        clc
        adc #4
        ;; double to index words
        tay
ldy #6

        bmi @overflowTODO
@overflowTODO: ;; LOL TODO:
        ;; TODO: check index is within range?

        ;; get new stream addr from index pos Y (PHONEM)

;;; TODO: handle more than "one" language
        lda language,Y
        sta stream
        iny
        lda language,Y
        sta stream+1

        ldy #0
        sty ipy

        jmp interpret


cmdRET:        ; 11 111 111
putc '@'
putc 'R'
NL
        ;; Restore
        dec antsp
        ldx antsp

        lda slostack,x
        sta stream

        lda shistack,x
        sta stream+1

        lda langstack,x
        sta antlang
        
        ;; reset ipy
        ldy #0
        sty ipy

        jmp interpret



CALLEND:        


cmdDRUM_KICK:     ; 11 111 000
        jmp cmdKickS

cmdDRUM_SNARE:    ; 11 111 001
        jmp cmdSnareSH

cmdDRUM_HH_CLS:   ; 11 111 010
        jmp cmdHiHatClosedCH

cmdDRUM_HH_OPN:   ; 11 111 011
        jmp cmdHiHatOpenTS


PARAMSTART:     

cmdEXTENDED_PAR:  ; 11 111 100|CTRL|BYTE|...
;;; TODO:
        jmp interpret


cmdPARAM_BYTE:    ; 11 111 101
        tax
        jsr antwryte

        jmp interpret

cmdPARAM_WORD:    ; 11 111 110
        ;; A= paramoffset (0-254)
        tax
        ;; lo
        jsr antwryte
        ;; lo
        inx
        jsr antwryte

        jmp interpret


PARAMEND:       

cmdSUSTAIN:       ; 11 001 000
        jmp cmdSUSTAIN_cont

cmdLEGATO:        ; 11 001 111
        jmp cmdLEGATO_cont 

cmdVALUE1:        ; 11 001 001  w)hole
cmdVALUE2:        ; 11 001 010  h)alf
cmdVALUE4:        ; 11 001 011  q)uarter
cmdVALUE8:        ; 11 001 100  e)igth
cmdVALUE16:       ; 11 001 101  s)ixteenth
cmdVALUE32:       ; 11 001 110  t)hirtysecond
;cmdVALUE:       
        jmp cmdVALUE_cont
    


AYSTART:        

cmdSETAY:         ; 11 10 rrrr
        ;; A=value, X=6-bit command
        tay

        ;; reconstruct 4-bit register from command (X)
        txa
        and #%1111
        tax
        tya
        sta ayshadow,x

        jmp interpret


cmdAYPDATE:       ; 11 10 1110
;;; TODO: maybe not worth it "too inlligent!"
;;;  (war.ym5 - not much save 280->190KB)

        jsr aypdate
        DOYIELD


cmdDUMPAY:        ; 11 10 1111
;;; 15 B
        ;; A= first byte
        ldx #0
        stx ay_reg
        jsr setayr
        ;; ay_reg==2
:       
        jsr pull_ay

        cpx #13
        bne :-
        
        DOYIELD


.include "antvm-aypdate.asm"

AYEND:  




;;; antwryte: Writes a byte from stream
;;;   X= param offset
;;; 
;;; returns: 
;;;   A= value, X= offset, Y trashed
antwryte:
        ;; lo
        ldy ipy
        lda (stream),Y
        inc ipy
        sta antvmBLOCK,X
        rts


VALUESTART:     

cmdSUSTAIN_cont:       ; 11 001 000
;;; TODO: = sustain
        ;; Allow envelop restart at new note
        ;; just no implicit YIELD (use WAIT)
        lda #0
        ;; TODO: not correct, this turns off envelopes

cmdLEGATO_cont:        ; 11 001 111
        ;; DISABLE restart envelope
        lda #0
        sta valueA

        jmp interpret

cmdVALUE_cont:       
        lda #WHOLETICKS
        ;; TODO for all seleted channels
:       
        dey
        bmi :+
        lsr
        ;; "always" (except zero==don't matter)
        bne :-
        ;; undeflow -> 1 tick
        lda #1
:       
;PUTC '@'
        sta valueA

;jsr put2h
        ;; Calculate "prooportional" rest ticks
        ldy restRatioA
:       
        dey
        bmi :+
        lsr
        ;; "always" (except zero==don't matter)
        bne :-
        ;; bottomed out
        lda #1
:       
        sta restA

;pha
;jsr put2h
;pla

;;; TDOO: this doesn't work if can cahnge REST later???
;;;   require update of VALUE

        ;; subtract from value ticks
        eor #$ff
        sec
        adc valueA
        ;; can't be 0
        bne :+
        lda #1
:       
;;; safetey valve if underflow
;;; TODO: revise? tones take at lesat 2 ticks
        sta valueA
;pha
;jsr put2h
;pla
        
        ;; enable channel ticker
        lda #%10000000

orprocessmap:
        ora processmap
storeprocessmap:       
        sta processmap
        jmp interpret


;;; TODO: cleanup
        ;; 
        ;; disable channel A ticker (?)
;;; disable channel A?
        and #%01111111

andprocessmap:
        and processmap
        jmp storeprocessmap

VALUEEND:       


KALLSUBSSTART:  

;;; Pushes current interpreter state on task stack
;;; 
;;; Y is preserved, A X used
;;; 
;;; TODO: make it relative to stack of task!
;;; (the value pushed is "noramlized" stream += ipy)

pushStream:     
;;; 31 B  ?54 c (+5c if inc; +3 ? write  ,x?)
        ldx antsp

        ;; push current lang
        lda antlang
        sta langstack,X

        ;; stream += ipy
        clc
        lda ipy
        adc stream
        sta stream
        bcc :+
        inc stream+1
:       

        ;; push current stream value
        lda stream+1
        sta shistack,X

        lda stream
        sta slostack,X

        inc antsp

        rts

KALLSUBSEND:    





INTERPEND:      







NOTESTART:      




;;; Playing a NOTE command
;;;   A=comamnd Y=octave(0-7) (from dispatch)
;;; 
;;; TODO: X= channel 0-2 (ABC)
;;; 
;;; Cycle Counts (Absolute addressing, no page crossing, includes RTS):
;;; Oct 0: 42c | Oct 1: 54c | Oct 2: 66c | Oct 3: 78c
;;; Oct 4: 36c | Oct 5: 47c | Oct 6: 58c | Oct 7: 69c
;;;
;;; 28B shift 0-7 steps, 17-122cycles (SLOW for high oct)
;;; 67B optimize by second byte array for oct>=4 (hip=0)
;;; 55B tight dual-table shifter
;;; 51B tightest opt
;;; 
;;; 
cmdNOTE:
        ;; nnnnn ooo => nnnn 0 use for LUT
        lsr
        lsr
        and #%01111110

.if ANTTRACE & AT_NOTE
        jsr traceNOTE1
.endif ; ANTTRACE

        ;; ? can use 8-bit LUT: oct 0..3
        cpy #4              ; 2
        bcs @high_oct       ; 2/3 | Branch to 8-bit logic
        


        ;; use 16-bit LUT: oct 4..7
        tax
        lda period_table+1, x ; 4
        sta antvm_tmp         ; 3
        lda period_table, x   ; 4
        
        cpy #0              ; 2
        beq :++
:       
        lsr antvm_tmp       ; 5  | 16-bit shift loop (9c per iter)
        ror                 ; 2
        dey                 ; 2
        bne :-
:       
        ldx antvm_tmp        ; 3
        jmp @pitch_done      ; 3



        ;; use 8-bit LUT: oct 4..7
@high_oct:
        ;; A= 000 nnnn (index in LUT)
        lsr                 ; 2
        tax                 ; 2
        lda oct4_table, x   ; 4
:       
        cpy #4              ; 2 | 8-bit shift loop (6c per iter)
        beq :+
        lsr                 ; 2
        dey                 ; 2
        ;; always
        bne :-
:       
        ldx #0              ; 2



;;; TODO: revsiit w pitch envelope
@pitch_done:


;;; TODO: detune not set!

;;; Store A
sta ayshadow+0
stx ayshadow+1

jmp donedone

        clc                 ; 2
        adc detune          ; 3

;;; TODO: tickX*2 ...
;;;   this only works for ONE tone
;;;   do something more clever?
;;;   when entering here X should be 0-3:A-N

        ldy #0
        sta ayshadow,Y

        adc detune+1        ; 3
        iny
        ;; to do limit?
        and #%1111
        sta ayshadow,Y

        ;; If SUSTAIN/LEGATO return
        ;; (value => interpret)
        lda valueA
        bne @hasvalue
        ;; no yield
        jmp interpret

@hasvalue:

donedone:       

;;; starts a new envelope
;;; A=value(A) 
;;; X= TODO: channel 0..3: ABCN
newenvelope:    

        sta delayA
        
        ;; mixer tone A
        lda #%00000110
        sta ayshadow+7

        ;; volA
        lda #VOLUME
        sta ayshadow+8

        DOYIELD



.endif ; BITSHIFT = !SUPERFAST

NOTEEND:        


IDATASTART:     

;;; --- Relative Dispatch Table (Base $C0) ---

.macro REL target
    .if (target - dispatch_br -2)>127
        .byte 10000+(target+2 - dispatch_br)
    .endif                    
;    .assert (target+2 - dispatch_br)>127,ERROR,"%% REL: too far away"
    .byte target - dispatch_br -2
.endmacro

.macro PREL target
    .byte (256 + target - dispatch_br + 2) .mod 256
;    .assert ((dispatch_br+2 - target) < 127),ERROR,"%% target too far"
.endmacro


command_table:

    PREL cmdSTOP    ; 11 000 000 = STOP wait for event/sync/spawn

    ; 11 000 www = WAIT.speech: 1-7 ticks: iii*20ms (32th,16th)
    ; 11 000 ppp = WAIT.music:  VALUE>>(ppp-1): 1 /2 /4 /8 /16 /32
    .repeat 7
        PREL cmdWAIT
    .endrepeat

    REL cmdSUSTAIN  ; 11 001 000 = SUSTAIN
    REL cmdVALUE1   ; 11 001 001 = VALUE1
    REL cmdVALUE2   ; 11 001 010 = VALUE/2
    REL cmdVALUE4   ; 11 001 011 = VALUE/4
    REL cmdVALUE8   ; 11 001 100 = VALUE/8
    REL cmdVALUE16  ; 11 001 101 = VALUE/16
    REL cmdVALUE32  ; 11 001 110 = VALUE/32
    REL cmdLEGATO   ; 11 001 111 = LEGATO

    ; 11 010 pnm = CALL pnm (0-7 => CALL.0: local 1-8)
    .repeat 8
        REL cmdCALL_LOCAL
    .endrepeat

    PREL cmdSELECT_A    ; 11 011 000 = CHANNEL A - select
    PREL cmdSELECT_B    ; 11 011 001 = CHANNEL B - select
    PREL cmdSELECT_C    ; 11 011 010 = CHANNEL C - select
    PREL cmdSELECT_N    ; 11 011 011 = NOISE N - select

;;; Error here if no ANTTRACE??? LOL

    PREL cmdEXTENDED    ; 11 011 100 = EXTENDED command
    PREL cmdYIELD       ; 11 011 101 = YIELD (almost same as WAIT 0?)
    PREL cmdQUIET       ; 11 011 110 = QUIET (all)
    PREL cmdKILL        ; 11 011 111 = KILL  (all)


;;; Commands that take PARAMTER(s)

    ; 11 10 rrrr|BYTE = SETAY AY[rrrr]= BYTE (2 B)
    .repeat 14
        REL cmdSETAY
    .endrepeat



;;; TODO: fix fake!!!

        REL cmdSETAY
        REL cmdSETAY

;;; TODO: these are too far away, for now not needed...

;    REL cmdAYPDATE    ; 11 10 1110|MASK|...= AYPDATE (3-13 B)
;    REL cmdDUMPAY    ; 11 10 1111|.{14 B}.= DUMPAY (14 regs)



    ; 11 110 lng|PNM = CALL.lng PNM
    .repeat 8
        REL cmdCALL_LNG
    .endrepeat

    REL cmdDRUM_KICK    ; 11 111 000|BYTE = DRUM kick "s"
    REL cmdDRUM_SNARE   ; 11 111 001|BYTE = DRUM snare "sh"
    REL cmdDRUM_HH_CLS  ; 11 111 010|BYTE = DRUM hihat(closed) "ch"
    REL cmdDRUM_HH_OPN  ; 11 111 011|BYTE = DRUM hihat(open) "ts"

    REL cmdEXTENDED_PAR ; 11 111 100|CTRL|... = EXTENDED commands
    REL cmdPARAM_BYTE   ; 11 111 101|PAR|BYTE = PARAM BYTE "param"
    REL cmdPARAM_WORD   ; 11 111 110|PAR|WORD = PARAM WORD "param"
    REL cmdRET          ; 11 111 111 = RETURN ($ff - as "expected")

IDATAEND:       


.if ANTTRACE & AT_CMD

traceCMD1:      
        NL
        putc 9
        putc 9

        lda antsp
        jsr putdigit
        putc '@'
        LDAX stream
        jsr puth
        putc '.'
        tya
        lda ipy
        jsr put2h
        putc ':'
        putc ' '
        rts

traceCMD2:      
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

        rts


traceCMD3:      
        ;; print CMD char
        SAVEAXY

        PUTC '>'

        ;; show one letter command 'name'
        and #%111111
        tay
        lda cmd_char,Y
        jsr putchar
        lda savey

        ;; show 3 low parameter bits (as digit)
        clc
        adc #'0'
        jsr putdigit
        putc ':'

;;; forcing a NL to flush, not to hide print at errrors
        NL

        LOADAXY
        rts



traceCMD4:      
        SAVEAXY

        PUTC '['
        jsr put2h
        PUTC ']'

        LOADAXY
        rts

traceNOTE1:     
        SAVEAXY

        PUTC '>'

        PUTC 'N'
        lda savey
        jsr putdigit
        putc ':'
        SPC

        ;; Show note 2 char >nnnnn< ooo
        lda savex
        lsr
        lsr
        lsr
        pha
        tax
        lda note_char1,x
        jsr putchar

        pla
        tax
        lda note_char2,x
        jsr putchar

;;; forcing a NL to flush, not to hide print at errrors
        NL

        LOADAXY
        rts

.endif ; ANTRACE & AT_CMD


.ifdef CHECKIPY_OVERFLOW

checkOverflow:  
        ;; We check for overflow, this should only
        ;; happen if we "run" too long in one "phonome"
        ;; > 240 bytes without any YIELD!
        ldy ipy
        cmp #255-1-14 -5        ; biggest==cmdDUMPAY; 5 extra
        bcc :+

        ;; OVERFLOW near!
        putc 'o'
        putc 'o'
        putc 'o'

        jmp halt
:       
        rts

.endif ; CHECKIPY_OVERFLOW

