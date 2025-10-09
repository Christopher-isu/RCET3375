#include <xc.inc>

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

    PSECT   udata_shr,class=COMMON,delta=1
W_TEMP:     DS      1
STATUS_TEMP:DS      1
COUNTER:    DS      1

    PSECT   resetVect,class=CODE,delta=2
resetVect:
    GOTO    MAIN

    PSECT   intVect,class=CODE,delta=2
    MOVWF   W_TEMP
    SWAPF   STATUS,W
    MOVWF   STATUS_TEMP

    ; Check interrupt sources
    BANKSEL INTCON
    BTFSC   INTCON,1        ; INTF set?
    GOTO    HANDLE_INT
    BANKSEL PIR1
    BTFSC   PIR1,0          ; TMR1IF set?
    GOTO    HANDLE_TMR1
    GOTO    ISR_END         ; Unexpected, exit

HANDLE_INT:
    BANKSEL INTCON
    BCF     INTCON,1        ; Clear INTF
    BCF     INTCON,4        ; Disable INTE during timeout
    BANKSEL PORTC
    MOVLW   0x37            ; Display '7'
    MOVWF   PORTC
    ; Start Timer1 for 2s
    BANKSEL COUNTER
    MOVLW   4               ; 3 full + 1 partial overflow
    MOVWF   COUNTER
    BANKSEL TMR1L
    CLRF    TMR1L
    CLRF    TMR1H
    BANKSEL PIE1
    BSF     PIE1,0          ; Enable TMR1IE
    BANKSEL T1CON
    MOVLW   0b00110000      ; Prescaler 1:8, internal clock
    MOVWF   T1CON
    BSF     T1CON,0         ; Enable TMR1
    GOTO    ISR_END

HANDLE_TMR1:
    BANKSEL PIR1
    BCF     PIR1,0          ; Clear TMR1IF
    BANKSEL COUNTER
    DECF    COUNTER,F
    MOVF    COUNTER,W
    BTFSC   STATUS,2        ; Check if COUNTER == 0 (Zero flag)
    GOTO    TIMEOUT         ; If COUNTER == 0, timeout

    MOVF    COUNTER,W       ; Reload W with updated counter
    MOVLW   1
    SUBWF   COUNTER,W       ; COUNTER - 1
    BTFSC   STATUS,2        ; Check if COUNTER == 1 (Zero flag)
    GOTO    SET_PARTIAL     ; If COUNTER == 1, set partial preload

    ; Else: full overflow again
    CLRF    TMR1L
    CLRF    TMR1H
    GOTO    ISR_END

SET_PARTIAL:
    BANKSEL TMR1L
    MOVLW   0x70            ; Low byte of 12144 (65536 - 53392)
    MOVWF   TMR1L
    MOVLW   0x2F            ; High byte
    MOVWF   TMR1H
    GOTO    ISR_END

TIMEOUT:
    BANKSEL T1CON
    BCF     T1CON,0         ; Disable TMR1
    BANKSEL PIE1
    BCF     PIE1,0          ; Disable TMR1IE
    BANKSEL PORTC
    MOVLW   0x31            ; Display '1'
    MOVWF   PORTC
    BANKSEL INTCON
    BSF     INTCON,4        ; Re-enable INTE
    GOTO    ISR_END

ISR_END:
    SWAPF   STATUS_TEMP,W
    MOVWF   STATUS
    SWAPF   W_TEMP,F
    SWAPF   W_TEMP,W
    RETFIE

    PSECT   code,class=CODE,delta=2
MAIN:
    CLRF    PORTC           ; Clear PORTC initially (RC7=0)
    BANKSEL TRISC
    CLRF    TRISC           ; Set PORTC as outputs
    BSF     TRISB,0         ; Set RB0 as input
    BANKSEL ANSELH
    BCF     ANSELH,4        ; Clear ANS12 for digital input on RB0
    BANKSEL OPTION_REG
    BCF     OPTION_REG,6    ; INTEDG=0: falling edge
    BANKSEL PORTB           ; Back to bank 0

    ; Initialize display to '1'
    MOVLW   0x31
    MOVWF   PORTC

    ; Check initial RB0 state
    BTFSC   PORTB,0         ; If high, enable INT and loop
    GOTO    ENABLE_INT
    ; Else low: treat as pressed, display '7' and start timeout (INTE remains disabled)
    MOVLW   0x37
    MOVWF   PORTC
    MOVLW   4
    MOVWF   COUNTER
    BANKSEL TMR1L
    CLRF    TMR1L
    CLRF    TMR1H
    BANKSEL PIE1
    BSF     PIE1,0
    BANKSEL T1CON
    MOVLW   0b00110000
    MOVWF   T1CON
    BSF     T1CON,0
    GOTO    ENABLE_GIE      ; Enable GIE (TMR1IE active)

ENABLE_INT:
    BANKSEL INTCON
    BCF     INTCON,1        ; Clear INTF
    BSF     INTCON,4        ; Enable INTE
ENABLE_GIE:
    BSF     INTCON,7        ; Enable GIE

LOOP:
    GOTO    LOOP            ; Idle loop (interrupts handle everything)

    END     resetVect
