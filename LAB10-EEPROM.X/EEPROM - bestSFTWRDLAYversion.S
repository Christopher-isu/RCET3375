;=================================================================
; VERSION 1.3.5 ? STEP 5: ShowAndWait1s + IncIdxAndCheck10
; Baseline: v1.3.4 + only these two subroutines
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
; Variables (unchanged)
;=================================================================
    PSECT udata_bank0
ASCII:          DS 1
idx:            DS 1
key_count:      DS 1
flags:          DS 1
prev_key_state: DS 1
idle_toggle:    DS 1
first_value:    DS 1
tmp1:           DS 1
tmp2:           DS 1
tmp3:           DS 1
KEY:            DS 1
buttonsA:       DS 1

;=================================================================
; Reset & Init (unchanged)
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
; Main loop (unchanged)
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
; RECORD mode ? uses IncIdxAndCheck10
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
    GOTO ShowRifZero
    BSF prev_key_state,0
    CALL WriteEE
    BANKSEL key_count
    INCF key_count,F
    CALL IncIdxAndCheck10     ; <-- new: inc + check
    BTFSC STATUS,2
    GOTO ExitRecord
    CALL ShowASCII
    CALL Delay200ms
    GOTO RecordLoop

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
    CALL DelayKeyPoll
    GOTO RecordLoop

ExitRecord:
    BANKSEL flags
    BCF flags,0
    BANKSEL prev_key_state
    CLRF prev_key_state
    CALL ExitMode
    RETURN

;=================================================================
; PLAY mode ? uses ShowAndWait1s + IncIdxAndCheck10
;=================================================================
PlayLoop:
    CALL ReadEE
    CALL ShowAndWait1s        ; <-- new: show + 1s
    CALL IncIdxAndCheck10     ; <-- new: inc + check
    BTFSC STATUS,2
    GOTO ExitPlay
    GOTO PlayLoop

ExitPlay:
    BANKSEL flags
    BCF flags,1
    CALL ExitMode
    RETURN

;=================================================================
; IDLE mode ? uses ShowAndWait1s
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
    CALL ShowAndWait1s        ; <-- new: show + 1s
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
; NEW Subroutines
;=================================================================
;--- Show ASCII + wait 1 second -----------------------------------
ShowAndWait1s:
    CALL ShowASCII
    CALL Delay1s
    RETURN

;--- Increment idx, set Z if idx == 10 ----------------------------
IncIdxAndCheck10:
    BANKSEL idx
    INCF idx,F
    MOVLW 10
    SUBWF idx,W
    RETURN                    ; Z = 1 if idx == 10

;=================================================================
; Existing Subroutines (unchanged)
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
    RETURN

;=================================================================
; KeypadScan, WriteEE, ReadEE, ShowASCII, Delays ? unchanged
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

Delay1s:
    MOVLW 0x04
    MOVWF tmp1
L1: MOVLW 0xFF
    MOVWF tmp2
L2: MOVLW 0xC8
    MOVWF tmp3
L3: DECFSZ tmp3,F
    GOTO L3
    DECFSZ tmp2,F
    GOTO L2
    DECFSZ tmp1,F
    GOTO L1
    RETURN

Delay200ms:
    MOVLW 0x01
    MOVWF tmp1
D2L1:
    MOVLW 0xFF
    MOVWF tmp2
D2L2:
    MOVLW 0x32
    MOVWF tmp3
D2L3:
    DECFSZ tmp3,F
    GOTO D2L3
    DECFSZ tmp2,F
    GOTO D2L2
    DECFSZ tmp1,F
    GOTO D2L1
    RETURN

DelayKeyPoll:
    MOVLW 40
    MOVWF tmp1
PollL1:
    MOVLW 250
    MOVWF tmp2
PollL2:
    NOP
    NOP
    DECFSZ tmp2,F
    GOTO PollL2
    DECFSZ tmp1,F
    GOTO PollL1
    RETURN

    END