;; ===========================================================================
;; setayr (Oric Atmos 6502A)
;; X = Register Index (0-15)
;; A = Value to write
;; Trashes: none (A and X preserved for caller logic)
;; ---------------------------------------------------------------------------
;; This routine follows the standard Oric Atmos VIA sequence:
;; 1. Set PCR ($030C) to latch register, then to latch data.
;; 2. Port A ($030F) carries the address/data.
;; 3. DDRA ($0303) toggles direction (essential for Oric Keyboard/Tape).
;; ===========================================================================

setayr:
    pha                     ; Save Value to write
    
    ; --- Special Case: Register 7 (Mixer) ---
    cpx #7                  ; Is this the Mixer?
    bne @skip_r7_patch
    ora #64                 ; Force Bit 6 HI (Required for Oric hardware)
@skip_r7_patch:
    sta tmp_val             ; Store the (potentially patched) value

    ; --- 1. Select the Register ---
    lda #$FF                ; Set VIA Port A to OUTPUT
    sta $0303               
    stx $030F               ; Put Register Index (X) on Port A
    
    lda #$FF                ; Latch Register (Control lines for 'Address')
    sta $030C               
    lda #$DD                ; Inactive state
    sta $030C               

    ; --- 2. Write the Value ---
    lda tmp_val             ; Get the value (A)
    sta $030F               ; Put Value on Port A
    
    lda #$FD                ; Latch Data (Control lines for 'Write')
    sta $030C               
    lda #$DD                ; Inactive state / Reset control lines
    sta $030C               

    ; --- 3. Cleanup ---
    lda #$00                ; Set VIA Port A back to INPUT
    sta $0303               ; (Critical for Oric Keyboard/IRQ scanning)
    
    pla                     ; Restore original A for cmdAYUPDATE's CMP checks
    rts

.bss
tmp_val: .res 1
