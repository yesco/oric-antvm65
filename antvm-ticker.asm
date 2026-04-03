;;; AntVM Ticker - dispatch to work to do




.data

;;; AntVM parameter state in RAM
antvmBLOCK:     

;;; A,B,C,N, E.F.K.T == (Echo,Follow,Korus,Tglissado)
processmap:     .byte 0



antvmBLOCKEnd:     

;;; value is length of note in ticks
;;; 0 == no YIELD (sustain/legato) do manual WAIT for length
;;; (whole@120BPM =4  beats = 2.0s = 100 50Hz ticks
WHOLETICKS=100

values: 
        
valueA:         .byte WHOLETICKS
valueB:         .byte WHOLETICKS
valueC:         .byte WHOLETICKS
valueN:         .byte WHOLETICKS


rests:  

restA:          .byte 0
restB:          .byte 0
restC:          .byte 0
restN:          .byte 0


restRatios:     

restRatioA:     .byte 2
restRatioB:     .byte 2
restRatioC:     .byte 2
restRatioN:     .byte 2


;;; Zeropage: AntVM state data
.zeropage

;;; copy of processmap and shifted
tickermap:      .res 1

;;; Current channel number 0-7:ABCD EFCT
tickX:          .res 1


delays: 

delayA:         .res 1
delayB:         .res 1
delayC:         .res 1
delayN:         .res 1

delayE:         .res 1
delayF:         .res 1
delayK:         .res 1
delayT:         .res 1

.code

;;; DISPATCH BITMASK COST:
;;; 
;;; a. nothing to do: 20c (incl RTI)
;;; b. something    : 28c
;;; 
;;; c. 0bit: 12c
;;; d. 1bit: 20c (delayed)
;;; e. 1bit: 46c (triggered)

;;; d. done: 10c


;;; Ticker bitmask dispatch:
;;; 
;;; NOTHING:             20c
;;; EACH leading 0 bit:  28c
;;; EACH 1-bit
;;;   DELAY:             20c
;;;   TRIGGER:           46c
;;; DONE (if had any 1): 10c

.ifdef ANTTRACE

.data

process_char:   .byte "ABCDEFKT"

.code

.endif ; ANTTRACE


startTick:
;;; nothing to do: 20c (incl RTI)
;;; something    : 28c

        ;; move ticks forward
;;; 8c
        inc ticks
        bne :+
        inc ticks+1
:       
;;; 20c

.ifdef ANTTRACE
        ;; ticks update in ticker
        NL
        LDAX ticks
        jsr puth
.endif ; ANTTRACE

        ;; make a copy
        lda processmap
        beq donetick

        sta tickermap

        ldx #$ff
        stx tickX

nextTickBit:
;;; 3c
        ldx tickX
        lda tickermap
@next:
;;; done: 10c
;;; 0bit: 12c
;;; 1bit: 20c (delayed)
;;;       22c (trigger)
        beq donetick
        inx
        ;; rotates out next bit
        rol
        bcc @next

.ifdef ANTTRACE
pha

putc 9
lda process_char,X
jsr putchar

pla
.endif ; ANTTRACE

        ;; Bit is set for X
        dec delays,X

.ifdef ANTTRACE
        pha

        lda delays,X
        jsr put2h
        putc '-'

        pla
        ldy delays,X
.endif ; ANTTRACE

        bne @next

.ifdef ANTTRACE
PUTC '!'
.endif ; ANTTRACE

        ;; Time to do something
        stx tickX
        sta tickermap
        jmp tickerX

donetick:
        ;; RTI? or called from handler
        rts

;;; Process A tick for a bit set
;;;  X= channel 0..7
;;;  (A,B,C,N, E.F.C.T == (Echo,Follow,Chrous,Tglissado))
;;;
tickerX:
;;; 14c
        stx tickX
        lda @ticktable,X
        sta @patchbpl+1
        ;; N=0 always
@patchbpl:
        bpl @patchbpl

@ticktable:
        .byte tickCHAN -@patchbpl-2
        .byte tickCHAN -@patchbpl-2
        .byte tickCHAN -@patchbpl-2
        .byte tickCHAN -@patchbpl-2

        .byte tickECHO      -@patchbpl-2
        .byte tickFOLLOW    -@patchbpl-2
        .byte tickCHORUS    -@patchbpl-2
        .byte tickTGLISSADO -@patchbpl-2




;;; === Global Effectecs

tickECHO:
        ;; B echo A

        jmp nextTickBit

tickFOLLOW:
        ;; C follows A

        jmp nextTickBit

tickPULSEWIDTH: 
;;; TODO:


tickCHORUS:
        ;; TODO: is this on all channels

        jmp nextTickBit

tickTGLISSADO:
        ;; TODO: is this on all channels

        jmp nextTickBit



;;; === Channel Effects (Generic)


;;; X= channel: 0-3: ABCN
;;; (TODO: make it use it for selecting stack etc)
;;;        (== selecting spaced offset of stack)
tickCHAN:
        ;; are we "playing" (volA != 0)
        lda ayshadow+8, X       ; relative volA
        ; and #%1111            ; if using ENV (drum?)
        beq @notedone

        ;; PLAYING

        ;; if valueA then need to invoke restA
        lda valueA
        beq nextTickBit

        ;; do REST
        lda restA
        sta delayA
        ;; volA = 0
        lda #0
        sta ayshadow+*,X


@notedone:

;;; TODO: restore antsp for task X!

        ;; restore stream from task's X stack
        ;; (calls directly into interpret!)
        jsr cmdRETURN
        ;; (returned from YIELD)

        ;; we push stream on task's stack
        ;; (TODO: YIELD could just be "jmp pushStream") ???
        jsr pushStream

        
.ifdef ANTTRACE
        NL

;;; TODO: how do we know that we should be doing
;;;   an "imlicit" REST == SILENCE+DELAY rest (ticks)

;;; IDEA: store an imlicit "command" byte
;;;   if !=00 tells us "what to do"!

        ;; For now: print all AY regs
        putc 9
        putc 9
        putc 9
        putc 'A'
        putc 'Y'
        putc ':'

        ldx #0
:       
        lda ayshadow,X
        jsr put2h
        SPC
        inx
        cpx #14
        bne :-

        NL
.endif ; ANTTRACE

;;; TODO: these shoudl be before?
;;;   no need apply, let's default do one tick at least?
        ldx tickX
        jsr tickVolENV

        ldx tickX
        jsr tickPitENV

        ;; TOOD:: make sure delay,X is updated to "min"
        lda valueA
        sta delayA
        
;;; TODO: how to handle rest?

        jmp nextTickBit
        

tickVolENV:     

        rts

tickPitENV:     
        
        rts
