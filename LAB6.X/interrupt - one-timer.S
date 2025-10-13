#include <xc.inc>

;=================================================================
; Device Configuration: Matches 4MHz oscillator and project setup
;=================================================================
    CONFIG  FOSC = XT         ; Use 4MHz external crystal oscillator
    CONFIG  WDTE = OFF        ; Disable Watchdog Timer to avoid resets
    CONFIG  PWRTE = OFF       ; Disable Power-up Timer for instant start
    CONFIG  MCLRE = ON        ; Enable MCLR pin for external reset
    CONFIG  CP = OFF          ; Disable code protection for full access
    CONFIG  CPD = OFF         ; Disable EEPROM data protection
    CONFIG  BOREN = OFF       ; Disable Brown-out Reset for simplicity
    CONFIG  IESO = OFF        ; Disable clock switchover for single source
    CONFIG  FCMEN = OFF       ; Disable Fail-Safe Clock Monitor
    CONFIG  LVP = OFF         ; Disable low-voltage programming
    CONFIG  WRT = OFF         ; Disable Flash write protection

;=================================================================
; Data Memory: Shared RAM for ISR and timer delay
;=================================================================
    PSECT   udata_shr,class=COMMON,delta=1
W_TEMP:         DS  1         ; Save W register during interrupts
STATUS_TEMP:    DS  1         ; Save STATUS register during interrupts
TIMER_COUNT:    DS  1         ; Timer0 overflow counter for ~2000ms
DELAY_FLAG:     DS  1         ; Flag for delay completion
DELAY_7_ACTIVE: DS  1         ; Flag for '7' delay in main
DELAY_6_ACTIVE: DS  1         ; Flag for '6' delay in main
SAVED_6_COUNT:  DS  1         ; Saved '6' count when interrupted by '7'

;=================================================================
; Reset Vector: Placed at 0x0000 per -presetVect=0h
;=================================================================
    PSECT   resetVect,class=CODE,delta=2
resetVect:
    GOTO    MAIN          ; Jump to main program at 0x0020

;=================================================================
; Interrupt Vector: Placed at 0x0004 per -pisrVect=4h
;=================================================================
    PSECT   isrVect,class=CODE,delta=2
isrVect:
    MOVWF   W_TEMP        ; Save W register to shared RAM
    SWAPF   STATUS,W      ; Save STATUS without altering flags
    MOVWF   STATUS_TEMP   ; Store STATUS in shared RAM
    GOTO    isrCode       ; Jump to ISR logic at 0x0008
    ; Total: 4 words, fits 0x0004?0x0007

;=================================================================
; ISR Logic: Placed at 0x0008 per -pisrCode=8h
;=================================================================
    PSECT   isrCode,class=CODE,delta=2
isrCode:
    BTFSC   INTCON,2      ; Check Timer0 overflow flag (T0IF)
    GOTO    HANDLE_T0     ; Handle Timer0 interrupt if T0IF set
    BANKSEL PORTB         ; Select Bank 0 for PORTB access
    MOVF    PORTB,W       ; Read PORTB to end mismatch condition
    BANKSEL INTCON        ; Select Bank 0 for INTCON
    BCF     INTCON,0      ; Clear IOC interrupt flag (RBIF)
    BTFSS   PORTB,0       ; Check RB0 state (0=low, trigger '7')
    GOTO    TRIGGER_7     ; RB0 low: handle '7' display
    BTFSS   PORTB,1       ; Check RB1 state (0=low, trigger '6')
    GOTO    TRIGGER_6     ; RB1 low, RB0 high: handle '6'
    GOTO    ISR_EXIT      ; Both high: no action (handle in main)
TRIGGER_7:
    MOVF    DELAY_6_ACTIVE,W ; Check if '6' delay active
    BTFSC   STATUS,2      ; Skip if '6' active (Z=0)
    GOTO    ISR_SET_7     ; No '6', proceed to '7'
    MOVF    TIMER_COUNT,W ; Save current '6' timer count
    MOVWF   SAVED_6_COUNT ; Store for resume
    CLRF    DELAY_6_ACTIVE ; Clear '6' active flag
ISR_SET_7:
    MOVLW   0x37          ; Load ASCII '7' for display
    MOVWF   PORTC         ; Write '7' to PORTC (RC0?RC6)
    BTFSC   DELAY_7_ACTIVE,0 ; Skip if '7' not already active
    GOTO    ISR_EXIT      ; Ignore duplicate '7' trigger
    BSF     DELAY_7_ACTIVE,0 ; Set '7' delay flag for main
    BANKSEL IOCB          ; Select Bank 2 for IOCB
    BCF     IOCB,1        ; Disable RB1 IOC to block '6'
    GOTO    ISR_EXIT      ; Exit ISR
TRIGGER_6:
    BTFSC   DELAY_7_ACTIVE,0 ; Skip if '7' not active
    GOTO    ISR_EXIT      ; Ignore '6' during '7'
    BTFSC   DELAY_6_ACTIVE,0 ; Skip if '6' not active
    GOTO    ISR_EXIT      ; Ignore duplicate '6' trigger
    MOVLW   0x36          ; Load ASCII '6' for display
    MOVWF   PORTC         ; Write '6' to PORTC (RC0?RC6)
    BSF     DELAY_6_ACTIVE,0 ; Set '6' delay flag for main
    GOTO    ISR_EXIT      ; Exit ISR
HANDLE_T0:
    BCF     INTCON,2      ; Clear Timer0 interrupt flag (T0IF)
    DECF    TIMER_COUNT,F ; Decrement Timer0 overflow counter
    BTFSC   STATUS,2      ; Check if counter reached zero (Z flag)
    BSF     DELAY_FLAG,0  ; Set delay completion flag if zero
    GOTO    ISR_EXIT      ; Exit ISR
ISR_EXIT:
    SWAPF   STATUS_TEMP,W ; Restore STATUS from saved value
    MOVWF   STATUS        ; Write restored STATUS
    SWAPF   W_TEMP,F      ; Prepare W restoration (swap nibbles)
    SWAPF   W_TEMP,W      ; Restore original W value
    RETFIE                ; Return from interrupt, re-enable GIE
    ; Total: 26 words, fits 0x0008?0x001F

;=================================================================
; Timer0 Delay: ~2000ms delay using Timer0 interrupts
;=================================================================
    PSECT   code,class=CODE,delta=2
DELAY_2000MS:
    MOVLW   31            ; Load 31 for ~2031.616ms (31 overflows)
    MOVWF   TIMER_COUNT   ; Initialize Timer0 overflow counter
    CLRF    DELAY_FLAG    ; Clear delay completion flag
    BSF     INTCON,5      ; Enable Timer0 interrupts (T0IE)
DELAY_WAIT:
    BTFSS   DELAY_FLAG,0  ; Check if delay complete (flag set)
    GOTO    DELAY_WAIT    ; Loop until delay completes
    BCF     INTCON,5      ; Disable Timer0 interrupts (T0IE)
    BCF     INTCON,2      ; Clear T0IF to prevent stray interrupts
    RETURN                ; Return to caller
    ; Total: 9 words

;=================================================================
; Handle Delay and Update: Process delays and update display
;=================================================================
HANDLE_DELAY:
    BTFSC   DELAY_7_ACTIVE,0 ; Check if '7' delay active
    GOTO    DO_7_DELAY    ; Handle '7' delay
    BTFSC   DELAY_6_ACTIVE,0 ; Check if '6' delay active
    GOTO    DO_6_DELAY    ; Handle '6' delay
    GOTO    UPDATE_DISPLAY ; No delay, update display
DO_7_DELAY:
    CALL    DELAY_2000MS  ; Run ~2000ms delay for '7'
    CLRF    DELAY_7_ACTIVE ; Clear '7' active flag
    BTFSC   SAVED_6_COUNT,0 ; Check if '6' was interrupted
    GOTO    RESUME_6      ; Resume '6' delay
    GOTO    UPDATE_DISPLAY ; Update display to current state
DO_6_DELAY:
    CALL    DELAY_2000MS  ; Run ~2000ms delay for '6'
    CLRF    DELAY_6_ACTIVE ; Clear '6' active flag
    GOTO    UPDATE_DISPLAY ; Update display to current state
RESUME_6:
    BANKSEL PORTC         ; Select Bank 0 for PORTC
    MOVLW   0x36          ; Load ASCII '6' to resume display
    MOVWF   PORTC         ; Write '6' to PORTC
    MOVF    SAVED_6_COUNT,W ; Restore saved '6' count
    MOVWF   TIMER_COUNT   ; Set Timer0 counter for resume
    CLRF    SAVED_6_COUNT ; Clear saved count
    CLRF    DELAY_FLAG    ; Clear delay flag for new cycle
    BSF     INTCON,5      ; Enable Timer0 interrupts (T0IE)
DELAY_RESUME:
    BTFSS   DELAY_FLAG,0  ; Check if resumed delay complete
    GOTO    DELAY_RESUME  ; Loop until complete
    BCF     INTCON,5      ; Disable Timer0 interrupts
    BCF     INTCON,2      ; Clear T0IF to prevent strays
    CLRF    DELAY_6_ACTIVE ; Clear '6' active flag
    GOTO    UPDATE_DISPLAY ; Update display after resume
UPDATE_DISPLAY:
    BANKSEL IOCB          ; Select Bank 2 for IOCB
    BSF     IOCB,1        ; Re-enable RB1 IOC after delay
    BANKSEL PORTB         ; Select Bank 0 for PORTB
    MOVF    PORTB,W       ; Read PORTB to end mismatch condition
    BANKSEL INTCON        ; Select Bank 0 for INTCON
    BCF     INTCON,0      ; Clear IOC interrupt flag (RBIF)
    BTFSS   PORTB,0       ; Check RB0 state (0=low, set '7')
    GOTO    DISP_SET_7    ; RB0 low: output '7'
    BTFSS   PORTB,1       ; RB0 high, check RB1 (0=low, '6')
    GOTO    DISP_SET_6    ; RB1 low: output '6'
    MOVLW   0x31          ; Both high: load ASCII '1'
    GOTO    DISP_OUTPUT   ; Output to PORTC
DISP_SET_7:
    MOVLW   0x37          ; RB0 low: load ASCII '7'
    BSF     DELAY_7_ACTIVE,0 ; Set '7' delay flag
    BANKSEL IOCB          ; Select Bank 2 for IOCB
    BCF     IOCB,1        ; Disable RB1 IOC during '7'
    GOTO    DISP_OUTPUT   ; Output to PORTC
DISP_SET_6:
    MOVLW   0x36          ; RB1 low: load ASCII '6'
    BSF     DELAY_6_ACTIVE,0 ; Set '6' delay flag
DISP_OUTPUT:
    BANKSEL PORTC         ; Select Bank 0 for PORTC
    MOVWF   PORTC         ; Write ASCII value to PORTC (RC0?RC6)
    RETURN                ; Return to main
    ; Total: 28 words

;=================================================================
; Main Program: Placed at 0x0020 per -pcode=20h
;=================================================================
    PSECT   code,class=CODE,delta=2
MAIN:
    BANKSEL PORTC         ; Select Bank 0 for PORTC
    CLRF    PORTC         ; Clear PORTC outputs (initially off)
    BANKSEL TRISC
    CLRF    TRISC         ; Configure PORTC as outputs (RC0?RC6)
    BSF     TRISB,0       ; Configure RB0 as input for interrupt
    BSF     TRISB,1       ; Configure RB1 as input for interrupt
    BANKSEL ANSELH
    BCF     ANSELH,4      ; Set RB0 as digital I/O (ANS12)
    BCF     ANSELH,2      ; Set RB1 as digital I/O (ANS10)
    BANKSEL OPTION_REG
    MOVLW   0x87          ; Set Timer0 prescaler 1:256, disable pull-ups
    MOVWF   OPTION_REG    ; Apply Timer0 and port settings
    BANKSEL TMR0
    CLRF    TMR0          ; Clear Timer0 counter
    BANKSEL IOCB
    BSF     IOCB,0        ; Enable Interrupt-on-Change for RB0
    BSF     IOCB,1        ; Enable Interrupt-on-Change for RB1
    BANKSEL PORTB
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch
    BANKSEL INTCON
    BCF     INTCON,0      ; Clear IOC interrupt flag (IOCIF)
    BCF     INTCON,2      ; Clear Timer0 interrupt flag (T0IF)
    BSF     INTCON,3      ; Enable IOC interrupts (IOCIE)
    BSF     INTCON,7      ; Enable global interrupts (GIE)
    CLRF    DELAY_7_ACTIVE ; Clear '7' delay flag
    CLRF    DELAY_6_ACTIVE ; Clear '6' delay flag
    CLRF    SAVED_6_COUNT ; Clear saved '6' count

    ; Initialize display based on RB0 and RB1 state
    BANKSEL PORTB
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch
    BANKSEL INTCON        ; Select Bank 0 for INTCON
    BCF     INTCON,0      ; Clear IOC interrupt flag (RBIF)
    BTFSS   PORTB,0       ; Check RB0 state (0=low, display '7')
    GOTO    INIT_SET_7    ; RB0 low: output ASCII '7'
    BTFSS   PORTB,1       ; RB0 high, check RB1 (0=low, display '6')
    GOTO    INIT_SET_6    ; RB1 low: output ASCII '6'
    MOVLW   0x31          ; Both RB0, RB1 high: load ASCII '1'
    GOTO    INIT_OUTPUT   ; Output to PORTC
INIT_SET_7:
    MOVLW   0x37          ; RB0 low: load ASCII '7'
    BSF     DELAY_7_ACTIVE,0 ; Set '7' delay flag
    BANKSEL IOCB          ; Select Bank 2 for IOCB
    BCF     IOCB,1        ; Disable RB1 IOC during '7'
    GOTO    INIT_OUTPUT   ; Output to PORTC
INIT_SET_6:
    MOVLW   0x36          ; RB1 low, RB0 high: load ASCII '6'
    BSF     DELAY_6_ACTIVE,0 ; Set '6' delay flag
INIT_OUTPUT:
    BANKSEL PORTC         ; Select Bank 0 for PORTC
    MOVWF   PORTC         ; Write ASCII value to PORTC (RC0?RC6)

    ; Main loop: Handle delays and display updates
IDLE_LOOP:
    CALL    HANDLE_DELAY  ; Process active delays and update display
    GOTO    IDLE_LOOP     ; Infinite loop, ISR/main handle display
    ; Total: 23 words, starts at 0x0020