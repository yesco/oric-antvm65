;;; a simulated antvm run

; was: Minimal BRK Handler for ca65
;;; see Play/brk.asm

;;;    5c   92 B - putc stuff + size 28 B ==	 120
;;; z04d1 1233 B ANTTRACE ==> (- 1233 120)	1113
;;; z05d0 1488 B ANTTRACE ==> (- 1488 120)	1368
;;; z0685 1669                (- 1669 1488)	 181 adding ant-vol/p
;;; z0526 1318   PRINT        (- 1318 120)      1198 TOTAL



;;; 

AT_TICK=1
AT_CMD=2
AT_NOTE=4
AT_AY=8

AT_ALL=255

;
ANTTRACE=AT_ALL

;ANTTRACE=AT_CMD+AT_NOTE


.ifndef ANTTRACE
  ANTTRACE=0
.endif

;;; Print sizes (and includes putc stuff => 120 B)

PRINT=1

.if ANTTRACE
.ifndef PRINT
        PRINT=1
.endif ; !PRINT
.endif ; ANTTRACE


.segment "CODE"

.zeropage

savea:          .res 1
savex:          .res 1
savey:          .res 1

tmp_putchar:    .res 1

.code

.macro SAVEAXY
        sta savea
        stx savex
        sty savey
.endmacro

.macro LOADAXY
        lda savea
        ldx savex
        ldy savey
.endmacro


.ifdef PRINT

.import _putchar

;;; Safe: prints A
;;; Retains A,X,Y
putchar:        
        sta tmp_putchar
        txa
        pha
        tya
        pha

        lda tmp_putchar
        jsr _putchar

        pla
        tay
        pla
        tax
        lda tmp_putchar
        rts


.macro putc char
        lda #char
        jsr putchar
.endmacro
        
.macro PUTC char
        pha
        putc char
        pla
.endmacro

.macro NL
        jsr nl
.endmacro

.macro SPC
        jsr spc
.endmacro

spc:    
        PUTC ' '
        rts

nl:     
        PUTC 10
        rts

puth:   
        pha
        txa
        jsr put2h
        pla
put2h:
        pha
        ;; hi nibble
        lsr
        lsr
        lsr
        lsr
        jsr putdigit
        ;; lo nibble
        pla
putdigit:
        and #%1111
        ora #'0'
        cmp #'9'+1
        bcc :+
        ;; hex a-f
        adc #'a'-'9'-1-1
:       
        jmp putchar
        

putb:   
        ldx #8
@loop:       
        cpx #3
        beq @spc
        cpx #6
        bne :+
@spc:
        PUTC '_'
:       
        asl

        pha
        lda #0
        adc #'0'
        jsr putdigit
        pla

        dex
        bne @loop

        rts



.endif ; PRINT




.macro LDAXD val
        lda #<val
        ldx #>val
.endmacro

.macro LDAX val
        lda val
        ldx val+1
.endmacro

.macro STAX addr
        sta addr
        stx addr+1
.endmacro


.macro PRSIZE letter,from,to
        putc letter
        putc ':'

        sec
        lda #<to
        sbc #<from
        tay

        lda #>to
        sbc #>from

        tax
        tya
        jsr puth
        NL
.endmacro



;;; Move all VM data here

.include "ant-zp.asm"

.code

;;; Gotten from print '@' START
;.org $0286
;.org $0286
;.org $1000

START:  

.include "antvm-vol.asm"
.include "antvm-p.asm"
.include "drum.asm"
.include "antvm-ticker.asm"
.include "notes.asm"            ; INTERPRET

END:    

ayheader:
        .byte "aa AA|bb BB|cc CC|nn|MM|va|vb|vc|pp PP|ee", 0

.export _main
_main:   

        lda #'V'
        jsr _putchar
        
        lda #$4a
        jsr puth

        NL


;        PRSIZE 'V',dispatch_br,cmdLENGTH
        NL
        PRSIZE 'P',DRUMSTART,DRUMEND ; percussion
        PRSIZE 'v',VOLSTART,VOLEND
        PRSIZE 'p',PITCHSTART,PITCHEND
        PRSIZE 'N',NDATASTART,NDATAEND
        PRSIZE 'n',NOTESTART,NOTEEND
        PRSIZE 'I',IDATASTART,IDATAEND
        PRSIZE 'i',INTERPSTART,INTERPEND
        NL
        NL
        PRSIZE 'w',WAITSTART,WAITEND
        PRSIZE 'm',MISCSTART,MISCEND
        NL
        PRSIZE 'j',JUMPSTART,JUMPEND
        NL
        PRSIZE 'k',CALLSTART,CALLEND
        PRSIZE 'K',KALLSUBSSTART,KALLSUBSEND
        PRSIZE 'v',LENGTHSTART,LENGTHEND
        PRSIZE 'p',PARAMSTART,PARAMEND
        NL
        PRSIZE 'y',AYSTART,AYEND
        PRSIZE 'Y',AYPDATESTART,AYPDATEEND
        PRSIZE 'S',SETAYRSTART,SETAYREND
        PRSIZE 's',setSTART,setEND

        
;;; > ./ant | head -12 | ./unhex

;; P:   97 - drum.asm                - TOOD: can be improved
;; v:   78 - antvm-vol-env.asm
;; p:  102 - antvm-p(itch)-env.asm   - hmmm 24 B more than vol?
;; N:   72 - notes pitch data        - 2*24+24
;; n:   84 - notes code              - (+ 72 84) = 156 (< 256B LUT)
;; I:   64 - dispatch data           - 6 bits dispatch (saves!)
;; i:  498 - INTERP very big!        - TODO: look at simplify!

;;; - Parts of 'i'
;; w:   22 - cmdSTOP, cmdWAIT
;; m:   46 - cmdEXTEND, cmdQUIT, cmdKILL, cmdSELECT_x

;; j:   65 - interpret: actual dispatch jmp
;; (+ 22 46 65) = 133

;; k:   60 - cmdRET, cmdCALL.local/cmdCALL.lang
;; K:   31 - pushStream
;; DRUM 12 = cmdDRUMxxx (4x jmp)
;; v:   65 - cmdLENGTH, SUSTAIN/LEGATO
;; p:   21 - cmdEXTEND, cmdPARAMBYTE, cmdPARAMWORD
;; (+ 60 31 12 65 21) = 189

;; y:  166 - cmdSETAY/cmdAYPDATE/cmdAYDUMP
;;(Y:   53 - AYUPDATE)
;;(S:   65 - SETAYR w vol hack)
;((s:   43  - only "set"))
;; (+ 133 189 166)= 488 (some after BRANCH location=AY)

;;; (+ 97 78 102 72 84 64 498) = 995 B total

;;; CHEMA (!compact): 1165: 893 B code / 272 B data / 48 B zp
;;; CHEMA COMPACT     1014: 960 B code /  54 B data / 48 B zp
;;; ANTVM:             995: 859 B code / 136 B data / ?? B zp
;;;  (antvm not working yet...)

;;; DATA: (+ 72 64) = 136 B

;;; SUM: 1082 bytes - little too big, as not finished yet!
;;;      1010 - Drum improved -72 B!
;;;      1009 - YIELD save 1 B
;;;      1007 - ayshadow instead of jsr
;;;       997 - simplify RET/CALL/stacks
;;;       995 - fix swap stack hi/lo, opt inc/dec sp


;;; Enable if we only want info
;        jmp halt

        putc '@'

        LDAXD START
        jsr puth
        NL

        putc 'z'

        lda #<END
        sec
        sbc #<START
        tay

        lda #>END
        sbc #>START

        tax
        tya

        jsr puth

        putc '.'
        NL

;;; TODO: move to antinit

init:   
       
        ;; ????
        ldy #1
        sty channels

        ;; processmap: A000 0000
        lda #%10000000
        ;lda #%11111111
        sta processmap

        
.if ANTTRACE & AT_AY
        ;; print AY header for debuggin
        putc 9
        putc 9
        putc 9
        putc 'A'
        putc 'Y'
        putc ':'

        ldx #0
:       
        lda ayheader,X
        jsr putchar
        beq :+
        inx
        bne :-
:       
        NL
.endif ; ANTTRACE & AT_AY
        
        ;; INIT state

        ldy #WHOLETICKS*3/4
        sty lengthA
        ldy #WHOLETICKS/4       ; (little silence 1/4 rel)
        sty restA

        ldy #3
        sty restRatioA

        ldy #1
        ;; needs to be 1 for not wait first tick!
        sty delayA
        dey

        ;; Initialize stream
        ;; Y=0
        sty ipy
        sty antsp

        LDAXD phonem0
        STAX stream

        jsr pushStream

        ;; pretend to be 50Hz interrupt
@loop:
        ;jsr interpret
        jsr startTick

;;; TODO: move to more generic place?
.if ANTTRACE & AT_AY
        jsr printAY
.endif ; ANTTRACE

        ;; hi-byte=0 done! (no music on ZP!)
        ldx stream+1
        bne @loop


.if ANTTRACE
        NL
        putc '.'
        NL
.endif ; ANNTRACE

        rts
halt2:  
        jmp halt2



;;; ----- Example "language"

.include "ant-cmd.asm"

language:
        ;; HEADER
        ;; TODO: "n"?
        ;; TODO: title?
        .byte 0,1
        .byte 2,3

        ;; MAIN
        .word phonem0

        ;; phonem 1-8
        .word scale1
        .word phonem2
        .word phonem3
        .word phonem4
        .word phonem5
        .word phonem6
        .word phonem7
        .word phonem8

        ;; phonems 9--255

scale1: 
        .byte _C  + OCT
        .byte _Cs + OCT
        .byte _Ds + OCT
        .byte _E  + OCT
        .byte _F  + OCT
        .byte _Fs + OCT
        .byte _G  + OCT
        .byte _Gs + OCT
        .byte _A  + OCT
        .byte _As + OCT
        .byte _B  + OCT

        .byte RET

phonem2:
phonem3:
phonem4:        
phonem5:
phonem6:
phonem7:
phonem8:
        ;; END
        .byte RET

OCT=oct4

        ;; MAIN (play "song" will launch this automatic)
phonem0: 
        .byte L32, CALL1
        .byte L16, CALL1
        .byte L8,  CALL1
        .byte L4,  CALL1
        .byte L2,  CALL1
        .byte L1,  CALL1

        .byte L1, _A  + OCT

        .byte L2, _A  + OCT
        .byte L2, _A  + OCT

        .byte L4, _A  + OCT
        .byte L4, _A  + OCT
        .byte L4, _A  + OCT
        .byte L4, _A  + OCT

        .byte L8, _A  + OCT
        .byte L8, _A  + OCT
        .byte L8, _A  + OCT
        .byte L8, _A  + OCT
        .byte L8, _A  + OCT
        .byte L8, _A  + OCT
        .byte L8, _A  + OCT
        .byte L8, _A  + OCT

        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT
        .byte L16, _A  + OCT

        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT
        .byte L32, _A  + OCT

        .byte WAIT0

        .byte L32

        .byte L16
        .byte _C  + OCT
        .byte _Cs + OCT
        .byte _Ds + OCT
        .byte _E  + OCT
        .byte _F  + OCT
        .byte _Fs + OCT
        .byte _G  + OCT
        .byte _Gs + OCT
        .byte _A  + OCT
        .byte _As + OCT
        .byte _B  + OCT

        .byte L8
        .byte _C  + OCT
        .byte _Cs + OCT
        .byte _Ds + OCT
        .byte _E  + OCT
        .byte _F  + OCT
        .byte _Fs + OCT
        .byte _G  + OCT
        .byte _Gs + OCT
        .byte _A  + OCT
        .byte _As + OCT
        .byte _B  + OCT

        .byte L4
        .byte _C  + OCT
        .byte _Cs + OCT
        .byte _Ds + OCT
        .byte _E  + OCT
        .byte _F  + OCT
        .byte _Fs + OCT
        .byte _G  + OCT
        .byte _Gs + OCT
        .byte _A  + OCT
        .byte _As + OCT
        .byte _B  + OCT


;;; just to get offset right
;.byte %11000000                 ; cmdSTOP

        ;; minimal length => 1,1
        .byte L32

        .byte _Ds + OCT
        .byte _E  + OCT

;;; TODO: Crashes! (because does yield?)
;        .byte %11000000

;;; TODO:

        ;; Explicit timing (SUSTAIN/LEGATO)
;        .byte SUSTAIN



;;; TODO: are these correct?
        .byte WAIT1
        .byte WAIT2

        .byte _F  + OCT
        .byte WAIT3
        .byte _G  + OCT
        .byte WAIT1

        .byte _Gs + OCT

        .byte STOP        ; STOP

        ;; return from non-call? lol
        .byte RET






;;; TODO: remove? or add real ISR (for oric)



; 1. Main Entry Point
brkmain:
        ;; install handler
        lda #<irq_brk_handler
        ldx #>irq_brk_handler
        sta $fffe
        stx $fffe+1

        sei
        cld
        ldx #$FF
        txs
        
        ;; meat
        lda #'A'
        jsr _putchar


        ldy #0

        brk
        iny
        iny

        brk
        iny
        iny

        brk
        iny
        iny
        
        clc
        tya
        adc #'0'
        jsr _putchar
halt:
        jmp halt

; 2. The BRK/IRQ Handler
;
; When BRK happens, the CPU pushes PC+2 (or +1) and P (with B flag set)
irq_brk_handler:
        pha
        txa
        pha
        tya
        pha

        lda #'B'
        jsr _putchar

        ;; --- Exit the handler ---
        pla
        tay
        pla
        tax
        pla

        ;; should skip one more byte than rti!
;rti
        plp
        rts


; 3. Vector Table
;.segment "VECTORS"
;    .addr $0000     ; NMI
;    .addr start     ; RESET
;    .addr irq_brk_handler ; IRQ/BRK

