;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = XT         ; External oscillator up to 4MHz
    CONFIG  WDTE = OFF        ; Disable watchdog timer
    CONFIG  PWRTE = OFF       ; Disable power-up timer
    CONFIG  MCLRE = ON        ; Enable MCLR pin for external reset
    CONFIG  CP = OFF          ; Disable code protection
    CONFIG  CPD = OFF         ; Disable data memory protection
    CONFIG  BOREN = OFF       ; Disable brown-out reset
    CONFIG  IESO = OFF        ; Disable clock switchover
    CONFIG  FCMEN = OFF       ; Disable fail-safe clock monitor
    CONFIG  LVP = OFF         ; Disable low-voltage programming
    CONFIG  WRT = OFF         ; Disable Flash write protection

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>         ; Include PIC16F883 register definitions

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    GOTO Start

;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2

;=================================================================
; Reserve working registers in RAM
;=================================================================
Delay1  EQU 0x20  ; Delay loop counter 1
Delay2  EQU 0x21  ; Delay loop counter 2
Delay3  EQU 0x22  ; Delay loop counter 3

;=================================================================
; Initialization
;=================================================================
Start:
    ; Disable comparators (Bank 0)
    CLRF  CM1CON0	 ; Disable comparator 1
    CLRF  CM2CON0	 ; Disable comparator 2
   
    ; Select Bank 1 for TRISB, OPTION_REG
    BSF	  STATUS, 5	 ; RP0 = 1 (Bank 1)
    BCF	  STATUS, 6	 ; RP1 = 0
    MOVLW 0x00		 ; Move b0000 0000 to W
    MOVWF TRISB		 ; Move from W to TRISB to set all PORTB as outputs
    BCF	  OPTION_REG, 7	 ; RBPU = 1, disable PORTB pull-ups
    BCF   INTCON, 3	 ; Clear bit 3 (RBIE), disable PORTB change interrupt    
    
    ; Select Bank 3 for ANSELH
    BSF   STATUS, 6	 ; RPI = 1 (Bank 3)
    MOVLW 0x00		 ; Write b0000 0000 to W)
    MOVWF  ANSELH	 ; Write W to ANSELH (AN12-AN8) to set all PORTB digital   
    
    ; Select Bank 0 for PORTB
    BCF   STATUS, 5	 ; RP0 = 0 (Bank 0)
    BCF   STATUS, 6	 ; RP1 = 0
    CLRF  PORTB		 ; Clear PORTB (all pins = 0)    

;=================================================================
; Main Loop
;=================================================================
MainLoop:    
    ; Toggle RB0 directly
    MOVLW 0x01		 ; Load b0000 0001 to W
    XORWF PORTB, F	 ; Apply mask from W to PORTB and save result in register
    ;XORWF PORTB, F       ; Toggle RB0 (PORTB ^= 0x01)
    ; Delay ~1000 us at 4 MHz
    CALL  Delay
    GOTO  MainLoop

;=================================================================
; Delay Subroutine (~96us at 4 MHz)
;=================================================================
Delay:
    MOVLW 0x21           ; Set outermost loop counter (33 iterations)
    MOVWF Delay3
OuterLoop:
    MOVLW 0x32           ; Set middle loop counter (50 iterations)
    MOVWF Delay2
MiddleLoop:
    MOVLW 0x63           ; Set inner loop counter (99 iterations)
    MOVWF Delay1
InnerLoop:
    DECFSZ Delay1, F     ; Decrement Delay1, skip if zero
    GOTO   InnerLoop
    DECFSZ Delay2, F     ; Decrement Delay2, skip if zero
    GOTO   MiddleLoop
    DECFSZ Delay3, F     ; Decrement Delay3, skip if zero
    GOTO   OuterLoop
    RETURN  
 

    END