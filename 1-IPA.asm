;;; 1-IPA wovels by AY directly, lol

;;; |Wov| F1 (EP)| F2(Tone)|F3(Noise)| R11/12| R4/5  | R6 | Vibe/Language | 
;;; |---|--------|---------|---------|-------|-------|----|-----------------|
;;; | A | 730 Hz | 1090 Hz | 2440 Hz | 05 00 | 39 00 | 0D | SE, JP (あ), ES |
;;; | O | 570 Hz |  840 Hz | 2410 Hz | 07 00 | 4A 00 | 0D | SE, JP (お), FR |
;;; | U | 440 Hz | 1020 Hz | 2240 Hz | 09 00 | 3D 00 | 0E | SE (short), JP (う) |
;;; | Å | 600 Hz |  900 Hz | 2500 Hz | 06 00 | 45 00 | 0C | SE (long O) |
;;; | E | 530 Hz | 1840 Hz | 2480 Hz | 07 00 | 22 00 | 0D | SE, JP (え), DE |
;;; | I | 270 Hz | 2290 Hz | 3010 Hz | 0E 00 | 1B 00 | 0A | SE, JP (い), IT |
;;; | Y | 260 Hz | 1500 Hz | 2620 Hz | 0F 00 | 29 00 | 0C | SE, FI (y), FR (u) |
;;; | Ä | 700 Hz | 1700 Hz | 2450 Hz | 06 00 | 25 00 | 0D | SE, DE (ä), FI |
;;; | Ö | 500 Hz | 1300 Hz | 2300 Hz | 08 00 | 30 00 | 0E | SE, DE (ö), FR (eu) |

; Format: Register, Value... WAIT, RET
; F1 -> R11/R12 | F2 -> R4/R5 | F3 -> NOISE (R6)

;;; a o u aa e i y ae ao

;a o u aa e i y ae ao

; AY-3-8910 @ 1MHz 
; F1 (Env) -> R11/R12 | F2 (Tone) -> R4/R5 | F3 -> NOISE (R6)


;;; Which one for your Speech?

;;; Use ENV,LOOP_SAW ($08):
;;;   For aggressive, clear Swedish vowels like ä and ö.

;;; Use ENV,LOOP_TRI ($0a):
;;;   For softer, rounded vowels like o and u.

;;; Wait! Be aware that writing to Register 13
;;;       is the only way to reset the envelope phase.
;;; 
;;;       If you change a vowel but don't re-write R13,
;;;       the "mouth" might be in the middle of a silent part
;;;       of the wave when the new note


;;; TODO: phonem subroutiunes, this one must be phonem1 !!!

SHORT = W250ms                  ; 250ms short wovel  "EIGHT"
LONG  = W500ms                  ; 500ms long  wovel  "QUARTER"


SHOFT_SAW= CALL1

swe_short_saw: 
        .byte MIXER,$fb, ENV,LOOP_SAW, SHORT, RET


LONG_SAW= CALL2

swe_long_saw: 
        .byte MIXER, $fb, ENV,LOOP_SAW, LONG, RET


; --- A Group ---
speech_a_short:                 ; /a/ (Hatt)
        .byte R11,$05, R12,$00
        .byte R4,$39, R5,$00
        .byte NOISE,$0d
        .byte SHORT_SAW
speech_a_long:                  ; /ɑː/ (Hata)
        .byte R11,$05, R12,$00
        .byte R4,$34, R5,$00
        .byte NOISE,$0c
        .byte LONG_SAW


; --- O Group --- ROUNDED
speech_o_short:                ; /ʊ/ (Bott)
        .byte R11,$08, R12,$00
        .byte R4,$4f, R5,$00
        .byte NOISE,$0e
        .byte MIXER, $fb, ENV,LOOP_TRI, SHORT, RET
speech_o_long:                  ; /uː/ (Bo)
        .byte R11,$07, R12,$00
        .byte R4,$4a, R5,$00
        .byte NOISE,$0d
        .byte MIXER, $fb, ENV,LOOP_TRI, LONG, RET

; --- U Group --- ROUNDED
speech_u_short:                 ; /ɵ/ (Hund)
        .byte R11,$09, R12,$00
        .byte R4,$3d, R5,$00
        .byte NOISE,$0e
        .byte MIXER, $fb, ENV,LOOP_TRI, SHORT, RET
speech_u_long:                  ; /ʉː/ (Hus)
        .byte R11,$0d, R12,$00
        .byte R4,$29, R5,$00
        .byte NOISE,$0e
        .byte MIXER, $fb, ENV,LOOP_TRI, LONG, RET


; --- UE / Y Group ---
speech_ue_short:                ; /ʏ/ (German ü / Sytt)
        .byte R11,$0f, R12,$00
        .byte R4,$2b, R5,$00
        .byte NOISE,$0c
        .byte SHORT_SAW
speech_ue_long:                 ; /yː/ (German ü / Syla)
        .byte R11,$11, R12,$00
        .byte R4,$29, R5,$00
        .byte NOISE,$0b
        .byte LONG_SAW

; --- E Group ---
speech_e_short:                 ; /ɛ/ (Hetta)
        .byte R11,$08, R12,$00
        .byte R4,$25, R5,$00
        .byte NOISE,$0d
        .byte SHORT_SAW
speech_e_long:                  ; /eː/ (He)
        .byte R11,$0b, R12,$00
        .byte R4,$1e, R5,$00
        .byte NOISE,$0b
        .byte LONG_SAW

; --- I Group ---
speech_i_short:                 ; /ɪ/ (Sill)
        .byte R11,$0e, R12,$00
        .byte R4,$1e, R5,$00
        .byte NOISE,$0a
        .byte SHORT_SAW
speech_i_long:                  ; /iː/ (Sil)
        .byte R11,$10, R12,$00
        .byte R4,$1b, R5,$00
        .byte NOISE,$09
        .byte LONG_SAW

; --- AE (Ä) Group ---
speech_ae_short:                ; /ɛ/ (Märta)
        .byte R11,$07, R12,$00
        .byte R4,$28, R5,$00
        .byte NOISE,$0d
        .byte SHORT_SAW
speech_ae_long:                 ; /æː/ (Här)
        .byte R11,$06, R12,$00
        .byte R4,$24, R5,$00
        .byte NOISE,$0d
        .byte LONG_SAW

; --- AO (Å) Group ---
speech_ao_short:                ; /ɔ/ (Lång)
        .byte R11,$07, R12,$00
        .byte R4,$48, R5,$00
        .byte NOISE,$0c
        .byte SHORT_SAW
speech_ao_long:                 ; /oː/ (Mål)
        .byte R11,$06, R12,$00
        .byte R4,$45, R5,$00
        .byte NOISE,$0c
        .byte LONG_SAW

; --- OE (Ö) Group ---
speech_oe_short:                ; /œ/ (Nött)
        .byte R11,$09, R12,$00
        .byte R4,$30, R5,$00
        .byte NOISE,$0e
        .byte SHORT_SAW
speech_oe_long:                 ; /øː/ (Nö)
        .byte R11,$0a, R12,$00
        .byte R4,$2d, R5,$00
        .byte NOISE,$0e
        .byte LONG_SAW
