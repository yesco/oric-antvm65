;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Needed functions
; A real random generator... 
;randseed .word $dead 	; will it be $dead again? 
randgen 
.(
   lda randseed     	; get old lsb of seed. 
   ora $308		; lsb of VIA T2L-L/T2C-L. 
   rol			; this is even, but the carry fixes this. 
   adc $304		; lsb of VIA TK-L/T1C-L.  This is taken mod 256. 
   sta randseed     	; random enough yet. 
   sbc randseed+1   	; minus the hsb of seed... 
   rol			; same comment than before.  Carry is fairly random. 
   sta randseed+1   	; we are set. 
   rts			; see you later alligator. 
.)


