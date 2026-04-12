; --- Global State Initialization ---
_CUR_OCT  = 4
_CUR_LEN  = 4
_PEND_ACC = 0

.macro GEN_ABC_SPN Arg
    .local @Char, @I, @TmpOct, @FinalNote, @NoteChar
    
    @I .set 0
    .repeat .strlen(Arg)
        .if @I < .strlen(Arg)
            @Char = .strat(Arg, @I)

            ; --- 1. HANDLE ACCIDENTAL PREFIX (^, _) ---
            .if @Char = '^'
                _PEND_ACC := 1
                @I .set @I + 1
                @Char = .strat(Arg, @I)
            .elseif @Char = '_'
                _PEND_ACC := -1
                @I .set @I + 1
                @Char = .strat(Arg, @I)
            .endif

            ; --- 2. HANDLE NOTES (A-H, a-h, z) ---
            @NoteChar = @Char
            .if (@NoteChar >= 'A' && @NoteChar <= 'H') || (@NoteChar >= 'a' && @NoteChar <= 'h') || @NoteChar = 'z'
                @TmpOct = _CUR_OCT
                
                ; ABC Lowercase = Octave Up
                .if @NoteChar >= 'a' && @NoteChar <= 'h'
                    @TmpOct = @TmpOct + 1
                    @NoteChar = @NoteChar - 32 ; Convert to uppercase for mapping
                .endif

                ; TODO: Map @NoteChar to 0-23 (Quarter tones) 
                ; C=0, D=2, E=4, F=5, G=7, A=9, H=11 (Example semitones)
                @FinalNote = 0 
                .if @NoteChar = 'C'
                    @FinalNote = 0
                .elseif @NoteChar = 'D'
                    @FinalNote = 2
                .elseif @NoteChar = 'E'
                    @FinalNote = 4
                .elseif @NoteChar = 'F'
                    @NoteChar = 5
                ; ... etc ...
                .endif

                ; --- 3. LOOK-AHEAD FOR MODIFIERS ---
                ; TODO: Check @I+1 for ABC markers (',') or SPN numbers (A4)
                ; TODO: Check @I+1 for ABC length (A/16) or SPN length (A416)

                ; OUTPUT (Example: Octave * 12 + Note + Accidental)
                .byte (@TmpOct * 12) + @FinalNote + _PEND_ACC
                
                _PEND_ACC := 0 ; Reset accidental

            ; --- 4. HANDLE STICKY COMMANDS (O, L, V, T, W, E) ---
            .elseif @Char = 'O' || @Char = 'o' || @Char = 'K'
                @I .set @I + 1
                _CUR_OCT := (.strat(Arg, @I) - '0')
            .elseif @Char = 'L'
                @I .set @I + 1
                ; TODO: Multi-digit capture for Length
                _CUR_LEN := (.strat(Arg, @I) - '0')
            .endif

            @I .set @I + 1
        .endif
    .endrepeat
.endmacro
