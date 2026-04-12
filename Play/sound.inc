;/*
;; -----------------------------------
;;            Oricium
;;         Fast Scroll game
;; -----------------------------------
;;			(c) Chema 2013
;;         enguita@gmail.com
;; -----------------------------------
;*/

;/* Sound effects header file */

;/* Main definitions for sound routines */

ayc_Register = $FF
ayc_Write    = $FD
ayc_Inactive = $DD


AY_AToneLSB= 		0
AY_AToneMSB= 		1
AY_BToneLSB= 		2
AY_BToneMSB= 		3
AY_CToneLSB= 		4
AY_CToneMSB= 		5
AY_Noise= 		6
AY_Status= 		7
AY_AAmplitude= 	8
AY_BAmplitude= 	9
AY_CAmplitude= 	10
AY_EnvelopeLSB= 	11
AY_EnvelopeMSB= 	12
AY_EnvelopeCy= 	13
AY_IOPort= 		14



;/* Commands available in a pattern list (channel in a song) */
;END=  	%10000000
ENV=  	%10000001
ORN=  	%10000010
NON=  	%10000011
NOFF= 	%10000100
TON= 		%10000101
TOFF= 	%10000110
NVAL= 	%10000111
NOFFSET=  %10001000
LOOP= 	%10001001
SETVOL=  	%10001010
WAITFLG=  %10001011

;/* Commands available inside a pattern */

END=  	%10000000
RST=  	%10010000
SIL=  	%10100000
PNON=  	%10110000
PNOFF= 	%11000000
PTON= 	%11010000
PTOFF= 	%11100000

;/* Notes */
C_= 	0
CS_= 	1
D_= 	2
DS_= 	3
E_= 	4
F_= 	5
FS_= 	6
G_= 	7
GS_= 	8
A_= 	9
AS_= 	10
B_= 	11

;/* ADSHR hold index */
HOLD_TEMPO=  3