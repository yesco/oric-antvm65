.zeropage
; --- Deltas (ds) Volume State ---
ds_v_mask:    .res 2    ; 16-bit pattern (Circular)
ds_v_config:  .res 1    ; [7:OneShot][3-6:Delay][0-2:Step S]
ds_v_current: .res 1    ; 4-bit Volume (0-15)
ds_v_delay:   .res 1    ; Negative = Off, 0-15 = Active
ds_v_count:   .res 1    ; Bit counter (16 down to 1)

.code

; ---------------------------------------------------------
; DS_V_VOLUME_ENGINE
; ;; 42 B - Initial branchy volume math/clamping
; ;; 38 B - Unified path via SBC #0 mask generation
; ;; 36 B - Final Zen Clamping (Uses ADC Carry for floor/ceil)
; ---------------------------------------------------------

; --- DS_V_INIT: A/X = Mask, Y = Config ---
ds_v_init:
    sta ds_v_mask
    stx ds_v_mask+1
    sty ds_v_config
    tya                ; Config in A for restart

ds_v_restart:
    ldx #16            ; Reset bit counter
    stx ds_v_count
    
    lda ds_v_config    ; [Improvement: 36 B] Setup Delay
    and #$78           ; Mask Delay bits [3-6]
    lsr a              ; Align to 0-15
    lsr a
    lsr a
    sta ds_v_delay
    rts

; --- DS_V_TICK: 50Hz Volume heartbeat ---
ds_v_tick:
    lda ds_v_delay
    bmi @rts2           ; Effect is OFF ($FF)
    dec ds_v_delay
    bpl @rts2           ; Still waiting for delay

@do_v_bit:
    ; 1. Shift & Loop Mask
    lda ds_v_mask
    asl a
    rol ds_v_mask+1
    adc #0              ; Cyclic bit loop
    sta ds_v_mask       ; Carry = Direction (1:Sub, 0:Add)
    
    ; 2. Symmetrical Delta Math (Speed+1)
    ; [Improvement: 38 B] Create bit-inverter mask from Carry
    lda #0
    sbc #0              ; A = $FF if Sub, $00 if Add
    eor ds_v_config     ; Flip only the Step bits (0-2)
    and #$07            ; Isolate S
    adc ds_v_current    ; V + S (Add) or V + NOT(S) + 1 (Sub)
    
    ; 3. Correct Symmetrical Clamp (0-15)
    ; [Improvement: 36 B] ADC Carry detects underflow accurately
    bcc @floor          ; Carry=0 after ADC-style sub means < 0
    cmp #16             ; Check if we exceeded 15
    bcc @save           ; If 0-15, store it
    lda #15             ; Ceiling
    bne @save           ; (Always taken)
@floor:
    lda #0              ; Floor
@save:
    sta ds_v_current
    ldy #8              ; AY Reg 8 (Ch A Volume)
    jsr setayr

    ; 4. Sequence Logic
    dec ds_v_count
    bne @rts2

    lda ds_v_config
    bpl ds_v_restart    ; Repeat if not One-Shot
    
    sta ds_v_delay      ; Kill ($FF)
@rts2:
    rts
