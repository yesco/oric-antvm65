.zeropage
ds_mask:    .res 2    ; 16-bit pattern (Circular)
ds_config:  .res 1    ; [7:OneShot][3-6:Delay][0-2:Step]
ds_current: .res 1    ; 4-bit Volume (0-15)
ds_delay:   .res 1    ; Negative = Off, 0-15 = Active
ds_count:   .res 1    ; Bit counter (16 down to 1)

.code

; ---------------------------------------------------------
; DS_INIT: A/X = Mask, Y = Config
; ---------------------------------------------------------
ds_init:
    sta ds_mask
    stx ds_mask+1
    sty ds_config
    tya                ; Config in A for restart

ds_restart:
    ldx #16            ; Reset bit counter
    stx ds_count
    and #$78           ; Mask Delay bits
    lsr a              ; Align 0-15
    lsr a
    lsr a
    sta ds_delay
@rts:
    rts

; ---------------------------------------------------------
; DS_TICK: The 50Hz heartbeat
; ---------------------------------------------------------
ds_tick:
    lda ds_delay
    bmi @rts            ; Bit 7 set? Dead.
    dec ds_delay
    bpl @rts            ; Not zero? Exit.

@do_bit:
    ; 1. Shift & Loop Mask
    lda ds_mask
    asl a
    rol ds_mask+1
    php                 ; Save Bit
    adc #0              ; Loop back
    sta ds_mask
    
    ; 2. Delta Math
    lda ds_config
    and #$07            ; Step
    plp                 ; Restore Bit
    bcs @calc           
    eor #$FF            ; Down: -Step-1

@calc:
    adc ds_current      
    bpl @ok             
    lda #0              ; Clamp Min
@ok:
    cmp #16             
    bcc @save           
    lda #15             ; Clamp Max

@save:
    sta ds_current
    ldy #8              ; AY Ch A Vol
    jsr SETAYR

    ; 3. Sequence Logic (The "Listen" Version)
    dec ds_count
    bne @rts            ; Bits remain? EXIT. Next tick handles delay.

    ; --- End of 16-bit cycle ---
    lda ds_config
    bpl ds_restart      ; Repeat? Full reset.
    
    ; --- End of One-Shot ---
    sta ds_delay        ; Config bit 7 is 1, so ds_delay becomes negative.
    rts
