.zeropage

channels:       .res 1
ticks:          .res 2

;;; IP for interpration
;;; TODO: ABCN
language:       .res 2
stream:         .res 2
ipy:            .res 1

antlang:        .res 1
antsp:          .res 1          ; next offset where to push

;;; maybe have a number of interrupt tmp!
;;; TODO: replace with savea, savex, savey
antvm_tmp:      .res 1

ay_reg: 
antvm_tmp2:     .res 1

ay_coarse:      
antvm_tmp3:     .res 1


.data


;;; TODO: "dish" out different offsets/task
antstack:       .res 3*8*4      ; 3B * 8 levels * 4 ch

detune:         .word 0

;;; AY register shadow in RAM to be manipulated
ayshadow:       .res 14

.code





.data

;;; AntVM parameter state in RAM
antvmBLOCK:     

;;; A,B,C,N, E.F.K.T == (Echo,Follow,Korus,Tglissado)
processmap:     .byte 0



antvmBLOCKEnd:     

;;; VALUE is length of note in ticks
;;; 0 == no YIELD (sustain/legato) do manual WAIT for length
;;; (whole@120BPM =4  beats = 2.0s = 100 50Hz ticks
WHOLETICKS=100
VOLUME=10

values: 
        
valueA:         .byte WHOLETICKS*3/4
valueB:         .byte WHOLETICKS*3/4
valueC:         .byte WHOLETICKS*3/4
valueN:         .byte WHOLETICKS*3/4


rests:  

restA:          .byte WHOLETICKS/4
restB:          .byte WHOLETICKS/4
restC:          .byte WHOLETICKS/4
restN:          .byte WHOLETICKS/4


restRatios:     

restRatioA:     .byte 2
restRatioB:     .byte 2
restRatioC:     .byte 2
restRatioN:     .byte 2


;;; Zeropage: AntVM state data
.zeropage

;;; copy of processmap and shifted
tickermap:      .res 1

;;; Current channel number 0-7:ABCD EFCT
tickX:          .res 1


delays: 

delayA:         .res 1
delayB:         .res 1
delayC:         .res 1
delayN:         .res 1

delayE:         .res 1
delayF:         .res 1
delayK:         .res 1
delayT:         .res 1

.code

.zeropage
; --- Deltas (ds) Pitch State ---
ds_p_mask:    .res 2    ; 16-bit pattern (Circular)
ds_p_config:  .res 1    ; [7:OneShot][3-6:Delay][0-2:StepIndex]
ds_p_current: .res 2    ; 16-bit Current Period (Reg 0/1)
ds_p_step:    .res 2    ; 16-bit Calculated Step (P >> (8-S))
ds_p_delay:   .res 1    ; Negative = Off, 0-15 = Active
ds_p_count:   .res 1    ; Bit counter (16 down to 1)

.code

.zeropage

; --- Deltas (ds) Volume State ---
ds_v_mask:    .res 2    ; 16-bit pattern (Circular)
ds_v_config:  .res 1    ; [7:OneShot][3-6:Delay][0-2:Step S]
ds_v_current: .res 1    ; 4-bit Volume (0-15)
ds_v_delay:   .res 1    ; Negative = Off, 0-15 = Active
ds_v_count:   .res 1    ; Bit counter (16 down to 1)

.code
