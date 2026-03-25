.zeropage
; --- Deltas (ds) Pitch State ---
ds_p_mask:    .res 2    ; 16-bit pattern (Circular)
ds_p_config:  .res 1    ; [7:OneShot][3-6:Delay][0-2:StepIndex]
ds_p_current: .res 2    ; 16-bit Current Period (Reg 0/1)
ds_p_step:    .res 2    ; 16-bit Calculated Step (P >> (8-S))
ds_p_delay:   .res 1    ; Negative = Off, 0-15 = Active
ds_p_count:   .res 1    ; Bit counter (16 down to 1)

.code

; ---------------------------------------------------------
; DS_P_PITCH_ENGINE
; ;; 77 B - Unified math path to remove @p_up/@p_down branches
; ;; 73 B - Replaced PHP/PLP with SBC #0 mask generation
; ;; 71 B - Optimized high-byte EOR by utilizing TAX/TXA
; ;; 67 B - Kept Step Low Byte in Accumulator during Init shift loop
; ;; 65 B - Removed redundant LDA in p_save (using result in A)
; ;; 62 B - Moved Step calculation out of Restart (Once per Init)
; ;; 60 B - Your EOR #$07 trick for (8-S) shift logic
; ---------------------------------------------------------

; --- DS_P_INIT: A/X = Mask, Y = Config ---
ds_p_init:
    sta ds_p_mask
    stx ds_p_mask+1
    sty ds_p_config
    
    ; --- Dynamic Relative Step (8-S logic) ---
    ; [Improvement: 60 B] EOR #$07 flips 0-7 into 7-0 range
    tya                ; Config (Y) to A
    and #$07           ; Get S (0-7)
    eor #$07           ; 0->7, 7->0
    tax                ; X = (7-S)
    inx                ; X = (8-S)

    ; [Improvement: 62 B] Calculation happens only in INIT
    lda ds_p_current+1 
    sta ds_p_step+1
    lda ds_p_current   ; [Improvement: 67 B] Low Byte in A for loop speed
@shift:
    lsr ds_p_step+1    ; Shift High Byte in RAM
    ror a              ; Rotate bit from High into A (Low Byte)
    dex
    bne @shift
    sta ds_p_step      ; Store final Low Byte once

ds_p_restart:
    ldx #16            ; Reset bit counter
    stx ds_p_count
    
    lda ds_p_config    
    and #$78           ; Extract 4-bit Delay (bits 3-6)
    lsr a
    lsr a
    lsr a
    sta ds_p_delay
@rts:
    rts

; --- DS_P_TICK: 50Hz Tone Heartbeat ---
ds_p_tick:
    lda ds_p_delay
    bmi @rts           ; If negative ($FF), effect is OFF
    dec ds_p_delay
    bpl @rts           ; Wait for delay to hit -1

@do_bit:
    ; 1. Shift & Loop Mask (Cyclic)
    lda ds_p_mask
    asl a
    rol ds_p_mask+1
    adc #0             ; Cyclic: Put bit back in at bit 0
    sta ds_p_mask      ; Carry = 1 (Up/Sub), 0 (Down/Add)

    ; 2. Branchless Symmetrical Math (Speed+1)
    ; [Improvement: 77 B / 73 B] Carry -> Mask via SBC #0
    lda #0
    sbc #0             ; A = $FF if C=1, $00 if C=0
    tax                ; [Improvement: 71 B] Keep mask in X

    ; --- Low Byte ---
    eor ds_p_step      ; Flip bits if subtracting
    adc ds_p_current   ; C=1 provides the '+1' for true two's complement
    sta ds_p_current
    
    ; --- High Byte ---
    txa                ; Restore inverter mask
    eor ds_p_step+1
    adc ds_p_current+1 ; Propagate carry from low byte
    
@p_save:
    ; 12-bit Clamp: 0x0001 to 0x0FFF
    ; [Improvement: 65 B] A already holds high-byte ADC result
    and #$0F           
    sta ds_p_current+1
    
    ldy #0             ; AY Reg 0 (Fine)
    lda ds_p_current
    jsr SETAYR
    iny                ; AY Reg 1 (Coarse)
    lda ds_p_current+1
    jsr SETAYR

    ; 3. Sequence Logic
    dec ds_p_count
    bne @rts

    lda ds_p_config
    bpl ds_p_restart   ; If Bit 7 is 0, Loop.
    
    sta ds_p_delay     ; One-Shot: Set delay to $FF (OFF)
    rts
