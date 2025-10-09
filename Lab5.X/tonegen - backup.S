;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = INTRC_CLKOUT     ; Use internal oscillator with clock out on RA6
    CONFIG  WDTE = OFF              ; Disable watchdog timer to prevent resets
    CONFIG  PWRTE = OFF             ; Disable power-up timer for immediate start
    CONFIG  MCLRE = ON              ; Enable MCLR pin for external reset
    CONFIG  CP = OFF                ; Disable code protection for development
    CONFIG  CPD = OFF               ; Disable data memory protection
    CONFIG  BOREN = OFF             ; Disable brown-out reset for stable power
    CONFIG  IESO = OFF              ; Disable clock switchover for internal osc
    CONFIG  FCMEN = OFF             ; Disable fail-safe clock monitor
    CONFIG  LVP = OFF               ; Disable low-voltage programming

    CONFIG  BOR4V = BOR40V          ; Set brown-out voltage (ignored, BOREN=OFF)
    CONFIG  WRT = OFF               ; Disable Flash write protection

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>               ; Include PIC16F883 register definitions

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
; Variable Delay Subroutine (~1.6ms to 3.8ms at 4MHz, based on CurrentInner)
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
; Delay Value Lookup Table (indexed 0-15 for sequential notes C3 to D5)
;=================================================================
DelayTable:
    ADDWF   PCL, F      ; Add index to PCL for jump
    RETLW   0x5E        ; Index 0: C3, ~3.813ms (94) ? ~7.626ms period
    RETLW   0x53        ; Index 1: D3, ~3.373ms (83) ? ~6.746ms period
    RETLW   0x4A        ; Index 2: E3, ~3.013ms (74) ? ~6.026ms period
    RETLW   0x46        ; Index 3: F3, ~2.853ms (70) ? ~5.706ms period
    RETLW   0x3E        ; Index 4: G3, ~2.533ms (62) ? ~5.066ms period
    RETLW   0x37        ; Index 5: A3, ~2.253ms (55) ? ~4.506ms period
    RETLW   0x31        ; Index 6: B3, ~2.013ms (49) ? ~4.026ms period
    RETLW   0x2E        ; Index 7: C4, ~1.893ms (46) ? ~3.786ms period
    RETLW   0x29        ; Index 8: D4, ~1.693ms (41) ? ~3.386ms period
    RETLW   0x24        ; Index 9: E4, ~1.493ms (36) ? ~2.986ms period
    RETLW   0x22        ; Index 10: F4, ~1.413ms (34) ? ~2.826ms period
    RETLW   0x1E        ; Index 11: G4, ~1.253ms (30) ? ~2.506ms period
    RETLW   0x1B        ; Index 12: A4, ~1.133ms (27) ? ~2.266ms period
    RETLW   0x17        ; Index 13: B4, ~0.973ms (23) ? ~1.946ms period
    RETLW   0x16        ; Index 14: C5, ~0.933ms (22) ? ~1.866ms period
    RETLW   0x13        ; Index 15: D5, ~0.813ms (19) ? ~1.626ms period

;=================================================================
; End of Program
;=================================================================
    END