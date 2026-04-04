;;; a simulated antvm run

; was: Minimal BRK Handler for ca65
;;; see Play/brk.asm

.segment "CODE"

.import _putchar

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



ANTTRACE=1

;;; TODO: Dummy

SETAY:  
        rts

.include "drum.asm"


;;; load INTERPRET
.include "notes.asm"

;;; load TICKER
.include "antvm-ticker.asm"

ayheader:
        .byte "aa AA|bb BB|cc CC|nn|MM|va|vb|vc|pp PP|ee", 0

.export _main
_main:   
        lda #'V'
        jsr _putchar
        
        lda #$4a
        jsr puth

        NL
        putc '.'
        NL

init:   
       
        ;; ????
        ldy #1
        sty channels

        ;; processmap: A000 0000
        lda #%10000000
        ;lda #%11111111
        sta processmap

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

        NL
        putc '.'
        NL

        rts
halt2:  
        jmp halt2


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

