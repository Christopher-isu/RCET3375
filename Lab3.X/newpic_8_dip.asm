;=================================================================
; Device Configuration
;=================================================================
    CONFIG  FOSC = INTRC_CLKOUT     ; Internal oscillator with clock out
    CONFIG  WDTE = OFF              ; Watchdog Timer disabled
    CONFIG  PWRTE = OFF             ; Power-up Timer disabled
    CONFIG  MCLRE = ON              ; MCLR pin enabled
    CONFIG  CP = OFF                ; Code protection disabled
    CONFIG  CPD = OFF               ; Data memory protection disabled
    CONFIG  BOREN = OFF             ; Brown-out Reset disabled
    CONFIG  IESO = OFF              ; Internal/External Switchover disabled
    CONFIG  FCMEN = OFF             ; Fail-Safe Clock Monitor disabled
    CONFIG  LVP = OFF               ; Low-voltage programming disabled

    CONFIG  BOR4V = BOR40V          ; Brown-out Reset at 4.0V
    CONFIG  WRT = OFF               ; Flash memory write protection disabled

    
;=================================================================
; Include Core Definitions
;=================================================================
    #include <xc.inc>               ; Include device-specific definitions

;=================================================================
; Reset Vector
;=================================================================
    PSECT resetVect,class=CODE,delta=2  ; PIC10/12/16 reset vector section
    GOTO Start                        ; Jump to Start label after reset
    
;=================================================================
; Main Code Section
;=================================================================
    PSECT code,class=CODE,delta=2     ; Main program code section

; Reserve working registers
TEMP    EQU 0x20                      ; TEMP register for PORTB value
VALUE   EQU 0x21                      ; VALUE register for decimal result
ASCII   EQU 0x22                      ; ASCII register for ASCII code

Start:
    ; Set up internal oscillator to 4 MHz
    BCF STATUS, 6       ; RP1 = 0 (select bank bits)
    BSF STATUS, 5       ; RP0 = 1 ? Bank 1
    MOVLW   0x61        ; Load WREG with 0x61 (4 MHz, SCS=01)
    MOVWF   OSCCON      ; Set OSCCON to configure internal oscillator

    ; Configure PORTB as input
    BCF STATUS, 6       ; RP1 = 0
    BSF STATUS, 5       ; RP0 = 1 ? Bank 1
    MOVLW   0xFF        ; Load WREG with 0xFF (all bits input)
    MOVWF   TRISB       ; Set PORTB as input

    ; Configure PORTC as output
    BCF STATUS, 6       ; RP1 = 0
    BSF STATUS, 5       ; RP0 = 1 ? Bank 1
    CLRF    TRISC       ; Clear TRISC (all bits output)

    ; Disable analog functions
    BSF STATUS, 6       ; RP1 = 1
    BSF STATUS, 5       ; RP0 = 1 ? Bank 3
    CLRF    ANSELH      ; Disable analog on high PORTs
    CLRF    ANSEL       ; Disable analog on low PORTs 

    ; Disable comparators
    BSF STATUS, 6       ; RP1 = 1
    BCF STATUS, 5       ; RP0 = 0 ? Bank 2 
    CLRF    CM1CON0     ; Disable comparator 1
    CLRF    CM2CON0     ; Disable comparator 2

    ; Disable PORTB weak pull-ups
    BCF STATUS, 6       ; RP1 = 0
    BSF STATUS, 5       ; RP0 = 1 ? Bank 1
    BSF     OPTION_REG, 7 ; Set RBPU bit to disable pull-ups

    ; Clear PORTC
    BCF STATUS, 6       ; RP1 = 0
    BCF STATUS, 5       ; RP0 = 0 ? Bank 0
    CLRF    PORTC       ; Set all PORTC outputs low

MainLoop:
    BCF STATUS, 6               ; Select Bank 0 (clear RP1)
    BCF STATUS, 5               ; Ensure RP0 = 0 ? Bank 0 active
    MOVF    PORTB, W            ; Read PORTB into WREG
    MOVWF   TEMP                ; Store PORTB value in TEMP

    ; Special case: if all inputs low, output ASCII '0'
    MOVF    TEMP, F             ; Update STATUS flags based on TEMP
    BTFSS   STATUS, 2           ; Test Zero flag (bit 2) ? skip next if TEMP == 0
    GOTO    NotZero              ; If TEMP ? 0, branch to NotZero
    MOVLW   0x30                ; Load WREG with ASCII '0'
    MOVWF   ASCII                ; Store in ASCII register
    BCF     ASCII, 7             ; Clear bit 7 so PORTC7 stays low
    MOVF    ASCII, W             ; Move ASCII value into WREG
    MOVWF   PORTC                ; Output to PORTC
    GOTO    MainLoop             ; Repeat loop

NotZero:
    CLRF    VALUE                ; Clear VALUE (default decimal = 0)

    ; Priority check from lowest bit to highest ? highest set bit wins
    BTFSC   TEMP, 0              ; Test RB0
    MOVLW   1                    ; If set, load decimal 1
    BTFSC   TEMP, 1              ; Test RB1
    MOVLW   2                    ; If set, load decimal 2
    BTFSC   TEMP, 2              ; Test RB2
    MOVLW   3                    ; If set, load decimal 3
    BTFSC   TEMP, 3              ; Test RB3
    MOVLW   4                    ; If set, load decimal 4
    BTFSC   TEMP, 4              ; Test RB4
    MOVLW   5                    ; If set, load decimal 5
    BTFSC   TEMP, 5              ; Test RB5
    MOVLW   6                    ; If set, load decimal 6
    BTFSC   TEMP, 6              ; Test RB6
    MOVLW   7                    ; If set, load decimal 7
    BTFSC   TEMP, 7              ; Test RB7
    MOVLW   8                    ; If set, load decimal 8

    MOVWF   VALUE                ; Store decimal number in VALUE

    ; Convert decimal to ASCII ('0'..'8')
    MOVF    VALUE, W             ; Move decimal into WREG
    ADDLW   0x30                 ; Add ASCII offset
    MOVWF   ASCII                ; Store ASCII code
    BCF     ASCII, 7             ; Clear bit 7 so PORTC7 stays low
    MOVF    ASCII, W             ; Move ASCII into WREG
    MOVWF   PORTC                ; Output to PORTC

    GOTO    MainLoop             ; Repeat loop

;=================================================================
; End of Program
;=================================================================
    END                 ; End of source