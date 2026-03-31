;;; a simulated antvm run

; was: Minimal BRK Handler for ca65
;;; see Play/brk.asm

.segment "CODE"

.import _putchar

.macro putc char
        lda #char
        jsr _putchar
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
        PUTC '$'
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
        jmp _putchar
        

.export _main
_main:   
        lda #'V'
        jsr _putchar
        
        lda #$4a
        jsr puth

        NL
        putc '.'
        NL




halt2:  
        jmp halt2


langauge:       
phonem: 
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

