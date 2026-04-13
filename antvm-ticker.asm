;;; AntVM Ticker - dispatch to work to do


;;; Ticker bitmask dispatch:
;;; 
;;; NOTHING:             20c (incl RTS)
;;; SOMETHING:           29c (incl RTS)
;;; 
;;; EACH leading 0 bit:   7c
;;; EACH 1-bit
;;;   DELAY:             17c
;;;   TRIGGER:           34c
;;;   PROCESSING:        ??c
;;; 
;;; DONE (if had any 1):  1c

.if ANTTRACE

.data

process_char:   .byte "ABCDEFKT"

.code

.endif ; ANTTRACE



;;; LOL, we put it at top to make the
;;; normal path 2c insteead of 3c!
donetick:
        ;; 6c
        ;; TODO: RTI? or called from handler
.if ANTTRACE & AT_TICK
        putc '<'
.endif
        rts


startTick:
        ;; nothing to do: 20c (incl RTI)
        ;; something    : 28c

        ;; move ticks forward
        ;; 8c
        inc ticks
        bne :+
        inc ticks+1
:       

.if ANTTRACE & AT_TICK
        NL
        LDAX ticks
        jsr puth
.endif ; ANTTRACE & AT_TICK

        ;;   no set:  6c
        ;;   copy  : 13c

        ;; make a copy
        lda processmap
        ;; technically this test is redundant
        ;; (adds 2c but early exit -17c!)
        beq donetick           

        sta tickermap

        ldx #$ff
        stx tickX

nextTickBit:
        ;; 10c(+1c)
        ;; done: 9c+6c(RTS)
        ldx tickX

        ;; Check if any bit set
        lda tickermap
@nextAfterOne:
        ;; we need to set flags again! - lol
        tay
        beq donetick

        ;; We only enter if there is a bit set!
        ;; 0bit:  7c
        ;; 1bit: 15c (delayed)
        ;;       21c (triggered)
@next:
        inx
        ;; rotates out next bit
        asl
        bcc @next

;;; TODO: somehow calling this code is vital,
;;;   otherwise crash, lol?
;.ifnblank                      

.if ANTTRACE ;& AT_TICK
;;; this doesn't get 4 but 1
;.if ANTTRACE & AT_TICK
pha
txa
pha

;putc 9
putc ' '
lda process_char,X
jsr putchar

pla
tax
pla
.endif ; ANTTRACE & AT_TICK

        ;; Bit is set for X
        dec delays,X

.if ANTTRACE & AT_TICK
        pha

        lda delays,X
        jsr put2h
        putc '-'

        pla
        ;; reestablish flags
        ldy delays,X
.endif ; ANTTRACE & AT_CMD

        bne @nextAfterOne

.if ANTTRACE & AT_TICK
PUTC '!'
.endif ; ANTTRACE & AT_CMD

        ;; Time to do something
        stx tickX
        sta tickermap

        ;; TODO: for now, just make freerunning (length0 safe)
        ;;   SUSTAIN & LEGATO
        lda #1
        sta delays,X


;;; Process A tick for a bit set
;;;  X= channel 0..7
;;;  (A,B,C,N, E.F.C.T == (Echo,Follow,Chrous,Tglissado))
;;;
tickerX:
;;; 14c
        lda @tickbranches,X
        sta @patchbpl+1
        ;; N=0 always
@patchbpl:
        bpl @patchbpl

@tickbranches:
        .byte tickCHAN -@patchbpl-2
        .byte tickCHAN -@patchbpl-2
        .byte tickCHAN -@patchbpl-2
        ;; TODO: special?
        .byte tickCHAN -@patchbpl-2


        .byte tickECHO      -@patchbpl-2
        .byte tickFOLLOW    -@patchbpl-2
        .byte tickKHORUS    -@patchbpl-2
        .byte tickTGLISSADO -@patchbpl-2




;;; === Global EFfeKTs :-D

tickECHO:
        ;; B echo A

        jmp nextTickBit


tickFOLLOW:
        ;; C follows A

        jmp nextTickBit


tickPULSEWIDTH: 
;;; TODO:


tickKHORUS:
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

        ;; "Articulator" Playing the note

        ;; if lengthA then need to invoke restA
        lda lengths,x
        beq nextTickBit

        ;; - do REST
        lda rests,x
        sta delays,x

        ;; - turn off channel sound (A-C)


;;; TODO: Noise (bit?), just have differnt dispatch routine!
        cpx #3
        beq nextTickBit



        lda #0
        sta ayshadow+8,X
:       
        beq nextTickBit


@notedone:

;;; TODO: restore antsp for task X!

        ;; restore stream from task's X stack
        ;; (calls directly into interpret!)
        jsr cmdRET
        ;; (returned from YIELD)

        ;; we push stream on task's stack
        ;; (TODO: YIELD could just be "jmp pushStream") ???
        jsr pushStream

      
;;; TODO: these shoudl be before?
;;;   no need apply, let's default do one tick at least?
        ldx tickX
        jsr tickVolENV

        ldx tickX
        jsr tickPitENV

        ;; TOOD:: make sure delay,X is updated to "min"
        lda lengthA
        sta delayA
        
;;; TODO: how to handle rest?

        jmp nextTickBit
        

tickVolENV:     

        rts


tickPitENV:     
        
        rts




.if ANTTRACE & AT_AY
printAY:        
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

        rts
.endif ; ANTTRACE

