;=================================================================
; 4x4 Keypad scan + blinking "S" idle + Recording mode with blinking "R"
; RA0 = Record button (active low)
; RA1 = Stop button (active low)
; RA2 = Play button (active low)
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

; VARIABLES
    PSECT udata_bank0
ASCII:          DS 1
KEY:            DS 1
blink_flag:     DS 1
tmp1:           DS 1
tmp2:           DS 1
tmp3:           DS 1
buttons_state:  DS 1
recording_flag: DS 1

; RESET VECTOR
    PSECT resetVect,class=CODE,delta=2
    GOTO Start

; CODE SECTION
    PSECT code,class=CODE,delta=2

Start:
    BANKSEL TRISB
    MOVLW 0b11110000         ; RB0-3 outputs, RB4-7 inputs (keypad)
    MOVWF TRISB

    BANKSEL TRISC
    CLRF TRISC               ; PORTC output

    BANKSEL TRISA
    MOVLW 0b00000111         ; RA0-RA2 inputs (buttons)
    MOVWF TRISA

    BANKSEL OPTION_REG
    BCF OPTION_REG,7         ; Enable weak pull-ups (if hardware)

    BANKSEL ANSEL
    CLRF ANSEL
    CLRF ANSELH              ; Disable analog inputs on PORTA and PORTB

    BANKSEL CM1CON0
    CLRF CM1CON0
    CLRF CM2CON0             ; Disable comparators

    BANKSEL PORTC
    CLRF PORTC

    BANKSEL blink_flag
    CLRF blink_flag

    BANKSEL recording_flag
    CLRF recording_flag

MainLoop:
    ; Read buttons RA0-RA2 (active low); invert bits using XORLW 0x07
    BANKSEL PORTA
    MOVF PORTA,W
    ANDLW 0x07              ; Mask bits 0-2
    XORLW 0x07              ; Invert bits: pressed=1, released=0
    BANKSEL buttons_state
    MOVWF buttons_state

    ; Set/clear recording flag based on Record button (bit0)
    BANKSEL buttons_state
    BTFSS buttons_state,0
    GOTO CheckStopBtn       ; if Record not pressed, skip setting recording

    BANKSEL recording_flag
    BSF recording_flag,0    ; set recording mode
    GOTO CheckStopBtn

CheckStopBtn:
    BANKSEL buttons_state
    BTFSS buttons_state,1
    GOTO CheckPlayBtn
    BANKSEL recording_flag
    BCF recording_flag,0    ; clear recording mode on Stop pressed

CheckPlayBtn:
    BANKSEL buttons_state
    BTFSS buttons_state,2
    GOTO KeypadAndDisplay
    ; Play button pressed - playback functionality can be added here

KeypadAndDisplay:
    BANKSEL recording_flag
    MOVF recording_flag,W
    BTFSC STATUS,2          ; if recording_flag == 0, not recording
    GOTO KeypadScan

    ; Recording active: blink 'R'
BlinkRecord:
    MOVLW 'R' | 0b10000000
    BANKSEL PORTC
    MOVWF PORTC
    BCF PORTC,7
    CALL Delay1s
    BANKSEL PORTC
    CLRF PORTC
    CALL Delay1s
    GOTO MainLoop

KeypadScan:
    BANKSEL KEY
    CLRF KEY
    BANKSEL ASCII
    CLRF ASCII

    ; --- Row 0 scan ---
    MOVLW 0b11110000
    ANDWF PORTB,F
    MOVLW 0b00000001
    IORWF PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS PORTB,4
    GOTO R0C1
    MOVLW '1'
    MOVWF ASCII
    BSF KEY,0
R0C1:
    BTFSS PORTB,5
    GOTO R0C2
    MOVLW '2'
    MOVWF ASCII
    BSF KEY,0
R0C2:
    BTFSS PORTB,6
    GOTO R0C3
    MOVLW '3'
    MOVWF ASCII
    BSF KEY,0
R0C3:
    BTFSS PORTB,7
    GOTO Row1
    MOVLW 'A'
    MOVWF ASCII
    BSF KEY,0

; --- Row 1 scan ---
Row1:
    MOVLW 0b11110000
    ANDWF PORTB,F
    MOVLW 0b00000010
    IORWF PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS PORTB,4
    GOTO R1C1
    MOVLW '4'
    MOVWF ASCII
    BSF KEY,0
R1C1:
    BTFSS PORTB,5
    GOTO R1C2
    MOVLW '5'
    MOVWF ASCII
    BSF KEY,0
R1C2:
    BTFSS PORTB,6
    GOTO R1C3
    MOVLW '6'
    MOVWF ASCII
    BSF KEY,0
R1C3:
    BTFSS PORTB,7
    GOTO Row2
    MOVLW 'B'
    MOVWF ASCII
    BSF KEY,0

; --- Row 2 scan ---
Row2:
    MOVLW 0b11110000
    ANDWF PORTB,F
    MOVLW 0b00000100
    IORWF PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS PORTB,4
    GOTO R2C1
    MOVLW '7'
    MOVWF ASCII
    BSF KEY,0
R2C1:
    BTFSS PORTB,5
    GOTO R2C2
    MOVLW '8'
    MOVWF ASCII
    BSF KEY,0
R2C2:
    BTFSS PORTB,6
    GOTO R2C3
    MOVLW '9'
    MOVWF ASCII
    BSF KEY,0
R2C3:
    BTFSS PORTB,7
    GOTO Row3
    MOVLW 'C'
    MOVWF ASCII
    BSF KEY,0

; --- Row 3 scan ---
Row3:
    MOVLW 0b11110000
    ANDWF PORTB,F
    MOVLW 0b00001000
    IORWF PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS PORTB,4
    GOTO R3C1
    MOVLW '*'
    MOVWF ASCII
    BSF KEY,0
R3C1:
    BTFSS PORTB,5
    GOTO R3C2
    MOVLW '0'
    MOVWF ASCII
    BSF KEY,0
R3C2:
    BTFSS PORTB,6
    GOTO R3C3
    MOVLW '#'
    MOVWF ASCII
    BSF KEY,0
R3C3:
    BTFSS PORTB,7
    GOTO Output
    MOVLW 'D'
    MOVWF ASCII
    BSF KEY,0

Output:
    MOVLW 0b11110000
    ANDWF PORTB,F

    BANKSEL KEY
    BTFSS KEY,0
    GOTO OutputBlank

    BANKSEL ASCII
    MOVF ASCII,W
    IORLW 0b10000000
    BANKSEL PORTC
    MOVWF PORTC
    BCF PORTC,7
    NOP
    NOP
    GOTO MainLoop

OutputBlank:
    BANKSEL PORTC
    MOVLW 'S' | 0b10000000
    MOVWF PORTC
    BCF PORTC,7
    CALL Delay1s
    BANKSEL PORTC
    CLRF PORTC
    CALL Delay1s
    GOTO MainLoop

; Approximate 1 second delay, 4MHz
Delay1s:
    MOVLW 0x04
    MOVWF tmp1
Loop1:
    MOVLW 0xFF
    MOVWF tmp2
Loop2:
    MOVLW 0xC8
    MOVWF tmp3
Loop3:
    DECFSZ tmp3,F
    GOTO Loop3
    DECFSZ tmp2,F
    GOTO Loop2
    DECFSZ tmp1,F
    GOTO Loop1
    RETURN

    END
