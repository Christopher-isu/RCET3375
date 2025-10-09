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
; Keypad Scanning Code Section (4x4 Matrix)
;=================================================================
    PSECT code,class=CODE,delta=2     ; Main program code section

; Reserve working registers in Bank 0 RAM
DelayOuter   EQU 0x20                  ; Outer delay counter for variable delay loop
DECIMAL      EQU 0x21                  ; Stores highest detected key value (0x00-0x0F)
DelayInner   EQU 0x22                  ; Inner delay counter for variable delay loop
KEY          EQU 0x23                  ; Bit 0=1 if any key is pressed, else 0
CurrentInner EQU 0x24                  ; Current inner loop value for variable delay

Start:
    ; Configure 4 MHz internal oscillator
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OSCCON access
    MOVLW   0b01100001  ; Set 4 MHz (IRCF=110), use internal clock (SCS=1)
    MOVWF   OSCCON      ; Write to OSCCON for stable timing

    ; Configure PORTB: RB0-RB3 outputs (rows), RB4-RB7 inputs (columns)
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISB access
    MOVLW   0b11110000  ; RB0-RB3=0 (outputs), RB4-RB7=1 (inputs)
    MOVWF   TRISB       ; Set PORTB direction for 4x4 keypad matrix

    ; Configure PORTA: RA0 and RA1 outputs (for square wave mirroring)
    BCF STATUS, 6       ; Stay in Bank 1
    BSF STATUS, 5       ; for TRISA access
    MOVLW   0b11111100  ; RA0=0, RA1=0 (outputs), RA2-RA5=1 (inputs)
    MOVWF   TRISA       ; Set PORTA direction

    ; Disable analog functions for digital I/O
    BSF STATUS, 6       ; Select Bank 3 (RP1=1, RP0=1)
    BSF STATUS, 5       ; for ANSEL/ANSELH
    CLRF    ANSEL       ; Disable analog on PORTA/C
    CLRF    ANSELH      ; Disable analog on PORTB (RB4-RB7)

    ; Disable PORTB weak pull-ups (external pull-downs used)
    BCF STATUS, 6       ; Select Bank 1 (RP1=0, RP0=1)
    BSF STATUS, 5       ; for OPTION_REG
    BSF     OPTION_REG, 7 ; Disable internal pull-ups (RBPU=1)

    ; Initialize PORTA with RA0 and RA1 high (default state for no sound)
    BCF STATUS, 6       ; Select Bank 0 (RP1=0, RP0=0)
    BCF STATUS, 5       ; for PORTA/PORTB access
    MOVLW   0x03        ; RA0=1, RA1=1
    MOVWF   PORTA       ; Set PORTA outputs high
    MOVLW   0x18        ; Initial inner value for 1ms delay
    MOVWF   CurrentInner; Set initial delay

Main:
    CALL    DelayVariable    ; Delay in current RA0/RA1 state
    CLRF    KEY         ; Clear keypress flag (no key detected yet)
    CLRF    DECIMAL     ; Clear decimal value for highest key (0x00-0x0F)

    ; Scan Row 0 (RB0=1): keys 1-4, checking columns RB4-RB7
    MOVLW   0b11110000 ; Mask to clear row bits RB0-RB3
    ANDWF   PORTB, F    ; Set all rows low (disable other rows)
    MOVLW   0b00000001 ; Set RB0 high to scan keys 1-4
    IORWF   PORTB, F    ; Activate row 0
    NOP                 ; 1 탎 delay for column input settling
    BTFSS   PORTB, 4    ; Check RB4 (col0): high if key 1 pressed
    GOTO    key2        ; Skip if not pressed
    MOVLW   0x01        ; Load key 1 value
    MOVWF   DECIMAL     ; Store as highest key so far
    BSF     KEY, 0      ; Set keypress flag
key2:
    BTFSS   PORTB, 5    ; Check RB5 (col1): high if key 2 pressed
    GOTO    key3        ; Skip if not pressed
    MOVLW   0x02        ; Load key 2 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
key3:
    BTFSS   PORTB, 6    ; Check RB6 (col2): high if key 3 pressed
    GOTO    key4        ; Skip if not pressed
    MOVLW   0x03        ; Load key 3 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
key4:
    BTFSS   PORTB, 7    ; Check RB7 (col3): high if key 4 pressed
    GOTO    row1        ; Skip to next row if not pressed
    MOVLW   0x04        ; Load key 4 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag

row1:
    ; Scan Row 1 (RB1=1): keys 5-8, checking columns RB4-RB7
    MOVLW   0b11110000 ; Mask to clear row bits RB0-RB3
    ANDWF   PORTB, F    ; Set all rows low
    MOVLW   0b00000010 ; Set RB1 high to scan keys 5-8
    IORWF   PORTB, F    ; Activate row 1
    NOP                 ; 1 탎 delay for column input settling
    BTFSS   PORTB, 4    ; Check RB4 (col0): high if key 5 pressed
    GOTO    key6        ; Skip if not pressed
    MOVLW   0x05        ; Load key 5 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
key6:
    BTFSS   PORTB, 5    ; Check RB5 (col1): high if key 6 pressed
    GOTO    key7        ; Skip if not pressed
    MOVLW   0x06        ; Load key 6 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
key7:
    BTFSS   PORTB, 6    ; Check RB6 (col2): high if key 7 pressed
    GOTO    key8        ; Skip if not pressed
    MOVLW   0x07        ; Load key 7 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
key8:
    BTFSS   PORTB, 7    ; Check RB7 (col3): high if key 8 pressed
    GOTO    row2        ; Skip to next row if not pressed
    MOVLW   0x08        ; Load key 8 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag

row2:
    ; Scan Row 2 (RB2=1): keys 9-C, checking columns RB4-RB7
    MOVLW   0b11110000 ; Mask to clear row bits RB0-RB3
    ANDWF   PORTB, F    ; Set all rows low
    MOVLW   0b00000100 ; Set RB2 high to scan keys 9-C
    IORWF   PORTB, F    ; Activate row 2
    NOP                 ; 1 탎 delay for column input settling
    BTFSS   PORTB, 4    ; Check RB4 (col0): high if key 9 pressed
    GOTO    keyA        ; Skip if not pressed
    MOVLW   0x09        ; Load key 9 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
keyA:
    BTFSS   PORTB, 5    ; Check RB5 (col1): high if key A pressed
    GOTO    keyB        ; Skip if not pressed
    MOVLW   0x0A        ; Load key A value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
keyB:
    BTFSS   PORTB, 6    ; Check RB6 (col2): high if key B pressed
    GOTO    keyC        ; Skip if not pressed
    MOVLW   0x0B        ; Load key B value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
keyC:
    BTFSS   PORTB, 7    ; Check RB7 (col3): high if key C pressed
    GOTO    row3        ; Skip to next row if not pressed
    MOVLW   0x0C        ; Load key C value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag

row3:
    ; Scan Row 3 (RB3=1): keys D-F, 0, checking columns RB4-RB7
    MOVLW   0b11110000 ; Mask to clear row bits RB0-RB3
    ANDWF   PORTB, F    ; Set all rows low
    MOVLW   0b00001000 ; Set RB3 high to scan keys D-F, 0
    IORWF   PORTB, F    ; Activate row 3
    NOP                 ; 1 탎 delay for column input settling
    BTFSS   PORTB, 4    ; Check RB4 (col0): high if key D pressed
    GOTO    keyE        ; Skip if not pressed
    MOVLW   0x0D        ; Load key D value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
keyE:
    BTFSS   PORTB, 5    ; Check RB5 (col1): high if key E pressed
    GOTO    keyF        ; Skip if not pressed
    MOVLW   0x0E        ; Load key E value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
keyF:
    BTFSS   PORTB, 6    ; Check RB6 (col2): high if key F pressed
    GOTO    key0        ; Skip if not pressed
    MOVLW   0x0F        ; Load key F value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
key0:
    BTFSS   PORTB, 7    ; Check RB7 (col3): high if key 0 pressed
    GOTO    AfterScan   ; Skip to after scan if not pressed
    MOVLW   0x00        ; Load key 0 value
    MOVWF   DECIMAL     ; Update highest key
    BSF     KEY, 0      ; Set keypress flag
    GOTO    AfterScan   ; Proceed to after scan

AfterScan:
    MOVLW   0b11110000 ; Mask to clear row bits RB0-RB3
    ANDWF   PORTB, F    ; Set all rows low after full scan
    BTFSS   KEY, 0      ; Check if any key was pressed (skip if set)
    GOTO    Main        ; No press: back to delay (RA0/RA1 high) and rescan
    ; Key press detected: update delay and generate square wave segment
    MOVF    DECIMAL, W  ; Load DECIMAL into W
    BTFSS   STATUS, 2   ; Skip if DECIMAL == 0 (Z=1)
    GOTO    NotZero     ; If not zero, go to NotZero
    MOVLW   0x0F        ; If zero, set index to 15
    GOTO    GetDelay    ; Go to call table
NotZero:
    ADDLW   0xFF        ; DECIMAL - 1 (since W = DECIMAL, add -1)
    ; Note: ADDLW 0xFF is equivalent to decrement W
GetDelay:
    CALL    DelayTable  ; Get delay value from table
    MOVWF   CurrentInner; Update current inner loop value
    ; Now generate square wave with direct writes
    MOVLW   0x00        ; Set RA0 and RA1 low
    MOVWF   PORTA       ; Write to PORTA
    CALL    DelayVariable    ; Hold low for variable ms
    MOVLW   0x03        ; Set RA0 and RA1 high
    MOVWF   PORTA       ; Write to PORTA
    GOTO    Main        ; Back to delay (high) and rescan

;=================================================================
; Variable Delay Subroutine (~1.6ms to 3.8ms at 4MHz, based on CurrentInner)
;=================================================================
DelayVariable:
    MOVLW   0x0A        ; Outer count = 10 (0x0A)
    MOVWF   DelayOuter  ; Set outer counter
OuterLoop:
    MOVF    CurrentInner, W ; Load variable inner count
    MOVWF   DelayInner  ; Set inner counter
InnerLoop:
    NOP                 ; Adjust timing
    DECFSZ  DelayInner, F ; Decrement inner, skip if zero
    GOTO    InnerLoop   ; Loop inner
    NOP                 ; Adjust timing (after inner, before outer dec)
    DECFSZ  DelayOuter, F ; Decrement outer, skip if zero
    GOTO    OuterLoop   ; Loop outer
    RETURN              ; Return from delay

;=================================================================
; Delay Value Lookup Table (indexed 0-15 for keys 1 to F to 0)
;=================================================================
DelayTable:
    ADDWF   PCL, F      ; Add index to PCL for jump
    RETLW   0x5E        ; Index 0: Key 1, C3, ~3.813ms (94) ? ~7.626ms period
    RETLW   0x53        ; Index 1: Key 2, D3, ~3.373ms (83) ? ~6.746ms period
    RETLW   0x4A        ; Index 2: Key 3, E3, ~3.013ms (74) ? ~6.026ms period
    RETLW   0x46        ; Index 3: Key 4, F3, ~2.853ms (70) ? ~5.706ms period
    RETLW   0x3E        ; Index 4: Key 5, G3, ~2.533ms (62) ? ~5.066ms period
    RETLW   0x37        ; Index 5: Key 6, A3, ~2.253ms (55) ? ~4.506ms period
    RETLW   0x31        ; Index 6: Key 7, B3, ~2.013ms (49) ? ~4.026ms period
    RETLW   0x2E        ; Index 7: Key 8, C4, ~1.893ms (46) ? ~3.786ms period
    RETLW   0x29        ; Index 8: Key 9, D4, ~1.693ms (41) ? ~3.386ms period
    RETLW   0x24        ; Index 9: Key A, E4, ~1.493ms (36) ? ~2.986ms period
    RETLW   0x22        ; Index 10: Key B, F4, ~1.413ms (34) ? ~2.826ms period
    RETLW   0x1E        ; Index 11: Key C, G4, ~1.253ms (30) ? ~2.506ms period
    RETLW   0x1B        ; Index 12: Key D, A4, ~1.133ms (27) ? ~2.266ms period
    RETLW   0x17        ; Index 13: Key E, B4, ~0.973ms (23) ? ~1.946ms period
    RETLW   0x16        ; Index 14: Key F, C5, ~0.933ms (22) ? ~1.866ms period
    RETLW   0x13        ; Index 15: Key 0, D5, ~0.813ms (19) ? ~1.626ms period

;=================================================================
; End of Program
;=================================================================
    END