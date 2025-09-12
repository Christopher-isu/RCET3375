;HEADER
;SPACE
;COURSE
;SEMESTER
;Program/Project
;Git URL
    
;Device Setup
;-----------------------------------------------------------------

;Configuration
; CONFIG1
  ;CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  FOSC = INTRC_CLKOUT
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
  
;Include Statements
#include <xc.inc>

    
;Code Section
;-----------------------------------------------------------------
    
;Register/Veriable Setup
  SOMEVALUE EQU 0x5f  ;assing value to a variable
    
;Start of Program
 PSECT resetVect,class=CODE,delta=2
 
 ORG 0x00	;Reset vector address
 GOTO Start
 
;Setup Code that runs once at power up/reset.
 PSECT code,class=CODE,delta=2
 Start:
    
    BANKSEL OSCCON
    MOVLW 0x61       ; IRCF = 110 (4MHz), SCS = 01 (use internal oscillator)
    MOVWF OSCCON
; === Bank 3 ===    
    BSF STATUS,5
    BSF STATUS,6
    CLRF TRISB
    CLRF ANSELH
    CLRF INTCON
    
    MOVLW 0X80
    MOVF OPTION_REG
    
; === Bank 2 ===
    BSF STATUS,6
    BCF STATUS,5
    CLRF CM2CON1
    
; === Bank 1 ===
    BSF STATUS,5
    BCF STATUS,6
    
    CLRF WPUB
    CLRF IOCB
    
; === Bank 0 ===
    BCF STATUS, 5
    BCF STATUS, 6
    CLRF CCP1CON
    CLRF PORTB
    
    
     
    

MainLoop:
    
    INCF PORTB, F

    GOTO    MainLoop      ; Repeat loop



   

;Sub
SomeSub:
    NOP
    RETURN
    
    

    
    
END ; The End
    

    
    
