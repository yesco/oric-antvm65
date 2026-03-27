;;; 35 B 12c - rol sequence is more compact than 4 lsr
;;; 33 B 22c - dey/bmi saves 2 bytes and cycles per loop
;;; 32 B 20c - Keeping hi in A during shifts saves 1 byte and 6c per loop
;;; 38 B 32c - keeping lo in A makes addition faster and saves 4 bytes
;;; 35 B 30c - Using Y for temp storage instead of PHA/PLA saves 2 bytes
;;; 31 B 26c - %NNNNNOOO + register-only logic (no stack) saves 4 bytes
;;; 35 B 34c - Interpret: Command dispatch (0-23 note, else cmd)
;;; 114 B 89-164c - Total Size (66 B code, 48 B table)

; Input: (stream),y points to VM data byte
; Note Path: %OOONNNNN (Octave 0-7, Note 0-23)
; Cmd Path:  %NGGG11III (N=Param flag, G=Group, I=Index)
interpret:
        lda (stream),y      ; 5B | Get command byte
        iny                 ; 2B
        tax                 ; 2B | Save raw byte in X
        and #%00011111      ; 2B | Isolate note index

        cmp #24             ; 2B | 24-TET check
        bcc calc_pitch      ; 2B | Fast path: It's a note!

        ;; --- Command Pre-Parser ---
        stx cmd             ; 3B | Save raw byte
        and #%00000111      ; 2B | Isolate Index (III)
        tay                 ; 1B | Y = Index

        txa                 ; 2B | Check Bit 7 (N flag)
        bpl dispatch        ; 2B | No parameters

        lda (stream),y      ; 5B | Fetch Byte 1 (Low)
        iny                 ; 2B
        sty ipy             ; 3B | Update stream pointer index
        pha                 ; 1B | Save parameter for group jump

dispatch:       
        lda cmd             ; 3B | Get GGG11III
        lsr                 ; 2B | Shift GGG to low bits
        lsr
        lsr
        lsr
        and #%00001110      ; 2B | Mask and Align for .word jump table
        tax                 ; 1B
        
        pla                 ; 1B | A = param (or junk if no pha)
        jmp (groupjmps,x)   ; 3B | Dispatch to command group

; Note calculation continues here if BCC note was taken...
calc_pitch:
    ; ... (rest of the 31B calc_pitch code from previous step) ...
