;;; 1-IPA wovels by AY directly, lol
;;; (see 1-IPA.md for session)


.include "ant-cmd.asm"


;;; TODO: phonem subroutiunes, this one must be phonem1 !!!

SHORT = W250ms                  ; 250ms short wovel  "EIGHT"
LONG  = W500ms                  ; 500ms long  wovel  "QUARTER"


SHORT_SAW= CALL1

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
speech_o_long:                  ; /uuː/ (Bo)
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






; --- Consonant Types ---

STOP_POP = CALL3                ; Short burst of noise/tone for P, T, K

swe_stop_pop: 
        .byte MIXER,$c7         ; %11 000 111: Noise on C, Tone off
        .byte ENV,FADE_OUT
        .byte W31ms, RET        


FRICATIVE = CALL4               ; Pure noise hiss for S, F, SH

swe_fricative: 
        .byte MIXER,$df         ; %11 011 111: Noise on C ONLY
        .byte ENV,FADE_OUT
        .byte W125ms, RET


VOICED_CONS = CALL5             ; Voiced buzz for V, Z, L, R

swe_voiced_cons:
        .byte MIXER,$fb         ; %11 111 011: Noise on C, Tone on
        .byte ENV,LOOP_SAW
        .byte W125ms, RET


; AY-3-8910 @ 1MHz 
; Consonant Library: K, P, T, S, F, SH, B, D, G, R, L, M, N
; Logic: Sets hardware registers then calls the appropriate timing/mixer macro


speech_k:
        .byte R4,$60, R5,$00

        .byte NOISE,$05
        .byte STOP_POP
        .byte RET

speech_p:
        .byte R4,$00, R5,$01

        .byte NOISE,$1f
        .byte STOP_POP
        .byte RET

speech_t:
        .byte R4,$80, R5,$00

        .byte NOISE,$02
        .byte STOP_POP
        .byte RET

speech_s:
        .byte NOISE,$01
        .byte FRICATIVE
        .byte RET

speech_f:
        .byte NOISE,$08
        .byte FRICATIVE
        .byte RET

speech_sj_se:   
speech_sh:                         ; English 'sh' / Swedish 'sj'
        .byte NOISE,$03
        .byte FRICATIVE
        .byte RET

speech_b:
        .byte R11,$00, R12,$06
        .byte R4,$00,R5,$02

        .byte NOISE,$1f
        .byte VOICED_CONS
        .byte RET

speech_d:
        .byte R11,$00, R12,$04
        .byte R4,$80,R5,$01

        .byte NOISE,$1a
        .byte VOICED_CONS
        .byte RET

speech_g:
        .byte R11,$00, R12,$03
        .byte R4,$00,R5,$01

        .byte NOISE,$10
        .byte VOICED_CONS
        .byte RET

speech_r:
        .byte R11,$00, R12,$0a
        .byte R4,$50,R5,$01

        .byte NOISE,$00
        .byte VOICED_CONS
        .byte RET

speech_l:
        .byte R11,$00, R12,$0c
        .byte R4,$00,R5,$02

        .byte NOISE,$00
        .byte VOICED_CONS
        .byte RET

speech_m:
        .byte R11,$00, R12,$10
        .byte R4,$00,R5,$03

        .byte NOISE,$00
        .byte VOICED_CONS
        .byte RET

speech_n:
        .byte R11,$00, R12,$0e
        .byte R4,$80,R5,$02

        .byte NOISE,$00
        .byte VOICED_CONS
        .byte RET


;;; C H J Q V W X Z

; --- Extended Consonants & Clusters ---

speech_ch:                         ; German 'ch' / Dutch 'g' (Guttural)
        .byte NOISE,$0f
        .byte FRICATIVE

speech_tsch:                       ; 'ch' in 'chair' (T + SH)
        .byte R4,$80, R5,$00

        .byte NOISE,$02
        .byte STOP_POP

        .byte NOISE,$03
        .byte FRICATIVE

speech_j_se:                       ; Swedish 'j' / American 'y'
speech_y_am:
        .byte R11,$0e, R12,$00
        .byte R4,$1e,R5,$00

        .byte NOISE,$0a
        .byte SHORT_SAW

speech_j_am:                       ; American 'j' (D + SH)
        .byte R11,$00, R12,$04
        .byte R4,$80,R5,$01

        .byte NOISE,$1a
        .byte VOICED_CONS

        .byte NOISE,$03
        .byte FRICATIVE

speech_v:                          ; 'v' / 'w' (Voiced friction)
speech_w:
        .byte R11,$00, R12,$08
        .byte R4,$00, R5,$02

        .byte NOISE,$15
        .byte VOICED_CONS

speech_z:                          ; 'z' (Voiced 's')
        .byte R11,$00, R12,$04
        .byte R4,$80, R5,$01

        .byte NOISE,$01
        .byte VOICED_CONS

speech_x:                          ; 'x' (K + S)
        .byte R4,$60, R5,$00
        .byte NOISE,$05
        .byte STOP_POP

        .byte NOISE,$01
        .byte FRICATIVE

speech_h:                          ; 'h' (Breath)
        .byte NOISE,$1f
        .byte FRICATIVE         ; Maximum noise period (softest hiss)

speech_q:                          ; 'q' (K + W)
        .byte R4,$60, R5,$00
        .byte NOISE, $05
        .byte STOP_POP
        .byte R11,$00, R12,$0d
        .byte R4,$29, R5,$00

        .byte NOISE,$0e
        .byte VOICED_CONS




; --- "Go'morron Sverige" Phrase Sequence ---

;;; TODO: when compile into langauge!

SPEECH_G	=8
SPEECH_O_LONG	=8
SPEECH_M	=8
SPEECH_O_SHORT	=8
SPEECH_N	=8
SPEECH_S	=8
SPEECH_B	=8
SPEECH_E_SHORT	=8
SPEECH_R	=8
SPEECH_I_LONG	=8


phrase_gomorron_sverige:
        ;; "Go-" (G + Long O)
        .byte SPEECH_G
        .byte SPEECH_O_LONG

        ;; "-morr-" (M + Short O + R)
        .byte SPEECH_M
        .byte SPEECH_O_SHORT
        .byte SPEECH_R

        ;; "-on" (Short O + N)
        .byte SPEECH_O_SHORT
        .byte SPEECH_N

        ;; (Brief Pause between words)
        .byte R10,$00,W62ms

        ;; "Sve-" (S + V/B-type voiced fricative + Short E)
        .byte SPEECH_S
        .byte SPEECH_B ;; Using B-voiced setup for the 'V' sound
        .byte SPEECH_E_SHORT

        ;; "-ri-" (R + Long I)
        .byte SPEECH_R
        .byte SPEECH_I_LONG

        ;; "-ge" (G + Short E)
        ;; Note: In SE "Sverige", this G is often soft, like SPEECH_Y_SHORT
        .byte SPEECH_G
        .byte SPEECH_E_SHORT

        ;; End of Phrase
        .byte R10,$00
        .byte RET



phrase_guten_morgen:
        ;;"Gu-" (G + Long U)
        .byte SPEECH_G
        .byte SPEECH_U_LONG
        ;;"-ten" (T + Short E + N)
        .byte SPEECH_T
        .byte SPEECH_E_SHORT
        .byte SPEECH_N
        ;;"Mor-" (M + Short O + R)
        .byte SPEECH_M
        .byte SPEECH_O_SHORT
        .byte SPEECH_R
        ;;"-gen" (G + Short E + N)
        .byte SPEECH_G
        .byte SPEECH_E_SHORT
        .byte SPEECH_N
        .byte R10,$00,RET


phrase_goedemorgen:
        ;;"Goe-" (Guttural G + Long U/oe)
        .byte SPEECH_CH
        .byte SPEECH_U_LONG
        ;;"-de-" (D + Short E)
        .byte SPEECH_D
        .byte SPEECH_E_SHORT
        ;;"mor-" (M + Short O + R)
        .byte SPEECH_M
        .byte SPEECH_O_SHORT
        .byte SPEECH_R
        ;;"-gen" (Guttural G + Short E + N)
        .byte SPEECH_CH
        .byte SPEECH_E_SHORT
        .byte SPEECH_N
        .byte R10,$00,RET

phrase_good_morning:
        ;;"Good" (G + Short U + D)
        .byte SPEECH_G
        .byte SPEECH_U_SHORT
        .byte SPEECH_D
        ;;"Mor-" (M + Short O + R)
        .byte SPEECH_M
        .byte SPEECH_O_SHORT
        .byte SPEECH_R
        ;;"-ning" (N + Short I + G)
        .byte SPEECH_N
        .byte SPEECH_I_SHORT
        .byte SPEECH_G
        .byte R10,$00,RET


        ;;--- "Sjökapten" Sequence ---
        ;;Pronunciation: [ɧøːkapˈteːn]

phrase_sjokapten:
        ;;"Sjö-" (SJ-hiss + Long Ö)
        .byte SPEECH_SH
        .byte SPEECH_OE_LONG

        ;;"-kap-" (K + Short A + P)
        .byte SPEECH_K
        .byte SPEECH_A_SHORT
        .byte SPEECH_P

        ;;"-ten" (T + Long E + N)
        .byte SPEECH_T
        .byte SPEECH_E_LONG
        .byte SPEECH_N

        .byte R10,$00,RET ;;Silence and end




        ;;--- "Hej" Sequence ---
        ;;Pronunciation: [hɛj]

phrase_hej:
        ;;"He-" (H + Short E)
        .byte SPEECH_H
        .byte SPEECH_E_SHORT

        ;;"-j" (The 'j' glide - high/tight like a short I)
        .byte SPEECH_I_SHORT
        
        .byte R10,$00,RET

        ;;--- "Hej då" Sequence ---
        ;;Pronunciation: [hɛjˈdoː]

phrase_hej_da:
        ;;"Hej" (Reuse the logic from above)
        .byte SPEECH_H
        .byte SPEECH_E_SHORT
        .byte SPEECH_I_SHORT

        ;;(Micro pause for word separation)
        .byte R10,$00,W62ms

        ;;"-då" (D + Long Å)
        .byte SPEECH_D
        .byte SPEECH_AO_LONG

        .byte R10,$00,RET

phrase_morron:
        .byte SPEECH_M
        .byte SPEECH_O_SHORT
        .byte SPEECH_R
        .byte SPEECH_O_SHORT
        .byte SPEECH_N
        .byte NASAL_FADE           ;;Smoothly ends the 'N'
        .byte R10,$00,RET



        ;;Rolling R: Fast vibration, moderate pitch
SPEECH_R_ROLL:
        .byte R11,$0a,R12,$00           ;;Fast envelope vibration
        .byte R4,$50,R5,$01             ;;Mid-low tone
        .byte R6,$00                    ;;No noise
        .byte VOICED_CONS
        .byte RET

        ;;Skanian R: Throat friction, no tongue roll
SPEECH_R_SKANE:
        .byte R11,$15,R12,$00           ;;Slower, "heavier" envelope
        .byte R4,$80,R5,$01             ;;Lower tone
        .byte R6,$0e                    ;;Heavy throat noise (Formant 3)
        .byte VOICED_CONS
        .byte RET


        ;;Thick 'RT' (The sound in 'Märta')
SPEECH_RT_THICK:
        .byte R4,$b0,R5,$00             ;;Lowered, "thicker" T-pitch
        .byte R6,$04                    ;;Extra resonance noise
        .byte STOP_POP
