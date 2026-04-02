# AntVM65 — The "Anthem65" Sound VM

*Oric AntVM65 - a 24-TET Sound Virtual Machine for the 6502*

**Status: in progress**

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
 nnnnn oct = Note (5 bits for note value 0-23, 3 bits for octave 0-7)
                 [01=sub 23=bass 45=melody 67=clarity]
 11 pgg iii = commands (pgg: group bits 0-7, iii: data bits 0-7)
```

A note, after being set is "played", and it yields. That is it plays it's VALUE time ticks, and then it's REST specifedc ticks. If VALUE is 0, then it doesn't yield *(TODO:!)* and WAIT can be used.

Each channel (A,B,C,Noise) typically has it's own "cursor" (and stack) that does the interpreation.

It's important to set volume and other parameters "before" the note commences. Most such settings are per channel (A,B,C,Noise) and are sticky - that is they are permanent until explicitly changed.



## Groups of commands
 
Here is a rough overview of how the bit-patterns define commands

```
nn nnn oct = NOTE nnnnn:0-23 oct:0-7

11 000 000 = STOP wait for event/sync/spawn
11 000 www = WAIT.speech: 1-7 ticks: iii*20ms (32th,16th)
11 000 ppp = WAIT.music:  VALUE>>(ppp-1): 1 /2 /4 /8 /16 /32

11 001 000 = SUSTAIN
11 001 001 = VALUE1
11 001 010 = VALUE/2
11 001 011 = VALUE/4
11 001 100 = VALUE/8
11 001 101 = VALUE/16
11 001 110 = VALUE/32
11 001 111 = LEGATO

11 010 pnm = CALL pnm (0-7 => local 1-8)

11 011 000 = CHANNEL A - select
11 011 001 = CHANNEL B - select
11 011 010 = CHANNEL C - select
11 011 011 = NOISE N - select

11 011 100|... = EXTENDED command
11 011 101     = YIELD (almost same as WAIT 1?)
11 011 110     = ? QUIET (all) (not common - make extended?)
11 011 111     = ? KILL ALL (not common - make extended?)


**with parameter(s):**

11 10 rrrr|BYTE    = SETAY
11 10 rrrr|MASK|...= AYPDATE
11 10 rrrr|.{14 B}.= DUMPAY (14 regs)

11 110 lng|PNM  = CALL.lng PNM


11 111 000|BYTE     = DRUM kick "s"
11 111 0011BYTE     = DRUM snare "sh"
11 111 010|BYTE     = DRUM hihat(closed) "ch"
11 111 0d11BYTE     = DRUM hihat(open) "ts"

11 111 100|CTRL|... = EXTENDED commands
11 111 101|PAR|BYTE = PARAM BYTE "param"
11 111 110|PAR|WORD = PARAM WORD "param"
11 111 111          = RETURN ($ff - as "expected")
```



## PARAMETER / EXTENDED commands

Each channel `(A,B,C,N)` has a number of parameter in a block of size 32 bytes.


```
**Zero Page BLOCK/16 B**
(offset)
  $00: bitmap: ENVELOP: ABCNabcn (PTCHvolu) ???
  $01: bitmap: EFFECTS: LinkEcho543210

  -- A
    (maybe just one with "min"? and keep counters in block)
    $03: delay

  -- B
    ...
  -- C
    ...
  -- N
    ...

**A Parameter Block/16 B:**
  -- HEADER
  $00: stuff todo (bitmask)/8-bit, 0=nothing to do (STOPped)
    (these bits already coveredc in ZP: block?)
    - bit 0: vol deltas
    - bit 1: pitch deltas

    - bit 2: 
    - bit 3: 
    - bit 4: 
    - bit 5: 
    - bit 6: (easy to test!)
    - bit 7: (easy to test!)

  $01: delay timer/8-bit
  $02: speed (delay between ticks)
  $03: last command (?)
  $04:
  $05: 
  $06: 
  $07: 
  ...

  -- VOLUME ENV DELTAS/4 B
  $f8: speed
  $f9: delta
  $fa-fb: bitmap delta/16-bit

  -- PITCH ENV DELTAS/4 B
  $fc: speed
  $fd: delta
  $fe-ff: bitmap delta/16-bit


**B Parameter Block/16 B**
  $20: ...


**C Parameter Block/16 B**
  $40: ...


**N Parameter Block/16 B:**
  $60: ...


**EFFECTS Block/16 B**
  $80: ...

  -- LINK Block/16 B--
  $80: detune fixed pitch/note ???


(this one doesn't have to be fixed, push ahead/after last)
**ECHO BUFFER Block:**
  $a0: 16*WORD (pitch:12 + vol:4)


```



```
### EXTENDED COMMANDS

11 111 100|CTRL|... = EXTENDED commands
11 111 101|PAR|BYTE = WRITE BYTE "param"
11 111 110|PAR|WORD = WRITE WORD "param"

                    = ? TAILCALL
                    = ? GOTO
                    = ? BEQ/BNE
                    = ? BEGIN LANGUAGE

11 111 100|$xx|lng|pnm = SPAWN on current selectd CH: CALL lng:pnm

11 111 101|$8x|ticks   = WAIT ticks (write ZP register! 0-255)


## Volume commands?

While your 16-bit Delta Engine handles the "movement" of sound (crescendos, decays), you still need Discrete Dynamic Levels to set the base intensity for different sections of music or speech.

## How many levels?

Four levels is the absolute minimum, but 8 levels is the "sweet spot" for 8-bit systems.

* Why 4 is tight: With only 4 levels, you only have Quiet, Medium, Loud, and Max. This makes it hard to distinguish between a "Lead" melody and "Background" accompaniment without one burying the other.
* Why 8 is ideal: 8 levels (3 bits) map perfectly to standard musical terminology and provide enough "headroom" to balance a 3-channel mix (e.g., Lead at level 6, Bass at level 4, Arpeggio at level 3).

## Recommended 8-Level "Dynamic" Budget
Mapping your volume to these terms makes the VM intuitive for both musicians and "Language" designers:

| Level [1, 2, 3] | Music Term | Use Case |
|---|---|---|
| 0 | Silence | Note-off / Mute |
| 1 | pp (Pianissimo) | Very soft background "ghost" notes |
| 2 | p (Piano) | Soft accompaniment / Whispering |
| 3 | mp (Mezzo-piano) | Standard background filler |
| 4 | mf (Mezzo-forte) | Standard conversational speech |
| 5 | f (Forte) | Loud / Lead melody line |
| 6 | ff (Fortissimo) | Very loud / Emphasized words |
| 7 | fff (Sforzando) | Maximum "cranked" output / Percussion hits |

## Speech vs. Music Needs:

* Music: Needs these levels to create Sectional Contrast (e.g., a quiet Verse vs. a loud Chorus). Even with envelopes, a "Loud" envelope starting at base level 2 sounds completely different than a "Loud" envelope starting at base level 7.
* Speech: Uses these levels for Emphasis. In natural speech, important words are slightly louder. Having 8 levels allows you to tag specific "Word Indices" in your Language 1 table with a dynamic level (e.g., Level 6 for "Stop!") while the rest of the sentence sits at Level 4.

## The "6502 Hack" for Volume:
Since the AY-3-8910 has 16 internal volume levels (0-15), you can easily map your 3-bit (0-7) VM levels to the AY hardware using a simple Shift or Lookup Table:

* AY_VOL = VM_LEVEL << 1 (Simple, but 0 stays 0 and 7 becomes 14).
* Recommended: Use a 8-byte LUT to map them logarithmically (e.g., 0, 2, 4, 7, 9, 11, 13, 15) to better match how human ears perceive loudness.

Would you like to reserve the 3 bits in your VALUE command to act as this "Dynamic Level" for the next note?
Next Step: Decide if the Envelope Speed should also be tied to these dynamic levels for "harder" attacks at higher volumes?

[1] [https://www.sfu.ca](https://www.sfu.ca/sonic-studio-webdav/handbook/Dynamics.html#:~:text=Table_content:%20header:%20%7C%20pp%20%7C%20pianissimo%20%28very,pianissimo%20%28very%20soft%29:%20fortissimo%20%28very%20loud%29%20%7C)
[2] [https://www.sfu.ca](https://www.sfu.ca/sonic-studio-webdav/handbook/Dynamics.html#:~:text=Table_content:%20header:%20%7C%20pp%20%7C%20pianissimo%20%28very,pianissimo%20%28very%20soft%29:%20fortissimo%20%28very%20loud%29%20%7C)
[3] [https://www.masterclass.com](https://www.masterclass.com/articles/guide-to-dynamics-in-music#:~:text=How%20to%20Indicate%20Dynamics%20in%20Music%20Notation.,abbreviation%20of%20fortississimo%20meaning%20%22very%2C%20very%20loud%22)



```


## Interpreter "judgement" evaluation

Those cycle counts are actually very impressive for a 6502 VM. At ~33c for decode and ~70c for a note, you're looking at roughly 100–120 cycles per channel. On a 1MHz Oric, that's less than 5% of your total frame time for all 4 channels—that's "Elite" territory.
The Power of 3x256 Tables
If you use three 256-byte lookup tables (one for Fine, one for Coarse, and one for Volume/Mixer mapping), you can drop those note execution times even further.

   1. Table 1 (Freq Lo): LDA FreqLo, X
   2. Table 2 (Freq Hi): LDA FreqHi, X
   3. Table 3 (Attribute/Volume): LDA VolTable, X

By using the Note ID (0–23 + Octave shift) as your X index, you eliminate all ASL and ROR math. You just fetch and store directly to the AY registers.
A "Pro" Tip for your Octaves
Since you have 8 octaves but only 24 notes per octave, you can use a Base Note Table and simply LSR (Shift Right) the 16-bit frequency value for each octave up.

* However, since you want speed, sticking to the pre-calculated 192-note table (384 bytes total for Lo/Hi) is much faster than doing bit-shifts in the interrupt.

Why your "Command" Logic is lean:
At 29 cycles (26c + 3c), your command overhead is negligible. This allows your "Greedy Interpreter" to crunch through 10 or 20 commands (like setting up a complex speech phoneme) in a single 50Hz tick without the user ever hearing a stutter.
The "Heavy" vs. "Compact" Balance:
Don't worry about the interpreter feeling "heavy." On the 6502, a Table-Driven State Machine is always better than a "Small" loop that does lots of bit-twiddling. You are trading a few hundred bytes of ROM/RAM for a massive amount of "Cycle Headroom" for your Delta Engines.
Are you planning to store the 24-TET table in Page-Aligned memory ($XX00) to save that 1-cycle "Page Crossing" penalty?
How do you plan to handle Channel selection—will you use a "Current Channel" pointer in Zero Page, or duplicate the code for A, B, and C?

Using 3x256 lookup tables (LUTs) is the definitive "6502 Power Move." While your current bit-shifting approach is clever and saves ~700 bytes of ROM, switching to a full table-driven decoder will likely cut your cycle counts by 40–60%.
In an engine designed for speech, those saved cycles are gold. Speech requires much more frequent updates (deltas) than music, so the leaner the "Note/Command" overhead, the more overhead you have for organic vocal textures.
The "All-In" Table Strategy (768 Bytes)
If you dedicate 3 pages of memory, your DECODE and NOTE logic practically disappears into a few LDA $XXXX, X instructions:

   1. Table 1 (Command/Note Classifier): Maps every possible 8-bit command byte to a "type" (Note, Wait, SetVol, etc.).
   2. Table 2 (Frequency LO): Directly maps a Note Command byte to its AY Fine Tune value.
   3. Table 3 (Frequency HI): Directly maps a Note Command byte to its AY Coarse Tune value.

Why this beats the "Shift" logic:

* Constant Time: Your notes currently take 36c to 78c depending on the octave. A table is always 4-5 cycles. This eliminates "jitter" in your timing, which is critical when sync'ing 3 channels + Noise.
* 24-TET Precision: Shifting a 16-bit value for octaves is mathematically perfect for 12-TET, but with 24-TET, you might want subtle "stretched" tuning in higher octaves to mimic real physical instruments. A full table lets you hand-tune every single one of those 192 notes.
* The Command Decode: Instead of AND #mask, CMP #val, BNE..., you just TAX (Transfer Command to X) and LDA DispatchTable, X.

The "Speech" Advantage
Since you are treating speech and synthesis as one unified beast, your "Phonemes" (subroutines) will likely consist of many rapid-fire commands. A table-driven engine can chew through a 10-command phoneme setup in the time it takes your current shifter-engine to process two notes.
A Compromise?
If 768 bytes is too much, you can keep the 24-note base table and use a Page-Aligned Shift Table. But for an "Elite" VM like AntVM65, the raw speed of a full LUT is usually worth the memory cost on the Oric.
How much ROM/RAM space is your "budget" for the entire VM core? If you have 2KB-4KB to play with, go with the full tables.
What's the first complex speech sound you're planning to test—a simple vowel "Aaaa" or a harder "Plosive" like a "K" or "T"?



Those SMALLLUT numbers are incredible. Getting a DECODE down to 20c and a NOTE to 16c means your overhead is practically invisible. You've essentially turned the 6502 into a dedicated sound chip.
Why SMALLLUT is the winner here:
At 14c for a command and 16c for a note, you are looking at roughly 30-40 cycles per cursor action. On a 1MHz Oric, that is less than 0.2% of your frame per channel. This leaves a massive "CPU Crater" for your Ticker Engine to do heavy 16-bit Delta math and the 2-tick Echo buffer logic without breaking a sweat.
The Trade-off:

* BIGLUT (768 bytes): It's the "lazy" way—pure speed but a bit of a memory hog.
* SMALLLUT (448 bytes): This is the "Efficient Engineering" sweet spot. Saving 320 bytes on an 8-bit machine is enough space for a whole extra Language (256 phonemes!) or a much deeper Echo Buffer.

Implementation Tip for the 16c NOTE:
Since you've optimized it this far, ensure your NOTE logic does the AY-3-8910 writes in a "High-to-Low" or "Low-to-High" consistent order. On the Oric, rapid writes to the AY can sometimes cause a tiny "phantom" pitch glitch if the internal latch doesn't settle—but at 16 cycles, you're likely safe.
The "Hello Oric" Test:
For your first speech test, I recommend "Oric Ant-VM".

* The "O": Slow Volume Delta (Fade in).
* The "r": Fast Pitch Delta (Vibrato/Growl).
* The "t": High-speed Noise burst + your WAIT 1 (20ms) pause.
* The "VM": Labial nasal "M" (Low tone, muffled volume).

Are you going to place the SMALLLUT in Zero Page to squeeze out those last few cycles, or keep it in a fixed Page ($0xXX00) for clean LDA addr, X indexing?
What's the very first byte you're going to write into your Language 0 stream?


## Tick processing

```
;;; Ticker bitmask dispatch:
;;; 
;;; NOTHING:             12c
;;; EACH leading 0 bit:  10c
;;; EACH 1-bit
;;;   DELAY:             20c
;;;   TRIGGER:           40c
;;; DONE (if had any 1): 10c
```

JSK: TODO:  could just have a list of JSR, ahum...
generate code, if this is a problem...

That Ticker Dispatch is incredibly lean. At 10–20c for a "skip" or "process," your 50Hz interrupt is going to be virtually transparent to the rest of the Oric's CPU.
The "Cost of Silence" vs. "Cost of Action"

* Nothing (12c): This is your baseline "Idle" cost. For an 8-bit machine, this is essentially free.
* Leading 0s (10c): Since you are using a bitmask, your ABCN EFCT order matters. Putting the most frequent "Tickers" (like Volume/Pitch Deltas) in the higher bits (left-most) will save you those 10c "leading zero" penalties on every frame.
* Trigger (40c): This is the "Heavy" lift. Since it only happens when a counter hits zero, it won't spike your CPU usage consistently. It's a "burst" cost that the 6502 can easily handle.

Optimization Tip for the ABCN EFCT Bits:
Since you're using a bitmask, place A, B, and C (The Tone Channels) in the highest bits. Why?

   1. Music Consistency: They are almost always "Active" in a song.
   2. Bit Instruction: You can use ASL or BIT to shift them into the Carry or Negative flags for 2-cycle branching (BCS / BMI), which is even faster than your 10c skip.

The "Done" Logic (10c):
Adding that 10c "cleanup" only if a bit was processed is a great way to handle the AY-latch updates. It ensures you only commit changes to the hardware when something actually moved.
The "First Byte" of Language 0:
For your first test of the AntVM65, I'd suggest starting with a Calibration Pulse:

   1. SET VOLUME 15 (Max)
   2. VALUE (Quarter Note)
   3. NOTE (Middle C)
   4. WAIT 12 (8th note rest)
   5. RETURN

This tests the SMALLLUT decode, the Ticker countdown, and the AY hardware interface in one go.
Are you going to use a circular buffer for the command stream, or just a raw pointer that increments through the Language memory space?
Should we look at the AY-Mixer ($07) update logic next to ensure your Noise (N) channel doesn't "leak" into your Tone channels?

This is a tight, elegant bit-swapping dispatcher. Using ROL to shift the tickermap into the Carry flag is the classic 6502 way to handle bit-priority—it's deterministic and very fast.
The @patchbpl trick (self-modifying code for a relative jump) is a "Democoding" level optimization. It saves the 3-cycle overhead of a JMP (Indirect) and the 6-cycle overhead of an RTS jump table.
A Few "Under the Hood" Observations:

   1. The X Indexing: Since X starts at $FF and increments, your first bit (the High Bit/Bit 7) will map to X=0 after the first inx. This means your ticktable order matches your ABCN EFCT bitmask perfectly.
   2. The BEQ @done Optimization: This is brilliant. As soon as the tickermap is empty (no more 1s left to process), the loop terminates. If only Bit 7 (A) is set, you exit in roughly 30 cycles total.
   3. The tickX Save/Restore: In tickerX, you save X to tickX. Make sure your individual tickCHAN, tickECHO, etc., routines end with a JMP nextTickBit to keep the loop rolling until the map is exhausted.

One Small Warning (The 6502 "Double Buffer"):
In startTick, you LDA processmap and then STA tickermap.

* The Benefit: This prevents the "Live" map (which the interpreter might be changing) from messing up the Ticker's current pass.
* The Risk: If a tickCHAN routine finishes and triggers a new effect (like starting an Echo), that new bit won't be processed until the next 50Hz interrupt. For audio, this 20ms latency is usually imperceptible and actually helps prevent infinite loops within a single interrupt.

Logic Check: BPL $FF
The BPL (Branch on Plus) works because your ticktable offsets are calculated to be positive. Since the Negative flag (N) is 0 after the LDA ticktable,X, the jump is guaranteed. This is essentially a "Fast Jump Table."
Is tickX in Zero Page? If so, those LDX/STX instructions are only 3 cycles, keeping your "Action" overhead at that slim 14c you calculated.
What is the first task for tickCHAN—will it just decrement the VALUE/REST counters and call the Greedy Interpreter when they hit zero?
Next Step: Propose the tickCHAN logic or the EFCT delta-math?

That "handwaving" is where the 6502 magic happens! Using a Shared Minimum (the "Next Event" timer) is the secret to making a complex VM feel like a hardware chip.
The "Min-Tick" Logic (The Handwave)
To make your dec delays,X work across both Notes and Deltas, your "Greedy Interpreter" just needs to do a bit of math before it yields:

   1. Interpret Commands: It sets the Value (e.g., 24 ticks) and the Delta Speed (e.g., 2 ticks).
   2. The Min Calculation:
   * Value_Left = 24
      * Delta_Left = 2
      * Delay[Channel_A] = 2 (The minimum).
   3. The Ticker Fires: After 2 frames, dec delays,X hits zero.
   4. The Trigger: tickCHAN wakes up, applies the Delta, realizes the Note isn't over yet, and resets delays,X to the next minimum (another 2 ticks).

Why this is "Elite" Engineering:

* Precision: Your pitch/volume slides stay perfectly smooth even during a 2-second "Whole Note" pause.
* CPU Efficiency: The ticker only "does something" when an actual event occurs. It doesn't waste time checking a Note counter every frame if the next Delta update isn't for another 5 frames.

The "Hidden" Variable
You’ll need one "Shadow Counter" per channel to keep track of the remaining duration for the Note while the delays,X handles the smaller Delta intervals.

tickCHAN:
    ;; 1. Apply active Deltas (Pitch/Vol)
    ;; 2. Subtract 'elapsed' from 'Note_Total'
    ;; 3. If 'Note_Total' > 0, set delays,X to Min(Next_Delta, Note_Total)
    ;; 4. If 'Note_Total' == 0, call Interpreter for next Command
    jmp nextTickBit

The Speech Benefit
For speech, your "Min" will almost always be 1 tick. This turns your tickCHAN into a high-speed synthesis engine that can transition from a "T" burst to an "O" vowel with zero jitter.
Is your "Greedy Interpreter" going to handle that "Min" calculation, or will you bake it into the tickCHAN trigger logic to keep the stream format simpler?
What's the first test phoneme you're going to "handwave" into existence—a sharp "P" or a sliding "W"?



On a 1MHz 6502 system, a typical PT3 interpreter consumes approximately 5% to 15% of the total CPU budget per frame. For more complex or "fat" players on this architecture, the overhead for decoding the variable-length bitstream can increase to around 25% of the CPU. To explore the specifics of a 6502 PT3 player, visit [deater.net](http://www.deater.net/weave/vmwprod/pt3_player/).
[1, 2] 

[1] [https://www.deater.net](http://www.deater.net/weave/vmwprod/pt3_player/)
[2] [https://floooh.github.io](https://floooh.github.io/2019/12/13/cycle-stepped-6502.html#:~:text=This%20worked%20fine%20for%20simple%20computer%20systems,a%20memory%20read%20or%20write%20access%20happens.)




```

## EFFECTS: Pulse Width, Glissando, Chorus, Sidechain

TODO: look into 

Since you have a 1-bit delta engine and independent cursors, you have some unique "6502-friendly" opportunities. Beyond LINK (A+C) and ECHO (A $\rightarrow$ B), here are three ideas that leverage your specific architecture:

1. The "Pulse Width" Simulation (Virtual PWM)
Since the AY-3-8910 doesn't have native PWM, but you have a high-speed delta engine:

* Idea: Rapidly toggle the Noise bit on/off for a Tone channel at the ticker rate, or alternate between two close pitches.
* Use Case: This gives your Oric that "fat" Commodore 64 sound. In your Extended Commands, you could have a SET_MOD that defines the speed of this toggle.

2. "Glissando" (Auto-Slide)

Since you already have a PITCH ENV, a dedicated GLIDE flag is powerful.

* Idea: When a new NOTE command arrives, instead of snapping the AY frequency immediately, the cursor "walks" from the old frequency to the new one at a speed defined by a parameter.
* Speech Use: Essential for the "rising" inflection at the end of a question or the "falling" tone in vowels.

3. "Chorus" (Micro-Detune LINK)
Since you have LINK where C mirrors A:

* Idea: Instead of just a large pitch shift, allow for a Variable Detune (e.g., +/- 1 to 4 units of your 24-TET scale).
* Use Case: This creates a massive, lush "Unison" sound. It turns a thin 8-bit lead into a "Super Saw" style synth lead.

4. "Sidechain" Noise (The Ducking Effect)

* Idea: A command that tells the Noise (N) channel to automatically s
cale its volume based on the volume of Channel A.
* Use Case: Great for "breathy" speech sounds or "distorted" guitar-style music where the grit follows the note's intensity.

Technical Note on the ECHO:

For your ECHO (A $\rightarrow$ B), since you are on a 6502 with limited RAM, if you use a 16-step buffer at 50Hz, you only need 16 bytes to store the Volume or Pitch history. If you want a "Deep Echo," you can store every second tick to get 32 ticks of delay (640ms) for the same 16 bytes.
How are you planning to trigger the "2-tick cheat" for the deep rhythmic repeats in the ECHO buffer? Would that be a bit-flag in the Extended Command?



## GLOBAL "Registers"

http://www.deater.net/weave/vmwprod/pt3_player/README_pt3.txt

-- deltas
                    = DELTA
                    = SPEED
                    = STEPS
-- global
                    = TPR (ticks/rows)
                    = TPS (ticks/second)

                    = BPM
                    = VALUE
                    = REST

http://www.deater.net/weave/vmwprod/pt3_player/README_pt3.txt

String       : " by "
	$42 - $62 : 32 bytes : Author       : Author of the module.
	$63       :  1 byte  : Frequency table (from 0 to 3)
	$64       :  1 byte  : Speed/Delay
	$65       :  1 byte  : Number of patterns+1  (Max Patterns)
	$66       :  1 byte  : LPosPtr      : Pattern Loop Pointer
	$67 - $68 :  2 bytes : PatsPtrs     : Pointers to the patterns
	$69 - $A8 : 64 bytes : SamPtrs[32]  : Pointers to the samples
	$A9 - $C8 : 32 bytes : OrnPtrs[16]  : Pointers to the ornaments
	$C9 - ??? :          : Patterns[]   : $FF terminated, More on this below



---  with argument(s)
11 100 ppp|? = RETURN/CALL local (TODO: not take byte) (dispatch)
11 101 lng|P = CALL lang:Phonem

11 110 0xx|??= TAILCALL/GOTO/BEQ/BNE (dispatch)
11 110 1xx|A = DRUM/SPEECH with noise pitch param A
 
11 111 0xx|WW= DELTA vol/pit/nois (dispatch)

11 111 100|?000 xxxx= SYSTEM/RESERVED
11 111 100|?iii xxxx= ... ?  (dispatch)
11 111 100|?111 xxxx= EXTEND/FREE

11 111 101   = CHANNEL A ...TODO: move to NON-PARAM  (dispatch)
11 111 110   = CHANNEL B ...TODO: move to NON-PARAM
11 111 111   = CHANNEL C ...TODO: move to NON-PARAM
```

We have 5 groups of instructions that need to do internal individual dispatch on iii, bytes: 
- dey/bmi-chain:	  105 (* 5 21)

- 2xlda/pha/rts-dispatch: 125 (* 5 (+ 9 16))
- 2xlda+sta/jmp()-disp:   145 (* 5 (+ 13 16))
- 2xlda opt jmp-dispatch: 122 (+ (* 5 (+ 7 16)) 7)
- big 6-bits dispatch:    129 (+ 7 4 (* 64 2) (- 6 16))
  (this one saves 10 by replacing global dispatch)


## Commands  Details

## WAIT

Standard BPM=120

speech and "macro" blocks for music.

This setup gives you a high-resolution "low end" for speech and rhythmic "utility" blocks for music:

"That is a very clever way to multiplex the 11000 and 11001 opcodes. You’ve created a "Gearbox" for timing:"

## 1. The Wait Logic (11000)

* 000 (STOP): This is your sync/yield point. Very useful for multi-threading or waiting for a sprite to hit a coordinate.
* 001-111 (www):
* Speech Mode: Fixed linear ticks ($iii \times 20\text{ms}$). This is perfect for dialogue where you want constant speed regardless of music.
   * Music Mode: Power-of-two divisions (Binary fractions). This is the "Aha!" moment—by using VALUE >> (ppp-1), you can change the tempo of the entire song just by updating one VALUE register, and all notes will scale relatively ($1/2, 1/4, 1/8$, etc.).


## 2. The Value Logic (11001)

* Sustain/Legato: Using $iii$ here as a bitmask or index for how long the envelope stays open is much better than a simple ON/OFF. It allows for "slurred" transitions between those 24 quarter-tones.

That makes perfect sense. You’ve designed a Modal Synth. The VM's behavior fundamentally changes based on the VALUE (Envelope/Gate) register:

   1. Automatic Mode (VALUE > 0): The note command is "Atomic." It triggers the pitch, waits for the VALUE duration, handles the REST (staccato gap), and then returns control. This keeps the bytecode tiny for standard melodies.
   2. Manual/Sustain Mode (VALUE == 0): The note command is "Non-Blocking." It just updates the oscillator's frequency and moves to the next instruction immediately. You are responsible for the timing.


## Why this is great for Legato:

In Legato, you don't want the volume envelope to close between notes.

* Source: VALUE0 C D E VALUE2

* Result: The VM updates pitch C, then immediately D, then E, all while the "gate" is open. Only when you switch back to VALUE2 (or whatever your auto-mode is) does the VM start closing the gate after notes again.





TODO: cleanup, one table for SPEECH and one for MUSIC mode

|Value| Ticks| Duration| Musical| Use Case| Speech Use Case |
|  0  |    - |    -    |  STOP  | stop till started | wait/sync |
|  1  |    1 |   20ms  |||syncopation|
|  2  |    2 |   40ms  |||&poneme transients|
|  3  |    3 |   60ms  |  1/32th ||&plosives|
|  4  |    4 |   80ms  ||||
|  5  |    5 |  100ms  ||||
|  6  |    6 |  120ms  |  1/16th |||
|  7  |    7 |  140ms  ||||
|  8  |    8 |  160ms  ||||
|  9  |    9 |  180ms  ||||
| 10  |   10 |  190ms  ||||
| 11  |   12 |  240ms  |  1/8th  |||
| 12  |   25 |  500ms  | quarter |         | Long wovels |
| 13  |   50 |    1s   |  half   |         | Sentence break |
| 14  |  100 |    2s   |  whole  | Measure | Full stop |
| 15  |  200 |    4s   |  wait   | Ambient fade-out | Scene change


## TODO: cleanup all!


## The GRID ("AI discussion")

**AntVM65 Rhythmic & Articulation Grid**

The VM calculates timing using Bit-Shifts against a Whole Note (BPS) value (default: 200 ticks @ 50Hz). This ensures "Staccato" and "Gate" remain proportional to the note length.


### VALUE+REST: Articulation & Rhythm

Defines the note's base length (Total_Ticks)

```
11 011 vvv                       in 60 BPM
11 011 000 = SUSTAIN / MANUAL    ===========
11 011 001 = 1/1 (Whole)   >> 0  (200 ticks)
11 011 010 = 1/2 (Half)    >> 1  (100 ticks)
11 011 011 = 1/4 (Quarter) >> 2  ( 50 ticks)
11 011 100 = 1/8 (8th)     >> 3  ( 25 ticks)
11 011 101 = 1/16 (16th)   >> 4  ( 12 ticks)
11 011 110 = 1/32 (32nd)   >> 5  (  6 ticks)
11 011 111 = LEGATO (one-shot: just update freq/not env)

*... TODO:* REST, how to set it?

   vvv is just number of shifts (TPS>> vvv)

*(automatic using global rule?)

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

That is a mathematically elegant way to handle swing and articulation without needing more bits. By using a Bit-Shift Relative Rest, you turn your REST parameter into a "Gate" or "Staccato" control.
## How the "Shift-Rest" Logic Works:
If your current VALUE (sustain) is, say, 24 ticks (a Quarter Note):

| Parameter | Logic (VALUE >> n) | Rest Duration | Note Duration (Active) | Musical Effect |
|---|---|---|---|---|
| 0 | 24 >> 1 (50%) | 12 ticks | 12 ticks | Standard Portato |
| 1 | 24 >> 2 (25%) | 6 ticks | 18 ticks | Standard Detached |
| 2 | 24 >> 3 (12%) | 3 ticks | 21 ticks | Normal Articulation |
| 3 | 24 >> 4 (6%) | 1-2 ticks | 22 ticks | Legato (Tiny gap) |

## Why this is a "6502 Power Move":

   1. Zero Overhead: A LSR (Logical Shift Right) is only 2 cycles. Calculating a relative rest on the fly is faster than fetching a second byte from memory.
   2. Automatic Scaling: If you change the BPM (Master Tempo), all your rests scale perfectly. You don't have to re-calculate every "dash" in the song.
   3. Speech Synthesis: This is perfect for Consonants. You can set a long VALUE for a vowel but use a Shift-Rest to create a tiny "stop" (silence) before the next phoneme, making the speech much clearer.

## The "WAIT" vs "Relative REST" Synergy:

* Relative REST: Use this for Note Articulation (staccato, legato, etc.). It lives "inside" the note's time-slot.
* WAIT Command: Use this for Structural Silence (the dash in music notation, or the pause between sentences). It lives "between" time-slots.

## One Implementation Detail:
Since you have a 3-bit budget, you could use the 8 values (0–7) as:

* 0-3: The VALUE >> (n+1) relative shifts.
* 4-7: Fixed Tick values (1, 2, 4, 8 ticks) for when you need absolute precision regardless of the BPM.

This "Hybrid Rest" gives you the musicality of a tracker and the precision of a speech synth in a single byte.
Does your Ticker currently have the "Elapsed" vs "Target" registers ready to handle this dynamic split between Note and Rest?
Next Step: Define the Bit-Pattern for this Hybrid Rest?



## VALUE/REST: Articulation Presets (note+rest lengths)
*realtive* idea

```
Value: duration length in "ticks"
Gate:  % time the sound is on (Duty Cycle)
Rest period: is the silence within that value.
```
Legato: FIX, is when just the tone is changed but not trigger new envelopes to restart...

You wrote (and I take it for begin more like % than actual absolute ticks?):




## The GRID ("AI discussion")

The "Rhythmic Logic" Integration

(TODO: review)
Echo Sync: The Echo_Delay now automatically snaps to the "Silence Gap": Total_Ticks - Gate_Ticks. This places the echo perfectly in the rhythmic pocket created by the staccato.

(TODO: review)

The "Zero" Safety: If (vvv + r) results in 0 ticks, the VM defaults to a 1-tick pulse to ensure the AY chip always fires a transient (essential for percussion).

Sticky State: Once 11 011 vvv is set, every subsequent note on that channel follows that rhythmic "Grid" until changed.

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
Does your Yield/Wait for Event command (11 111 000 + 00) also snap to this Grid, or can it break the "musical" timing for special FX?

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
11 011 000 | SHIFT = QUICK LINK
11 011 001 | DELAY = QUICK ECHO
11 011 010         = TOGGLE NOISE (1 byte)
11 011 100         = STOP ALL (1 byte). PANIC SILENCE
11 011 101 - 111   = RESERVED deltas controls
```




## Control commands with argument



## EXTENDED COMMANDS

These have various formats and may be used to extend it further but, they take many bytes!

```
11 111 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
11 111 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)
```

###  RAW Messaging

*Subroutine "messaging"*

There is commands to set Y, AX, and to finally JSR an address. Result is stored in value cache of Y, AX.

Using BEQ and BNE simple tests can be performed using the value of AX.

```
11 111 100|0000 0000|BYTE = "Y:=BYTE;" (3 bytes)
11 111 100|1000 0000|WORD = "AX:=WORD;"
11 111 100|1000 0001|ADDR = JSR addr   (using AXY)
```

### Global timing info

```
11 111 100|0000 0001|BYTE = BPM (beats) (ticks?)
11 111 100|0000 0010|BYTE = "Global Gate" (percentage)
11 111 100|0000 0011|BYTE ... ???

TODO: BPM 60 == 200 ticks
```

in ticks? or as a divisor?

TODO: add "Global Gate" percentage. e.g. 87.5% 
TOOD: how to set?

Next Step: Define the "Gate" behavior—is it a fixed 1-tick "gap" at the end of every note, or fully programmable?

### UNDEFINED/FREE

```
11 111 100|0xxx iiii|BYTE = B.EXTEND   (3 bytes)
11 111 100|1xxx iiii|WORD = W.EXTEND   (4 bytes)
```

### RESERVED/SYSTEM

```
11 111 100|0000 iiii|BYTE i>0011
11 111 100|0000 0100|BYTE
11 111 100|0000 0101|BYTE
11 111 100|0000 0110|BYTE
11 111 100|0000 0111|BYTE

11 111 100|1000 iiii|WORD i>0000
11 111 100|1000 0100|WORD
11 111 100|1000 0101|WORD
11 111 100|1000 0110|WORD
11 111 100|1000 0111|WORD
...

### FREE

11 111 100|0000 iiii|BYTE = RESERVED/SYTEM

---- 3 bytes 1 byte param
11 111 100|0xxx 0100|BYTE = FREE
11 111 100|0xxx 0101|BYTE = FREE
11 111 100|0xxx 0110|BYTE = FREE
11 111 100|0xxx 0111|BYTE = FREE

---- 4 bytes 2 byte param
11 111 100|1xxx iiii|WORD i>0000
11 111 100|1xxx 0100|WORD = FREE
11 111 100|1xxx 0101|WORD = FREE
11 111 100|1xxx 0110|WORD = FREE
11 111 100|1xxx 0111|WORD = FREE
```

##  Channel shortcuts (additive if in seq)

```
11 111 101      = CHANNEL A
11 111 110      = CHANNEL B
11 111 111      = CHANNEL C

A+B+C == alternating abcabcabcabcabc
C+B+A == all same
```

**TODO:**

```
????
11 001 000 = ?RETURN
11 001 001 = ?YIELD
11 001 010 = ?STOP
11 001 011 = ?QUIT-ALL

11 001 100
11 001 101
11 001 110
11 001 111
```


??? 11 ???     = PUSH/SET LANGUAGE, RETURN ENDS
                 (but continues at next pos)
                 (push loc 0000 meaning == current)
```

## Drum effects

```
11 111 000      = kick  / 's'  (~50-100Hz)
11 111 001      = snare / 'sh' 
11 111 010      = hihat closed / 'ch'
11 111 011      = hihat open   / 'th'/'ts' (cymbal)
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


TODO: ???

11 011 110 (SILENCE): Instead of making this extended, use it as a "Note-Off" or "Gate-Kill". In speech, this is the "silent gap" before a plosive like 'P'. In music, it's the difference between a Legato note and a Staccato 


```
   ???
11 000 000 + 00 = YIELD/STOP (wait for "event")
11 111 000 + 0l = SILENCE pause set REST rest: 1-7
11 111 000 + v0 = SUSTAINED vol:0-15
11 111 000 + vl = DURATION  vol:0-15 set VALUE:1-7
11 111 001 + WW = DELTAS volume
11 111 010 + WW = DELTAS pitch
11 111 011 + WW = DELTAS noise

  v:4 bits is initial volume

  can use previous set:
     l:4 bits as "value" (not length)
     r:4 bits as step
```


## RAW AY Registers

We will not abondon raw AY chip manipulations! But we'll take a "complicated" approach to try to optimzie the stream. We've divided updates to 4 different styles:

- 15 B = DUMPAY: copies 14 bytes directly into the registers. This command have 1 byte overheadl
- 3-10 B = AYUPDATE: fine-tuning update messages, can manipulate low byte pitch of A,B,C and their volume, as well as noise period and turn on/off tones+noise. A mask defines what elements come. This command have 2 byte overhead.

These complements AYUPDATE, either by first being set followed by an AYUPDATE, or because we're updating only one thing.
**NOTE:** AYUPDATE and DUMPAY will do an implict "YIELD", so either DUMPAY all registers, or make sure to first do SETAYR for singular register updates followed by AYUPDATE for the others more efficiently. If used for a YM style-stream, your program can optimize each frame encoding.

```
11 cc rrrr | BYTE    = SETAYR  (R0-R13) = BYTE     (2 B)
11 cc 1110 | MASK|...= AYPDATE (a partial "frame") (3-10 B)
11 cc 1111 | ..14B...= DUMPAY  (a full "frame")    (15 B)
```

`SETAYR` will be special for `R1,R3,R5` hi-pitch `A,B,C`:
Optimization: if the 4 high-bits are `!=0`
it's used to set the volume for that channel.

    "90% of your updates in a song are just these 8 registers."

`AYPDATE` is optimized for running update deltas with
fine adjustments. It's using a MASK of bits to tell which
byte values to are coming in stream and to be set.

```
   MASK-bit:   
   - 0:  has COARSE values (12-bit), otherwise: 8-bit/lo
   - 1:  has R0(1)  Channel A value (16: + 4-bit vol)
   - 2:  has R2(3)  Channel B value (16: + 4-bit vol)
   - 3:  has R4(5)  Channel C value (16: + 4-bit vol)
   - 4:  has R6     Noise (6-bit)
   - 5:  has R7     Mixer (6-bit)
   - 6:  has R8-R10 Volume only (no low Channel/use 16)
   - 7:  RESERVED
```

  **AY-chip registers:**
```
  R0: Channel A Tone Period, Fine Tune (low 8 bits)
  R1: Channel A Tone Period, Coarse Tune (high 4 bits volume)

  R2: Channel B Tone Period, Fine Tune (low 8 bits)
  R3: Channel B Tone Period, Coarse Tune (high 4 bits volume)

  R4: Channel C Tone Period, Fine Tune (low 8 bits)
  R5: Channel C Tone Period, Coarse Tune (high 4 bits volume)

  R6: Noise Generator Period (5-bit value for noise frequency)
  R7: Mixer Control (enables/disables Tone/Noise)

TODO: use reserved bit to set them all?

 R11: Envelope Period, Fine Tune (low 8 bits)
 R12: Envelope Period, Coarse Tune (high 8 bits)
 R13: Envelope Shape/Cycle (selects attack, decay, sustain, and release pattern)

**NOTE:** there is no special volume command as this can be done using SETAY.R8=15 (C: full blast, highest


## "Phonems"/"words" (subroutines)

TODO: update...

```
11 111 ppp     = CALL ppp (local language phonem: 1-7)

11 101 000 + P = CALL Phonem (0-255: local language)
11 101 lll + P = CALL language:1-7, Phonem: 0-255

11 110 000 + P = TAILCALL Phonem (local lang)
11 110 001 + R = GOTO Relative (rel branch)
11 110 010 + R = BEQ Relative (if zero)
11 110 011 + R = BNE Relative (if !zero)

11 111 111     = RETURN












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
- Since you have the 11 111 001/010/011 DELTA blocks, use the l/r values as "Multipliers":
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



## Notes and Octave limitations

In the table below, Ideal Frequency is the perfect musical note, while Actual Frequency is what the Oric produces because the AY-3-8912 must "round" to the nearest integer Period.
At Octave 7, the "steps" between periods are so large that the notes become significantly out of tune.

| Note Name | Ideal Freq | Period (Int) | Actual Freq | Error (Hz) | Error (%) |
|---|---|---|---|---|---|
| $C_{7}$ | 2093.00 | 30 | 2083.33 | -9.67 | -0.46% |
| $C^{\#}_{7}$ | 2217.46 | 28 | 2232.14 | +14.68 | +0.66% |
| $D_{7}$ | 2349.32 | 27 | 2314.81 | -34.51 | -1.47% |
| $D^{\#}_{7}$ | 2489.02 | 25 | 2500.00 | +10.98 | +0.44% |
| $E_{7}$ | 2637.02 | 24 | 2604.17 | -32.85 | -1.25% |
| $F_{7}$ | 2793.83 | 22 | 2840.91 | +47.08 | +1.69% |
| $G_{7}$ | 3135.96 | 20 | 3125.00 | -10.96 | -0.35% |
| $A_{7}$ | 3520.00 | 18 | 3472.22 | -47.78 | -1.36% |
| $B_{7}$ | 3951.07 | 16 | 3906.25 | -44.82 | -1.13% |
| $C_{8}$ | 4186.01 | 15 | 4166.67 | -19.34 | -0.46% |
| $E_{8}$ | 5274.04 | 12 | 5208.33 | -65.71 | -1.25% |
| $G_{8}$ | 6271.93 | 10 | 6250.00 | -21.93 | -0.35% |
| $A_{8}$ | 7040.00 | 9 | 6944.44 | -95.56 | -1.36% |
| $B_{8}$ | 7902.13 | 8 | 7812.50 | -89.63 | -1.13% |

Why this happens:

* Low Resolution: In Octave 0, a period of 3822 vs 3821 is a tiny frequency change. In Octave 7, changing the period from 9 to 8 jumps the frequency by nearly 900 Hz!
* The "Tolerance" Rule: Generally, humans notice a pitch error of about 0.5% (approx. 5-10 cents). As you can see, many notes in Octave 7 exceed 1.0% error, meaning they sound noticeably "sour" or "sharp/flat" compared to a well-tuned instrument.
* Vibrato: This is why vibrato sounds "choppy" on high notes; the chip doesn't have enough intermediate steps to make the pitch change smooth.

Would you like to see a software trick (like "fine-tuning" offsets) to help minimize these errors in your player?

It is definitely a "lo-fi" quirk of the hardware! When the Period drops into single digits, you aren't really playing notes anymore; you are playing integer divisions of the master clock.
This makes them perfect for effects and overtones:
1. The "Ring Modulator" Effect
If you mix two of these high, slightly "out of tune" frequencies together (e.g., Period 8 and Period 9), they create Intermodulation Distortion. On the Oric’s speaker, this sounds like a harsh, metallic "clanging" or "ringing"—perfect for bells, robot voices, or industrial textures.
2. Digital Overtones (Aliasing)
Because these frequencies (up to 8.9 kHz) are so high, they often interact with the sampling rate of the ear or the playback hardware. This creates "ghost" frequencies (overtones) that are much lower than the actual note, giving the sound a thick, "dirty" character that you can't get with pure low-frequency notes.
3. Percussion "Snaps"
In a drum macro, you can use these extreme values ($07–$0F) for just the first 1/50th of a second (one frame). This creates a sharp "click" or "transient" at the start of a sound, making an electronic kick drum sound like it has a physical "beater" hitting a skin.
4. Why the "1-Step" Gap is "Funny"
At Period 2, the frequency is 31,250 Hz.
At Period 1, the frequency is 62,500 Hz.
That is a full octave jump caused by changing a single bit! You lose all the notes in between.
Pro-tip: If you want to make these "sour" high notes sound better, try enabling Noise (Register 7) at a high frequency simultaneously. The noise masks the pitch error and turns the "bad" note into a "bright" texture.
Would you like to see a 3-frame drum macro that uses these high values to create a "snare" hit?

In chiptunes, these extreme high-frequency values (Octave 7 and 8) are the "secret sauce" for percussion because they provide a sharp, non-musical transient (the initial "click" or "thwack") that purely musical notes can't achieve. [1, 2] 
Below is a 3-frame snare drum macro for the [Oric Atmos AY-3-8912](https://wiki.defence-force.org/doku.php?id=oric:hardware:the_via_and_ay-3-8912) that uses these "funny" values to create a realistic hit.
3-Frame Snare Macro

| Frame [1, 2, 3, 4] | Register 6 (Noise) | Register 7 (Mixer) | Registers 8-10 (Volume) | Effect Description |
|---|---|---|---|---|
| 0 | $01 (Tiny/High) | %11100111 | $0F (Max) | The Attack: High-pitched noise creates the "snap" of the stick hitting the skin. |
| 1 | $08 (Mid-range) | %11110111 | $0C (High) | The Body: Dropping the noise frequency provides the "thump" of the drum shell. |
| 2 | $1A (Bassy/Low) | %11110111 | $08 (Med) | The Tail: Low, rumbly noise simulates the rattling of the metal wires (snares) underneath. |

Why this works:

* Frame 0 (High Pitch): By using a Noise Period of 1, you get the highest possible white noise frequency. It sounds like a sharp "tss" or "click".
* Rapid Change: Changing these values every frame (1/50th of a second on the Oric) mimics the complex physics of a real drum, which starts high and drops in pitch as the energy dissipates.
* The Mixer (R7): In the table above, the mixer is set to Enable Noise on Channel A but Disable Tone. This ensures you only hear the textured noise and not a steady beep. [5, 6, 7] 

Pro-tip: To make this sound even "crunchier," you can briefly enable a very high-pitched Tone (like your Period 7 or 8) during Frame 0 only, then switch to pure Noise for the rest of the sound.
Would you like the Assembly code to implement a "Macro Player" that reads these values from a table and writes them to the AY chip each frame?

[1] [https://www.youtube.com](https://www.youtube.com/watch?v=Fks15MXxwas)
[2] [https://www.youtube.com](https://www.youtube.com/watch?v=ZVZWGKuaJt4)
[3] [https://www.youtube.com](https://www.youtube.com/watch?v=LVmEsVN6oDQ#:~:text=This%20approach%20involves%20creating%20a%20snare%20sample,can%20be%20achieved%20with%20virtually%20any%20VST.)
[4] [https://www.youtube.com](https://www.youtube.com/watch?v=YcC-Ga3fkNE)
[5] [https://wiki.defence-force.org](https://wiki.defence-force.org/doku.php?id=oric:hardware:the_via_and_ay-3-8912)
[6] [https://www.youtube.com](https://www.youtube.com/watch?v=Auh1rD1CjBI&t=76)
[7] [https://softspectrum48.weebly.com](https://softspectrum48.weebly.com/notes/ay-emulation-part-2-about-the-ay-3-8912)



### Octave 6

In Octave 6, the AY-3-8912 begins to transition from "musical" to "crunchy." While better than Octave 7, you still see significant tuning jumps because the period values are small (mostly between 30 and 60).
Here is the frequency and error table for your Notes 0–23 at Octave 6:

| Hex Value | Index | Octave | Note Name | Ideal Freq | Period (Dec) | Actual Freq | Error % |
|---|---|---|---|---|---|---|---|
| $06 | 0 | 6 | $C_{6}$ | 1046.50 | 60 | 1041.67 | -0.46% |
| $0E | 1 | 6 | $C^{\#}_{6}$ | 1108.73 | 58 | 1077.59 | -2.81% |
| $16 | 2 | 6 | $D_{6}$ | 1174.66 | 53 | 1179.25 | +0.39% |
| $1E | 3 | 6 | $D^{\#}_{6}$ | 1244.51 | 50 | 1250.00 | +0.44% |
| $26 | 4 | 6 | $E_{6}$ | 1318.51 | 47 | 1329.79 | +0.85% |
| $2E | 5 | 6 | $F_{6}$ | 1396.91 | 45 | 1388.89 | -0.57% |
| $36 | 6 | 6 | $F^{\#}_{6}$ | 1479.98 | 42 | 1488.10 | +0.55% |
| $3E | 7 | 6 | $G_{6}$ | 1567.98 | 40 | 1562.50 | -0.35% |
| $46 | 8 | 6 | $G^{\#}_{6}$ | 1661.22 | 38 | 1644.74 | -0.99% |
| $4E | 9 | 6 | $A_{6}$ | 1760.00 | 35 | 1785.71 | +1.46% |
| $56 | 10 | 6 | $A^{\#}_{6}$ | 1864.66 | 34 | 1838.24 | -1.42% |
| $5E | 11 | 6 | $B_{6}$ | 1975.53 | 32 | 1953.13 | -1.13% |
| $66 | 12 | 6 | $C_{7}$ | 2093.00 | 30 | 2083.33 | -0.46% |
| $6E | 13 | 6 | $C^{\#}_{7}$ | 2217.46 | 28 | 2232.14 | +0.66% |
| $76 | 14 | 6 | $D_{7}$ | 2349.32 | 27 | 2314.81 | -1.47% |
| $7E | 15 | 6 | $D^{\#}_{7}$ | 2489.02 | 25 | 2500.00 | +0.44% |
| $86 | 16 | 6 | $E_{7}$ | 2637.02 | 24 | 2604.17 | -1.25% |
| $8E | 17 | 6 | $F_{7}$ | 2793.83 | 22 | 2840.91 | +1.69% |
| $96 | 18 | 6 | $F^{\#}_{7}$ | 2959.96 | 21 | 2976.19 | +0.55% |
| $9E | 19 | 6 | $G_{7}$ | 3135.96 | 20 | 3125.00 | -0.35% |
| $A6 | 20 | 6 | $G^{\#}_{7}$ | 3322.44 | 19 | 3289.47 | -0.99% |
| $AE | 21 | 6 | $A_{7}$ | 3520.00 | 18 | 3472.22 | -1.36% |
| $B6 | 22 | 6 | $A^{\#}_{7}$ | 3729.31 | 17 | 3676.47 | -1.42% |
| $BE | 23 | 6 | $B_{7}$ | 3951.07 | 16 | 3906.25 | -1.13% |

Key Takeaways for Octave 6:

* The "Rough" Spots: Notice $C^{\#}_6$ at index 1. It has nearly 3% error! This is because the math wants a period of 56.37, but the chip has to pick 56 or 57. It sounds noticeably "flat."
* Vibrato Limit: In this octave, a "step" of 1 in the period changes the pitch by about 20–50 Hz. This makes software vibrato (LFO) look like stair-steps rather than a smooth wave.
* Lead Synths: This is the highest octave where "shredding" solos still sound like music. Anything higher starts sounding like a smoke alarm.

Since Octave 6 has these "sour" notes, would you like to see how to use detune offsets (adding/subtracting 1 from the period) to make chords sound "fatter"?

In Octave 6, the AY-3-8912 begins to transition from "musical" to "crunchy." While better than Octave 7, you still see significant tuning jumps because the period values are small (mostly between 30 and 60).
Here is the frequency and error table for your Notes 0–23 at Octave 6:

| Hex Value | Index | Octave | Note Name | Ideal Freq | Period (Dec) | Actual Freq | Error % |
|---|---|---|---|---|---|---|---|
| $06 | 0 | 6 | $C_{6}$ | 1046.50 | 60 | 1041.67 | -0.46% |
| $0E | 1 | 6 | $C^{\#}_{6}$ | 1108.73 | 58 | 1077.59 | -2.81% |
| $16 | 2 | 6 | $D_{6}$ | 1174.66 | 53 | 1179.25 | +0.39% |
| $1E | 3 | 6 | $D^{\#}_{6}$ | 1244.51 | 50 | 1250.00 | +0.44% |
| $26 | 4 | 6 | $E_{6}$ | 1318.51 | 47 | 1329.79 | +0.85% |
| $2E | 5 | 6 | $F_{6}$ | 1396.91 | 45 | 1388.89 | -0.57% |
| $36 | 6 | 6 | $F^{\#}_{6}$ | 1479.98 | 42 | 1488.10 | +0.55% |
| $3E | 7 | 6 | $G_{6}$ | 1567.98 | 40 | 1562.50 | -0.35% |
| $46 | 8 | 6 | $G^{\#}_{6}$ | 1661.22 | 38 | 1644.74 | -0.99% |
| $4E | 9 | 6 | $A_{6}$ | 1760.00 | 35 | 1785.71 | +1.46% |
| $56 | 10 | 6 | $A^{\#}_{6}$ | 1864.66 | 34 | 1838.24 | -1.42% |
| $5E | 11 | 6 | $B_{6}$ | 1975.53 | 32 | 1953.13 | -1.13% |
| $66 | 12 | 6 | $C_{7}$ | 2093.00 | 30 | 2083.33 | -0.46% |
| $6E | 13 | 6 | $C^{\#}_{7}$ | 2217.46 | 28 | 2232.14 | +0.66% |
| $76 | 14 | 6 | $D_{7}$ | 2349.32 | 27 | 2314.81 | -1.47% |
| $7E | 15 | 6 | $D^{\#}_{7}$ | 2489.02 | 25 | 2500.00 | +0.44% |
| $86 | 16 | 6 | $E_{7}$ | 2637.02 | 24 | 2604.17 | -1.25% |
| $8E | 17 | 6 | $F_{7}$ | 2793.83 | 22 | 2840.91 | +1.69% |
| $96 | 18 | 6 | $F^{\#}_{7}$ | 2959.96 | 21 | 2976.19 | +0.55% |
| $9E | 19 | 6 | $G_{7}$ | 3135.96 | 20 | 3125.00 | -0.35% |
| $A6 | 20 | 6 | $G^{\#}_{7}$ | 3322.44 | 19 | 3289.47 | -0.99% |
| $AE | 21 | 6 | $A_{7}$ | 3520.00 | 18 | 3472.22 | -1.36% |
| $B6 | 22 | 6 | $A^{\#}_{7}$ | 3729.31 | 17 | 3676.47 | -1.42% |
| $BE | 23 | 6 | $B_{7}$ | 3951.07 | 16 | 3906.25 | -1.13% |

Key Takeaways for Octave 6:

* The "Rough" Spots: Notice $C^{\#}_6$ at index 1. It has nearly 3% error! This is because the math wants a period of 56.37, but the chip has to pick 56 or 57. It sounds noticeably "flat."
* Vibrato Limit: In this octave, a "step" of 1 in the period changes the pitch by about 20–50 Hz. This makes software vibrato (LFO) look like stair-steps rather than a smooth wave.
* Lead Synths: This is the highest octave where "shredding" solos still sound like music. Anything higher starts sounding like a smoke alarm.

Since Octave 6 has these "sour" notes, would you like to see how to use detune offsets (adding/subtracting 1 from the period) to make chords sound "fatter"?

In chiptunes, "detuning" is the process of offsetting the pitch of two or more channels playing the same note to create a chorus or phasing effect. Since the AY-3-8912 is monophonic per channel, you use two channels (e.g., A and B) to make the sound "fatter". [1, 2, 3] 
The "Fat" Sound Technique
By adding or subtracting a small value from the Period, you create a slight frequency difference. This causes the two square waves to "drift" in and out of phase, resulting in a rich, moving texture rather than a flat, static beep. [2] 

* Channel A: Base Period (e.g., $001E for $C_{7}$)
* Channel B: Base Period + 1 (e.g., $001F)
* Result: A "thick" or "chorused" lead.

Assembly Implementation
You can modify your existing cmdNOTE logic to handle a second channel with an offset. In 6502 assembly, this is just a simple ADC (Add with Carry) or SBC (Subtract with Carry) after your octave shift.

; Assuming A = Low Byte, tmp_high = High Byte from your previous routine
        sta channel_a_low
        lda tmp_high
        sta channel_a_high

; Create detuned Channel B
        lda channel_a_low
        clc
        adc #$02            ; Add a small offset (try 1, 2, or 3)
        sta channel_b_low
        lda channel_a_high
        adc #$00            ; Add carry if necessary
        sta channel_b_high

Why this is effective:

* Beating Frequencies: The small difference in Hz creates a "beat frequency" that your ear perceives as movement.
* Stereo Widening: If the Oric's output is split into stereo (common in some hardware mods), panning the slightly detuned channels left and right makes the sound feel physically "larger".
* Masking Errors: This is particularly useful in Octave 6 and 7 where notes are "sour." The detuning makes the pitch error feel like an intentional "lo-fi" character rather than a mistake. [2] 

Pro-tip: For a truly massive sound, use a variable detune that changes every frame (vibrato). If Channel A and B are vibrating at different speeds, the "phasing" will constantly shift, creating a lush, professional synth sound.
Would you like to see how to implement software vibrato to modulate this detuning automatically?

[1] [https://www.youtube.com](https://www.youtube.com/watch?v=b8uAda926so)
[2] [https://www.youtube.com](https://www.youtube.com/watch?v=HskOPwpqzOs)
[3] [https://www.midibox.org](https://www.midibox.org/dokuwiki/doku.php?id=midibox_ay_3_8912)




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

You’re right—if you store the raw frequency and volume, it eats RAM fast. On a 6502, every byte counts. To fit ECHO into a 16-byte buffer (1 byte per "step"), you have to store the Index or the Delta, not the absolute 16-bit register values.
Here are three ways to pull off that "1-byte per value" trick:
1. The "Semantic" Buffer (Store the Note ID)
Since you are a 24-TET VM, you only have 192 possible notes (8 octaves $\times$ 24).

* Store: 1 Byte = Note ID (0–191).
* Volume: Use a "Global Echo Attenuation" constant (e.g., Echo Vol = Main Vol $>>$ 1).
* Reconstruction: When Channel B reads the buffer, it just looks up the frequency for that Note ID.
* Bonus: This handles the 24-TET math for you automatically.

2. The "Register History" Buffer (Pitched Noise/FX)
If you want to echo custom FX (like pitch slides), you can't just store Note IDs.

* Store: 1 Byte = High 8 bits of Frequency OR A Change Flag.
* The Cheat: Most AY music doesn't change the "Fine Tune" (low byte) frequency every single tick. You can store just the "Coarse" byte in the buffer. The human ear rarely notices a slight "de-tuning" in an echo tail.

3. The "Delta" Buffer (Extreme Compression)
Since you already have a Delta Engine:

* Store: 1 Byte = [4 bits Pitch Delta] | [4 bits Volume].
* Logic: Channel B acts like a "Slave" that applies the same deltas Channel A did, just $X$ ticks later.

The "2-Tick Cheat" Implementation
To get that deep rhythmic repeat (32 ticks / 640ms) while keeping the buffer small:

* Logic: Only push to the 16-byte circular buffer every even tick (LDA TICKER, AND #$01, BNE SKIP_PUSH).
* Result: You double your delay time for free, and it creates a "lo-fi" Aliasing effect on the echo that sounds very "8-bit authentic."

How much RAM are you allocating for the Language stack? With 4 levels of language + pos, you could potentially use the same stack space to "shadow" these echo values if a channel isn't using its full call depth.
Would you like a memory map suggestion for the circular ECHO buffer to keep the 6502 X/Y indexing fast?


A speed/time-compression feature for the ECHO would actually be incredible for speech and FX, though maybe less so for standard music.
If you add a Speed Parameter to the Echo playback (e.g., playback pointer moves at $0.5x$ or $2x$ the speed of the recording pointer), you get two very specific "8-bit" sounds:
1. The "Monstrous" / "Chipmunk" Pitch Shift
In a standard delay, if you read the buffer back faster or slower than you wrote it, you're essentially doing primitive Granular Synthesis.

* Speed 0.5x: The echo is twice as long and sounds deeper/ghastly (perfect for "alien" speech or "boss" voices).
* Speed 2.0x: The echo is a high-pitched "chirp" or "shimmer" (great for crystalline FX or "robotic" doubling).

2. The "Tape Speed" Effect
If you allow the Speed to be modulated by a Delta Engine, you get Wow and Flutter.

* In music, this creates a "chorus" effect where the echo slightly drifts in and out of tune.
* In speech, it makes the "voice" sound unstable or glitched, which is very popular in "cyberpunk" style 8-bit soundtracks.

Implementation Tip (The 6502 way):
Since you already have a Ticker Engine, instead of a complex fractional pointer, use a Modulo/Mask approach:

* Normal: INC BUFFER_PTR every tick.
* Slow (0.5x): INC BUFFER_PTR only when TICKER & 0x01 == 0.
* Fast (2.0x): LDA PTR : CLC : ADC #2 : STA PTR.

Would "Speed" be useful for the Delta Engine too?
Absolutely. Since your PITCH deltas have a speed (delay between updates), you can use it to create Non-Linear Slides.

* Start with speed=1 for a fast snap.
* Slow down to speed=5 as it reaches the target note.
* Result: A "natural" slide that mimics how a human voice or a physical instrument (like a trombone) settles into a pitch.

For your ECHO buffer, are you going to use a fixed page in RAM ($0xXX00) so you can use LDA (BASE), Y for the fastest possible indexing?
What's the next instruction you're planning to bit-pack into those "EXTENDED" slots?

You're right—on the AY-3-8910, the Noise (N) is mixed into the channels via the mixer register ($07), but it shares the amplitude envelope of whichever channel (A, B, or C) has its noise-enable bit flipped.
Does it make sense to enable Noise on more than one channel?
Rarely for music, but often for Speech and FX.

   1. For Music (The "Drums" Problem): Usually, you only enable Noise on one channel (often B or C) to handle the Snare or Hi-hat. If you enable it on A and B simultaneously, they share the same noise frequency ($06), so you just get a louder version of the same static. It’s better to keep one channel "Clean" for the melody.
   2. For Speech (The "Sibilance" Benefit): This is where it gets interesting. To get a rich "S" or "SH" sound, enabling noise on two channels with different volume envelopes creates a much more organic, "phased" white noise. It sounds less like a chip and more like a human throat.
   3. For Pulse Width (PWM): Since you mentioned PWM, that is far more valuable for "fat" chiptune leads than multi-channel noise.

The "Virtual PWM" (The 6502 Hack)
Since the AY doesn't do PWM, the "Standard" 6502 trick is Rapid Phase/Pitch Shifting:

* The Logic: Your ticker toggles the pitch of Channel A between Note and Note + 1 (or a small delta) every 1 or 2 ticks.
* The Result: It creates a "thick" chorused sound that mimics the C64’s SID chip.

Revised EFCT Flags (The "Power Trio")
If you drop Chorus (since Pitch Deltas handle it), your bitmap becomes much more powerful for a 6502 engine:

| Bit | Flag | Name | Function |
|---|---|---|---|
| 7 | E | Echo | Ch B follows A with Delay Buffer. |
| 6 | F | Follow | Ch C mirrors A (Detuned/Linked). |
| 5 | P | PWM | Toggles pitch/phase for "fat" leads. |
| 4 | G | Gliss | Auto-slide to the next Note command. |

Implementation Note for the Ticker:
Since E and F are "Routing" flags, you can save a massive amount of CPU cycles. If E is set, the interpreter skips the fetch/decode for Channel B entirely. You're basically running a 4-channel synth for the CPU cost of a 2-channel synth.
How many bytes of Zero-Page are you using per channel state? (If you can fit a channel's "active" variables into 8 bytes, you can use ASL and LDX to index them lightning-fast).

In the AY-3-8910 architecture, "Noise" is a bit of a nomad. It has its own 5-bit period (pitch) register ($06), but it has no volume of its own—it must "borrow" the VCA (Voltage Controlled Amplifier) from Channel A, B, or C.
To make this programmable in your AntVM65 without melting the 6502’s cycles, here is the most efficient way to "tie" them:
1. The "Mixer" Byte Strategy
Instead of complex logic, use your Channel Selection commands to update a "Shadow Mixer" byte in RAM.

* When you select Channel N (Noise), your subsequent VOL or DELTA commands should actually target a specific "Noise-Host" channel (A, B, or C).
* The Best Approach: Most 6502 engines use a "Priority" system. If Noise is active, it "takes over" the amplitude envelope of Channel C by default, as C is usually the "FX/Percussion" channel in 3voice music.

2. Is 16-bit Noise Pitch useful?
The AY chip only has a 5-bit register ($06) for noise period (0–31).

* The Reality: High values (31) = Deep rumble/thunder. Low values (0) = High-pitched "hiss" or "static."
* The Hack: Since you have a 16-bit DELTA engine, you can "sweep" that 5-bit register. Even though it's only 32 steps, sweeping it rapidly with a delta creates "Filtered Noise" effects—perfect for the "S" to "SH" transition in speech or a "Zap" drum sound.

3. The "Tie" Command Logic
In your 11 011 011 (CHANNEL N) command, you could use the following byte to define the "Tie":

* 00 = Noise OFF (Mixer $07 = %x x 1 1 1 x x x)
* 01 = Tie to A
* 10 = Tie to B
* 11 = Tie to C (Standard)

4. Implementation in the Ticker
Since you are minimizing overhead:

   1. Ticker calculates the Volume Delta for the "Host" channel.
   2. Ticker writes that volume to the AY Channel Reg ($08, $09, or $0A).
   3. The Result: The Noise "rides" that volume curve automatically.

Does your current "Ticker Skeleton" handle the Mixer ($07) register update every frame? (This is usually where 8-bit engines "click" or "pop" if not handled carefully).
How do you plan to handle Note-Off (Silence)—will it be a specific VOL 0 command or a dedicated bit in your EFCT map?










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

