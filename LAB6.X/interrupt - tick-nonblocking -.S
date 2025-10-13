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
; Data Memory: Shared RAM for ISR and timer counters
;=================================================================
    PSECT   udata_shr,class=COMMON,delta=1
W_TEMP:         DS  1         ; Save W register during interrupts
STATUS_TEMP:    DS  1         ; Save STATUS register during interrupts
TICK_FLAG:      DS  1         ; Flag for Timer0 tick (set every overflow)
DELAY_7_COUNTER:DS  1         ; Counter for '7' delay (~2000ms)
DELAY_6_COUNTER:DS  1         ; Counter for '6' delay (~2000ms)
SAVED_6_COUNTER:DS  1         ; Saved '6' count when interrupted by '7'

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
    GOTO    HANDLE_T0     ; Handle Timer0 tick if T0IF set
    BANKSEL PORTB         ; Select Bank 0 for PORTB access
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch/flag
    BTFSS   PORTB,0       ; Check RB0 state (0=low, trigger '7')
    GOTO    TRIGGER_7     ; RB0 low: handle '7' display
    BTFSS   PORTB,1       ; Check RB1 state (0=low, trigger '6')
    GOTO    TRIGGER_6     ; RB1 low, RB0 high: handle '6'
    GOTO    ISR_EXIT      ; Both high: no action (handle in main)
TRIGGER_7:
    MOVLW   0x37          ; Load ASCII '7' for display
    MOVWF   PORTC         ; Write '7' to PORTC (RC0?RC6)
    BTFSS   DELAY_7_COUNTER,0 ; Skip if '7' already active (bit 0 as flag)
    MOVLW   31            ; Load 31 ticks for ~2031.616ms delay
    MOVWF   DELAY_7_COUNTER ; Set '7' counter (also flags active)
    BCF     IOCB,1        ; Disable RB1 IOC to block '6' triggers
    GOTO    ISR_EXIT      ; Exit ISR
TRIGGER_6:
    BTFSC   DELAY_7_COUNTER,0 ; Skip if '7' active (ignore '6')
    GOTO    ISR_EXIT      ; Exit if '7' active
    BTFSS   DELAY_6_COUNTER,0 ; Skip if '6' already active
    MOVLW   31            ; Load 31 ticks for ~2031.616ms delay
    MOVWF   DELAY_6_COUNTER ; Set '6' counter (also flags active)
    MOVLW   0x36          ; Load ASCII '6' for display
    MOVWF   PORTC         ; Write '6' to PORTC (RC0?RC6)
    GOTO    ISR_EXIT      ; Exit ISR
HANDLE_T0:
    BCF     INTCON,2      ; Clear Timer0 interrupt flag (T0IF)
    BSF     TICK_FLAG,0   ; Set tick flag for main to process
    GOTO    ISR_EXIT      ; Exit ISR
ISR_EXIT:
    SWAPF   STATUS_TEMP,W ; Restore STATUS from saved value
    MOVWF   STATUS        ; Write restored STATUS
    SWAPF   W_TEMP,F      ; Prepare W restoration (swap nibbles)
    SWAPF   W_TEMP,W      ; Restore original W value
    RETFIE                ; Return from interrupt, re-enable GIE
    ; Total: 20 words, fits 0x0008?0x001C

;=================================================================
; Main Program: Placed at 0x0020 per -pcode=20h
;=================================================================
    PSECT   code,class=CODE,delta=2
MAIN:
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
    BSF     INTCON,5      ; Enable Timer0 interrupts (T0IE)
    BSF     INTCON,7      ; Enable global interrupts (GIE)
    CLRF    DELAY_7_COUNTER ; Clear '7' delay counter
    CLRF    DELAY_6_COUNTER ; Clear '6' delay counter
    CLRF    SAVED_6_COUNTER ; Clear saved '6' counter
    CLRF    TICK_FLAG     ; Clear tick flag

    ; Initialize display based on RB0 and RB1 state
    BANKSEL PORTB
    BTFSS   PORTB,0       ; Check RB0 state (0=low, display '7')
    GOTO    INIT_7        ; RB0 low: output ASCII '7'
    BTFSS   PORTB,1       ; RB0 high, check RB1 (0=low, display '6')
    GOTO    INIT_6        ; RB1 low: output ASCII '6'
    MOVLW   0x31          ; Both RB0, RB1 high: load ASCII '1'
    GOTO    INIT_OUTPUT   ; Output to PORTC
INIT_7:
    MOVLW   0x37          ; RB0 low: load ASCII '7' for display
    GOTO    INIT_OUTPUT   ; Output to PORTC
INIT_6:
    MOVLW   0x36          ; RB1 low, RB0 high: load ASCII '6'
INIT_OUTPUT:
    MOVWF   PORTC         ; Write ASCII value to PORTC (RC0?RC6)

    ; Main loop: Handle tick-based delays and display updates
IDLE_LOOP:
    BTFSS   TICK_FLAG,0   ; Check if Timer0 tick occurred
    GOTO    IDLE_LOOP     ; No tick, keep looping
    BCF     TICK_FLAG,0   ; Clear tick flag
    BTFSC   DELAY_7_COUNTER,0 ; Check if '7' delay active
    GOTO    DEC_7_COUNTER ; Decrement '7' counter
    BTFSC   DELAY_6_COUNTER,0 ; Check if '6' delay active
    GOTO    DEC_6_COUNTER ; Decrement '6' counter
    GOTO    IDLE_LOOP     ; No active delays, loop
DEC_7_COUNTER:
    DECF    DELAY_7_COUNTER,F ; Decrement '7' counter
    BTFSS   STATUS,2      ; Check if '7' delay done (Z flag)
    GOTO    IDLE_LOOP     ; Not done, keep '7', loop
    BANKSEL IOCB          ; Select Bank 2 for IOCB
    BSF     IOCB,1        ; Re-enable RB1 IOC after '7' delay
    BANKSEL PORTB         ; Select Bank 0 for PORTB
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch
    BTFSS   PORTB,0       ; Check RB0 state (0=low, keep '7')
    GOTO    POST_7        ; RB0 low: output '7'
    BTFSC   SAVED_6_COUNTER,0 ; Check if '6' was interrupted
    GOTO    RESUME_6      ; Resume '6' delay
    BTFSS   PORTB,1       ; RB0 high, check RB1 (0=low, '6')
    GOTO    POST_6        ; RB1 low: output '6'
    MOVLW   0x31          ; Both high: load ASCII '1'
    GOTO    POST_OUTPUT   ; Output to PORTC
DEC_6_COUNTER:
    DECF    DELAY_6_COUNTER,F ; Decrement '6' counter
    BTFSS   STATUS,2      ; Check if '6' delay done (Z flag)
    GOTO    IDLE_LOOP     ; Not done, keep '6', loop
    BANKSEL PORTB         ; Select Bank 0 for PORTB
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch
    BTFSS   PORTB,0       ; Check RB0 state (0=low, set '7')
    GOTO    POST_7        ; RB0 low: output '7'
    BTFSS   PORTB,1       ; RB0 high, check RB1 (0=low, '6')
    GOTO    POST_6        ; RB1 low: output '6'
    MOVLW   0x31          ; Both high: load ASCII '1'
    GOTO    POST_OUTPUT   ; Output to PORTC
RESUME_6:
    MOVLW   0x36          ; Load ASCII '6' to resume display
    MOVWF   PORTC         ; Write '6' to PORTC
    MOVF    SAVED_6_COUNTER,W ; Restore saved '6' count
    MOVWF   DELAY_6_COUNTER ; Resume '6' delay
    CLRF    SAVED_6_COUNTER ; Clear saved counter
    GOTO    IDLE_LOOP     ; Return to loop
POST_7:
    MOVLW   0x37          ; RB0 low: load ASCII '7'
    MOVLW   31            ; Load 31 ticks for new '7' delay
    MOVWF   DELAY_7_COUNTER ; Restart '7' delay
    BCF     IOCB,1        ; Disable RB1 IOC during '7'
    GOTO    POST_OUTPUT   ; Output to PORTC
POST_6:
    MOVLW   0x36          ; RB1 low: load ASCII '6'
    MOVLW   31            ; Load 31 ticks for new '6' delay
    MOVWF   DELAY_6_COUNTER ; Start '6' delay
POST_OUTPUT:
    MOVWF   PORTC         ; Write ASCII value to PORTC (RC0?RC6)
    GOTO    IDLE_LOOP     ; Return to loop
    ; Total: ~43 words (main + handlers), starts at 0x0020