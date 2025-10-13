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
; Data Memory: Shared RAM for ISR and Timer0 delay variables
;=================================================================
    PSECT   udata_shr,class=COMMON,delta=1
W_TEMP:             DS      1         ; Reserve 1 byte for saving W register
STATUS_TEMP:        DS      1         ; Reserve 1 byte for saving STATUS register
TIMER_COUNT:        DS      1         ; Reserve 1 byte for Timer0 overflow counter
DELAY_FLAG:         DS      1         ; Reserve 1 byte to signal delay completion
DELAY_ACTIVE:       DS      1         ; Reserve 1 byte to flag delay active for main
DELAY_STATE:        DS      1         ; Reserve 1 byte for delay state (0=none, 1='6', 2='7')
SAVED_TIMER_COUNT:  DS      1         ; Reserve 1 byte for saved '6' delay count

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
    SWAPF   STATUS,W      ; Save STATUS to W without altering flags
    MOVWF   STATUS_TEMP   ; Store STATUS in shared RAM
    GOTO    isrCode       ; Jump to ISR logic at 0x0008
    ; Total: 4 words, fits 0x0004?0x0007

;=================================================================
; ISR Logic: Placed at 0x0008 per -pisrCode=8h
;=================================================================
    PSECT   isrCode,class=CODE,delta=2
isrCode:
    BTFSC   INTCON,2      ; Check Timer0 overflow flag (T0IF bit 2)
    GOTO    HANDLE_T0     ; Handle Timer0 interrupt if T0IF is set
    BANKSEL PORTB         ; Select Bank 0 for PORTB access
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch/flag
    BCF     INTCON,0      ; Clear IOC interrupt flag (IOCIF bit 0)
    MOVF    DELAY_STATE,W ; Load current delay state
    XORLW   0x02          ; Check if state is '7' (2)
    BTFSC   STATUS,2      ; Skip if not '7' (Z=0 if not equal)
    GOTO    ISR_EXIT      ; Exit if during '7' (shouldn't trigger)
    MOVF    DELAY_STATE,W ; Reload state
    XORLW   0x01          ; Check if state is '6' (1)
    BTFSS   STATUS,2      ; Skip if not '6' (Z=1 if equal)
    GOTO    NORMAL_HANDLE ; Handle normally if no delay
    BTFSC   PORTB,0       ; During '6': check RB0 (high=ignore, not '7')
    GOTO    ISR_EXIT      ; Ignore change if not to '7'
    GOTO    START_7       ; RB0 low: interrupt to '7'
NORMAL_HANDLE:
    BTFSS   PORTB,0       ; Check RB0 state (0=low, start '7')
    GOTO    START_7       ; RB0 low: start '7' delay
    BTFSS   PORTB,1       ; RB0 high, check RB1 (0=low, start '6')
    GOTO    START_6       ; RB1 low: start '6' delay
    GOTO    START_1       ; Both high: display '1', no delay
START_7:
    MOVLW   0x37          ; Load ASCII '7' for display
    MOVWF   PORTC         ; Write '7' to PORTC (RC0?RC6)
    CLRF    SAVED_TIMER_COUNT ; Default: no saved count
    MOVF    DELAY_STATE,W ; Check if interrupting '6'
    XORLW   0x01          ; Compare to 1 ('6')
    BTFSS   STATUS,2      ; Skip if not '6' (Z=1 if equal)
    GOTO    NO_SAVE       ; Not interrupting '6'
    MOVF    TIMER_COUNT,W ; Save remaining '6' count
    MOVWF   SAVED_TIMER_COUNT ; Store for resume
    BSF     DELAY_FLAG,0  ; Set flag to exit current '6' delay loop
NO_SAVE:
    MOVLW   31            ; Load 31 for ~2000ms full delay
    MOVWF   TIMER_COUNT   ; Initialize counter for '7'
    CLRF    DELAY_FLAG    ; Clear delay flag for new delay
    CLRF    TMR0          ; Reset Timer0 for accuracy
    BSF     INTCON,5      ; Enable Timer0 interrupts (T0IE bit 5)
    MOVLW   0x02          ; Set state to '7' (2)
    MOVWF   DELAY_STATE   ; Update delay state
    BSF     DELAY_ACTIVE,0; Set flag for main to handle
    BCF     INTCON,3      ; Disable IOC interrupts (IOCIE bit 3) for '7'
    GOTO    ISR_EXIT      ; Jump to ISR exit
START_6:
    MOVLW   0x36          ; Load ASCII '6' for display
    MOVWF   PORTC         ; Write '6' to PORTC (RC0?RC6)
    MOVLW   31            ; Load 31 for ~2000ms delay
    MOVWF   TIMER_COUNT   ; Initialize counter for '6'
    CLRF    DELAY_FLAG    ; Clear delay flag
    CLRF    TMR0          ; Reset Timer0 for accuracy
    BSF     INTCON,5      ; Enable Timer0 interrupts (T0IE bit 5)
    MOVLW   0x01          ; Set state to '6' (1)
    MOVWF   DELAY_STATE   ; Update delay state
    BSF     DELAY_ACTIVE,0; Set flag for main to handle
    GOTO    ISR_EXIT      ; Jump to ISR exit (IOCIE remains enabled)
START_1:
    MOVLW   0x31          ; Load ASCII '1' for display
    MOVWF   PORTC         ; Write '1' to PORTC (RC0?RC6)
    CLRF    DELAY_STATE   ; Clear delay state
    CLRF    DELAY_ACTIVE  ; Clear delay active flag
    BCF     INTCON,5      ; Disable Timer0 interrupts (T0IE bit 5)
    GOTO    ISR_EXIT      ; Jump to ISR exit
HANDLE_T0:
    BCF     INTCON,2      ; Clear Timer0 interrupt flag (T0IF bit 2)
    DECF    TIMER_COUNT,F ; Decrement Timer0 overflow counter
    BTFSC   STATUS,2      ; Check if counter reached zero (Z flag)
    BSF     DELAY_FLAG,0  ; Set delay completion flag if zero
    GOTO    ISR_EXIT      ; Jump to ISR exit
ISR_EXIT:
    SWAPF   STATUS_TEMP,W ; Restore STATUS from saved value
    MOVWF   STATUS        ; Write restored STATUS
    SWAPF   W_TEMP,F      ; Prepare W restoration (swap nibbles)
    SWAPF   W_TEMP,W      ; Restore original W value
    RETFIE                ; Return from interrupt, re-enable GIE
    ; Total: ~35 words, fits 0x0008?0x002B (expanded for new logic)

;=================================================================
; Delay Remaining: Wait for current delay to complete
;=================================================================
    PSECT   code,class=CODE,delta=2
DELAY_REMAINING:
    BTFSS   DELAY_FLAG,0  ; Poll DELAY_FLAG bit 0: skip if set (delay complete)
    GOTO    DELAY_REMAINING ; Loop until delay completes or interrupted
    BCF     INTCON,5      ; Disable Timer0 interrupts (T0IE bit 5)
    RETURN                ; Return to caller
    ; Total: 4 words

;=================================================================
; Post-Completion Update: Check current inputs and update display
;=================================================================
POST_COMPLETE:
    BANKSEL PORTB         ; Select Bank 0 for PORTB access
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch/flag
    BCF     INTCON,0      ; Clear IOC interrupt flag (IOCIF bit 0)
    BTFSC   PORTB,0       ; Check RB0 (low=0? '7')
    GOTO    PC_CHECK1     ; High: check RB1
    MOVLW   0x37          ; RB0 low: '7'
    GOTO    PC_OUT        ; Output to PORTC
PC_CHECK1:
    BTFSC   PORTB,1       ; RB0 high, check RB1 (low=0? '6')
    GOTO    PC_1          ; Both high: '1'
    MOVLW   0x36          ; RB1 low: '6'
    GOTO    PC_OUT        ; Output to PORTC
PC_1:
    MOVLW   0x31          ; Both high: '1'
PC_OUT:
    MOVWF   PORTC         ; Write to PORTC (RC0?RC6)
    BSF     INTCON,3      ; Enable IOC interrupts (IOCIE bit 3)
    RETURN                ; Return to caller
    ; Total: 10 words (optimized)

;=================================================================
; Handle Delay: Manage '6' or '7' delay based on state
;=================================================================
HANDLE_DELAY:
    MOVF    DELAY_STATE,W ; Load current state
    XORLW   0x01          ; Check if '6' (1)
    BTFSC   STATUS,2      ; Skip if not '6' (Z=1 if equal)
    GOTO    HANDLE_6_DELAY; Handle '6' delay
HANDLE_7_DELAY:
    CALL    DELAY_REMAINING ; Wait for '7' delay
    MOVF    SAVED_TIMER_COUNT,W ; Check if saved '6' count exists
    BTFSC   STATUS,2      ; Skip if saved count >0 (Z=0 if nonzero)
    GOTO    NO_RESUME     ; No resume: complete normally
    MOVWF   TIMER_COUNT   ; Restore saved count for '6'
    CLRF    DELAY_FLAG    ; Clear delay flag
    CLRF    TMR0          ; Reset Timer0 for resumed delay
    BSF     INTCON,5      ; Enable Timer0 interrupts (T0IE bit 5)
    MOVLW   0x01          ; Set state to '6'
    MOVWF   DELAY_STATE   ; Update delay state
    BSF     DELAY_ACTIVE,0; Ensure active flag set
    BSF     INTCON,3      ; Enable IOC interrupts for '6'
    CLRF    SAVED_TIMER_COUNT ; Clear saved count
    MOVLW   0x36          ; Revert display to '6'
    MOVWF   PORTC         ; Write '6' to PORTC
    RETURN                ; Return (main will handle resumed '6')
NO_RESUME:
    CLRF    DELAY_STATE   ; Clear delay state
    CLRF    DELAY_ACTIVE  ; Clear active flag
    CALL    POST_COMPLETE ; Update display based on current inputs
    RETURN                ; Return to main
HANDLE_6_DELAY:
    CALL    DELAY_REMAINING ; Wait for '6' delay
    MOVF    DELAY_STATE,W ; Check if state still '6'
    XORLW   0x01          ; Compare to 1
    BTFSS   STATUS,2      ; Skip if still '6' (Z=1 if equal)
    RETURN                ; Interrupted: return (main handles '7')
    CLRF    DELAY_STATE   ; Clear delay state
    CLRF    DELAY_ACTIVE  ; Clear active flag
    CALL    POST_COMPLETE ; Update display based on current inputs
    RETURN                ; Return to main
    ; Total: 28 words

;=================================================================
; Main Program: Placed at 0x0020 per -pcode=20h
;=================================================================
    PSECT   code,class=CODE,delta=2
MAIN:
    CLRF    PORTC         ; Clear PORTC outputs (initially off)
    BANKSEL TRISC
    CLRF    TRISC         ; Configure PORTC as outputs (RC0?RC7)
    BSF     TRISB,0       ; Configure RB0 as input for interrupt
    BSF     TRISB,1       ; Configure RB1 as input for interrupt
    BANKSEL ANSELH
    BCF     ANSELH,4      ; Set RB0 as digital I/O (ANS12 bit 4)
    BCF     ANSELH,2      ; Set RB1 as digital I/O (ANS10 bit 2)
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
    BCF     INTCON,0      ; Clear IOC interrupt flag (IOCIF bit 0)
    BCF     INTCON,2      ; Clear Timer0 interrupt flag (T0IF bit 2)
    BSF     INTCON,3      ; Enable IOC interrupts (IOCIE bit 3)
    BSF     INTCON,7      ; Enable global interrupts (GIE bit 7)
    CLRF    DELAY_ACTIVE  ; Clear delay active flag
    CLRF    DELAY_STATE   ; Clear delay state
    CLRF    SAVED_TIMER_COUNT ; Clear saved count

    ; Initialize display and delay based on RB0 and RB1 state
    BANKSEL PORTB
    BTFSS   PORTB,0       ; Check RB0 state (0=low, init '7')
    GOTO    INIT_START_7  ; RB0 low: start '7'
    BTFSS   PORTB,1       ; RB0 high, check RB1 (0=low, init '6')
    GOTO    INIT_START_6  ; RB1 low: start '6'
    MOVLW   0x31          ; Both high: display '1'
    MOVWF   PORTC         ; Write '1' to PORTC
    GOTO    IDLE_LOOP     ; Enter main loop
INIT_START_7:
    MOVLW   0x37          ; Load ASCII '7'
    MOVWF   PORTC         ; Write '7' to PORTC
    MOVLW   31            ; Load 31 for ~2000ms
    MOVWF   TIMER_COUNT   ; Initialize counter
    CLRF    DELAY_FLAG    ; Clear delay flag
    CLRF    TMR0          ; Reset Timer0
    BSF     INTCON,5      ; Enable Timer0 interrupts
    MOVLW   0x02          ; Set state to '7'
    MOVWF   DELAY_STATE   ; Update state
    BSF     DELAY_ACTIVE,0; Set active flag
    BCF     INTCON,3      ; Disable IOCIE for '7'
    GOTO    IDLE_LOOP     ; Enter main loop
INIT_START_6:
    MOVLW   0x36          ; Load ASCII '6'
    MOVWF   PORTC         ; Write '6' to PORTC
    MOVLW   31            ; Load 31 for ~2000ms
    MOVWF   TIMER_COUNT   ; Initialize counter
    CLRF    DELAY_FLAG    ; Clear delay flag
    CLRF    TMR0          ; Reset Timer0
    BSF     INTCON,5      ; Enable Timer0 interrupts
    MOVLW   0x01          ; Set state to '6'
    MOVWF   DELAY_STATE   ; Update state
    BSF     DELAY_ACTIVE,0; Set active flag
    ; IOCIE remains enabled for '6'

    ; Main loop: Handle delays when active
IDLE_LOOP:
    BTFSC   DELAY_ACTIVE,0; Check if delay active
    CALL    HANDLE_DELAY  ; Handle current delay state
    GOTO    IDLE_LOOP     ; Infinite loop, interrupts handle changes
    ; Total: ~33 words, starts at 0x0020

    END     resetVect