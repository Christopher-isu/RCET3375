;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = XT         ; External crystal oscillator, up to 4 MHz
    CONFIG  WDTE = OFF        ; Disable Watchdog Timer
    CONFIG  PWRTE = OFF       ; Disable Power-up Timer
    CONFIG  MCLRE = ON        ; Enable MCLR pin
    CONFIG  CP = OFF          ; Disable code protection
    CONFIG  CPD = OFF         ; Disable data EEPROM protection
    CONFIG  BOREN = OFF       ; Disable Brown-out Reset
    CONFIG  IESO = OFF        ; Disable Internal/External Switchover
    CONFIG  FCMEN = OFF       ; Disable Fail-Safe Clock Monitor
    CONFIG  LVP = OFF         ; Disable Low-Voltage Programming
    CONFIG  WRT = OFF         ; Disable Flash write protection

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>               ; Include PIC16F883 register definitions

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
    ; Configure PORTB: RB0 input, RB1-RB7 inputs (unused)
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for TRISB access
    MOVLW   0b11111111  ; All RB0-RB7=1 (inputs), but only RB0 used
    MOVWF   TRISB       ; Set PORTB direction

    ; Configure PORTC: RC0 output, RC1-RC7 outputs (unused)
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISC access
    MOVLW   0b00000000  ; All RC0-RC7=0 (outputs), but only RC0 used
    MOVWF   TRISC       ; Set PORTC direction

    ; Disable analog functions for digital I/O
    BSF STATUS, 6       ; Select Bank 3 (RP1=1, RP0=1)
    BSF STATUS, 5       ; for ANSEL/ANSELH
    CLRF    ANSELH      ; Disable analog on PORTB
    CLRF    ANSEL       ; Disable analog on PORTA/C

    ; Disable comparators
    BSF STATUS, 6       ; Select Bank 2 (RP1=1, RP0=0)
    BCF STATUS, 5       ; for CM1CON0/CM2CON0
    CLRF    CM1CON0     ; Turn off comparator 1
    CLRF    CM2CON0     ; Turn off comparator 2

    ; Disable PORTB weak pull-ups
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OPTION_REG
    BSF     OPTION_REG, 7 ; Disable internal pull-ups

    ; Initialize PORTB and PORTC to low
    BCF STATUS, 6       ; Select Bank 0 (RP1=0, RP0=0)
    BCF STATUS, 5       ; for PORTB/C access
    CLRF    PORTB       ; Clear PORTB (though inputs)
    CLRF    PORTC       ; Clear PORTC (RC0=0)

MainLoop:
MOVF    PORTB, W    ; Read PORTB (RB0) into W (1 cycle)
XORLW   0x01        ; Flip the LSB (0->1, 1->0) (1 cycle)
MOVWF   PORTC       ; Write flipped value to PORTC (RC0) (1 cycle)
GOTO    MainLoop    ; Repeat infinite loop (2 cycles)

;=================================================================
; End of Program
;=================================================================
    END

