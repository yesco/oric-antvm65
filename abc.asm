;.include "ant-abc.asm"

; === Global Music State (Initialize at top) ===
M_OCT  = 4
M_LEN  = 4
M_ACC  = 0
M_VOL  = 12
M_TMP  = 120

.macro NOTE Arg, _p, _o, _n

    .if _p < .strlen(Arg)
        .local @c
        @c = .strat(Arg, _p)
        
        .byte 00,@c

        ABC Arg, (_p+1), _o

    .else
        .exitmacro
    .endif

.endmacro

.macro ABC Arg, Pos, Oct
    ; Setup position pointer
    .ifblank Pos
        _p .set 0
        .byte "data"
    .else
        _p .set Pos
    .endif

    .ifblank Oct
        _o .set M_OCT
    .else
        _o .set Oct
    .endif

    .if _p < .strlen(Arg)
        .local @c, @nc, @nv, @toct, @arg
        @c = .strat(Arg, _p)
        
;        .byte @c

        ; --- COMMANDS (O, L, V, T, W, E, S) ---
        .if @c = 'O' || @c = 'o' || @c = 'K'
            M_OCT := (.strat(Arg, _p + 1) - '0')
            ABC Arg, (_p + 2)
        .elseif @c = 'L'
            M_LEN := (.strat(Arg, _p + 1) - '0')
            ABC Arg, (_p + 2)
        .elseif @c = 'V' || @c = 'v'
            M_VOL := (.strat(Arg, _p + 1) - '0')
            ABC Arg, (_p + 2)
        .elseif @c = 'T'
            ; TODO: Handle multi-digit tempo
            ABC Arg, (_p + 2)
        .elseif @c = 'W' || @c = 'N'
            ; TODO: Mixer logic
            ABC Arg, (_p + 2)
        .elseif @c = 'E'
            ; TODO: Envelope logic
            ABC Arg, (_p + 2)
        .elseif @c = 'S'
            .byte $FE ; Stop code
            ABC Arg, (_p + 1)
        .elseif @c = '^' || @c = '_' || (@c >= 'A' && @c <= 'H') || (@c >= 'a' && @c <= 'h') || @c = 'R' || @c = 'P' || @c = 'r' || @c = 'p'
            NOTE Arg, _p, _o, 0
        .elseif
            ;; Skip spaces or unknown chars
            ABC Arg, (_p + 1)
        .endif
    .else
        .exitmacro
    .endif
.endmacro ; ABC



ABC "ABCDEFGH"

;GEN_ABC_SPN "HAGFEDC"
;GEN_ABC_SPN "BAGFEDC"

.end

.macro NOTE Arg, _p, _o, _n

    .if _p >= .strlen(Arg)
        ABC Arg, (_p+1)
    .else
        .local @c
        @c = .strat(Arg, _p)
        
        .if @c = '^'
            NOTE Arg, (_p+1), (_n+2)
        .elseif @c= '_'
            NOTE Arg, (_p+1), (_n-2)
;        .elseif @nc = 'C'
;            NOTE Arg, (_p+1), (_n+0)
        .elseif @nc = 'D'
            NOTE Arg, (_p+1), (_n+2)
        .elseif @nc = 'E'
            NOTE Arg, (_p+1), (_n+4)
        .elseif @nc = 'F'
            NOTE Arg, (_p+1), (_n+10)
        .elseif @nc = 'G'
            NOTE Arg, (_p+1), (_n+14)
        .elseif @nc = 'A'
            NOTE Arg, (_p+1), (_n+18)
        .elseif @nc = 'H' || @nc = 'B'
            NOTE Arg, (_p+1), (_n+22)
        .elseif @nc = 'z' || @nc = 'R' || @nc = 'P'
            NOTE ARG, (_p+1), $FF ; Rest
        .endif

     .endif

.endmacro
