.zeropage
; --- Deltas (ds) Volume State ---
ds_mask:    .res 2    ; 16-bit pattern (Circular)
ds_config:  .res 1    ; [7:Repeat][3-6:Delay][0-2:Step]
ds_current: .res 1    ; 4-bit Volume (0-15)
ds_delay:   .res 1    ; -1 = Off, 0-15 = Active
ds_count:   .res 1    ; Bit counter (0-16)

.code

; ---------------------------------------------------------
; DS_INIT: A/X = Mask, Y = Config [R][D][D][D][D][S][S][S]
; ---------------------------------------------------------
ds_init:
    sta ds_mask
    stx ds_mask+1
    sty ds_config
    
    lda #0             ; Force immediate reload on first tick
    sta ds_count
    tya                ; Pass config to restart logic

ds_restart:
    ldx #16            ; Reset bit counter
    stx ds_count
    and #$78           ; Mask Delay bits
    lsr a              ; Align 0-15
    lsr a
    lsr a
    sta ds_delay
    rts

; ---------------------------------------------------------
; DS_TICK: 50Hz Update
; ---------------------------------------------------------
ds_tick:
    lda ds_delay
    bmi @done           ; $FF = Off
    beq @do_bit
    dec ds_delay
    rts

@do_bit:
    ; 1. Cyclic 16-bit Shift
    lda ds_mask
    asl a
    rol ds_mask+1
    php                 ; Save Bit
    adc #0              ; Loop it
    sta ds_mask
    
    ; 2. Unified Delta Math
    lda ds_config
    and #$07            ; Step
    plp                 ; Restore Bit
    bcs @calc           
    eor #$FF            ; Negate

@calc:
    adc ds_current      ; Accumulate

    ; 3. Triple-Check Clamp
    bpl @ok             
    lda #0              
@ok:
    cmp #16             
    bcc @save           
    lda #15             

@save:
    sta ds_current
    ldy #8              ; AY Ch A Vol
    jsr SETAYR

    ; 4. Logic & Flow
    dec ds_count        ; One bit done
    bne @reload_delay   ; Still in the 16-bit window?

    ; --- 16-bit Cycle Over ---
    lda ds_config       ; Check Repeat bit
    bpl @stop_seq       ; If not Repeat, kill it
    ; Fall through to reload counter/delay

@reload_delay:
    lda ds_config
    jmp ds_restart

@stop_seq:
    lda #$FF
    sta ds_delay

@done:
    rts
