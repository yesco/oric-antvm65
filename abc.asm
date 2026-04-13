;;; 
;;; Testing:
;;; 
;;; >   ca65 -t sim6502 abc.asm -l abc.lst && cat abc.lst
;;; 



.listbytes unlimited

;.include "ant-abc.asm"

;;; ABC-notation equivalence:
;;; 
;;; V:1
;;; U: p = +1quartertone
;;; U: m = -1quartertone

; === Global Music State (Initialize at top) ===
M_OCT  = 4
M_LEN  = 4
M_ACC  = 0
M_VOL  = 12
M_TMP  = 120

.macro POSTNOTE Arg, _p, _o, _n

    .if _p >= .strlen(Arg)
        ;; AT END: gen
        .byte _p,00,00,_n*8 + _o

        .exitmacro
    .endif


   ;; MODIFY
    .local @c
    @c = .strat(Arg, _p)

    .if @c = '#'
        POSTNOTE Arg, (_p+1), _o, (_n+2)
    .elseif @c = 'b'
        POSTNOTE Arg, (_p+1), _o, (_n-2)
    .elseif @c = 'm'
        POSTNOTE Arg, (_p+1), _o, (_n-1)
    .elseif @c = 'p'
        POSTNOTE Arg, (_p+1), _o, (_n+1)

    .elseif @c = '0' || @c = '1' || @c = '2'
        POSTNOTE Arg, (_p+1), (@c-'0'), _n
    .else
        .byte _p,00,00,_n*8 + _o
        ;; Garbage? new note?
        ABC Arg, _p
    .endif
    
.endmacro ; POSTNOTE



.macro NOTE Arg, _p, _o, _n

    .if _p >= .strlen(Arg)
        ;; AT END: gen
        .byte _p,00,00,_n*8 + _o

        .exitmacro
    .endif


   ;; COMMANDS
    .local @c
    @c = .strat(Arg, _p)

    .if @c = '^'
        NOTE Arg, (_p+1), _o, (_n+2)
    .elseif @c= '_'
        NOTE Arg, (_p+1), _o, (_n-2)

    .elseif @c = '''
        NOTE Arg, (_p+1), (_o+1), _n
    .elseif @c = ','
        NOTE Arg, (_p+1), (_o-1), _n

    ;; NOTES
    .elseif @c = 'C'
        POSTNOTE Arg, (_p+1), _o, (_n+0)
    .elseif @c = 'D'
        POSTNOTE Arg, (_p+1), _o, (_n+4)
    .elseif @c = 'E'
        POSTNOTE Arg, (_p+1), _o, (_n+8)
    .elseif @c = 'F'
        POSTNOTE Arg, (_p+1), _o, (_n+10)
    .elseif @c = 'G'
        POSTNOTE Arg, (_p+1), _o, (_n+14)
    .elseif @c = 'A'
        POSTNOTE Arg, (_p+1), _o, (_n+18)
    .elseif @c = 'H' || @c = 'B'
        POSTNOTE Arg, (_p+1), _o, (_n+22)

    ;; NOTES
    .elseif @c = 'c'
        POSTNOTE Arg, (_p+1), (_o+1), (_n+0)
    .elseif @c = 'd'
        POSTNOTE Arg, (_p+1), (_o+1), (_n+4)
    .elseif @c = 'e'
        POSTNOTE Arg, (_p+1), (_o+1), (_n+8)
    .elseif @c = 'f'
        POSTNOTE Arg, (_p+1), (_o+1), (_n+10)
    .elseif @c = 'g'
        POSTNOTE Arg, (_p+1), (_o+1), (_n+14)
    .elseif @c = 'a'
        POSTNOTE Arg, (_p+1), (_o+1), (_n+18)
    .elseif @c = 'h' || @c = 'b'
        POSTNOTE Arg, (_p+1), (_o+1), (_n+22)

    ;; REST
    .elseif @c = 'z' || @c = 'R' || @c = 'Z' || @c = 'r'
        POSTNOTE ARG, (_p+1), $FF, $FF ; Rest
    ;; else: gen
    .else
        ;; AT END: gen
        .byte _p,00,00,_n*8 + _o

        ;; assume a new note coming, or new ABC
         ABC Arg, (_p+1)
    .endif

.endmacro ; NOTE



.macro ABC Arg, Pos, Oct

    ; Setup position pointer
    .ifblank Pos
        _p .set 0
    .else
        _p .set Pos
    .endif

    ; The end is nigh 
    .if _p >= .strlen(Arg)
        .exitmacro
    .endif


    .ifblank Oct
        _o .set M_OCT
    .else
        _o .set Oct
    .endif


    .local @c
    @c = .strat(Arg, _p)

;;; err
;    .if @c = '^' || @c = '_' || (@c >= 'A' && @c <= 'H') || (@c >= 'a' && @c <= 'h') || @c = 'R' || @c = 'P' || @c = 'r' || @c = 'p'
;;; ok
;    .if @c = '^' || @c = '_'

    .if @c = '^'  || @c = 'A'
        NOTE Arg, _p, _o, 0
        .exitmacro
    .endif

    ; --- COMMANDS (O, L, V, T, W, E, S) ---
    .if @c = 'O' || @c = 'o' || @c = 'K'
        ;; o0 -- o7 K:0 -- K:7
        ;; TODO: K:3
        M_OCT := (.strat(Arg, _p + 1) - '0')
        ABC Arg, (_p + 2)

    .elseif @c = 'L'
        ;; Gives 1,2,4,8,1(6),3(2),6(4)
        ;; TODO: 16 is not distinguaishable
        M_LEN := (.strat(Arg, _p + 1) - '0') ;
        ABC Arg, (_p + 2)

    .elseif @c = 'V' || @c = 'v'
        M_VOL := (.strat(Arg, _p + 1) - '0')
        ABC Arg, (_p + 2)

    .elseif @c = 'T'
        ; TODO: Handle multi-digit tempo
        ABC Arg, (_p + 2)

    .elseif @c = 'W' || @c = 'N'
        ; TODO: Mixer logic 0 1 2 3
        ABC Arg, (_p + 2)
    .elseif @c = 'E'
        ; TODO: Envelope logic
        ABC Arg, (_p + 2)

    .elseif @c = 'S'
        .byte $FE ; Stop code
        ABC Arg, (_p + 1)
    .else 
        NOTE Arg, _p, M_OCT, 0
        ;; Skip spaces or unknown chars
        ;; TODO: give error (but no good context?)
;        ABC Arg, (_p + 1)
    .endif

.endmacro ; ABC



;ABC "ABCDEFGH ABCDEFGH"
NOTE "C", 0, 4, 0
NOTE "C#", 0, 4, 0
NOTE "Db", 0, 4, 0
NOTE "D", 0, 4, 0
NOTE "D#", 0, 4, 0
NOTE "Eb", 0, 4, 0
NOTE "E", 0, 4, 0
NOTE "F", 0, 4, 0
NOTE "F#", 0, 4, 0
NOTE "Gb", 0, 4, 0
NOTE "G", 0, 4, 0
NOTE "G#", 0, 4, 0
NOTE "A", 0, 4, 0
NOTE "A#", 0, 4, 0
NOTE "Hb", 0, 4, 0
NOTE "Bb", 0, 4, 0
NOTE "H", 0, 4, 0
NOTE "B", 0, 4, 0
NOTE "Bpm", 0, 4, 0

ABC "CC"
ABC "CC#DbD#EbEFF#"
ABC "F#GbGG#AA#BbA"
;;; Max-len: too manyh tested IFs!
ABC "CC#DbD#EbEFF#GbGG#AA#BbA"
;;;  123456789012345 = 15 notes max?
ABC "AAAAAAAAAAAAAAA"
ABC "AAAAAAA     "              ; lol spaces take more "IFs"

;ABC "CC#DbDD#EbEFF#GbGG#AA#HbBbHBBpm"

;GEN_ABC_SPN "HAGFEDC"
;GEN_ABC_SPN "BAGFEDC"

.end
