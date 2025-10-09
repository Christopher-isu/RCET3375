;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = XT         ; External crystal oscillator, up to 4 MHz
    CONFIG  WDTE = OFF        ; Disable Watchdog Timer
    CONFIG  PWRTE = OFF       ; Disable Power-up Timer
    CONFIG  MCLRE = ON        ; Enable MCLR pin
    CONFIG  CP = OFF          ; Disable code protection
    CONFIG  CPD = OFF         ; Disable data EEPROM protection
    CONFIG  BOREN = OFF       ; Disable Brown-out Reset
    CONFIG  IESO = OFF        ; Disable Internal/External Switchover
    CONFIG  FCMEN = OFF       ; Disable Fail-Safe Clock Monitor
    CONFIG  LVP = OFF         ; Disable Low-Voltage Programming
    CONFIG  WRT = OFF         ; Disable Flash write protection

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>               ; Include PIC16F883 register definitions

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    GOTO Start
    
;=================================================================
; Reserve Working Registers in RAM
;=================================================================
    ; Allocate registers in General Purpose RAM (Bank 0, 0x20-0x6F)
Delay1  EQU 0x20  ; Delay loop counter 1 (inner loop)

  
;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2

Start:
    ; Configure PORTB: RB0 input, RB1-RB7 inputs (unused)
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for TRISB access
    MOVLW   0b11111111  ; All RB0-RB7=1 (inputs), but only RB0 used
    MOVWF   TRISB       ; Set PORTB direction

    ; Configure PORTA: RA0 output, RA1-RA7 inputs (unused, but RA6/RA7 may not exist)
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISA access
    MOVLW   0b11111110  ; RA0=0 (output), RA1-RA5=1 (inputs)
    MOVWF   TRISA       ; Set PORTA direction

    ; Disable analog functions for digital I/O
    BSF STATUS, 6       ; Select Bank 3 (RP1=1, RP0=1)
    BSF STATUS, 5       ; for ANSEL/ANSELH
    CLRF    ANSELH      ; Disable analog on PORTB
    CLRF    ANSEL       ; Disable analog on PORTA/C

    ; Disable comparators
    BSF STATUS, 6       ; Select Bank 2 (RP1=1, RP0=0)
    BCF STATUS, 5       ; for CM1CON0/CM2CON0
    CLRF    CM1CON0     ; Turn off comparator 1
    CLRF    CM2CON0     ; Turn off comparator 2

    ; Disable PORTB weak pull-ups
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OPTION_REG
    BSF     OPTION_REG, 7 ; Disable internal pull-ups

    ; Initialize PORTB and PORTA to low
    BCF STATUS, 6       ; Select Bank 0 (RP1=0, RP0=0)
    BCF STATUS, 5       ; for PORTB/A access
    CLRF    PORTB       ; Clear PORTB (though inputs)
    CLRF    PORTA       ; Clear PORTA (RA0=0)

MainLoop:
    BTFSS   PORTB, 0    ; Skip if RB0 is high (1)
    GOTO    Toggle      ; If low (0), go to toggle
    BCF     PORTA, 0    ; If high, set RA0 low (do nothing means idle low)
    GOTO    MainLoop    ; Repeat

Toggle:
    MOVF    PORTA, W    ; Read PORTA into W
    XORLW   0x01        ; Toggle the LSB (RA0)
    MOVWF   PORTA       ; Write back to PORTA
    NOP
    
    CALL    DelayLoop       ; Call delay
    GOTO    MainLoop    ; Back to check RB0 again

DelayLoop:
    MOVLW   0xA2        ; 1 cycle (loads literal 0xA2 into W register)
    MOVWF   Delay1      ; 1 cycle (moves W to Delay1 register)

InnerLoop:    
    DECFSZ  Delay1      ; 1 cycle if result != 0 (2 cycles if skip)
    GOTO    InnerLoop   ; 2 cycles (unconditional branch back to InnerLoop)    
    RETURN              ; 2 cycles (returns from subroutine, popping return address)

;=================================================================
; End of Program
;=================================================================
    END