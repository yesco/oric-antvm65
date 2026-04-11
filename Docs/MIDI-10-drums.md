In ABC notation, Channel 10 is the "magic" channel reserved specifically for drums. Unlike other channels where notes represent pitches (A, B, C), on Channel 10, each "note" triggers a different drum sound (like a Kick, Snare, or Hi-Hat).
To set this up, you use the %%MIDI channel 10 command.
## How to Code Drums
Here is a quick example of a standard "Rock Beat" in ABC:

V:3
%%MIDI channel 10
L:1/8
% In Channel 10: 
% C = Bass Drum, D = Snare, ^F = Closed Hi-Hat
[C^F] [^F] [D^F] [^F] | [C^F] [^F] [D^F] [^F] |

## Common Drum Map for Channel 10
When using Channel 10, the notes on the staff correspond to these percussion instruments:

| ABC Note | MIDI Number | Instrument |
|---|---|---|
| C, | 36 | Bass Drum 1 |
| D, | 38 | Acoustic Snare |
| ^F, | 42 | Closed Hi-Hat |
| G, | 43 | High Floor Tom |
| A, | 45 | Low Tom |
| _B, | 46 | Open Hi-Hat |
| C | 48 | Hi-Mid Tom |
| D | 50 | High Tom |
| _E | 51 | Ride Cymbal 1 |
| ^F | 54 | Tambourine |
| G | 55 | Splash Cymbal |

## Why use V:3?
In your original Enola Gay file, you have V:1 (Piano) and V:2 (Music Box). If you want to add the iconic electronic drum beat from that song, you would create a V:3, assign it to Channel 10, and write the rhythm there.
Would you like me to show you how to write the specific drum pattern for the intro of "Enola Gay"?

