;=================================================================
; Traffic Light Simulation for PIC16F883
; MPLAB 6.2, PIC-AS (XC8), 4MHz XT Oscillator
; Outputs: RC0=EW_Green, RC1=EW_Yellow, RC2=EW_Red, RC3=NS_Green, RC4=NS_Yellow, RC5=NS_Red, Active HIGH
; Inputs: RB0 (EW car detect), RB1 (NS car detect), Active LOW, >=20us pulses
; Timer1: 500ms ticks
;=================================================================

#include <xc.inc>                 ; Generic XC8 header with -mcpu=PIC16F883

; Device Configuration (exactly as provided in first post)
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
; Constants and Variables
;=================================================================
    ; Constants
GREEN_TICKS    equ  10        ; 5s / 500ms = 10 ticks
YELLOW_TICKS   equ  2         ; 1s / 500ms = 2 ticks
CAR_TIMEOUT    equ  10        ; 5s timeout for car flags (5s / 500ms = 10 ticks)

    ; State machine states
EW_GREEN       equ  0x00
EW_YELLOW      equ  0x01
NS_GREEN       equ  0x02
NS_YELLOW      equ  0x03

    ; Light states for PORTC (RC0=EW_Green, RC1=EW_Yellow, RC2=EW_Red, RC3=NS_Green, RC4=NS_Yellow, RC5=NS_Red)
EW_GREEN_STATE  equ  0b100001  ; EW_Green (RC0=1) + NS_Red (RC5=1)
EW_YELLOW_STATE equ  0b100010  ; EW_Yellow (RC1=1) + NS_Red (RC5=1)
NS_GREEN_STATE  equ  0b001100  ; NS_Green (RC3=1) + EW_Red (RC2=1)
NS_YELLOW_STATE equ  0b010100  ; NS_Yellow (RC4=1) + EW_Red (RC2=1)

    ; Variable definitions in Bank 0
    psect udata_bank0, global
CURRENT_STATE:  ds  1         ; Current state (0-3)
TICK_COUNT:     ds  1         ; Remaining ticks for current state
EW_CAR_FLAG:    ds  1         ; 1 if EW car detected, 0 otherwise
NS_CAR_FLAG:    ds  1         ; 1 if NS car detected, 0 otherwise
EW_CAR_TIMEOUT: ds  1         ; Timeout counter for EW car flag
NS_CAR_TIMEOUT: ds  1         ; Timeout counter for NS car flag
W_SAVE:         ds  1         ; Save W in ISR
STATUS_SAVE:    ds  1         ; Save STATUS in ISR

;=================================================================
; Reset Vector
;=================================================================
    psect resetVect, class=CODE, delta=2, global
    org 0x0000                ; Reset vector (-presetVect=0h)
    goto START

;=================================================================
; Interrupt Vector
;=================================================================
    psect isrVect, class=CODE, delta=2, global
    org 0x0004                ; Interrupt vector (-pisrVect=4h)
    goto ISR

;=================================================================
; ISR Code Section
;=================================================================
    psect isrCode, class=CODE, delta=2, global
    org 0x0008                ; ISR code start (-pisrCode=8h)
ISR:
    ; Save context
    movwf W_SAVE
    swapf STATUS, W           ; Swap to avoid altering flags
    movwf STATUS_SAVE

    ; Check Timer1 interrupt (TMR1IF is bit 0 of PIR1)
    banksel PIR1
    btfsc PIR1, 0             ; TMR1IF
    call HANDLE_TIMER1

    ; Check IOC interrupt (RBIF is bit 3 of INTCON)
    banksel INTCON
    btfsc INTCON, 3           ; RBIF
    call HANDLE_IOC

    ; Restore context
    movf STATUS_SAVE, W
    movwf STATUS
    movf W_SAVE, W
    retfie

HANDLE_TIMER1:
    ; Clear Timer1 interrupt flag
    banksel PIR1
    bcf PIR1, 0               ; TMR1IF
    ; Reload Timer1 for ~500ms (4MHz/4/8 = 125kHz, 62500 counts)
    banksel TMR1H
    movlw 0x0B                ; High byte: 65536 - 62500 = 3036 (0x0BDC)
    movwf TMR1H
    movlw 0xDC                ; Low byte
    movwf TMR1L

    ; Update car flag timeouts
    movf EW_CAR_TIMEOUT, F
    btfss STATUS, 2           ; Skip if zero flag set (Z=1)
    decf EW_CAR_TIMEOUT, F    ; Decrement timeout
    btfsc STATUS, 2           ; Clear flag if timeout reaches 0
    clrf EW_CAR_FLAG

    movf NS_CAR_TIMEOUT, F
    btfss STATUS, 2           ; Skip if zero
    decf NS_CAR_TIMEOUT, F
    btfsc STATUS, 2           ; Clear flag if timeout reaches 0
    clrf NS_CAR_FLAG

    ; Update tick counter
    movf TICK_COUNT, F
    btfsc STATUS, 2           ; Skip if not zero
    goto ADVANCE_STATE        ; Zero: advance state
    decf TICK_COUNT, F        ; Decrement tick counter
    goto UPDATE_OUTPUTS

ADVANCE_STATE:
    ; State machine: advance based on CURRENT_STATE
    movf CURRENT_STATE, W
    xorlw EW_GREEN
    btfsc STATUS, 2
    goto TO_EW_YELLOW

    movf CURRENT_STATE, W
    xorlw EW_YELLOW
    btfsc STATUS, 2
    goto TO_NS_GREEN

    movf CURRENT_STATE, W
    xorlw NS_GREEN
    btfsc STATUS, 2
    goto TO_NS_YELLOW

    ; Must be NS_YELLOW
    goto TO_EW_GREEN

TO_EW_GREEN:
    movlw EW_GREEN
    movwf CURRENT_STATE
    movlw GREEN_TICKS
    movwf TICK_COUNT
    ; Check car flags for extension
    movf EW_CAR_FLAG, F
    btfsc STATUS, 2           ; No EW cars
    movf NS_CAR_FLAG, F       ; Check NS
    btfsc STATUS, 2           ; No cars in either
    goto UPDATE_OUTPUTS       ; Normal cycle
    btfss EW_CAR_FLAG, 0      ; EW cars?
    goto UPDATE_OUTPUTS       ; No EW, but NS cars: normal cycle
    ; EW cars: extend green
    movlw GREEN_TICKS
    movwf TICK_COUNT
    goto UPDATE_OUTPUTS

TO_EW_YELLOW:
    movlw EW_YELLOW
    movwf CURRENT_STATE
    movlw YELLOW_TICKS
    movwf TICK_COUNT
    goto UPDATE_OUTPUTS

TO_NS_GREEN:
    movlw NS_GREEN
    movwf CURRENT_STATE
    movlw GREEN_TICKS
    movwf TICK_COUNT
    ; Check car flags for extension
    movf NS_CAR_FLAG, F
    btfsc STATUS, 2           ; No NS cars
    movf EW_CAR_FLAG, F       ; Check EW
    btfsc STATUS, 2           ; No cars in either
    goto UPDATE_OUTPUTS       ; Normal cycle
    btfss NS_CAR_FLAG, 0      ; NS cars?
    goto UPDATE_OUTPUTS       ; No NS, but EW cars: normal cycle
    ; NS cars: extend green
    movlw GREEN_TICKS
    movwf TICK_COUNT
    goto UPDATE_OUTPUTS

TO_NS_YELLOW:
    movlw NS_YELLOW
    movwf CURRENT_STATE
    movlw YELLOW_TICKS
    movwf TICK_COUNT
    goto UPDATE_OUTPUTS

UPDATE_OUTPUTS:
    ; Set PORTC based on CURRENT_STATE
    banksel PORTC
    movf CURRENT_STATE, W
    xorlw EW_GREEN
    btfsc STATUS, 2
    movlw EW_GREEN_STATE
    btfsc STATUS, 2
    movwf PORTC

    movf CURRENT_STATE, W
    xorlw EW_YELLOW
    btfsc STATUS, 2
    movlw EW_YELLOW_STATE
    btfsc STATUS, 2
    movwf PORTC

    movf CURRENT_STATE, W
    xorlw NS_GREEN
    btfsc STATUS, 2
    movlw NS_GREEN_STATE
    btfsc STATUS, 2
    movwf PORTC

    movf CURRENT_STATE, W
    xorlw NS_YELLOW
    btfsc STATUS, 2
    movlw NS_YELLOW_STATE
    btfsc STATUS, 2
    movwf PORTC

    return

HANDLE_IOC:
    ; Clear IOC flag by reading PORTB
    banksel PORTB
    movf PORTB, W
    banksel INTCON
    bcf INTCON, 3             ; RBIF

    ; Check RB0 (EW) for falling edge
    banksel PORTB
    btfss PORTB, 0            ; RB0 high? Skip (no car)
    bsf EW_CAR_FLAG, 0        ; RB0 low: set EW car flag
    btfss PORTB, 0
    movlw CAR_TIMEOUT
    btfss PORTB, 0
    movwf EW_CAR_TIMEOUT      ; Reset timeout on detect

    ; Check RB1 (NS) for falling edge
    btfss PORTB, 1            ; RB1 high? Skip
    bsf NS_CAR_FLAG, 0        ; RB1 low: set NS car flag
    btfss PORTB, 1
    movlw CAR_TIMEOUT
    btfss PORTB, 1
    movwf NS_CAR_TIMEOUT      ; Reset timeout on detect

    return

;=================================================================
; Main Program
;=================================================================
    psect mainCode, class=CODE, delta=2, global
    org 0x0020                ; Program code start (-pcode=20h)
START:
    ; Initialize registers
    banksel PORTC
    clrf PORTC                ; Clear outputs
    banksel PORTB
    clrf PORTB
    clrf CURRENT_STATE        ; Start with EW_GREEN
    movlw GREEN_TICKS
    movwf TICK_COUNT
    clrf EW_CAR_FLAG
    clrf NS_CAR_FLAG
    clrf EW_CAR_TIMEOUT
    clrf NS_CAR_TIMEOUT

    ; Configure I/O
    banksel TRISC
    movlw 0xC0                ; RC0-RC5 outputs, RC6-RC7 default (unused)
    movwf TRISC
    banksel TRISB
    movlw 0x03                ; RB0-RB1 inputs
    movwf TRISB

    ; Disable unused peripherals
    banksel ANSEL
    clrf ANSEL                ; Disable analog inputs (RC0-RC5)
    banksel ANSELH
    clrf ANSELH               ; Disable analog inputs (RB0-RB1)
    banksel CM1CON0
    clrf CM1CON0              ; Disable comparator 1
    clrf CM2CON0              ; Disable comparator 2
    banksel VRCON
    clrf VRCON                ; Disable voltage reference
    banksel ADCON0
    clrf ADCON0               ; Disable ADC
    clrf ADCON1

    ; Configure Timer1 (~500ms ticks)
    banksel T1CON
    movlw 0b00110001          ; 1:8 prescaler, Timer1 on
    movwf T1CON
    banksel TMR1H
    movlw 0x0B                ; Preload for 500ms (65536 - 62500 = 3036)
    movwf TMR1H
    movlw 0xDC
    movwf TMR1L

    ; Configure interrupts
    banksel PIE1
    bsf PIE1, 0               ; TMR1IE (bit 0)
    banksel IOCB
    movlw 0x03                ; Enable IOC on RB0, RB1
    movwf IOCB
    banksel INTCON
    bsf INTCON, 3             ; RBIE (bit 3)
    bsf INTCON, 6             ; PEIE (bit 6)
    bsf INTCON, 7             ; GIE (bit 7)

    ; Set initial output (EW_GREEN_STATE)
    banksel PORTC
    movlw EW_GREEN_STATE
    movwf PORTC

    ; Main loop (idle)
MAIN_LOOP:
    goto MAIN_LOOP            ; Wait for interrupts

    end