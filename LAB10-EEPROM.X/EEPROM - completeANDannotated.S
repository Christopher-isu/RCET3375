;=================================================================
; VERSION 2.6.6 ? FINAL: Play stops exactly at recorded count
; Only change from v2.6.5: PlayLoop comparison fixed to use key_count
;=================================================================
    CONFIG FOSC = XT          ; external 4 MHz XT oscillator
    CONFIG WDTE = OFF         ; watchdog timer disabled
    CONFIG PWRTE = OFF        ; power-up timer disabled
    CONFIG MCLRE = ON         ; MCLR pin used as reset
    CONFIG CP = OFF           ; code protection off
    CONFIG CPD = OFF          ; data EEPROM protection off
    CONFIG BOREN = OFF        ; brown-out reset disabled
    CONFIG IESO = OFF         ; internal/external oscillator switchover off
    CONFIG FCMEN = OFF        ; fail-safe clock monitor off
    CONFIG LVP = OFF          ; low-voltage programming off
    CONFIG WRT = OFF          ; write protection off

    #include <xc.inc>         ; include XC8/PIC-AS header

;=================================================================
; RAM variables ? all in bank 0
;=================================================================
    PSECT udata_bank0
ASCII:          DS 1      ; current character to display (7-bit ASCII)
idx:            DS 1      ; current EEPROM address pointer (0?9)
key_count:      DS 1      ; number of valid characters stored (0?10), binary, saved at 0x0A
flags:          DS 1      ; bit0 = Record mode active, bit1 = Play mode active
prev_key_state: DS 1      ; bit0 = previous keypad press state (edge detection)
idle_toggle:    DS 1      ; bit0 toggles every 1s in idle for 'S' / first-char blink
first_value:    DS 1      ; cached copy of EEPROM[0] for idle display
tmp1:           DS 1      ; DelayMs outer loop counter
tmp2:           DS 1      ; DelayMs inner loop counter
KEY:            DS 1      ; bit0 set when KeypadScan detects any key press
buttonsA:       DS 1      ; bit0=Record btn, bit1=Stop btn, bit2=Play btn (active-high after inversion)

;=================================================================
; Reset vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    GOTO Start                ; jump to initialization

;=================================================================
; Main code section
;=================================================================
    PSECT code,class=CODE,delta=2

Start:
    BANKSEL TRISB
    MOVLW   0b11110000        ; RB7?RB4 inputs (keypad columns), RB3?RB0 outputs (rows)
    MOVWF   TRISB             ; configure keypad port direction
    BANKSEL TRISC
    CLRF    TRISC             ; PORTC all outputs ? drives dot-matrix display
    BANKSEL TRISA
    MOVLW   0b00000111        ; RA0?RA2 inputs for Record/Stop/Play buttons
    MOVWF   TRISA             ; configure button inputs
    BANKSEL ANSEL
    CLRF    ANSEL             ; disable analog on PORTA
    CLRF    ANSELH            ; disable analog on PORTB
    BANKSEL CM1CON0
    CLRF    CM1CON0          ; disable comparator 1
    CLRF    CM2CON0           ; disable comparator 2
    BANKSEL PORTC
    CLRF    PORTC             ; clear display at startup

    BANKSEL OPTION_REG
    MOVLW   0b00000001        ; prescaler to TMR0, ratio 1:4 for accurate timing
    MOVWF   OPTION_REG        ; configure Timer0 prescaler

    BANKSEL flags
    CLRF    flags             ; clear all mode flags
    BANKSEL idx
    CLRF    idx               ; initialize EEPROM pointer
    BANKSEL key_count
    CLRF    key_count         ; initialize stored count
    BANKSEL prev_key_state
    CLRF    prev_key_state    ; no previous key press
    BANKSEL idle_toggle
    CLRF    idle_toggle       ; start idle showing first character

    CALL    LoadKeyCount      ; restore saved key_count from EEPROM[0x0A]
    CALL    LoadFirstVal      ; load first recorded character for idle display

;=================================================================
; Main dispatcher ? checks buttons and active modes
;=================================================================
MainLoop:
    CALL    ReadButtons       ; sample RA0?RA2 into buttonsA (active-high)

    BANKSEL flags
    BTFSC   flags,0           ; is Record mode already active?
    GOTO    CheckPlay         ; skip button check if yes

    BANKSEL buttonsA
    BTFSS   buttonsA,0        ; Record button pressed?
    GOTO    CheckPlay         ; no ? skip

    MOVLW   'R'               ; show 'R' during entry
    BANKSEL ASCII
    MOVWF   ASCII
    CALL    ShowASCII         ; display 'R'

    BSF     flags,0           ; enter Record mode
    BANKSEL idx
    CLRF    idx               ; start writing from address 0
    BANKSEL prev_key_state
    CLRF    prev_key_state    ; clear edge detector
    GOTO    RecordLoop        ; begin recording

CheckPlay:
    BANKSEL flags
    BTFSC   flags,1           ; is Play mode already active?
    GOTO    RecordOrPlay      ; skip button check

    BANKSEL buttonsA
    BTFSS   buttonsA,2        ; Play button pressed?
    GOTO    RecordOrPlay      ; no ? skip

    BSF     flags,1           ; enter Play mode
    BANKSEL idx
    CLRF    idx               ; start reading from address 0
    GOTO    PlayLoop          ; begin playback

RecordOrPlay:
    BANKSEL flags
    BTFSC   flags,0           ; Record mode active?
    GOTO    RecordLoop
    BTFSC   flags,1           ; Play mode active?
    GOTO    PlayLoop
    GOTO    IdleBlink         ; no mode ? idle state

;=================================================================
; RECORD mode ? edge-triggered keypad, stops at 10 or Stop button
;=================================================================
RecordLoop:
    CALL    ReadButtons       ; check for Stop button

    BTFSS   buttonsA,1        ; Stop button pressed?
    GOTO    CheckKeyEdge      ; no ? continue
    GOTO    ExitRecord        ; yes ? exit recording

CheckKeyEdge:
    CALL    KeypadScan        ; scan keypad, fill ASCII and set KEY,0 on press

    BANKSEL KEY
    BTFSC   KEY,0             ; any key pressed?
    GOTO    KeyPressedNow     ; yes ? process
    BANKSEL prev_key_state
    CLRF    prev_key_state    ; key released ? clear edge
    GOTO    ShowRifZero       ; show 'R' if nothing recorded

KeyPressedNow:
    BANKSEL prev_key_state
    BTFSC   prev_key_state,0  ; was key already down?
    GOTO    RecordLoop        ; yes ? ignore repeat
    BSF     prev_key_state,0  ; remember key is down

    CALL    WriteEE           ; store ASCII at current idx
    BANKSEL key_count
    INCF    key_count,F       ; increment stored count
    CALL    SaveKeyCount      ; persist count immediately
    BANKSEL idx
    INCF    idx,F             ; advance pointer
    MOVLW   10
    SUBWF   idx,W             ; compare idx with 10
    BTFSC   STATUS,2          ; Z=1 ? idx == 10?
    GOTO    ReachedTen        ; yes ? cap and exit

    CALL    ShowASCII         ; echo pressed character
    GOTO    RecordLoop        ; continue recording

ReachedTen:
    BANKSEL key_count
    MOVLW   10                ; force maximum count
    MOVWF   key_count
    CALL    SaveKeyCount      ; persist capped count
    GOTO    ExitRecord        ; exit recording

ShowRifZero:
    BANKSEL key_count
    MOVF    key_count,W
    BTFSS   STATUS,2          ; Z=1 ? nothing recorded?
    GOTO    JustPoll          ; no ? skip 'R' display
    MOVLW   'R'
    BANKSEL ASCII
    MOVWF   ASCII
    CALL    ShowASCII         ; show 'R' when idle in record mode

JustPoll:
    MOVLW   10
    CALL    DelayMs           ; 10 ms non-blocking poll delay
    GOTO    RecordLoop        ; continue loop

ExitRecord:
    BANKSEL idx
    MOVF    idx,W             ; idx = actual number of chars written
    BANKSEL key_count
    MOVWF   key_count         ; sync count with reality
    CALL    SaveKeyCount      ; persist final count

    BANKSEL flags
    BCF     flags,0           ; clear Record mode flag
    BANKSEL prev_key_state
    CLRF    prev_key_state    ; clear edge detector
    CALL    ExitMode          ; refresh idle display
    GOTO    MainLoop          ; return to dispatcher

;=================================================================
; PLAY mode ? displays each character for 1 second, stops at key_count
;=================================================================
PlayLoop:
    CALL    ReadEE            ; load EEPROM[idx] into ASCII
    CALL    ShowASCII         ; display current character
    MOVLW   1000
    CALL    DelayMs           ; hold for 1 second

    BANKSEL idx
    INCF    idx,F             ; advance to next address

    BANKSEL key_count
    MOVF    idx,W
    SUBWF   key_count,W       ; W = key_count - idx
    BTFSC   STATUS,2          ; Z=1 ? idx == key_count?
    GOTO    ExitPlay          ; yes ? playback complete

    GOTO    PlayLoop          ; continue playback

ExitPlay:
    BANKSEL flags
    BCF     flags,1           ; clear Play mode flag
    CALL    ExitMode          ; refresh idle display
    GOTO    MainLoop          ; return to dispatcher

;=================================================================
; IDLE mode ? blink 'S' ? first stored character every 1 second
;=================================================================
IdleBlink:
    BANKSEL idle_toggle
    BTFSC   idle_toggle,0     ; toggle bit set?
    GOTO    ShowS             ; yes ? show 'S'

    BANKSEL first_value
    MOVF    first_value,W     ; load cached first character
    BANKSEL ASCII
    MOVWF   ASCII             ; prepare for display
    GOTO    DoShowWait

ShowS:
    MOVLW   'S'               ; load 'S' for start indication
    BANKSEL ASCII
    MOVWF   ASCII             ; prepare 'S' for display

DoShowWait:
    CALL    ShowASCII         ; output current symbol
    MOVLW   1000
    CALL    DelayMs           ; hold for 1 second

    BANKSEL idle_toggle
    MOVLW   1
    XORWF   idle_toggle,F     ; toggle bit 0 for next cycle

    CALL    ReadButtons       ; allow instant exit on button press
    BTFSC   buttonsA,0        ; Record button?
    GOTO    MainLoop
    BTFSC   buttonsA,2        ; Play button?
    GOTO    MainLoop

    GOTO    IdleBlink         ; continue blinking

;=================================================================
; DelayMs ? TMR0-based delay, ~1 ms × W (prescaler 1:4)
;=================================================================
DelayMs:
    MOVWF   tmp1              ; store requested milliseconds
DelayMs_Loop:
    MOVLW   4                 ; 4 × 250 µs loops per ms
    MOVWF   tmp2              ; inner counter
DelayMs_Inner:
    MOVLW   6                 ; TMR0 preload for ~250 µs
    MOVWF   TMR0              ; start timer
DelayMs_Wait:
    BTFSS   INTCON,2          ; wait for overflow
    GOTO    DelayMs_Wait
    BCF     INTCON,2          ; clear T0IF
    DECFSZ  tmp2,F            ; inner loop done?
    GOTO    DelayMs_Inner
    DECFSZ  tmp1,F            ; outer loop done?
    GOTO    DelayMs_Loop
    RETURN                    ; delay complete

;=================================================================
; LoadKeyCount ? restore binary count from EEPROM address 0x0A
;=================================================================
LoadKeyCount:
    BANKSEL EEADR
    MOVLW   0x0A              ; address of count storage
    MOVWF   EEADR             ; set address
    BANKSEL EECON1
    BCF     EECON1,7          ; EEPGD=0 ? data EEPROM
    BSF     EECON1,0          ; RD=1 ? initiate read
    BANKSEL EEDATA
    MOVF    EEDATA,W          ; read byte
    BANKSEL key_count
    MOVWF   key_count         ; restore into RAM
    RETURN

;=================================================================
; SaveKeyCount ? write current key_count to EEPROM address 0x0A
;=================================================================
SaveKeyCount:
    BANKSEL EEADR
    MOVLW   0x0A              ; target address
    MOVWF   EEADR
    BANKSEL key_count
    MOVF    key_count,W       ; get current count
    BANKSEL EEDATA
    MOVWF   EEDATA            ; place into data register
    BANKSEL EECON1
    BCF     EECON1,7          ; EEPGD=0
    BSF     EECON1,2          ; WREN=1 enable write
    MOVLW   0x55
    MOVWF   EECON2            ; unlock sequence
    MOVLW   0xAA
    MOVWF   EECON2
    BSF     EECON1,1          ; WR=1 start write
SaveWait:
    BTFSC   EECON1,1          ; wait for completion
    GOTO    SaveWait
    BCF     EECON1,2          ; WREN=0 disable write
    RETURN

;=================================================================
; ReadButtons ? sample RA0?RA2, invert logic (active-high)
;=================================================================
ReadButtons:
    BANKSEL PORTA
    MOVF    PORTA,W           ; read PORTA
    ANDLW   0x07              ; mask RA0?RA2
    XORLW   0x07              ; invert (external pull-downs)
    BANKSEL buttonsA
    MOVWF   buttonsA          ; store result
    RETURN

;=================================================================
; LoadFirstVal ? read EEPROM[0] into first_value and ASCII
;=================================================================
LoadFirstVal:
    BANKSEL EEADR
    CLRF    EEADR             ; address 0
    BANKSEL EECON1
    BCF     EECON1,7          ; EEPGD=0
    BSF     EECON1,0          ; RD=1 initiate read
    BANKSEL EEDATA
    MOVF    EEDATA,W          ; get byte
    BANKSEL first_value
    MOVWF   first_value       ; cache for idle blink
    BANKSEL ASCII
    MOVWF   ASCII             ; display immediately
    RETURN

;=================================================================
; ExitMode ? common exit cleanup for Record and Play
;=================================================================
ExitMode:
    CALL    LoadFirstVal      ; refresh first character
    BANKSEL idle_toggle
    CLRF    idle_toggle       ; force next idle to show first char
    GOTO    MainLoop          ; return to main dispatcher

;=================================================================
; KeypadScan ? 4×4 matrix scan, fills ASCII and sets KEY,0
;=================================================================
KeypadScan:
    BANKSEL KEY
    CLRF    KEY               ; clear key detected flag
    BANKSEL ASCII
    CLRF    ASCII             ; clear output

    MOVLW   0b11110000
    ANDWF   PORTB,F           ; clear row drive bits
    MOVLW   0b00000001
    IORWF   PORTB,F           ; drive row 0
    NOP                       ; settle time
    BANKSEL PORTB
    BTFSS   PORTB,4
    GOTO    R0C1
    MOVLW   '1'
    MOVWF   ASCII
    BSF     KEY,0
R0C1:   BTFSS   PORTB,5
    GOTO    R0C2
    MOVLW   '2'
    MOVWF   ASCII
    BSF     KEY,0
R0C2:   BTFSS   PORTB,6
    GOTO    R0C3
    MOVLW   '3'
    MOVWF   ASCII
    BSF     KEY,0
R0C3:   BTFSS   PORTB,7
    GOTO    Row1
    MOVLW   'A'
    MOVWF   ASCII
    BSF     KEY,0

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
R1C1:   BTFSS   PORTB,5
    GOTO    R1C2
    MOVLW   '5'
    MOVWF   ASCII
    BSF     KEY,0
R1C2:   BTFSS   PORTB,6
    GOTO    R1C3
    MOVLW   '6'
    MOVWF   ASCII
    BSF     KEY,0
R1C3:   BTFSS   PORTB,7
    GOTO    Row2
    MOVLW   'B'
    MOVWF   ASCII
    BSF     KEY,0

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
R2C1:   BTFSS   PORTB,5
    GOTO    R2C2
    MOVLW   '8'
    MOVWF   ASCII
    BSF     KEY,0
R2C2:   BTFSS   PORTB,6
    GOTO    R2C3
    MOVLW   '9'
    MOVWF   ASCII
    BSF     KEY,0
R2C3:   BTFSS   PORTB,7
    GOTO    Row3
    MOVLW   'C'
    MOVWF   ASCII
    BSF     KEY,0

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
R3C1:   BTFSS   PORTB,5
    GOTO    R3C2
    MOVLW   '0'
    MOVWF   ASCII
    BSF     KEY,0
R3C2:   BTFSS   PORTB,6
    GOTO    R3C3
    MOVLW   '#'
    MOVWF   ASCII
    BSF     KEY,0
R3C3:   BTFSS   PORTB,7
    GOTO    ScanEnd
    MOVLW   'D'
    MOVWF   ASCII
    BSF     KEY,0

ScanEnd:
    MOVLW   0b11110000
    ANDWF   PORTB,F           ; return rows to idle state
    RETURN

;=================================================================
; WriteEE ? write ASCII to EEPROM at current idx (0?9)
;=================================================================
WriteEE:
    BANKSEL idx
    MOVF    idx,W             ; get current index
    BANKSEL EEADR
    MOVWF   EEADR             ; set EEPROM address
    BANKSEL ASCII
    MOVF    ASCII,W           ; get character
    BANKSEL EEDATA
    MOVWF   EEDATA            ; place in data register
    BANKSEL EECON1
    BCF     EECON1,7          ; EEPGD=0 data EEPROM
    BSF     EECON1,2          ; WREN=1 enable write
    MOVLW   0x55
    MOVWF   EECON2            ; unlock sequence part 1
    MOVLW   0xAA
    MOVWF   EECON2            ; unlock sequence part 2
    BSF     EECON1,1          ; WR=1 start write
WriteWait:
    BTFSC   EECON1,1          ; wait for WR to clear
    GOTO    WriteWait
    BCF     EECON1,2          ; WREN=0 disable write
    RETURN

;=================================================================
; ReadEE ? read EEPROM at current idx into ASCII
;=================================================================
ReadEE:
    BANKSEL idx
    MOVF    idx,W             ; get current index
    BANKSEL EEADR
    MOVWF   EEADR             ; set address
    BANKSEL EECON1
    BCF     EECON1,7          ; EEPGD=0
    BSF     EECON1,0          ; RD=1 initiate read
    BANKSEL EEDATA
    MOVF    EEDATA,W          ; read data
    BANKSEL ASCII
    MOVWF   ASCII             ; store in display register
    RETURN

;=================================================================
; ShowASCII ? output ASCII + DP bit to PORTC
;=================================================================
ShowASCII:
    BANKSEL ASCII
    MOVF    ASCII,W           ; get current character
    IORLW   0b10000000        ; set bit7 (DP, not used but maintains pattern)
    BANKSEL PORTC
    MOVWF   PORTC             ; direct drive to display
    BCF     PORTC,7           ; ensure latch low
    NOP                       ; small delay
    NOP
    RETURN

    END