;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = INTRC_CLKOUT
    CONFIG  WDTE = OFF
    CONFIG  PWRTE = OFF
    CONFIG  MCLRE = ON
    CONFIG  CP = OFF
    CONFIG  CPD = OFF
    CONFIG  BOREN = OFF
    CONFIG  IESO = OFF
    CONFIG  FCMEN = OFF
    CONFIG  LVP = OFF
    CONFIG  BOR4V = BOR40V
    CONFIG  WRT = OFF

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    GOTO Start

;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2

Start:
    ; Configure internal oscillator to 4 MHz
    BCF STATUS, RP1
    BSF STATUS, RP0
    MOVLW   0b01100001
    MOVWF   OSCCON

    ; Set PORTC as output
    CLRF    TRISC

    ; Disable analog functions
    BSF STATUS, RP1
    BSF STATUS, RP0
    CLRF    ANSEL
    CLRF    ANSELH

    ; Disable comparators
    BCF STATUS, RP0
    CLRF    CM1CON0
    CLRF    CM2CON0

    ; Clear PORTC
    BCF STATUS, RP1
    BCF STATUS, RP0
    CLRF    PORTC

Display8:
    ; ASCII '8' = 0x38
    MOVLW   0xB8        ; 0x38 + RC7=1 (WE inactive)
    MOVWF   PORTC       ; Output '8' with WE high
    BCF     PORTC, 7    ; Pull WE low to latch
    NOP
    NOP
    GOTO    Display8    ; Repeat to keep display latched

    END
