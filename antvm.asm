.zeropage
; --- Deltasequence (ds) State ---
ds_mask:    .res 2    ; 16-bit pattern (orbits itself)
ds_config:  .res 1    ; [7:Repeat][4-6:Speed][0-3:Step]
ds_current: .res 1    ; 4-bit Volume (0-15)
ds_delay:   .res 1    ; -1 = Off, 0-7 = Active/Delay
ds_count:   .res 1    ; 16-bit counter (only for one-shot)

.code

; ---------------------------------------------------------
; DS_INIT: Initialize the delta sequence
; Input: A/X = Mask Lo/Hi, Y = Config
; ---------------------------------------------------------
ds_init:
    sta ds_mask
    stx ds_mask+1
    sty ds_config
    lda #16
    sta ds_count
    
    lda ds_config      ; Extract Speed (bits 4-6)
    lsr a
    lsr a
    lsr a
    lsr a
    and #$07           ; Reset delay to speed
    sta ds_delay
    rts

; ---------------------------------------------------------
; DS_TICK: The 50Hz Update
; ---------------------------------------------------------
ds_tick:
    lda ds_delay
    bmi @done           ; If $FF, sequence is finished
    beq @do_bit         ; If 0, process next bit
    dec ds_delay
    rts

@do_bit:
    ; 1. Fully Cyclic 16-bit Shift (Destructive but Circular)
    lda ds_mask
    asl a               ; Shift Lo-Byte Bit 7 into Carry
    rol ds_mask+1       ; Rotate Carry into Hi-Byte, Hi-Byte Bit 7 into Carry
    php                 ; Save the Bit for ADC and Logic
    adc #0              ; Add Carry back to A (Lo-Byte)
    sta ds_mask
    plp                 ; Restore Bit into Carry for Delta Logic

    ; 2. Update Volume (Optimized: No CLC/SEC)
    bcs @vol_up         ; Carry=1: ADC Vol + Step + 1

@vol_down:              ; Carry=0: SBC Vol - Step - 1
    lda ds_current
    sbc ds_config       ; Sub step (bits 0-3)
    bcs @save_vol       ; If result >= 0, save
    lda #0              ; Clamp Min
    beq @save_vol

@vol_up:                ; Carry=1: ADC Vol + Step + 1
    lda ds_current
    adc ds_config       ; Add step (bits 0-3)
    and #$0F            ; 4-bit limit
    cmp #16             ; Overflow 15?
    bcc @save_vol
    lda #15             ; Clamp Max

@save_vol:
    sta ds_current
    ldy #8              ; Target AY Reg (Ch A Vol)
    jsr SETAYR

    ; 3. Reset Speed Delay
    lda ds_config
    lsr a
    lsr a
    lsr a
    lsr a
    and #$07
    sta ds_delay

    ; 4. Check Sequence Length (Only matters for One-Shot)
    bit ds_config       ; Check Repeat bit (7)
    bmi @done           ; If repeating, just exit (mask cycles forever)
    
    dec ds_count
    bne @done           ; If not 16 bits yet, exit
    
    lda #$FF            ; Otherwise, disable sequence
    sta ds_delay

@done:
    rts
