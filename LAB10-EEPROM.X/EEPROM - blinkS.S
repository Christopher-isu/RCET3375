;=================================================================
; 4x4 Keypad scanning + blinking "S" on idle
; Original logic restored with variables defined
; Compatible with PIC16F883 and PIC-AS (XC8) assembler
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

; Variable declarations (Bank0 RAM)
    PSECT udata_bank0
ASCII:      DS 1
KEY:        DS 1
blink_flag: DS 1
tmp1:       DS 1
tmp2:       DS 1
tmp3:       DS 1

; Reset vector
    PSECT resetVect,class=CODE,delta=2
    GOTO Start

; Code section
    PSECT code,class=CODE,delta=2

Start:
    BANKSEL TRISB
    MOVLW   0b11110000          ; RB0-3 outputs, RB4-7 inputs
    MOVWF   TRISB

    BANKSEL TRISC
    CLRF    TRISC               ; PORTC output

    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH              ; disable analog

    BANKSEL CM1CON0
    CLRF    CM1CON0
    CLRF    CM2CON0             ; disable comparators

    BANKSEL OPTION_REG
    BSF     OPTION_REG,7        ; disable weak pull-ups

    BANKSEL PORTC
    CLRF    PORTC

MainLoop:
    CLRF    KEY
    CLRF    ASCII

    ; Row 0 scan
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000001
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
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

    ; Row 1 scan
row1:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000010
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
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

    ; Row 2 scan
row2:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000100
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
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

    ; Row 3 scan
row3:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00001000
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
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

    BANKSEL KEY
    BTFSS   KEY,0
    GOTO    output_blank

    BANKSEL ASCII
    MOVF    ASCII, W
    IORLW   0b10000000
    BANKSEL PORTC
    MOVWF   PORTC
    BCF     PORTC, 7
    NOP
    NOP
    GOTO    MainLoop

output_blank:
    BANKSEL PORTC
    MOVLW   'S' | 0b10000000
    MOVWF   PORTC
    BCF     PORTC,7
    CALL    Delay1s
    BANKSEL PORTC
    CLRF    PORTC
    CALL    Delay1s
    GOTO    MainLoop

; Delay approximately 1 second @ 4MHz
Delay1s:
    MOVLW   0x04
    MOVWF   tmp1
Loop1:
    MOVLW   0xFF
    MOVWF   tmp2
Loop2:
    MOVLW   0xC8
    MOVWF   tmp3
Loop3:
    DECFSZ  tmp3, F
    GOTO    Loop3
    DECFSZ  tmp2, F
    GOTO    Loop2
    DECFSZ  tmp1, F
    GOTO    Loop1
    RETURN

    END
