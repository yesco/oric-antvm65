In MIDI, "Special Effects" (SFX) are structured in two different ways depending on which General MIDI (GM) program number you choose. They can act as "melodic" instruments that play tones or "sample kits" where every key is a different sound.
## 1. Melodic SFX (Programs 96–103)
Programs in the "Synth Effects" category (like Rain, Crystal, or Sci-fi) usually behave like standard instruments.

* Tone-based: If you play different keys, the sound's pitch changes.
* How it works: The synthesizer takes a core sound (a sample or a generated wave) and "transposes" it across the keyboard. This allows you to play a melody using the "Rain" sound or create a chord with "Crystal". [1, 2] 

## 2. The Sound FX "Sample" Kit (Program 127)
Program 127 is unique. It doesn't treat the keyboard as a scale but rather as a big list of distinct samples, similar to how Channel 10 handles drums. [3, 4] 

* Non-melodic: Playing a higher note won't make the sound higher in pitch; it will simply trigger a completely different sound effect.
* The SFX Map: Each key (MIDI Note Number) is mapped to a specific real-world sound. For example:
* Note 39: High Q (Cutting sound)
   * Note 45: Laser
   * Note 55: Footsteps
   * Note 60: Bird Tweet
   * Note 125: Helicopter
   * Note 127: Gunshot [4] 

## Comparison: Tone vs. Sample

| Feature [5, 6] | Melodic SFX (e.g., 98: Crystal) | Sound FX Kit (127: Gunshot) |
|---|---|---|
| Pitching | Shifts pitch based on the note played. | Pitch is usually fixed for each sample. |
| Keyboard Use | One sound spread across all keys. | Dozens of different sounds on different keys. |
| Musical Use | Used for atmosphere, pads, or leads. | Used for "one-shot" environmental sounds. |

## How MIDI triggers them
Regardless of the type, MIDI itself is just a trigger. It sends a "Note On" message that tells the sound engine: "Hey, play the sample associated with key #60 at volume #100". The engine then decides whether to pitch-shift a single sample (like a piano) or just play a specific file (like a drum or a laser). [2, 7, 8, 9] 
Would you like the full map of sounds for the Program 127 Sound FX kit so you can use them in your ABC code?

[1] [https://www.roland.com](https://www.roland.com/uk/blog/midi-vs-audio/)
[2] [https://www.avid.com](https://www.avid.com/resource-center/what-is-midi-musical-instrument-digital-interface)
[3] [https://www.scribd.com](https://www.scribd.com/doc/68525202/GM-Sound-List#:~:text=The%20document%20describes%20the%20General%20MIDI%20sound,ensure%20compatibility%20across%20General%20MIDI%20compliant%20devices.)
[4] [https://www.scribd.com](https://www.scribd.com/document/334871863/GM-1-SOUND-SET)
[5] [https://medium.com](https://medium.com/@transmissionsamples/the-creative-role-of-midi-packs-in-music-production-ff77a62ec031)
[6] [https://www.youtube.com](https://www.youtube.com/watch?v=Mp3Qj3Rlpl0)
[7] [https://www.londonsoundacademy.com](https://www.londonsoundacademy.com/blog/whats-the-difference-between-audio-and-midi)
[8] [https://www.reddit.com](https://www.reddit.com/r/makinghiphop/comments/j9eu12/what_is_a_midi_trigger_and_what_is_the_purpose_of/)
[9] [https://s3-eu-west-1.amazonaws.com](https://s3-eu-west-1.amazonaws.com/s3-euw1-ap-pe-ws4-cws-documents.ri-prod/9781032854519/bonus-chapters/MIDI-Basics.pdf)


In MIDI, "Special Effects" (SFX) are structured in two different ways depending on which General MIDI (GM) program number you choose. They can act as "melodic" instruments that play tones or "sample kits" where every key is a different sound.
## 1. Melodic SFX (Programs 96–103)
Programs in the "Synth Effects" category (like Rain, Crystal, or Sci-fi) usually behave like standard instruments.

* Tone-based: If you play different keys, the sound's pitch changes.
* How it works: The synthesizer takes a core sound (a sample or a generated wave) and "transposes" it across the keyboard. This allows you to play a melody using the "Rain" sound or create a chord with "Crystal". [1, 2] 

## 2. The Sound FX "Sample" Kit (Program 127)
Program 127 is unique. It doesn't treat the keyboard as a scale but rather as a big list of distinct samples, similar to how Channel 10 handles drums. [3, 4] 

* Non-melodic: Playing a higher note won't make the sound higher in pitch; it will simply trigger a completely different sound effect.
* The SFX Map: Each key (MIDI Note Number) is mapped to a specific real-world sound. For example:
* Note 39: High Q (Cutting sound)
   * Note 45: Laser
   * Note 55: Footsteps
   * Note 60: Bird Tweet
   * Note 125: Helicopter
   * Note 127: Gunshot [4] 

## Comparison: Tone vs. Sample

| Feature [5, 6] | Melodic SFX (e.g., 98: Crystal) | Sound FX Kit (127: Gunshot) |
|---|---|---|
| Pitching | Shifts pitch based on the note played. | Pitch is usually fixed for each sample. |
| Keyboard Use | One sound spread across all keys. | Dozens of different sounds on different keys. |
| Musical Use | Used for atmosphere, pads, or leads. | Used for "one-shot" environmental sounds. |

## How MIDI triggers them
Regardless of the type, MIDI itself is just a trigger. It sends a "Note On" message that tells the sound engine: "Hey, play the sample associated with key #60 at volume #100". The engine then decides whether to pitch-shift a single sample (like a piano) or just play a specific file (like a drum or a laser). [2, 7, 8, 9] 
Would you like the full map of sounds for the Program 127 Sound FX kit so you can use them in your ABC code?

[1] [https://www.roland.com](https://www.roland.com/uk/blog/midi-vs-audio/)
[2] [https://www.avid.com](https://www.avid.com/resource-center/what-is-midi-musical-instrument-digital-interface)
[3] [https://www.scribd.com](https://www.scribd.com/doc/68525202/GM-Sound-List#:~:text=The%20document%20describes%20the%20General%20MIDI%20sound,ensure%20compatibility%20across%20General%20MIDI%20compliant%20devices.)
[4] [https://www.scribd.com](https://www.scribd.com/document/334871863/GM-1-SOUND-SET)
[5] [https://medium.com](https://medium.com/@transmissionsamples/the-creative-role-of-midi-packs-in-music-production-ff77a62ec031)
[6] [https://www.youtube.com](https://www.youtube.com/watch?v=Mp3Qj3Rlpl0)
[7] [https://www.londonsoundacademy.com](https://www.londonsoundacademy.com/blog/whats-the-difference-between-audio-and-midi)
[8] [https://www.reddit.com](https://www.reddit.com/r/makinghiphop/comments/j9eu12/what_is_a_midi_trigger_and_what_is_the_purpose_of/)
[9] [https://s3-eu-west-1.amazonaws.com](https://s3-eu-west-1.amazonaws.com/s3-euw1-ap-pe-ws4-cws-documents.ri-prod/9781032854519/bonus-chapters/MIDI-Basics.pdf)
