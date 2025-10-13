#include <xc.inc>

;=================================================================
; Device Configuration: Matches 4MHz oscillator and project setup
;=================================================================
    CONFIG  FOSC = XT         ; Use 4MHz external crystal oscillator
    CONFIG  WDTE = OFF        ; Disable Watchdog Timer
    CONFIG  PWRTE = OFF       ; Disable Power-up Timer
    CONFIG  MCLRE = ON        ; Enable MCLR pin
    CONFIG  CP = OFF          ; Disable code protection
    CONFIG  CPD = OFF         ; Disable EEPROM data protection
    CONFIG  BOREN = OFF       ; Disable Brown-out Reset
    CONFIG  IESO = OFF        ; Disable clock switchover
    CONFIG  FCMEN = OFF       ; Disable Fail-Safe Clock Monitor
    CONFIG  LVP = OFF         ; Disable low-voltage programming
    CONFIG  WRT = OFF         ; Disable Flash write protection

;=================================================================
; Data Memory: Shared RAM for ISR and timer delays
;=================================================================
    PSECT   udata_shr,class=COMMON,delta=1
W_TEMP:         DS  1         ; Save W register during interrupts
STATUS_TEMP:    DS  1         ; Save STATUS register during interrupts
TIMER0_COUNT:   DS  1         ; Timer0 overflow counter for '7' (~2000ms)
TIMER2_COUNT:   DS  1         ; Timer2 period counter for '6' (2000ms)
DELAY_7_DONE:   DS  1         ; Flag for '7' delay completion
DELAY_6_DONE:   DS  1         ; Flag for '6' delay completion
DELAY_7_ACTIVE: DS  1         ; Flag for '7' delay in progress
DELAY_6_ACTIVE: DS  1         ; Flag for '6' delay in progress
SAVED_6_COUNT:  DS  1         ; Saved Timer2 count for '6' interruption

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
    MOVWF   W_TEMP
    SWAPF   STATUS,W
    MOVWF   STATUS_TEMP
    GOTO    isrCode
    ; Total: 4 words, fits 0x0004?0x0007

;=================================================================
; ISR Logic: Placed at 0x0008 per -pisrCode=8h
;=================================================================
    PSECT   isrCode,class=CODE,delta=2
isrCode:
    BTFSC   INTCON,2      ; Check Timer0 overflow (T0IF)
    GOTO    HANDLE_T0     ; Handle Timer0 for '7'
    BTFSC   PIR1,1        ; Check Timer2 match (TMR2IF)
    GOTO    HANDLE_T2     ; Handle Timer2 for '6'
    BANKSEL PORTB
    MOVF    PORTB,W       ; Read PORTB to clear IOC mismatch
    BANKSEL INTCON
    BCF     INTCON,0      ; Clear IOC interrupt flag (RBIF)
    BTFSS   PORTB,0       ; Check RB0 (0=low, '7')
    GOTO    TRIGGER_7
    BTFSS   PORTB,1       ; Check RB1 (0=low, '6')
    GOTO    TRIGGER_6
    GOTO    ISR_EXIT      ; Both high: no action
TRIGGER_7:
    BTFSC   DELAY_7_ACTIVE,0 ; Skip if '7' not active
    GOTO    ISR_EXIT      ; Ignore duplicate '7'
    MOVF    DELAY_6_ACTIVE,W ; Check if '6' active
    BTFSS   STATUS,2      ; Skip if '6' not active (Z=1)
    GOTO    PAUSE_6       ; Pause '6' delay
    GOTO    START_7
PAUSE_6:
    MOVF    TIMER2_COUNT,W ; Save '6' count
    MOVWF   SAVED_6_COUNT
    CLRF    DELAY_6_ACTIVE ; Clear '6' active flag
    BANKSEL T2CON
    BCF     T2CON,2       ; Pause Timer2 (TMR2ON=0)
START_7:
    BANKSEL PORTC
    MOVLW   0x37          ; Load ASCII '7'
    MOVWF   PORTC         ; Display '7'
    BSF     DELAY_7_ACTIVE,0 ; Set '7' active flag
    MOVLW   31            ; Load 31 for ~2031.616ms
    MOVWF   TIMER0_COUNT
    BANKSEL INTCON
    BSF     INTCON,5      ; Enable Timer0 interrupts (T0IE)
    BANKSEL IOCB
    BCF     IOCB,1        ; Disable RB1 IOC
    GOTO    ISR_EXIT
TRIGGER_6:
    BTFSC   DELAY_7_ACTIVE,0 ; Skip if '7' not active
    GOTO    ISR_EXIT      ; Ignore '6' during '7'
    BTFSC   DELAY_6_ACTIVE,0 ; Skip if '6' not active
    GOTO    ISR_EXIT      ; Ignore duplicate '6'
    BANKSEL PORTC
    MOVLW   0x36          ; Load ASCII '6'
    MOVWF   PORTC         ; Display '6'
    BSF     DELAY_6_ACTIVE,0
    MOVLW   0xFA          ; Load 250 for 2000ms (500*4ms)
    MOVWF   TIMER2_COUNT
    BANKSEL T2CON
    MOVLW   0x7B          ; Timer2: on, no prescaler, 1:16 postscaler
    MOVWF   T2CON         ; Start Timer2
    GOTO    ISR_EXIT
HANDLE_T0:
    BCF     INTCON,2      ; Clear T0IF
    DECF    TIMER0_COUNT,F
    BTFSC   STATUS,2      ; Check if counter zero
    BSF     DELAY_7_DONE,0 ; Set '7' done flag
    GOTO    ISR_EXIT
HANDLE_T2:
    BANKSEL PIR1
    BCF     PIR1,1        ; Clear TMR2IF
    DECF    TIMER2_COUNT,F
    BTFSC   STATUS,2      ; Check if counter zero
    BSF     DELAY_6_DONE,0 ; Set '6' done flag
    GOTO    ISR_EXIT
ISR_EXIT:
    SWAPF   STATUS_TEMP,W
    MOVWF   STATUS
    SWAPF   W_TEMP,F
    SWAPF   W_TEMP,W
    RETFIE
    ; Total: 31 words, fits 0x0008?0x0026

;=================================================================
; Main Program: Placed at 0x0020 per -pcode=20h
;=================================================================
    PSECT   code,class=CODE,delta=2
MAIN:
    BANKSEL PORTC
    CLRF    PORTC         ; Clear PORTC
    BANKSEL TRISC
    CLRF    TRISC         ; PORTC as outputs (RC0?RC6)
    BSF     TRISB,0       ; RB0 as input
    BSF     TRISB,1       ; RB1 as input
    BANKSEL ANSELH
    BCF     ANSELH,4      ; RB0 digital (ANS12)
    BCF     ANSELH,2      ; RB1 digital (ANS10)
    BANKSEL OPTION_REG
    MOVLW   0x87          ; Timer0: 1:256 prescaler, no pull-ups
    MOVWF   OPTION_REG
    BANKSEL T2CON
    CLRF    T2CON         ; Timer2 off initially
    MOVLW   0xF9          ; PR2=249 for 4ms period
    MOVWF   PR2
    BANKSEL TMR0
    CLRF    TMR0          ; Clear Timer0
    BANKSEL IOCB
    BSF     IOCB,0        ; Enable RB0 IOC
    BSF     IOCB,1        ; Enable RB1 IOC
    BANKSEL PORTB
    MOVF    PORTB,W       ; Clear IOC mismatch
    BANKSEL INTCON
    BCF     INTCON,0      ; Clear RBIF
    BCF     INTCON,2      ; Clear T0IF
    BANKSEL PIR1
    BCF     PIR1,1        ; Clear TMR2IF
    BANKSEL INTCON
    BSF     INTCON,3      ; Enable IOCIE
    BSF     INTCON,5      ; Enable T0IE
    BANKSEL PIE1
    BSF     PIE1,1        ; Enable TMR2IE
    BANKSEL INTCON
    BSF     INTCON,7      ; Enable GIE
    CLRF    DELAY_7_ACTIVE
    CLRF    DELAY_6_ACTIVE
    CLRF    DELAY_7_DONE
    CLRF    DELAY_6_DONE
    CLRF    SAVED_6_COUNT

    ; Initialize display
    BANKSEL PORTB
    MOVF    PORTB,W
    BANKSEL INTCON
    BCF     INTCON,0      ; Clear RBIF
    BTFSS   PORTB,0
    GOTO    INIT_SET_7
    BTFSS   PORTB,1
    GOTO    INIT_SET_6
    MOVLW   0x31          ; Both high: '1'
    GOTO    INIT_OUTPUT
INIT_SET_7:
    MOVLW   0x37          ; RB0 low: '7'
    BSF     DELAY_7_ACTIVE,0
    MOVLW   31            ; ~2031.616ms
    MOVWF   TIMER0_COUNT
    BANKSEL INTCON
    BSF     INTCON,5      ; Enable T0IE
    BANKSEL IOCB
    BCF     IOCB,1        ; Disable RB1 IOC
    GOTO    INIT_OUTPUT
INIT_SET_6:
    MOVLW   0x36          ; RB1 low: '6'
    BSF     DELAY_6_ACTIVE,0
    MOVLW   0xFA          ; 250 for 2000ms
    MOVWF   TIMER2_COUNT
    BANKSEL T2CON
    MOVLW   0x7B          ; Timer2: on, no prescaler, 1:16 postscaler
    MOVWF   T2CON
INIT_OUTPUT:
    BANKSEL PORTC
    MOVWF   PORTC         ; Set initial display

IDLE_LOOP:
    BTFSC   DELAY_7_DONE,0
    GOTO    HANDLE_7_DONE
    BTFSC   DELAY_6_DONE,0
    GOTO    HANDLE_6_DONE
    BTFSC   DELAY_7_ACTIVE,0
    GOTO    IDLE_LOOP
    BTFSC   DELAY_6_ACTIVE,0
    GOTO    IDLE_LOOP
    GOTO    UPDATE_DISPLAY ; No active delays, update display
HANDLE_7_DONE:
    CLRF    DELAY_7_DONE
    CLRF    DELAY_7_ACTIVE
    BANKSEL INTCON
    BCF     INTCON,5      ; Disable T0IE
    BTFSC   SAVED_6_COUNT,0
    GOTO    RESUME_6
    GOTO    UPDATE_DISPLAY
HANDLE_6_DONE:
    CLRF    DELAY_6_DONE
    CLRF    DELAY_6_ACTIVE
    BANKSEL T2CON
    BCF     T2CON,2       ; Disable Timer2
    GOTO    UPDATE_DISPLAY
RESUME_6:
    BANKSEL PORTC
    MOVLW   0x36
    MOVWF   PORTC
    MOVF    SAVED_6_COUNT,W
    MOVWF   TIMER2_COUNT
    CLRF    SAVED_6_COUNT
    CLRF    DELAY_6_DONE
    BSF     DELAY_6_ACTIVE,0
    BANKSEL T2CON
    MOVLW   0x7B          ; Timer2: on, no prescaler, 1:16 postscaler
    MOVWF   T2CON
    GOTO    IDLE_LOOP
UPDATE_DISPLAY:
    BANKSEL IOCB
    BSF     IOCB,1        ; Re-enable RB1 IOC
    BANKSEL PORTB
    MOVF    PORTB,W
    BANKSEL INTCON
    BCF     INTCON,0      ; Clear RBIF
    BTFSS   PORTB,0
    GOTO    DISP_SET_7
    BTFSS   PORTB,1
    GOTO    DISP_SET_6
    MOVLW   0x31          ; Both high: '1'
    GOTO    DISP_OUTPUT
DISP_SET_7:
    MOVLW   0x37
    BSF     DELAY_7_ACTIVE,0
    MOVLW   31
    MOVWF   TIMER0_COUNT
    BANKSEL INTCON
    BSF     INTCON,5      ; Enable T0IE
    BANKSEL IOCB
    BCF     IOCB,1
    GOTO    DISP_OUTPUT
DISP_SET_6:
    MOVLW   0x36
    BSF     DELAY_6_ACTIVE,0
    MOVLW   0xFA
    MOVWF   TIMER2_COUNT
    BANKSEL T2CON
    MOVLW   0x7B
    MOVWF   T2CON
DISP_OUTPUT:
    BANKSEL PORTC
    MOVWF   PORTC
    GOTO    IDLE_LOOP
    ; Total: ~40 words, starts at 0x0020