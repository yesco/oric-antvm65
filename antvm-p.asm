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
    
    ; --- Calculate Relative Step: Step16 = Current >> (8 - Config_Step) ---
    ; (Simplified for prototype: assume Step 3 = >> 5 = Quarter Tone)
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
    ; 1. Shift & Loop Mask
    lda ds_p_mask
    asl a
    rol ds_p_mask+1
    php
    adc #0
    sta ds_p_mask
    
    ; 2. 16-bit Delta Math (Carry: 0=Down, 1=Up)
    plp                ; Restore Data Bit
    bcs @p_up

@p_down:               ; Period - Step - 1
    ; (AY Period is inverse: Adding to register LOWERS pitch)
    lda ds_p_current
    adc ds_p_step      ; Carry is 0, so result is P + Step + 0
    sta ds_p_current
    lda ds_p_current+1
    adc ds_p_step+1
    sta ds_p_current+1
    jmp @p_save

@p_up:                 ; Period + Step + 1
    lda ds_p_current
    sbc ds_p_step      ; Carry is 1, so result is P - Step - 0
    sta ds_p_current
    lda ds_p_current+1
    sbc ds_p_step+1
    sta ds_p_current+1

@p_save:
    ; 12-bit Clamp: 0x0001 to 0x0FFF
    lda ds_p_current+1
    and #$0F           ; Force 12-bit
    sta ds_p_current+1
    
    ldy #0             ; AY Reg 0 (Ch A Fine)
    lda ds_p_current
    jsr SETAYR
    iny                ; AY Reg 1 (Ch A Coarse)
    lda ds_p_current+1
    jsr SETAYR

    ; 3. Sequence Logic (The "Zen" Version)
    dec ds_p_count
    bne @rts

    lda ds_p_config
    bpl ds_p_restart   ; Repeat? Reset everything.
    
    sta ds_p_delay     ; One-Shot? Kill it.
    rts
