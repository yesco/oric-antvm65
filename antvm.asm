;;; AntVM65 - "anthem65" - the actual virtual machine


antvm:  
        ;; Channel A
        ldx #0
        jsr runchannel

        ;; Channel B
        ldx #1
        jsr runchannel

        ;; Channel C
        ldx #2
        jsr runchannel

        ;; Channel N
        ldx #3
        jsr run

        ;; Tick A
        ldax #0
        jsr tick

        rts

        
;;; X= channel 0..3 (A,B,C,N)
runchannel:
        ;;  ...
        rts


note:   
        sty ipy
        ;; "play"
        PUTC 10
        jsr _print2h

        ;; Yield
        rts



interpret:
        ;; Get command byte
        LDA (stream),y
        INY

        tax
        and #%00011111

        CMP #24                 ; 2. Note Check
        BCC note                ; 3. Fast path (0-23)

        ;; --- Command Pre-Parser ---
        stx cmd                 ; Save raw byte
        AND #%00000111          ; Isolate III
        tay

        ;; N set if has parmeter(s)
        txa                     ; Check Bit 7 (N flag)
        BPL Dispatch            ; If Bit 7 is 0

        LDA (stream),y       ; Fetch Byte 1 (Low)
        iny
        sty ipy
        pha

        ;; Optional: Fetch Byte 2 if needed
        ; LDA (StreamPtr), y  ; Fetch Byte 2 (High)
        ; TAX                 ; Store in "X" register
        ; INY

dispatch:       
        LDA cmd                 ; Get GGG 11 III
        LSR
        LSR
        LSR
        LSR
        ASL
        TAX
        
        pla

        ;; A= param, Y= iii
        JMP (groupjmps,X)       ; dispatch
1

        ;; --- The Group Jump Table ---
groupjmps:      
        .dw cmdWAIT             ; 000 11 iii
        .dw cmdCTRL             ; 001 11 iii
        .dw cmdSETAY            ; 010 11 iii
        .dw cmdVALUE            ; 011 11 iii
        .dw cmdLocalCALL        ; 100 11 iii
        .dw cmdLangCALL         ; 101 11 iii
        .dw cmdFlowDrums        ; 110 11 iii
        .dw cmdModSet           ; 111 11 iii


;;; --------------------------------------------------
;;; Command implementations
;;; 
;;; (only comamnds that "yield" should do "rts")
;;; (others "take no time" and should continue interpreting)

cmdWAIT:        
        ;; TODO: set delay

        ;; yield
        rts


cmdCTRL:        
        ;; ...
        jmp interpret


cmdSETAY:       
        ;; regs[Y] = A;
        jsr SETAYR

        jmp interpret


        ;; Group 3 (Rhythm Grid)
cmdVALUE:       
        ;; TODO: ...?
        sty nextvalueshift

        jmp interpret


cmdLocalCALL:   
        

        jmp interpret


cmdLangCALL:    

        jmp interpret


cmdFlowDrums:   
;;; 19 B (saves (- 26 19) 7 bytes cmp JMP ()
;;; (17 B doing table BRA jmp for 8 items)
        ;; ? 0
        dey
        bmi cmdTAILCALL
        ;; ? 1
        dey
        bmi cmdGOTO
        ;; ? 2
        dey
        bmi cmdBEQ
        ;; ? 3
        dey
        bmi cmdBNE

;;; TODO: Do these take a parameter?
;;;   otherwise need to "put it back"
;;;   OR: move them to single OP codes
;;; TODO: are drum sounds effected by VALUE+REST?
;;;   OR they could use a parameter?


;;; - Skip into middles
;;; - Volume
;;; - Pitch
;;; - Note/freq

;;; - retrigger every interval "ticks"
;;; - volume slides
;;; - arpeggio only for "chiptunes" for percussions effects

;;; - sample lengths are "fixed" and bleed over,
;;;   or play accumulated (or are cut-short w new one)
;;; - drums don't have rest
;;; - "empty" lines - just don't play trigger



;;; In the AY chip, the Hardware Envelope (R13) is a "fire and forget" analog-style decay, while your ticker manager likely handles "Software Envelopes" by writing to R8/R9/R10 every frame.
;;; Note on Vol Envelopes: If your ticker manager is active, ensure it doesn't overwrite Register 10 with a volume value of 0–15 immediately after these routines set it to 16 (Hardware mode), or the drum will go silent or lose its hardware 

.include "drum.asm"        



cmdBNE:
cmdBEQ: 
cmdGOTO:
cmdTAILCALL:
        ;; ...
        jmp interpret


cmdModSet:
        
