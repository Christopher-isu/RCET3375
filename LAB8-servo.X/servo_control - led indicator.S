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

;=================================================================
; Includes and Definitions
;=================================================================
#include <xc.inc>

;=================================================================
; Variables
;=================================================================
    PSECT udata_bank0,class=BANK0,space=1
ACQ_CNT: DS 1

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    ORG     0x0000
    GOTO    MAIN

;=================================================================
; Interrupt Vector
;=================================================================
    PSECT isrVect,class=CODE,delta=2
    ORG     0x0004
    GOTO    ISR  ; Vector to ISR code

;=================================================================
; ISR Code (dummy for now)
;=================================================================
    PSECT isrCode,class=CODE,delta=2
    ORG     0x0008
ISR:
    RETFIE

;=================================================================
; Main Program
;=================================================================
    PSECT code,class=CODE,delta=2
    ORG     0x0020
MAIN:
    ; Bank 0
    BANKSEL PORTC
    CLRF    PORTC           ; Clear PORTC outputs

    BANKSEL TRISC
    CLRF    TRISC           ; Set PORTC as all outputs

    BANKSEL ANSEL
    MOVLW   0x01            ; Enable AN0 as analog
    MOVWF   ANSEL
    CLRF    ANSELH          ; Disable other analog inputs

    BANKSEL CM1CON0         ; Bank 1 for comparator registers
    CLRF    CM1CON0         ; Disable comparator 1
    CLRF    CM2CON0         ; Disable comparator 2

    BANKSEL ADCON0          ; Bank 0
    MOVLW   0b01000001      ; ADCS=01 (Fosc/8 with ADCS2=0), CHS=0000 (AN0), GO=0, ADON=1
    MOVWF   ADCON0

    BANKSEL ADCON1
    MOVLW   0b00000000      ; ADFM=0 (left justified), VCFG=00 (VDD/VSS), ADCS2=0
    MOVWF   ADCON1

    BANKSEL ADCON0          ; Ensure back to Bank 0 for ADCON0

LOOP:
    ; Acquisition delay (~20us at 1us/instr cycle)
    MOVLW   0x05            ; Load 5 for approx 20us (with NOPs for precision)
    MOVWF   ACQ_CNT
DELAY_ACQ:
    NOP
    NOP
    NOP
    NOP
    DECFSZ  ACQ_CNT, F
    GOTO    DELAY_ACQ

    BSF     ADCON0, 1       ; Start ADC conversion (GO/DONE bit 1)
WAIT_ADC:
    BTFSC   ADCON0, 1       ; Wait for conversion done (GO/DONE bit 1)
    GOTO    WAIT_ADC

    MOVF    ADRESH, W       ; Get 8 MSBs
    BANKSEL PORTC
    MOVWF   PORTC           ; Output to PORTC (RC0=LSB, RC7=MSB)

    GOTO    LOOP

    END