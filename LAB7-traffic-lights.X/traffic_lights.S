;=================================================================
; Traffic Light Simulation for PIC16F883 with Adaptive Extension, Version 1.0
; MPLAB 6.2, PIC-AS (XC8), 4MHz XT Oscillator
; Outputs: RC0=EW_Green, RC1=EW_Yellow, RC2=EW_Red, RC3=NS_Green, RC4=NS_Yellow, RC5=NS_Red, Active HIGH
; Inputs: RB0=EW_Car (active LOW), RB1=NS_Car (active LOW), detects short pulses via IOC
; Timer1: 500ms ticks, base 5s green (10 ticks), 1s yellow (2 ticks), cycle EW -> NS
; Extends green by 5s (restart ticks) on same-direction detection if no cross demand
; Sets cross demand on cross-detection to prevent extensions, clears on green entry
; 
; Integrates Timer1 for cycle timing, IOC on RB0/RB1 for detections.
; CROSS_DEMAND prevents endless extensions with cross traffic, resets on new green.
; IOC catches short pulses via change trigger and level check in ISR
;=================================================================

#include <xc.inc>                 ; Include XC8 header for PIC16F883

; Device Configuration (matches both programs)
    CONFIG  FOSC = XT         ; Set external crystal osc up to 4MHz
    CONFIG  WDTE = OFF        ; Turn off watchdog to avoid resets
    CONFIG  PWRTE = OFF       ; No power-up timer for quick start
    CONFIG  MCLRE = ON        ; Enable MCLR for reset
    CONFIG  CP = OFF          ; No code protect for access
    CONFIG  CPD = OFF         ; No EEPROM data protect
    CONFIG  BOREN = OFF       ; No brown-out reset
    CONFIG  IESO = OFF        ; No clock switchover
    CONFIG  FCMEN = OFF       ; No fail-safe clock monitor
    CONFIG  LVP = OFF         ; No low-voltage programming
    CONFIG  WRT = OFF         ; No flash write protect

;=================================================================
; Constants and Variables
;=================================================================
    ; Tick counts for phases
GREEN_TICKS    equ  10        ; 5s green: 10 x 500ms ticks
YELLOW_TICKS   equ  2         ; 1s yellow: 2 x 500ms ticks

    ; Vars in Bank 0 for access
    psect udata_bank0, global ; Start bank0 data section
CURRENT_STATE:  ds  1         ; Holds state: 0=EW_G,1=EW_Y,2=NS_G,3=NS_Y
TICK_COUNT:     ds  1         ; Ticks left in current state
CROSS_DEMAND:   ds  1         ; Cross detect flag, blocks extensions
W_SAVE:         ds  1         ; ISR W save
STATUS_SAVE:    ds  1         ; ISR STATUS save

;=================================================================
; Reset Vector
;=================================================================
    psect resetVect, class=CODE, delta=2, global
    org 0x0000                ; Reset loc at address 0
    goto START                ; Jump to main init code

;=================================================================
; Interrupt Vector
;=================================================================
    psect isrVect, class=CODE, delta=2, global
    org 0x0004                ; Int loc at address 4
    goto ISR                  ; Jump to ISR handler

;=================================================================
; ISR Code Section
;=================================================================
; ISR handles Timer1 ticks and IOC detections, saves context.
; Prioritizes IOC for fast detect response, then Timer1.
    psect isrCode, class=CODE, delta=2, global
    org 0x0008                ; ISR code loc at address 8
ISR:
    movwf W_SAVE              ; Save W reg for context restore
    swapf STATUS, W           ; Swap STATUS to W, no flag change
    movwf STATUS_SAVE         ; Save STATUS for context restore

    ; Check IOC flag
    banksel INTCON            ; Switch to INTCON bank
    btfsc INTCON, 0           ; IOCIF bit 0 set? (detect change)
    call HANDLE_IOC           ; Call IOC handler if flagged

    ; Check Timer1 flag
    banksel PIR1              ; Switch to PIR1 bank
    btfsc PIR1, 0             ; TMR1IF bit 0 set? (tick overflow)
    call HANDLE_TIMER1        ; Call timer handler if flagged

    ; Restore regs
    banksel STATUS_SAVE       ; Switch to save var bank
    movf STATUS_SAVE, W       ; Load saved STATUS to W
    movwf STATUS              ; Restore original STATUS
    movf W_SAVE, W            ; Restore original W
    retfie                    ; Return from int, re-enable GIE

HANDLE_IOC:
    banksel PORTB             ; Switch to PORTB bank
    movf PORTB, W             ; Read PORTB to clear mismatch condition
    banksel INTCON            ; Switch to INTCON bank
    bcf INTCON, 0             ; Clear IOCIF bit 0 to reset flag

    ; W holds PORTB for input tests

    ; Test EW car (RB0 low)
    btfsc PORTB, 0            ; RB0 high? Skip if low (detected)
    goto CHECK_NS_DETECT      ; No EW detect, check NS
    ; EW detected
    banksel CURRENT_STATE     ; Switch to state bank
    movf CURRENT_STATE, W     ; Load current state to W
    xorlw 0                   ; Compare to EW_Green (0)
    btfss STATUS, 2           ; Z=1 if match (EW_Green)
    goto EW_NOT_CURRENT       ; No match, check if NS_Green
    ; EW_Green, check cross
    banksel CROSS_DEMAND      ; Switch to flag bank
    btfsc CROSS_DEMAND, 0     ; Cross flag bit 0 set?
    goto CHECK_NS_DETECT      ; Yes, skip extend, check NS
    banksel TICK_COUNT        ; Switch to tick bank
    movlw GREEN_TICKS         ; Load full green tick count
    movwf TICK_COUNT          ; Restart ticks to extend green
    goto CHECK_NS_DETECT      ; Proceed to NS check
EW_NOT_CURRENT:
    xorlw 0 ^ 2               ; Compare to NS_Green (2)
    btfss STATUS, 2           ; Z=1 if match (NS_Green)
    goto CHECK_NS_DETECT      ; No match, proceed to NS check
    ; NS_Green + EW detect, set cross
    banksel CROSS_DEMAND      ; Switch to flag bank
    bsf CROSS_DEMAND, 0       ; Set bit 0 to flag cross demand

CHECK_NS_DETECT:
    btfsc PORTB, 1            ; RB1 high? Skip if low (detected)
    goto IOC_DONE             ; No NS detect, end handler
    ; NS detected
    banksel CURRENT_STATE     ; Switch to state bank
    movf CURRENT_STATE, W     ; Load current state to W
    xorlw 2                   ; Compare to NS_Green (2)
    btfss STATUS, 2           ; Z=1 if match (NS_Green)
    goto NS_NOT_CURRENT       ; No match, check if EW_Green
    ; NS_Green, check cross
    banksel CROSS_DEMAND      ; Switch to flag bank
    btfsc CROSS_DEMAND, 0     ; Cross flag set?
    goto IOC_DONE             ; Yes, skip extend, end
    banksel TICK_COUNT        ; Switch to tick bank
    movlw GREEN_TICKS         ; Load full green tick count
    movwf TICK_COUNT          ; Restart ticks to extend green
    goto IOC_DONE             ; End handler
NS_NOT_CURRENT:
    xorlw 2 ^ 0               ; Compare to EW_Green (0)
    btfss STATUS, 2           ; Z=1 if match (EW_Green)
    goto IOC_DONE             ; No match, end handler
    ; EW_Green + NS detect, set cross
    banksel CROSS_DEMAND      ; Switch to flag bank
    bsf CROSS_DEMAND, 0       ; Set bit 0 to flag cross demand

IOC_DONE:
    return                    ; Return from IOC handler

HANDLE_TIMER1:
    banksel PIR1              ; Switch to PIR1 bank
    bcf PIR1, 0               ; Clear TMR1IF bit 0 to reset flag
    ; Reload Timer1 for next 500ms interval (65536 - 62500 = 3036 or 0x0BDC)
    banksel TMR1H             ; Switch to TMR1H bank
    movlw 0x0B                ; Load high byte of preload (0x0B from 0x0BDC)
    movwf TMR1H               ; Set TMR1H to high byte for 500ms preload
    movlw 0xDC                ; Load low byte of preload (0xDC from 0x0BDC)
    movwf TMR1L               ; Set TMR1L to low byte for 500ms preload
    ; Handle tick
    banksel TICK_COUNT        ; Switch to tick bank
    movf TICK_COUNT, F        ; Load tick to set Z flag (test for zero)
    btfsc STATUS, 2           ; Zero? Skip if not (Z=0)
    goto ADVANCE_STATE        ; Zero ticks, advance to next state
    decf TICK_COUNT, F        ; Decrement remaining ticks
    return                    ; Ticks remain, return from handler

; Cycles states via branches, tables for ticks/lights.
; Clears cross on green (even states).
ADVANCE_STATE:
    banksel CURRENT_STATE     ; Switch to state bank
    movf CURRENT_STATE, W     ; Load state to W for comparison
    xorlw 0                   ; Compare to EW_Green (0)
    btfsc STATUS, 2           ; Z=1 if match
    goto TO_EW_YELLOW         ; Match, transition to EW yellow
    xorlw 0 ^ 1               ; Compare to EW_Yellow (1)
    btfsc STATUS, 2           ; Z=1 if match
    goto TO_NS_GREEN          ; Match, transition to NS green
    xorlw 1 ^ 2               ; Compare to NS_Green (2)
    btfsc STATUS, 2           ; Z=1 if match
    goto TO_NS_YELLOW         ; Match, transition to NS yellow
    goto TO_EW_GREEN          ; Otherwise, transition to EW green

TO_EW_GREEN:
    movlw 0                   ; Load state value 0 (EW_Green)
    movwf CURRENT_STATE       ; Update current state
    movlw TICK_COUNT_TABLE & 0xFF ; Load table base address
    movwf PCL                 ; Jump to table entry via PCL

TICK_COUNT_TABLE:
    goto TICK_EW_GREEN        ; Entry 0: EW_Green ticks
    goto TICK_EW_YELLOW       ; Entry 1: EW_Yellow ticks
    goto TICK_NS_GREEN        ; Entry 2: NS_Green ticks
    goto TICK_NS_YELLOW       ; Entry 3: NS_Yellow ticks

TICK_EW_GREEN:
    movlw GREEN_TICKS         ; Load green tick constant
    goto SET_TICK             ; Jump to set ticks
TICK_EW_YELLOW:
    movlw YELLOW_TICKS        ; Load yellow tick constant
    goto SET_TICK             ; Jump to set ticks
TICK_NS_GREEN:
    movlw GREEN_TICKS         ; Load green tick constant
    goto SET_TICK             ; Jump to set ticks
TICK_NS_YELLOW:
    movlw YELLOW_TICKS        ; Load yellow tick constant

SET_TICK:
    banksel TICK_COUNT        ; Switch to tick bank
    movwf TICK_COUNT          ; Store new tick count for phase
    ; Check for green clear
    banksel CURRENT_STATE     ; Switch to state bank
    movf CURRENT_STATE, W     ; Load state to W
    andlw 0x01                ; Mask to check if even (Z=1 for even/green)
    btfsc STATUS, 2           ; Even (green)? Skip if odd
    goto NO_CLEAR_DEMAND      ; Odd state, no clear needed
    banksel CROSS_DEMAND      ; Switch to flag bank
    clrf CROSS_DEMAND         ; Clear cross demand on new green entry
NO_CLEAR_DEMAND:
    banksel CURRENT_STATE     ; Switch to state bank
    movf CURRENT_STATE, W     ; Load state to W
    addlw LIGHT_STATE_TABLE & 0xFF ; Add table base offset
    movwf PCL                 ; Jump to light table entry via PCL

LIGHT_STATE_TABLE:
    goto LIGHT_EW_GREEN       ; Entry 0: EW_Green lights
    goto LIGHT_EW_YELLOW      ; Entry 1: EW_Yellow lights
    goto LIGHT_NS_GREEN       ; Entry 2: NS_Green lights
    goto LIGHT_NS_YELLOW      ; Entry 3: NS_Yellow lights

LIGHT_EW_GREEN:
    movlw 0b100001            ; EW Green (RC0=1), NS Red (RC5=1)
    goto SET_LIGHT            ; Jump to set outputs
LIGHT_EW_YELLOW:
    movlw 0b100010            ; EW Yellow (RC1=1), NS Red (RC5=1)
    goto SET_LIGHT            ; Jump to set outputs
LIGHT_NS_GREEN:
    movlw 0b001100            ; NS Green (RC3=1), EW Red (RC2=1)
    goto SET_LIGHT            ; Jump to set outputs
LIGHT_NS_YELLOW:
    movlw 0b010100            ; NS Yellow (RC4=1), EW Red (RC2=1)
SET_LIGHT:
    banksel PORTC             ; Switch to PORTC bank
    movwf PORTC               ; Update light outputs on PORTC
    return                    ; Return from state advance

TO_EW_YELLOW:
    movlw 1                   ; Load state value 1 (EW_Yellow)
    movwf CURRENT_STATE       ; Update current state
    movlw TICK_COUNT_TABLE & 0xFF + 1 ; Load entry 1 offset
    movwf PCL                 ; Jump to table entry

TO_NS_GREEN:
    movlw 2                   ; Load state value 2 (NS_Green)
    movwf CURRENT_STATE       ; Update current state
    movlw TICK_COUNT_TABLE & 0xFF + 2 ; Load entry 2 offset
    movwf PCL                 ; Jump to table entry

TO_NS_YELLOW:
    movlw 3                   ; Load state value 3 (NS_Yellow)
    movwf CURRENT_STATE       ; Update current state
    movlw TICK_COUNT_TABLE & 0xFF + 3 ; Load entry 3 offset
    movwf PCL                 ; Jump to table entry

;=================================================================
; Main Program
;=================================================================
; Sets ports, vars, timer, ints, idles.
; Disables unused to avoid issues. IOC on RB0/RB1 for changes.
    psect mainCode, class=CODE, delta=2, global
    org 0x0020                ; Main code loc at address 0x20
START:
    ; Clear ports initial
    banksel PORTC             ; Switch to PORTC bank
    clrf PORTC                ; Clear all outputs to off
    banksel PORTB             ; Switch to PORTB bank
    clrf PORTB                ; Clear PORTB (though inputs)
    banksel PORTA             ; Switch to PORTA bank
    clrf PORTA                ; Clear PORTA (unused inputs)

    ; Set start state/ticks/flag
    banksel CURRENT_STATE     ; Switch to vars bank
    clrf CURRENT_STATE        ; Set state 0: EW_Green start
    movlw GREEN_TICKS         ; Load initial green ticks
    movwf TICK_COUNT          ; Set starting tick count
    clrf CROSS_DEMAND         ; Clear cross demand flag

    ; Config I/O tris
    banksel TRISC             ; Switch to TRISC bank
    movlw 0xC0                ; RC0-5 outputs, RC6-7 inputs
    movwf TRISC               ; Set PORTC directions
    banksel TRISB             ; Switch to TRISB bank
    movlw 0xFF                ; All PORTB as inputs
    movwf TRISB               ; Set PORTB directions
    banksel TRISA             ; Switch to TRISA bank
    movlw 0xFF                ; All PORTA as inputs (unused)
    movwf TRISA               ; Set PORTA directions

    ; Disable unused features
    banksel ANSEL             ; Switch to ANSEL bank
    clrf ANSEL                ; Disable analog on PORTA/PORTC pins
    banksel ANSELH            ; Switch to ANSELH bank
    clrf ANSELH               ; Disable analog on PORTB pins (RB0/RB1 digital)
    banksel CM1CON0           ; Switch to comparator 1 bank
    clrf CM1CON0              ; Disable comparator 1 to avoid interference
    clrf CM2CON0              ; Disable comparator 2 to avoid interference
    banksel VRCON             ; Switch to VRCON bank
    clrf VRCON                ; Disable voltage reference module
    banksel ADCON0            ; Switch to ADCON0 bank
    clrf ADCON0               ; Disable ADC module
    clrf ADCON1               ; Clear ADC config (speed unused)

    ; Setup IOC on RB0/1
    banksel IOCB              ; Switch to IOCB bank
    movlw 0b00000011          ; Enable IOC on bits 0 and 1 (RB0/RB1)
    movwf IOCB                ; Set interrupt-on-change enables
    banksel PORTB             ; Switch to PORTB bank
    movf PORTB, W             ; Read PORTB to clear initial mismatch
    banksel INTCON            ; Switch to INTCON bank
    bcf INTCON, 0             ; Clear IOCIF flag
    bsf INTCON, 3             ; Enable IOCIE for changes

    ; Timer1 config
    banksel T1CON             ; Switch to T1CON bank
    movlw 0b00110001          ; Set 1:8 prescaler, internal clock, timer on
    movwf T1CON               ; Configure Timer1 control
    banksel TMR1H             ; Switch to TMR1H bank
    movlw 0x0B                ; Load high preload (0x0B from 0x0BDC for 500ms)
    movwf TMR1H               ; Set TMR1H to high byte for 500ms preload
    movlw 0xDC                ; Load low preload (0xDC from 0x0BDC for 500ms)
    movwf TMR1L               ; Set TMR1L to low byte for 500ms preload

    ; Enable interrupts
    banksel PIE1              ; Switch to PIE1 bank
    bsf PIE1, 0               ; Enable TMR1IE for timer interrupts
    banksel INTCON            ; Switch to INTCON bank
    bsf INTCON, 6             ; Enable PEIE for peripheral ints
    bsf INTCON, 7             ; Enable GIE for global interrupts

    ; Set start lights
    banksel PORTC             ; Switch to PORTC bank
    movlw 0b100001            ; EW Green + NS Red pattern
    movwf PORTC               ; Update initial light outputs

    ; Loop idle
MAIN_LOOP:
    goto MAIN_LOOP            ; Infinite loop, wait for interrupts

    end