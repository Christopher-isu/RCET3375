;=================================================================
; Description: Assembly code for PIC16F883 to toggle PORTC between ASCII '5' (0x35) and '0' (0x30)
;              and PORTB bit 0 (RB0) between 1 and 0, with a ~500 ms delay between states,
;              using a 4 MHz oscillator.
; Datasheet: DS40001291H
;=================================================================

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

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>         ; Include PIC16F883 register definitions (e.g., STATUS, PORTB, TRISB)
                              ; Provided by XC8 compiler, maps registers to addresses

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2  ; Define reset vector at program memory address 0x0000
    GOTO Start                          ; Jump to initialization routine on reset (2 cycles)

;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2       ; Define main code section for program logic

;=================================================================
; Reserve Working Registers in RAM
;=================================================================
    ; Allocate registers in General Purpose RAM (Bank 0, 0x20-0x6F)
Delay1  EQU 0x20  ; Delay loop counter 1 (inner loop)
Delay2  EQU 0x21  ; Delay loop counter 2 (middle loop)
Delay3  EQU 0x22  ; Delay loop counter 3 (outer loop)
State   EQU 0x23  ; Toggle state (0 for ASCII '0', 1 for ASCII '5')

;=================================================================
; Initialization
;=================================================================
Start:
    ; Disable comparators to free up PORT pins
    CLRF  CM1CON0        ; Clear Comparator 1 Control Register (Bank 0, 0x19) to disable (1 cycle)
    CLRF  CM2CON0        ; Clear Comparator 2 Control Register (Bank 0, 0x1D) to disable (1 cycle)

    ; Select Bank 1 for TRISB, TRISC, OPTION_REG
    BSF   STATUS, 5      ; Set RP0 = 1 (Bank 1 selected) (1 cycle)
    BCF   STATUS, 6      ; Clear RP1 = 0 (ensure Bank 1, not Bank 3) (1 cycle)
    MOVLW 0x00           ; Load W with 0x00 (all bits output) (1 cycle)
    MOVWF TRISB          ; Set PORTB as outputs (0 = output) (1 cycle)
    MOVLW 0x00           ; Load W with 0x00 (all bits output) (1 cycle)
    MOVWF TRISC          ; Set PORTC as outputs (0 = output) (1 cycle)
    BCF   OPTION_REG, 7  ; Clear RBPU (bit 7) to disable PORTB weak pull-ups (1 cycle)
    BCF   INTCON, 3      ; Clear RBIE (bit 3) to disable PORTB change interrupt (1 cycle)

    ; Select Bank 3 for ANSEL, ANSELH
    BSF   STATUS, 6      ; Set RP1 = 1 (Bank 3 selected, with RP0 = 1) (1 cycle)
    MOVLW 0x00           ; Load W with 0x00 (disable analog inputs) (1 cycle)
    MOVWF ANSELH         ; Clear AN12-AN8 (PORTB pins digital) (1 cycle)
    MOVLW 0x00           ; Load W with 0x00 (disable analog inputs) (1 cycle)
    MOVWF ANSEL          ; Clear AN7-AN0 (PORTA, PORTC pins digital) (1 cycle)

    ; Select Bank 0 for PORTB, PORTC
    BCF   STATUS, 5      ; Clear RP0 = 0 (Bank 0 selected) (1 cycle)
    BCF   STATUS, 6      ; Clear RP1 = 0 (Bank 0 selected) (1 cycle)
    CLRF  PORTB          ; Clear PORTB (all pins = 0) (1 cycle)
    CLRF  PORTC          ; Clear PORTC (all pins = 0) (1 cycle)
    CLRF  State          ; Initialize State to 0 (start with ASCII '0' output) (1 cycle)

;=================================================================
; Main Loop
;=================================================================
MainLoop:
    ; Toggle RB0 directly
    MOVLW 0x01           ; Load W with 0x01 (for RB0 toggle) (1 cycle)
    XORWF PORTB, F       ; Toggle RB0 (PORTB ^= 0x01, only RB0 changes) (1 cycle)
    ; Set PORTC to ASCII '5' or '0' based on State
    BTFSC State, 0       ; Test bit 0 of State, skip if clear (State = 0) (1 cycle, 2 if skip)
    GOTO  SetFive        ; State = 1, jump to output '5' (2 cycles)
    ; Output '0' (0x30 = 0011 0000)
    MOVLW 0x30           ; Load ASCII '0' (1 cycle)
    MOVWF PORTC          ; Write to PORTC (RC0-RC6 = 011 0000, RC7 = 0) (1 cycle)
    GOTO  ToggleState    ; Jump to toggle State (2 cycles)
SetFive:
    ; Output '5' (0x35 = 0011 0101)
    MOVLW 0x35           ; Load ASCII '5' (1 cycle)
    MOVWF PORTC          ; Write to PORTC (RC0-RC6 = 011 0101, RC7 = 0) (1 cycle)
    NOP                  ; No operation, balance cycle count with '0' path (1 cycle)
ToggleState:
    MOVLW 0x01           ; Load W with 0x01 (for State toggle) (1 cycle)
    XORWF State, F       ; Toggle State (0 ? 1) (1 cycle)
    ; Delay ~500 ms at 4 MHz
    CALL  Delay          ; Call delay subroutine (2 cycles)
    GOTO  MainLoop       ; Loop back to continue toggling (2 cycles)

;=================================================================
; Delay Loop (~500 ms at 4 MHz)
;=================================================================
Delay:
    ; Initialize outer loop counter (Delay3) for ~500 ms delay
    MOVLW 0x21           ; Load W with 33 (decimal) for Delay3 (1 cycle)
    MOVWF Delay3         ; Store in Delay3 (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
OuterLoop:
    MOVLW 0x33           ; Load W with 51 (decimal) for Delay2 (1 cycle)
    MOVWF Delay2         ; Store in Delay2 (1 cycle)
MiddleLoop:
    MOVLW 0x61           ; Load W with 97 (decimal) for Delay1 (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    NOP                  ; No operation, padding for timing (1 cycle)
    MOVWF Delay1         ; Store in Delay1 (1 cycle)
InnerLoop:
    DECFSZ Delay1, F     ; Decrement Delay1, skip if zero (1 cycle, 2 if skip)
    GOTO   InnerLoop     ; Loop back to InnerLoop (2 cycles)
    DECFSZ Delay2, F     ; Decrement Delay2, skip if zero (1 cycle, 2 if skip)
    GOTO   MiddleLoop    ; Loop back to MiddleLoop (2 cycles)
    DECFSZ Delay3, F     ; Decrement Delay3, skip if zero (1 cycle, 2 if skip)
    GOTO   OuterLoop     ; Loop back to OuterLoop (2 cycles)
    RETURN               ; Return to caller (2 cycles)

    END                  ; End of program
