#include <xc.inc>

;=================================================================
; Device Configuration
;=================================================================
    ; Configure oscillator and protection settings
    CONFIG  FOSC = XT         ; External crystal oscillator, up to 4 MHz
    CONFIG  WDTE = OFF        ; Disable Watchdog Timer to prevent unintended resets
    CONFIG  PWRTE = OFF       ; Disable Power-up Timer for immediate startup
    CONFIG  MCLRE = ON        ; Enable MCLR pin for external reset
    CONFIG  CP = OFF          ; Disable code protection to allow program memory access
    CONFIG  CPD = OFF         ; Disable data EEPROM protection
    CONFIG  BOREN = OFF       ; Disable Brown-out Reset to simplify power management
    CONFIG  IESO = OFF        ; Disable Internal/External Switchover for single clock source
    CONFIG  FCMEN = OFF       ; Disable Fail-Safe Clock Monitor
    CONFIG  LVP = OFF         ; Disable Low-Voltage Programming to prevent accidental programming
    CONFIG  WRT = OFF         ; Disable Flash write protection for full memory access

    PSECT   resetVect,class=CODE,delta=2
resetVect:
    GOTO    main

    PSECT   code,class=CODE,delta=2
main:
    CLRF    PORTC           ; Clear PORTC initially (RC7=0)
    BANKSEL TRISC
    CLRF    TRISC           ; Set PORTC as outputs
    BSF     TRISB,0         ; Set RB0 as input
    BANKSEL ANSELH
    BCF     ANSELH,4        ; Clear ANS12 for digital input on RB0
    BANKSEL PORTB           ; Back to bank 0

loop:
    BTFSS   PORTB,0         ; Test RB0, skip if high
    GOTO    display_7
    MOVLW   0x31            ; ASCII '1' (00110001, RC7=0)
    GOTO    output
display_7:
    MOVLW   0x37            ; ASCII '7' (00110111, RC7=0)
output:
    MOVWF   PORTC           ; Output to PORTC (RC7 remains 0)
    GOTO    loop

    END