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

;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>               ; Include PIC16F883 register definitions

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2  ; Define reset vector section at 0x0000
    GOTO Start                        ; Jump to initialization on power-up/reset
    
;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2     ; Main program code section

; Reserve working registers in Bank 0 RAM
DECIMAL EQU 0x21                      ; Stores highest detected key value (1-9)
ASCII   EQU 0x22                      ; Holds ASCII code for output ('1'-'9', '0')
KEY     EQU 0x23                      ; Bit 0=1 if any key is pressed, else 0

Start:
    ; Configure 4 MHz internal oscillator
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OSCCON access
    MOVLW   0b01100001  ; Set 4 MHz (IRCF=110), use internal clock (SCS=1)
    MOVWF   OSCCON      ; Write to OSCCON for stable timing

    ; Configure PORTB: RB0-RB2 outputs (rows), RB3-RB7 inputs (columns)
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISB access
    MOVLW   0b11111000  ; RB0-RB2=0 (outputs), RB3-RB7=1 (inputs)
    MOVWF   TRISB       ; Set PORTB direction for keypad matrix

    ; Configure PORTC as output for ASCII data and WE signal
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISC access
    CLRF    TRISC       ; All PORTC bits output (RC0-RC6=ASCII, RC7=WE)

    ; Disable analog functions for digital I/O
    BSF STATUS, 6       ; Select Bank 3 (RP1=1, RP0=1)
    BSF STATUS, 5       ; for ANSEL/ANSELH
    CLRF    ANSELH      ; Disable analog on PORTB (RB4-RB7)
    CLRF    ANSEL       ; Disable analog on PORTA/C

    ; Disable comparators to free PORT pins
    BSF STATUS, 6       ; Select Bank 2 (RP1=1, RP0=0)
    BCF STATUS, 5       ; for CM1CON0/CM2CON0
    CLRF    CM1CON0     ; Turn off comparator 1
    CLRF    CM2CON0     ; Turn off comparator 2

    ; Disable PORTB weak pull-ups (external pull-ups used)
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OPTION_REG
    BSF     OPTION_REG, 7 ; Disable internal pull-ups (RBPU=1)

    ; Initialize PORTC to low
    BCF STATUS, 6       ; Select Bank 0 (RP1=0, RP0=0)
    BCF STATUS, 5       ; for PORTC access
    CLRF    PORTC       ; Clear PORTC outputs to avoid initial glitches

MainLoop:
    BCF STATUS, 6       ; Select Bank 0 for PORTB/C access
    BCF STATUS, 5       ; Ensure RP0=0
    CLRF    KEY         ; Clear keypress flag (no key detected yet)
    CLRF    DECIMAL     ; Clear decimal value for highest key (1-9)

    ; Scan Row 0 (RB0=1): keys 1-3, checking columns RB4-RB6
    MOVLW   0b11111000 ; Mask to clear row bits RB0-RB2
    ANDWF   PORTB, F    ; Set all rows low (disable other rows)
    MOVLW   0b00000001 ; Set RB0 high to scan keys 1-3
    IORWF   PORTB, F    ; Activate row 0
    NOP                 ; 1 탎 delay for column input settling
    BTFSS   PORTB, 4    ; Check RB4 (col0): low if key 1 pressed
    GOTO    key2        ; Skip if not pressed
    MOVLW   1           ; Load key 1 value
    MOVWF   DECIMAL     ; Store as highest key so far
    BSF     KEY, 0      ; Set keypress flag
key2:
    BTFSS   PORTB, 5    ; Check RB5 (col1): low if key 2 pressed
    GOTO    key3        ; Skip if not pressed
    MOVLW   2           ; Load key 2 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1)
    BSF     KEY, 0      ; Set keypress flag
key3:
    BTFSS   PORTB, 6    ; Check RB6 (col2): low if key 3 pressed
    GOTO    row1        ; Skip to next row if not pressed
    MOVLW   3           ; Load key 3 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1,2)
    BSF     KEY, 0      ; Set keypress flag

row1:
    ; Scan Row 1 (RB1=1): keys 4-6, checking columns RB4-RB6
    MOVLW   0b11111000 ; Mask to clear row bits RB0-RB2
    ANDWF   PORTB, F    ; Set all rows low
    MOVLW   0b00000010 ; Set RB1 high to scan keys 4-6
    IORWF   PORTB, F    ; Activate row 1
    NOP                 ; 1 탎 delay for column input settling
    BTFSS   PORTB, 4    ; Check RB4 (col0): low if key 4 pressed
    GOTO    key5        ; Skip if not pressed
    MOVLW   4           ; Load key 4 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1-3)
    BSF     KEY, 0      ; Set keypress flag
key5:
    BTFSS   PORTB, 5    ; Check RB5 (col1): low if key 5 pressed
    GOTO    key6        ; Skip if not pressed
    MOVLW   5           ; Load key 5 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1-4)
    BSF     KEY, 0      ; Set keypress flag
key6:
    BTFSS   PORTB, 6    ; Check RB6 (col2): low if key 6 pressed
    GOTO    row2        ; Skip to next row if not pressed
    MOVLW   6           ; Load key 6 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1-5)
    BSF     KEY, 0      ; Set keypress flag

row2:
    ; Scan Row 2 (RB2=1): keys 7-9, checking columns RB4-RB6
    MOVLW   0b11111000 ; Mask to clear row bits RB0-RB2
    ANDWF   PORTB, F    ; Set all rows low
    MOVLW   0b00000100 ; Set RB2 high to scan keys 7-9
    IORWF   PORTB, F    ; Activate row 2
    NOP                 ; 1 탎 delay for column input settling
    BTFSS   PORTB, 4    ; Check RB4 (col0): low if key 7 pressed
    GOTO    key8        ; Skip if not pressed
    MOVLW   7           ; Load key 7 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1-6)
    BSF     KEY, 0      ; Set keypress flag
key8:
    BTFSS   PORTB, 5    ; Check RB5 (col1): low if key 8 pressed
    GOTO    key9        ; Skip if not pressed
    MOVLW   8           ; Load key 8 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1-7)
    BSF     KEY, 0      ; Set keypress flag
key9:
    BTFSS   PORTB, 6    ; Check RB6 (col2): low if key 9 pressed
    GOTO    output      ; Skip to output if not pressed
    MOVLW   9           ; Load key 9 value
    MOVWF   DECIMAL     ; Update highest key (overwrites 1-8)
    BSF     KEY, 0      ; Set keypress flag

output:
    ; Output highest key (or '0') to PORTC, latch with WE
    MOVLW   0b11111000 ; Clear row bits RB0-RB2
    ANDWF   PORTB, F    ; Disable all rows for clean state
    BTFSS   KEY, 0      ; Check if any key was pressed
    GOTO    output_zero ; Jump to output '0' if no key
    MOVF    DECIMAL, W  ; Load highest key value (1-9)
    ADDLW   0b00110000 ; Convert to ASCII ('1'-'9')
    MOVWF   ASCII       ; Store ASCII code
    MOVF    ASCII, W    ; Move ASCII to W for output
    IORLW   0b10000000 ; Set RC7=1 (WE inactive)
    MOVWF   PORTC       ; Set PORTC with ASCII and WE high
    BCF     PORTC, 7    ; Pull RC7 low to latch display
    NOP                 ; Delay 1 탎 for stable WE pulse
    NOP                 ; Extend WE low to ~3 탎 for latching
    GOTO    MainLoop    ; Repeat scan loop

output_zero:
    ; Output '0' to PORTC if no key pressed
    MOVLW   0b00110000 | 0b10000000 ; Load ASCII '0' with RC7=1
    MOVWF   PORTC       ; Set PORTC with '0' and WE high
    BCF     PORTC, 7    ; Pull RC7 low to latch display
    NOP                 ; Delay 1 탎 for stable WE pulse (~2 탎)
    GOTO    MainLoop    ; Repeat scan loop

;=================================================================
; End of Program
;=================================================================
    END