# ant-lang: AntVM textual notation

We will base the format mostly on the ABC-notation, but when possibly add from MML, and some stuff from Vortex Tracker when we can.

| ABC | MML | Vortex | Description |
|---|---|---|---|
| C c | c C | C-4 C-5 | Normal C vs. High C (Octave shift) |
| _B | b- | A#3 | Flats / Sharps (Note modification) |
| C2 | c2 | --- | Duration: Double length (Half note) |
| C/2 | c8 | --- | Duration: Half length (Eighth note) |
| [K:Gmin] | o? | (Header) | Global Octave or Key signature |
| (none) | v? | 0..F | Volume / Amplitude (0-15) |
| z | r | RST | Rest (Silence/Pause) |
| !...! | @? | 01.. | Instrument / Patch selection |
| (none) | t? | F?? | Tempo (BPM or Ticks-per-row) |




# AI discussion

While many trackers use unique binary formats, there isn't one single "standard" text notation. However, the most widely recognized text-based system for representing tracker-style music is ABC Notation. [1, 2] 
Common Textual Notations

* ABC Notation: This is the most standardized plain-text format. It uses English note names (A, B, C, etc.) and symbols like commas (,) for lower octaves and apostrophes (') for higher octaves. For example, a low C is C, and a high C is c.
* Music Macro Language (MML): Used frequently in early computer music and Japanese trackers. It uses the letters a to g for pitches and specifies length with trailing numbers (e.g., c8 for an eighth note). It also uses o for octave and v for volume.
* Tracker-Specific Text Exports: Trackers like Vortex Tracker II or OpenMPT often have their own text-based formats that resemble a spreadsheet grid. A typical line might look like C-4 01 ..., where C-4 is the note and octave, and 01 is the instrument number. [1, 3, 4, 5, 6, 7] 

Popcorn Theme: G Minor Sequence (Approximate Text)
For your 6502 Atmos format, you can use the following sequence for the main "popping" lead. Note that in tracker text, octave 4 is the middle range.
Part A (The "Pop") - 130-140 BPM
G-4 F-4 G-4 D-4 Bb3 D-4 G-3 (Repeat)
Part B (The Scale)
G-4 A-4 Bb4 A-4 Bb4 G-4 A-4 G-4 A-4 F-4 G-4 F-4 G-4 Eb4 G-4
Mapping to your Atmos Tracker
If you want to use the notation you described (e.g., HAGBFEC with numbers for octaves), here is a translation:

* Notes: G4, F4, G4, D4, Bb3, D4, G3
* Pauses: Use [PAUSE] or R (Rest).
* Durations: Since trackers use a grid, a [FULL] note usually occupies one "row" at a set speed. [5, 8, 9] 

Would you like a step-by-step hex encoding of this specific melody to test directly in your 6502 cmdNOTE routine?
What's next? Should we define the BPM to Tick conversion formula or look at Volume Decay macros?

[1] [https://forum.openmpt.org](https://forum.openmpt.org/index.php?topic=5816.0)
[2] [https://ipipapa.com](https://ipipapa.com/en/blogs/ipipapa-speech-in-music/5-fakten-uber-das-notationssystem-abc-und-warum-du-es-nutzen-solltest#:~:text=5%20facts%20about%20the%20notation%20system%20abc,to%20write%20music%20notation%20in%20text%20form.)
[3] [https://www.talkbass.com](https://www.talkbass.com/threads/is-there-a-convention-for-writing-musical-notation-in-plain-text.1104786/#:~:text=I%20think%20I%20found%20my%20answer%2C%20after,least%20it%27s%20standardized.%20Details%20are%20here:%20http://abcnotation.com/)
[4] [https://arxiv.org](https://arxiv.org/html/2502.10467v1)
[5] [https://en.wikipedia.org](https://en.wikipedia.org/wiki/Music_Macro_Language)
[6] [https://en.wikipedia.org](https://en.wikipedia.org/wiki/Music_Macro_Language)
[7] [https://github.com](https://github.com/zserge/1bitr)
[8] [https://en.wikipedia.org](https://en.wikipedia.org/wiki/Music_tracker)
[9] [https://www.youtube.com](https://www.youtube.com/watch?v=KxNfc8YDIjI&t=28)

Here is the completed summary table comparing the three most common text-based music systems. For your 6502 Atmos engine, a hybrid of MML (for speed) and Vortex (for register control) is usually the most powerful way to write data.
Music Notation Summary

How these map to your 6502 Player:

   1. Vortex Style (Note-Octave): This maps 1:1 to your nnnnn ooo byte. C-4 becomes a single byte in your stream.
   2. MML Style (Lengths): This determines the value you load into your wait_timer. If a "Whole Note" is 32 ticks, c8 (eighth note) tells your code to LDA #4 : STA wait_timer.
   3. ABC Style (Case Sensitivity): Using C vs c is just a text-parser trick to increment or decrement your ooo (octave) bits before packing the byte.

The "Popcorn" Staccato Effect:
In Vortex, you would use an Instrument (like @01) that contains a volume macro:

* Tick 0: Vol 15
* Tick 1: Vol 8
* Tick 2: Vol 0 (The "Pop")

Would you like the full G-Minor text sequence for Popcorn using one of these notations (like MML) so you can begin converting it to your hex format?
What's next? Shall we define the Instrument Macro for that "pop" or the Wait Timer logic for the note lengths?


Summary of various notations
| ABC | MML | Vortex  | Description |
|-----|-----|---------|-------------|
| C c |     | C-4 C-3 | normal C, high c |
| Bb3 |     |         | half note |
|     | c8  |         | length: note |
|     | o?  |         | octave |
|     | v?  |         | volume |
|     |     |         | rest |

