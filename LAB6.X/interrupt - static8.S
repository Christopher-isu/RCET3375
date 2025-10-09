;=================================================================
; Device Configuration
;=================================================================
    config  FOSC = XT               ; Use external 8 MHz crystal
    config  WDTE = OFF              ; Disable watchdog timer
    config  PWRTE = OFF             ; Disable power-up timer
    config  MCLRE = ON              ; Enable MCLR pin
    config  CP = OFF                ; Disable code protection
    config  CPD = OFF               ; Disable data memory protection
    config  BOREN = OFF             ; Disable brown-out reset
    config  IESO = OFF              ; Disable clock switchover
    config  FCMEN = OFF             ; Disable fail-safe clock monitor
    config  LVP = OFF               ; Disable low-voltage programming
    config  BOR4V = BOR40V          ; Brown-out voltage (ignored if BOREN=OFF)
    config  WRT = OFF               ; Disable Flash write protection

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>

;=================================================================
; Variable Definitions
;=================================================================
    psect udata_bank0,class=RAM,space=1,delta=1
Timer1Count: ds 1                   ; Reserve 1 byte for Timer1 overflow counter

;=================================================================
; Reset Vector
;=================================================================
    psect resetVec,class=CODE,delta=2,abs
    org 0x0000
    goto Start                      ; Jump to main code on reset

;=================================================================
; Interrupt Vector
;=================================================================
    psect intVec,class=CODE,delta=2,abs
    org 0x0004
    goto ISR                        ; Jump to ISR on interrupt

;=================================================================
; Main Code Section
;=================================================================
    psect code,class=CODE,delta=2

Start:
    ; Set PORTC as output
    banksel TRISC               ; Select Bank 1
    clrf    TRISC               ; All PORTC bits as output

    ; Set RB0 as input
    bsf     TRISB, 0            ; RB0 as input

    ; Enable weak pull-up on RB0
    banksel OPTION_REG          ; Select Bank 1
    bcf     OPTION_REG, 7       ; Enable weak pull-ups (NOT_RBPU = 0)
    banksel WPUB                ; Select Bank 2
    bsf     WPUB, 0             ; Enable pull-up on RB0

    ; Disable analog functions
    banksel ANSEL               ; Select Bank 3
    clrf    ANSEL               ; Disable analog on PORTA/C
    clrf    ANSELH              ; Disable analog on PORTB

    ; Disable comparators
    banksel CM1CON0             ; Select Bank 2
    clrf    CM1CON0
    clrf    CM2CON0

    ; Configure RB0 interrupt-on-change
    banksel IOCB                ; Select Bank 3
    bsf     IOCB, 0             ; Enable IOC on RB0

    ; Configure Timer1
    banksel T1CON               ; Select Bank 1
    movlw   0x30                ; Prescaler 1:8, Timer1 off
    movwf   T1CON

    ; Initialize Timer1 count
    banksel Timer1Count         ; Select Bank 0
    clrf    Timer1Count         ; Clear overflow counter

    ; Clear PORTC
    banksel PORTC               ; Select Bank 0
    clrf    PORTC

    ; Enable interrupts
    banksel INTCON              ; Select Bank 0
    bsf     INTCON, GIE         ; Enable global interrupts
    bsf     INTCON, RBIE        ; Enable RB port change interrupt
    bsf     INTCON, PEIE        ; Enable peripheral interrupts
    banksel PIR1                ; Select Bank 0
    bcf     PIR1, TMR1IF        ; Clear Timer1 interrupt flag
    banksel PIE1                ; Select Bank 1
    bsf     PIE1, TMR1IE        ; Enable Timer1 interrupt

DisplayASCII1:
    banksel PORTC               ; Select Bank 0
    movlw   0x31                ; ASCII code for '1' ? binary: 00110001
    iorlw   0x80                ; Set RC7 high (WE inactive)
    movwf   PORTC               ; Output to RC0?RC6, RC7 high
    bcf     PORTC, 7            ; Pull RC7 low to latch
    nop
    nop
    goto    DisplayASCII1       ; Loop to keep display latched

;=================================================================
; Interrupt Service Routine (ISR)
;=================================================================
ISR:
    ; Save context
    movwf   0x70                ; Save W in shared GPR (Bank 0/1)
    swapf   STATUS, W           ; Save STATUS (SWAPF avoids status change)
    banksel 0x71                ; Select Bank 0/1 for shared GPR
    movwf   0x71                ; Save STATUS in shared GPR

    ; Check RB0 interrupt-on-change
    banksel INTCON              ; Select Bank 0
    btfsc   INTCON, RBIF        ; Check if RBIF is set
    goto    HandleRB0           ; Handle RB0 interrupt

    ; Check Timer1 overflow
    banksel PIR1                ; Select Bank 0
    btfsc   PIR1, TMR1IF        ; Check if TMR1IF is set
    goto    HandleTimer1        ; Handle Timer1 interrupt

    goto    ISR_Exit            ; No relevant interrupt, exit

HandleRB0:
    ; Read PORTB to clear mismatch condition
    banksel PORTB               ; Select Bank 0
    movf    PORTB, W            ; Read PORTB to clear IOC

    ; Check if RB0 is low
    btfsc   PORTB, 0            ; Skip if RB0 is low
    goto    ClearRBIF           ; RB0 is high, clear flag and exit

    ; Start Timer1 and display '7'
    banksel Timer1Count         ; Select Bank 0
    clrf    Timer1Count         ; Reset overflow counter
    banksel PORTC               ; Select Bank 0
    movlw   0x37                ; ASCII code for '7' ? binary: 00110111
    iorlw   0x80                ; Set RC7 high (WE inactive)
    movwf   PORTC               ; Output to RC0?RC6, RC7 high
    bcf     PORTC, 7            ; Pull RC7 low to latch
    nop
    nop
    banksel T1CON               ; Select Bank 1
    bsf     T1CON, TMR1ON       ; Start Timer1

ClearRBIF:
    banksel INTCON              ; Select Bank 0
    bcf     INTCON, RBIF        ; Clear RB port change interrupt flag
    goto    ISR_Exit

HandleTimer1:
    banksel PIR1                ; Select Bank 0
    bcf     PIR1, TMR1IF        ; Clear Timer1 interrupt flag
    banksel Timer1Count         ; Select Bank 0
    incf    Timer1Count, F      ; Increment overflow counter
    movlw   4                   ; Compare with 4 overflows (~2 seconds)
    subwf   Timer1Count, W
    btfss   STATUS, Z           ; Skip if Timer1Count == 4
    goto    ISR_Exit            ; Not yet 2 seconds, exit

    ; 2 seconds elapsed, revert to '1' and stop Timer1
    banksel T1CON               ; Select Bank 1
    bcf     T1CON, TMR1ON       ; Stop Timer1
    banksel Timer1Count         ; Select Bank 0
    clrf    Timer1Count         ; Clear overflow counter
    banksel PORTC               ; Select Bank 0
    movlw   0x31                ; ASCII code for '1' ? binary: 00110001
    iorlw   0x80                ; Set RC7 high (WE inactive)
    movwf   PORTC               ; Output to RC0?RC6, RC7 high
    bcf     PORTC, 7            ; Pull RC7 low to latch
    nop
    nop

ISR_Exit:
    ; Restore context
    banksel 0x71                ; Select Bank 0/1 for shared GPR
    swapf   0x71, W             ; Restore STATUS
    movwf   STATUS
    movf    0x70, W             ; Restore W
    retfie                      ; Return from interrupt

    end