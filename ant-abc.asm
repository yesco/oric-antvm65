; --- Driver Command Constants (Modify to match your driver) ---
CMD_OCTAVE   = $80
CMD_LENGTH   = $81
CMD_VOLUME   = $82
CMD_TEMPO    = $83
CMD_MIXER    = $84
CMD_ENVELOPE = $85
CMD_STOP     = $FF

.macro GEN_ABC_SPN Arg
    .local @Char, @Next, @ArgVal, @I, @NoteVal
    
    @I = 0
    .repeat .strlen(Arg)
        ; Check if we've skipped indices (because of multi-char commands)
        .if @I < .strlen(Arg)
            @Char = .strat(Arg, @I)
            
            ; --- 1. HANDLE OCTAVE (O, o, K) ---
            .if @Char = 'O' | @Char = 'o' | @Char = 'K'
                @I = @I + 1
                @ArgVal = .strat(Arg, @I) - '0'
                .byte CMD_OCTAVE, @ArgVal
                
            ; --- 2. HANDLE VOLUME (V, v, !) ---
            .elseif @Char = 'V' | @Char = 'v'
                @I = @I + 1
                ; TODO: Handle hex (A-F) vs Dec logic for @ArgVal
                @ArgVal = .strat(Arg, @I) - '0' 
                .byte CMD_VOLUME, @ArgVal
                
            ; --- 3. HANDLE LENGTH (L) ---
            .elseif @Char = 'L'
                @I = @I + 1
                ; TODO: Capture 1 or 2 digits (L4 vs L16)
                @ArgVal = .strat(Arg, @I) - '0'
                .byte CMD_LENGTH, @ArgVal

            ; --- 4. HANDLE ENVELOPE (E) ---
            .elseif @Char = 'E'
                @I = @I + 1
                @ArgVal = .strat(Arg, @I) - '0'
                ; TODO: Capture optional "llhh" 16-bit pitch if present
                .byte CMD_ENVELOPE, @ArgVal

            ; --- 5. HANDLE TEMPO (T) ---
            .elseif @Char = 'T'
                @I = @I + 1
                ; TODO: Handle 3-digit BPM (T120)
                .byte CMD_TEMPO ; (followed by arg)

            ; --- 6. HANDLE STOP (S) ---
            .elseif @Char = 'S'
                .byte CMD_STOP

            ; --- 7. HANDLE NOTES (A-H, z, R, P) ---
            .elseif (@Char >= 'A' & @Char <= 'H') | (@Char >= 'a' & @Char <= 'h') | @Char = 'z' | @Char = 'R' | @Char = 'P'
                ; TODO: Map letter to note index (0-11)
                ; TODO: Check @I+1 for sharps (#, ^) or flats (b, _)
                ; TODO: Check @I+1 for ABC octave markers (',')
                ; TODO: Check @I+1 for SPN octave number (A4) or length (A44)
                .byte $01 ; Placeholder for Note Byte
            .endif

            @I = @I + 1
        .endif
    .endrepeat
.endmacro

; --- Usage Example ---
; GEN_ABC_SPN "O4 V15 A#44 R8 E1 V16 A41 S"
