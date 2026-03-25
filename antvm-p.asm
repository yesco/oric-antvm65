.zeropage
; --- Deltas (ds) Pitch State ---
ds_p_mask:    .res 2    ; 16-bit pattern (Circular)
ds_p_config:  .res 1    ; [7:OneShot][3-6:Delay][0-2:Step]
ds_p_current: .res 2    ; 16-bit Current Period (Reg 0/1)
ds_p_step:    .res 2    ; 16-bit Calculated Step (P >> (8-S))
ds_p_delay:   .res 1    ; Negative = Off, 0-15 = Active
ds_p_count:   .res 1    ; Bit counter (16 down to 1)

.code

; ---------------------------------------------------------
; DS_P_INIT: A/X = Mask, Y = Config
; ---------------------------------------------------------
ds_p_init:
    sta ds_p_mask
    stx ds_p_mask+1
    sty ds_p_config
    tya                ; Config in A for restart

ds_p_restart:
    ldx #16            ; Reset bit counter
    stx ds_p_count
    
    ; --- Calculate Relative Step ---
    lda ds_p_current+1 ; High byte
    sta ds_p_step+1
    lda ds_p_current   ; Low byte
    sta ds_p_step
    
    ldx #5             ; Example: Fixed shift for Quarter Tone
@shift:
    lsr ds_p_step+1
    ror ds_p_step
    dex
    bne @shift

    lda ds_p_config    ; Reload A with config for delay logic
    and #$78           ; Mask Delay bits
    lsr a
    lsr a
    lsr a
    sta ds_p_delay
@rts:
    rts

; ---------------------------------------------------------
; DS_P_TICK: 50Hz Tone Heartbeat
; ---------------------------------------------------------
ds_p_tick:
    lda ds_p_delay
    bmi @rts
    dec ds_p_delay
    bpl @rts

@do_bit:
    ; 1. Shift & Loop Mask (Cyclic)
    lda ds_p_mask
    asl a
    rol ds_p_mask+1
    adc #0             ; Loop the carry bit back into the low byte
    sta ds_p_mask      ; Carry = 1 (Pitch Up), 0 (Pitch Down)

    ; 2. Branchless Symmetrical Math (Speed+1)
    ; Create an EOR mask in X: $00 if C=0, $FF if C=1
    lda #0
    sbc #0             ; If C=0, A=0. If C=1, A=$FF.
    tax                ; X is now our bitwise "inverter"

    ; --- Low Byte ---
    eor ds_p_step      ; Invert step bits if C=1
    ; Carry is still set if we are subtracting, providing the +1 for SBC
    adc ds_p_current
    sta ds_p_current
    
    ; --- High Byte ---
    txa                ; Restore inverter mask
    eor ds_p_step+1
    adc ds_p_current+1 ; Propagate carry from low byte
    sta ds_p_current+1

@p_save:
    ; 12-bit Clamp: 0x0001 to 0x0FFF
    lda ds_p_current+1
    and #$0F           
    sta ds_p_current+1
    
    ldy #0             ; AY Reg 0
    lda ds_p_current
    jsr SETAYR
    iny                ; AY Reg 1
    lda ds_p_current+1
    jsr SETAYR

    ; 3. Sequence Logic
    dec ds_p_count
    bne @rts

    lda ds_p_config
    bpl ds_p_restart   ; Repeat?
    
    sta ds_p_delay     ; One-Shot? Kill it ($FF).
    rts
