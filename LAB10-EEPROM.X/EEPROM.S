;=================================================================
; EEPROM core + 10-key overwrite on RA0 low + playback on RA2 low
; Full 4x4 keypad scan, "R" blink during record, merge-ready
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

;=================================================================
; Variables
;=================================================================
    PSECT udata_bank0
ASCII:       DS 1   ; current display char / write buffer
idx:         DS 1   ; EEPROM address 0-9
key_count:   DS 1   ; keys stored in record mode (0-9)
flags:       DS 1   ; bit0=record_flag, bit1=play_flag
tmp1:        DS 1   ; delay
tmp2:        DS 1
tmp3:        DS 1
KEY:         DS 1   ; keypad hit flag (bit0)
buttonsA:    DS 1   ; RA0-RA2 state (inverted: pressed=1)

;=================================================================
; Reset vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    GOTO    Start

;=================================================================
; Code section
;=================================================================
    PSECT code,class=CODE,delta=2

Start:
    ;--- Port config - identical to reference -------------------------
    BANKSEL TRISB
    MOVLW   0b11110000          ; RB0-3 out, RB4-7 in
    MOVWF   TRISB

    BANKSEL TRISC
    CLRF    TRISC               ; PORTC full output

    BANKSEL TRISA
    MOVLW   0b00000111          ; RA0-RA2 inputs
    MOVWF   TRISA

    BANKSEL OPTION_REG
    BCF     OPTION_REG,7        ; weak pull-ups (circuit)

    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH              ; all digital

    BANKSEL CM1CON0
    CLRF    CM1CON0
    CLRF    CM2CON0             ; comparators off

    BANKSEL PORTC
    CLRF    PORTC

    ;--- Init variables -----------------------------------------------
    BANKSEL flags
    CLRF    flags
    BANKSEL idx
    CLRF    idx
    BANKSEL key_count
    CLRF    key_count

    ;--- Fill EEPROM 0x00-0x09 with '1'..'A' once --------------------
    MOVLW   0x31                ; '1'
    MOVWF   ASCII
    CLRF    idx
FillLoop:
    CALL    WriteEE
    BANKSEL ASCII
    INCF    ASCII,F
    BANKSEL idx
    INCF    idx,F
    MOVLW   10
    SUBWF   idx,W
    BTFSS   STATUS,2
    GOTO    FillLoop

    ;--- Load first value for display --------------------------------
    BANKSEL EEADR
    CLRF    EEADR
    BANKSEL EECON1
    BCF     EECON1,7
    BSF     EECON1,0            ; RD
    BANKSEL EEDATA
    MOVF    EEDATA,W
    BANKSEL ASCII
    MOVWF   ASCII

;=================================================================
; Main loop
;=================================================================
MainLoop:
    ;--- Show "R" blink while recording -------------------------------
    BANKSEL flags
    BTFSC   flags,0
    GOTO    ShowRecordR

    ;--- Normal display of current ASCII ------------------------------
    CALL    ShowASCII

    ;--- Read RA0-RA2 (active low) -----------------------------------
    BANKSEL PORTA
    MOVF    PORTA,W
    ANDLW   0x07
    XORLW   0x07                ; invert -> pressed = 1
    BANKSEL buttonsA
    MOVWF   buttonsA            ; bit0=RA0(record), bit2=RA2(play)

    GOTO    CheckRecordBtn

ShowRecordR:
    MOVLW   'R' | 0b10000000
    BANKSEL PORTC
    MOVWF   PORTC
    BCF     PORTC,7
    CALL    Delay1s
    BANKSEL PORTC
    CLRF    PORTC
    CALL    Delay1s
    GOTO    MainLoop

CheckRecordBtn:
    ;--- Enter RECORD on RA0 first press -----------------------------
    BANKSEL flags
    BTFSC   flags,0
    GOTO    CheckPlay
    BANKSEL buttonsA
    BTFSS   buttonsA,0          ; RA0 pressed?
    GOTO    CheckPlay
    BSF     flags,0             ; set record_flag
    BANKSEL key_count
    CLRF    key_count
    BANKSEL idx
    CLRF    idx
    GOTO    RecordLoop

CheckPlay:
    ;--- Enter PLAY on RA2 first press -------------------------------
    BANKSEL flags
    BTFSC   flags,1
    GOTO    RecordOrPlay
    BANKSEL buttonsA
    BTFSS   buttonsA,2          ; RA2 pressed?
    GOTO    RecordOrPlay
    BSF     flags,1             ; set play_flag
    BANKSEL idx
    CLRF    idx
    GOTO    PlayLoop

RecordOrPlay:
    ;--- Dispatch to active mode -------------------------------------
    BANKSEL flags
    BTFSC   flags,0
    GOTO    RecordLoop
    BTFSC   flags,1
    GOTO    PlayLoop
    GOTO    IdleDelay

;=================================================================
; RECORD mode - wait for 10 keypad entries
;=================================================================
RecordLoop:
    CALL    KeypadScan          ; fills ASCII, sets KEY,0 on hit
    BANKSEL KEY
    BTFSS   KEY,0               ; key pressed?
    GOTO    RecordDelay
    ;--- Store key ---------------------------------------------------
    CALL    WriteEE
    BANKSEL key_count
    INCF    key_count,F
    BANKSEL idx
    INCF    idx,F
    ;--- Brief feedback (0.2s) ---------------------------------------
    CALL    ShowASCII
    CALL    Delay200ms
    ;--- Check completion --------------------------------------------
    MOVLW   10
    SUBWF   key_count,W
    BTFSC   STATUS,2
    GOTO    ExitRecord

RecordDelay:
    CALL    Delay1s
    GOTO    RecordLoop

ExitRecord:
    BANKSEL flags
    BCF     flags,0             ; clear record_flag
    ;--- Reload first value ------------------------------------------
    BANKSEL EEADR
    CLRF    EEADR
    BANKSEL EECON1
    BCF     EECON1,7
    BSF     EECON1,0
    BANKSEL EEDATA
    MOVF    EEDATA,W
    BANKSEL ASCII
    MOVWF   ASCII
    GOTO    MainLoop

;=================================================================
; PLAY mode - cycle 10 values once
;=================================================================
PlayLoop:
    CALL    ReadEE              ; -> ASCII
    CALL    ShowASCII
    CALL    Delay1s
    BANKSEL idx
    INCF    idx,F
    MOVLW   10
    SUBWF   idx,W
    BTFSC   STATUS,2
    GOTO    ExitPlay
    GOTO    PlayLoop

ExitPlay:
    BANKSEL flags
    BCF     flags,1             ; clear play_flag
    ;--- Reload first value ------------------------------------------
    BANKSEL EEADR
    CLRF    EEADR
    BANKSEL EECON1
    BCF     EECON1,7
    BSF     EECON1,0
    BANKSEL EEDATA
    MOVF    EEDATA,W
    BANKSEL ASCII
    MOVWF   ASCII
    GOTO    MainLoop

IdleDelay:
    CALL    Delay1s
    GOTO    MainLoop

;=================================================================
; KeypadScan ? full 4×4 scan, identical to reference
;=================================================================
KeypadScan:
    BANKSEL KEY
    CLRF    KEY
    BANKSEL ASCII
    CLRF    ASCII

    ;--- Row 0 --------------------------------------------------------
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000001
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS   PORTB,4
    GOTO    R0C1
    MOVLW   '1'
    MOVWF   ASCII
    BSF     KEY,0
R0C1:
    BTFSS   PORTB,5
    GOTO    R0C2
    MOVLW   '2'
    MOVWF   ASCII
    BSF     KEY,0
R0C2:
    BTFSS   PORTB,6
    GOTO    R0C3
    MOVLW   '3'
    MOVWF   ASCII
    BSF     KEY,0
R0C3:
    BTFSS   PORTB,7
    GOTO    Row1
    MOVLW   'A'
    MOVWF   ASCII
    BSF     KEY,0

    ;--- Row 1 --------------------------------------------------------
Row1:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000010
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS   PORTB,4
    GOTO    R1C1
    MOVLW   '4'
    MOVWF   ASCII
    BSF     KEY,0
R1C1:
    BTFSS   PORTB,5
    GOTO    R1C2
    MOVLW   '5'
    MOVWF   ASCII
    BSF     KEY,0
R1C2:
    BTFSS   PORTB,6
    GOTO    R1C3
    MOVLW   '6'
    MOVWF   ASCII
    BSF     KEY,0
R1C3:
    BTFSS   PORTB,7
    GOTO    Row2
    MOVLW   'B'
    MOVWF   ASCII
    BSF     KEY,0

    ;--- Row 2 --------------------------------------------------------
Row2:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00000100
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS   PORTB,4
    GOTO    R2C1
    MOVLW   '7'
    MOVWF   ASCII
    BSF     KEY,0
R2C1:
    BTFSS   PORTB,5
    GOTO    R2C2
    MOVLW   '8'
    MOVWF   ASCII
    BSF     KEY,0
R2C2:
    BTFSS   PORTB,6
    GOTO    R2C3
    MOVLW   '9'
    MOVWF   ASCII
    BSF     KEY,0
R2C3:
    BTFSS   PORTB,7
    GOTO    Row3
    MOVLW   'C'
    MOVWF   ASCII
    BSF     KEY,0

    ;--- Row 3 --------------------------------------------------------
Row3:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    MOVLW   0b00001000
    IORWF   PORTB,F
    NOP
    BANKSEL PORTB
    BTFSS   PORTB,4
    GOTO    R3C1
    MOVLW   '*'
    MOVWF   ASCII
    BSF     KEY,0
R3C1:
    BTFSS   PORTB,5
    GOTO    R3C2
    MOVLW   '0'
    MOVWF   ASCII
    BSF     KEY,0
R3C2:
    BTFSS   PORTB,6
    GOTO    R3C3
    MOVLW   '#'
    MOVWF   ASCII
    BSF     KEY,0
R3C3:
    BTFSS   PORTB,7
    GOTO    ScanEnd
    MOVLW   'D'
    MOVWF   ASCII
    BSF     KEY,0

ScanEnd:
    MOVLW   0b11110000
    ANDWF   PORTB,F
    RETURN

;=================================================================
; EEPROM write - polling, no interrupt
;=================================================================
WriteEE:
    BANKSEL idx
    MOVF    idx,W
    BANKSEL EEADR
    MOVWF   EEADR
    BANKSEL ASCII
    MOVF    ASCII,W
    BANKSEL EEDATA
    MOVWF   EEDATA
    BANKSEL EECON1
    BCF     EECON1,7            ; data EE
    BSF     EECON1,2            ; WREN
    MOVLW   0x55
    MOVWF   EECON2
    MOVLW   0xAA
    MOVWF   EECON2
    BSF     EECON1,1            ; WR
WriteWait:
    BTFSC   EECON1,1
    GOTO    WriteWait
    BCF     EECON1,2
    RETURN

;=================================================================
; EEPROM read
;=================================================================
ReadEE:
    BANKSEL idx
    MOVF    idx,W
    BANKSEL EEADR
    MOVWF   EEADR
    BANKSEL EECON1
    BCF     EECON1,7
    BSF     EECON1,0            ; RD
    BANKSEL EEDATA
    MOVF    EEDATA,W
    BANKSEL ASCII
    MOVWF   ASCII
    RETURN

;=================================================================
; Display ASCII on PORTC (bit7=1, strobe off)
;=================================================================
ShowASCII:
    BANKSEL ASCII
    MOVF    ASCII,W
    IORLW   0b10000000
    BANKSEL PORTC
    MOVWF   PORTC
    BCF     PORTC,7
    NOP
    NOP
    RETURN

;=================================================================
; 1 second delay - identical to reference
;=================================================================
Delay1s:
    MOVLW   0x04
    MOVWF   tmp1
L1: MOVLW   0xFF
    MOVWF   tmp2
L2: MOVLW   0xC8
    MOVWF   tmp3
L3: DECFSZ  tmp3,F
    GOTO    L3
    DECFSZ  tmp2,F
    GOTO    L2
    DECFSZ  tmp1,F
    GOTO    L1
    RETURN

;=================================================================
; 200 ms feedback delay (record mode)
;=================================================================
Delay200ms:
    MOVLW   0x01
    MOVWF   tmp1
D2L1:
    MOVLW   0xFF
    MOVWF   tmp2
D2L2:
    MOVLW   0x32                ; ~200 ms at 4 MHz
    MOVWF   tmp3
D2L3:
    DECFSZ  tmp3,F
    GOTO    D2L3
    DECFSZ  tmp2,F
    GOTO    D2L2
    DECFSZ  tmp1,F
    GOTO    D2L1
    RETURN

    END