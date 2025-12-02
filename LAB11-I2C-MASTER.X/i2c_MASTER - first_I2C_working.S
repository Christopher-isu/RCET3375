;===========================================================
; PIC16F883 I2C MASTER - FULL DATA TRANSMISSION
; - Sends [START][0x20][ACK][0x55][ACK][STOP] continuously
;===========================================================
#include <xc.inc>

;-----------------------------------------------------------
; CONFIGURATION BITS
;-----------------------------------------------------------
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

;-----------------------------------------------------------
; RAM VARIABLES
;-----------------------------------------------------------
PSECT udata_acs
W_SAVE:         DS 1
STATUS_SAVE:    DS 1
TMP:            DS 1

;-----------------------------------------------------------
; VECTORS
;-----------------------------------------------------------
PSECT resetVect,class=CODE,delta=2
    goto    Start

PSECT isrVect,class=CODE,delta=2
    goto    ISR

PSECT code,class=CODE,delta=2

;-----------------------------------------------------------
; INTERRUPT SERVICE ROUTINE
;-----------------------------------------------------------
ISR:
    movwf   W_SAVE
    swapf   STATUS,W
    movwf   STATUS_SAVE
    swapf   STATUS_SAVE,W
    movwf   STATUS
    swapf   W_SAVE,F
    swapf   W_SAVE,W
    retfie

;-----------------------------------------------------------
; WAIT FOR I2C BUS IDLE
;-----------------------------------------------------------
I2C_WaitIdle:
I2C_IdleLoop:
    BANKSEL SSPSTAT
    btfsc   SSPSTAT,2          ; R/W bit busy?
    goto    I2C_IdleLoop
    BANKSEL SSPCON2
    movf    SSPCON2,W
    andlw   0x1F
    btfss   STATUS,2           ; SEN, RSEN, PEN, RCEN, ACKEN cleared?
    goto    I2C_IdleLoop
    return

;-----------------------------------------------------------
; I2C START CONDITION
;-----------------------------------------------------------
I2C_Start:
    call    I2C_WaitIdle
    BANKSEL SSPCON2
    bsf     SSPCON2,0          ; SEN = 1, start condition
I2C_WaitStart:
    btfsc   SSPCON2,0
    goto    I2C_WaitStart
    BANKSEL PIR1              ; Clear SSPIF after start
    bcf     PIR1,3
    return

;-----------------------------------------------------------
; I2C STOP CONDITION
;-----------------------------------------------------------
I2C_Stop:
    BANKSEL PIR1              ; Clear SSPIF before stop
    bcf     PIR1,3
    BANKSEL SSPCON2
    bsf     SSPCON2,2          ; PEN = 1, stop condition
I2C_WaitStop:
    btfsc   SSPCON2,2
    goto    I2C_WaitStop
    return

;-----------------------------------------------------------
; I2C WRITE BYTE
; - NACK causes immediate STOP
; - Clear SSPIF after ACKSTAT check
;-----------------------------------------------------------
I2C_WriteByte:
    BANKSEL SSPBUF
    movwf   SSPBUF             ; Load byte to transmit

I2C_WaitTX:
    BANKSEL PIR1
    btfss   PIR1,3             ; Wait until SSPIF=1
    goto    I2C_WaitTX

    BANKSEL SSPCON2
    btfsc   SSPCON2,6          ; Check NACK bit
    goto    I2C_NackStop

    BANKSEL PIR1
    bcf     PIR1,3             ; Clear SSPIF after ACK check
    return

I2C_NackStop:
    call    I2C_Stop
    return

;-----------------------------------------------------------
; Delay ~10us (@4MHz) for bus free time (tBUF)
;-----------------------------------------------------------
Delay_InterPacket:
    movlw   40
    movwf   TMP
Delay_Loop:
    decfsz  TMP,F
    goto    Delay_Loop
    return

;-----------------------------------------------------------
; Send full packet: [START][0x20][0x55][STOP]+delay
;-----------------------------------------------------------
I2C_SendFullPacket:
    call    I2C_Start

    movlw   0x20               ; Slave address (7-bit << 1 for PIC MSSP expected)
    call    I2C_WriteByte

    movlw   0x55               ; Data byte
    call    I2C_WriteByte

    call    I2C_Stop
    call    Delay_InterPacket
    return

;-----------------------------------------------------------
; INITIALIZATION AND MAIN LOOP
;-----------------------------------------------------------
Start:
    ; Disable analog input and comparators
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

    ; Configure pins
    BANKSEL TRISA
    movlw   0b11111111          ; PORTA inputs
    movwf   TRISA
    BANKSEL TRISC
    movlw   0b00011000          ; RC3 (SDI), RC4 (SCL) inputs
    movwf   TRISC

    ; Clear ports
    BANKSEL PORTA
    clrf    PORTA
    BANKSEL PORTB
    clrf    PORTB
    BANKSEL PORTC
    clrf    PORTC

    ; MSSP setup for I2C Master, 100kHz
    BANKSEL SSPSTAT
    movlw   0x80                ; SMP=1 standard speed
    movwf   SSPSTAT
    BANKSEL SSPCON
    movlw   0x28                ; SSPEN=1, Master mode
    movwf   SSPCON
    BANKSEL SSPADD
    movlw   9                   ; 100kHz @4MHz clock
    movwf   SSPADD

    ; Clear interrupts
    BANKSEL PIR1
    bcf     PIR1,3
    BANKSEL PIE1
    bcf     PIE1,3             ; Disable MSSP interrupts (polling mode)

Main_Loop:
    call    I2C_SendFullPacket
    goto    Main_Loop

END
