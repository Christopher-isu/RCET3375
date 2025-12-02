;===========================================================
; PIC16F883 I2C SLAVE v5.0 - RC1 ACK/STATUS CONTROL
; RC0: Heartbeat     RC2: 2x pulses/packet  
; RC1: HIGH=Data Match, LOW=ACK Processed (No NOPs!)
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

PSECT resetVect,class=CODE,delta=2
    goto    Start

PSECT isrVect,class=CODE,delta=2
    goto    I2C_ISR

PSECT code,class=CODE,delta=2

;-----------------------------------------------------------
; I2C ISR v5.0 - CLEAR RC1 on EVERY byte (ACK processed)
;-----------------------------------------------------------
I2C_ISR:
    movwf   W_SAVE
    swapf   STATUS,W
    movwf   STATUS_SAVE

    ; CLEAR RC1 - ACK processed for this byte
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
; Initialization (unchanged)
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

    BANKSEL PORTA
    clrf    PORTA
    BANKSEL PORTB
    clrf    PORTB
    BANKSEL PORTC
    clrf    PORTC

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
    bsf     PIE1,3
    BANKSEL INTCON
    bsf     INTCON,7
    bsf     INTCON,6

    BANKSEL BYTE_COUNT
    clrf    BYTE_COUNT
    BANKSEL NEW_DATA_FLAG
    clrf    NEW_DATA_FLAG
    BANKSEL RECV_DATA
    clrf    RECV_DATA

;-----------------------------------------------------------
; Main Loop v5.0 - SET RC1 on data match only
;-----------------------------------------------------------
Slave_Loop:
    BANKSEL PORTC
    bcf     PORTC,0
    nop
    bsf     PORTC,0

    BANKSEL NEW_DATA_FLAG
    btfss   NEW_DATA_FLAG,0
    goto    SkipCheck
    bcf     NEW_DATA_FLAG,0

    BANKSEL RECV_DATA
    movf    RECV_DATA,W
    sublw   0x55
    btfss   STATUS,2
    goto    SkipCheck

    ; DATA MATCH! Set RC1 HIGH
    BANKSEL PORTC
    bsf     PORTC,1

SkipCheck:
    nop
    nop
    goto    Slave_Loop

    END
