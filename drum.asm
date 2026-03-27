        ;; -- at this point we're entering DRUM sounds
        ;; (A is an optional parameter / Variation)
        ;; (dispatch on Y=4..7)

        pha             ; Save Variation A
        
        ;; Set Channel C to Hardware Envelope Mode
        lda #$10        ; Value 16 = Use Envelope
        ldy #10         ; R10 = Amplitude C
        jsr SETAY

        dey             ; Y was 4
        bmi cmdKickS
        dey             ; Y was 5
        bmi cmdSnareSH
        dey             ; Y was 6
        bmi cmdHiHatClosedCH
        ;; Fall through to 7 (cmdHiHatOpenTS)

;;; 4. Open Hi-hat ("ts" - Sizzle)
cmdHiHatOpenTS:
        lda #$24        ; Mixer: Noise C ON, Tone C OFF
        jsr setMixerC
        lda #$00
        sta drum_slide_val ; No slide for hats
        pla             ; Get Variation
        clc
        adc #$02        ; Base Noise
        ldy #6
        jsr SETAY
        ldx #$00        ; Env Period Low
        lda #$15        ; Env Period High
        jmp trigger

;;; 3. Closed Hi-hat ("ch" - Tick)
cmdHiHatClosedCH:
        lda #$24        ; Mixer: Noise C ON, Tone C OFF
        jsr setMixerC
        lda #$00
        sta drum_slide_val
        pla             ; Get Variation
        clc
        adc #$01
        ldy #6
        jsr SETAY
        ldx #$00
        lda #$02        ; Env Period High
        jmp trigger

;;; 2. Snare Drum ("sh" - Snap)
cmdSnareSH:     
        lda #$00        ; Mixer: Noise C ON, Tone C ON
        jsr setMixerC
        lda #$10
        sta drum_slide_val ; Set a snappy downward slide speed
        lda #$0F        ; Mid-range crunch
        ldy #6
        jsr SETAY
        pla             ; Variation
        ldy #4          ; Fine Tone C
        jsr SETAY
        lda #$01        ; Coarse Tone C
        ldy #5
        jsr SETAY
        ldx #$00
        lda #$08
        jmp trigger

;;; 1. Kick Drum ("s" - Thump)
cmdKickS:       
        lda #$20        ; Mixer: Noise C OFF, Tone C ON
        jsr setMixerC
        lda #$20
        sta drum_slide_val ; Heavy slide for "booom"
        pla             ; Variation
        clc
        adc #$05
        ldy #5          ; Coarse Tone C
        jsr SETAY
        lda #$00        ; Fine Tone C
        ldy #4
        jsr SETAY
        ldx #$00
        lda #$0A
        ;; fall through to trigger

;;; --- COMMON TRIGGER ---
trigger:
        ldy #12         ; R12 = Env Period Coarse
        jsr SETAY
        txa
        ldy #11         ; R11 = Env Period Fine
        jsr SETAY
        lda #$09        ; Shape: Single Decay (\)
        ldy #13         ; R13 starts the one-shot
        jsr SETAY
        rts

;;; --- MIXER SUBROUTINE ---
setMixerC:
        pha
        lda mixer_cache 
        and #%11011011  ; Clear Channel C bits
        sta mixer_cache
        pla
        and #%00100100  ; Keep only relevant bits
        ora mixer_cache
        sta mixer_cache
        ldy #7
        lda mixer_cache
        jsr SETAY
        rts

mixer_cache:    .byte $FF
drum_slide_val: .byte $00 ; Global for the Interrupt to read
