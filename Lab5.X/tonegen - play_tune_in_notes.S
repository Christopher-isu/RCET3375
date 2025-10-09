;=================================================================
; Reserve working registers in Bank 0 RAM
;=================================================================
DelayOuter   EQU 0x20                  ; Outer delay counter for variable delay loop
DelayInner   EQU 0x22                  ; Inner delay counter for variable delay loop
CurrentInner EQU 0x24                  ; Current inner loop value for variable delay
NOTE_IDX     EQU 0x25                  ; Current note index (0-15)
RB0_PREV     EQU 0x26                  ; Previous RB0 state for edge detection (0 or 1)
NoteDur      EQU 0x28                  ; Duration counter for note periods

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2  ; Define reset vector section at 0x0000
    GOTO Start                        ; Jump to initialization on power-up/reset
    
;=================================================================
; Main Program Code Section
;=================================================================
    PSECT code,class=CODE,delta=2     ; Main program code section

Start:
    ; Configure 4 MHz internal oscillator
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OSCCON access
    MOVLW   0b01100001  ; Set 4 MHz (IRCF=110), use internal clock (SCS=1)
    MOVWF   OSCCON      ; Write to OSCCON for stable timing

    ; Configure PORTB: RB0 input, RB1-RB3 outputs (unused), RB4-RB7 inputs (unused)
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISB access
    MOVLW   0b11110001  ; RB0=1 (input), RB1-RB3=0 (outputs), RB4-RB7=1 (inputs)
    MOVWF   TRISB       ; Set PORTB direction

    ; Configure PORTA: RA0 and RA1 outputs (for square wave mirroring)
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISA access
    MOVLW   0b11111100  ; RA0=0, RA1=0 (outputs), RA2-RA5=1 (inputs)
    MOVWF   TRISA       ; Set PORTA direction

    ; Disable analog functions for digital I/O
    BSF STATUS, 6       ; Select Bank 3 (RP1=1, RP0=1)
    BSF STATUS, 5       ; for ANSEL/ANSELH
    CLRF    ANSEL       ; Disable analog on PORTA/C
    CLRF    ANSELH      ; Disable analog on PORTB (RB4-RB7)

    ; Disable PORTB weak pull-ups (external pull-downs used)
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OPTION_REG
    BSF     OPTION_REG, 7 ; Disable internal pull-ups (RBPU=1)

    ; Initialize ports and variables
    BCF STATUS, 6       ; Select Bank 0 (RP1=0, RP0=0)
    BCF STATUS, 5       ; for PORTA/PORTB access
    CLRF    PORTB       ; Set PORTB outputs low
    MOVLW   0x03        ; RA0=1, RA1=1
    MOVWF   PORTA       ; Set PORTA outputs high
    MOVLW   0x01        ; Assume initial RB0 high
    MOVWF   RB0_PREV    ; Set previous state
    CLRF    NOTE_IDX    ; Initialize note index

Main:
    ; Edge detection for RB0 pulled low (falling edge)
    BTFSC   PORTB, 0    ; Skip if RB0 high
    GOTO    UpdatePrevHigh
    ; RB0 is low
    MOVLW   0x01
    XORWF   RB0_PREV, W ; Check if previous was high (Z=1 if trigger)
    BTFSC   STATUS, 2
    GOTO    Triggered
    ; No trigger (already low)
    CLRF    RB0_PREV    ; Update previous to low
    GOTO    IdleLoop
UpdatePrevHigh:
    MOVLW   0x01
    MOVWF   RB0_PREV    ; Update previous to high
    ; Fall through to idle
IdleLoop:
    MOVLW   0x03        ; Set RA0 and RA1 high (no tone)
    MOVWF   PORTA
    MOVLW   0x10        ; Fixed inner value for idle delay (~0.4ms)
    MOVWF   CurrentInner
    CALL    DelayVariable ; Idle delay for responsiveness
    GOTO    Main

Triggered:
    CLRF    NOTE_IDX    ; Start sequence from first note
    GOTO    PlayNote    ; Jump to play first note

PlayNote:
    MOVF    NOTE_IDX, W ; Load current note index
    CALL    DelayTable  ; Get half-period delay value
    MOVWF   CurrentInner ; Update delay for this note
    MOVLW   0x32        ; 50 full periods per note
    MOVWF   NoteDur
PeriodLoop:
    MOVLW   0x00        ; Set RA0 and RA1 low
    MOVWF   PORTA
    CALL    DelayVariable ; Hold low for half-period
    MOVLW   0x03        ; Set RA0 and RA1 high
    MOVWF   PORTA
    CALL    DelayVariable ; Hold high for half-period
    DECFSZ  NoteDur, F  ; Decrement duration, skip if zero
    GOTO    PeriodLoop
    ; Note complete
    INCF    NOTE_IDX, F ; Next note index
    MOVLW   0x10        ; Check if 16 notes done
    SUBWF   NOTE_IDX, W
    BTFSS   STATUS, 2   ; Skip if zero (done)
    GOTO    PlayNote    ; Continue sequence
    ; Sequence complete
    GOTO    Main

;=================================================================
; Variable Delay Subroutine
;=================================================================
DelayVariable:
    MOVLW   0x0A        ; Outer count = 10 (0x0A)
    MOVWF   DelayOuter  ; Set outer counter
OuterLoop:
    MOVF    CurrentInner, W ; Load variable inner count
    MOVWF   DelayInner  ; Set inner counter
InnerLoop:
    NOP                 ; Adjust timing
    DECFSZ  DelayInner, F ; Decrement inner, skip if zero
    GOTO    InnerLoop   ; Loop inner
    NOP                 ; Adjust timing (after inner, before outer dec)
    DECFSZ  DelayOuter, F ; Decrement outer, skip if zero
    GOTO    OuterLoop   ; Loop outer
    RETURN              ; Return from delay

;=================================================================
; Delay Value Lookup Table (indexed 0-15 for Imperial March snippet: 
; G4 G4 G4 Eb4 Bb3 G4 Eb4 Bb3 Eb4 Bb3 G4 G4 G4 Eb4 Bb3 G4)
;=================================================================
DelayTable:
    ADDWF   PCL, F      ; Add index to PCL for jump
    RETLW   0x1F        ; Index 0: G4 ~391 Hz, ~1.278ms half-period
    RETLW   0x1F        ; Index 1: G4 ~391 Hz, ~1.278ms half-period
    RETLW   0x1F        ; Index 2: G4 ~391 Hz, ~1.278ms half-period
    RETLW   0x27        ; Index 3: Eb4 ~313 Hz, ~1.598ms half-period
    RETLW   0x35        ; Index 4: Bb3 ~232 Hz, ~2.158ms half-period
    RETLW   0x1F        ; Index 5: G4 ~391 Hz, ~1.278ms half-period
    RETLW   0x27        ; Index 6: Eb4 ~313 Hz, ~1.598ms half-period
    RETLW   0x35        ; Index 7: Bb3 ~232 Hz, ~2.158ms half-period
    RETLW   0x27        ; Index 8: Eb4 ~313 Hz, ~1.598ms half-period
    RETLW   0x35        ; Index 9: Bb3 ~232 Hz, ~2.158ms half-period
    RETLW   0x1F        ; Index 10: G4 ~391 Hz, ~1.278ms half-period
    RETLW   0x1F        ; Index 11: G4 ~391 Hz, ~1.278ms half-period
    RETLW   0x1F        ; Index 12: G4 ~391 Hz, ~1.278ms half-period
    RETLW   0x27        ; Index 13: Eb4 ~313 Hz, ~1.598ms half-period
    RETLW   0x35        ; Index 14: Bb3 ~232 Hz, ~2.158ms half-period
    RETLW   0x1F        ; Index 15: G4 ~391 Hz, ~1.278ms half-period

;=================================================================
; End of Program
;=================================================================
    END