;=================================================================
; Reference Code 3.0 ? USART Echo ? TX DEBUG ONLY (RC5)
; From Code 1.0 (verified echo), TX LED high TXREG ? TRMT=1,
; RC5=0 output, TRISC=0b11010000, no RX LED, no pin state
;=================================================================
    PROCESSOR 16F883
    #include <xc.inc>

;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = XT
    CONFIG  WDTE = OFF
    CONFIG  PWRTE = OFF
    CONFIG  MCLRE = ON
    CONFIG  CP = OFF
    CONFIG  CPD = OFF
    CONFIG  BOREN = OFF
    CONFIG  IESO = OFF
    CONFIG  FCMEN = OFF
    CONFIG  LVP = OFF
    CONFIG  WRT = OFF

;=================================================================
; Reset Vector ? 0x0000
;=================================================================
    PSECT   resetVect, class=CODE, delta=2
    GOTO    MAIN

;=================================================================
; ISR Vector ? 0x0004 (dummy)
;=================================================================
    PSECT   isrVect, class=CODE, delta=2
    GOTO    ISR_DUMMY

;=================================================================
; ISR Code ? 0x0008 (dummy)
;=================================================================
    PSECT   isrCode, class=CODE, delta=2
ISR_DUMMY:
    RETFIE

;=================================================================
; Main Program ? 0x0020
;=================================================================
    PSECT   code, class=CODE, delta=2
MAIN:
    BANKSEL OSCCON
    CLRF    OSCCON          ; 4 MHz XT
    ;--- disable unused peripherals
    BANKSEL ANSEL
    CLRF    ANSEL
    BANKSEL ANSELH
    CLRF    ANSELH
    BANKSEL CM1CON0
    CLRF    CM1CON0
    CLRF    CM2CON0
    BANKSEL SRCON
    CLRF    SRCON
    BANKSEL CCP1CON
    CLRF    CCP1CON
    CLRF    CCP2CON
    ;--- PORTC: RC7=1 RX, RC6=1 TX, RC5=0 TX_LED, RC4=1 (input, no RX LED)
    BANKSEL TRISC
    MOVLW   0b11010000      ; .7=1 .6=1 .5=0 .4=1
    MOVWF   TRISC
    BANKSEL PORTC
    CLRF    PORTC           ; TX LED off

    ;--- USART 9600 8N1 BRGH=1
    BANKSEL TXSTA
    MOVLW   0b00100100
    MOVWF   TXSTA
    BANKSEL RCSTA
    MOVLW   0b10010000
    MOVWF   RCSTA
    BANKSEL SPBRG
    MOVLW   25
    MOVWF   SPBRG

;--- handshake -------------------------------------------------
HANDSHAKE:
    BANKSEL PIR1
    BTFSS   PIR1,5          ; RCIF=1?
    GOTO    HANDSHAKE
    BANKSEL RCREG
    MOVF    RCREG,W
    SUBLW   0x24
    BTFSS   STATUS,2
    GOTO    HANDSHAKE
    MOVLW   0x24
    CALL    SEND_BYTE_TRMT  ; echo '$' with TX LED

;--- main echo loop -------------------------------------------
ECHO_LOOP:
    BANKSEL PIR1
    BTFSS   PIR1,5
    GOTO    ECHO_LOOP
    BANKSEL RCSTA
    BTFSC   RCSTA,1
    GOTO    RESET_CREN
    BTFSC   RCSTA,2
    GOTO    RESET_CREN
    BANKSEL RCREG
    MOVF    RCREG,W
    CALL    SEND_BYTE_TRMT  ; echo with TX LED
    GOTO    ECHO_LOOP

RESET_CREN:
    BANKSEL RCSTA
    BCF     RCSTA,4
    BSF     RCSTA,4
    GOTO    ECHO_LOOP

;=================================================================
; SEND_BYTE_TRMT ? TX LED (RC5) full byte pulse
; High: TXREG write, Low: TRMT=1 (TSR empty)
;=================================================================
SEND_BYTE_TRMT:
    BANKSEL PORTC
    BSF     PORTC,5         ; TX LED ON
    BANKSEL TXREG
    MOVWF   TXREG           ; start TX
    BANKSEL TXSTA
WAIT_TRMT:
    BTFSS   TXSTA,1         ; TRMT=1?
    GOTO    WAIT_TRMT
    BANKSEL PORTC
    BCF     PORTC,5         ; TX LED OFF
    RETURN

    END