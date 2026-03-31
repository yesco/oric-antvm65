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

;;; load INTERPRET
.include "notes.asm"

.export _main
_main:   
        lda #'V'
        jsr _putchar
        
        lda #$4a
        jsr puth

        NL
        putc '.'
        NL

        LDAXD phonem
        STAX stream
        ldy #0
        sty ipy

@loop:       
        jsr interpret
        ;; hi-byte=0 done! (no music on ZP!)
        ldx stream+1
        bne @loop


        NL
        putc '.'
        NL

halt2:  
        jmp halt2


langauge:       
phonem: 
        .byte %00000100
        .byte %00001100
        .byte %00010100
        .byte %00011100
        .byte %00100100
        .byte %00101100
        .byte %00110100
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

