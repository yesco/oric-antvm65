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


# Commands recognized

```
Notes:        B/H AGFEDC agfdedc A' a, a" a,, a# C-4 C#4 
Duration:     C/2 
Octave:       K:4  (default)
              K:+  K:-
              o4
              v11
Lyrics-line   w: hello baby, baby, baby.
Channel:      A: B: C: N: ABN: (3 selected)

label:        $foo:

calling:      $foo




CALL       _foo
CALL       _bar

```

# Examples

To test your AntVM65 Perl converter, here are two melodies formatted in the ABC-ish style we've developed. One is a simple "Ode to Joy" to test 24-TET note logic, and the other is a rhythmic "Mario" intro to test your WAIT and |ABC multi-channel selecting.

## 1. Ode to Joy (Beethoven)

This test focuses on Scale Degrees and Key Tracking.

$ode_to_joy:
  K:4 |ABC 
  E E F G | G F E D | C C D E | E2 D2
  E E F G | G F E D | C C D E | D2 C2
RET

## 2. Super Mario Theme (Intro)

This test checks Staccato Rhythms and Triple-Channel Sync.

$mario_intro:
  K:5 |ABC
  E1 E1 WAIT1 E1 WAIT1 C1 E2 G2 
  |ABC K:4 G2 RET

## 3. Star Wars (Main Theme)

A good test for Octave Jumps and Triplets.

$star_wars:
  K:4 |A
  G,4 D4 | C B, A, G4 | d4 C B, A, G4 | d4 C B, C A,4 
RET

## Running the Test
 You can save these into a file called test_songs.abc and run your Perl script: [1] 

perl convert.pl test_songs.abc > test_songs.s

## Expected ca65 Output (Visual Check)
Your script should produce binary output similar to this:

* Notes: %nnnnn ooo (e.g., E at Octave 4 → %01000 100).
* Channels: %11011 000 for |A, %11011 001 for |B, etc.
* Wait: %11000 001 for a 1-tick pause.
* Procs: Properly wrapped .proc and .endproc blocks with matching labels.

Would you like me to generate a "Language" word-list test (using the 0 prefix for speech-style commands) for your IPA phoneme layer?

[1] [https://www.volkerschatz.com](https://www.volkerschatz.com/noise/abctrans.html)







# ABC notation free characters

PDF reference chart 2 pages


https://michaeleskin.com/documents/ABCquickRefv0_6.pdf



Summary: @ $ ?  --- free to use!

@ $ ? 


Actually, both # and ; have specific, though limited, roles in ABC notation. [1] 

* # (Hash/Sharp): Primarily used in headers (like K:F#) to define the key signature. While the music body uses ^ for sharps, some modern software allows # within chord symbols (e.g., "C#m") to display a sharp sign.
* ; (Semicolon): Primarily used to separate multiple lines of chord symbols or annotations that apply to the same note. [2, 3, 4, 5, 6] 

## ABC-Notation: One-Line Command Summary
Here is a concise guide to the core syntax for your AntVM65 toolchain:

| Syntax [2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18] | Description |
|---|---|
| X:1 | Reference Number: Marks the start of a new tune. |
| T:Title | Title: The name of the song or piece. |
| M:4/4 | Meter: Sets the time signature (beats per measure). |
| L:1/8 | Default Length: Defines what a single letter (e.g., C) represents in ticks. |
| K:G | Key: Sets sharps/flats for the scale (must be the last header). |
| C D E | Notes (Low): Uppercase letters for the middle/lower octave. |
| c d e | Notes (High): Lowercase letters for the upper octave. |
| z / x | Rests: z is a visible rest; x is an invisible/silent rest. |
| C2 / C/2 | Duration: Numbers multiply the default length; slashes divide it. |
| ^ / _ / = | Accidentals: Sharp (^), Flat (_), or Natural (=) before a note. |
| , / ' | Octave Shifts: Comma lowers an octave; apostrophe raises it. |
| | / |: / :| | Structure: Bar line (|), start repeat (|:), and end repeat (:|). |
| [CEG] | Chords: Plays multiple notes simultaneously. |
| (3abc | Tuplets: Groups notes into irregular rhythms (e.g., triplets). |
| {g}C | Grace Notes: Tiny decorative notes played quickly before the main note. |
| "Am" | Guitar Chords: Text in quotes above the staff. |
| % | Comments: Ignores everything following it on that line. |

Since you're using $ for your VM labels, it's a perfect choice—it's one of the few standard ASCII characters that standard ABC notation doesn't use for music logic!
Would you like a sample of an ABC file converted to your AntVM65 bit-stream format?

[1] [https://thecelticroom.org](https://thecelticroom.org/abc-music-notation/abc-notation-read-and-write.html)
[2] [https://en.wikipedia.org](https://en.wikipedia.org/wiki/Letter_notation)
[3] [https://trillian.mit.edu](https://trillian.mit.edu/~jc/music/abc/doc/ABC.html)
[4] [https://trillian.mit.edu](https://trillian.mit.edu/~jc/music/abc/doc/ABC.html)
[5] [https://justsolve.archiveteam.org](http://justsolve.archiveteam.org/wiki/ABC_%28musical_notation%29)
[6] [https://moinejf.free.fr](http://moinejf.free.fr/abcm2ps-doc/features.html)
[7] [https://folkworks.org](https://folkworks.org/article/all-about-abc-notation/#:~:text=Lines%20in%20the%20first%20part%20of%20the,using%20one%20of%20the%20ABC%20conversion%20tools.)
[8] [https://folkworks.org](https://folkworks.org/article/all-about-abc-notation/#:~:text=Lines%20in%20the%20first%20part%20of%20the,using%20one%20of%20the%20ABC%20conversion%20tools.)
[9] [https://en.wikibooks.org](https://en.wikibooks.org/wiki/ABC_notation/Notes)
[10] [https://en.wikipedia.org](https://en.wikipedia.org/wiki/ABC_notation#:~:text=ABC%20notation%20is%20a%20shorthand%20form%20of,musical%20notation%20%28bar%20lines%2C%20tempo%20marks%2C%20etc.%29)
[11] [https://notabc.app](https://notabc.app/abc/basics/)
[12] [https://thecelticroom.org](https://thecelticroom.org/abc-music-notation/abc-notation-read-and-write.html#:~:text=Under%20the%20headers%20we%20type%20the%20code,to%20lower%20it%20an%20octave%20so:%20C%2CD%2CE%2CF%2CG%2CA%2CB%2C)
[13] [https://www.biteyourownelbow.com](https://www.biteyourownelbow.com/abcnotation.htm)
[14] [https://intmus.github.io](https://intmus.github.io/abc-tutorial.html)
[15] [https://trillian.mit.edu](https://trillian.mit.edu/~jc/music/abc/doc/ABCtut_Repeats.html)
[16] [https://www.lesession.co.uk](http://www.lesession.co.uk/abc/abc_extensions.htm)
[17] [https://www.youtube.com](https://www.youtube.com/watch?v=u6_tjcKE42A&t=1)
[18] [https://www.facebook.com](https://www.facebook.com/groups/498671610282070/posts/3093154600833745/)



To define and call labels in a way that remains compatible with ABC notation, you need characters that do not interfere with note letters (A-G, a-g), accidentals (^, _, =), durations (numbers), or structural symbols (|, [, ]). [1] 
The following characters are generally safe for your purpose because they are either unused in the music body or reserved specifically for "user-defined" extensions:
## 1. The @ (At) Symbol
The @ character is not part of the standard ABC note syntax. It is widely used in other languages for decorators or pointers, making it intuitive for labels. [2, 3] 

* Definition: @foo:
* Call: @foo
* Pros: Highly visible; zero clashing with standard accidentals or note names.

## 2. The $ (Dollar) Symbol
Similar to @, the $ is not used for notes or standard ornaments. [3] 

* Definition: $foo:
* Call: $foo
* Pros: Familiar "variable" or "macro" notation in many scripting environments. [4] 

## 3. The ? (Question Mark) Symbol
Standard ABC does not use ? in the music body. [3, 5] 

* Definition: ?foo:
* Call: ?foo
* Pros: Short and distinct; unlikely to be confused with any duration or octave marker.

## 4. The & (Ampersand) Symbol
While & is sometimes used for voice overlays in multi-voice tunes, it is less common in single-track or simple music bodies. However, to be safest, avoid it if you plan to support polyphony. [1, 6] 
## Recommendation for AntVM65:
I recommend using @ or $. These are the "cleanest" because they don't look like any musical accidental (unlike _, -, or ^) and aren't used for ornaments (like . or !). [7, 8] 
Avoid These (Common Clashes):

* _ (Underscore): Used for flat accidentals and lyrics extension.
* ^ (Caret): Used for sharp accidentals.
* = (Equals): Used for natural accidentals.
* : (Colon): Usually follows a letter in headers (like K:, L:). Using it mid-line for labels might confuse some parsers unless it follows your unique prefix. [3, 4, 5, 6] 

Would you like a sample of how a label-based loop would look in this notation for your 6502 interpreter?

[1] [https://help.sap.com](https://help.sap.com/saphelp_em92/helpdata/en/4e/37f5e8dfbe3822e10000000a42189c/content.htm)
[2] [https://en.wikipedia.org](https://en.wikipedia.org/wiki/ABC_notation#:~:text=ABC%20notation%20is%20a%20shorthand%20form%20of,musical%20notation%20%28bar%20lines%2C%20tempo%20marks%2C%20etc.%29)
[3] [https://folkworks.org](https://folkworks.org/article/all-about-abc-notation/)
[4] [https://abcnotation.com](https://abcnotation.com/wiki/abc:standard:v2.1#:~:text=Table_title:%203.%20Information%20fields%20Table_content:%20header:%20%7C,notes:%20N:see%20also%20O%27Neills%20%2D%20234%20%7C)
[5] [https://trillian.mit.edu](https://trillian.mit.edu/~jc/music/abc/doc/ABC.html)
[6] [https://www.lesession.co.uk](http://www.lesession.co.uk/abc/abc_extensions.htm)
[7] [https://www.lesession.co.uk](http://www.lesession.co.uk/abc/abc_extensions.htm)
[8] [https://en.wikipedia.org](https://en.wikipedia.org/wiki/ABC_notation#:~:text=ABC%20notation%20is%20a%20shorthand%20form%20of,musical%20notation%20%28bar%20lines%2C%20tempo%20marks%2C%20etc.%29)




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

