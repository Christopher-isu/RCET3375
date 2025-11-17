;=================================================================
; VERSION 2.6 ? FINAL: NON-BLOCKING KEY DETECTION
; TMR0 + T0IF + PRELOAD, 1ms BASE, BANK-SAFE
; Key press: immediate save, show, no delay
; Poll every 10 ms ? catches short presses
; "R" stays until next key or stop
;=================================================================
    CONFIG FOSC = XT
    CONFIG WDTE = OFF
    CONFIG PWRTE = OFF
    CONFIG MCLRE = ON
    CONFIG CP = OFF
    CONFIG CPD = OFF
    CONFIG BOREN = OFF
    CONFIG IESO = OFF
    CONFIG FCMEN = OFF
    CONFIG LVP = OFF
    CONFIG WRT = OFF
    #include <xc.inc>

;=================================================================
; Variables (Bank 0)
;=================================================================
    PSECT udata_bank0
ASCII:          DS 1
idx:            DS 1
key_count:      DS 1
flags:          DS 1
prev_key_state: DS 1
idle_toggle:    DS 1
first_value:    DS 1
tmp1:           DS 1        ; DelayMs counter (ms)
tmp2:           DS 1        ; Inner loop counter (×4)
KEY:            DS 1
buttonsA:       DS 1

;=================================================================
; Reset & Init
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    GOTO Start

    PSECT code,class=CODE,delta=2
Start:
    BANKSEL TRISB
    MOVLW 0b11110000
    MOVWF TRISB
    BANKSEL TRISC
    CLRF TRISC
    BANKSEL TRISA
    MOVLW 0b00000111
    MOVWF TRISA
    BANKSEL ANSEL
    CLRF ANSEL
    CLRF ANSELH
    BANKSEL CM1CON0
    CLRF CM1CON0
    CLRF CM2CON0
    BANKSEL PORTC
    CLRF PORTC

    ;--- TMR0: PSA=0, PS=001 (1:4) ----------------------------------
    BANKSEL OPTION_REG
    MOVLW 0b00000001
    MOVWF OPTION_REG

    ;--- Init variables --------------------------------------------
    BANKSEL flags
    CLRF flags
    BANKSEL idx
    CLRF idx
    BANKSEL key_count
    CLRF key_count
    BANKSEL prev_key_state
    CLRF prev_key_state
    BANKSEL idle_toggle
    CLRF idle_toggle

    ;--- Fill EEPROM ------------------------------------------------
    MOVLW 0x31
    MOVWF ASCII
    CLRF idx
FillLoop:
    CALL WriteEE
    BANKSEL ASCII
    INCF ASCII,F
    BANKSEL idx
    INCF idx,F
    MOVLW 10
    SUBWF idx,W
    BTFSS STATUS,2
    GOTO FillLoop

    CALL LoadFirstVal

;=================================================================
; MAIN LOOP
;=================================================================
MainLoop:
    CALL ReadButtons
    BANKSEL flags
    BTFSC flags,0
    GOTO CheckPlay
    BANKSEL buttonsA
    BTFSS buttonsA,0
    GOTO CheckPlay
    MOVLW 'R'
    BANKSEL ASCII
    MOVWF ASCII
    CALL ShowASCII
    BSF flags,0
    BANKSEL key_count
    CLRF key_count
    BANKSEL idx
    CLRF idx
    BANKSEL prev_key_state
    CLRF prev_key_state
    GOTO RecordLoop

CheckPlay:
    BANKSEL flags
    BTFSC flags,1
    GOTO RecordOrPlay
    BANKSEL buttonsA
    BTFSS buttonsA,2
    GOTO RecordOrPlay
    BSF flags,1
    BANKSEL idx
    CLRF idx
    GOTO PlayLoop

RecordOrPlay:
    BANKSEL flags
    BTFSC flags,0
    GOTO RecordLoop
    BTFSC flags,1
    GOTO PlayLoop
    GOTO IdleBlink

;=================================================================
; RECORD ? NON-BLOCKING
;=================================================================
RecordLoop:
    CALL ReadButtons
    BTFSS buttonsA,1
    GOTO CheckKeyEdge
    GOTO ExitRecord

CheckKeyEdge:
    CALL KeypadScan
    BANKSEL KEY
    BTFSC KEY,0
    GOTO KeyPressedNow
    BANKSEL prev_key_state
    CLRF prev_key_state
    GOTO ShowRifZero

KeyPressedNow:
    BANKSEL prev_key_state
    BTFSC prev_key_state,0
    GOTO RecordLoop
    BSF prev_key_state,0
    CALL WriteEE
    BANKSEL key_count
    INCF key_count,F
    CALL IncIdxAndCheck10
    BTFSC STATUS,2
    GOTO ExitRecord
    CALL ShowASCII
    GOTO RecordLoop        ; ? NO DELAY, return immediately

ShowRifZero:
    BANKSEL key_count
    MOVF key_count,W
    BTFSS STATUS,2
    GOTO JustPoll
    MOVLW 'R'
    BANKSEL ASCII
    MOVWF ASCII
    CALL ShowASCII
JustPoll:
    MOVLW 10
    CALL DelayMs              ; 10 ms poll
    GOTO RecordLoop

ExitRecord:
    BANKSEL flags
    BCF flags,0
    BANKSEL prev_key_state
    CLRF prev_key_state
    CALL ExitMode
    GOTO MainLoop

;=================================================================
; PLAY
;=================================================================
PlayLoop:
    CALL ReadEE
    CALL ShowASCII
    MOVLW 1000
    CALL DelayMs              ; 1 sec
    CALL IncIdxAndCheck10
    BTFSC STATUS,2
    GOTO ExitPlay
    GOTO PlayLoop

ExitPlay:
    BANKSEL flags
    BCF flags,1
    CALL ExitMode
    GOTO MainLoop

;=================================================================
; IDLE
;=================================================================
IdleBlink:
    BANKSEL idle_toggle
    BTFSC idle_toggle,0
    GOTO ShowS
    BANKSEL first_value
    MOVF first_value,W
    BANKSEL ASCII
    MOVWF ASCII
    GOTO DoShowWait
ShowS:
    MOVLW 'S'
    BANKSEL ASCII
    MOVWF ASCII
DoShowWait:
    CALL ShowASCII
    MOVLW 1000
    CALL DelayMs              ; 1 sec
    BANKSEL idle_toggle
    MOVLW 1
    XORWF idle_toggle,F
    CALL ReadButtons
    BTFSC buttonsA,0
    GOTO MainLoop
    BTFSC buttonsA,2
    GOTO MainLoop
    GOTO IdleBlink

;=================================================================
; DELAY ENGINE ? TMR0 + T0IF + PRELOAD (1ms) ? BANK-SAFE
;=================================================================
DelayMs:                      ; W = ms
    MOVWF tmp1
DelayMs_Loop:
    MOVLW 4
    MOVWF tmp2
DelayMs_Inner:
    MOVLW 6
    MOVWF TMR0
DelayMs_Wait:
    BTFSS INTCON,2
    GOTO DelayMs_Wait
    BCF INTCON,2
    DECFSZ tmp2,F
    GOTO DelayMs_Inner
    DECFSZ tmp1,F
    GOTO DelayMs_Loop
    RETURN

IncIdxAndCheck10:
    BANKSEL idx
    INCF idx,F
    MOVLW 10
    SUBWF idx,W
    RETURN

;=================================================================
; SUBROUTINES
;=================================================================
ReadButtons:
    BANKSEL PORTA
    MOVF PORTA,W
    ANDLW 0x07
    XORLW 0x07
    BANKSEL buttonsA
    MOVWF buttonsA
    RETURN

LoadFirstVal:
    BANKSEL EEADR
    CLRF EEADR
    BANKSEL EECON1
    BCF EECON1,7
    BSF EECON1,0
    BANKSEL EEDATA
    MOVF EEDATA,W
    BANKSEL first_value
    MOVWF first_value
    BANKSEL ASCII
    MOVWF ASCII
    RETURN

ExitMode:
    CALL LoadFirstVal
    BANKSEL idle_toggle
    CLRF idle_toggle
    GOTO MainLoop

;=================================================================
; KEYPAD, EEPROM, DISPLAY ? FULL
;=================================================================
KeypadScan:
    BANKSEL KEY
    CLRF KEY
    BANKSEL ASCII
    CLRF ASCII
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
R0C1: BTFSS PORTB,5
    GOTO R0C2
    MOVLW '2'
    MOVWF ASCII
    BSF KEY,0
R0C2: BTFSS PORTB,6
    GOTO R0C3
    MOVLW '3'
    MOVWF ASCII
    BSF KEY,0
R0C3: BTFSS PORTB,7
    GOTO Row1
    MOVLW 'A'
    MOVWF ASCII
    BSF KEY,0
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
R1C1: BTFSS PORTB,5
    GOTO R1C2
    MOVLW '5'
    MOVWF ASCII
    BSF KEY,0
R1C2: BTFSS PORTB,6
    GOTO R1C3
    MOVLW '6'
    MOVWF ASCII
    BSF KEY,0
R1C3: BTFSS PORTB,7
    GOTO Row2
    MOVLW 'B'
    MOVWF ASCII
    BSF KEY,0
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
R2C1: BTFSS PORTB,5
    GOTO R2C2
    MOVLW '8'
    MOVWF ASCII
    BSF KEY,0
R2C2: BTFSS PORTB,6
    GOTO R2C3
    MOVLW '9'
    MOVWF ASCII
    BSF KEY,0
R2C3: BTFSS PORTB,7
    GOTO Row3
    MOVLW 'C'
    MOVWF ASCII
    BSF KEY,0
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
R3C1: BTFSS PORTB,5
    GOTO R3C2
    MOVLW '0'
    MOVWF ASCII
    BSF KEY,0
R3C2: BTFSS PORTB,6
    GOTO R3C3
    MOVLW '#'
    MOVWF ASCII
    BSF KEY,0
R3C3: BTFSS PORTB,7
    GOTO ScanEnd
    MOVLW 'D'
    MOVWF ASCII
    BSF KEY,0
ScanEnd:
    MOVLW 0b11110000
    ANDWF PORTB,F
    RETURN

WriteEE:
    BANKSEL idx
    MOVF idx,W
    BANKSEL EEADR
    MOVWF EEADR
    BANKSEL ASCII
    MOVF ASCII,W
    BANKSEL EEDATA
    MOVWF EEDATA
    BANKSEL EECON1
    BCF EECON1,7
    BSF EECON1,2
    MOVLW 0x55
    MOVWF EECON2
    MOVLW 0xAA
    MOVWF EECON2
    BSF EECON1,1
WriteWait:
    BTFSC EECON1,1
    GOTO WriteWait
    BCF EECON1,2
    RETURN

ReadEE:
    BANKSEL idx
    MOVF idx,W
    BANKSEL EEADR
    MOVWF EEADR
    BANKSEL EECON1
    BCF EECON1,7
    BSF EECON1,0
    BANKSEL EEDATA
    MOVF EEDATA,W
    BANKSEL ASCII
    MOVWF ASCII
    RETURN

ShowASCII:
    BANKSEL ASCII
    MOVF ASCII,W
    IORLW 0b10000000
    BANKSEL PORTC
    MOVWF PORTC
    BCF PORTC,7
    NOP
    NOP
    RETURN

    END