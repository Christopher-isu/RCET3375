;=================================================================
; Description: Assembly code for PIC16F883 to toggle PORTC between ASCII '5' (0x35) and '0' (0x30)
;              with a ~500ms delay between states, using a 4 MHz oscillator.
;              PORTB bit 0 toggles between 1 and 0 accordingly.
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
    GOTO Start                          ; Jump to main initialization routine on reset

;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2       ; Define main code section for program logic

;=================================================================
; Reserve Working Registers in RAM
;=================================================================
    ; Allocate registers in General Purpose RAM
Delay1  EQU 0x20  ; Delay loop counter 1 (inner loop)
Delay2  EQU 0x21  ; Delay loop counter 2 (middle loop)
Delay3  EQU 0x22  ; Delay loop counter 3 (outer loop)
State   EQU 0x23  ; Toggle state (0 for ASCII '0', 1 for ASCII '5')

;=================================================================
; Initialization
;=================================================================
Start:
    ; Disable comparators to free up PORT pins
    CLRF  CM1CON0        ; Clear Comparator 1 Control Register (Bank 0, 0x19) to disable
    CLRF  CM2CON0        ; Clear Comparator 2 Control Register (Bank 0, 0x1D) to disable

    ; Select Bank 1 for TRISB, TRISC, OPTION_REG
    BSF   STATUS, 5      ; Set RP0 = 1 (Bank 1 selected)
    BCF   STATUS, 6      ; Clear RP1 = 0 (ensure Bank 1, not Bank 3)
    MOVLW 0x00           ; Load W with 0x00 (all bits output)
    MOVWF TRISB          ; Set PORTB as outputs (0 = output)
    MOVLW 0x00           ; Load W with 0x00 (all bits output)
    MOVWF TRISC          ; Set PORTC as outputs (0 = output)
    BCF   OPTION_REG, 7  ; Clear RBPU (bit 7) to disable PORTB weak pull-ups
    BCF   INTCON, 3      ; Clear RBIE (bit 3) to disable PORTB change interrupt

    ; Select Bank 3 for ANSEL, ANSELH
    BSF   STATUS, 6      ; Set RP1 = 1 (Bank 3 selected, with RP0 = 1)
    MOVLW 0x00           ; Load W with 0x00 (disable analog inputs)
    MOVWF ANSELH         ; Clear AN12-AN8 (PORTB pins digital)
    MOVLW 0x00           ; Load W with 0x00 (disable analog inputs)
    MOVWF ANSEL          ; Clear AN7-AN0 (PORTA, PORTC pins digital)

    ; Select Bank 0 for PORTB, PORTC
    BCF   STATUS, 5      ; Clear RP0 = 0
    BCF   STATUS, 6      ; Clear RP1 = 0
    CLRF  PORTB          ; Clear PORTB (all pins = 0)
    CLRF  PORTC          ; Clear PORTC (all pins = 0)
    CLRF  State          ; Initialize State to 0 (start with ASCII '0' output)

;=================================================================
; Delay Loop (~500ms at 4 MHz)
;=================================================================
PWDelay:
    ; Initialize outer loop counter (Delay3) for ~500ms delay
    MOVLW 0x21           ; Load W with 33 (decimal) for Delay3    
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)    
    MOVWF Delay3         ; Store in Delay3 (1 cycle)
OuterLoop:
    MOVLW 0x33           ; Load W with 51 (decimal) for Delay2
    MOVWF Delay2         ; Store in Delay2 (1 cycle)
MiddleLoop:
    MOVLW 0x61           ; Load W with 97 (decimal) for Delay1
    MOVWF Delay1         ; Store in Delay1 (1 cycle)
InnerLoop:
    DECFSZ Delay1        ; Decrement Delay1, skip if zero (1 cycle, 2 if skip)
    GOTO InnerLoop       ; Loop back (2 cycles)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    DECFSZ Delay2        ; Decrement Delay2, skip if zero (1 cycle, 2 if skip)
    GOTO MiddleLoop      ; Loop back to MiddleLoop (2 cycles)
    DECFSZ Delay3        ; Decrement Delay3, skip if zero (1 cycle, 2 if skip)
    GOTO OuterLoop       ; Loop back to OuterLoop (2 cycles)
    MOVLW 0x35           ; Load ASCII '5' (0011 0101) for PORTC
    MOVWF PORTC          ; Write to PORTC (RC0-RC6 = 011 0101, RC7 = 0, 1 cycle)
    MOVLW 0x01           ; Load W with 0x01 (RB0 = 1)
    MOVWF PORTB          ; Write to PORTB (RB0 = 1, others unchanged, 1 cycle)

PSDelay:
    ; Initialize outer loop counter (Delay3) for ~500ms delay (identical to PWDelay)
    MOVLW 0x21           ; Load W with 33 (decimal) for Delay3    
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)    
    MOVWF Delay3         ; Store in Delay3 (1 cycle)
OuterLoop2:
    MOVLW 0x33           ; Load W with 51 (decimal) for Delay2
    MOVWF Delay2         ; Store in Delay2 (1 cycle)
MiddleLoop2:
    MOVLW 0x61           ; Load W with 97 (decimal) for Delay1
    MOVWF Delay1         ; Store in Delay1 (1 cycle)
InnerLoop2:
    DECFSZ Delay1        ; Decrement Delay1, skip if zero (1 cycle, 2 if skip)
    GOTO InnerLoop2      ; Loop back (2 cycles)
    NOP                  ; No operation (1 cycle, padding for timing)
    NOP                  ; No operation (1 cycle, padding for timing)
    DECFSZ Delay2        ; Decrement Delay2, skip if zero (1 cycle, 2 if skip)
    GOTO MiddleLoop2     ; Loop back to MiddleLoop2 (2 cycles)
    DECFSZ Delay3        ; Decrement Delay3, skip if zero (1 cycle, 2 if skip)
    GOTO OuterLoop2      ; Loop back to OuterLoop2 (2 cycles)
    MOVLW 0x30           ; Load ASCII '0' (0011 0000) for PORTC
    MOVWF PORTC          ; Write to PORTC (RC0-RC6 = 011 0000, RC7 = 0, 1 cycle)
    MOVLW 0x00           ; Load W with 0x00 (RB0 = 0)
    MOVWF PORTB          ; Write to PORTB (RB0 = 0, others unchanged, 1 cycle)
    GOTO PWDelay         ; Loop back to PWDelay for continuous toggling (2 cycles)

    END                  ; End of program