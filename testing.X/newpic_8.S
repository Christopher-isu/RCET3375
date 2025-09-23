;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = INTRC_CLKOUT     ; Use internal oscillator with clock out on RA6
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
    
    
    
#include <xc.inc>
#include <pic16f883.inc>

; When assembly code is placed in a psect, it can be manipulated as a
; whole by the linker and placed in memory.  
;
; In this example, barfunc is the program section (psect) name, 'local' means
; that the section will not be combined with other sections even if they have
; the same name.  class=CODE means the barfunc must go in the CODE container.
; PIC18 should have a delta (addressible unit size) of 1 (default) since they
; are byte addressible.  PIC10/12/16 have a delta of 2 since they are word
; addressible.  PIC18 should have a reloc (alignment) flag of 2 for any
; psect which contains executable code.  PIC10/12/16 can use the default
; reloc value of 1.  Use one of the psects below for the device you use:

PSECT   barfunc,local,class=CODE,delta=2 ; PIC10/12/16
; psect   barfunc,local,class=CODE,reloc=2 ; PIC18

PSECT resetVect,class=CODE,delta=2
    GOTO Start

PSECT isrVect,class=CODE,delta=2
    RETFIE
    
PSECT code,class=CODE,delta=2

    
Start:    
    
BSF	  STATUS, 5	 ; RP0 = 1 (Bank 1)
BCF	  STATUS, 6	 ; RP1 = 0

BANKSEL PORTB
CLRF PORTB
    
BANKSEL TRISB
CLRF TRISB

BANKSEL PORTB
    
PSECT code
    
MainLoop:
    INCF PORTB,1
    GOTO MainLoop

global _bar ; extern of bar function goes in the C source file
_bar:
    movf PORTA,w    ; here we use a symbol defined via xc.inc
    ;BSF  STATUS, RP0
    return
END