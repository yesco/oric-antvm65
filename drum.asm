;;; ================================================================
;;; COMBO COMMANDS: DRUM & SPEECH EMULATION
;;; ================================================================
;;; Y=4 : DRUM S  (Kick / Plosive 'P/B') - Tone-heavy thump
;;; Y=5 : DRUM SH (Snare / Sibilant 'SH') - Mid-noise + Tone
;;; Y=6 : DRUM CH (Closed Hat / 'CH/T')   - High-noise, fast decay
;;; Y=7 : DRUM TS (Open Hat / 'S/Z')      - High-noise, slow decay
;;; ================================================================

;;; TODO: a common init???

        pha             ; Save Variation A (The "Mouth" shape)
        
        lda #$10        ; Use Hardware Envelope
        ldy #10         ; R10 = Amplitude C
        jsr SETAY

        dey             ; Y was 4
        bmi cmdKickS
        dey             ; Y was 5
        bmi cmdSnareSH
        dey             ; Y was 6
        bmi cmdHiHatClosedCH
        ;; Fall through to 7 (cmdHiHatOpenTS)

;;; COMBO "TS" (Open Hi-Hat / Long Sibilant 'S/Z/TS')
;;; A = Sibilant Pitch (0=Sizzle, 15=Hiss)
cmdHiHatOpenTS:
        lda #$24        ; Noise C ON, Tone C OFF
        jsr setMixerC
        pla             ; Get Variation
        clc
        adc #$02        ; Base "S" noise
        ldy #6          ; R6 = Noise Period
        jsr SETAY
        ldx #$00        ; Env Fine
        lda #$25        ; Env Coarse (Long "Sssshh" fade)
        jmp trigger

;;; COMBO "CH" (Closed Hi-Hat / Hard Plosive 'CH/T/K')
;;; A = Sharpness (0=Thick 'CH', 15=Thin 'T')
cmdHiHatClosedCH:
        lda #$24        ; Noise C ON, Tone C OFF
        jsr setMixerC
        pla             ; Get Variation
        clc
        adc #$01        ; Very high noise
        ldy #6
        jsr SETAY
        ldx #$00
        lda #$03        ; Env Coarse (Extremely short "Tick")
        jmp trigger

;;; COMBO "SH" (Snare / Fricative 'SH/ZH')
;;; A = Vowel Body (Changes the "mouth" tone)
cmdSnareSH:     
        lda #$00        ; Noise C ON, Tone C ON
        jsr setMixerC
        lda #$0F        ; Mid-range "Breath" noise
        ldy #6
        jsr SETAY
        pla             ; Get Variation for Vowel Tone
        ldy #4          ; Fine Tone C
        jsr SETAY
        lda #$01        ; Coarse Tone C
        ldy #5
        jsr SETAY
        ldx #$00
        lda #$08        ; Env Coarse (Bust of noise)
        jmp trigger

;;; COMBO "S" (Kick / Deep Plosive 'B/P/D')
;;; A = Impact (0=Deep Thump, 15=Tight Pop)
cmdKickS:       
        lda #$20        ; Noise C OFF, Tone C ON
        jsr setMixerC
        pla             ; Get Variation for Impact
        clc
        adc #$05        ; Base low frequency
        ldy #5          ; Coarse Tone C
        jsr SETAY
        lda #$00        ; Fine Tone C
        ldy #4
        jsr SETAY
        ldx #$00
        lda #$0C        ; Env Coarse (Heavy thump)
        ;; fall through to trigger

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

setMixerC:
        pha
        lda mixer_cache 
        and #%11011011  ; Mask Channel C
        sta mixer_cache
        pla
        and #%00100100 
        ora mixer_cache
        sta mixer_cache
        ldy #7
        lda mixer_cache
        jsr SETAY
        rts

mixer_cache: .byte $FF
