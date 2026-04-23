;;; ================================================================
;;; COMBO COMMANDS: DRUM & SPEECH EMULATION
;;; ================================================================
;;; Y=4 : DRUM S  (Kick / Plosive 'P/B')  - Tone-heavy thump
;;; Y=5 : DRUM SH (Snare / Sibilant 'SH') - Mid-noise + Tone
;;; Y=6 : DRUM CH (Closed Hat / 'CH/T')   - High-noise, fast decay
;;; Y=7 : DRUM TS (Open Hat / 'S/Z')      - High-noise, slow decay
;;; ================================================================

;;; 163 B - as AI gen
;;;  97 B - JSK: opt! (ayshadow + structure change)

DRUMSTART:

;;; COMBO "TS" (Open Hi-Hat / Long Sibilant 'S/Z/TS')
;;; A = Sibilant Pitch (0=Sizzle, 15=Hiss)
cmdHiHatOpenTS:
        clc
        adc #$02        ; Base "S" noise
        sta ayshadow+6  ; R6 = Noise Period

        ldy #$24        ; Noise C ON, Tone C OFF
        ldx #$25        ; Env Coarse (Long "Sssshh" fade)
        jmp trigger

;;; COMBO "CH" (Closed Hi-Hat / Hard Plosive 'CH/T/K')
;;; A = Sharpness (0=Thick 'CH', 15=Thin 'T')
cmdHiHatClosedCH:
        clc
        adc #$01        ; Very high noise
        sta ayshadow+6

        ldy #$24        ; Noise C ON, Tone C OFF
        ldx #$03        ; Env Coarse (Extremely short "Tick")
        jmp trigger

;;; COMBO "SH" (Snare / Fricative 'SH/ZH')
;;; A = Vowel Body (Changes the "mouth" tone)
cmdSnareSH:     
        sta ayshadow+4  ; Fine Tone C

        lda #$01        ; Coarse Tone C
        sta ayshadow+5

        lda #$0F        ; Mid-range "Breath" noise
        sta ayshadow+6

        ldy #$00        ; Noise C ON, Tone C ON
        ldx #$08        ; Env Coarse (Bust of noise)
        jmp trigger

;;; COMBO "S" (Kick / Deep Plosive 'B/P/D')
;;; A = Impact (0=Deep Thump, 15=Tight Pop)
cmdKickS:       
        clc
        adc #$05        ; Base low frequency
        sta ayshadow+5  ; Coarse Tone C

        lda #$00        ; Fine Tone C
        sta ayshadow+4

        ldy #$20        ; Noise C OFF, Tone C ON
        ldx #$0C        ; Env Coarse (Heavy thump)
        ;; fall through to trigger


;;; X= env coarse
;;; Y= mixer new bits C N or:ed in
trigger:

        ;; Update MIXER C+N bits

;;; TODO: is this correct, not inverted?

        lda #%11011011

        and ayshadow+7
        sta ayshadow+7

        ;; maybe add C+/N
        tya
        ora ayshadow+7
        sta ayshadow+7


        ;; Update common (R11=0, R12=X, R13=9, R10=10)

        stx ayshadow+12 ; R12 = Env Period Coarse

        ldx #0
        stx ayshadow+11 ; R11 = Env Period Fine

        ldx #$09        ; Shape: Single Decay (\)
        stx ayshadow+13 ; R13 starts the one-shot

        ldx #$10        ; Use Hardware Envelope
        stx ayshadow+10 ; R10 = Amplitude C

        ;; "jsr"
        jmp interpret

DRUMEND:        


;;;
	
;; ## Strategic Wait Times

;; On a standard 50Hz/60Hz clock, here are the typical "Wait Ticks" for hardware drums:

;; - Kick Drum: 2-4 Ticks. You want it short so the bass/arp isn't gone for too long. The HW Envelope provides the "thump" even in that tiny window.
;; - Snare Drum: 3-6 Ticks. Snares need a bit more time for the "noise" to sizzle before the melody returns.
;; - Hi-Hat: 1-2 Ticks. Just a tiny "click" of noise.

;; ## The "Self-Correcting" Arp

;; The beauty of your Arp Cache (the note1, note2 you stored earlier) is that the "Wait" doesn't break the music.
;; - Frame 1: Drum interrupts (Arp is paused).
;; - Frame 2: Drum continuing.
;; - Frame 3: Timer hits 0. The VM simply restores the volume. Because the Arp Counter kept running in the background, the note comes back perfectly in time with the rhythm.

;; ## HW Envelope Shapes for the Wait

;; Since you are using a timer, these are the shapes to use in Register 13:

;; |Shape|(Binary)|Visual|	Effect
;; |--|--|--|--|
;; |1000|(\___)   |Single Decay|	The King for Drums. Best for Kicks and Snares. Drops to silence and stays there.
;; |1011|(\---)   |Decay & Hold|	Good for "Gated" snare sounds where you want a sudden drop but then a lingering buzz.
;; |1100|(/---)   |Attack & Hold|	Rare for drums, but can create a "reverse" cymbal effect if your wait is long enough.

;; ## VM Implementation Detail

;; You can bake the "Wait" value directly into the Fast-Call subroutine.

;; Fast-Call "Snare": [Setup Hardware] -> [Set VM_State.ChannelC_Lock = 5] -> RET.

;; The VM's main tick handler handles the decrement and the eventual "Unlock."

;; Would you like to see how to interleave these drum commands into your 24-TET delta stream so the timing stays rock-solid?
;; Exactly! In the world of 8-bit Sound VMs, last-writer-wins is the most efficient "priority" system there is.
;; If your VM processes Cursor C (the Arp/Chords) and then immediately processes Cursor D (the Drums), Cursor D simply overwrites the specific AY-shadow registers it needs. Since the actual physical I/O to the AY-3-8910 chip happens only once at the very end of the tick, the chip never even "sees" the Chord note that was briefly in that slot.
;; ## Why this is a "Zero-Cost" Priority System:

;; * No Conditional Logic: You don't need if/else checks to see if a drum is playing. You just run the code for all cursors in a fixed order.
;; * Implicit Priority: The order of your loop is the priority. If D is last, D is king.
;; * Total Control: If a drum needs to be "Noise only," it writes to the Noise and Mixer registers. If it's a "Tonal Kick," it overwrites the Frequency registers too.


;; ## The "Harm" Factor?

;; There is zero harm to the hardware or the audio quality. The AY chip only updates its internal oscillators based on the values present at the moment the BDIR/BC1 pins strobe the data in. Within those "hundred instructions" of your VM, you're just shuffling bits in RAM. It’s perfectly clean.


;; ## A Fun "Bach" Trick with this System:

;; Because D overwrites C, you can do "Note Robbing" for complex counterpoint. If Bach writes a 4th voice that the AY can't handle, you can put it on Cursor D. When the 4th voice isn't playing, Cursor C’s chord shines through. When the 4th voice hits, it "steals" the channel momentarily.
;; ## Data Structure for the "D" Cursor:
;; Since D is overwriting C, it only needs to provide:

;;    1. Which Registers to Overwrite: (Mixer, Noise, Volume, or Frequency?)
;;    2. The New Values: (The drum's specific "crunch" or "sweep").

;; Your Fast-Call for a drum would basically just be a "Block Move" or a series of LD (Shadow_Reg), A instructions that happen right before the final hardware sync.

;; Since this happens so fast, you could even have a "Layering" effect where a drum overwrites the Volume and Noise but leaves the Frequency of the chord alone, creating a "Harmonic Snare."

;; Does your VM use a Buffer for all 14 AY registers that gets pushed to the chip in one burst at the end of the frame? Bold your sync method!

