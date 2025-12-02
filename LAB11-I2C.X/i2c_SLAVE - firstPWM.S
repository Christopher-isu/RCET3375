;=================================================================
; Reference Code v1.0 ? PIC16F883 I²C SLAVE SINGLE SERVO STABLE
; Verified stable PWM on RC2 (CCP1), I²C slave @0x20, foreground update
; Vector style proven with PIC-AS + your linker options (ORG removed from vectors)
; Linker: -Wa,-mcpu=PIC16F883,-alms -Wl,-presetVect=0h,-pisrVect=4h,-pudata_acs=0x70,-pcode=80h
;=================================================================
#include <xc.inc>

;=================================================================
; CONFIG BITS ? PIC-AS syntax (lowercase config)
;=================================================================
config FOSC = XT          ; external 4 MHz crystal
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
; RAM VARIABLES ? access bank
;=================================================================
PSECT udata_acs
W_SAVE:         DS 1     ; ISR W save
STATUS_SAVE:    DS 1     ; ISR STATUS save
SERVO1_TEMP:    DS 1     ; raw byte from I²C master
SERVO1_VAL:     DS 1     ; current scaled value for PWM

;=================================================================
; VECTORS ? PIC-AS compatible (no ORG inside non-abs PSECT)
;=================================================================
PSECT resetVect,class=CODE,delta=2
    goto    Start                ; reset vector

PSECT isrVect,class=CODE,delta=2
    goto    ISR                  ; interrupt vector

;=================================================================
; MAIN CODE SECTION
;=================================================================
PSECT code,class=CODE,delta=2

;=================================================================
; INTERRUPT SERVICE ROUTINE ? unchanged from your reference
;=================================================================
ISR:
    movwf   W_SAVE               ; save W
    swapf   STATUS,W             ; save STATUS no flag affect
    movwf   STATUS_SAVE
    btfsc   INTCON,2             ; T0IF heartbeat
    call    Heartbeat
    btfsc   PIR1,3               ; SSPIF I²C
    call    SspHandler
    swapf   STATUS_SAVE,W        ; restore STATUS
    movwf   STATUS
    swapf   W_SAVE,F             ; restore W double swapf
    swapf   W_SAVE,W
    retfie

;=================================================================
; Heartbeat ? toggle RA0 ~30 Hz proof-of-life
;=================================================================
Heartbeat:
    bcf     INTCON,2             ; clear T0IF
    BANKSEL PORTA
    movlw   1<<0
    xorwf   PORTA,F              ; toggle RA0
    return

;=================================================================
; SspHandler ? I²C slave receive only
;=================================================================
SspHandler:
    BANKSEL PIR1
    bcf     PIR1,3               ; clear SSPIF
    BANKSEL SSPSTAT
    btfss   SSPSTAT,5            ; D/A=1 data byte?
    goto    ReleaseClock
    BANKSEL SSPBUF
    movf    SSPBUF,W             ; read clears BF
    BANKSEL SERVO1_TEMP
    movwf   SERVO1_TEMP          ; buffer for main loop
ReleaseClock:
    BANKSEL SSPCON
    bsf     SSPCON,4             ; CKP=1 release clock
    return

;=================================================================
; INITIALIZATION ? 100% copy from your verified reference
;=================================================================
Start:
    BANKSEL OSCCON
    clrf    OSCCON               ; external 4 MHz XT
    BANKSEL ANSEL
    clrf    ANSEL
    clrf    ANSELH
    BANKSEL CM1CON0
    clrf    CM1CON0
    clrf    CM2CON0
    BANKSEL SRCON
    clrf    SRCON
    BANKSEL TRISA
    movlw   0b11111110           ; RA0 output heartbeat
    movwf   TRISA
    BANKSEL TRISC
    movlw   0b11111011           ; RC2 CCP1 out, RC3/RC4 SDA/SCL in
    movwf   TRISC
    BANKSEL PORTA
    clrf    PORTA
    BANKSEL PORTC
    clrf    PORTC
    BANKSEL PR2
    movlw   249                  ; 250 Hz frame
    movwf   PR2
    BANKSEL T2CON
    movlw   0b00000111
    movwf   T2CON
    BANKSEL CCP1CON
    movlw   0b00001100
    movwf   CCP1CON
    BANKSEL CCPR1L
    movlw   94                   ; centre 1.5 ms
    movwf   CCPR1L
    BANKSEL OPTION_REG
    movlw   0b00000111
    movwf   OPTION_REG
    BANKSEL TMR0
    clrf    TMR0
    BANKSEL INTCON
    bsf     INTCON,5             ; T0IE
    BANKSEL SSPADD
    movlw   0x40                 ; 0x20<<1
    movwf   SSPADD
    BANKSEL SSPSTAT
    movlw   0x80
    movwf   SSPSTAT
    BANKSEL SSPCON
    movlw   0x36
    movwf   SSPCON
    BANKSEL SSPCON2
    clrf    SSPCON2
    BANKSEL PIE1
    bsf     PIE1,3               ; SSPIE
    BANKSEL INTCON
    bsf     INTCON,6             ; PEIE
    bsf     INTCON,7             ; GIE
    BANKSEL SERVO1_VAL
    movlw   94
    movwf   SERVO1_VAL

;=================================================================
; MAIN LOOP ? unchanged, already has correct BANKSEL CCPR1L
;=================================================================
Main_Loop:
    BANKSEL SERVO1_TEMP
    movf    SERVO1_TEMP,W
    xorwf   SERVO1_VAL,W
    btfsc   STATUS,2             ; Z=1 no change
    goto    Main_Loop
    movf    SERVO1_TEMP,W
    BANKSEL SERVO1_VAL
    movwf   SERVO1_VAL
    BANKSEL CCPR1L               ; bank 1 for duty write
    movwf   CCPR1L               ; ×1
    addwf   CCPR1L,F             ; ×2
    movlw   31
    addwf   CCPR1L,F             ; +31 ? 0.5-2.5 ms
    BANKSEL CCP1CON
    bcf     CCP1CON,0
    bcf     CCP1CON,1
    goto    Main_Loop

    END