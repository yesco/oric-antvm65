; --- Global Parser State ---
.set _CUR_OCT    = 4        ; Default Octave
.set _CUR_LEN    = 4        ; Default Length (Denominator)
.set _PEND_ACC   = 0        ; Pending accidental (^ = +1, _ = -1)

.macro GEN_ABC_SPN Arg
    .local @Char, @I, @TmpOct, @TmpLen, @FinalNote
    
    @I = 0
    .repeat .strlen(Arg)
        .if @I < .strlen(Arg)
            @Char = .strat(Arg, @I)

            ; --- ACCIDENTALS (Prefix) ---
            .if @Char = '^'
                .set _PEND_ACC, 1
                @I = @I + 1
                @Char = .strat(Arg, @I)
            .elseif @Char = '_'
                .set _PEND_ACC, -1
                @I = @I + 1
                @Char = .strat(Arg, @I)
            .endif

            ; --- NOTE HANDLING ---
            .if (@Char >= 'A' & @Char <= 'G') | @Char = 'H' | (@Char >= 'a' & @Char <= 'h')
                @TmpOct = _CUR_OCT
                
                ; 1. Handle ABC Case-Sensitivity
                .if @Char >= 'a' & @Char <= 'h'
                    @TmpOct = @TmpOct + 1
                .endif

                ; 2. Map Letter to Base Index (0-11 or 0-23)
                ; TODO: Implement NoteMapping(@Char) -> 0, 2, 4, 5, 7, 9, 11...
                @FinalNote = 0 ; Placeholder

                ; 3. Look-ahead for ABC modifiers (',', ''')
                ; TODO: Loop @I+1 to catch multiple ,,, or ''' and adjust @TmpOct

                ; 4. Look-ahead for SPN modifiers (A4, A416)
                ; TODO: If @I+1 is a digit, @TmpOct = Digit. 
                ; TODO: If @I+2 is also a digit, start capturing @TmpLen.

                ; 5. Handle ABC Length (A/16)
                ; TODO: If @Char = '/', capture following digits for @TmpLen.

                ; 6. OUTPUT: Final Value = (@TmpOct * 12) + @FinalNote + _PEND_ACC
                .byte (@TmpOct * 12) + @FinalNote + _PEND_ACC
                
                .set _PEND_ACC, 0 ; Reset accidental after note is placed

            ; --- STICKY COMMANDS ---
            .elseif @Char = 'O' | @Char = 'o' | @Char = 'K'
                @I = @I + 1
                .set _CUR_OCT, .strat(Arg, @I) - '0'
            .elseif @Char = 'L'
                @I = @I + 1
                ; TODO: Capture multi-digit length
                .set _CUR_LEN, 4 
            .endif

            @I = @I + 1
        .endif
    .endrepeat
.endmacro
