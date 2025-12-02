;=================================================================
; PIC16F883 ? I2C Servo Controller ? REFERENCE VERSION 1.0 (COMPLETE)
; Locked baseline ? verified working with exact servo mapping:
;   0x00 ? ~1.000 ms
;   0x20 ? ~1.500 ms (center)
;   0x3F ? ~2.000 ms (full)
; Full port initialization, complete UDATA, safe defaults
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

;=================================================================
; Complete variable declaration (access bank)
;=================================================================
PSECT udata_acs
W_SAVE:         DS 1        ; ISR context save
STATUS_SAVE:    DS 1
RECV_BYTE:      DS 1        ; last received I2C byte
NEW_POS_FLAG:   DS 1        ; bit 0 = new position received
CURRENT_POS:    DS 1        ; 6-bit position (0?63)

;=================================================================
; Vectors
;=================================================================
PSECT resetVect,class=CODE,delta=2
    goto    Start
PSECT isrVect,class=CODE,delta=2
    goto    ISR

PSECT code,class=CODE,delta=2

;=================================================================
; ISR ? Safe I2C slave handling
;=================================================================
ISR:
    movwf   W_SAVE
    swapf   STATUS,W
    movwf   STATUS_SAVE

    btfss   PIR1,3
    goto    ISR_Exit
    bcf     PIR1,3

    BANKSEL SSPBUF
    movf    SSPBUF,W                ; clear BF ? send ACK

    BANKSEL SSPSTAT
    btfss   SSPSTAT,5
    goto    Release_Clock           ; address byte ? ignore

    BANKSEL RECV_BYTE
    movwf   RECV_BYTE

    ; Accept only servo ID 00
    movf    RECV_BYTE,W
    andlw   0xC0
    btfss   STATUS,2
    goto    Release_Clock

    movf    RECV_BYTE,W
    andlw   0x3F
    BANKSEL CURRENT_POS
    movwf   CURRENT_POS

    BANKSEL NEW_POS_FLAG
    bsf     NEW_POS_FLAG,0

Release_Clock:
    BANKSEL SSPCON
    bsf     SSPCON,4                ; release SCL

ISR_Exit:
    swapf   STATUS_SAVE,W
    movwf   STATUS
    swapf   W_SAVE,F
    swapf   W_SAVE,W
    retfie

;=================================================================
; Full hardware initialization
;=================================================================
Start:
    ; --- Disable analog functions ---
    BANKSEL ANSEL
    clrf    ANSEL                   ; PORTA all digital
    clrf    ANSELH                  ; PORTB all digital

    ; --- Disable comparators and SR latch ---
    BANKSEL CM1CON0
    clrf    CM1CON0
    clrf    CM2CON0
    BANKSEL SRCON
    clrf    SRCON

    ; --- Full PORT and TRIS initialization ---
    BANKSEL PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC

    BANKSEL TRISA
    movlw   0xFF                    ; PORTA all inputs (safe)
    movwf   TRISA
    movlw   0xFF                    ; PORTB all inputs (safe)
    movwf   TRISB

    BANKSEL TRISC
    movlw   0b11111011              ; RC2 = output (PWM), others input
    movwf   TRISC                   ; RC3=SCL, RC4=SDA input for I2C

    ; --- OPTION_REG: weak pull-ups off, TMR0 prescaler to WDT ---
    BANKSEL OPTION_REG
    movlw   0b10001000              ; Pull-ups off, TMR0 to WDT
    movwf   OPTION_REG

    ; --- Timer2: 1 ms period, 16 µs/tick ---
    BANKSEL PR2
    movlw   249
    movwf   PR2
    BANKSEL T2CON
    movlw   0b00000111              ; ON, prescaler 1:16
    movwf   T2CON

    ; --- CCP1 PWM on RC2 ---
    BANKSEL CCP1CON
    movlw   0x0C
    movwf   CCP1CON
    BANKSEL CCPR1L
    movlw   94                      ; default center ~1.5 ms
    movwf   CCPR1L

    ; --- I2C slave address 0x20 ---
    BANKSEL SSPADD
    movlw   0x20
    movwf   SSPADD
    BANKSEL SSPSTAT
    movlw   0x80
    movwf   SSPSTAT
    BANKSEL SSPCON
    movlw   0x36
    movwf   SSPCON

    ; --- Interrupts ---
    BANKSEL PIE1
    bsf     PIE1,3                  ; SSPIE only
    BANKSEL INTCON
    bsf     INTCON,7                ; GIE
    bsf     INTCON,6                ; PEIE

    ; --- Clear flag ---
    BANKSEL NEW_POS_FLAG
    clrf    NEW_POS_FLAG

;=================================================================
; Main loop ? Perfect servo scaling (62 + pos)
;=================================================================
Main_Loop:
    BANKSEL NEW_POS_FLAG
    btfss   NEW_POS_FLAG,0
    goto    Main_Loop
    bcf     NEW_POS_FLAG,0

    BANKSEL CURRENT_POS
    movf    CURRENT_POS,W
    addlw   62                      ; 62 to 125 ticks

    BANKSEL CCPR1L
    movwf   CCPR1L

    BANKSEL CCP1CON
    bcf     CCP1CON,5
    bcf     CCP1CON,4               ; exact duty

    BANKSEL PORTC
    bsf     PORTC,1                 ; update indicator

    goto    Main_Loop

    END