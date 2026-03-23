;;; Oric AntVM65 sound tracker
;;; 
;;; (C) 2026 Jonas S Karlsson

;;; Stream Format "rough picture"
;;; 
;;;   BIT 7 - has param(if cmd) or has pitch+volume
;;; 
;;;   BIT 6 - has channel A byte
;;;   BIT 5 - has channel B byte
;;;   BIT 4 - has channel C byte
;;; 
;;;   BIT 3 - FX bit
;;;   BIT 2 - FX bit
;;; 
;;;   BIT 1 - control bit
;;;   BIT 0 - control bit


;;;   PW CMND CM commands with no arguments
;;;   ======================================
;;;   .. .... 00 - command byte
;;; 
;;;   00 .... 00 - USER commands
;;;   01 .... 00 - WAIT commands below

;;;   00 0000 00 - RETURN from stackewd CALL
;;; 
;;;   00 0001 00 - ENTER SPEECH: 0 LL+phonem seq till 0 0
;;;    (using langauge LL "speak" phonems till 0 0)
;;;    (0 LL can switch language)
;;;    (similar to CALL, current LL is saved and restored
;;;     after return)
;;;   00 0010 00 - reserved 2
;;;   00 0011 00 - reserved 3
;;;   00 01.. 00 - reserved 4-7
;;;   ----------
;;;   00 uuuu 00 - USER 8-15 command (use from 15 down)


;;;   01 0000 00 - WAIT 1 second
;;;   01 xxxx 00 - WAIT 1-15 cycles (20-300ms)


;;;   Following commands take 2 byte parmaters
;;;   ========================================
;;;   1. ....  00 - Parameter (2 bytes)
;;; 
;;;   10 0000  00 - CALL ll pp (language phonem-index)
;;; 
;;;   Phonem calls using "language" library 1-255
;;;   with a phonem index 1-255
;;;     ll= is an index into different langauges
;;;     pp= is a phonenem number


;;;   10 0001  00 - CHORD fixed first
;;;   10 0010  00 - CHORD fixed second

;;;   10 0011  00 - ENVELOPE for A only 16-bits
;;; 
;;;   This is a micro-envelope. It defines a 16-bit
;;;   cycle. The current volume is remembered. The
;;;   16-bits are shifted, 0 is interpred as -1
;;;   and 1 as +1. After 16 cycles, volume is reset.
;;;   Bit-cycle repeats.
;;; 
;;;   (possibly orthogonal to DURATION/DELAY?)
;;;   

;;;   10 0100  00 - SILENCE all
;;;   10 0101  00 - A DECAY note vol 0-15 speed1-16
;;;   10 0110  00 - B DECAY           - " - 
;;;   10 0110  00 - C DECAY           - " - 

;;;   10 1000  00 - SETAYREG: 1 byte reg + 1 byte value
;;;   10 1001  00 - A DURATION:note vol 0-15 len 1-16
;;;   10 1010  00 - B DURATION:       - " -
;;;   10 1011  00 - C DURATION:       - " -

;;;  length: of durction 16 is 4 BEATS, so can have 1/16th

;;;   10 1100  00 - PLAYAY: set all 14 regs from address
;;;   10 1101  00 - A SLIDE note vol 0-15 speed 1-16
;;;   10 1110  00 - B SLIDE           - " - 
;;;   10 1111  00 - C SLIDE           - " - 

;;;   11 0000  00 - SETBEATS a/b (a,b two bytes)
;;;   11 0001  00 - SETCYCLE 2 bytes cyc: 1M/cyc= Hz

;;;   11 0010  00 - reserved 2
;;;   11 00xx  00 - ...
;;;   11 0111  00 - reserved 7

;;;   11 1xxx  00 - USER command (2 byte Parameter)
;;;   -----------
;;;   11 1xxx  00 - USER command 0-7


;;;   HAS-HEADER
;;;   ========================================
;;;   A "has-header" as identified by xx!=0.
;;;   Each "has" bit more or less determines if a 
;;;   it "has" a feature-byte following.
;;;   
;;;   The FX byte is different

;;;   V ABC FX MX
;;;   -----------
;;;   . ... .. xx - xx!=0 means tone data
;;;   h hhh .. .. - HAS bit!

;;;   1 ... .. .. - has A+B volume byte
;;;   . ... .. .1 - has noise (speech/drum in FX)
;;;   . 100 .. .. - has A     1 byte note data
;;;   . 111 .. .. - has A+B+C 3 byte note data
;;; 
;;;   . ... .. 01 - tone + speech FX
;;;   -----------
;;;   . ... 00 01 -   speech 's'
;;;   . ... 01 01 -   speech 'sh'
;;;   . ... 10 01 -   speech 'ch'
;;;   . ... 11 01 -   speech 'th' (?)
;;; 
;;;   . ... .. 11 - tone + drum   FX
;;;   -----------
;;;   . ... 00 11 -   kick
;;;   . ... 01 11 -   snare
;;;   . ... 10 11 -   hihat closed
;;;   . ... 11 11 -   hihat open
;;; 
;;;   . ... 00 10 - tone only
;;;   . ... 01 10 - tone + other effect?
;;;   . ... 10 10 - tone + other effect?
;;;   . ... 11 10 - tone + other effect?


;;;   Channel Data byte (tone)
;;;   ========================
;;;   765 43210
;;;   ---------
;;;   oct .....   8 octaves
;;;                 (01sub 23bass 45melody 67clarity)
;;;   ... nnnnn  24 TET-notes (quadnotes)

;;;   oct 11xxx  fine tune: delta pitch+= delta<<oct;
;;;   

;;;   The 192-255, 64 values in each of the
;;;   A, B, or C channels have different functions:
;;;   - A = LINK C
;;;   - B = ECHO A
;;;   - C = CHORD/ARHIPELLO

;;;   A: 192-255: LINK A-C: C frequency "follow" A
;;;   ============================================

;;;   76 543210
;;;   ---------
;;;   11 000000   UNLINK C
;;;   11 tunduo   LINK: link C=A+tunduo cycle

;;;   B: 192-255: ECHO A-B: B is delay echo A
;;;   =======================================
;;; 
;;;   76 543210
;;;   ---------
;;;   11 000000   UNECHO
;;;   11 000wai   DELAY wait 1-7
