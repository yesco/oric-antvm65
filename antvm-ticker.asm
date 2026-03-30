;;; AntVM Ticker - dispatch to work to do

using ZP:bitmap 

Called by interrrupt 50Hz so need to be superfast
```
;;; X= A,B,C,N, E.F.C.T == (Echo,Follow,Chrous,Tglissado)


;;; AntVM state data in RAM
antvmBLOCK:     

processmap:     .byte 0

antvmBLOCKEnd:     



;;; Zeropage: AntVM state data
.zeropage

tickermap:      .res 1
tickX:          .res 1

delays: 

delayA:         .res 1
delayB:         .res 1
delayC:         .res 1
delayN:         .res 1

delayE:         .res 1
delayF:         .res 1
delayC:         .res 1
delayT:         .res 1

.code



startTick:
        ;; make a copy
        lda processmap
        beq @done

        sta tickermap

        ldx #$ff
        stx tickX

nextTickBit:
        ldx tickX
@next:
        inx
        ;; rotates out next bit
        rol tickermap
        beq @done
        bcc @next

        ;; Bit is set for X
        dec delays,X
        bne @next

        ;; Time to do something
        jmp tickerX

@done:
        rti

;;; Process A tick for a bit set
;;;  X= channel 0..7
;;;  (A,B,C,N, E.F.C.T == (Echo,Follow,Chrous,Tglissado))
;;;
tickerX:
        stx tickX
        lda (ticktable),X
        sta @patchbpl+1
        ;; N=0 always
@patchbpl:
        bpl $ff

ticktable:
        .byte tickCHAN -patchbpl-2
        .byte tickCHAN -patchbpl-2
        .byte tickCHAN -patchbpl-2
        .byte tickCHAN -patchbpl-2

        .byte tickECHO      -patchbpl-2
        .byte tickFOLLOW    -patchbpl-2
        .byte tickCHROUS    -patchbpl-2
        .byte tickTGLISSADO -patchbpl-2




;;; === Global Effectecs

tickEHCO:
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
tickCHAN:
        ;; TODO: need to make interpreter 
        ;;   use X to do task
        jsr interpreter

        ldx tickX
        jsr tickVolENV

        ldx tickX
        jsr tickPitENV

        ;; TOOD:: make sure delay,X is updated to "min"

        jmp nextTickBit
        
