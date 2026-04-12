;;; Command to binary/number mapping "authorative"
;;; (as described in README.md)

STOP= %11000000

WAIT= %11000000
WAIT0= WAIT+0
WAIT1= WAIT+1
WAIT2= WAIT+2
WAIT3= WAIT+3
WAIT4= WAIT+4
WAIT5= WAIT+5
WAIT6= WAIT+6
WAIT7= WAIT+7



SUSTAIN= %11001000
VALUE =  %11001000
VALUE1=  VALUE+1
VALUE2=  VALUE+2
VALUE3=  VALUE+3
VALUE4=  VALUE+4
VALUE5=  VALUE+5
VALUE6=  VALUE+6
LEGATO=  %11001111



CALL1= %11010000+0
CALL2= %11010000+1
CALL3= %11010000+2
CALL4= %11010000+3
CALL5= %11010000+4
CALL6= %11010000+5
CALL7= %11010000+6



SELECT_A= %11011000
SELECT_B= %11011001
SELECT_C= %11011010
SELECT_N= %11011011


EXTENDED= %11011100
YIELD=    %11011101
QUIET=    %11011110
KILL=     %11011111




;;; command w argument(s)


;;; SETAYR+rrrr

SETAYR=  %11100000
AYPDATE= %11101110
DUMPAY=  %11101111


CALL_LOCAL= %1110000
CALL_LANG1= %1110001
CALL_LANG2= %1110010
CALL_LANG3= %1110011
CALL_LANG4= %1110100
CALL_LANG5= %1110101
CALL_LANG6= %1110110
CALL_LANG7= %1110111


IPA=     CALL_LANG1
GENERIC= CALL_LANG1

SPEAK=   CALL_LANG2


DRUM_KICK=   %11111000
DRUM_SNARE=  %11111001
DRUM_HH_CLS= %11111010
DRUM_HH_OPN= %11111011


EXTENDED_PAR= %11111100

PARAM_BYTE=   %11111101

PARAM_WORD=   %11111110

RET=          %11111111


;;; OCT4 is normal, OCT3 higher frequency

oct0= 0
oct1= 1
oct2= 2
oct3= 3
oct4= 4
oct5= 5                        
oct6= 6
oct7= 7


;;; 12-TET Notes by "name" (common-notation)

_C   = 8* 0                 
_Cs  = 8* 2   ; C#
_D   = 8* 4
_Ds  = 8* 6   ; D#
_E   = 8* 8
_F   = 8* 10
_Fs  = 8* 12  ; F#
_G   = 8* 14
_Gs  = 8* 16  ; G#
_A   = 8* 18
_As  = 8* 20  ; A#
_B   = 8* 22


;;; 24-TET Notes by "name" (common-notation)

;_C   = 8* 0
_Cqs = 8* 1   ; C half-sharp
;_Cs  = 8* 2   ; C#
_Cts = 8* 3   ; C three-quarters-sharp
;_D   = 8* 4
_Dqs = 8* 5   ; D half-sharp
;_Ds  = 8* 6   ; D#
_Dts = 8* 7   ; D three-quarters-sharp
;_E   = 8* 8
_Eqs = 8* 9   ; E half-sharp
;_F   = 8* 10
_Fqs = 8* 11  ; F half-sharp
;_Fs  = 8* 12  ; F#
_Fts = 8* 13  ; F three-quarters-sharp
;_G   = 8* 14
_Gqs = 8* 15  ; G half-sharp
;_Gs  = 8* 16  ; G#
_Gts = 8* 17  ; G three-quarters-sharp
;_A   = 8* 18
_Aqs = 8* 19  ; A half-sharp
;_As  = 8* 20  ; A#
_Ats = 8* 21  ; A three-quarters-sharp
;_B   = 8* 22
_Bqs = 8* 23  ; B half-sharp


;;; Naturals and Flats (adding to your existing list)

;_C   = 8* 0
_Db  = 8* 2   ; D-flat (Same as C-sharp)
_Dqb = 8* 3   ; D-half-flat (Between C# and D)
;_D   = 8* 4
_Eb  = 8* 6   ; E-flat (Same as D-sharp)
_Eqb = 8* 7   ; E-half-flat (Between D# and E)
;_E   = 8* 8
;_F   = 8* 10
_Gb  = 8* 12  ; G-flat (Same as F-sharp)
_Gqb = 8* 13  ; G-half-flat (Between F# and G)
;_G   = 8* 14
_Ab  = 8* 16  ; A-flat (Same as G-sharp)
_Aqb = 8* 17  ; A-half-flat (Between G# and A)
;_A   = 8* 18
_Bb  = 8* 20  ; B-flat (Same as A-sharp)
_Bqb = 8* 21  ; B-half-flat (Between A# and B)
;_B   = 8* 22
_Cb  = 8* 22  ; C-flat (Same as B)


;;; 24-TET Notes: German/Contemporary Flute Style
;;; s = 8* sharp, m = 8* minus (1/4 flat), p = 8* plus (1/4 sharp)

;_C  = 8* 0
_Cp = 8* 1   ; C-plus (1/4 sharp)
;_Cs = 8* 2   ; Cis (C-sharp)
_Dm = 8* 3   ; D-minus (1/4 flat) -- often written _Dm
;_D  = 8* 4
_Dp = 8* 5   ; D-plus (1/4 sharp)
;_Ds = 8* 6   ; Dis (D-sharp)
_Em = 8* 7   ; E-minus (1/4 flat) -- often written _Em
;_E  = 8* 8
_Fm = 8* 9   ; F-minus (1/4 flat) OR E-plus
;_F  = 8* 10
_Fp = 8* 11  ; F-plus (1/4 sharp)
;_Fs = 8* 12  ; Fis (F-sharp)
_Gm = 8* 13  ; G-minus (1/4 flat)
;_G  = 8* 14
_Gp = 8* 15  ; G-plus (1/4 sharp)
;_Gs = 8* 16  ; Gis (G-sharp)
_Am = 8* 17  ; A-minus (1/4 flat)
;_A  = 8* 18
_Ap = 8* 19  ; A-plus (1/4 sharp)
;_As = 8* 20  ; Ais (A-sharp)
_Bm = 8* 21  ; B-minus (1/4 flat)
;_B  = 8* 22
_Cm = 8* 23  ; C-minus (1/4 flat) OR B-plus
