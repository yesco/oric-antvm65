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

;ANTTRACE=AT_ALL
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


START:  

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



.include "antvm-vol.asm"

.include "antvm-p.asm"

.include "drum.asm"

;;; load TICKER
.include "antvm-ticker.asm"

;;; load INTERPRET
.include "notes.asm"

ayheader:
        .byte "aa AA|bb BB|cc CC|nn|MM|va|vb|vc|pp PP|ee", 0

.export _main
_main:   

.if ANTTRACE
        lda #'V'
        jsr _putchar
        
        lda #$4a
        jsr puth

        NL

.endif ; ANTTRACE

.ifdef PRINT


TODO:   

;(+ 9 66 26 7 11 3 42) === 164 !!!! too big...


;00022Cr 2     9         cmdSTOP:          ; 11 000 000
;000235r 2    66         cmdWAIT:          ; 11 000 www / 
;000277r 2    26         cmdSELECT_A:      ; 11 011 000
;....          7         cmdEXTEND cmdYIELD
;             11         cmdQUIET:
;0002A3r 2     3         cmdKILL:          ; 11 011 111

;0002A6r 2    42         interpret:
;0002D0r 2     2         dispatch_br:

;(+ 14 4 15 3 29 27 18 11)= 121
;0002D2r 2    14         cmdSETAY:         ; 11 10 rrrr
;0002E0r 2     4         cmdAYPDATE:       ; 11 10 1110
;0002E4r 2    15         cmdDUMPAY:        ; 11 10 1111

;0002F3r 2     3         cmdCALL_LOCAL:    ; 11 010 pnm
;0002F6r 2    29         cmdCALL_LNG:      ; 11 110 lng|PHO
;000313r 2    27         cmdDRUM_KICK:     ; 11 111 000
;00032Er 2    18         cmdPARAM_BYTE:    ; 11 111 101
;000335r 2    11         cmdPARAM_WORD:    ; 11 111 110

;000340r 2    39         cmdRETURN:        ; 11 111 111
;00035Dr 2    10         cmdSUSTAIN:       ; 11 001 000
;000367r 2               cmdVALUE:





;;; cmdNOTE:

;; 000238r 2      9    9   cmdSTOP:          ; 11 000 000
;; 000241r 2     66   75   cmdWAIT:          ; 11 000 www / 1
;; 000283r 2     55        cmdSUSTAIN:       ; 11 001 000
;; 0002BAr 2     50        cmdCALL_LOCAL:    ; 11 010 pnm
;; 0002ECr 2      3        cmdKILL:          ; 11 011 111

;; 0002EFr 2    205        interpret: ; LOT'S ANTTRACE bytes!

;; 0003BCr 2               dispatch_br:
;; 0003BEr 2     14  107   cmdSETAY:         ; 11 10 rrrr
;; 0003CCr 2      4   93   cmdAYPDATE:       ; 11 10 1110
;; 0003D0r 2     15   89   cmdDUMPAY:        ; 11 10 1111
;; 0003DFr 2     29   74   cmdCALL_LNG:      ; 11 110 lng|PHO
;; 0003FCr 2     24   45   cmdDRUM_KICK:     ; 11 111 000
;; 000414r 2      3   21   cmdEXTENDED_PAR:  ; 11 111 100|CTR
;; 000417r 2      7   18   cmdPARAM_BYTE:    ; 11 111 101
;; 00041Er 2     11   11   cmdPARAM_WORD:    ; 11 111 110
;; 000429r 2     29    0   cmdRETURN:        ; 11 111 111
;; (- #x446 #x429)

;; 000446r 2               cmdNOTE:

;;; 180
;DFROM=cmdSTOP
;DTO=cmdKILL

;cmdSETAY:         ; 11 10 rrrr

;;; 109
DFROM=dispatch_br
DTO=cmdVALUE

        putc 'c'
        sec
        lda #<DTO
        sbc #<DFROM
        tay

        lda #>DTO
        sbc #>DFROM

        tax
        tya
        jsr puth

        jmp halt


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
.endif ; PRINT

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
        sty valueA
        ldy #WHOLETICKS/4       ; (little silence 1/4 rel)
        sty restA

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


END:    



langauge:       
        ;; HEADER
        .byte 0,1,2,3
        .word phonem0
        .word phonem1
        .word phonem2
        .word phonem3
        .word phonem4
        .word phonem5
        .word phonem6
        .word phonem7
        .word phonem8
phonem1:
phonem2:
phonem3:
phonem4:        
phonem5:
phonem6:
phonem7:
phonem8:
        ;; END
        .byte $ff

        ;; MAIN
phonem0: 
        .byte %00000100
        .byte %00001100
        .byte %00010100

;        .byte %11001111         ; LEGATO
;        .byte %11001000         ; SUSTAIN
;        .byte %11001110        ; VALUE6
;        .byte %11001100        ; VALUE4
;        .byte %11001001         ; VALUE1 = WHOLE
;        .byte %11001010         ; VALUE2 = HALF

;;; just to get offset right
.byte %11000000                 ; cmdSTOP

        ;; minimal length => 1,1
        .byte %11001110       ; VALUE6

        .byte %00011100
        .byte %00100100

;;; TODO: Crashes! (because does yield?)
;        .byte %11000000

;;; Loop writing :1:1:1:1:1:1:1 .... lol?
        .byte %11000001
        .byte %11000010

        .byte %00101100
        .byte %11000001
        .byte %00110100
        .byte %11000001
        .byte %00110100
        
        .byte $ff





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

