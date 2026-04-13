;;; TODO: not working, an almost working prototype 
;;;   in abc.asm  !




; === Global Music State (Initialize at top) ===
M_OCT  = 4
M_LEN  = 4
M_ACC  = 0
M_VOL  = 12
M_TMP  = 120

.macro GEN_ABC_SPN Arg, Pos
    ; Setup position pointer
    .ifblank Pos
        _p .set 0
    .else
        _p .set Pos
    .endif

    .if _p < .strlen(Arg)
        .local @c, @nc, @nv, @toct, @arg
        @c = .strat(Arg, _p)

        ; --- 1. ACCIDENTALS (Prefix) ---
        .if @c = '^'
            M_ACC := 1
            GEN_ABC_SPN Arg, (_p + 1)
        .elseif @c = '_'
            M_ACC := -1
            GEN_ABC_SPN Arg, (_p + 1)

        ; --- 2. NOTES (A-H, a-h, z, R, P) ---
        .elseif (@c >= 'A' && @c <= 'H') || (@c >= 'a' && @c <= 'h') || @c = 'z' || @c = 'R' || @c = 'P'
            @nc = @c
            @toct = M_OCT
            
            .if @nc >= 'a' && @nc <= 'h'
                @toct = M_OCT + 1
                @nc = @nc - 32
            .endif

            @nv = 0
            .if @nc = 'C'
                @nv = 0
            .elseif @nc = 'D'
                @nv = 2
            .elseif @nc = 'E'
                @nv = 4
            .elseif @nc = 'F'
                @nv = 5
            .elseif @nc = 'G'
                @nv = 7
            .elseif @nc = 'A'
                @nv = 9
            .elseif @nc = 'H' || @nc = 'B'
                @nv = 11
            .elseif @nc = 'z' || @nc = 'R' || @nc = 'P'
                @nv = $FF ; Rest
            .endif

            ; TODO: Look-ahead for ' , / and digits
            .byte (@toct * 12) + @nv + M_ACC
            M_ACC := 0
            GEN_ABC_SPN Arg, (_p + 1)

        ; --- 3. COMMANDS (O, L, V, T, W, E, S) ---
        .elseif @c = 'O' || @c = 'o' || @c = 'K'
            M_OCT := (.strat(Arg, _p + 1) - '0')
            GEN_ABC_SPN Arg, (_p + 2)
        .elseif @c = 'L'
            M_LEN := (.strat(Arg, _p + 1) - '0')
            GEN_ABC_SPN Arg, (_p + 2)
        .elseif @c = 'V' || @c = 'v'
            M_VOL := (.strat(Arg, _p + 1) - '0')
            GEN_ABC_SPN Arg, (_p + 2)
        .elseif @c = 'T'
            ; TODO: Handle multi-digit tempo
            GEN_ABC_SPN Arg, (_p + 2)
        .elseif @c = 'W' || @c = 'N'
            ; TODO: Mixer logic
            GEN_ABC_SPN Arg, (_p + 2)
        .elseif @c = 'E'
            ; TODO: Envelope logic
            GEN_ABC_SPN Arg, (_p + 2)
        .elseif @c = 'S'
            .byte $FE ; Stop code
            GEN_ABC_SPN Arg, (_p + 1)
        .else
            ; Skip spaces or unknown chars
            GEN_ABC_SPN Arg, (_p + 1)
        .endif
    .endif
.endmacro



.macro GEN_NOTES Arg
    .local @Char, @Next, @Val
    ; Loop through each character in the string
    .repeat .strlen(Arg), I
        @Char = .strat(Arg, I)
        
        ; Only process if this isn't a '#' (since '#' is handled by the previous note)
        .if @Char <> '#'
            @Val = 0
            
            ; Map the note letter
            .if @Char = 'C' | @Char = 'c'
                @Val = NOTE_C
            .elseif @Char = 'D' | @Char = 'd'
                @Val = NOTE_D
            .elseif @Char = 'E' | @Char = 'e'
                @Val = NOTE_E
            .elseif @Char = 'F' | @Char = 'f'
                @Val = NOTE_F
            .elseif @Char = 'G' | @Char = 'g'
                @Val = NOTE_G
            .elseif @Char = 'A' | @Char = 'a'
                @Val = NOTE_A
            .elseif @Char = 'H' | @Char = 'h'
                @Val = NOTE_H
            .endif

            ; Check if the NEXT character is a sharp '#'
            .if I + 1 < .strlen(Arg)
                @Next = .strat(Arg, I + 1)
                .if @Next = '#'
                    @Val = @Val + 1 ; Shift to the sharp value
                .endif
            .endif

            ; Output the byte if a valid note was found
            .if @Val > 0
                .byte @Val
            .endif
        .endif
    .endrepeat
.endmacro

; --- Usage ---
MyMelody:
    GEN_NOTES "C#DF#GAH" 
    ; Results in: .byte $02, $03, $07, $08, $0A, $0C
