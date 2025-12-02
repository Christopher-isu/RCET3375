;=================================================================
; PIC16F883 ? I2C 3-Servo Controller ? REFERENCE VERSION 2.1 (LOCKED)
; FINAL WORKING BASELINE ? ALL 3 SERVOS ACTIVE
; Servo 0 (ID 00) ? RC2  (CCP1 hardware)
; Servo 1 (ID 01) ? RC1  (CCP2 hardware)
; Servo 2 (ID 10) ? RB0  (bit-banged via Timer2 compare ? 16 µs resolution)
; Mapping: 62 + pos ? 0x00 ? 1.000 ms, 0x20 ? 1.500 ms, 0x3F = 2.000 ms
; Known status: RB0 PWM has minor jitter (to be fixed in 2.2)
;=================================================================
#include <xc.inc>

config FOSC = XT
config WDTE = OFF
config PWRTE = OFF
config MCLRE = ON
config CP = OFF
config CPD = OFF
config BOREN = OFF
config IESO = OFF
config FCMEN = OFF
config LVP = OFF
config WRT = OFF

PSECT udata_acs
W_SAVE:         DS 1
STATUS_SAVE:    DS 1
RECV_BYTE:      DS 1
TEMP:           DS 1
SERVO_POS_0:    DS 1
SERVO_POS_1:    DS 1
SERVO_POS_2:    DS 1

PSECT resetVect,class=CODE,delta=2
    goto    Start
PSECT isrVect,class=CODE,delta=2
    goto    ISR

PSECT code,class=CODE,delta=2

ISR:
    movwf   W_SAVE
    swapf   STATUS,W
    movwf   STATUS_SAVE

    btfss   PIR1,3
    goto    ISR_Exit
    bcf     PIR1,3

    BANKSEL SSPBUF
    movf    SSPBUF,W

    BANKSEL SSPSTAT
    btfss   SSPSTAT,5
    goto    Release_Clock

    movwf   RECV_BYTE

    movf    RECV_BYTE,W
    andlw   0xC0
    movwf   TEMP

    movf    RECV_BYTE,W
    andlw   0x3F

    movf    TEMP,F
    btfsc   STATUS,2
    movwf   SERVO_POS_0

    movlw   0x40
    subwf   TEMP,W
    btfsc   STATUS,2
    movwf   SERVO_POS_1

    movlw   0x80
    subwf   TEMP,W
    btfsc   STATUS,2
    movwf   SERVO_POS_2

Release_Clock:
    BANKSEL SSPCON
    bsf     SSPCON,4

ISR_Exit:
    swapf   STATUS_SAVE,W
    movwf   STATUS
    swapf   W_SAVE,F
    swapf   W_SAVE,W
    retfie

Start:
    BANKSEL ANSEL
    clrf    ANSEL
    clrf    ANSELH
    BANKSEL CM1CON0
    clrf    CM1CON0
    clrf    CM2CON0
    BANKSEL SRCON
    clrf    SRCON

    BANKSEL PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC

    BANKSEL TRISA
    movlw   0xFF
    movwf   TRISA
    BANKSEL TRISB
    movlw   0b11111110
    movwf   TRISB
    BANKSEL TRISC
    movlw   0b11111000
    movwf   TRISC

    BANKSEL PR2
    movlw   249
    movwf   PR2
    BANKSEL T2CON
    movlw   0b00000111
    movwf   T2CON

    BANKSEL CCP1CON
    movlw   0x0C
    movwf   CCP1CON
    movlw   0x0C
    movwf   CCP2CON

    movlw   32
    movwf   SERVO_POS_0
    movwf   SERVO_POS_1
    movwf   SERVO_POS_2

    BANKSEL SSPADD
    movlw   0x20
    movwf   SSPADD
    BANKSEL SSPSTAT
    movlw   0x80
    movwf   SSPSTAT
    BANKSEL SSPCON
    movlw   0x36
    movwf   SSPCON

    BANKSEL PIE1
    bsf     PIE1,3
    BANKSEL INTCON
    bsf     INTCON,7
    bsf     INTCON,6

Main_Loop:
    movf    SERVO_POS_0,W
    addlw   62
    BANKSEL CCPR1L
    movwf   CCPR1L
    BANKSEL CCP1CON
    bcf     CCP1CON,5
    bcf     CCP1CON,4

    movf    SERVO_POS_1,W
    addlw   62
    BANKSEL CCPR2L
    movwf   CCPR2L
    BANKSEL CCP2CON
    bcf     CCP2CON,5
    bcf     CCP2CON,4

    BANKSEL TMR2
    movf    TMR2,W
    movwf   TEMP
    movf    SERVO_POS_2,W
    addlw   62
    subwf   TEMP,W
    btfss   STATUS,0
    goto    RB0_Low
    bsf     PORTB,0
    goto    After_RB0
RB0_Low:
    bcf     PORTB,0
After_RB0:

    BANKSEL PORTC
    bsf     PORTC,0

    goto    Main_Loop

    END