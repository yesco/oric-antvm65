; ---------------------------------------------------------------------------
; cmdAYUPDATE
; A = Mask (The "Baseball" Header)
; X, Y = Trashed
; ---------------------------------------------------------------------------
cmdAYUPDATE:
    sta tmp_mask            ; Save header to check bits later
    
    ; --- Handle Channels A (X=0), B (X=2), C (X=4) ---
    ldx #0                  ; Start with Channel A (R0/R1)
@channel_loop:
    lsr tmp_mask            ; Shift bit 1, 2, 3 into Carry (Upd A, B, C)
    bcc @next_ch            ; If Carry=0, this channel isn't in the stream

    ; Read Pitch Lo (always present if channel bit is set)
    ldy ipy
    lda (stream),y
    inc ipy
    
    ; Update Pitch Lo (X is 0, 2, or 4)
    txy                     ; Y = Register index
    jsr setayr
    
    ; Check Bit 0 (Coarse Flag) from original mask
    lda tmp_mask
    bit #%00000001          ; We check bit 0 (Coarse)
    beq @low_update         ; Bit 0 = 0: Low Update logic

@high_update:
    ; Read Pitch Hi + Vol byte
    ldy ipy
    lda (stream),y
    inc ipy
    iny                     ; Y = X + 1 (Pitch Hi register)
    tya                     ; Transfer index to Y for setayr
    ldy #0                  ; Dummy clear or setup for setayr if needed
    txy                     ; Restore X-based index
    iny                     ; Target R1, R3, or R5
    jsr setayr              ; setayr handles the High/Vol split internally
    jmp @next_ch

@low_update:
    ; Check Bit 4 (Volume Flag)
    lda tmp_mask
    and #%00010000          ; Check bit 4
    beq @next_ch            ; No volume update
    
    ldy ipy
    lda (stream),y          ; Read Volume byte
    inc ipy
    
    ; Map X (0,2,4) to Vol Reg (8,9,10) -> (X/2) + 8
    txa
    lsr                     ; 0, 1, 2
    clc
    adc #8                  ; 8, 9, 10
    tay                     ; Y = Target Volume Register
    jsr setayr

@next_ch:
    inx
    inx                     ; Move to next channel registers
    cpx #6                  ; Done with A, B, and C?
    bne @channel_loop

    ; --- Bit 5: Mixer (R7) ---
    lda tmp_mask
    and #%00100000
    beq @check_noise
    ldy ipy
    lda (stream),y
    inc ipy
    ldy #7
    jsr setayr

@check_noise:
    ; --- Bit 6: Noise (R6) ---
    lda tmp_mask
    and #%01000000
    beq @done
    ldy ipy
    lda (stream),y
    inc ipy
    ldy #6
    jsr setayr

@done:
    rts

.bss
tmp_mask: .res 1
