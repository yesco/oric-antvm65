; === Global Music State (Initialize once at top of file) ===
M_OCT  = 4
M_LEN  = 4
M_ACC  = 0
M_VOL  = 12

.macro GEN_ABC_SPN Arg
    _i = 0
    .repeat .strlen(Arg)
        .if _i < .strlen(Arg)
            _c = .strat(Arg, _i)

            ; --- 1. ACCIDENTALS (Prefix: ^, _) ---
            .if _c = '^'
                M_ACC = 1
                _i = _i + 1
                _c = .strat(Arg, _i)
            .elseif _c = '_'
                M_ACC = -1
                _i = _i + 1
                _c = .strat(Arg, _i)
            .endif

            ; --- 2. NOTES (A-H, a-h, z/R/P) ---
            _nc = _c
            .if (_nc >= 'A' && _nc <= 'H') || (_nc >= 'a' && _nc <= 'h') || _nc = 'z' || _nc = 'R' || _nc = 'P'
                _toct = M_OCT
                
                ; ABC Lowercase = Octave Up
                .if _nc >= 'a' && _nc <= 'h'
                    _toct = _toct + 1
                    _nc = _nc - 32 ; Convert to uppercase for mapping
                .endif

                ; TODO: 24-quarter-tone mapping (C=0, D=4, E=8, F=10, G=14, A=18, H=22)
                _nv = 0
                .if _nc = 'C'
                    _nv = 0
                .elseif _nc = 'D'
                    _nv = 2
                .elseif _nc = 'E'
                    _nv = 4
                .elseif _nc = 'F'
                    _nv = 5
                .elseif _nc = 'G'
                    _nv = 7
                .elseif _nc = 'A'
                    _nv = 9
                .elseif _nc = 'H' || _nc = 'B'
                    _nv = 11
                .elseif _nc = 'z' || _nc = 'R' || _nc = 'P'
                    _nv = $FF ; Rest code
                .endif

                ; --- 3. LOOK-AHEAD FOR MODIFIERS ---
                ; TODO: Check _i+1 for ' or , (ABC Octave)
                ; TODO: Check _i+1 for / (ABC Length)
                ; TODO: Check _i+1 for digits (SPN Octave/Length)

                ; OUTPUT NOTE
                .byte (_toct * 12) + _nv + M_ACC
                M_ACC = 0 ; Reset accidental

            ; --- 4. COMMANDS (O, L, V, T, W, E, S) ---
            .elseif _c = 'O' || _c = 'o' || _c = 'K'
                _i = _i + 1
                M_OCT = (.strat(Arg, _i) - '0')
            .elseif _c = 'L'
                _i = _i + 1
                M_LEN = (.strat(Arg, _i) - '0') ; TODO: Multi-digit L16
            .elseif _c = 'V' || _c = 'v'
                _i = _i + 1
                M_VOL = (.strat(Arg, _i) - '0') ; TODO: Hex support V0F
            .elseif _c = 'S'
                .byte $FF ; Stop
            .endif

            _i = _i + 1
        .endif
    .endrepeat
.endmacro
