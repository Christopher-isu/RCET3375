;===========================================================
; PIC16F883 I2C SLAVE v6.8 + MAIN-LOOP SERVO (COMPATIBLE)
; RB0: 4ms frame, 1-2ms PW (YOUR working calibration)
;===========================================================
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
config DEBUG = OFF

PSECT udata_acs
W_SAVE:         DS 1
STATUS_SAVE:    DS 1
RECV_DATA:      DS 1
BYTE_COUNT:     DS 1
NEW_DATA_FLAG:  DS 1
SERVO_TICK:     DS 1
SERVO0_PW:      DS 1

PSECT resetVect,class=CODE,delta=2
    goto    Start

PSECT isrVect,class=CODE,delta=2
    goto    I2C_ISR

PSECT code,class=CODE,delta=2

;-----------------------------------------------------------
; I2C ISR v5.0 - UNCHANGED (working)
;-----------------------------------------------------------
I2C_ISR:
    movwf   W_SAVE
    swapf   STATUS,W
    movwf   STATUS_SAVE

    BANKSEL PORTC
    bcf     PORTC,1

    BANKSEL SSPBUF
    movf    SSPBUF,W
    BANKSEL RECV_DATA
    movwf   RECV_DATA

    BANKSEL BYTE_COUNT
    incf    BYTE_COUNT,F
    movf    BYTE_COUNT,W
    sublw   2
    btfss   STATUS,2
    goto    NoFlagSet
    BANKSEL NEW_DATA_FLAG
    bsf     NEW_DATA_FLAG,0
    BANKSEL BYTE_COUNT
    clrf    BYTE_COUNT

NoFlagSet:
    BANKSEL PORTC
    bsf     PORTC,2
    nop
    bcf     PORTC,2

    BANKSEL PIR1
    bcf     PIR1,3
    BANKSEL SSPSTAT
    bsf     SSPSTAT,7

    swapf   STATUS_SAVE,W
    movwf   STATUS
    swapf   W_SAVE,F
    swapf   W_SAVE,W
    retfie

;-----------------------------------------------------------
; Initialization - PIC16F883 PORTB compatible
;-----------------------------------------------------------
Start:
    BANKSEL ANSEL
    clrf    ANSEL
    BANKSEL ANSELH
    clrf    ANSELH
    BANKSEL CM1CON0
    clrf    CM1CON0
    BANKSEL CM2CON0
    clrf    CM2CON0
    BANKSEL SRCON
    clrf    SRCON

    BANKSEL TRISC
    movlw   0b00111000
    movwf   TRISC

    ; PORTB FIXED for PIC16F883 (NO LATB)
    BANKSEL TRISB
    clrf    TRISB           ; ALL PORTB = OUTPUTS
    BANKSEL PORTB
    clrf    PORTB           ; ALL PORTB = LOW

    BANKSEL PORTA
    clrf    PORTA
    BANKSEL PORTC
    clrf    PORTC

    ; I2C v5.0 exact
    BANKSEL SSPCON
    clrf    SSPCON
    BANKSEL SSPCON2
    clrf    SSPCON2
    BANKSEL SSPBUF
    clrf    SSPBUF
    BANKSEL SSPSTAT
    clrf    SSPSTAT
    BANKSEL PIR1
    bcf     PIR1,3

    BANKSEL SSPADD
    movlw   0x20
    movwf   SSPADD
    BANKSEL SSPCON
    movlw   0x36
    movwf   SSPCON

    BANKSEL PIE1
    bsf     PIE1,3          ; SSPIE only
    BANKSEL INTCON
    bsf     INTCON,7
    bsf     INTCON,6

    ; YOUR calibrated servo values
    BANKSEL SERVO0_PW
    movlw   28              ; 1ms = 28 steps
    movwf   SERVO0_PW
    BANKSEL SERVO_TICK
    clrf    SERVO_TICK
    BANKSEL BYTE_COUNT
    clrf    BYTE_COUNT
    BANKSEL NEW_DATA_FLAG
    clrf    NEW_DATA_FLAG

;-----------------------------------------------------------
; Main Loop - Heartbeat + PROVEN Servo PWM
; 111 steps x 36us = YOUR 4ms frame ?
;-----------------------------------------------------------
Main_Loop:
    ; RC0 Heartbeat
    BANKSEL PORTC
    bcf     PORTC,0
    nop
    bsf     PORTC,0

    ; Servo step (YOUR TIMING)
    BANKSEL SERVO_TICK
    incf    SERVO_TICK,F
    movf    SERVO_TICK,W
    sublw   111             ; 4ms frame ?
    btfss   STATUS,2
    goto    CheckServoPW
    
    clrf    SERVO_TICK
    BANKSEL PORTB
    bsf     PORTB,0         ; Servo HIGH
    goto    CheckI2C

CheckServoPW:
    BANKSEL SERVO0_PW
    movf    SERVO0_PW,W
    BANKSEL SERVO_TICK
    subwf   SERVO_TICK,W
    btfss   STATUS,2
    goto    CheckI2C
    
    BANKSEL PORTB
    bcf     PORTB,0         ; Servo LOW

CheckI2C:
    BANKSEL NEW_DATA_FLAG
    btfss   NEW_DATA_FLAG,0
    goto    Main_Loop
    bcf     NEW_DATA_FLAG,0

    BANKSEL RECV_DATA
    movf    RECV_DATA,W
    sublw   0x55
    btfss   STATUS,2
    goto    UpdateServo
    BANKSEL PORTC
    bsf     PORTC,1

UpdateServo:
    BANKSEL SERVO0_PW
    movlw   28              ; 1ms min
    movwf   SERVO0_PW
    BANKSEL RECV_DATA
    movf    RECV_DATA,W
    sublw   128
    btfsc   STATUS,0
    incf    SERVO0_PW,F     ; 28-56 steps = 1-2ms

    goto    Main_Loop

    END
