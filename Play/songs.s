#include "sound.h"

sfx_priority
sfx_listlo
sfx_listhi

trance_tab
	.byt 0,0,3,$fd,3,$fd,3,$fd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; TEST

; Instrument definition
/*
Envelope_table
	.byt 13,13,13,14,14,15,13,0
	.byt 12,13,14,15,15,10,6,0 
	.byt 15,15,15,15,10,8,6,0
	.byt 12,12,12,13,15,15,14,0
; drums
	.byt 0,0,0,8,12,15,15,15
	.byt 0,15,15,15,15,15,15,0
	.byt 15,15,15,15,15,15,15,15
*/	

Envelope_table
	.byt 6,10,12,13,10,11,8,6
	.byt 13,13,13,13,10,11,8,6
	.byt 8,10,12,13,14,12,10,8
	.byt 10,10,12,13,15,15,14,10
; drums
	.byt 0,2,6,7,8,10,12,15
	.byt 9,10,11,13,12,14,15,12
	.byt 0,2,6,10,12,15,12,10



Ornament_table
	.byt 0,0,0,0,0,0,0,0
	.byt 0,$ff-1,0,1+1,0,$ff-1,0,1+1
	.byt 0,$fd-2,0,3+2,0,$fd-2,0,3+2
	.byt $70,$60,$50,$40,$30,$20,$10,0
	.byt 0,$ff,0,1,0,$ff,0,1



_PlayOW
.(
	lda #<__OrdinaryWorld_start
	sta tmp
	lda #>__OrdinaryWorld_start
	sta tmp+1
	jmp _PlaySong
.)


	

__OrdinaryWorld_start
; Header: Tempo, pointers to pattern lists
.byt 9
.byt <owpattern_list_lo,>owpattern_list_lo,<owpattern_list_hi,>owpattern_list_hi
.byt <_Tune1A, >_Tune1A, <_Tune1B, >_Tune1B, <_Tune1C, >_Tune1C



_Tune1A .byt ORN, 2, ENV, 3, 12, ENV, 0,         14,7,  14,7,  14,7,  14,8,  14,9, 10,10, 12  ,END
_Tune1B	.byt ORN, 0, ENV, 3, 11, ENV, 1,         13,0,1,13,2,3,13,0,1,13,2,4,13,5,  6, 6      ,END
_Tune1C	.byt NOFFSET, 12, ORN, 0, ENV, 3, 11, ENV, 2, ORN, 1, 13,0,1,13,2,3,13,0,1,13,2,4,13,5,  6, 6,ORN, 0, ENV, 3,11  ,END



owpattern_list_lo .byt <_ow_p0,<_ow_p1,<_ow_p2,<_ow_p3,<_ow_p4,<_ow_p5,<_ow_pa0,<_ow_2_p0,<_ow_2_p1,<_ow_2_p2,<_ow_2_pa0, <_ow_i, <_ow_i_2, <_ow_s0,<_ow_2_s0
owpattern_list_hi .byt >_ow_p0,>_ow_p1,>_ow_p2,>_ow_p3,>_ow_p4,>_ow_p5,>_ow_pa0,>_ow_2_p0,>_ow_2_p1,>_ow_2_p2,>_ow_2_pa0, >_ow_i, >_ow_i_2, >_ow_s0,>_ow_2_s0

#define OCT 4

_ow_s0
    .byt (OCT-1)*12+GS_,RST, OCT*12+CS_,RST, OCT*12+DS_,RST, OCT*12+CS_,OCT*12+DS_, OCT*12+DS_,RST,END

_ow_p0
	;.byt (OCT-1)*12+GS_,RST, OCT*12+CS_,RST, OCT*12+DS_,RST, OCT*12+CS_,OCT*12+DS_, OCT*12+DS_,RST, OCT*12+CS_,RST, OCT*12+DS_,RST, OCT*12+CS_,RST
    .byt OCT*12+CS_,RST, OCT*12+DS_,RST, OCT*12+CS_,RST
	.byt END

_ow_p1
	.byt OCT*12+DS_,RST, OCT*12+CS_,RST, OCT*12+CS_,OCT*12+DS_, (OCT-1)*12+GS_,RST, (OCT-1)*12+GS_,RST+2, SIL, RST+3
	.byt END

_ow_p2
	;.byt (OCT-1)*12+GS_,RST, OCT*12+CS_,RST, OCT*12+DS_,RST, OCT*12+CS_,OCT*12+DS_, OCT*12+DS_,RST, OCT*12+E_,OCT*12+DS_, OCT*12+DS_,RST, OCT*12+CS_,RST
	.byt OCT*12+E_,OCT*12+DS_, OCT*12+DS_,RST, OCT*12+CS_,RST
    .byt END

_ow_p3
	.byt SIL, RST+9, (OCT-1)*12+B_,RST+2, (OCT-1)*12+AS_,RST
	.byt END

_ow_p4
	.byt OCT*12+CS_,(OCT-1)*12+B_, (OCT-1)*12+B_,RST+2,(OCT-1)*12+B_,RST, SIL, RST+7
	.byt END

_ow_p5
	;.byt (OCT-1)*12+GS_,RST, OCT*12+CS_,RST, OCT*12+DS_,RST, OCT*12+CS_,OCT*12+DS_, OCT*12+DS_,RST, OCT*12+CS_,RST, OCT*12+DS_,RST+2
    .byt OCT*12+CS_,RST, OCT*12+DS_,RST+2
	.byt (OCT-1)*12+GS_,RST, OCT*12+CS_,RST, OCT*12+DS_,OCT*12+CS_, OCT*12+DS_,RST+4, SIL, RST+3
	.byt OCT*12+CS_,RST,OCT*12+CS_,RST,OCT*12+CS_,RST,OCT*12+CS_,RST, (OCT-1)*12+B_,RST, OCT*12+DS_,RST, OCT*12+CS_,OCT*12+DS_, (OCT-1)*12+B_,RST
	;.byt (OCT-1)*12+B_,RST+2,(OCT-1)*12+B_,RST,SIL,RST+9
    .byt (OCT-1)*12+B_,RST+4,SIL,RST+9
	.byt END


_ow_pa0
	.byt SIL, RST+1, (OCT-1)*12+B_,OCT*12+DS_,OCT*12+FS_,RST+2, OCT*12+FS_,RST,OCT*12+FS_,OCT*12+E_,OCT*12+E_,RST,OCT*12+DS_,OCT*12+CS_
	.byt OCT*12+CS_,RST+2,OCT*12+CS_,RST,(OCT-1)*12+B_,OCT*12+CS_,OCT*12+CS_,RST,(OCT-1)*12+B_,OCT*12+CS_,OCT*12+CS_,RST+1,OCT*12+E_
	.byt OCT*12+E_,RST+2,OCT*12+CS_,OCT*12+E_,RST+1, OCT*12+E_,RST+2, OCT*12+E_,RST,OCT*12+FS_,OCT*12+FS_
	.byt OCT*12+FS_,RST+10,SIL,RST+3
	.byt END


_ow_i
	.byt SIL
	.byt OCT*12+E_,OCT*12+E_,OCT*12+E_,OCT*12+E_
	.byt OCT*12+E_,OCT*12+DS_,OCT*12+DS_,OCT*12+DS_,OCT*12+DS_, OCT*12+CS_,OCT*12+CS_,OCT*12+CS_,OCT*12+CS_,(OCT-1)*12+B_,(OCT-1)*12+B_,(OCT-1)*12+B_,(OCT-1)*12+B_,RST,OCT*12+FS_,OCT*12+FS_,OCT*12+FS_
	.byt OCT*12+FS_,OCT*12+E_,OCT*12+E_,OCT*12+E_,OCT*12+E_,OCT*12+DS_,OCT*12+DS_,OCT*12+DS_,OCT*12+DS_,OCT*12+CS_,OCT*12+CS_,RST,OCT*12+CS_,(OCT-1)*12+B_,RST+1
	.byt (OCT-1)*12+B_,RST,(OCT-1)*12+E_,(OCT-1)*12+B_,(OCT-1)*12+B_,(OCT-1)*12+E_,(OCT-1)*12+B_,RST,(OCT-1)*12+B_,RST+6
	.byt (OCT-1)*12+A_,RST,(OCT-1)*12+E_,(OCT-1)*12+A_,(OCT-1)*12+A_,(OCT-1)*12+E_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,RST+2,(OCT-1)*12+E_,RST+2
	.byt END

#define OCT 2
_ow_i_2
	.byt SIL
	.byt RST+3
	.byt RST+15,RST+15,RST+15,RST+15,RST
/*
	.byt OCT*12+GS_,RST+2
	.byt OCT*12+B_,RST+4,OCT*12+B_,OCT*12+GS_,OCT*12+B_,OCT*12+B_,OCT*12+B_,RST+2,OCT*12+B_,RST
	.byt OCT*12+GS_,RST+4,OCT*12+GS_,OCT*12+GS_,OCT*12+GS_,RST,OCT*12+GS_,RST,OCT*12+GS_,OCT*12+GS_,(OCT+1)*12+CS_,OCT*12+GS_

	.byt OCT*12+D_,RST+4,OCT*12+DS_,OCT*12+DS_,OCT*12+CS_,RST,OCT*12+CS_,RST+2,OCT*12+CS_,RST
	.byt OCT*12+C_,RST+4,OCT*12+CS_,OCT*12+CS_,OCT*12+A_,OCT*12+G_,RST+1,OCT*12+GS_,RST,OCT*12+CS_,RST
*/
	.byt END


#define OCT 2
_ow_2_s0
	.byt OCT*12+CS_,RST+4,OCT*12+CS_,OCT*12+CS_,OCT*12+CS_,RST,OCT*12+CS_,RST+2,OCT*12+CS_,RST
    .byt END
_ow_2_p0
	;.byt OCT*12+CS_,RST+4,OCT*12+CS_,OCT*12+CS_,OCT*12+CS_,RST,OCT*12+CS_,RST+2,OCT*12+CS_,RST
	.byt OCT*12+E_,RST+4,OCT*12+E_,OCT*12+E_,OCT*12+FS_,RST,OCT*12+FS_,RST+2,OCT*12+CS_,RST
	.byt END

_ow_2_p1
	;.byt OCT*12+CS_,RST+4,OCT*12+CS_,OCT*12+CS_,OCT*12+CS_,RST,OCT*12+CS_,RST+2,OCT*12+CS_,RST
	.byt OCT*12+E_,RST, (OCT+1)*12+CS_,RST, OCT*12+B_,RST+2, OCT*12+FS_,OCT*12+FS_,OCT*12+FS_,OCT*12+FS_, OCT*12+E_,RST, OCT*12+CS_,RST
	.byt END

_ow_2_p2
	;.byt OCT*12+CS_,RST+4,OCT*12+CS_,OCT*12+CS_,OCT*12+CS_,RST,OCT*12+CS_,RST+2,OCT*12+CS_,RST
	.byt OCT*12+GS_,RST+4,OCT*12+GS_,OCT*12+GS_,OCT*12+GS_,RST,OCT*12+GS_,RST+2,OCT*12+GS_,RST
	.byt OCT*12+DS_,RST+4,OCT*12+DS_,OCT*12+DS_,OCT*12+DS_,RST,OCT*12+DS_,RST+2,OCT*12+DS_,OCT*12+E_
	.byt END

#define OCT 2
_ow_2_pa0
	.byt SIL
	.byt OCT*12+B_,RST+4,OCT*12+B_,OCT*12+B_,OCT*12+B_,RST,OCT*12+B_,RST+2,OCT*12+B_,RST
	.byt OCT*12+FS_,RST+4,OCT*12+FS_,OCT*12+FS_,OCT*12+FS_,RST,OCT*12+FS_,RST+2,OCT*12+FS_,RST
	.byt (OCT+1)*12+CS_,RST+4,(OCT+1)*12+CS_,(OCT+1)*12+CS_,(OCT+1)*12+CS_,RST,(OCT+1)*12+CS_,RST+2,(OCT+1)*12+CS_,RST	
	.byt (OCT+1)*12+E_,RST+4,(OCT+1)*12+E_,(OCT+1)*12+E_,(OCT+1)*12+E_,RST,(OCT+1)*12+E_,RST+2,(OCT+1)*12+E_,RST	
	.byt END
	
__OrdinaryWorld_end


__TaintedLove_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 8
.byt <tlpattern_list_lo,>tlpattern_list_lo,<tlpattern_list_hi,>tlpattern_list_hi
.byt <_Tune2A, >_Tune2A, <_Tune2B, >_Tune2B, <_Tune2C, >_Tune2C


_Tune2A .byt SETVOL,2,ORN, 0, ENV, 5, 						0,0,0,0,0,0,5,6,0,0,0,5,6, 5,5,6,6,7,7,8,8,8,8,0,0,LOOP,0, END
_Tune2B	.byt ORN,3, ENV,4, 2,2,ORN,1,ENV,0,           4,             LOOP,0,END
_Tune2C	.byt ORN, 3, ENV, 4, 	    1,1,1,3,3,3,1,1,3,3,3,1,1,1,1,1,3,3, LOOP,0,END



tlpattern_list_lo 
	.byt <tl_p0,<tl_drums,<tl_wait,<tl_drums2,<tl_main1,<tl_p1,<t1_p2,<t1_p3,<t1_p4
tlpattern_list_hi 
	.byt >tl_p0,>tl_drums,>tl_wait,>tl_drums2,>tl_main1,>tl_p1,>t1_p2,>t1_p3,>t1_p4

#define OCT 2

tl_p0
.byt OCT*12+G_,RST, OCT*12+G_,RST, OCT*12+AS_,RST, OCT*12+AS_,RST,SIL
.byt (OCT+1)*12+DS_,RST, (OCT+1)*12+DS_,RST, OCT*12+AS_,(OCT+1)*12+C_,RST+1,SIL
.byt END

tl_p1
.byt OCT*12+G_,RST,OCT*12+G_,RST,OCT*12+G_,RST,OCT*12+G_,RST
.byt END

t1_p2
.byt OCT*12+AS_,RST,OCT*12+AS_,RST,OCT*12+AS_,RST,OCT*12+AS_,RST
.byt END

t1_p3
.byt (OCT+1)*12+DS_,RST,(OCT+1)*12+DS_,RST,(OCT+1)*12+DS_,RST,(OCT+1)*12+DS_,RST
.byt END

t1_p4
.byt (OCT+1)*12+C_,RST,(OCT+1)*12+C_,RST,(OCT+1)*12+C_,RST,(OCT+1)*12+C_,RST
.byt END


#define OCTD 2
tl_drums
.byt RST+1, OCTD*12+D_,RST, RST+1, OCTD*12+D_,RST
.byt RST+1, OCTD*12+D_,RST, RST+1, OCTD*12+D_,RST
.byt END

tl_drums2
.byt RST+1, OCTD*12+D_, RST, RST+1, OCTD*12+D_,RST
.byt RST+1, OCTD*12+D_, RST, OCTD*12+D_, OCTD*12+D_, OCTD*12+D_,RST
.byt END

/*
tl_drums3
.byt RST+1, OCTD*12+D_, RST, RST+1, OCTD*12+D_,RST
.byt RST+1, OCTD*12+D_, RST, RST, OCTD*12+D_, OCTD*12+D_,RST
.byt END
*/

tl_wait
	.byt (OCTD)*12+G_,RST,SIL,(OCTD)*12+G_,RST,SIL, RST+3, RST+7,END

#define OCTM 3
tl_main1
	.byt RST+13,(OCTM+1)*12+C_,RST
	.byt (OCTM+1)*12+D_,RST+1,OCTM*12+G_,RST+1,OCTM*12+AS_,RST,SIL
	.byt RST+1,OCTM*12+G_,RST,OCTM*12+AS_,RST,(OCTM+1)*12+C_,RST,SIL
	
	.byt RST+1,(OCTM+1)*12+D_,RST,OCTM*12+G_,RST,OCTM*12+AS_,RST,SIL
	.byt RST+1,OCTM*12+G_,RST,OCTM*12+AS_,RST,(OCTM+1)*12+C_,RST,SIL
	.byt RST+1,(OCTM+1)*12+D_,RST,OCTM*12+G_,RST,OCTM*12+AS_,RST,SIL

	.byt RST+1,(OCTM*12)+G_,OCTM*12+G_,OCTM*12+AS_,RST,(OCTM+1)*12+C_,RST
	.byt (OCTM+1)*12+D_,OCTM*12+G_,RST,OCTM*12+G_,RST,OCTM*12+G_,RST,(OCTM)*12+F_
	.byt OCTM*12+G_,OCTM*12+AS_,(OCTM+1)*12+C_,(OCTM+1)*12+D_,RST,(OCTM+1)*12+F_,(OCTM+1)*12+D_,RST,SIL
	
	.byt RST+2,OCTM*12+G_, RST+1, OCTM*12+AS_,RST,SIL
	.byt RST+1,OCTM*12+G_,RST,OCTM*12+AS_,RST,(OCTM+1)*12+C_,RST,SIL
	.byt RST+2,(OCTM+1)*12+D_,OCTM*12+G_,RST,OCTM*12+AS_,RST,SIL
	.byt RST+1,(OCTM*12)+G_,OCTM*12+G_,OCTM*12+AS_,RST,(OCTM+1)*12+C_,RST

	.byt (OCTM+1)*12+D_,RST+2,OCTM*12+G_,RST,OCTM*12+AS_,RST,SIL
	.byt RST+2,OCTM*12+G_,OCTM*12+AS_,RST,(OCTM+1)*12+C_,RST 
	
	.byt (OCTM+1)*12+D_,(OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,(OCTM+1)*12+D_,(OCTM+1)*12+C_
	.byt (OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,RST+2,SIL
	.byt RST+3,(OCTM)*12+B_,(OCTM)*12+A_,(OCTM)*12+G_,RST,SIL
	.byt (OCTM)*12+A_,RST,(OCTM)*12+G_,(OCTM)*12+G_,RST+3,SIL
	.byt RST+3,(OCTM+1)*12+D_,RST,(OCTM+1)*12+C_,(OCTM)*12+AS_
	.byt (OCTM+1)*12+D_,RST+2,OCTM*12+G_,OCTM*12+AS_,RST, SIL, RST
	.byt (OCTM+1)*12+DS_,RST,(OCTM+1)*12+DS_,RST,(OCTM+1)*12+DS_,RST,(OCTM+1)*12+DS_,RST
	.byt (OCTM+1)*12+DS_,RST,(OCTM+1)*12+F_,RST,(OCTM+1)*12+DS_,RST,(OCTM+1)*12+DS_,RST
	.byt (OCTM+1)*12+C_,RST,(OCTM+1)*12+C_,(OCTM+1)*12+C_,RST+2,(OCTM+1)*12+C_
	.byt (OCTM+1)*12+D_,RST,(OCTM+1)*12+C_,RST,(OCTM)*12+G_,RST,(OCTM+1)*12+C_,RST
	
	.byt (OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,RST
	.byt (OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,RST,(OCTM+1)*12+D_,(OCTM+1)*12+D_,(OCTM+1)*12+G_,RST,SIL
	.byt RST,(OCTM+1)*12+D_,(OCTM)*12+G_,RST,(OCTM)*12+AS_,RST+2,SIL
	.byt RST+7

	;.byt RST,(OCTM+1)*12+D_,(OCTM)*12+G_,RST,(OCTM)*12+AS_,RST+2,SIL
	.byt (OCTM+1)*12+D_,RST,SIL,RST+1,(OCTM)*12+G_,RST,(OCTM)*12+AS_,RST,SIL
	.byt RST+7
	
	.byt END


	
__TaintedLove_end


_PlayTL
.(
	lda #<__TaintedLove_start
	sta tmp
	lda #>__TaintedLove_start
	sta tmp+1
	jmp _PlaySong
.)

__EnolaGay_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 8
.byt <egpattern_list_lo,>egpattern_list_lo,<egpattern_list_hi,>egpattern_list_hi
.byt <_Tune3A, >_Tune3A, <_Tune3B, >_Tune3B, <_Tune3C, >_Tune3C


_Tune3A .byt ORN, 1, ENV, 2,SETVOL,0,		0,0,0,1,0,0,0,1,0,0,0,1, 0,1,6,  LOOP,0,END
_Tune3B	.byt ORN, 3, ENV, 4,SETVOL,0,NOFF, NVAL, 2,		2,     2,     7,      8, 8,8,8,8,8,8,8,8,  LOOP,0,END
_Tune3C	.byt ORN, 1, ENV, 0,SETVOL,0, 		3,3,3,3,4,4,4,4,5,5,5,5, 9,9,10,10,11,11,12,12,13,13,     LOOP,0,END



egpattern_list_lo 
	.byt <eg_p0,<eg_p1,<eg_drums0,<eg_pm0,<eg_pm1,<eg_pm2,<eg_p2,<eg_drums1,<eg_drums2,<eg_pm3,<eg_pm4,<eg_pm5,<eg_pm6,<eg_pm7
egpattern_list_hi 
	.byt >eg_p0,>eg_p1,>eg_drums0,>eg_pm0,>eg_pm1,>eg_pm2,>eg_p2,>eg_drums1,>eg_drums2,>eg_pm3,>eg_pm4,>eg_pm5,>eg_pm6,>eg_pm7

#define OCT 4

eg_p0
.byt OCT*12+F_,OCT*12+D_,OCT*12+F_,OCT*12+E_
.byt END

eg_p1
.byt OCT*12+F_,OCT*12+D_,OCT*12+G_,OCT*12+E_
.byt END

eg_p2
.byt OCT*12+F_,OCT*12+F_,OCT*12+A_,OCT*12+AS_,(OCT+1)*12+C_,OCT*12+AS_,OCT*12+A_,OCT*12+F_

.byt RST,OCT*12+F_,OCT*12+A_,OCT*12+AS_,(OCT+1)*12+C_,(OCT)*12+AS_,OCT*12+A_,RST
.byt OCT*12+D_,OCT*12+D_,OCT*12+F_,OCT*12+G_,OCT*12+A_,OCT*12+G_,OCT*12+F_,OCT*12+D_
.byt RST,OCT*12+D_,OCT*12+A_,OCT*12+A_,OCT*12+G_,RST,OCT*12+F_,RST

.byt (OCT-1)*12+AS_,(OCT-1)*12+AS_,(OCT)*12+D_,(OCT)*12+DS_,(OCT)*12+F_,(OCT)*12+DS_,(OCT)*12+D_,(OCT-1)*12+AS_
.byt RST,(OCT-1)*12+AS_,(OCT)*12+D_,(OCT)*12+DS_,(OCT)*12+F_,(OCT)*12+DS_,(OCT)*12+D_,RST
.byt (OCT)*12+C_,(OCT)*12+C_,(OCT)*12+E_,(OCT)*12+F_,(OCT)*12+G_,(OCT)*12+F_,(OCT)*12+E_,(OCT)*12+C_

.byt RST,(OCT)*12+C_,(OCT)*12+G_,(OCT)*12+G_,(OCT)*12+F_,RST,(OCT)*12+E_,RST

.byt END




#define OCTD 3
eg_drums0
.byt OCTD*12+D_, RST+2, OCTD*12+D_,RST+2
.byt OCTD*12+D_, RST+2, OCTD*12+D_,RST+2
.byt END

eg_drums1
.byt OCTD*12+D_, RST+2, OCTD*12+D_,RST+2
.byt OCTD*12+D_, OCTD*12+D_, OCTD*12+D_, OCTD*12+D_, OCTD*12+D_, OCTD*12+D_, OCTD*12+D_, OCTD*12+D_
.byt END

eg_drums2
.byt OCTD*12+D_, RST, OCTD*12+D_, RST, OCTD*12+D_, OCTD*12+D_, PNON,OCTD*12+D_, RST,PNOFF 
.byt END

#define OCTM 3
eg_pm0
.byt OCTM*12+F_,OCTM*12+F_,OCTM*12+F_,OCTM*12+F_
.byt END
eg_pm1
.byt OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_
.byt END
eg_pm2
.byt (OCTM-1)*12+AS_,(OCTM-1)*12+AS_,(OCTM-1)*12+AS_,(OCTM-1)*12+AS_
.byt END
eg_pm3
.byt OCTM*12+C_,OCTM*12+C_,OCTM*12+C_,OCTM*12+C_
.byt END
eg_pm4
.byt (OCTM-1)*12+F_,(OCTM)*12+F_,(OCTM)*12+F_,(OCTM-1)*12+F_
.byt (OCTM)*12+F_,(OCTM-1)*12+F_,(OCTM)*12+F_,(OCTM)*12+F_
.byt END
eg_pm5
.byt (OCTM-1)*12+D_,(OCTM)*12+D_,(OCTM)*12+D_,(OCTM-1)*12+D_
.byt (OCTM)*12+D_,(OCTM-1)*12+D_,(OCTM)*12+D_,(OCTM)*12+D_
.byt END
eg_pm6
.byt (OCTM-1)*12+AS_,(OCTM)*12+AS_,(OCTM)*12+AS_,(OCTM-1)*12+AS_
.byt (OCTM)*12+AS_,(OCTM-1)*12+AS_,(OCTM)*12+AS_,(OCTM)*12+AS_
.byt END
eg_pm7
.byt (OCTM-1)*12+C_,(OCTM)*12+C_,(OCTM)*12+C_,(OCTM-1)*12+C_
.byt (OCTM)*12+C_,(OCTM-1)*12+C_,(OCTM)*12+C_,(OCTM)*12+C_
.byt END

__EnolaGay_end

_PlayEG
.(
	lda #<__EnolaGay_start
	sta tmp
	lda #>__EnolaGay_start
	sta tmp+1
	jmp _PlaySong
.)



__LivingOnVideo_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 8
.byt <lvpattern_list_lo,>lvpattern_list_lo,<lvpattern_list_hi,>lvpattern_list_hi
.byt <_Tune4A, >_Tune4A, <_Tune4B, >_Tune4B, <_Tune4C, >_Tune4C


_Tune4A .byt ORN, 0, ENV, 1,		0,0,0,0,   2,5,  5,  5,  5,  5,  5,  5      ,LOOP,9,END
_Tune4B	.byt ORN, 2, ENV, 1,		1,1,	   3,4,3,4,3,4,3,4,3,4,3,4,3,4,3  ,LOOP,7,END
_Tune4C	.byt ORN, 4, ENV, 2, 		0,0,0,0,   0,0,0,0,0,0,6,  6,  6,  6  ,0    ,LOOP,9,END


lvpattern_list_lo 
	.byt <lv_wait,<lv_p0,<lv_p0m,<lv_p1,<lv_p2,<lv_p1m,<lv_p1v
lvpattern_list_hi 
	.byt >lv_wait,>lv_p0,>lv_p0m,>lv_p1,>lv_p2,>lv_p1m,>lv_p1v


lv_wait
.byt SIL,RST+7
.byt END

#define OCT 2

lv_p0
.byt OCT*12+GS_,RST,OCT*12+GS_,RST,OCT*12+DS_,RST,OCT*12+E_,RST
.byt OCT*12+FS_,RST,OCT*12+FS_,RST,OCT*12+FS_,RST,OCT*12+FS_,RST
.byt END

lv_p1
.byt OCT*12+GS_,(OCT+1)*12+GS_,OCT*12+GS_,(OCT+1)*12+GS_,OCT*12+DS_,(OCT+1)*12+DS_,OCT*12+E_,(OCT+1)*12+E_
.byt END

lv_p2
.byt OCT*12+FS_,(OCT+1)*12+FS_,OCT*12+FS_,(OCT+1)*12+FS_,OCT*12+FS_,(OCT+1)*12+FS_,OCT*12+FS_,(OCT+1)*12+FS_
.byt END


#define OCTM 4
lv_p0m
.byt OCTM*12+B_,OCTM*12+GS_,OCTM*12+B_,OCTM*12+DS_,OCTM*12+B_,OCTM*12+GS_,OCTM*12+B_,OCTM*12+E_
.byt END

lv_p1m
.byt (OCTM+1)*12+CS_,OCTM*12+AS_,(OCTM+1)*12+CS_,OCTM*12+FS_,OCTM*12+B_,OCTM*12+AS_,OCTM*12+B_,OCTM*12+GS_
.byt OCTM*12+B_,OCTM*12+GS_,OCTM*12+B_,OCTM*12+DS_, OCTM*12+B_,OCTM*12+GS_,OCTM*12+B_,OCTM*12+E_
.byt END

#define OCTV 5
lv_p1v
.byt OCTV*12+GS_,RST,OCTV*12+GS_,OCTV*12+AS_,OCTV*12+B_,OCTV*12+E_,SIL,RST,OCTV*12+FS_
.byt OCTV*12+FS_,OCTV*12+GS_,OCTV*12+FS_,RST,(OCTV+1)*12+CS_,OCTV*12+B_,OCTV*12+AS_,SIL,RST
.byt END


__LivingOnVideo_end

_PlayLV
.(
	lda #<__LivingOnVideo_start
	sta tmp
	lda #>__LivingOnVideo_start
	sta tmp+1
	jmp _PlaySong
.)


__Stay_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 14
.byt <spattern_list_lo,>spattern_list_lo,<spattern_list_hi,>spattern_list_hi
.byt <_Tune5A, >_Tune5A, <_Tune5B, >_Tune5B, <_Tune5C, >_Tune5C

_Tune5A .byt ORN, 2, ENV, 1, SETVOL,4,				0,2,  2,  2,  2,			 2,  2,  2,  0,0,		LOOP,0,END
_Tune5B	.byt ORN, 1, ENV, 2, SETVOL,2,				3,						  			 		 	    		LOOP,0,END
_Tune5C	.byt ORN, 3, ENV, 4,NVAL, 1,SETVOL,4, 		0,1,1,1,1,1,1,1,SETVOL,0, 4,SETVOL,3,1,1,1,1,1,1,SETVOL,0,NVAL,8,5,4,		LOOP,0,END


spattern_list_lo 
	.byt <s_wait,<s_drums0,<s_p0,<s_m0,<s_drums1,<s_drums2
spattern_list_hi 
	.byt >s_wait,>s_drums0,>s_p0,>s_m0,>s_drums1,>s_drums2


s_wait
.byt SIL,RST+7,END

#define OCTD 2
s_drums0
.byt PNON,OCTD*12+FS_,PNOFF,OCTD*12+FS_,PNON,OCTD*12+FS_,OCTD*12+FS_,PNOFF
.byt PNON,OCTD*12+FS_,PNOFF,OCTD*12+FS_,PNON,OCTD*12+FS_,OCTD*12+FS_,PNOFF
.byt END

s_drums1
.byt OCTD*12+E_,OCTD*12+E_,OCTD*12+E_,OCTD*12+E_
.byt OCTD*12+C_,OCTD*12+C_,OCTD*12+C_,PNON,OCTD*12+A_,PNOFF
.byt END

s_drums2
.byt PNON,OCTD*12+E_,OCTD*12+B_,OCTD*12+CS_,PNOFF,RST+4
.byt END

#define OCT 2
s_p0
.byt OCT*12+G_,RST,SIL,RST,OCT*12+G_,OCT*12+E_,RST+1,OCT*12+E_,SIL
.byt OCT*12+C_,OCT*12+C_,RST,SIL,OCT*12+C_,OCT*12+D_,RST+1,OCT*12+D_
.byt END


#define OCTM 4

s_m0
.byt RST+5,OCTM*12+G_,OCTM*12+G_
.byt OCTM*12+G_,RST+6
.byt RST+1,OCTM*12+G_,OCTM*12+G_,OCTM*12+FS_,OCTM*12+G_,OCTM*12+A_,OCTM*12+G_

.byt OCTM*12+B_,RST,OCTM*12+G_,RST+4
.byt RST+4,OCTM*12+B_,OCTM*12+A_,OCTM*12+G_
.byt OCTM*12+G_,RST+2,OCTM*12+B_,RST+2

.byt SIL,RST,OCTM*12+G_,RST,OCTM*12+G_,OCTM*12+FS_,OCTM*12+G_,OCTM*12+A_,OCTM*12+G_
.byt OCTM*12+B_,RST+2,OCTM*12+G_,RST+2

.byt SIL,RST+5,OCTM*12+D_,OCTM*12+D_ 
.byt OCTM*12+B_,OCTM*12+G_,OCTM*12+A_,OCTM*12+E_,OCTM*12+G_,RST+2
.byt SIL,RST+5,OCTM*12+D_,OCTM*12+D_ 
.byt OCTM*12+B_,OCTM*12+G_,OCTM*12+A_,OCTM*12+E_,OCTM*12+G_,RST+2  

.byt SIL,RST+5,OCTM*12+D_,OCTM*12+D_ 
.byt OCTM*12+B_,OCTM*12+G_,OCTM*12+A_,OCTM*12+E_,OCTM*12+G_,SIL,RST,OCTM*12+E_,OCTM*12+D_
.byt OCTM*12+B_,OCTM*12+G_,OCTM*12+A_,OCTM*12+E_,OCTM*12+G_,SIL,RST,OCTM*12+E_,OCTM*12+D_

.byt RST+1,(OCTM+1)*12+E_,RST+2,OCTM*12+B_,OCTM*12+A_,SIL
.byt OCTM*12+G_,RST+2,SIL,RST+3;,(OCTM+1)*12+B_,RST,(OCTM+2)*12+D_,RST,(OCTM+1)*12+B_,RST


.byt END



__Stay_end

_PlayST
.(
	lda #<__Stay_start
	sta tmp
	lda #>__Stay_start
	sta tmp+1
	jmp _PlaySong
.)


__LessonsInLove_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 5
;.byt 15
.byt <llpattern_list_lo,>llpattern_list_lo,<llpattern_list_hi,>llpattern_list_hi
.byt <_Tune6A, >_Tune6A, <_Tune6B, >_Tune6B, <_Tune6C, >_Tune6C

_Tune6A .byt ORN, 1, ENV, 2, SETVOL,2,		5,5,0,ORN, 1, ENV, 0, SETVOL,2,			0,0,0,0,0,4,9,			LOOP,21,	END
_Tune6B	.byt ORN, 1, ENV, 2, SETVOL,2,		6,6,0,ORN, 2, ENV, 3, SETVOL,3,			2,3,3,3,3, 				LOOP,16,END
_Tune6C	.byt ORN, 1, ENV, 2, SETVOL,2, 		7,7,ENV, 3, ORN, 1,8,ORN, 3, ENV, 4, SETVOL,0, 			1,	LOOP,17+2,			END
5

llpattern_list_lo 
	.byt <ll_wait,<ll_drums0,<ll_p0,<ll_p1,<ll_pm0,<ll_init1,<ll_init2,<ll_init3,<ll_init4,<ll_pm1
llpattern_list_hi 
	.byt >ll_wait,>ll_drums0,>ll_p0,>ll_p1,>ll_pm0,>ll_init1,>ll_init2,>ll_init3,>ll_init4,>ll_pm1

#define OCTI 4
ll_init1
.byt OCTI*12+GS_,RST+3+2, OCTI*12+A_,RST+4+3/*, OCTI*12+D_,RST+3+2*/
.byt OCTI*12+A_,RST+14
.byt END

ll_init2
.byt OCTI*12+E_,RST+14
.byt OCTI*12+C_,RST+14
.byt END

ll_init3
.byt (OCTI-1)*12+E_,RST+3+2, (OCTI-1)*12+D_,RST+4+3/*, RST+4+2*/
.byt (OCTI-1)*12+C_,RST+14
.byt END

ll_init4
.byt SIL,(OCTI+1)*12+G_,RST,(OCTI+1)*12+FS_,RST,(OCTI+1)*12+E_,RST,(OCTI)*12+G_,RST,(OCTI)*12+G_,RST+3+3,END

ll_wait
.byt SIL,RST+15,END

#define OCTD 1
ll_drums0
/*
.byt PNON,OCTD*12+FS_,PNOFF,OCTD*12+FS_,OCTD*12+FS_,OCTD*12+FS_
.byt PNON,OCTD*12+FS_,PNOFF,OCTD*12+FS_,OCTD*12+FS_,OCTD*12+FS_
.byt PNON,OCTD*12+FS_,PNOFF,OCTD*12+FS_,OCTD*12+FS_,OCTD*12+FS_
.byt PNON,OCTD*12+FS_,PNOFF,OCTD*12+FS_,OCTD*12+FS_,OCTD*12+FS_
*/
.byt OCTD*12+FS_,RST+2
.byt OCTD*12+FS_,RST+2
.byt OCTD*12+FS_,RST+2
.byt OCTD*12+FS_,RST+2

.byt END

#define OCT 2
ll_p0
.byt OCT*12+G_,RST,OCT*12+G_,OCT*12+G_,OCT*12+G_,RST,OCT*12+G_,OCT*12+G_
.byt OCT*12+G_,RST,OCT*12+G_,OCT*12+G_,OCT*12+G_,RST,OCT*12+G_,RST
.byt END

ll_p1
.byt OCT*12+G_,RST,OCT*12+G_,OCT*12+G_,OCT*12+B_,RST,OCT*12+B_,OCT*12+B_
.byt (OCT+1)*12+D_,RST,(OCT+1)*12+D_,(OCT+1)*12+D_,(OCT+1)*12+G_,RST,(OCT+1)*12+G_,(OCT+1)*12+G_

.byt (OCT+1)*12+B_,RST,(OCT+1)*12+B_,(OCT+1)*12+B_,(OCT+1)*12+DS_,RST,(OCT+1)*12+DS_,(OCT+1)*12+DS_
.byt (OCT+1)*12+FS_,RST,(OCT+1)*12+FS_,(OCT+1)*12+FS_,(OCT+1)*12+B_,RST,(OCT+1)*12+B_,(OCT+1)*12+B_

.byt (OCT)*12+E_,RST,(OCT)*12+E_,(OCT)*12+E_,(OCT)*12+G_,RST,(OCT)*12+G_,(OCT)*12+G_
.byt (OCT)*12+B_,RST,(OCT)*12+B_,(OCT)*12+B_,(OCT)*12+E_,RST,(OCT)*12+E_,(OCT)*12+E_

.byt (OCT)*12+C_,RST,(OCT)*12+C_,(OCT)*12+C_,(OCT)*12+E_,RST,(OCT)*12+E_,(OCT)*12+E_
.byt (OCT)*12+G_,RST,(OCT)*12+G_,(OCT)*12+G_,(OCT+1)*12+C_,RST,(OCT+1)*12+C_,(OCT+1)*12+C_


.byt END

#define OCTM 4
ll_pm0
.byt OCTM*12+G_,RST+2,SIL,RST+3,OCTM*12+G_,RST+2,OCTM*12+A_,RST+2
.byt OCTM*12+FS_,RST+2,SIL,RST+1,OCTM*12+B_,RST+2,OCTM*12+A_,RST+2,OCTM*12+G_,RST+4
.byt SIL,RST+3,OCTM*12+A_,RST+2,OCTM*12+B_,RST+2
.byt END

ll_pm1
.byt (OCTM+1)*12+C_,RST+2,OCTM*12+G_,RST,(OCTM+1)*12+C_,RST+2,(OCTM+1)*12+D_,RST+2,OCTM*12+B_,RST+4
.byt SIL,RST+3,OCTM*12+B_,RST+2,OCTM*12+D_,RST+2
.byt (OCTM+1)*12+DS_,RST+2,OCTM*12+B_,RST,OCTM*12+A_,RST+2,OCTM*12+B_,RST+2,OCTM*12+G_,RST+4
.byt SIL,RST+3,OCTM*12+A_,RST+2,OCTM*12+B_,RST+2
.byt (OCTM+1)*12+C_,RST+2,OCTM*12+G_,RST,(OCTM+1)*12+C_,RST+2,(OCTM+1)*12+D_,RST+2,OCTM*12+B_,OCTM*12+A_
.byt OCTM*12+G_,RST+4,SIL,RST+1,OCTM*12+G_,RST+2,OCTM*12+A_,RST+2
.byt OCTM*12+FS_,RST+4,OCTM*12+B_,RST+2,OCTM*12+A_,RST+2,OCTM*12+G_,RST+4
.byt SIL,RST+3,OCTM*12+A_,RST+2,OCTM*12+B_,RST+2
.byt END

/* REpeated!*/
/*
.byt (OCTM+1)*12+C_,RST+2,OCTM*12+G_,RST,(OCTM+1)*12+C_,RST+2,(OCTM+1)*12+D_,RST+2,OCTM*12+B_,RST+4
.byt SIL,RST+3,OCTM*12+B_,RST+2,OCTM*12+D_,RST+2
.byt (OCTM+1)*12+DS_,RST+2,OCTM*12+B_,RST,OCTM*12+A_,RST+2,OCTM*12+B_,RST+2,OCTM*12+G_,RST+4
.byt SIL,RST+3,OCTM*12+A_,RST+2,OCTM*12+B_,RST+2
.byt (OCTM+1)*12+C_,RST+2,OCTM*12+G_,RST,(OCTM+1)*12+C_,RST+2,(OCTM+1)*12+D_,RST+2,OCTM*12+B_,OCTM*12+A_
.byt OCTM*12+G_,RST+4,SIL,RST+1,OCTM*12+G_,RST+2,OCTM*12+A_,RST+2
.byt OCTM*12+FS_,RST+4,OCTM*12+B_,RST+2,OCTM*12+A_,RST+2,OCTM*12+G_,RST+4
.byt SIL,RST+3,OCTM*12+A_,RST+2,OCTM*12+B_,RST+2
*/
.byt END


__LessonsInLove_end

_PlayLL
.(
	lda #<__LessonsInLove_start
	sta tmp
	lda #>__LessonsInLove_start
	sta tmp+1
	jmp _PlaySong
.)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Walk Like an Egyptian

__Walk_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 6
.byt <wepattern_list_lo,>wepattern_list_lo,<wepattern_list_hi,>wepattern_list_hi
.byt <_Tune7A, >_Tune7A, <_Tune7B, >_Tune7B, <_Tune7C, >_Tune7C

_Tune7A .byt ORN, 1, ENV, 2, 			2,2,3,3,3, LOOP,4, END
_Tune7B	.byt ORN, 2, ENV, 0, SETVOL,4,	1,1,1,1,1, LOOP, 6, END
_Tune7C	.byt ORN, 3, ENV, 4, NVAL,7, 	0,0,0,0,0, LOOP, 4, END


wepattern_list_lo 
	.byt <we_drums0,<we_bass0,<we_wait,<we_main0
wepattern_list_hi 
	.byt >we_drums0,>we_bass0,>we_wait,>we_main0


#define OCTD 3
we_drums0
.byt /*SIL,RST+1*/PNON,(OCTD+1)*12+D_,RST+1,PNOFF,OCTD*12+D_,OCTD*12+D_,OCTD*12+D_,SIL,RST,OCTD*12+D_,RST
.byt OCTD*12+D_,RST,OCTD*12+D_,OCTD*12+D_,SIL,RST,OCTD*12+D_,RST
.byt SIL,RST+1,OCTD*12+D_,OCTD*12+D_,OCTD*12+D_,SIL,RST,OCTD*12+D_,RST
.byt SIL,RST+7

.byt END

#define OCTB 2
we_bass0
.byt OCTB*12+B_,RST+1,OCTB*12+FS_,RST+1,OCTB*12+A_,RST
.byt OCTB*12+B_,RST+1,OCTB*12+FS_,RST+1,OCTB*12+A_,RST
.byt OCTB*12+B_,RST+1,OCTB*12+FS_,RST+1,OCTB*12+A_,RST
.byt OCTB*12+B_,RST+1,OCTB*12+FS_,RST+1,OCTB*12+A_,RST
.byt END

#define OCTM 4

we_wait
.byt RST+7,RST+7,RST+7,RST+7,END

we_main0
.byt RST+1,OCTM*12+FS_,OCTM*12+DS_,OCTM*12+DS_,RST,OCTM*12+DS_,RST
.byt OCTM*12+DS_,RST+1,OCTM*12+CS_,RST,OCTM*12+FS_,OCTM*12+DS_,RST
.byt SIL,RST+1,OCTM*12+DS_,OCTM*12+E_,RST,OCTM*12+DS_,(OCTM-1)*12+B_,RST
.byt (OCTM-1)*12+B_,RST+1,(OCTM-1)*12+A_,RST,(OCTM-1)*12+A_,(OCTM-1)*12+B_,RST
.byt SIL,END



__Walk_end

_PlayWE
.(
	lda #<__Walk_start
	sta tmp
	lda #>__Walk_start
	sta tmp+1
	jmp _PlaySong
.)




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Take on Me

__TakeOnMe_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 8
.byt <tonpattern_list_lo,>tonpattern_list_lo,<tonpattern_list_hi,>tonpattern_list_hi
.byt <_Tune8A, >_Tune8A, <_Tune8B, >_Tune8B, <_Tune8C, >_Tune8C

_Tune8A .byt ORN, 0, ENV, 1, 				1,2,1, 	ENV, 5,						4,4,4, 			 LOOP,9, END
_Tune8B	.byt ORN, 1, ENV, 1,				1,3, ORN, 2, ENV, 3, 			5,6,7,6,6,6,6,   LOOP, 11, END
_Tune8C	.byt ORN, 3, ENV, 4, NVAL,7, 		0, LOOP, 4, END


tonpattern_list_lo 
	.byt <ton_drums0,<ton_wait,<ton_initA,<ton_initB,<ton_main0,<ton_bass0,<ton_bass1,<ton_bass2
tonpattern_list_hi 
	.byt >ton_drums0,>ton_wait,>ton_initA,>ton_initB,>ton_main0,>ton_bass0,>ton_bass1,>ton_bass2


#define OCTD 2
ton_drums0
/*
.byt PNON, OCTD*12+FS_, OCTD*12+FS_, PNOFF, OCTD*12+FS_, PNON, OCTD*12+FS_
.byt OCTD*12+FS_, SIL,RST, PNOFF, OCTD*12+FS_, PNON,OCTD*12+FS_,PNOFF
*/

.byt PNOFF, OCTD*12+FS_, OCTD*12+FS_, PNON, OCTD*12+FS_, PNOFF, OCTD*12+FS_
.byt OCTD*12+FS_, SIL,RST, PNON, OCTD*12+FS_, PNOFF,OCTD*12+FS_


.byt END

#define OCTB 2
ton_bass0
.byt OCTB*12+B_,RST,SIL,RST,(OCTB-1)*12+B_,RST+1,(OCTB-1)*12+B_,(OCTB-1)*12+B_
.byt OCTB*12+B_,OCTB*12+B_,RST+1,(OCTB-1)*12+B_,RST,(OCTB-1)*12+B_,(OCTB-1)*12+B_
.byt OCTB*12+B_,RST,SIL,RST,(OCTB-1)*12+B_,RST+1,(OCTB-1)*12+B_,(OCTB-1)*12+B_
.byt OCTB*12+B_,OCTB*12+B_,RST,OCTB*12+B_,RST+2,SIL,RST
.byt END

ton_bass1
.byt OCTB*12+B_,OCTB*12+B_,RST,OCTB*12+B_,RST,SIL,RST+1,OCTB*12+E_
.byt RST,OCTB*12+E_,RST,SIL,RST,OCTB*12+E_,OCTB*12+E_,RST,SIL,RST
.byt END

ton_bass2
.byt OCTB*12+A_,OCTB*12+A_,RST,OCTB*12+A_,RST,SIL,RST+1,OCTD*12+E_
.byt RST,OCTB*12+D_,RST,SIL,RST,OCTB*12+CS_,OCTB*12+CS_,RST,SIL,RST
.byt END


ton_wait
;.byt RST+7
;.byt RST+7
.byt RST+7
.byt RST+7, END


#define OCT 5
ton_initA
.byt OCT*12+CS_,RST+6,SIL,RST+11,RST+11
.byt (OCT-1)*12+FS_,RST+6+8,SIL
.byt END

ton_initB
.byt (OCT-1)*12+FS_,RST+6,SIL,RST+11,RST+11
.byt END

#define OCTM 4
ton_main0
.byt OCTM*12+FS_,OCTM*12+FS_,OCTM*12+D_,(OCTM-1)*12+B_,RST,(OCTM-1)*12+B_,RST,OCTM*12+E_
.byt RST,OCTM*12+E_,RST,OCTM*12+E_,OCTM*12+GS_,OCTM*12+GS_,OCTM*12+A_,OCTM*12+B_

.byt OCTM*12+A_,OCTM*12+A_,OCTM*12+A_,OCTM*12+E_,RST,OCTM*12+D_,RST,OCTM*12+FS_
.byt RST,OCTM*12+FS_,RST,OCTM*12+FS_,OCTM*12+E_,OCTM*12+E_,OCTM*12+FS_,OCTM*12+E_

.byt END

/*
ton_main1
.byt OCTM*12+A_,OCTM*12+A_,OCTM*12+A_,OCTM*12+FS_,RST,OCTM*12+D_,RST,OCTM*12+FS_
.byt RST,OCTM*12+FS_,RST,OCTM*12+FS_,OCTM*12+E_,OCTM*12+E_,OCTM*12+E_,(OCTM-1)*12+B_

;.byt OCTM*12+D_,RST,SIL,RST,OCTM*12+D_,OCTM*12+D_,OCTM*12+CS_,OCTM*12+B_,RST+1; One extra
;.byt SIL,RST+6

.byt END
*/
__TakeOnMe_end

_PlayTOM
.(
	lda #<__TakeOnMe_start
	sta tmp
	lda #>__TakeOnMe_start
	sta tmp+1
	jmp _PlaySong
.)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;True

__True_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 14
.byt <tpattern_list_lo,>tpattern_list_lo,<tpattern_list_hi,>tpattern_list_hi
.byt <_Tune9A, >_Tune9A, <_Tune9B, >_Tune9B, <_Tune9C, >_Tune9C

_Tune9A .byt ORN, 1, ENV, 1, SETVOL,4, 			1, LOOP,4, END
_Tune9B	.byt ORN, 1, ENV, 1, SETVOL,6,	3, LOOP, 6, END
_Tune9C	.byt ORN, 1, ENV, 4, NVAL,7, 	0, LOOP, 4, END


tpattern_list_lo 
	.byt <t_drums0,<t_synth0,<t_wait,<t_main0
tpattern_list_hi 
	.byt >t_drums0,>t_synth0,>t_wait,>t_main0

#define OCTM 5
#define OCTD 3
#define OCT 4

t_drums0
.byt RST,OCTM*12+D_,RST,SIL,RST,OCTM*12+D_,RST,SIL,RST,PNON,OCTD*12+AS_,PNOFF
;.byt SIL,RST+4,PNON,OCTD*12+FS_,OCTD*12+FS_,PNOFF,OCTD*12+AS_
.byt END


t_synth0
.byt OCT*12+D_,RST+6,OCT*12+FS_,RST+6,OCT*12+D_,RST+2,(OCT-1)*12+G_,RST,(OCT-1)*12+C_,RST
.byt OCT*12+D_,RST+6,OCT*12+D_,RST+6,OCT*12+FS_,RST+6

.byt OCT*12+D_,RST+6,(OCT-1)*12+G_,RST+2,OCT*12+D_,RST+2

.byt END

t_wait
.byt RST+7,RST+7,RST+7,RST+7,END

t_main0
;.byt RST,OCTM*12+DS_,RST,SIL,RST,OCTM*12+DS_,RST,SIL,RST,PNON,OCTD*12+AS_,PNOFF
.byt (OCT-1)*12+B_,RST+6,OCT*12+D_,RST+6,(OCT-1)*12+B_,RST+6
.byt (OCT-1)*12+A_,RST+6,(OCT-1)*12+B_,RST+6,OCT*12+D_,RST+6
.byt SIL,END



__True_end

_PlayTR
.(
	lda #<__True_start
	sta tmp
	lda #>__True_start
	sta tmp+1
	jmp _PlaySong
.)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Walking on Sunshine

__Walking_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 6
.byt <wspattern_list_lo,>wspattern_list_lo,<wspattern_list_hi,>wspattern_list_hi
.byt <_Tune10A, >_Tune10A, <_Tune10B, >_Tune10B, <_Tune10C, >_Tune10C

_Tune10A 	.byt ORN, 0, ENV, 2, SETVOL,2, 	3,3,		2, 	LOOP,8, END
_Tune10B	.byt ORN, /*4*/1, ENV, 2, SETVOL,1,	3,3,3,3, 		4,4,		LOOP, 8, END
_Tune10C	.byt ORN, 1, ENV, 4, NVAL,7, 	0,0,0,1, 			LOOP, 4, END


wspattern_list_lo 
	.byt <ws_drums0,<ws_drums1,<ws_synth0,<ws_wait,<ws_main0
wspattern_list_hi 
	.byt >ws_drums0,>ws_drums1,>ws_synth0,>ws_wait,>ws_main0

#define OCTM (4+1)
#define OCTD 2
#define OCT (4-1)

ws_drums0
.byt OCTD*12+C_,RST,PNON,OCTD*12+E_,RST,PNOFF,OCTD*12+C_,RST,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,RST,OCTD*12+C_,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,OCTD*12+C_,RST,PNON,OCTD*12+E_,RST,PNOFF
.byt END

ws_drums1
.byt OCTD*12+C_,RST,PNON,OCTD*12+E_,RST,PNOFF,OCTD*12+C_,RST,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,RST,OCTD*12+C_,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,OCTD*12+C_,PNON,OCTD*12+E_,OCTD*12+E_,PNOFF,RST
.byt END


ws_synth0
.byt OCT*12+GS_,RST,OCT*12+GS_,RST,OCT*12+GS_,RST,(OCT-1)*12+B_,(OCT)*12+A_,RST,(OCT)*12+A_,(OCT)*12+A_,SIL,RST,(OCT)*12+A_,(OCT)*12+A_,(OCT)*12+A_,(OCT)*12+A_    ;,RST,(OCT)*12+A_,RST,(OCT)*12+A_,RST ;,(OCT)*12+A_,RST
.byt OCT*12+B_,RST,OCT*12+B_,RST,OCT*12+B_,RST,OCT*12+DS_,OCT*12+A_,RST,OCT*12+A_,RST,OCT*12+A_,OCT*12+A_,RST,OCT*12+A_,RST
.byt END

ws_wait
.byt RST+7,RST+7,RST+7,RST+7,END

ws_main0

.byt OCTM*12+E_,RST+2,SIL,RST+4,/*OCTM*12+E_,RST,OCTM*12+CS_,(OCTM-1)*12+GS_,RST,*/OCTM*12+CS_,OCTM*12+CS_,OCTM*12+CS_,OCTM*12+CS_,RST,OCTM*12+CS_,RST+1
.byt OCTM*12+DS_,RST,OCTM*12+DS_,OCTM*12+DS_,OCTM*12+DS_,OCTM*12+D_,OCTM*12+CS_,RST+2,SIL,RST+4

.byt END



__Walking_end

_PlayWS
.(
	lda #<__Walking_start
	sta tmp
	lda #>__Walking_start
	sta tmp+1
	jmp _PlaySong
.)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Big in Japan 

__BigInJapan_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 6
.byt <bjpattern_list_lo,>bjpattern_list_lo,<bjpattern_list_hi,>bjpattern_list_hi
.byt <_Tune11A, >_Tune11A, <_Tune11B, >_Tune11B, <_Tune11C, >_Tune11C

_Tune11A 	.byt ORN, 1, ENV, 2, SETVOL,1, 	3,ENV, 3,3,5, 	LOOP,6+1, END
_Tune11B	.byt ORN, 1, ENV, 5, SETVOL,1,	4,4,2,2,		LOOP, 6+2, END
_Tune11C	.byt ORN, 1, ENV, 4, NVAL,7-3, 	4,4,0,0,0,0,0,0,0,1, 			LOOP, 6+2, END


bjpattern_list_lo 
	.byt <bj_drums0,<bj_drums1,<bj_synth0,<bj_main0,<bj_wait,<bj_main1
bjpattern_list_hi 
	.byt >bj_drums0,>bj_drums1,>bj_synth0,>bj_main0,>bj_wait,>bj_main1

#define OCTM (4)
#define OCTD 1
#define OCT (4-1)

bj_drums0
.byt OCTD*12+B_,RST+1,OCTD*12+B_,PNON,OCTD*12+D_,RST,SIL,RST+1,PNOFF
.byt END

bj_drums1
.byt OCTD*12+B_,RST+1,OCTD*12+B_,PNON,OCTD*12+D_,RST,OCTD*12+D_,RST,PNOFF
.byt END


bj_synth0
.byt OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_
.byt (OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_
.byt OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_,OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_

.byt (OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_,(OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_
/*
.byt OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_
.byt (OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_

.byt OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_,OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_
;.byt (OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_,RST,(OCT-1)*12+AS_,(OCT-1)*12+AS_
.byt (OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_,(OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+A_
;.byt SIL,RST+15
*/
.byt END


bj_wait
.byt RST+15,END

bj_main0

.byt OCTM*12+F_,RST,OCTM*12+D_,RST,OCTM*12+C_,OCTM*12+C_,OCTM*12+D_,OCTM*12+F_,RST+1,SIL,RST+5
.byt OCTM*12+F_,RST,OCTM*12+D_,RST,OCTM*12+C_,OCTM*12+C_,OCTM*12+D_,OCTM*12+G_,RST+1,SIL,RST+1,OCTM*12+F_,RST+2
.byt END

bj_main1
.byt OCTM*12+F_,RST,OCTM*12+D_,RST,OCTM*12+C_,OCTM*12+C_,OCTM*12+D_,OCTM*12+F_,OCTM*12+F_,OCTM*12+D_,OCTM*12+C_,RST,OCTM*12+D_,RST,SIL,RST+1

.byt OCTM*12+A_,RST,OCTM*12+A_,RST,OCTM*12+A_,RST,(OCTM+1)*12+C_,RST,(OCTM+1)*12+C_,RST,(OCTM+1)*12+C_,RST,SIL,RST+3
.byt OCTM*12+F_,RST,OCTM*12+D_,RST,OCTM*12+C_,OCTM*12+C_,OCTM*12+D_,OCTM*12+F_,OCTM*12+F_,OCTM*12+D_,OCTM*12+C_,RST,OCTM*12+D_,RST,SIL,RST+1
.byt OCTM*12+F_,RST,OCTM*12+D_,RST,OCTM*12+C_,OCTM*12+C_,OCTM*12+D_,OCTM*12+G_,SIL,RST,OCTM*12+G_,RST,OCTM*12+G_,OCTM*12+F_,OCTM*12+F_,RST,SIL,RST

.byt OCTM*12+F_,RST,OCTM*12+D_,RST,OCTM*12+C_,OCTM*12+C_,OCTM*12+D_,OCTM*12+F_,OCTM*12+F_,OCTM*12+D_,OCTM*12+C_,RST,OCTM*12+D_,RST,SIL,RST+1
.byt OCTM*12+A_,RST,OCTM*12+A_,RST,OCTM*12+A_,RST,OCTM*12+A_,RST,OCTM*12+G_,(OCTM+1)*12+C_,OCTM*12+G_,OCTM*12+A_,RST+3,SIL

;.byt SIL,RST+15

.byt END



__BigInJapan_end

_PlayBJ
.(
	lda #<__BigInJapan_start
	sta tmp
	lda #>__BigInJapan_start
	sta tmp+1
	jmp _PlaySong
.)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Blue Monday

__BlueMonday_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 5
.byt <bmpattern_list_lo,>bmpattern_list_lo,<bmpattern_list_hi,>bmpattern_list_hi
.byt <_Tune12A, >_Tune12A, <_Tune12B, >_Tune12B, <_Tune12C, >_Tune12C

_Tune12A 	.byt ORN, 2, ENV, 06,SETVOL,2, 								                3,3,3,3,3,2, 	LOOP,9+2, END
_Tune12B	.byt ORN, 1, ENV, 4-4, SETVOL,10,	1,SETVOL,5, 6,SETVOL,3, 1,SETVOL,1,       6,1,6,1,	LOOP, 15, END
_Tune12C	.byt ORN, 1, ENV, 4, NVAL,20,NOFF, 							            0,0,0,0,0,0, 	LOOP, 6+1, END


bmpattern_list_lo 
	.byt <bm_drums0,<bm_synth0,<bm_main0,<bm_wait,<bm_main1,<bm_drums1,<bm_synth1
bmpattern_list_hi 
	.byt >bm_drums0,>bm_synth0,>bm_main0,>bm_wait,>bm_main1,>bm_drums1,>bm_synth1

#define OCTM (2)
#define OCTD 1
#define OCT (4)

bm_drums0
.byt OCTD*12+C_,RST,SIL,RST+1,OCTD*12+C_,RST,SIL,RST+1,OCTD*12+C_,OCTD*12+C_,OCTD*12+C_,OCTD*12+C_,OCTD*12+C_,OCTD*12+C_,OCTD*12+C_,OCTD*12+C_
.byt OCTD*12+C_,RST,SIL,RST+1,OCTD*12+C_,RST,SIL,RST+1,OCTD*12+C_,RST,SIL,RST+1,OCTD*12+C_,RST,SIL,RST+1
.byt END

bm_drums1
.byt OCTD*12+B_,RST+1,OCTD*12+B_,PNON,OCTD*12+D_,RST,OCTD*12+D_,RST,PNOFF
.byt END


bm_synth0
/*.byt OCT*12+F_,OCT*12+F_,OCT*12+F_,RST+2, OCT*12+G_,OCT*12+G_,OCT*12+C_,RST+2, OCT*12+C_,OCT*12+C_,OCT*12+D_,SIL,RST
.byt OCT*12+D_,OCT*12+D_,OCT*12+D_,RST+2, OCT*12+D_,OCT*12+D_,OCT*12+D_,RST+2, OCT*12+D_,OCT*12+D_,RST+1
*/

/*
.byt RST+1,OCT*12+F_,RST,OCT*12+F_,RST+2,OCT*12+C_,RST,OCT*12+C_,RST+2,OCT*12+D_,RST,SIL
.byt OCT*12+D_,RST+2,OCT*12+D_,RST,OCT*12+D_,RST+2,OCT*12+D_,RST,OCT*12+D_,RST+2,SIL
*/

.byt OCT*12+F_,OCT*12+F_,OCT*12+F_,RST,OCT*12+F_,RST,OCT*12+G_,OCT*12+G_,OCT*12+C_,RST,OCT*12+C_,RST,OCT*12+D_,OCT*12+D_,OCT*12+D_,RST,SIL
.byt OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,SIL

.byt END

bm_synth1
.byt OCT*12+F_,RST,OCT*12+F_,RST,OCT*12+F_,OCT*12+G_,OCT*12+G_,RST,OCT*12+C_,RST,OCT*12+C_,OCT*12+C_,OCT*12+C_,RST,OCT*12+D_,RST
.byt OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,OCT*12+D_,RST,OCT*12+D_,RST,OCT*12+D_,OCT*12+D_,SIL

.byt END

bm_wait
.byt RST+15,RST+15,END

bm_main0
.byt OCTM*12+F_,RST,OCTM*12+F_,OCTM*12+F_,OCTM*12+F_,OCTM*12+F_,OCTM*12+F_,OCTM*12+C_,SIL,RST+1,OCTM*12+C_,OCTM*12+C_,OCTM*12+C_,RST,OCTM*12+C_,OCTM*12+C_
.byt OCTM*12+D_,RST,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,SIL,RST+1,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,RST,OCTM*12+D_,OCTM*12+D_
.byt OCTM*12+G_,RST,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,SIL,RST+1,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,RST,OCTM*12+G_,OCTM*12+G_
.byt OCTM*12+D_,RST,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,SIL,RST+1,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,RST,OCTM*12+D_,OCTM*12+D_

/*
.byt OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,RST+3,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_
.byt OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,RST+3,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_,OCTM*12+G_
.byt OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,RST+3,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_,OCTM*12+D_
*/
.byt END

bm_main1
.byt END



__BlueMonday_end

_PlayBM
.(
	lda #<__BlueMonday_start
	sta tmp
	lda #>__BlueMonday_start
	sta tmp+1
	jmp _PlaySong
.)




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;For instrument testing

__Instrument_testing_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 15
.byt <itpattern_list_lo,>itpattern_list_lo,<itpattern_list_hi,>itpattern_list_hi
.byt <_TuneAA, >_TuneAA, <_TuneAB, >_TuneAB, <_TuneAC, >_TuneAC

_TuneAA .byt END
_TuneAB	.byt END
_TuneAC	.byt ORN, 0, ENV, 0, 0, END


itpattern_list_lo 
	.byt <it_pat
itpattern_list_hi 
	.byt >it_pat


it_pat
.byt 36,37,38,39,40,41,42,43,RST
.byt RST,46,RST+1
.byt 36,RST+5,SIL,RST+5,37,RST+5,38,RST+5,39,RST+5,40,RST+5,END

__Instrument_testing_end

_Test
.(
	lda #<__Instrument_testing_start
	sta tmp
	lda #>__Instrument_testing_start
	sta tmp+1
	jmp _PlaySong
.)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Vienna

__Vienna_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 7
.byt <vipattern_list_lo,>vipattern_list_lo,<vipattern_list_hi,>vipattern_list_hi
.byt <_TuneBA, >_TuneBA, <_TuneBB, >_TuneBB, <_TuneBC, >_TuneBC

_TuneBA 	.byt ORN, 2, ENV, 3, SETVOL, 5, 								                2,3, SETVOL,2,ORN, 1,4, 	LOOP,0, END
_TuneBB		.byt ORN, 0, ENV, 3, SETVOL, 7,	NOFFSET,12,											2,3, SETVOL,3,NOFFSET,0,5,	LOOP, 0, END
_TuneBC		.byt ORN, 3, ENV, 4, NVAL, 15, NOFF, 							         		0,1, LOOP, 8, END


vipattern_list_lo 
	.byt <vi_drums0,<vi_drums1,<vi_wait,<vi_main0,<vi_main1,<vi_piano
vipattern_list_hi 
	.byt >vi_drums0,>vi_drums1,>vi_wait,>vi_main0,>vi_main1,>vi_piano

#define OCTM (3)
#define OCTD 1
#define OCT (4)

vi_drums0
.byt SIL,RST+5,OCTD*12+B_,RST
.byt SIL,RST+5,OCTD*12+B_,RST
.byt END
vi_drums1
.byt OCTD*12+B_,OCTD*12+B_,RST,SIL,RST,PNON,OCTD*12+G_,OCTD*12+G_,RST,SIL,RST,PNOFF
.byt OCTD*12+B_,RST,SIL,RST+3,OCTD*12+B_,RST,SIL
.byt END

vi_wait
.byt SIL,RST+7
.byt RST+7
.byt RST+7
.byt RST+7
.byt END

vi_main0
.byt SIL,RST+6,OCTM*12+C_
.byt OCTM*12+E_,RST,OCTM*12+E_,OCTM*12+C_,OCTM*12+F_,RST,OCTM*12+E_,RST+6,SIL
.byt RST+1
.byt RST+7
.byt RST+7
.byt RST+5,OCTM*12+F_,RST
.byt SIL,RST,OCTM*12+F_,RST,OCTM*12+F_,OCTM*12+F_,OCTM*12+F_,OCTM*12+G_,RST
.byt OCTM*12+F_,SIL,RST,OCTM*12+F_,RST+2,OCTM*12+E_,RST
.byt OCTM*12+E_,OCTM*12+C_,OCTM*12+F_,RST,OCTM*12+E_,RST+9,SIL
.byt RST+7
.byt RST+7
.byt (OCTM+1)*12+F_,RST,(OCTM+1)*12+E_,RST,(OCTM+1)*12+C_,RST,(OCTM+1)*12+D_,RST
.byt (OCTM+1)*12+F_,RST,(OCTM+1)*12+E_,RST,(OCTM+1)*12+C_,RST,(OCTM+1)*12+F_,RST+6,SIL
.byt RST+7+1


.byt SIL,RST,OCTM*12+F_,RST,OCTM*12+F_,OCTM*12+F_,OCTM*12+F_,OCTM*12+G_,RST
.byt OCTM*12+F_,SIL,RST,OCTM*12+F_,RST+2,OCTM*12+G_,RST
.byt OCTM*12+G_,(OCTM)*12+A_,OCTM*12+G_,RST,OCTM*12+G_,RST+9,SIL
.byt RST+7
.byt RST+7
.byt (OCTM+1)*12+F_,RST,(OCTM+1)*12+E_,RST,(OCTM+1)*12+C_,RST,(OCTM+1)*12+D_,RST
.byt (OCTM+1)*12+F_,RST,(OCTM+1)*12+E_,RST,(OCTM+1)*12+C_,RST,(OCTM+1)*12+D_,RST+6
.byt SIL,RST+7+2

.byt END

vi_main1
.byt (OCTM+1)*12+AS_,RST,(OCTM+1)*12+AS_,RST,(OCTM+1)*12+A_,(OCTM+1)*12+A_,(OCTM+1)*12+G_,(OCTM+1)*12+G_,RST
.byt (OCTM+1)*12+G_,RST,(OCTM+1)*12+F_,RST,(OCTM+1)*12+F_,(OCTM+1)*12+G_,(OCTM+1)*12+G_
.byt RST,(OCTM+1)*12+G_,RST,(OCTM+1)*12+F_,RST,(OCTM+1)*12+E_,(OCTM+1)*12+F_,RST+14
;.byt RST+7+6
.byt (OCTM+1)*12+G_,(OCTM+1)*12+G_
.byt RST,(OCTM+1)*12+G_,RST,(OCTM+1)*12+F_,RST,(OCTM+1)*12+E_,(OCTM+1)*12+F_,RST+8+4,SIL
.byt RST+7
.byt /*RST+3,*/(OCTM+1)*12+G_,RST+2,(OCTM+1)*12+A_,RST
.byt (OCTM+1)*12+G_,RST,(OCTM+1)*12+F_,RST+13,SIL
;.byt RST+7
.byt END

vi_piano
.byt RST+15,RST+7+2
.byt (OCT)*12+AS_,RST+2,(OCT)*12+G_,RST+2,(OCT)*12+A_,RST+2,(OCT)*12+F_,(OCT)*12+G_,(OCT)*12+A_
.byt (OCT)*12+AS_,RST+2,(OCT)*12+G_,RST+2,(OCT)*12+A_,RST+2,(OCT)*12+F_,(OCT)*12+G_,(OCT)*12+A_
.byt (OCT)*12+AS_,RST+2,(OCT)*12+G_,RST+2,(OCT)*12+A_,RST+2,(OCT)*12+F_,(OCT)*12+G_,(OCT)*12+A_
.byt SIL,RST+4
;.byt (OCT)*12+AS_,RST+2,(OCT)*12+G_,RST+2,(OCT)*12+AS_,RST+2,(OCT)*12+G_,(OCT)*12+AS_,(OCT)*12+A_,SIL,RST+14
.byt RST+14
.byt END

__Vienna_end

_PlayVienna
.(
	lda #<__Vienna_start
	sta tmp
	lda #>__Vienna_start
	sta tmp+1
	jmp _PlaySong
.)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Blake's 7
//#define ORIGINAL 
#ifdef ORIGINAL
__Blake_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 8-1
.byt <Blpattern_list_lo,>Blpattern_list_lo,<Blpattern_list_hi,>Blpattern_list_hi
.byt <_TuneCA, >_TuneCA, <_TuneCB, >_TuneCB, <_TuneCC, >_TuneCC

_TuneCA 	.byt ORN, 1, ENV, 3, SETVOL, 0, 3, ORN, 1, ENV, 3, SETVOL, 3, 2, LOOP,0, END
_TuneCB		.byt ORN, 0, ENV, 3, SETVOL, 3, 1, LOOP,0, END
_TuneCC		.byt ORN, 0, ENV, 5, SETVOL, 0, 0, LOOP,0, END


Blpattern_list_lo 
	.byt <Bl_main0,<Bl_main1,<Bl_main2,<Bl_init2
Blpattern_list_hi 
	.byt >Bl_main0,>Bl_main1,>Bl_main2,>Bl_init2

#define OCTM (4)
#define OCTM1 (OCTM-1)
#define OCTD 1
#define OCT (OCTM+1)

Bl_main0
.byt (OCTM1-1)*12+G_,RST+4,OCTM1*12+G_,OCTM1*12+G_
.byt OCTM1*12+F_,RST,OCTM1*12+E_,RST,(OCTM1)*12+D_,RST,(OCTM1)*12+C_,RST
.byt (OCTM1-1)*12+B_,RST+6+8
;.byt SIL,RST+7

.byt (OCTM1-1)*12+A_,RST+4,(OCTM1)*12+A_,(OCTM1)*12+A_
.byt (OCTM1)*12+G_,RST,(OCTM1)*12+F_,RST,(OCTM1)*12+E_,RST,(OCTM1)*12+D_,RST
.byt (OCTM1)*12+DS_,RST+6+8
;.byt SIL,RST+7

.byt (OCTM1)*12+GS_,RST+6+6,SIL,RST+1
;***
.byt (OCTM1)*12+G_,RST+6

; Melody starts here...
.byt (OCTM-1)*12+G_,RST,(OCTM)*12+CS_,RST,(OCTM)*12+D_,RST+2
.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM)*12+E_,RST+2+4



; Pag 2, bar 16

.byt /*SIL,RST+3,*/(OCTM)*12+C_,RST,(OCTM)*12+D_,RST
.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM-1)*12+B_,RST+2+4
.byt /*SIL,RST+3,*/(OCTM)*12+C_,RST,(OCTM)*12+D_,RST

.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM)*12+E_,RST+2+4
.byt /*SIL,RST+3,*/(OCTM)*12+G_,RST,(OCTM)*12+F_,RST
.byt (OCTM)*12+E_,RST+1,(OCTM)*12+D_,RST,(OCTM-1)*12+B_,RST+1+4+4


;.byt SIL,RST+3
.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM)*12+E_,RST+2+4
.byt /*SIL, RST+3,*/ (OCTM)*12+D_,(OCTM)*12+E_,(OCTM)*12+G_,(OCTM)*12+F_


; Pag 3, bar 25

.byt (OCTM)*12+D_,RST+2, (OCTM)*12+D_, (OCTM-1)*12+A_, RST+1+8
;.byt SIL,RST+7
.byt (OCTM)*12+E_,RST+2, (OCTM)*12+D_,RST, (OCTM)*12+D_, RST+2

.byt /*SIL,RST+1,*/ (OCTM)*12+F_,RST, (OCTM)*12+E_,RST+2
.byt (OCTM)*12+D_,RST, (OCTM)*12+C_,RST, (OCTM)*12+C_,RST+2
.byt (OCTM)*12+D_,RST,(OCTM)*12+DS_,RST+2,(OCTM)*12+D_,RST

.byt (OCTM)*12+D_,RST,(OCTM-1)*12+B_,RST,(OCTM)*12+C_,RST+2
.byt (OCTM)*12+D_,RST,(OCTM-1)*12+B_,RST,(OCTM)*12+C_,RST+2
.byt (OCTM)*12+C_,RST+6
; Falta Silencio negra+corchea

.byt END

Bl_main1
.byt (OCTM1-2)*12+G_,RST+4,(OCTM1)*12+E_,(OCTM1)*12+E_
.byt OCTM1*12+D_,RST,OCTM1*12+C_,RST,(OCTM1-1)*12+B_,RST,(OCTM1-1)*12+A_,RST
.byt (OCTM1-1)*12+G_,RST+6
.byt SIL,RST+7

.byt (OCTM1-1)*12+F_,RST+4,(OCTM1)*12+F_,(OCTM1)*12+F_
.byt (OCTM1)*12+E_,RST,(OCTM1)*12+D_,RST,(OCTM1)*12+C_,RST,(OCTM1-1)*12+A_,RST
.byt (OCTM1-1)*12+DS_,RST+6
.byt SIL,RST+7

.byt (OCTM-1)*12+D_,RST+3, (OCTM-1)*12+GS_,RST,(OCTM-1)*12+GS_
.byt (OCTM-1)*12+G_,RST,(OCTM-1)*12+F_,RST,(OCTM-1)*12+E_,RST,(OCTM-1)*12+F_,RST
;.byt (OCTM)*12+CS_,RST+6
.byt (OCTM-1)*12+G_,RST+6

; Melody starts here...
.byt (OCTM-2)*12+G_,RST,(OCTM-1)*12+CS_,RST,(OCTM-1)*12+D_,RST+2
.byt (OCTM-1)*12+F_,RST+1,(OCTM-1)*12+E_,(OCTM-1)*12+E_,RST+2
; Pag 2, bar 16

.byt SIL,RST+7
.byt (OCTM-1)*12+E_,RST+6+8
;.byt SIL,RST+7


.byt (OCTM-1)*12+F_,RST+1,(OCTM-1)*12+E_,(OCTM-1)*12+E_,RST+2+8
;.byt RST+7
.byt (OCTM-1)*12+E_,RST+1,(OCTM-1)*12+D_,RST,(OCTM-2)*12+B_,RST+1+4


.byt SIL,RST+3
.byt (OCTM-1)*12+E_,RST+6+7
.byt SIL,RST/*+7*/

; Pag 3, bar 25

.byt (OCTM-1)*12+D_,RST+6+7
.byt SIL,RST
.byt (OCTM-1)*12+D_,RST+6+7

.byt SIL,RST/*+7*/
.byt (OCTM-1)*12+D_,RST, SIL, RST, (OCTM-1)*12+C_,RST+3+7
.byt SIL,RST/*+7*/

.byt (OCTM-1)*12+D_,RST+6
.byt (OCTM-2)*12+B_,RST+6
.byt (OCTM-1)*12+C_,RST+6

; Falta silencio negra

.byt END

Bl_init2
.byt (OCTM1-1)*12+G_,RST+6+8
.byt (OCTM1-2)*12+FS_,RST
.byt (OCT)*12+GS_,(OCT)*12+G_,(OCT)*12+F_,RST+1,(OCT)*12+DS_
.byt (OCT)*12+CS_,RST,(OCT)*12+CS_,(OCT)*12+C_,(OCT-1)*12+B_,RST+2

.byt (OCTM1-1)*12+F_,RST+6+8
.byt SIL,RST+1
.byt (OCT)*12+DS_,(OCT)*12+D_,(OCT)*12+C_,RST+1,(OCT-1)*12+AS_
.byt (OCT-1)*12+A_,RST,(OCT-1)*12+A_,(OCT-1)*12+G_,(OCT-1)*12+FS_,RST+2
.byt END

Bl_main2
.byt (OCTM-1)*12+GS_,RST+3, (OCTM-1)*12+GS_,RST,(OCTM-1)*12+GS_
.byt (OCTM-1)*12+GS_,RST,(OCTM-1)*12+GS_,RST,(OCTM-1)*12+GS_,RST,(OCTM-1)*12+GS_,RST
.byt (OCTM-1)*12+G_,RST+6+8
;.byt SIL,RST+7
.byt (OCTM-1)*12+G_,RST+6+8

; Pag 2, bar 16
;.byt SIL, RST+7
.byt (OCTM-1)*12+E_,RST+6+8
;.byt SIL, RST+7

.byt (OCTM-1)*12+A_,RST+2, (OCTM-1+1)*12+E_,RST+2+8
;.byt SIL, RST+7
.byt (OCTM-1)*12+GS_,RST+2, (OCTM-1+1)*12+E_,RST+2+8

;.byt SIL, RST+7
.byt (OCTM-1)*12+G_,RST+6+8
;.byt SIL, RST+7

; Page 3, bar 25

.byt (OCTM-1)*12+F_,RST+6+8
;.byt SIL, RST+7
.byt (OCTM-1)*12+F_,RST+6+8

;.byt SIL, RST+7
.byt (OCTM-1+1)*12+C_,RST+6
.byt (OCTM-1)*12+B_,RST+6

.byt (OCTM-1+1)*12+D_,RST+6
.byt (OCTM-1)*12+B_,RST+6
.byt (OCTM-1+1)*12+C_,RST+6

.byt END

__Blake_end
#else

__Blake_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 8
.byt <Blpattern_list_lo,>Blpattern_list_lo,<Blpattern_list_hi,>Blpattern_list_hi
.byt <_TuneCA, >_TuneCA, <_TuneCB, >_TuneCB, <_TuneCC, >_TuneCC

_TuneCA 	.byt ORN, 1, ENV, 4, NVAL,0, 4,2,2,2,2,2,2,2,3,2,2,3,2,4,4,4,4,4,4,4,  LOOP,0, END
_TuneCB		.byt ORN, 0, ENV, 6, SETVOL, 1, 1, LOOP,0, END
_TuneCC		.byt ORN, 1, ENV, 0, 0, LOOP,0, END


Blpattern_list_lo
	.byt <Bl_main0,<Bl_main1,<Bl_drums,<Bl_drums2,<Bl_pause
Blpattern_list_hi
	.byt >Bl_main0,>Bl_main1,>Bl_drums,>Bl_drums,>Bl_pause

#define OCTM (4)
#define OCTM2 (OCTM-2)
#define OCTD 1
#define OCT (OCTM+1)

Bl_main0

; Melody starts here...
.byt (OCTM-1)*12+G_,RST,(OCTM)*12+CS_,RST,(OCTM)*12+D_,RST+2
.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM)*12+E_,RST+2+4



; Pag 2, bar 16

.byt (OCTM)*12+C_,RST,(OCTM)*12+D_,RST
.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM-1)*12+B_,RST+2+4
.byt (OCTM)*12+C_,RST,(OCTM)*12+D_,RST

.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM)*12+E_,RST+2+4
.byt (OCTM)*12+G_,RST,(OCTM)*12+F_,RST
/**********************/
.byt (OCTM)*12+E_,RST+1,(OCTM)*12+D_,(OCTM-1)*12+B_,RST+2+4+4


.byt (OCTM)*12+F_,RST+1,(OCTM)*12+E_,(OCTM)*12+E_,RST+2+4
.byt (OCTM)*12+D_,(OCTM)*12+E_,(OCTM)*12+G_,(OCTM)*12+F_


; Pag 3, bar 25

.byt (OCTM)*12+D_,RST+2, (OCTM)*12+D_, (OCTM-1)*12+A_, RST+8+1
.byt (OCTM)*12+E_,RST+2, (OCTM)*12+D_,RST, (OCTM)*12+D_, RST+2
.byt (OCTM)*12+F_,RST, (OCTM)*12+E_,RST+2

.byt (OCTM)*12+D_,RST, (OCTM)*12+C_,RST, (OCTM)*12+C_,RST+2
.byt (OCTM)*12+D_,RST,(OCTM)*12+DS_,RST+2,(OCTM)*12+D_,RST

.byt (OCTM)*12+D_,RST,(OCTM-1)*12+B_,RST,(OCTM)*12+C_,RST+2
.byt (OCTM)*12+D_,RST,(OCTM-1)*12+B_,RST,(OCTM)*12+C_,RST+2
.byt (OCTM)*12+C_,RST+6
; Falta Silencio negra+corchea

.byt END

Bl_main1

; Melody starts here...
.byt (OCTM2-1)*12+G_,RST,(OCTM2)*12+CS_,RST,(OCTM2)*12+D_,RST+2
.byt (OCTM2)*12+F_,RST+1,(OCTM2)*12+E_,(OCTM2)*12+E_,RST+2+8
; Pag 2, bar 16
.byt (OCTM2)*12+E_,RST+6+8
.byt (OCTM2)*12+F_,RST+1,(OCTM2)*12+E_,(OCTM2)*12+E_,RST+2+8
.byt (OCTM2)*12+E_,RST+1,(OCTM2)*12+D_,RST,(OCTM2-1)*12+B_,RST+1+4

.byt SIL,RST+3
.byt (OCTM2)*12+E_,RST+6+7
.byt SIL,RST/*+7*/

; Pag 3, bar 25

.byt (OCTM2)*12+D_,RST+6+7
.byt SIL,RST
.byt (OCTM2)*12+D_,RST+6+7

.byt SIL,RST/*+7*/
.byt (OCTM2)*12+D_,RST, SIL, RST, (OCTM2)*12+C_,RST+3+7
.byt SIL,RST/*+7*/

.byt (OCTM2)*12+D_,RST+6
.byt (OCTM2-1)*12+B_,RST+6
.byt (OCTM2)*12+C_,RST+6

; Falta silencio negra

.byt END

#define OCTD 2
Bl_drums
;.byt OCTD*12+C_,RST,PNON,OCTD*12+E_,RST,PNOFF,OCTD*12+C_,RST,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,RST,OCTD*12+C_,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,OCTD*12+C_,RST,PNON,OCTD*12+E_,RST,PNOFF
;.byt PNON,OCTD*12+E_,RST,PNOFF,SIL,RST+1,OCTD*12+C_,RST,OCTD*12+C_,RST
.byt PNON,OCTD*12+F_,RST+1,PNOFF,SIL,RST
;.byt PNON,OCTD*12+F_,RST+1,PNOFF,SIL,RST
.byt OCTD*12+C_,RST,OCTD*12+C_,RST
.byt END

Bl_drums2
;.byt OCTD*12+C_,RST,PNON,OCTD*12+E_,RST,PNOFF,OCTD*12+C_,RST,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,RST,OCTD*12+C_,PNON,OCTD*12+E_,PNOFF,OCTD*12+C_,OCTD*12+C_,RST,PNON,OCTD*12+E_,RST,PNOFF
.byt OCTD*12+C_,RST,OCTD*12+C_,RST,OCTD*12+C_,OCTD*12+C_,OCTD*12+C_,RST
.byt END

Bl_pause
.byt SIL,RST+7
.byt END

__Blake_end
#endif

_PlayBlake
.(
	lda #<__Blake_start
	sta tmp
	lda #>__Blake_start
	sta tmp+1
	jmp _PlaySong
.)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Blake's 7: Federation March
__Blake2_start
; Header: Tempo, pointers to patterns and pointers to pattern lists
.byt 10
.byt <Bl2pattern_list_lo,>Bl2pattern_list_lo,<Bl2pattern_list_hi,>Bl2pattern_list_hi
.byt <_TuneDA, >_TuneDA, <_TuneDB, >_TuneDB, <_TuneDC, >_TuneDC

_TuneDA 	.byt ORN, 1, ENV, 6, SETVOL, 1, 0, 3, LOOP,0, END
_TuneDB		.byt ORN, 0, ENV, 4, SETVOL, 0, 2, LOOP,0, END ; Drums
_TuneDC		.byt ORN, 0, ENV, 4, SETVOL, 0, 1, LOOP,0, END ; Drums


Bl2pattern_list_lo 
	.byt <Bl2_main,<Bl2_perc0,<Bl2_perc1,<B12_main2
Bl2pattern_list_hi 
	.byt >Bl2_main,>Bl2_perc0,>Bl2_perc1,>B12_main2

#define OCTM (4)
#define OCTD 2
#define OCTD2 (OCTD-0)

Bl2_main
.byt RST+7

.byt (OCTM-2)*12+C_,RST+5-1, (OCTM-2)*12+CS_,RST
.byt (OCTM-2)*12+FS_,/*RST,*/(OCTM-2)*12+F_,/*RST+2,*/(OCTM-2)*12+E_,RST+2,(OCTM+1)*12+B_,(OCTM+1)*12+F_
.byt (OCTM+1)*12+A_,RST,OCTM*12+B_,OCTM*12+F_,OCTM*12+A_,RST,(OCTM-1)*12+B_,(OCTM-1)*12+F_
.byt (OCTM-1)*12+A_,RST+6

;.byt RST+7
.byt RST+7
.byt (OCTM-2)*12+D_,RST+5-1, (OCTM-2)*12+DS_,RST
.byt (OCTM-1)*12+A_,/*RST,*/(OCTM-2)*12+GS_,/*RST+2,*/(OCTM-2)*12+FS_,RST+4
;.byt ((OCTM+1)-1)*12+B_,RST+3, SIL+3
;.byt RST+7

.byt RST+7
.byt (OCTM+1)*12+DS_,(OCTM+1)*12+E_,RST+1,(OCTM+1)*12+F_,RST+2
.byt ((OCTM+1)-2)*12+B_,((OCTM+1)-1)*12+C_,RST+1,((OCTM+1)-1)*12+CS_,RST+2

.byt RST+7
.byt (OCTM-2)*12+C_,RST+5-1, (OCTM-2)*12+CS_,RST
.byt (OCTM-2)*12+FS_,/*RST,*/(OCTM-2)*12+F_,/*RST+2,*/(OCTM-2)*12+E_,RST+4

.byt END

B12_main2
.byt RST+4, (OCTM+2)*12+FS_,(OCTM+2)*12+CS_,RST
.byt RST, (OCTM+1)*12+FS_,(OCTM+1)*12+CS_,RST,(OCTM)*12+FS_,(OCTM)*12+CS_,RST+1

.byt RST+7
.byt RST+7
.byt (OCTM)*12+CS_,(OCTM)*12+A_,(OCTM)*12+CS_,(OCTM-1)*12+B_,RST+3
.byt (OCTM)*12+CS_,(OCTM-1)*12+F_,RST+5

.byt RST+7



.byt END

Bl2_perc0
.byt (OCTD*12)+A_,RST,RST+1,(OCTD*12)+A_,RST,RST+1
.byt END

Bl2_perc1
.byt (OCTD2)*12+F_,RST,RST+1,(OCTD2)*12+F_,RST,RST+1
.byt END


__Blake2_end

_PlayBlake2
.(
	lda #<__Blake2_start
	sta tmp
	lda #>__Blake2_start
	sta tmp+1
	jmp _PlaySong
.)

