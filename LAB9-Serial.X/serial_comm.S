;=================================================================
; Servo Echo via USART - this section sets PIC16F883 for RS232
; echo RX RC7 to TX RC6, 4MHz XT osc, async 9600 8N1 (BRGH=1
; SPBRG=25 <1% err), poll RCIF/TXIF, '$' handshake then byte echo
; loop, RC4 out high on RX data (RCIF=1) debug LED, disable unused
; (ADC/CM/CCP/SR) noise/power save, dummy isrVect/isrCode for
; linker -pisrVect=4h,-pisrCode=8h
;=================================================================
PROCESSOR 16F883
#include <xc.inc>
;=================================================================
; Device Configuration - this section sets 4MHz XT osc, disables
; WDT/PWRTE/BOREN/LVP/CP for power/debug/simple lab, MCLR on; no
; IESO/FCMEN single clk src stability
;=================================================================
CONFIG  FOSC = XT         ; 4MHz crystal osc
CONFIG  WDTE = OFF        ; no WDT unintended resets
CONFIG  PWRTE = OFF       ; immediate start
CONFIG  MCLRE = ON        ; ext reset pin
CONFIG  CP = OFF          ; no code prot access
CONFIG  CPD = OFF         ; no EEPROM prot
CONFIG  BOREN = OFF       ; no brown-out power simple
CONFIG  IESO = OFF        ; no clk switch single src
CONFIG  FCMEN = OFF       ; no clk monitor
CONFIG  LVP = OFF         ; no low-volt prog accidental
CONFIG  WRT = OFF         ; no flash prot full access
;=================================================================
; Variables (Bank0) - this section allocs Bank0 reg for temp recv
; byte, fast access in poll loop, min footprint
;=================================================================
PSECT udata_bank0, class=BANK0, space=1
RECV_BYTE:  DS 1            ; temp store recv byte for echo
;=================================================================
; Reset Vector - this section at 0x0000 by -presetVect=0h, no int
; poll-based, jump MAIN at 0x0020
;=================================================================
PSECT   resetVect, class=CODE, delta=2
GOTO    MAIN            ; to MAIN at 0x0020 program start
;=================================================================
; ISR Vector - this section dummy at 0x0004 by -pisrVect=4h, no
; interrupts, points to isrCode satisfy linker
;=================================================================
PSECT   isrVect, class=CODE, delta=2
GOTO    ISR_DUMMY       ; to dummy ISR at 0x0008
;=================================================================
; ISR Code - this section dummy at 0x0008 by -pisrCode=8h, no
; action poll-based, RETFIE satisfy linker
;=================================================================
PSECT   isrCode, class=CODE, delta=2
ISR_DUMMY:
RETFIE                  ; return no action, dummy ISR
;=================================================================
; Main Program - this section at 0x0020 by -pcode=20h, inits 4MHz
; osc, disables unused (ADC/CM/CCP/SR) noise/power save, TRISC
; RC7=1 RX RC6=1 TX RC4=0 LED out, USART async 9600, wait '$'
; handshake, echo '$', then inf recv-echo loop, RC4 high on RX
;=================================================================
PSECT   code, class=CODE, delta=2
MAIN:
BANKSEL OSCCON
CLRF    OSCCON          ; clear OSCCON use 4MHz XT (FOSC=XT)
; disable unused periphs save power/reduce noise
BANKSEL ANSEL
CLRF    ANSEL           ; clear ANSEL all digital
BANKSEL ANSELH
CLRF    ANSELH          ; clear ANSELH PORTB digital
BANKSEL CM1CON0
CLRF    CM1CON0         ; disable comp1
CLRF    CM2CON0         ; disable comp2
BANKSEL SRCON
CLRF    SRCON           ; disable SR latch
BANKSEL CCP1CON
CLRF    CCP1CON         ; disable CCP1
CLRF    CCP2CON         ; disable CCP2
; ports: TRISC RC7=1 RX RC6=1 TX (USART ctrl) RC4=0 LED out
BANKSEL TRISC
MOVLW   0b11010000      ; TRISC.7=1 RX, .6=1 TX, .4=0 LED
MOVWF   TRISC           ; config PORTC USART+LED
BANKSEL PORTC
CLRF    PORTC           ; clear PORTC init (RC4 low)
; USART: async master, 8-bit no parity, BRGH=1
BANKSEL TXSTA
MOVLW   0b00100100      ; TXSTA=0b00100100 (TXEN=1, SYNC=0, BRGH=1)
MOVWF   TXSTA           ; enable TX async high baud
BANKSEL RCSTA
MOVLW   0b10010000      ; RCSTA=0b10010000 (SPEN=1, CREN=1)
MOVWF   RCSTA           ; enable serial/recv
BANKSEL SPBRG
MOVLW   25              ; SPBRG=25 9600 baud 4MHz BRGH=1
MOVWF   SPBRG           ; load baud gen
; init vars
BANKSEL RECV_BYTE
CLRF    RECV_BYTE       ; clear RECV_BYTE init
; handshake: wait '$' (0x24)
HANDSHAKE:
BANKSEL PIR1
BTFSS   PIR1, 5         ; RCIF=1? skip
GOTO    HANDSHAKE       ; loop till recv
BANKSEL RCREG
MOVF    RCREG, W        ; read RCREG clear RCIF
SUBLW   0x24            ; W=0x24-W check '$'
BTFSS   STATUS, 2       ; zero? skip (is '$')
GOTO    HANDSHAKE       ; not '$' wait
; echo '$' ack
MOVLW   0x24            ; W=0x24 '$' TX
CALL    SEND_BYTE       ; send sub
; main echo loop: recv byte, RC4 high LED, echo back
ECHO_LOOP:
BANKSEL PIR1
BTFSS   PIR1, 5         ; RCIF=1? skip
GOTO    NO_RX           ; no data, clear RC4
BANKSEL PORTC
BSF     PORTC, 4        ; RC4=1 LED on RX data
BANKSEL RCSTA
BTFSC   RCSTA, 1        ; OERR=1? skip
GOTO    RESET_CREN      ; overrun reset CREN
BTFSC   RCSTA, 2        ; FERR=1? skip
GOTO    RESET_CREN      ; frame err reset CREN
BANKSEL RCREG
MOVF    RCREG, W        ; read RCREG clear RCIF
BANKSEL RECV_BYTE
MOVWF   RECV_BYTE       ; store RECV_BYTE
CALL    SEND_BYTE       ; send W
GOTO    ECHO_LOOP       ; loop
NO_RX:
BANKSEL PORTC
BCF     PORTC, 4        ; RC4=0 LED off no RX
GOTO    ECHO_LOOP       ; loop
; err handle: reset CREN clear OERR/FERR
RESET_CREN:
BANKSEL RCSTA
BCF     RCSTA, 4        ; CREN=0 disable recv
BSF     RCSTA, 4        ; CREN=1 re-enable clear errs
BANKSEL PORTC
BSF     PORTC, 4        ; RC4=1 LED on err (RX active)
GOTO    ECHO_LOOP       ; back loop
;=================================================================
; Send Byte Subroutine - this section polls TXIF, loads TXREG=W,
; simple poll TX sync send
;=================================================================
SEND_BYTE:
BANKSEL PIR1
BTFSS   PIR1, 4         ; TXIF=1? skip
GOTO    SEND_BYTE       ; loop ready
BANKSEL TXREG
MOVWF   TXREG           ; TXREG=W start TX
RETURN                  ; end
END