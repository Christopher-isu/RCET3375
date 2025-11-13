;=================================================================
; 4x4 Keypad ? EXACT logic as your working 3x3 (pull-up, detect 0)
;=================================================================
    CONFIG  FOSC = XT
    CONFIG  WDTE = OFF
    CONFIG  PWRTE = OFF
    CONFIG  MCLRE = ON
    CONFIG  CP = OFF
    CONFIG  CPD = OFF
    CONFIG  BOREN = OFF
    CONFIG  IESO = OFF
    CONFIG  FCMEN = OFF
    CONFIG  LVP = OFF
    CONFIG  WRT = OFF

    #include <xc.inc>

    PSECT resetVect,class=CODE,delta=2
    GOTO    Start

    PSECT code,class=CODE,delta=2

ASCII   EQU 0x20
KEY     EQU 0x21

Start:
    BANKSEL TRISB
    MOVLW   0b11110000          ; RB0-3 out, RB4-7 in
    MOVWF   TRISB

    CLRF    TRISC

    BANKSEL ANSEL
    CLRF    ANSELH
    CLRF    ANSEL

    BANKSEL CM1CON0
    CLRF    CM1CON0
    CLRF    CM2CON0

    BANKSEL OPTION_REG
    BSF     OPTION_REG,7        ; disable weak pull-ups

    BANKSEL PORTB
    CLRF    PORTC

MainLoop:
    CLRF    KEY
    CLRF    ASCII

    ;--- Row 0: 1 2 3 A
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000001
    IORWF   PORTB,F
    NOP
    BTFSS   PORTB,4
    GOTO    r0_c1
    MOVLW   '1'
    MOVWF   ASCII
    BSF     KEY,0
r0_c1:
    BTFSS   PORTB,5
    GOTO    r0_c2
    MOVLW   '2'
    MOVWF   ASCII
    BSF     KEY,0
r0_c2:
    BTFSS   PORTB,6
    GOTO    r0_c3
    MOVLW   '3'
    MOVWF   ASCII
    BSF     KEY,0
r0_c3:
    BTFSS   PORTB,7
    GOTO    row1
    MOVLW   'A'
    MOVWF   ASCII
    BSF     KEY,0

    ;--- Row 1: 4 5 6 B
row1:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000010
    IORWF   PORTB,F
    NOP
    BTFSS   PORTB,4
    GOTO    r1_c1
    MOVLW   '4'
    MOVWF   ASCII
    BSF     KEY,0
r1_c1:
    BTFSS   PORTB,5
    GOTO    r1_c2
    MOVLW   '5'
    MOVWF   ASCII
    BSF     KEY,0
r1_c2:
    BTFSS   PORTB,6
    GOTO    r1_c3
    MOVLW   '6'
    MOVWF   ASCII
    BSF     KEY,0
r1_c3:
    BTFSS   PORTB,7
    GOTO    row2
    MOVLW   'B'
    MOVWF   ASCII
    BSF     KEY,0

    ;--- Row 2: 7 8 9 C
row2:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000100
    IORWF   PORTB,F
    NOP
    BTFSS   PORTB,4
    GOTO    r2_c1
    MOVLW   '7'
    MOVWF   ASCII
    BSF     KEY,0
r2_c1:
    BTFSS   PORTB,5
    GOTO    r2_c2
    MOVLW   '8'
    MOVWF   ASCII
    BSF     KEY,0
r2_c2:
    BTFSS   PORTB,6
    GOTO    r2_c3
    MOVLW   '9'
    MOVWF   ASCII
    BSF     KEY,0
r2_c3:
    BTFSS   PORTB,7
    GOTO    row3
    MOVLW   'C'
    MOVWF   ASCII
    BSF     KEY,0

    ;--- Row 3: * 0 # D
row3:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00001000
    IORWF   PORTB,F
    NOP
    BTFSS   PORTB,4
    GOTO    r3_c1
    MOVLW   '*'
    MOVWF   ASCII
    BSF     KEY,0
r3_c1:
    BTFSS   PORTB,5
    GOTO    r3_c2
    MOVLW   '0'
    MOVWF   ASCII
    BSF     KEY,0
r3_c2:
    BTFSS   PORTB,6
    GOTO    r3_c3
    MOVLW   '#'
    MOVWF   ASCII
    BSF     KEY,0
r3_c3:
    BTFSS   PORTB,7
    GOTO    output
    MOVLW   'D'
    MOVWF   ASCII
    BSF     KEY,0

output:
    MOVLW   0b11110000
    ANDWF   PORTB,F

    BTFSS   KEY,0
    GOTO    output_zero

    MOVF    ASCII,W
    IORLW   0b10000000
    MOVWF   PORTC
    BCF     PORTC,7
    NOP
    NOP
    GOTO    MainLoop

output_zero:
    MOVLW   '0' | 0b10000000
    MOVWF   PORTC
    BCF     PORTC,7
    NOP
    GOTO    MainLoop

    END