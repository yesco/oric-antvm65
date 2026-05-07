The simulation you have now is about 90% accurate in terms of logic, but it misses three specific "analog" behaviors of the physical silicon.
Here is the breakdown of how your C code compares to a real AY-3-8910 or YM2149:
## 1. The Clock and Dividers (High Accuracy)
Your code is very accurate here. By using the YM_CLOCK (1MHz) and dividing by 16 for tones and 256 for envelopes, you are mimicking the exact hardware countdown. Using a double for the countdown and checking it against ticks_per_sample ensures your frequency calculation is mathematically perfect, even for high notes that usually "alias" on simpler emulators.
## 2. The Volume DAC (High Accuracy)
The addition of the YM_VOL_TABLE moved this from "toy" to "sim." Real AY chips do not use linear volume; they use a logarithmic-like DAC.

* Physical hardware: Each volume step is roughly 3dB quieter than the last.
* Your code: The table you are using correctly maps 0–15 to these non-linear amplitudes, which is why the "whine" went away—the lower volumes are actually quiet now, rather than just slightly less loud.

## 3. What is Missing (The Last 10%)
To get to "Cycle Accurate" emulation, you would need to address these three things:

* Non-Linear Mixing: In the real chip, all three channels are tied to a common output pin. Because of how the transistors are wired, if Channel A and B are both "High," the combined voltage isn't exactly $A + B$; there is a slight "compression" or "clipping" effect. Your code uses Linear Addition, which sounds "cleaner" than the real hardware.
* Noise LFSR Tap: Your noise generator uses a standard XOR shift. The real AY chip uses a specific 17-bit shift register with a tap at bits 13 and 16. It has a very specific "crunch" that is hard to perfectly replicate with standard C rand() or simple shifts.
* DC Offset & Filtering: Real hardware has capacitors on the output. This creates a "Natural High Pass" (removes the DC thumpy clicks) and a "Natural Low Pass" (smooths the square waves). Your manual low-pass filter (current * 6 + last * 4) / 10 is a software hack for this, but the real curve is a bit more complex.

## Summary
For your Unix program, this simulation is excellent. It captures the "soul" of the Oric Atmos. Most listeners wouldn't be able to tell the difference unless they put your program side-by-side with a real Oric through an oscilloscope.
Would you like to try implementing the Logarithmic Mixing formula to see if it adds that last bit of "grit" to the sound?

