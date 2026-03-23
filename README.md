# Oric AntVM65 - a 24-TET Sound Virtual Machine for the 6502

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


## Note Datum Encoding


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

192–223 (32 Gaps): Fixed 
 offsets for Channel C (e.g., cycles). These are your "R", "L", and "Nasal" presets.
224–239 (16 Macros): Vowel Templates. A single command sets both A and C to a specific pitch ratio (e.g., the "EE" or "OO" sound).
240–255 (16 Controls): Toggle Noise/Envelope specifically for this A+C pair.

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

