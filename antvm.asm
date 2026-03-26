;;; AntVM65 - "anthem65" - the actual virtual machine

        AntVM65 — The "Anthem65" Sound Virtual Machine

AntVM65 is a high-performance, 24-TET micro-synth designed for elite 8-bit music, organic speech synthesis, and custom FX. It’s a specialized VM that interprets "in-band" command streams alongside quarter-note data.

The Architecture:

Precision Tuning: Native 24-TET support across 8 octaves (0–7), bridging the gap between clinical Western scales and natural, microtonal speech.

Channel Routing: Independent cursors for Tone Channels A, B, C, plus a dedicated Virtual Noise (N) channel.

The Ticker Engine: A savage 1-bit delta engine with 16-bit patterns. It drives high-resolution, custom envelopes for volume, pitch, and noise.

Advanced FX:
- LINK: C mirrors A with relative detuning and volume attenuation.
- ECHO: A-to-B delay with a 1–16 step buffer (switching to a 2-tick "cheat" for deep rhythmic repeats).

The Logic & Control: Commands that trigger channel shifts, control flow, or raw AY-register overrides.

The Language System: Install up to 8 independent "Languages." Each holds up to 255 Phonemes (subroutines) with a 4-level stack.

Extensibility: Execute JSR calls to host code with AXY register passing. Use the AX return for zero-flag relative branching, enabling true algorithmic sound design.

Tag-line: "AntVM65 isn't just a player; it’s a Sound Language that treats speech and synthesis as one unified, programmable beast."


;;; Interpretes with 4 voices with 3 "cursors"
;;; - A,B,C: tone generators w independent cursors
;;; - N    : noise generator (on A, B, or C)
;;; 
;;; Each cursor interprets a stream.
;;; Each stream has the following parameters:
;;; - volume
;;; - note/pitch 
;;; - duration
;;; - rest
;;; - DELTAS: 1-bitstream modulator
;;;   - volume
;;;   - pitch
;;; - EFFECTS
;;;   - LINK: C linked to A, detuned by:
;;; 
;;;         pitch +- = pitch >> 1..12
;;;         vol    - = dvol
;;; 
;;;   - ECHO: B follows A, delayed in 8 buffer
;;; 
;;;        - delay 1-8  : 
;;;        - delay 9-16 : every second swample
;;;        
;;;        - ? optional feedback? w >>
;;; 


COMMAND BITPATTERN FORMATS
==========================
;;; Notes

ooo nnnnn = note (octave: 0-7, note: 0-23)
            [01=sub 23=bass 45=melody 67=clarity]
cmd 11yyy = commands (cmd: 0-7, data: yyy=0-7)

;;; Comamnds

0ii 11yyy = no argument

000 11 000 = WAIT 0.5s
000 11 www = WAIT (www+1)*20ms: 20-140ms)
;;;  TODO: tie 20ms to BPM 'instead' 8th or 16th note


=== RAW Registers

010 11 rrr | BYTE     = SETAY   ( 2 bytes)
010 11 111 | ...14B...= DUMPAY  (15 bytes)
010 11 110 | MASK |...= AYPDATE (3..10 bytes)

  "90% of your updates in a song are just these 8 registers."

  MASK:   
  - 0: Fine Pitch A
  - 1: Fine Pitch B
  - 2: Fine Pitch C
  - 3: Volume A
  - 4: Volume B
  - 5: Volume C
  - 6: Noise Period (Global)
  - 7: Mixer (R7)

=== Articulation Presets (note+rest lengths)

Value: duration length in "ticks"
Gate:  % time the sound is on (Duty Cycle)
Rest period: is the silence within that value.

Isn't a full note "4 seconds"? ("normal BPS")

011 11 xxx        = VALUE (i.e. length)

011 11 000        = SUSTAIN (no rest)
011 11 001        = VALUE 1 = full note (1/1) 200 ticks
011 11 010        = VALUE 2 = half      (1/2) 100
011 11 011        = VALUE 3 = quarter   (1/4)  50
011 11 100        = VALUE               (1/8)  25
011 11 101                              (1/16) 12
011 11 110                              (1/32)  6 ticks
011 11 111        = LEGATO (no rest), "switch"

Legato: FIX, is when just the tone is changed but not trigger new envelopes to restart...

You wrote (and I take it for begin more like % than actual absolute ticks?):

011 11 000 (Staccato):       Play 1/4 ticks
011 11 001 (Tenuto):         Play 3/4 ticks
011 11 010 (Legato/Sustain): Play 4 ticks



Proposed 011 Mapping:

011 11 000 | SHIFT = QUICK LINK
011 11 001 | DELAY = QUICK ECHO
011 11 010         = TOGGLE NOISE (1 byte)
011 11 011         = PUSH+SET LANGUAGE (1 byte)
011 11 100         = STOP ALL (1 byte). PANIC SILENCE
011 11 101 - 111   = RESERVED deltas controls



/// Control commands with argument

1__ 11 ___     = command with argument(s)


=== Phonems (subroutines)

100 11 000     = RETURN
100 11 ppp     = CALL ppp (local language phonem: 1-7)

101 11 000 + P = CALL Phonem (0-255: local language)
101 11 lll + P = CALL language:1-7, Phonem: 0-255

110 11 000 + P = TAILCALL Phonem (local lang)
110 11 001 + R = GOTO Relative (rel branch)
110 11 010 + R = BEQ Relative (if zero)
110 11 011 + R = BNE Relative (if !zero)


=== Drum effects

110 11 100      = kick  / 's'  (~50-100Hz)
110 11 101      = snare / 'sh' 
110 11 110      = hihat closed / 'ch'
110 11 111      = hihat open   / 'th'/'ts' (cymbal)

=== DELTAS

TODO:
- link? C follow A == Thickening Haas Effect (chorus)
   pitch -= pitch >> S "thick" (default!)
 ( pitch += pitch >> S "thin" (little out of tune) )

ECHO needs a: once to R7 per tick.

Echo Feedback Phase: Without an explicit "Feedback" command, your echo is a one-shot delay. Adding feedback (feeding B back into itself) would require a separate volume coefficient, which might be hard to fit into your minimal bit patterns without adding a 2nd byte to the echo command. 

echo? B delay A less vol
   volume subtract

   delay = 1    = Haas
   delay = 2    = Doubling
   delay = 5-10 = small room
   delay = 5    = Slapback echo
   delay = 7-10 = Physical space 
   delay = 12+  = Rythmic echo

   1-8:   buffer of 8 samples delayed and decaying
   8-16:  every second tick update

   Not clear if have "feedback"



=== Timing/Channel modifications

(also see 011 for only VALUE/length changes)

111 11 000 + 00 = YIELD/STOP (wait for "event")
111 11 000 + 0l = SILENCE pause set REST rest: 1-7
111 11 000 + v0 = SUSTAINED vol:0-15
111 11 000 + vl = DURATION  vol:0-15 set VALUE:1-7

111 11 001 + WW = DELTAS volume
111 11 010 + WW = DELTAS pitch
111 11 011 + WW = DELTAS noise

  v:4 bits is initial volume

  can use previous set:
     l:4 bits as "value" (not length)
     r:4 bits as step
  

brilliant way to save bytes. If you use the Rest Setting (r) to drive the Ticker Speed (Stretch) and the Duration (l) to drive the Envelope Step, you’ve essentially created a "Rhythmic Sync" engine.
Here is why it works and where it gets messy:
1. The "Pro" Side (The Sync)
By tying Envelope Speed to your Rhythm (Rest/Duration), your sounds stay "in time" automatically.
Faster Tempo: The note gets shorter, and the Volume Delta speeds up to match.
Result: You never get "cutoff" notes. A snare hit will always finish its decay exactly when the next beat hits, regardless of the BPM. This is a "Holy Grail" for tracker music.
2. The "Messy" Side (The "Side Effect")
The mess happens when you want a Long Decay on a Short Note (e.g., a "reverb" tail on a 16th note).
The Conflict: If you change the Duration (l) to make a fast melody, your Step increases, making the volume drop way too fast.
The Sound: Your "Lush Pad" suddenly turns into a "Chirp" just because you played a faster rhythm.
3. How to Clean it Up: The "Offset" Logic
To stop it from being messy, use Addition instead of Replacement:
Base Speed: Set by the Instrument/Phoneme (Language).
Modifier: The Rest (r) or Duration (l) adds a "Shift" to that speed.
Logic: Actual_Speed = Base_Speed + (r << 1)
4. The AntVM Strategy
Since you have the 111 11 001/010/011 DELTA blocks, use the l/r values as "Multipliers":
Default: If l and r are 0, the Delta Engine runs at the "Language" speed.
Active: if l > 0, the VM uses it to scale the 1-bit ticker.
The Verdict: It's a high-level "cheat" that makes AntVM65 feel incredibly musical. It forces the synthesis to dance with the rhythm. Just ensure you have a "Manual Override" command (perhaps in the 011 block) to "Unlink Envelope from Rhythm" for those times you need a long tail on a short note.
The "Pro" Move: Use r as the Ticker Stretch and l as the Gate (Duty Cycle). This lets you control "How fast it moves" vs. "How soon it cuts off" in one single state.
Should the Echo (B) also inherit this "Speed-Sync," or should the echo timing stay fixed to the 50Hz clock?
Next Step: Define the "Sync Toggle"—is it a global bit or per-channel?


----------TODO: 

jsk:    Echo will also have a delay parameter, and a volume adjustment. Delay can be == rest I guess.

That is a massive optimization. By tying Echo Delay to the Rest/Value parameter, you’ve created an "Auto-Sync Delay"—a high-end feature usually reserved for modern VSTs.
In a 50Hz tracker, manually calculating echo delays to match the BPM is a chore. If Echo Delay == Rest, the echo will always hit "on the beat" (e.g., an 8th note delay for an 8th note melody) without the user ever touching a hex calculator.
The "Sync" Logic

* Melody A: Plays a 16th note (Rest = 2 ticks).
* Echo B: Automatically delays by 2 ticks.
* Result: A perfect, rhythmic 16th-note "slapback" that follows the groove of the song instantly.

Potential "Messy" Conflict: The Delay Buffer
Since your buffer is 1-8 (High Res) or 9-16 (Eco/Skip-1):

* Small Rest (1-8): Perfect 1:1 mapping.
* Large Rest (9-16): If the user sets a long REST (e.g., 14 ticks), your VM needs to automatically flip into "Eco Mode" (recording every 2nd tick) to fit that delay into the 16-byte buffer.
* The Logic: if (Rest > 8) { Use Eco_Mode; Buffer_Index = Rest; }

The Volume Adjustment (The Decay)
Since the Volume Adjustment is also "Sticky," you can set it once per instrument:

* Echo Vol = -2: A long, trailing dub-style echo.
* Echo Vol = -8: A single, sharp "shadow" note.

Does it make sense?
Yes, absolutely. Mapping Echo Delay to Rest is the smartest way to keep your data stream "thin." You only send the Note and the Volume/Rest byte, and the VM handles the synthesis (Delta Envelopes), the thickening (Link), and the rhythmic space (Echo) all from that one command.
The "Pro" Verdict:
It’s a "Musical Shortcut." By linking Delay to Rest, you ensure the song never sounds "cluttered" because the echoes are always tucked perfectly behind the next note's timing.
One critical detail:
Should the Echo (B) "reset" its delay timer when a new REST command is sent, or only when a new NOTE is triggered?
Next Step: Define the "Echo Feedback"—does the echo repeat forever, or just once per note?



/// EXTENDED SET

111 11 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
111 11 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)

=== RAW Messaging

--- Subroutine "messaging"

There is commands to set Y, AX, and to finally JSR an address. Result is stored in value cache of Y, AX.
Using BEQ and BNE simple tests can be performed using the value of AX.

111 11 100|0000 0000|BYTE = "Y:=BYTE;" (3 bytes)
111 11 100|1000 0000|WORD = "AX:=WORD;"
111 11 100|1000 0001|ADDR = JSR addr   (using AXY)


=== Global timing info

111 11 100|0000 0001|BYTE = BeatsPerSecond (ticks?)
111 11 100|0000 0010|BYTE = "Global Gate" (percentage)
111 11 100|0000 0011|BYTE 

TODO: add "Global Gate" percentage. e.g. 87.5% 
TOOD: how to set?

Next Step: Define the "Gate" behavior—is it a fixed 1-tick "gap" at the end of every note, or fully programmable?

=== UNDEFINED/FREE

111 11 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
111 11 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)

--- RESERVED/SYSTEM

111 11 100|0000 iiii|BYTE i>0011
111 11 100|0000 0100|BYTE
111 11 100|0000 0101|BYTE
111 11 100|0000 0110|BYTE
111 11 100|0000 0111|BYTE
...

111 11 100|1000 iiii|WORD i>0000
111 11 100|1000 0100|WORD
111 11 100|1000 0101|WORD
111 11 100|1000 0110|WORD
111 11 100|1000 0111|WORD
...

--- Free for extensions

111 11 100|0000 iiii|BYTE = RESERVED/SYTEM

---- 3 bytes 1 byte param
111 11 100|0xxx 0100|BYTE = FREE
111 11 100|0xxx 0101|BYTE = FREE
111 11 100|0xxx 0110|BYTE = FREE
111 11 100|0xxx 0111|BYTE = FREE

---- 4 bytes 2 byte param
111 11 100|1xxx iiii|WORD i>0000
111 11 100|1xxx 0100|WORD = FREE
111 11 100|1xxx 0101|WORD = FREE
111 11 100|1xxx 0110|WORD = FREE
111 11 100|1xxx 0111|WORD = FREE



=== Channel shortcuts (additive if in seq)

111 11 101      = CHANNEL A
111 11 110      = CHANNEL B
111 11 111      = CHANNEL C

A+B+C == alternating abcabcabcabcabc
C+B+A == all same
