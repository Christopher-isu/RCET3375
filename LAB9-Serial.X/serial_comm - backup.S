;=================================================================
; MILESTONE_1_v1.6_ISR_FULLY_COMMENTED.ASM
; 4 MHz XT ? 250 Hz servo ? 0.5?2.5 ms ? ADC via ISR
;=================================================================
    PROCESSOR 16F883                 ; target device
    #include <xc.inc>                ; PIC-AS header ? required first line

;=================================================================
; CONFIGURATION BITS ? define MCU operating mode
;=================================================================
    CONFIG FOSC = XT                 ; use external 4 MHz crystal
    CONFIG WDTE = OFF                ; disable watchdog timer
    CONFIG PWRTE = OFF               ; disable power-up timer
    CONFIG MCLRE = ON                ; RA5 functions as reset pin
    CONFIG CP = OFF                  ; disable program memory code protection
    CONFIG CPD = OFF                 ; disable data EEPROM code protection
    CONFIG BOREN = OFF               ; disable brown-out reset
    CONFIG IESO = OFF                ; disable internal/external oscillator switch
    CONFIG FCMEN = OFF               ; disable fail-safe clock monitor
    CONFIG LVP = OFF                 ; disable low-voltage programming
    CONFIG WRT = OFF                 ; disable flash write protection
    CONFIG DEBUG = OFF               ; disable background debugger

;=================================================================
; RAM ? shared bank 0 (0x20?0x6F) ? accessible from any bank
;=================================================================
    PSECT udata_shr
SERVO_VAL: DS 1                     ; stores servo position byte from PC (0?255)
KEYWORD:   DS 1                     ; stores command byte (0x18 = echo, 0x81 = ADC)
ADC_HIGH:  DS 1                     ; holds upper 2 bits of 10-bit ADC result
ADC_LOW:   DS 1                     ; holds lower 8 bits of 10-bit ADC result

;=================================================================
; VECTORS ? fixed locations for reset and interrupt
;=================================================================
    PSECT resetVect,class=CODE,delta=2
    GOTO MAIN                       ; jump to start of program on reset

    PSECT isrVect,class=CODE,delta=2
    GOTO ADC_ISR                    ; jump to A/D interrupt handler

;=================================================================
; MAIN CODE SECTION ? program starts at 0x0020
;=================================================================
    PSECT code,class=CODE,delta=2

;=================================================================
; MAIN ? hardware initialization sequence
;=================================================================
MAIN:
    BANKSEL OSCCON                   ; select bank 1
    CLRF    OSCCON                   ; set oscillator to external 4 MHz crystal

    ;--- analog pin selection ---------------------------------------
    BANKSEL ANSEL                    ; select bank 1
    MOVLW   0x01                     ; set only AN0 as analog
    MOVWF   ANSEL                    ; AN1?AN7 remain digital
    BANKSEL ANSELH
    CLRF    ANSELH                   ; AN8?AN13 remain digital

    ;--- disable comparators ----------------------------------------
    BANKSEL CM1CON0                  ; select bank 3
    CLRF    CM1CON0                  ; turn off comparator 1
    CLRF    CM2CON0                  ; turn off comparator 2
    BANKSEL SRCON
    CLRF    SRCON                    ; disable SR latch

    ;--- I/O direction setup ----------------------------------------
    BANKSEL TRISA                    ; select bank 1
    BSF     TRISA,0                  ; RA0 = input for ADC

    BANKSEL TRISC                    ; select bank 1
    MOVLW   0b10000000               ; RC7 = input (RX), RC6 = output (TX)
    MOVWF   TRISC                    ; all other RC pins set as outputs

    BANKSEL PORTC                    ; select bank 0
    CLRF    PORTC                    ; clear all PORTC outputs (TX starts HIGH)

    ;--- UART configuration ? 9615 baud ----------------------------
    BANKSEL TXSTA                    ; select bank 1
    MOVLW   0b00100100               ; TX enable, high-speed mode
    MOVWF   TXSTA
    BANKSEL RCSTA
    MOVLW   0b10010000               ; enable UART, continuous receive
    MOVWF   RCSTA
    BANKSEL SPBRG
    MOVLW   25                       ; baud rate = 4 MHz / (16 × 25)
    MOVWF   SPBRG

    ;--- ADC configuration ------------------------------------------
    BANKSEL ADCON1                   ; select bank 1
    MOVLW   0b10000000               ; result right-justified
    MOVWF   ADCON1                   ; Tad = Fosc/16 = 4 µs
    BANKSEL ADCON0                   ; select bank 0
    MOVLW   0b01000001               ; select AN0, turn ADC on
    MOVWF   ADCON0

    ;--- PWM configuration ? 250 Hz, 4 ms frame --------------------
    BANKSEL PR2                      ; select bank 1
    MOVLW   249                      ; Timer2 period register
    MOVWF   PR2                      ; period = 250 counts
    BANKSEL T2CON
    MOVLW   0b00000111               ; Timer2 on, prescaler 1:16
    MOVWF   T2CON
    BANKSEL CCP1CON                  ; select bank 0
    MOVLW   0b00001100               ; enable PWM on RC2
    MOVWF   CCP1CON
    BANKSEL CCPR1L
    MOVLW   94                       ; initial duty = 94 counts ? 1.504 ms
    MOVWF   CCPR1L

    ;--- enable A/D interrupt ---------------------------------------
    BANKSEL PIE1                     ; select bank 1
    BSF     PIE1,6                   ; enable A/D conversion complete interrupt
    BANKSEL INTCON                   ; select bank 0
    BSF     INTCON,7                 ; enable all interrupts
    BSF     INTCON,6                 ; enable peripheral interrupts

;=================================================================
; MAIN LOOP ? runs forever
;=================================================================
LOOP:
    CALL    HANDSHAKE                ; wait for '$' handshake byte
    CALL    RX_LOOP                  ; receive servo and command bytes
    GOTO    LOOP                     ; repeat indefinitely

;=================================================================
; HANDSHAKE ? wait for ASCII '$' (0x24)
;=================================================================
HANDSHAKE:
    CALL    WAIT_RX                  ; wait for any received byte
    BANKSEL RCREG                    ; select bank 0
    MOVF    RCREG,W                  ; read received byte
    SUBLW   0x24                     ; subtract 0x24 from W
    BTFSS   STATUS,2                 ; skip if result is zero
    GOTO    HANDSHAKE                ; repeat until '$' received
    RETURN                           ; handshake complete

;=================================================================
; RX_LOOP ? receive two data bytes
;=================================================================
RX_LOOP:
    CALL    WAIT_RX                  ; wait for first byte
    BANKSEL RCREG
    MOVF    RCREG,W                  ; read servo position
    MOVWF   SERVO_VAL                ; store in RAM

    CALL    WAIT_RX                  ; wait for second byte
    BANKSEL RCREG
    MOVF    RCREG,W                  ; read command byte
    MOVWF   KEYWORD                  ; store in RAM
    CALL    PROCESS                  ; decode and act
    RETURN                           ; back to main loop

;=================================================================
; PROCESS ? interpret command and update hardware
;=================================================================
PROCESS:
    ;--- scale servo value to PWM duty -------------------------------
    MOVF    SERVO_VAL,W              ; load received servo byte
    MOVWF   CCPR1L                   ; write to PWM duty register
    ADDWF   CCPR1L,F                 ; multiply by 2
    MOVLW   31                       ; constant offset
    ADDWF   CCPR1L,F                 ; final duty = (byte×2)+31 ? 31?156 counts

    BANKSEL CCP1CON                  ; select bank 0
    BCF     CCP1CON,0                ; clear duty bit 0
    BCF     CCP1CON,1                ; clear duty bit 1

    MOVLW   0x24                     ; prepare handshake acknowledge
    CALL    SEND                     ; transmit '$'

    ;--- command dispatch -------------------------------------------
    MOVF    KEYWORD,W
    SUBLW   0b00011000               ; test for echo command
    BTFSC   STATUS,2
    GOTO    DO_ECHO

    MOVF    KEYWORD,W
    SUBLW   0b10000001               ; test for ADC command
    BTFSC   STATUS,2
    GOTO    DO_ADC

    RETURN                           ; unknown command ? ignore

DO_ECHO:
    MOVF    SERVO_VAL,W              ; retransmit servo byte
    CALL    SEND
    MOVF    KEYWORD,W                ; retransmit command byte
    CALL    SEND
    RETURN

DO_ADC:
    BANKSEL ADCON0                   ; select bank 0
    BSF     ADCON0,1                 ; set GO bit ? start conversion
    RETURN                           ; return immediately (ISR handles result)

;=================================================================
; A/D INTERRUPT ? runs when conversion finishes
;=================================================================
ADC_ISR:
    BANKSEL PIR1                     ; select bank 0
    BTFSS   PIR1,6                   ; test A/D interrupt flag
    RETFIE                           ; flag not set ? exit
    BCF     PIR1,6                   ; clear A/D interrupt flag

    BANKSEL ADRESH                   ; select bank 0
    MOVF    ADRESH,W                 ; read upper 2 bits
    MOVWF   ADC_HIGH                 ; store in RAM
    BANKSEL ADRESL
    MOVF    ADRESL,W                 ; read lower 8 bits
    MOVWF   ADC_LOW                  ; store in RAM

    BANKSEL 0                        ; ensure bank 0
    MOVF    ADC_HIGH,W
    CALL    SEND                     ; transmit high byte
    MOVF    ADC_LOW,W
    CALL    SEND                     ; transmit low byte
    RETFIE                           ; return from interrupt

;=================================================================
; WAIT_RX ? wait for received byte and clear errors
;=================================================================
WAIT_RX:
    BANKSEL PIR1                     ; select bank 0
    BTFSS   PIR1,5                   ; test receive interrupt flag
    GOTO    $-1                      ; loop until byte arrives
    BANKSEL RCSTA
    BTFSC   RCSTA,1                  ; test overrun error
    GOTO    CLR
    BTFSC   RCSTA,2                  ; test framing error
    GOTO    CLR
    RETURN                           ; byte valid ? return

CLR:
    BCF     RCSTA,4                  ; disable receiver
    BSF     RCSTA,4                  ; re-enable receiver
    BANKSEL RCREG
    MOVF    RCREG,W                  ; dummy read clears RCIF
    RETURN

;=================================================================
; SEND ? transmit one byte
;=================================================================
SEND:
    BTFSS   PIR1,4                   ; test transmit register empty
    GOTO    $-1                      ; loop until space available
    BANKSEL TXREG
    MOVWF   TXREG                    ; load byte into transmit register
    RETURN                           ; transmission started

    END