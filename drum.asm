;;; ================================================================
;;; COMBO COMMANDS: DRUM & SPEECH EMULATION
;;; ================================================================
;;; Y=4 : DRUM S  (Kick / Plosive 'P/B') - Tone-heavy thump
;;; Y=5 : DRUM SH (Snare / Sibilant 'SH') - Mid-noise + Tone
;;; Y=6 : DRUM CH (Closed Hat / 'CH/T')   - High-noise, fast decay
;;; Y=7 : DRUM TS (Open Hat / 'S/Z')      - High-noise, slow decay
;;; ================================================================

;;; 163 B - as AI gen
;;;  97 B - JSK: opt! (ayshadow + structure change)

DRUMSTART:

;;; COMBO "TS" (Open Hi-Hat / Long Sibilant 'S/Z/TS')
;;; A = Sibilant Pitch (0=Sizzle, 15=Hiss)
cmdHiHatOpenTS:
        clc
        adc #$02        ; Base "S" noise
        sta ayshadow+6  ; R6 = Noise Period

        ldy #$24        ; Noise C ON, Tone C OFF
        ldx #$25        ; Env Coarse (Long "Sssshh" fade)
        jmp trigger

;;; COMBO "CH" (Closed Hi-Hat / Hard Plosive 'CH/T/K')
;;; A = Sharpness (0=Thick 'CH', 15=Thin 'T')
cmdHiHatClosedCH:
        clc
        adc #$01        ; Very high noise
        sta ayshadow+6

        ldy #$24        ; Noise C ON, Tone C OFF
        ldx #$03        ; Env Coarse (Extremely short "Tick")
        jmp trigger

;;; COMBO "SH" (Snare / Fricative 'SH/ZH')
;;; A = Vowel Body (Changes the "mouth" tone)
cmdSnareSH:     
        sta ayshadow+4  ; Fine Tone C

        lda #$01        ; Coarse Tone C
        sta ayshadow+5

        lda #$0F        ; Mid-range "Breath" noise
        sta ayshadow+6

        ldy #$00        ; Noise C ON, Tone C ON
        ldx #$08        ; Env Coarse (Bust of noise)
        jmp trigger

;;; COMBO "S" (Kick / Deep Plosive 'B/P/D')
;;; A = Impact (0=Deep Thump, 15=Tight Pop)
cmdKickS:       
        clc
        adc #$05        ; Base low frequency
        sta ayshadow+5  ; Coarse Tone C

        lda #$00        ; Fine Tone C
        sta ayshadow+4

        ldy #$20        ; Noise C OFF, Tone C ON
        ldx #$0C        ; Env Coarse (Heavy thump)
        ;; fall through to trigger


;;; X= env coarse
;;; Y= mixer new bits C N or:ed in
trigger:

        ;; Update MIXER C+N bits

;;; TODO: is this correct, not inverted?

        lda #%11011011

        and ayshadow+7
        sta ayshadow+7

        ;; maybe add C+/N
        tya
        ora ayshadow+7
        sta ayshadow+7


        ;; Update common (R11=0, R12=X, R13=9, R10=10)

        stx ayshadow+12 ; R12 = Env Period Coarse

        ldx #0
        stx ayshadow+11 ; R11 = Env Period Fine

        ldx #$09        ; Shape: Single Decay (\)
        stx ayshadow+13 ; R13 starts the one-shot

        ldx #$10        ; Use Hardware Envelope
        stx ayshadow+10 ; R10 = Amplitude C

        ;; "jsr"
        jmp interpret

DRUMEND:        
