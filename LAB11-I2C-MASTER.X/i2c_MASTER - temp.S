;=================================================================
; PIC16F883 I2C MASTER ? v1.9 FINAL ? build-error free
; Removed bogus line "bsf INTCON,size=16" (typo from previous copy-paste)
; All other fixes retained (clrf SSPCON first, double SSPADD, RA5 heartbeat)
;=================================================================
#include <xc.inc>

;=================================================================
; CONFIG BITS ? PIC-AS syntax
;=================================================================
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

;=================================================================
; RAM ? access bank ? space after DS (strict PIC-AS)
;=================================================================
PSECT udata_acs
W_SAVE:         DS  1     ; ISR W save
STATUS_SAVE:    DS  1     ; ISR STATUS save
ADC_LAST:       DS  1     ; previous sent value
ADC_CURRENT:    DS  1     ; current scaled ADC
I2C_ERROR_FLAG: DS  1     ; set on NACK/bus issue

;=================================================================
; VECTORS ? non-abs PSECT
;=================================================================
PSECT resetVect,class=CODE,delta=2
    goto    Start

PSECT isrVect,class=CODE,delta=2
    goto    ISR

PSECT code,class=CODE,delta=2

;=================================================================
; ISR ? heartbeat only
;=================================================================
ISR:
    movwf   W_SAVE
    swapf   STATUS,W
    movwf   STATUS_SAVE
    btfsc   INTCON,2
    call    Heartbeat
    swapf   STATUS_SAVE,W
    movwf   STATUS
    swapf   W_SAVE,F
    swapf   W_SAVE,W
    retfie

Heartbeat:
    bcf     INTCON,2
    BANKSEL PORTA
    movlw   1<<5
    xorwf   PORTA,F          ; toggle RA5
    return

;=================================================================
; I2C BUS RECOVERY ? full MSSP reset
;=================================================================
I2C_BusRecover:
    BANKSEL SSPCON
    clrf    SSPCON           ; SSPEN = 0 ? disable MSSP completely first
    BANKSEL TRISC
    movlw   0b00011000       ; RC3/RC4 inputs
    movwf   TRISC
    BANKSEL PORTC
    bsf     PORTC,4          ; force SDA high
    clrf    ADC_CURRENT      ; counter
RecoverLoop:
    bcf     PORTC,3          ; SCL low
    call    DelayShort
    bsf     PORTC,3          ; SCL high
    call    DelayShort
    incf    ADC_CURRENT,F
    movlw   9
    subwf   ADC_CURRENT,W
    btfss   STATUS,2
    goto    RecoverLoop
    bsf     PORTC,4          ; SDA high
    call    DelayShort
    BANKSEL SSPSTAT
    movlw   0x80
    movwf   SSPSTAT
    BANKSEL SSPCON
    movlw   0x28             ; master mode
    movwf   SSPCON
    BANKSEL SSPADD
    movlw   9
    movwf   SSPADD
    movlw   9                ; double write
    movwf   SSPADD
    return

DelayShort:
    movlw   8
    movwf   ADRESH
ShortLoop:
    decfsz  ADRESH,F
    goto    ShortLoop
    return

;=================================================================
; WAIT BUS IDLE
;=================================================================
I2C_WaitIdle:
    BANKSEL SSPSTAT
    btfsc   SSPSTAT,2
    goto    I2C_WaitIdle
    BANKSEL SSPCON2
    movf    SSPCON2,W
    andlw   0x1F
    btfss   STATUS,2
    goto    I2C_WaitIdle
    return

;=================================================================
; NACK HANDLER
;=================================================================
I2C_NackError:
    BANKSEL SSPCON2
    bsf     SSPCON2,2
WaitStopErr:
    btfsc   SSPCON2,2
    goto    WaitStopErr
    BANKSEL I2C_ERROR_FLAG
    bsf     I2C_ERROR_FLAG,0
    call    I2C_BusRecover
    return

;=================================================================
; SEND BYTE
;=================================================================
SendByteToSlave:
    call    I2C_WaitIdle
    BANKSEL SSPCON2
    bsf     SSPCON2,0
WaitStart:
    btfsc   SSPCON2,0
    goto    WaitStart
    movlw   0x40
    BANKSEL SSPBUF
    movwf   SSPBUF
WaitAddrAck:
    BANKSEL PIR1
    btfss   PIR1,3
    goto    WaitAddrAck
    bcf     PIR1,3
    BANKSEL SSPCON2
    btfsc   SSPCON2,6
    goto    I2C_NackError
    BANKSEL ADC_CURRENT
    movf    ADC_CURRENT,W
    BANKSEL SSPBUF
    movwf   SSPBUF
WaitDataAck:
    BANKSEL PIR1
    btfss   PIR1,3
    goto    WaitDataAck
    bcf     PIR1,3
    BANKSEL SSPCON2
    btfsc   SSPCON2,6
    goto    I2C_NackError
    BANKSEL SSPCON2
    bsf     SSPCON2,2
WaitStop:
    btfsc   SSPCON2,2
    goto    WaitStop
    return

;=================================================================
; READ POT AN0
;=================================================================
ReadPotScaled:
    BANKSEL ADCON0
    bsf     ADCON0,1
WaitADC:
    btfsc   ADCON0,1
    goto    WaitADC
    BANKSEL ADRESH
    movf    ADRESH,W
    return

;=================================================================
; STARTUP
;=================================================================
Start:
    call    I2C_BusRecover

    BANKSEL OSCCON
    clrf    OSCCON

    BANKSEL ANSEL
    movlw   1<<0
    movwf   ANSEL
    clrf    ANSELH

    BANKSEL CM1CON0
    clrf    CM1CON0
    clrf    CM2CON0
    BANKSEL SRCON
    clrf    SRCON

    BANKSEL TRISA
    movlw   0b11011111       ; RA5 output heartbeat, RA0 input AN0
    movwf   TRISA

    BANKSEL TRISC
    movlw   0b00011000       ; RC3/RC4 inputs
    movwf   TRISC

    BANKSEL PORTA
    clrf    PORTA
    BANKSEL PORTC
    clrf    PORTC

    BANKSEL OPTION_REG
    movlw   0b00000111
    movwf   OPTION_REG
    BANKSEL TMR0
    clrf    TMR0
    BANKSEL INTCON
    bsf     INTCON,5         ; T0IE

    BANKSEL ADCON1
    movlw   0b10010000
    movwf   ADCON1
    BANKSEL ADCON0
    movlw   0b01000001
    movwf   ADCON0

    BANKSEL INTCON
    bsf     INTCON,6        ; PEIE
    bsf     INTCON,7        ; GIE

    BANKSEL I2C_ERROR_FLAG
    clrf    I2C_ERROR_FLAG

    call    ReadPotScaled
    BANKSEL ADC_LAST
    movwf   ADC_LAST
    movwf   ADC_CURRENT

Main_Loop:
    call    ReadPotScaled
    BANKSEL ADC_CURRENT
    movwf   ADC_CURRENT
    subwf   ADC_LAST,W
    btfsc   STATUS,2
    goto    Main_Loop
    movf    ADC_CURRENT,W
    BANKSEL ADC_LAST
    movwf   ADC_LAST
    call    SendByteToSlave
    goto    Main_Loop

    END