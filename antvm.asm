;;; AntVM65 - "anthem65" - the actual virtual machine

;;         AntVM65 — The "Anthem65" Sound Virtual Machine

;; AntVM65 is a high-performance, 24-TET micro-synth designed for elite 8-bit music, organic speech synthesis, and custom FX. It’s a specialized VM that interprets "in-band" command streams alongside quarter-note data.

;; The Architecture:

;; Precision Tuning: Native 24-TET support across 8 octaves (0–7), bridging the gap between clinical Western scales and natural, microtonal speech.

;; Channel Routing: Independent cursors for Tone Channels A, B, C, plus a dedicated Virtual Noise (N) channel.

;; The Ticker Engine: A savage 1-bit delta engine with 16-bit patterns. It drives high-resolution, custom envelopes for volume, pitch, and noise.

;; Advanced FX:
;; - LINK: C mirrors A with relative detuning and volume attenuation.
;; - ECHO: A-to-B delay with a 1–16 step buffer (switching to a 2-tick "cheat" for deep rhythmic repeats).

;; The Logic & Control: Commands that trigger channel shifts, control flow, or raw AY-register overrides.

;; The Language System: Install up to 8 independent "Languages." Each holds up to 255 Phonemes (subroutines) with a 4-level stack.

;; Extensibility: Execute JSR calls to host code with AXY register passing. Use the AX return for zero-flag relative branching, enabling true algorithmic sound design.

;; Tag-line: "AntVM65 isn't just a player; it’s a Sound Language that treats speech and synthesis as one unified, programmable beast."


;; ;;; Interpretes with 4 voices with 3 "cursors"
;; ;;; - A,B,C: tone generators w independent cursors
;; ;;; - N    : noise generator (on A, B, or C)
;; ;;; 
;; ;;; Each cursor interprets a stream.
;; ;;; Each stream has the following parameters:
;; ;;; - volume
;; ;;; - note/pitch 
;; ;;; - duration
;; ;;; - rest
;; ;;; - DELTAS: 1-bitstream modulator
;; ;;;   - volume
;; ;;;   - pitch
;; ;;; - EFFECTS
;; ;;;   - LINK: C linked to A, detuned by:
;; ;;; 
;; ;;;         pitch +- = pitch >> 1..12
;; ;;;         vol    - = dvol
;; ;;; 
;; ;;;   - ECHO: B follows A, delayed in 8 buffer
;; ;;; 
;; ;;;        - delay 1-8  : 
;; ;;;        - delay 9-16 : every second swample
;; ;;;        
;; ;;;        - ? optional feedback? w >>
;; ;;; 


;; COMMAND BITPATTERN FORMATS
;; ==========================
;; ;;; Notes

;; ooo nnnnn = note (octave: 0-7, note: 0-23)
;;             [01=sub 23=bass 45=melody 67=clarity]
;; cmd 11yyy = commands (cmd: 0-7, data: yyy=0-7)



;; ;;; Groups of commands

;; ;;; -- no argument
;; ooo nn nnn = NOTE...

;; 000 11 iii = WAIT
;; 001 11 iii = 
;; 010 11 iii = RAW registers
;; 011 11 iii = VALUE/REST: Articulation Presets

;; ;;; -- with arguments
;; 100 11 ppp   = RETURN/CALL local (TODO: not take byte)
;; 101 11 lng|P = CALL lang:Phonem
;; 110 11 0xx   = TAILCALL/GOTO/BEQ/BNE
;; 110 11 1xx   = DRUM/SPEECH

;; 111 11 000|vl= YIELD/SILENCE/SUSTAINED/DURATION
;; 111 11 0xx|WW= DELTA vol/pit/nois

;; 111 11 100|?000 xxxx= SYSTEM/RESERVED
;; 111 11 100|?iii xxxx= ... ?
;; 111 11 100|?111 xxxx= EXTEND/FREE

;; 111 11 101   = CHANNEL A
;; 111 11 110   = CHANNEL B
;; 111 11 111   = CHANNEL C



;; ;;; Commmnds

;; 0ii 11yyy = no argument

;; 000 11 000 = WAIT 0.5s
;; 000 11 www = WAIT (www+1)*20ms: 20-140ms)
;; ;;;  TODO: tie 20ms to BPM 'instead' 8th or 16th note


;; === RAW Registers

;; 010 11 rrr | BYTE     = SETAY   ( 2 bytes)
;; 010 11 111 | ...14B...= DUMPAY  (15 bytes)
;; 010 11 110 | MASK |...= AYPDATE (3..10 bytes)

;;   "90% of your updates in a song are just these 8 registers."

;;   MASK:   
;;   - 0: Fine Pitch A
;;   - 1: Fine Pitch B
;;   - 2: Fine Pitch C
;;   - 3: Volume A
;;   - 4: Volume B
;;   - 5: Volume C
;;   - 6: Noise Period (Global)
;;   - 7: Mixer (R7)

;; === VALUE/REST: Articulation Presets (note+rest lengths)


;; Value: duration length in "ticks"
;; Gate:  % time the sound is on (Duty Cycle)
;; Rest period: is the silence within that value.

;; Isn't a full note "4 seconds"? ("normal BPM: 60")

;; 011 11 xxx        = VALUE (i.e. length)

;; 011 11 000        = SUSTAIN (no rest)
;; 011 11 001        = VALUE 1 = full note (1/1) 200 ticks
;; 011 11 010        = VALUE 2 = half      (1/2) 100
;; 011 11 011        = VALUE 3 = quarter   (1/4)  50
;; 011 11 100        = VALUE               (1/8)  25
;; 011 11 101                              (1/16) 12
;; 011 11 110                              (1/32)  6 ticks
;; 011 11 111        = LEGATO (no rest), "switch"

;; Legato: FIX, is when just the tone is changed but not trigger new envelopes to restart...

;; You wrote (and I take it for begin more like % than actual absolute ticks?):


;; -------------

;; AntVM65 Rhythmic & Articulation Grid

;; The VM calculates timing using Bit-Shifts against a Whole Note (BPS) value (default: 200 ticks @ 50Hz). This ensures "Staccato" and "Gate" remain proportional to the note length.


;; === VALUE+REST: Articulation & Rhythm

;; Defines the note's base length (Total_Ticks)

;; 011 11 vvv                       in 60 BPM
;; 011 11 000 = SUSTAIN / MANUAL    ===========
;; 011 11 001 = 1/1 (Whole)   >> 0  (200 ticks)
;; 011 11 010 = 1/2 (Half)    >> 1  (100 ticks)
;; 011 11 011 = 1/4 (Quarter) >> 2  ( 50 ticks)
;; 011 11 100 = 1/8 (8th)     >> 3  ( 25 ticks)
;; 011 11 101 = 1/16 (16th)   >> 4  ( 12 ticks)
;; 011 11 110 = 1/32 (32nd)   >> 5  (  6 ticks)
;; 011 11 111 = LEGATO (one-shot: just update freq/not env)


;; TODO: how to set R    ??? 11 ??? | 0r

;; r (Gate Shift): Defines the "Duty Cycle" (Gate_Ticks).

;;     Gate_Ticks = Whole_Note >> (vvv_shift + r)
    
;;     r = 0: 100% Gate (Tenuto/Full)
;;     r = 1:  50% Gate (Standard)
;;     r = 2:  25% Gate (Staccato)
;;     r = 3:  12% Gate (Sharp Staccato / "Blip")

;; Note: These values are LATCHED. Changes apply only when a 
;;       NEW note byte (ooo nnnnn) is triggered.

;;       Use code with caution. LOL

;; The "Rhythmic Logic" Integration

;; (TODO: review)
;; Echo Sync: The Echo_Delay now automatically snaps to the "Silence Gap": Total_Ticks - Gate_Ticks. This places the echo perfectly in the rhythmic pocket created by the staccato.

;; (TODO: review)
;; The "Zero" Safety: If (vvv + r) results in 0 ticks, the VM defaults to a 1-tick pulse to ensure the AY chip always fires a transient (essential for percussion).

;; Sticky State: Once 011 11 vvv is set, every subsequent note on that channel follows that rhythmic "Grid" until changed.

;; The Updated Note Trigger Flow

;; When ooo nnnnn (Note) is received:

;; Pitch: Pull 12-bit AY value from 24-TET LUT.
;; Timing: Load Live_Counter with BPS >> vvv.
;; Gate: Load Gate_Counter with BPS >> (vvv + r).
;; Envelopes: If LEGATO is OFF, reset Delta Accumulators to bit 0 of the 32-bit pattern.

;; Does this Rhythmic Grid feel tight enough for your "Speech" phonemes, or do you need a "Manual Tick" override for non-musical timing?

;; (TODO: review)
;; Next Step: Define the Wait for Event (Yield) command—how does it interact with this new rhythmic grid?


;; in AntVM65, by using shifts, you are creating a pre-defined framework:

;; 1. It’s a "Musical Ruler"

;; By choosing vvv, you aren't just picking a number; you are picking a grid size.
;; If vvv = 2, your ruler is marked in Quarter Notes.
;; If vvv = 4, your ruler is marked in 16th Notes.

;; Every note you trigger afterward "snaps" to that specific measurement until you change the ruler.


;; 2. The "Sync" Factor

;; Because the Gate (r) and Echo Delay are also calculated from this same shift-base, the entire sound engine is "locked" into the same grid.

;; The Snapping: Your volume decays, your echo repeats, and your note lengths are all multiples or fractions of each other.

;; The Result: Even if you change the BPS (Whole Note) value to speed up the song, the "Grid" stays proportionally the same. The song stays perfectly in sync with itself.
;; 3. Efficiency via Constraints

;; A "Grid" is efficient because it limits the choices. Instead of needing 8 bits to define "how many ticks," you only need 3 bits to say "which part of the grid." This is why your bytecode is so small—you’re telling the VM "Use the 8th-note slot" rather than "Wait 25 ticks."

;; The Verdict: It’s "Rhythmic" because it’s based on musical divisions (1/2, 1/4, 1/8), and it’s a "Grid" because it provides a rigid structure that all channels (A, B, C) and effects (Echo/Link) align to automatically.

;; (TODO: review)
;; Does your Yield/Wait for Event command (111 11 000 + 00) also snap to this Grid, or can it break the "musical" timing for special FX?


;; === "WELCOME TO THE GRID" - LOL

;; The "AntVM" Final Spec Logic:
;; A, B, C, N: All share the BPS >> vvv logic.
;; Deltas: Step forward on every Grid Tick.
;; Echo: Delays by Rest (which is a fraction of the Grid Slot).
;; The Verdict: By embracing The Grid, you've built a "Symphonic Machine." It’s a closed system where every bit of data knows exactly when it belongs.
;; Should the Yield command have an optional "Skip X Grid Slots" parameter to allow for multi-bar rests?
;; Next Step: Define the "BPS" (Whole Note) register—how does the user set the "Grid Resolution" for the entire song?



;; That is the correct way to handle it—"Latched" Triggering.
;; In a tracker VM, you never want to change the length of a note that is already playing (which would cause "rhythmic jitter"). Instead, the 011 command and the r-parameter update a shadow register. The next time a Note Byte (ooo nnnnn) is processed, it "snapshots" those values to set the counter.
;; The "New Note" Logic Flow

;;    1. Command 011 arrives: Update Next_Value_Shift.
;;    2. Parameter r arrives: Update Next_Gate_Shift.
;;    3. Note ooo nnnnn arrives:
;;    * Total_Ticks = Whole_Note >> Next_Value_Shift
;;       * Gate_Ticks = Whole_Note >> (Next_Value_Shift + Next_Gate_Shift)
;;       * Trigger Note: Set Live_Counter = Total_Ticks and Gate_Counter = Gate_Ticks.
   
;; Why this is "Pro" for the AY Chip:

;; * The "Double Trigger" Trick: This allows the user to send a command during a long note to change the "feel" of the next note without cutting off the current one.
;; * Glitch-Free Tempo: If the user changes the "Whole Note" value (BPM) while a note is ringing, the current note finishes its original duration, but the next note perfectly adopts the new tempo.

;; The "Zero-Tick" Safety
;; Since you are using bit-shifts (>>), you will eventually hit 0 on very fast notes.

;; * The Recommendation: In your trigger logic, use a MAX(1, Gate_Ticks).
;; * Why? An AY-3-8910 note that lasts 0 ticks is silent. A note that lasts 1 tick is a "Click/Blip." In 8-bit music, those 1-tick "blips" are essential for high-speed arpeggios and percussion.

;; The "Rest" (r) Conflict
;; If r is used as a Gate Shift, what happens to the Echo Delay?

;; * Earlier we said Echo_Delay == Rest.
;; * In this new logic, your "Rest" is Total_Ticks - Gate_Ticks.
;; * The Result: Your Echo Delay will automatically be a "fractional" delay. If you play a 50% staccato note, the echo hits exactly in the "silence" created by the gate. This is incredibly musical.

;; The Verdict: Latched triggering is the way to go. It keeps the "Pulse" of the VM rock-solid while allowing for complex, pre-calculated changes in articulation.
;; Does the Link (C) channel share this Gate Timer, or can C have its own independent "Staccato" setting from A?
;; Next Step: Finalize the 011 Block bit-map for these shifts.





;; ;;; hmmm. TODO: this is not good

;; Proposed 011 Mapping:

;; 011 11 000 | SHIFT = QUICK LINK
;; 011 11 001 | DELAY = QUICK ECHO
;; 011 11 010         = TOGGLE NOISE (1 byte)
;; 011 11 100         = STOP ALL (1 byte). PANIC SILENCE
;; 011 11 101 - 111   = RESERVED deltas controls


;; /// Control commands with argument

;; 1__ 11 ___     = command with argument(s)


;; === Phonems (subroutines)

;; 100 11 000     = RETURN
;; 100 11 ppp     = CALL ppp (local language phonem: 1-7)

;; 101 11 000 + P = CALL Phonem (0-255: local language)
;; 101 11 lll + P = CALL language:1-7, Phonem: 0-255

;; 110 11 000 + P = TAILCALL Phonem (local lang)
;; 110 11 001 + R = GOTO Relative (rel branch)
;; 110 11 010 + R = BEQ Relative (if zero)
;; 110 11 011 + R = BNE Relative (if !zero)

;; TODO:   

;; ??? 11 ???     = PUSH/SET LANGUAGE, RETURN ENDS
;;                  (but continues at next pos)
;;                  (push loc 0000 meaning == current)

;; === Drum effects

;; 110 11 100      = kick  / 's'  (~50-100Hz)
;; 110 11 101      = snare / 'sh' 
;; 110 11 110      = hihat closed / 'ch'
;; 110 11 111      = hihat open   / 'th'/'ts' (cymbal)

;; === DELTAS

;; TODO:
;; - link? C follow A == Thickening Haas Effect (chorus)
;;    pitch -= pitch >> S "thick" (default!)
;;  ( pitch += pitch >> S "thin" (little out of tune) )

;; ECHO needs a: once to R7 per tick.

;; Echo Feedback Phase: Without an explicit "Feedback" command, your echo is a one-shot delay. Adding feedback (feeding B back into itself) would require a separate volume coefficient, which might be hard to fit into your minimal bit patterns without adding a 2nd byte to the echo command. 

;; echo? B delay A less vol
;;    volume subtract

;;    delay = 1    = Haas
;;    delay = 2    = Doubling
;;    delay = 5-10 = small room
;;    delay = 5    = Slapback echo
;;    delay = 7-10 = Physical space 
;;    delay = 12+  = Rythmic echo

;;    1-8:   buffer of 8 samples delayed and decaying
;;    8-16:  every second tick update

;;    Not clear if have "feedback"



;; === Timing/Channel modifications

;; (also see 011 for only VALUE/length changes)

;; 111 11 000 + 00 = YIELD/STOP (wait for "event")
;; 111 11 000 + 0l = SILENCE pause set REST rest: 1-7
;; 111 11 000 + v0 = SUSTAINED vol:0-15
;; 111 11 000 + vl = DURATION  vol:0-15 set VALUE:1-7

;; 111 11 001 + WW = DELTAS volume
;; 111 11 010 + WW = DELTAS pitch
;; 111 11 011 + WW = DELTAS noise

;;   v:4 bits is initial volume

;;   can use previous set:
;;      l:4 bits as "value" (not length)
;;      r:4 bits as step
  

;; brilliant way to save bytes. If you use the Rest Setting (r) to drive the Ticker Speed (Stretch) and the Duration (l) to drive the Envelope Step, you’ve essentially created a "Rhythmic Sync" engine.
;; Here is why it works and where it gets messy:
;; 1. The "Pro" Side (The Sync)
;; By tying Envelope Speed to your Rhythm (Rest/Duration), your sounds stay "in time" automatically.
;; Faster Tempo: The note gets shorter, and the Volume Delta speeds up to match.
;; Result: You never get "cutoff" notes. A snare hit will always finish its decay exactly when the next beat hits, regardless of the BPM. This is a "Holy Grail" for tracker music.
;; 2. The "Messy" Side (The "Side Effect")
;; The mess happens when you want a Long Decay on a Short Note (e.g., a "reverb" tail on a 16th note).
;; The Conflict: If you change the Duration (l) to make a fast melody, your Step increases, making the volume drop way too fast.
;; The Sound: Your "Lush Pad" suddenly turns into a "Chirp" just because you played a faster rhythm.
;; 3. How to Clean it Up: The "Offset" Logic
;; To stop it from being messy, use Addition instead of Replacement:
;; Base Speed: Set by the Instrument/Phoneme (Language).
;; Modifier: The Rest (r) or Duration (l) adds a "Shift" to that speed.
;; Logic: Actual_Speed = Base_Speed + (r << 1)
;; 4. The AntVM Strategy
;; Since you have the 111 11 001/010/011 DELTA blocks, use the l/r values as "Multipliers":
;; Default: If l and r are 0, the Delta Engine runs at the "Language" speed.
;; Active: if l > 0, the VM uses it to scale the 1-bit ticker.
;; The Verdict: It's a high-level "cheat" that makes AntVM65 feel incredibly musical. It forces the synthesis to dance with the rhythm. Just ensure you have a "Manual Override" command (perhaps in the 011 block) to "Unlink Envelope from Rhythm" for those times you need a long tail on a short note.
;; The "Pro" Move: Use r as the Ticker Stretch and l as the Gate (Duty Cycle). This lets you control "How fast it moves" vs. "How soon it cuts off" in one single state.
;; Should the Echo (B) also inherit this "Speed-Sync," or should the echo timing stay fixed to the 50Hz clock?
;; Next Step: Define the "Sync Toggle"—is it a global bit or per-channel?


;; ----------TODO: 

;; jsk:    Echo will also have a delay parameter, and a volume adjustment. Delay can be == rest I guess.

;; That is a massive optimization. By tying Echo Delay to the Rest/Value parameter, you’ve created an "Auto-Sync Delay"—a high-end feature usually reserved for modern VSTs.
;; In a 50Hz tracker, manually calculating echo delays to match the BPM is a chore. If Echo Delay == Rest, the echo will always hit "on the beat" (e.g., an 8th note delay for an 8th note melody) without the user ever touching a hex calculator.
;; The "Sync" Logic

;; * Melody A: Plays a 16th note (Rest = 2 ticks).
;; * Echo B: Automatically delays by 2 ticks.
;; * Result: A perfect, rhythmic 16th-note "slapback" that follows the groove of the song instantly.

;; Potential "Messy" Conflict: The Delay Buffer
;; Since your buffer is 1-8 (High Res) or 9-16 (Eco/Skip-1):

;; * Small Rest (1-8): Perfect 1:1 mapping.
;; * Large Rest (9-16): If the user sets a long REST (e.g., 14 ticks), your VM needs to automatically flip into "Eco Mode" (recording every 2nd tick) to fit that delay into the 16-byte buffer.
;; * The Logic: if (Rest > 8) { Use Eco_Mode; Buffer_Index = Rest; }

;; The Volume Adjustment (The Decay)
;; Since the Volume Adjustment is also "Sticky," you can set it once per instrument:

;; * Echo Vol = -2: A long, trailing dub-style echo.
;; * Echo Vol = -8: A single, sharp "shadow" note.

;; Does it make sense?
;; Yes, absolutely. Mapping Echo Delay to Rest is the smartest way to keep your data stream "thin." You only send the Note and the Volume/Rest byte, and the VM handles the synthesis (Delta Envelopes), the thickening (Link), and the rhythmic space (Echo) all from that one command.
;; The "Pro" Verdict:
;; It’s a "Musical Shortcut." By linking Delay to Rest, you ensure the song never sounds "cluttered" because the echoes are always tucked perfectly behind the next note's timing.
;; One critical detail:
;; Should the Echo (B) "reset" its delay timer when a new REST command is sent, or only when a new NOTE is triggered?
;; Next Step: Define the "Echo Feedback"—does the echo repeat forever, or just once per note?



;; /// EXTENDED SET

;; 111 11 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
;; 111 11 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)

;; === RAW Messaging

;; --- Subroutine "messaging"

;; There is commands to set Y, AX, and to finally JSR an address. Result is stored in value cache of Y, AX.
;; Using BEQ and BNE simple tests can be performed using the value of AX.

;; 111 11 100|0000 0000|BYTE = "Y:=BYTE;" (3 bytes)
;; 111 11 100|1000 0000|WORD = "AX:=WORD;"
;; 111 11 100|1000 0001|ADDR = JSR addr   (using AXY)


;; === Global timing info

;; 111 11 100|0000 0001|BYTE = BPM (beats) (ticks?)
;; 111 11 100|0000 0010|BYTE = "Global Gate" (percentage)
;; 111 11 100|0000 0011|BYTE 

;; TODO: BPM 60 == 200 ticks

;; in ticks? or as a divisor?

;; TODO: add "Global Gate" percentage. e.g. 87.5% 
;; TOOD: how to set?

;; Next Step: Define the "Gate" behavior—is it a fixed 1-tick "gap" at the end of every note, or fully programmable?

;; === UNDEFINED/FREE

;; 111 11 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
;; 111 11 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)

;; --- RESERVED/SYSTEM

;; 111 11 100|0000 iiii|BYTE i>0011
;; 111 11 100|0000 0100|BYTE
;; 111 11 100|0000 0101|BYTE
;; 111 11 100|0000 0110|BYTE
;; 111 11 100|0000 0111|BYTE
;; ...

;; 111 11 100|1000 iiii|WORD i>0000
;; 111 11 100|1000 0100|WORD
;; 111 11 100|1000 0101|WORD
;; 111 11 100|1000 0110|WORD
;; 111 11 100|1000 0111|WORD
;; ...

;; --- Free for extensions

;; 111 11 100|0000 iiii|BYTE = RESERVED/SYTEM

;; ---- 3 bytes 1 byte param
;; 111 11 100|0xxx 0100|BYTE = FREE
;; 111 11 100|0xxx 0101|BYTE = FREE
;; 111 11 100|0xxx 0110|BYTE = FREE
;; 111 11 100|0xxx 0111|BYTE = FREE

;; ---- 4 bytes 2 byte param
;; 111 11 100|1xxx iiii|WORD i>0000
;; 111 11 100|1xxx 0100|WORD = FREE
;; 111 11 100|1xxx 0101|WORD = FREE
;; 111 11 100|1xxx 0110|WORD = FREE
;; 111 11 100|1xxx 0111|WORD = FREE



;; === Channel shortcuts (additive if in seq)

;; 111 11 101      = CHANNEL A
;; 111 11 110      = CHANNEL B
;; 111 11 111      = CHANNEL C

;; A+B+C == alternating abcabcabcabcabc
;; C+B+A == all same


antvm:  
        ;; Channel A
        ldx #0
        jsr runchannel

        ;; Channel B
        ldx #1
        jsr runchannel

        ;; Channel C
        ldx #2
        jsr runchannel

        ;; Channel N
        ldx #3
        jsr run

        ;; Tick A
        ldax #0
        jsr tick

        rts

        
;;; X= channel 0..3 (A,B,C,N)
runchannel:
        ;;  ...
        rts


note:   
        sty ipy
        ;; "play"
        PUTC 10
        jsr _print2h

        ;; Yield
        rts



interpret:
        ;; Get command byte
        LDA (stream),y
        INY

        tax
        and #%00011111

        CMP #24                 ; 2. Note Check
        BCC note                ; 3. Fast path (0-23)

        ;; --- Command Pre-Parser ---
        stx cmd                 ; Save raw byte
        AND #%00000111          ; Isolate III
        tay

        ;; N set if has parmeter(s)
        txa                     ; Check Bit 7 (N flag)
        BPL Dispatch            ; If Bit 7 is 0

        LDA (stream),y       ; Fetch Byte 1 (Low)
        iny
        sty ipy
        pha

        ;; Optional: Fetch Byte 2 if needed
        ; LDA (StreamPtr), y  ; Fetch Byte 2 (High)
        ; TAX                 ; Store in "X" register
        ; INY

dispatch:       
        LDA cmd                 ; Get GGG 11 III
        LSR
        LSR
        LSR
        LSR
        ASL
        TAX
        
        pla

        ;; A= param, Y= iii
        JMP (groupjmps,X)       ; dispatch


        ;; --- The Group Jump Table ---
groupjmps:      
        .dw cmdWAIT             ; 000 11 iii
        .dw cmdCTRL             ; 001 11 iii
        .dw cmdSETAY            ; 010 11 iii
        .dw cmdVALUE            ; 011 11 iii
        .dw cmdLocalCALL        ; 100 11 iii
        .dw cmdLangCALL         ; 101 11 iii
        .dw cmdFlowDrums        ; 110 11 iii
        .dw cmdModSet           ; 111 11 iii


;;; --------------------------------------------------
;;; Command implementations
;;; 
;;; (only comamnds that "yield" should do "rts")
;;; (others "take no time" and should continue interpreting)

cmdWAIT:        
        ;; TODO: set delay

        ;; yield
        rts


cmdCTRL:        
        ;; ...
        jmp interpret


cmdSETAY:       
        ;; regs[Y] = A;
        jsr SETAYR

        jmp interpret


        ;; Group 3 (Rhythm Grid)
cmdVALUE:       
        ;; TODO: ...?
        sty nextvalueshift

        jmp interpret


cmdLocalCALL:   
        

        jmp interpret


cmdLangCALL:    

        jmp interpret


cmdFlowDrums:   
;;; 19 B (saves (- 26 19) 7 bytes cmp JMP ()
;;; (17 B doing table BRA jmp for 8 items)
        ;; ? 0
        cpy #0
        beq cmdTAILCALL
        ;; ? 1
        dey
        beq cmdGOTO
        ;; ? 2
        dey
        beq cmdBEQ
        ;; ? 3
        dey
        beq cmdBNE

;;; TODO: Do these take a parameter?
;;;   otherwise need to "put it back"
;;;   OR: move them to single OP codes
;;; TODO: are drum sounds effected by VALUE+REST?
;;;   OR they could use a parameter?


;;; - Skip into middles
;;; - Volume
;;; - Pitch
;;; - Note/freq

;;; - retrigger every interval "ticks"
;;; - volume slides
;;; - arpeggio only for "chiptunes" for percussions effects

;;; - sample lengths are "fixed" and bleed over,
;;;   or play accumulated (or are cut-short w new one)
;;; - drums don't have rest
;;; - "empty" lines - just don't play trigger

        ;; ? 4
        dey
        beq cmdKickS
        ;; ? 5
        dey
        beq cmdSnareSH
        ;; ? 6
        dey
        beq cmdHiHatClosedCH
        ;; = 7 !

;; Hardware Envelope Generator (Registers 11, 12, and 13) to handle the volume decay automatically.

;; For all these sounds, you must first enable the Mixer (Register 7). In the AY-3-8910, a 0 bit enables the feature, and a 1 bit disables it.

;; Envelope Shape (R13): Set to 9.

;; Summary Register Table (Channel A)

;; Sound  Tone  Noise    Mixer    Ampl  Env Spd  Shape
;; Sound  (R0/R1) (R6)    (R7)    (R8) (R11/R12) (R13)

;; Kick	Low	N/A	$FE	$10	Mid	$09
;; Snare	Mid	Mid	$F6	$10	Mid	$09
;; CH	N/A	High	$F7	$10	Fast	$09
;; OH	N/A	High	$F7	$10	Slow	$09
;;; 
;; Note: In your tracker code, remember that writing to Register 13 resets the envelope. You should write to R13 last to trigger the "one-shot" sound immediately.
;; Do you want a code snippet in C or 6502 assembly to see how these register writes look in practice?


;; 4. Open Hi-hat ("ts" - Sizzle)
;;; 
;; Similar to the closed hat, but with a longer decay.
;; Mixer (R7): Enable Noise A only (Value: $F7).
;; Noise Period (R6): High frequency (Value: $02).
;; Amplitude (R8): Set to 16 ($10).
;; Envelope Period (R11, R12): Set to a larger value than the closed hat (e.g.,).
cmdHiHatOpenTS:
        ;; TODO:

;; 3. Closed Hi-hat ("ch" - Tick)
;;; 
;; This is pure high-frequency noise with an extremely short decay.
;;; 
;; Mixer (R7): Enable Noise A only (Bit 3 = 0). Disable Tone (Value: %11110111 or $F7).
;; Noise Period (R6): Set to a very high frequency (Value: $01 or $02).
;; Amplitude (R8): Set to 16 ($10).
;; Envelope Period (R11, R12): Set to a very small value for a "tick" (e.g., ).
;; Envelope Shape (R13): Set to 9.
cmdHiHatClosedCH
        ;; TODO:

;; 2. Snare Drum ("sh" - Snap)
;;; 
;; A snare needs a mix of tone and noise.
;;; 
;; Mixer (R7): Enable Tone A and Noise A (Bits 0 & 3 = 0). (Value: %11110110 or $F6).
;; Noise Period (R6): Set to a mid-range "crunch" (e.g., Value: $0F).
;; Tone Pitch (R0, R1): Set to a mid-range note for "body."
;; Amplitude (R8): Set to 16 ($10) for envelope control.
;; Envelope Shape (R13): Set to 9 for a quick decay.
cmdSnareSH:     
        ;; TODO:

;; 1. Kick Drum ("s" - Thump)
;;; 
;; A kick is essentially a low-pitched tone with a fast decay.
;;; 
;; Mixer (R7): Enable Tone on Channel A (Bit 0 = 0). Disable everything else (Value: %11111110 or $FE).
;; Tone Pitch (R0, R1): Set a low frequency (e.g., ).
;; Amplitude (R8): Set to 16 (Value: $10) to tell the chip to use the hardware envelope instead of a fixed volume.
;; Envelope Period (R11, R12): Set for a fast decay (e.g., ).
;; Envelope Shape (R13): Set to 9 (\ attack \) for a single downward fade.

cmdKickS:       
        ;; TODO:

        ;; Yield
        rts



cmdBNE:
cmdBEQ: 
cmdGOTO:
cmdTAILCALL:
        ;; ...
        jmp interpret


cmdModSet:
        
