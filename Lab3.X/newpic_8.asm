;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = INTRC_CLKOUT     ; Internal oscillator with clock out
    CONFIG  WDTE = OFF              ; Watchdog Timer disabled
    CONFIG  PWRTE = OFF             ; Power-up Timer disabled
    CONFIG  MCLRE = ON              ; MCLR pin enabled
    CONFIG  CP = OFF                ; Code protection disabled
    CONFIG  CPD = OFF               ; Data memory protection disabled
    CONFIG  BOREN = OFF              ; Brown-out Reset disabled
    CONFIG  IESO = OFF               ; Internal/External Switchover disabled
    CONFIG  FCMEN = OFF              ; Fail-Safe Clock Monitor disabled
    CONFIG  LVP = OFF                ; Low-voltage programming disabled

    CONFIG  BOR4V = BOR40V          ; Brown-out Reset at 4.0V
    CONFIG  WRT = OFF               ; Flash memory write protection disabled

    
;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>



;=================================================================
; Reset Vector
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
;=================================================================
    PSECT resetVect,class=CODE,delta=2  ; PIC10/12/16
    ; psect   barfunc,local,class=CODE,reloc=2 ; PIC18
    GOTO Start
    
;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2

Start:
    ; Set up internal oscillator to 4 MHz
    BCF STATUS, 6       ; RP1 = 0
    BSF STATUS, 5       ; RP0 = 1 ? Bank 1
    MOVLW   0x61
    MOVWF   OSCCON      ; IRCF = 110 (4 MHz), SCS = 01

    ; Configure PORTB as input
    BCF STATUS, 6
    BSF STATUS, 5       ; Bank 1
    MOVLW   0xFF
    MOVWF   TRISB

    ; Configure PORTC as output
    BCF STATUS, 6
    BSF STATUS, 5       ; Bank 1
    CLRF    TRISC

    ; Disable analog functions
    BSF STATUS, 6
    BSF STATUS, 5       ; Bank 3
    CLRF    ANSELH

    BCF STATUS, 6
    BSF STATUS, 5       ; Bank 1
    CLRF    ANSEL

    ; Disable comparators
    CLRF    CM1CON0
    CLRF    CM2CON0

    ; Disable PORTB weak pull-ups
    BCF STATUS, 6
    BCF STATUS, 5       ; Bank 0
    BSF     OPTION_REG, 7

    ; Clear PORTC
    CLRF    PORTC

MainLoop:
    BCF STATUS, 6
    BCF STATUS, 5       ; Bank 0
    MOVF    PORTB, W    ; Read PORTB
    MOVWF   PORTC       ; Write to PORTC
    GOTO    MainLoop

;=================================================================
; Externally Callable Function: _bar
; If mixing C and assembly, call this assembly function from a C source file. 
;=================================================================
    global _bar         ; Makes _bar visible to C code

_bar:
    BCF STATUS, 6
    BCF STATUS, 5       ; Bank 0
    MOVF    PORTA, W    ; Read PORTA into WREG
    RETURN              ; Return to caller (WREG holds result)

;=================================================================
; End of Program
;=================================================================
    END
