# AntVM65 — The "Anthem65" Sound VM

*Oric AntVM65 - a 24-TET Sound Virtual Machine for the 6502*

AntVM65 is a high-performance, 24-TET micro-synth designed for elite 8-bit music, organic speech synthesis, and custom FX. It’s a specialized VM that interprets "in-band" command streams alongside quarter-note data.

## The Architecture:

Precision Tuning: Native 24-TET support across 8 octaves (0–7), bridging the gap between clinical Western scales and natural, microtonal speech.

Channel Routing: Independent cursors for Tone Channels A, B, C, plus a dedicated Virtual Noise (N) channel.

The Ticker Engine: A savage 1-bit delta engine with 16-bit patterns.It drives high-resolution, custom envelopes for volume, pitch, and noise.

**Advanced FX:**

- LINK: C mirrors A with relative detuning and volume attenuation.
- ECHO: A-to-B delay with a 1–16 step buffer (switching to a 2-tick "cheat" for deep rhythmic repeats).

The Logic & Control: Commands that trigger channel shifts, control flow, or raw AY-register overrides.

The Language System: Install up to 8 independent "Languages." Zero is your main program. Each can hold up to 256 Phonemes (subroutines). There is a 4.-level stack for caLLs, which stores language+pos, which are restored at return.

Extensibility: Execute JSR calls to host code with AXY register passing. Use the AX return for zero-flag relative branching, enabling true algorithmic sound design.

Tag-line: "AntVM65 isn't just a player; it’s a Sound Language that treats speech and synthesis as one unified, programmable beast."


**Feature summary:**

```
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
;;;         pitch +- = pitch >> 1..12
;;;         vol    - = dvol
;;;   - ECHO: B follows A, delayed in 8 buffer
;;;        - delay 1-8  : 
;;;        - delay 9-16 : every second swample
;;;        - ? optional feedback? w >>
;;; 
```


# COMMAND BITPATTERN FORMATS

The stream is an simple byte-coded VM: it has two types of commands:

```
 ooo nnnnn = Note (octave: 0-7, note: 0-23)
             [01=sub 23=bass 45=melody 67=clarity]
 cmd 11yyy = commands (cmd: 0-7, data: yyy=0-7)
```

A note, after being set is "played", and it yields. That is it plays it's VALUE time ticks, and then it's REST specifedc ticks. If VALUE is 0, then it doesn't yield *(TODO:!)* and WAIT can be used.

Each channel (A,B,C,Noise) typically has it's own "cursor" (and stack) that does the interpreation.

It's important to set volume and other parameters "before" the note commences. Most such settings are per channel (A,B,C,Noise) and are sticky - that is they are permanent until explicitly changed.

## Groups of commands
 
--- no arguments
ooo nn nnn = NOTE...
 
000 11 iii = WAIT 1s
001 11 iii = ???
010 11 iii = RAW registers
011 11 iii = VALUE/REST: Articulation Presets
 
---  with argument(s)
100 11 ppp ? = RETURN/CALL local (TODO: not take byte)
101 11 lng|P = CALL lang:Phonem
110 11 0xx|..= TAILCALL/GOTO/BEQ/BNE
110 11 1xx   = DRUM/SPEECH
 
111 11 000|vl= YIELD/SILENCE/SUSTAINED/DURATION
111 11 0xx|WW= DELTA vol/pit/nois

111 11 100|?000 xxxx= SYSTEM/RESERVED
111 11 100|?iii xxxx= ... ?
111 11 100|?111 xxxx= EXTEND/FREE

111 11 101   = CHANNEL A
111 11 110   = CHANNEL B
111 11 111   = CHANNEL C
```


## Commands  Details

TODO: cleanup


```
0ii 11yyy = no argument

000 11 000 = WAIT 0.5s
000 11 www = WAIT (www+1)*20ms: 20-140ms)
```

TODO: tie 20ms to BPM 'instead' 8th or 16th note

```
001 11 000 = ?RETURN
001 11 001 = ?YIELD
001 11 010 = ?STOP
001 11 011 = ?QUIT-ALL

001 11 100
001 11 101
001 11 110
001 11 111
```

## RAW AY Registers

TODO: move to 1xx as they take parameters!

TODO: how to address reg>7 ?

```
 010 11 rrr | BYTE     = SETAY   ( 2 bytes)
 -- (should these auto-yield?)
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
```

## VALUE/REST: Articulation Presets (note+rest lengths)

```
Value: duration length in "ticks"
Gate:  % time the sound is on (Duty Cycle)
Rest period: is the silence within that value.
```

Isn't a full note "4 seconds"? ("normal BPM: 60")

```
011 11 xxx        = VALUE (i.e. length)

011 11 000        = SUSTAIN (no rest)
011 11 001        = VALUE 1 = full note (1/1) 200 ticks
011 11 010        = VALUE 2 = half      (1/2) 100
011 11 011        = VALUE 3 = quarter   (1/4)  50
011 11 100        = VALUE               (1/8)  25
011 11 101                              (1/16) 12
011 11 110                              (1/32)  6 ticks
011 11 111        = LEGATO (no rest), "switch"
```

Legato: FIX, is when just the tone is changed but not trigger new envelopes to restart...

You wrote (and I take it for begin more like % than actual absolute ticks?):

## The GRID ("AI discussion")

**AntVM65 Rhythmic & Articulation Grid**

The VM calculates timing using Bit-Shifts against a Whole Note (BPS) value (default: 200 ticks @ 50Hz). This ensures "Staccato" and "Gate" remain proportional to the note length.


### VALUE+REST: Articulation & Rhythm

Defines the note's base length (Total_Ticks)

```
011 11 vvv                       in 60 BPM
011 11 000 = SUSTAIN / MANUAL    ===========
011 11 001 = 1/1 (Whole)   >> 0  (200 ticks)
011 11 010 = 1/2 (Half)    >> 1  (100 ticks)
011 11 011 = 1/4 (Quarter) >> 2  ( 50 ticks)
011 11 100 = 1/8 (8th)     >> 3  ( 25 ticks)
011 11 101 = 1/16 (16th)   >> 4  ( 12 ticks)
011 11 110 = 1/32 (32nd)   >> 5  (  6 ticks)
011 11 111 = LEGATO (one-shot: just update freq/not env)
```

```
 TODO: how to set R    ??? 11 ??? | 0r

 r (Gate Shift): Defines the "Duty Cycle" (Gate_Ticks).

     Gate_Ticks = Whole_Note >> (vvv_shift + r)
    
     r = 0: 100% Gate (Tenuto/Full)
     r = 1:  50% Gate (Standard)
     r = 2:  25% Gate (Staccato)
     r = 3:  12% Gate (Sharp Staccato / "Blip")

 Note: These values are LATCHED. Changes apply only when a 
       NEW note byte (ooo nnnnn) is triggered.

       Use code with caution. LOL
```

## The GRID ("AI discussion")

The "Rhythmic Logic" Integration

(TODO: review)
Echo Sync: The Echo_Delay now automatically snaps to the "Silence Gap": Total_Ticks - Gate_Ticks. This places the echo perfectly in the rhythmic pocket created by the staccato.

(TODO: review)

The "Zero" Safety: If (vvv + r) results in 0 ticks, the VM defaults to a 1-tick pulse to ensure the AY chip always fires a transient (essential for percussion).

Sticky State: Once 011 11 vvv is set, every subsequent note on that channel follows that rhythmic "Grid" until changed.

The Updated Note Trigger Flow

When ooo nnnnn (Note) is received:

Pitch: Pull 12-bit AY value from 24-TET LUT.

Timing: Load Live_Counter with BPS >> vvv.

Gate: Load Gate_Counter with BPS >> (vvv + r).

Envelopes: If LEGATO is OFF, reset Delta Accumulators to bit 0 of the 32-bit pattern.

Does this Rhythmic Grid feel tight enough for your "Speech" phonemes, or do you need a "Manual Tick" override for non-musical timing?

(TODO: review)

Next Step: Define the Wait for Event (Yield) command—how does it interact with this new rhythmic grid?

in AntVM65, by using shifts, you are creating a pre-defined framework:

### It’s a "Musical Ruler"

By choosing vvv, you aren't just picking a number; you are picking a grid size.
If vvv = 2, your ruler is marked in Quarter Notes.
If vvv = 4, your ruler is marked in 16th Notes.

Every note you trigger afterward "snaps" to that specific measurement until you change the ruler.


### The "Sync" Factor

Because the Gate (r) and Echo Delay are also calculated from this same shift-base, the entire sound engine is "locked" into the same grid.

The Snapping: Your volume decays, your echo repeats, and your note lengths are all multiples or fractions of each other.

The Result: Even if you change the BPS (Whole Note) value to speed up the song, the "Grid" stays proportionally the same. The song stays perfectly in sync with itself.
 3. Efficiency via Constraints

A "Grid" is efficient because it limits the choices. Instead of needing 8 bits to define "how many ticks," you only need 3 bits to say "which part of the grid." This is why your bytecode is so small—you’re telling the VM "Use the 8th-note slot" rather than "Wait 25 ticks."

The Verdict: It’s "Rhythmic" because it’s based on musical divisions (1/2, 1/4, 1/8), and it’s a "Grid" because it provides a rigid structure that all channels (A, B, C) and effects (Echo/Link) align to automatically.

(TODO: review)
Does your Yield/Wait for Event command (111 11 000 + 00) also snap to this Grid, or can it break the "musical" timing for special FX?

The "AntVM" Final Spec Logic:

A, B, C, N: All share the BPS >> vvv logic.

Deltas: Step forward on every Grid Tick.

Echo: Delays by Rest (which is a fraction of the Grid Slot).

The Verdict: By embracing The Grid, you've built a "Symphonic Machine." It’s a closed system where every bit of data knows exactly when it belongs.

Should the Yield command have an optional "Skip X Grid Slots" parameter to allow for multi-bar rests?

That is the correct way to handle it—"Latched" Triggering. In a tracker VM, you never want to change the length of a note that is already playing (which would cause "rhythmic jitter"). Instead, the 011 command and the r-parameter update a shadow register. The next time a Note Byte (ooo nnnnn) is processed, it "snapshots" those values to set the counter.

```
Total_Ticks = Whole_Note >> Next_Value_Shift
 Gate_Ticks = Whole_Note >> (Next_Value_Shift + Next_Gate_Shift)

Trigger Note:
  Set Live_Counter = Total_Ticks and Gate_Counter = Gate_Ticks.
```
   
Why this is "Pro" for the AY Chip:

- The "Double Trigger" Trick: This allows the user to send a command during a long note to change the "feel" of the next note without cutting off the current one.
- Glitch-Free Tempo: If the user changes the "Whole Note" value (BPM) while a note is ringing, the current note finishes its original duration, but the next note perfectly adopts the new tempo.

The "Zero-Tick" Safety

Since you are using bit-shifts (>>), you will eventually hit 0 on very fast notes.

- The Recommendation: In your trigger logic, use a MAX(1, Gate_Ticks).
- Why? An AY-3-8910 note that lasts 0 ticks is silent. A note that lasts 1 tick is a "Click/Blip." In 8-bit music, those 1-tick "blips" are essential for high-speed arpeggios and percussion.

(TODO: resolve)

**The "Rest" (r) Conflict**

If r is used as a Gate Shift, what happens to the Echo Delay?

- Earlier we said Echo_Delay == Rest.
- In this new logic, your "Rest" is Total_Ticks - Gate_Ticks.
- The Result: Your Echo Delay will automatically be a "fractional" delay. If you play a 50% staccato note, the echo hits exactly in the "silence" created by the gate. This is incredibly musical.

The Verdict: Latched triggering is the way to go. It keeps the "Pulse" of the VM rock-solid while allowing for complex, pre-calculated changes in articulation.
 Does the Link (C) channel share this Gate Timer, or can C have its own independent "Staccato" setting from A?


**TODO: this is not good**

Proposed 011 Mapping:

```
011 11 000 | SHIFT = QUICK LINK
011 11 001 | DELAY = QUICK ECHO
011 11 010         = TOGGLE NOISE (1 byte)
011 11 100         = STOP ALL (1 byte). PANIC SILENCE
011 11 101 - 111   = RESERVED deltas controls
```

## Control commands with argument

```
1__ 11 ___     = command with argument(s)
```


## "Phonems"/"words" (subroutines)

```
100 11 000     = RETURN
100 11 ppp     = CALL ppp (local language phonem: 1-7)

101 11 000 + P = CALL Phonem (0-255: local language)
101 11 lll + P = CALL language:1-7, Phonem: 0-255

110 11 000 + P = TAILCALL Phonem (local lang)
110 11 001 + R = GOTO Relative (rel branch)
110 11 010 + R = BEQ Relative (if zero)
110 11 011 + R = BNE Relative (if !zero)

**TODO:**

??? 11 ???     = PUSH/SET LANGUAGE, RETURN ENDS
                 (but continues at next pos)
                 (push loc 0000 meaning == current)
```

## Drum effects

```
110 11 100      = kick  / 's'  (~50-100Hz)
110 11 101      = snare / 'sh' 
110 11 110      = hihat closed / 'ch'
110 11 111      = hihat open   / 'th'/'ts' (cymbal)
```

## DELTAS

**TODO:**

```
- link? C follow A == Thickening Haas Effect (chorus)
   pitch -= pitch >> S "thick" (default!)
 ( pitch += pitch >> S "thin" (little out of tune) )
```

ECHO needs a: once to R7 per tick.

Echo Feedback Phase: Without an explicit "Feedback" command, your echo is a one-shot delay. Adding feedback (feeding B back into itself) would require a separate volume coefficient, which might be hard to fit into your minimal bit patterns without adding a 2nd byte to the echo command. 

```
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
```

## Timing/Channel modifications

(also see 011 for only VALUE/length changes)

```
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
```

### TODO: hmmm

If you use the Rest Setting (r) to drive the Ticker Speed (Stretch) and the Duration (l) to drive the Envelope Step, you’ve essentially created a "Rhythmic Sync" engine.

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

### The AntVM Strategy
- Since you have the 111 11 001/010/011 DELTA blocks, use the l/r values as "Multipliers":
- Default: If l and r are 0, the Delta Engine runs at the "Language" speed.
- Active: if l > 0, the VM uses it to scale the 1-bit ticker.

The Verdict: It's a high-level "cheat" that makes AntVM65 feel incredibly musical. It forces the synthesis to dance with the rhythm. Just ensure you have a "Manual Override" command (perhaps in the 011 block) to "Unlink Envelope from Rhythm" for those times you need a long tail on a short note.

The "Pro" Move: Use r as the Ticker Stretch and l as the Gate (Duty Cycle). This lets you control "How fast it moves" vs. "How soon it cuts off" in one single state.

Should the Echo (B) also inherit this "Speed-Sync," or should the echo timing stay fixed to the 50Hz clock?

jsk: Echo will also have a delay parameter, and a volume adjustment. Delay can be == rest I guess.

That is a massive optimization. By tying Echo Delay to the Rest/Value parameter, you’ve created an "Auto-Sync Delay"—a high-end feature usually reserved for modern VSTs.

In a 50Hz tracker, manually calculating echo delays to match the BPM is a chore. If Echo Delay == Rest, the echo will always hit "on the beat" (e.g., an 8th note delay for an 8th note melody) without the user ever touching a hex calculator.

**The "Sync" Logic:**

- Melody A: Plays a 16th note (Rest = 2 ticks).
- Echo B: Automatically delays by 2 ticks.
- Result: A perfect, rhythmic 16th-note "slapback" that follows the groove of the song instantly.

Potential "Messy" Conflict: The Delay Buffer. Since your buffer is 1-8 (High Res) or 9-16 (Eco/Skip-1):

- Small Rest (1-8): Perfect 1:1 mapping.
- Large Rest (9-16): If the user sets a long REST (e.g., 14 ticks), your VM needs to automatically flip into "Eco Mode" (recording every 2nd tick) to fit that delay into the 16-byte buffer.
- The Logic: if (Rest > 8) { Use Eco_Mode; Buffer_Index = Rest; }

The Volume Adjustment (The Decay). Since the Volume Adjustment is also "Sticky," you can set it once per instrument:

- Echo Vol = -2: A long, trailing dub-style echo.
- Echo Vol = -8: A single, sharp "shadow" note.

**Does it make sense?**

Yes, absolutely. Mapping Echo Delay to Rest is the smartest way to keep your data stream "thin." You only send the Note and the Volume/Rest byte, and the VM handles the synthesis (Delta Envelopes), the thickening (Link), and the rhythmic space (Echo) all from that one command.

**The "Pro" Verdict:**

It’s a "Musical Shortcut." By linking Delay to Rest, you ensure the song never sounds "cluttered" because the echoes are always tucked perfectly behind the next note's timing.

(TODO: resolve) One critical detail: Should the Echo (B) "reset" its delay timer when a new REST command is sent, or only when a new NOTE is triggered?


## EXTENDED COMMANDS

These have various formats and may be used to extend it further but, they take many bytes!

```
111 11 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
111 11 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)
```

###  RAW Messaging

*Subroutine "messaging"*

There is commands to set Y, AX, and to finally JSR an address. Result is stored in value cache of Y, AX.

Using BEQ and BNE simple tests can be performed using the value of AX.

```
111 11 100|0000 0000|BYTE = "Y:=BYTE;" (3 bytes)
111 11 100|1000 0000|WORD = "AX:=WORD;"
111 11 100|1000 0001|ADDR = JSR addr   (using AXY)
```

### Global timing info

```
111 11 100|0000 0001|BYTE = BPM (beats) (ticks?)
111 11 100|0000 0010|BYTE = "Global Gate" (percentage)
111 11 100|0000 0011|BYTE ... ???

TODO: BPM 60 == 200 ticks
```

in ticks? or as a divisor?

TODO: add "Global Gate" percentage. e.g. 87.5% 
TOOD: how to set?

Next Step: Define the "Gate" behavior—is it a fixed 1-tick "gap" at the end of every note, or fully programmable?

### UNDEFINED/FREE

```
111 11 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
111 11 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)
```

### RESERVED/SYSTEM

```
111 11 100|0000 iiii|BYTE i>0011
111 11 100|0000 0100|BYTE
111 11 100|0000 0101|BYTE
111 11 100|0000 0110|BYTE
111 11 100|0000 0111|BYTE

111 11 100|1000 iiii|WORD i>0000
111 11 100|1000 0100|WORD
111 11 100|1000 0101|WORD
111 11 100|1000 0110|WORD
111 11 100|1000 0111|WORD
...

### FREE

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
```

##  Channel shortcuts (additive if in seq)

```
111 11 101      = CHANNEL A
111 11 110      = CHANNEL B
111 11 111      = CHANNEL C

A+B+C == alternating abcabcabcabcabc
C+B+A == all same
```



## Drum Cheat Sheet

We use the parameter to offset the pitch/frequency and the hardware envelope for the length, we can treat the A value as a "Character" or "Intensity" selector.

This is how to tune the parameter.

Sound Palette: Drum & Speech Variations
Using your existing BLOCK logic (where A is the Variation/Pitch):

 | Command (Y) | Hex A | Name / Description | What's happening in the chip? |
 |---|---|---|---|
 | KICK (S) | $00 | Deep 808 Thump | Lowest possible base frequency. |
 | KICK (S) | $10 | Techno "Punch" | Higher pitch, cuts through a busy mix. |
 | KICK (S) | $30 | Pebble / Pop | High pitch, sounds like a "P" or "B" plosive. |
 | SNARE (SH) | $05 | Power Ballad Snare | Deep "body" tone mixed with noise. |
 | SNARE (SH) | $40 | Rimshot / Click | Very high tone pitch makes it "snap" harder. |
 | SNARE (SH) | $7F | Whispering "SH" | Tone is so high it disappears, leaving just the "breath." |
 | C-HAT (CH) | $00 | Classic 909 Tick | Purest, sharpest high-frequency noise. |
 | C-HAT (CH) | $15 | Soft "T" / "Ch" | Slightly lower noise frequency, more "chunk." |
 | C-HAT (CH) | $50 | Metallic Clink | Noise gets "grainy" and heavier. |
 | O-HAT (TS) | $02 | Sizzling Ride | Smooth, long high-frequency decay. |
 | O-HAT (TS) | $20 | Aggressive "S" | Lower noise pitch makes the "Sss" sound "hissier." |
 | O-HAT (TS) | $60 | Strong German "CH" | Heavy, throaty friction sound. |



## Speech Synthesis Guide

If you are using these routines to simulate speech (phonemes), here is how to map them to your tracker:

- "B", "P", "D" (Plosives): Use cmdKickS with a high A value ($20-$40).
- "T", "K" (Hard stops): Use cmdHiHatClosedCH with a low A value ($00-$05).
- "SH", "ZH" (Fricatives): Use cmdSnareSH with a high A value to minimize the "note" and emphasize the "air."
- "S", "Z" (Sibilants): Use cmdHiHatOpenTS with a low A value.

The "German CH" Example: To get that "Strong German CH" (like in Bach or Ich):

    1. Select Y = 7 (cmdHiHatOpenTS).
    2. Set A = $60.

The result is a long, noisy decay but with a much "lower" noise frequency that sounds like back-of-the-throat friction rather than a high-pitched cymbal.



## Language Data Design
 
There can be 8 languages. The 0:th is called "lcoal" and it's MAIN is autoplayed (phrase 0).
 
 
**A language is a block of bytes:**

```
HEADER:
- length  : word
- reserved: byte
- nphrases: byte
MAIN:
- phrase 0: word (load: offset; memory: ptr)
SHORTS:
- phrase 1: word 
- phrase 2: word 
- phrase 3: word 
- phrase 4: word 
- phrase 5: word 
- phrase 6: word 
- phrase 7: word 
- phrase 8: word 
LONGS:
- phrase 9: word 
- phrase10: word 
- ...
- (phrase_n-1): word
PHRASE a:
- stream of bytes
PHRASE b:
- stream of bytes
```




# TODO: cleanup, this was initial design discussion with bits and pieces.

An experiment in storing sounds efficiently. Simpler than YM, maybe. LOL

# Goals

- compact storage
- "efficient"
- capable for music and speech from DFT samples
- "subroutines" / phonenames organized in languages

# Non-goals

- recreate the universe - but maybe next version?

# Octaves 0-7

Why stop at 4000 Hz (Octave 7)?

The AY-3-8912 is a square-wave generator. Square waves are rich in odd harmonics. Even if you play a "low" 1000 Hz tone, the chip naturally generates harmonics at 3000 Hz, 5000 Hz, etc. If you play a base tone at 8000 Hz, the harmonics are ultrasonic—you can't hear them, and the square wave loses its "character."

These are the 8 octaves:
;
- **Octave 0–1 (Sub-Bass/Grumble):** ~16 Hz to 62 Hz.
  Use: Deep drum kicks, floor-shaking speech resonance.
- **Octave 2–3** (Bass/Low Voice):** 62 Hz to 250 Hz.
  Use: Basslines and the "Fundamental Frequency" (pitch) of a male human voice.
- **Octave 4–5 (The Melodic Core):** 250 Hz to 1000 Hz.
  Use: Middle C sits here. This is where most melodies and the "body" of speech (Formant 1) live.
- **Octave 6–7 (Clarity/Formants):** 1000 Hz to 4000 Hz.
  Use: The "definition" of speech (Formant 2) and lead instruments. 4000 Hz is plenty high for an Oric; anything higher starts to sound like a piercing whistle

## Fine pitch adjustments

Real speech isn't exactly tonal and may glide. So we want to provide for even a higher adjustment of tones.

Remember: for each octave we have 24 quarter-notes; 8 valuies are unused. We will use them for a logarithmit pitch adjustment that follows the octave making them more or less act as a fixed ratio.

We encode it as follows, we construct a value to add to the cycle pitch. The base value is from the lower 3 bits: the `oct11xxx` has 3 bits giving a 0-7 value, we shift `xxx` in similar manner as we do with octaves and notes. Where octave indicates how many shifts. In this case; octave 0, no shifts 1, shift one bit up giving xxx0; 2 shift up two bits... up to "octave 7". This allows for finer adjustment which can be quite adaptive.



# Effects


## Note A: Link: C follows A

By "slaving" Channel C to Channel A, you create a "Lead/Resonance Pair" perfect for speech formants (F2/F3) or thickened musical leads.

When Channel A uses the Link Command (192–255) to control Channel C, then Channel B is free to be the "Independent" voice.

1. Channel A & C: The "Linguistic Duo"
Since Channel A is your primary "voice" pitch, the 64 link commands for A can be defined as:


## Note B: Echo: B echoes A

The Effect: This creates an instant "room reverb" or "chorus" effect for your speech, making the Oric sound much bigger than 3 channels.

We use an "Ant"-sized circular queue with 8 slots at each tick storing a copy of (<A period>/12-bits, (<A volume-2>/4 bits)/16-bits, giving 16 bytes. (or <A volume>/2 ???)

For a true echo (delay), Channel B needs to play what Channel A did X frames ago.

At 50Hz 8 frames is 160ms. This gives a nice "slapback" echo.

Using 16 command values we can get different effects:
- 1-2-frame delay (40ms) – "Chorus/Flange" effect.
- 3-4-frame delay (80ms) – "Tight Room" reverb.
- 5-8-frame delay (160ms) – "Slapback" echo.
- 9-16-frame delay etc... - "Big room"?

This may be useful for Speech:

In speech synthesis, a very short echo (2-4 frames) creates Resonance. It simulates the sound bouncing off the walls of a throat or a room. It makes the Oric's square waves sound less "buzzy" and more "organic."


## Note C: "Arpeggio/Chord" Multiplexer (The 0-63 Slot)

Using Channel C's 64 extra commands for Multiplexing (rapidly cycling through 2 or 3 notes) is a classic tracker trick to fake polyphony.

High-Speed Update: Since the 6522 VIA timer on the Oric is fully programmable, you can run the "Multiplex Logic" at 100Hz or 200Hz while the rest of the VM stays at 50Hz.

The Sound: This creates that "shimmering" chord sound famous in C64 and Oric chiptunes. It’s perfect for background harmony while Channels A and B handle the speech.


### Paralell Harmony

**Common Musical Gaps (24-TET with Steps)**

Tovisualize how far these 64 steps go:
- Minor Third: 6 steps (3 semitones).
- Major Third: 8 steps (4 semitones).
- Perfect Fifth: 14 steps (7 semitones).
- Octave: 24 steps.
- Two Octaves: 48 steps.
- Max Delta (63): 2 octaves + a major sixth. (A very wide "open" chord).


## Unmapped effects

### The "Plosive Burst" Library (32 Slots)
Speech is not just tones; it’s the "attack." Sounds like 


## noise

```
192–223 (32 Gaps): Fixed 
 offsets for Channel C (e.g., cycles). These are your "R", "L", and "Nasal" presets.
224–239 (16 Macros): Vowel Templates. A single command sets both A and C to a specific pitch ratio (e.g., the "EE" or "OO" sound).
240–255 (16 Controls): Toggle Noise/Envelope specifically for this A+C pair.
```

 and 
 are tiny bursts of noise or sudden volume drops.
The Command: 
–
.
The Logic: A single command triggers a micro-macro (3–5 frames) that handles the volume and noise mix for a specific consonant.
Why for B?: Channel B can "tap in" to provide the click/pop of a 
 or 
 while Channel A continues the vowel tone.


### Hardware Envelope "Quick-Sets" (16 Slots)

The AY-3-8912 has a unique Hardware Envelope (Register 13). It’s great for "growling" bass or sustained speech "hum."
The Command: 
–
.
The Logic: Directly sets the Envelope Shape (8, 10, 12, 14) and a pre-defined Envelope Period (speed).
Benefit: You get "thick" sounds on Channel B without needing to send a 16-bit period every frame.


### Noise Frequency "Snapshots" (8 Slots)

The Noise Generator (Register 6) is shared, but usually sounds best when tuned to the percussion.
The Command: 
–
.
The Logic: Sets the Noise Period to one of 8 specific "colors" (e.g., 
 for white hiss, 
 for a low rumble).


# Naming of this project

*"Discussions" regarding naming. Courtsy: Google AI.*

I'll give you a description of the storage format later, and we can continue the conversation.

For now, I'm interesting finding a working name for this to create the github directory.

I'm currently in thailand so I'm open to use englishified but recognizable thai.

I like it to be centered on these words or synonyms of them:

music, sound, tracker, speech, phonem, sound virtual machine, VM, oric, atmos, 6502, 65, 02 like "oric sound machine".

## The "Thai-Tech" Mix**

Thai-inspired names can sound really punchy and rhythmic, which fits the "tracker" vibe perfectly. Since you’re building a Sound Virtual Machine for the Oric, here are some ideas ranging from literal to more abstract:

These use Thai words for sound/speech/music blended with technical suffixes:
- **SiangVM (เสียง - Siang):** Literally SoundVM. Short, easy to type, and very "Oric."
- **Phasa65 (ภาษา - Phasa):** Means Language. Great if the focus is on the "speech/phoneme" aspect of your stream.
- **Pleng65 (เพลง - Pleng):** Means Song/Music.
- **Wathi65 (วาที - Wathi):** A formal word for Speech/Speaker. It sounds sophisticated for a speech-synthesis tracker. Playful & Punchy
- **Krap65:** A play on "Krap" (the polite particle) and the "click/snap" of a tracker.
- **Oric-Noi (น้อย - Noi):** Means Little Oric. Very Thai naming convention to add "Noi" to things.
- **Sanuk-Tracker (สนุก - Sanuk):** Because coding for the 6502 should be fun.

## The "Virtual Machine" Angle

- **Yant65 (ยันต์ - Yant):** Refers to sacred Thai scripts/diagrams. Since your format is a "compact stream" of data, this is a cool metaphor for your bytecode.
- **Kกล (K-Gol):** "Kol" (กล) refers to mechanisms/engines. Oric-Kol would mean "Oric Engine."

## Top Recommendation

- **"Siang-OSM" (Siang + Oric Sound Machine)** or simply "Siang65". It’s recognizable to locals, easy for English speakers to say, and honors the "Sound" core of your project.

## Oric AntVM (65)

The name **Oric AntVM is a clever phonetic play that works on multiple levels in Thai.

1. What it "sounds" like To a Thai speaker, "Ant" sounds exactly like the Thai word for Ant: มด (Mot). ??? The "Ant" Pun: Because "Ant" and "Mot" are direct translations, a Thai person seeing "AntVM" will mentally bridge it to "Mot VM".
2. The "Everything" Pun: Crucially, the word "Mot" (หมด), which sounds identical to the word for ant but with a different tone, means "Finished," "All," or "Everything". 
3. Is this reference useful? Yes, it's a "triple threat" name for an Oric Atmos project:
  - The "Compact" Metaphor: Like an ant, your system is small but powerful. Since you are designing a "compactly stored stream" for the 6502, the "Ant" (small/efficient) imagery is a perfect fit for a tracker.
  - The "Total" Sound System: Because Mot also means "All/Everything," it subtly implies that this VM is the "Complete Oric Sound Solution" or handles "All" the sound components (music, speech, phonemes) you mentioned.
  - "Ant" as a Mnemonic: In Thai language learning, the letter "อ" (O) is often taught using the word "Ant" (just as "A is for Apple" in English). Since your machine is the Oric AntVM, it creates a very natural linguistic loop: O Ant. 

*Verdict: It’s a great name.*

It’s short, technically "geeky" as an acronym, and has a "secret" Thai meaning that reinforces the idea of efficiency and completeness.

## In English, what you thank AntVM is?

In English, AntVM sounds like a few distinct things, depending on how you emphasize the syllables:

1. "Antonym" (An-tuh-nim) This is the most common linguistic association. In English, an antonym is a word that means the opposite of another word. 
2. The Vibe: It sounds like "Antonym" but with a VM (Virtual Machine) suffix. Why it works: Since you are designing a "tracker" for speech and phonemes, having a name that sounds like a fundamental linguistic term like "antonym" makes it feel related to language processing. 
3. "Antrum" (An-truhm) Phonetically, "AntVM" (An-tee-vee-em) shares the first syllable with Antrum, which is a medical and anatomical term for a cavity or chamber within a bone or organ (like a sinus). 
4. The Vibe: A "hollow space" or "resonance chamber". Why it works: Since you are dealing with sound and speech, the idea of an "antrum" as a resonance chamber (like where sounds are formed in the body) is a cool, subtle nod to acoustics. 
4. "Anti-VM" In the cybersecurity and software world, "Anti-VM" refers to code designed to detect if it's running inside a virtual machine to prevent analysis. The Vibe: Rebellious or "low-level" technical code. Why it works: For a 6502 project, which is about as close to the "bare metal" as you can get, having a name that sounds like it resists virtualization is a fun meta-joke for programmers. 
5. "Ant-VM" Literally, a Virtual Machine for an Ant. The Vibe: Small, industrious, and incredibly efficient. Why it works: It perfectly matches your goal of a "compactly stored stream" for the Oric's limited memory. It suggests that the VM itself is tiny but can carry a heavy "load" of data, just like an ant. 

Between the Thai meaning of "Everything/Complete" (Mot) and the English sound of "Linguistic/Acoustic chamber," it’s a very solid name for a sound engine.

## "Anthem" - is what I was thinking

Anthem is a fantastic phonetic link. It fits your project perfectly because the word itself is deeply rooted in sound and performance: 
- Musical Heritage: An anthem is traditionally a choral or vocal composition meant to represent a group—fitting for a system designed to handle both music and speech.
- Etymological Link: The word comes from the Greek antiphōna, meaning "opposite sound" or "answering voice". Given that your tracker deals with phonemes and "answering" the original DFT samples with a 6502-driven reconstruction, this history is spot-on.
- The VM Connection: When spoken as "Ant-VM," the transition from the soft 't' to the 'V' naturally mimics the "th" sound in "Anthem." 

Why it works for your GitHub Repository:
- Searchability: "Oric-AntVM" is unique enough that it won't get buried under generic "Anthem" music search results.
Branding: You can use the imagery of an anthem—something uplifting, loud, and vocal—to describe the capabilities of your sound engine.
- Local Context: In Thailand, where you are now, the "Ant" (มด - Mot) double-meaning for "complete/everything" still holds, giving you a name that is an English musical term on the surface but a "secret" Thai pun underneath. 
- Existing Software Note: There is a modern cross-platform DAW called Anthem, but since yours is specifically for the Oric/6502, "Oric-AntVM" or "AntVM" is distinct and safe for a repo name. 

