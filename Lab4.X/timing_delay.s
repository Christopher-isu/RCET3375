;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = XT	            ; Use external oscillator up to 4MHz
    CONFIG  WDTE = OFF              ; Disable watchdog timer to prevent resets
    CONFIG  PWRTE = OFF             ; Disable power-up timer for immediate start
    CONFIG  MCLRE = ON              ; Enable MCLR pin for external reset
    CONFIG  CP = OFF                ; Disable code protection for development
    CONFIG  CPD = OFF               ; Disable data memory protection
    CONFIG  BOREN = OFF             ; Disable brown-out reset for stable power
    CONFIG  IESO = OFF              ; Disable clock switchover for internal osc
    CONFIG  FCMEN = OFF             ; Disable fail-safe clock monitor
    CONFIG  LVP = OFF               ; Disable low-voltage programming

    CONFIG  BOR4V = BOR40V          ; Set brown-out voltage (ignored, BOREN=OFF)
    CONFIG  WRT = OFF               ; Disable Flash write protection

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>               ; Include PIC16F883 register definitions

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2  ; Define reset vector section at 0x0000
    GOTO Start                        ; Jump to initialization on power-up/reset
    
;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2     ; Main program code section
 
;=================================================================
; Reserve working registers in RAM
;=================================================================
    Delay1  EQU 0x20
 
Start: 
    BSF	STATUS, RP0
    BCF	STATUS, RP1
    MOVLW 0xFE
    MOVWF TRISB
    
    
    BCF STATUS, RP0
    BCF STATUS, RP1
    CLRF PORTB

    
MainLoop:
    MOVF PORTB,0
    XORLW 0x01
    MOVWF PORTB    
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    GOTO MainLoop
    
    
    
END
 