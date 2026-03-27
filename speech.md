Since your vowel sounds rely on 24-TET (which is perfect for the subtle pitch shifts in human speech) and your 1-bit delta envelopes, the "vowel" part of your tracker isn't a one-shot command like the drums. Instead, it’s a state-based instrument.
To create vowels on the AY chip, you are essentially simulating Formants (resonant frequencies of the vocal tract). While true formants usually require multiple oscillators, you can "fake" them by using your Ticker Manager to oscillate the pitch or volume rapidly.
Vowel Guide (The "A-E-I-O-U" Palette)
Since you have a 1-bit delta stream for pitch/vol, use these "recipes" to define your envelopes:

| Vowel | 24-TET Base Note | Pitch Envelope (Delta) | Vol Envelope (Delta) | Description |
|---|---|---|---|---|
| "AH" (A) | Low (Oct 2-3) | Steady / Flat | High, Wide Open | The most "open" sound. Use a flat pitch. |
| "EE" (E) | High (Oct 4-5) | Slight upward ramp | Narrow / Lower Vol | Higher frequency resonance. Sharp and piercing. |
| "OO" (U) | Very Low (Oct 1-2) | Downward slide | Muted / Filtered | Sounds "hollow." Use your frequency slide to drop the pitch. |
| "OH" (O) | Mid (Oct 3) | Vibrato (Fast Delta) | Rounded | Use a repeating 1-bit delta to create a fast pitch wobble. |

The "Speech" Workflow in your Tracker
To make words, you would sequence your Drum/Sibilant BLOCK and your Vowel Notes back-to-back:

   1. Line 01: Y=4, A=$20 (The "P" plosive from cmdKickS)
   2. Line 02: Note: Oct 3, Note 12 + Vol Env: "AH" (The "A" vowel)
   3. Line 03: Y=7, A=$05 (The "S" sibilant from cmdHiHatOpenTS)
   * Result: You just "said" the word "PASS".
   
1-Bit Delta Encoding Tip
For vowels, your 1-bit delta stream is your best friend for Vibrato.

* A stream of 10101010 at a high "ticks per bit" speed will create a tiny pitch oscillation that makes a raw AY tone sound much more "vocal" and less like a computer beep.

Do you want to define a specific "Vibrato" delta-stream pattern that we can use as a default for all 'voiced' speech notes?

To get a convincing "human" sound out of the AY chip, you really want to use both, but they serve different purposes in your 1-bit delta architecture.
In speech synthesis, Pitch Deltas simulate the "Prosody" (the inflection and vibration of vocal cords), while Volume Deltas simulate the "Mouth Shape" (the filtering/constriction of air).
1. The Pitch Delta (Vibrato & Inflection)
Since the AY chip produces a very "pure" square wave, it sounds like a computer. Human voices are never perfectly stable.

* Micro-Vibrato (The "Vocal" texture): Use a fast-speed delta stream like %10101010. This creates a tiny oscillation. Without this, your vowels will sound like a flat organ pipe.
* Prosody (Question vs. Statement):
* Question: A slow stream of %11110000 (ramping up) at the end of a vowel.
   * Statement: A slow stream of %00001111 (dropping down) to "land" the word.

2. The Volume Delta (The "Envelope")
This is where you define the Attack and Decay of the vowel to make it sound natural.

* Glottal Attack: For a word starting with a vowel (like "Apple"), use a sharp volume increase.
* Soft Attack: For a word that "fades in" (like "Home"), use a slow delta ramp up.

------------------------------
Vocal "Recipe" Examples (Pitch + Vol)

| Vowel | Pitch Delta (1-bit stream) | Vol Delta (1-bit stream) | Result |
|---|---|---|---|
| "AH" | %10101010 (Fast) | %11100000 (Open/Steady) | Natural, vibrating "Aaaaa" |
| "EE" | %11110000 (Slow Slide Up) | %11001100 (Tremolo) | High-pitched, piercing "Eeee?" |
| "OH" | %00001111 (Slow Slide Down) | %11111111 (Full Vol) | Deep, authoritative "Ohhh" |

The "Speech" Combo Strategy
If you are sequencing a word in your tracker, you would apply these to your Note lines:

   1. Consonant: Trigger your BLOCK code (e.g., Y=4 for a "B" kick).
   2. Vowel (The Note): Set the 24-TET Note and assign the Pitch Delta (for texture) and the Vol Delta (for shape).
   3. End: Stop the note or trigger a Note Cut.

Would you like me to provide a 16-bit hex string for a "standard" human-like vibrato delta to test in your ticker manager?

