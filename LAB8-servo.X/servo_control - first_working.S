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
ACQ_CNT:    DS 1
OLD_ADC:    DS 1
NEW_ADC:    DS 1
STEP:       DS 1
OLD_STEP:   DS 1
PULSE_HI:   DS 1
PULSE_LO:   DS 1
OFF_HI:     DS 1
OFF_LO:     DS 1
TEMP:       DS 1
TEMP_LO:    DS 1
TEMP_HI:    DS 1
PRE_HI:     DS 1
PRE_LO:     DS 1

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
    GOTO    ISR

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

    BANKSEL PORTB
    CLRF    PORTB           ; Clear PORTB outputs

    BANKSEL TRISB
    BCF     TRISB, 0        ; Set RB0 as output for servo

    BANKSEL ANSEL
    MOVLW   0x01            ; Enable AN0 as analog
    MOVWF   ANSEL
    CLRF    ANSELH          ; Disable other analog inputs

    BANKSEL CM1CON0         ; Bank 1 for comparator registers
    CLRF    CM1CON0         ; Disable comparator 1
    CLRF    CM2CON0         ; Disable comparator 2

    BANKSEL T1CON           ; Bank 0
    MOVLW   0b00100000      ; Timer1: prescale 1:4 (T1CKPS=10), off
    MOVWF   T1CON

    BANKSEL PIE1
    BCF     PIE1, 0         ; Disable TMR1IE

    BANKSEL ADCON0          ; Bank 0
    MOVLW   0b01000001      ; ADCS=01 (Fosc/8), CHS=0000 (AN0), GO=0, ADON=1
    MOVWF   ADCON0

    BANKSEL ADCON1
    MOVLW   0b00000000      ; ADFM=0 (left justified), VCFG=0 (VDD/VSS)
    MOVWF   ADCON1

    BANKSEL ADCON0          ; Ensure back to Bank 0 for ADCON0

    MOVLW   0xFF            ; Force initial update
    MOVWF   OLD_ADC
    MOVWF   OLD_STEP

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
    MOVWF   NEW_ADC

    SUBWF   OLD_ADC, W
    BTFSC   STATUS, 2
    GOTO    GENERATE_PWM    ; No change in ADC, skip update

    MOVF    NEW_ADC, W
    MOVWF   OLD_ADC
    BANKSEL PORTC
    MOVWF   PORTC           ; Update LEDs

    ; Compute STEP = NEW_ADC / 17
    CLRF    STEP
    MOVF    NEW_ADC, W
    MOVWF   TEMP
SUB_LOOP:
    MOVLW   17
    SUBWF   TEMP, F
    BTFSS   STATUS, 0       ; If no borrow (C=1), continue
    GOTO    DONE_SUB
    INCF    STEP, F
    GOTO    SUB_LOOP
DONE_SUB:

    MOVF    STEP, W
    SUBWF   OLD_STEP, W
    BTFSC   STATUS, 2
    GOTO    GENERATE_PWM    ; No change in step, skip pulse update

    MOVF    STEP, W
    MOVWF   OLD_STEP

    ; Compute PULSE_ticks = 200 + STEP * 25 (ticks = us / 4, base 800us, step 100us)
    CLRF    PULSE_HI
    MOVF    STEP, W
    MOVWF   PULSE_LO       ; PULSE = STEP

    ; STEP * 16
    RLF     PULSE_LO, F
    BTFSC   STATUS, 0
    INCF    PULSE_HI, F
    RLF     PULSE_LO, F
    BTFSC   STATUS, 0
    INCF    PULSE_HI, F
    RLF     PULSE_LO, F
    BTFSC   STATUS, 0
    INCF    PULSE_HI, F
    RLF     PULSE_LO, F
    BTFSC   STATUS, 0
    INCF    PULSE_HI, F

    ; Add STEP * 8
    MOVF    STEP, W
    MOVWF   TEMP
    RLF     TEMP, F         ; *2
    RLF     TEMP, F         ; *4
    RLF     TEMP, F         ; *8
    MOVF    TEMP, W
    ADDWF   PULSE_LO, F
    BTFSC   STATUS, 0
    INCF    PULSE_HI, F

    ; Add STEP * 1
    MOVF    STEP, W
    ADDWF   PULSE_LO, F
    BTFSC   STATUS, 0
    INCF    PULSE_HI, F

    ; Add base 200 (0xC8)
    MOVLW   0xC8
    ADDWF   PULSE_LO, F
    BTFSC   STATUS, 0
    INCF    PULSE_HI, F

    ; Compute OFF = 5000 - PULSE (0x1388 - PULSE)
    MOVLW   0x88
    MOVWF   TEMP_LO
    MOVLW   0x13
    MOVWF   TEMP_HI
    MOVF    PULSE_LO, W
    SUBWF   TEMP_LO, F
    BTFSS   STATUS, 0
    DECF    TEMP_HI, F
    MOVF    PULSE_HI, W
    SUBWF   TEMP_HI, F
    MOVF    TEMP_LO, W
    MOVWF   OFF_LO
    MOVF    TEMP_HI, W
    MOVWF   OFF_HI

GENERATE_PWM:
    ; Generate pulse: set high, delay PULSE ticks
    BANKSEL PORTB
    BSF     PORTB, 0        ; Servo high

    ; Compute preload for PULSE (0x10000 - PULSE)
    MOVF    PULSE_LO, W
    XORLW   0xFF
    MOVWF   PRE_LO
    MOVF    PULSE_HI, W
    XORLW   0xFF
    MOVWF   PRE_HI
    INCF    PRE_LO, F
    BTFSC   STATUS, 2
    INCF    PRE_HI, F

    MOVF    PRE_LO, W
    MOVWF   TMR1L
    MOVF    PRE_HI, W
    MOVWF   TMR1H

    BCF     PIR1, 0         ; Clear TMR1IF
    BSF     T1CON, 0        ; TMR1ON=1
WAIT_PULSE:
    BTFSS   PIR1, 0
    GOTO    WAIT_PULSE
    BCF     T1CON, 0        ; TMR1ON=0

    BCF     PORTB, 0        ; Servo low

    ; Delay OFF ticks
    MOVF    OFF_LO, W
    XORLW   0xFF
    MOVWF   PRE_LO
    MOVF    OFF_HI, W
    XORLW   0xFF
    MOVWF   PRE_HI
    INCF    PRE_LO, F
    BTFSC   STATUS, 2
    INCF    PRE_HI, F

    MOVF    PRE_LO, W
    MOVWF   TMR1L
    MOVF    PRE_HI, W
    MOVWF   TMR1H

    BCF     PIR1, 0         ; Clear TMR1IF
    BSF     T1CON, 0        ; TMR1ON=1
WAIT_OFF:
    BTFSS   PIR1, 0
    GOTO    WAIT_OFF
    BCF     T1CON, 0        ; TMR1ON=0

    GOTO    LOOP

    END