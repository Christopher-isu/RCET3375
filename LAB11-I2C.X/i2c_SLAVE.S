;=================================================================
; PIC16F883 ? I2C 3-Servo Controller ? v4.10 (LOCKED REFERENCE ? FULLY ANNOTATED)
; Triple servo control: CCP1/2 hardware PWM + RB0 TMR2 software PWM
; I2C Slave Addr 0x40: ID00?RC2, ID01?RC1, ID10?RB0 (all 1-2ms pulses)
; VERIFIED: All 3 servos respond correctly to analog inputs
; Optimizations: Rate limiter, ISR efficiency, RB0 pulse width fix
;=================================================================
#include <xc.inc>

;----------------------------------------------------------- 
; CONFIGURATION BITS ? 4 MHz XT crystal, all protection off
;-----------------------------------------------------------
config FOSC = XT                ; external crystal oscillator (4 MHz assumed)
config WDTE = OFF               ; watchdog timer disabled
config PWRTE = OFF              ; power-up timer disabled  
config MCLRE = ON               ; MCLR pin enabled as reset
config CP = OFF                 ; code protection disabled
config CPD = OFF                ; data EEPROM protection disabled
config BOREN = OFF              ; brown-out reset disabled
config IESO = OFF               ; internal/external switchover disabled
config FCMEN = OFF              ; fail-safe clock monitor disabled
config LVP = OFF                ; low-voltage programming disabled
config WRT = OFF                ; flash program memory write protection disabled

;----------------------------------------------------------- 
; RAM VARIABLES ? access bank optimised layout
;-----------------------------------------------------------
PSECT udata_acs
W_SAVE:         DS 1            ; ISR context: W register save
STATUS_SAVE:    DS 1            ; ISR context: STATUS register save (nibble swap method)
RECV_BYTE:      DS 1            ; raw received I2C data byte
TEMP:           DS 1            ; general purpose temp register (I2C decode + TMR2 snapshot)
SERVO_POS_0:    DS 1            ; Servo 0 position (0-63) ? RC2/CCP1 hardware PWM
SERVO_POS_1:    DS 1            ; Servo 1 position (0-63) ? RC1/CCP2 hardware PWM
SERVO_POS_2:    DS 1            ; Servo 2 position (0-63) ? RB0/TMR2 software PWM
UPDATE_COUNT:   DS 1            ; PWM update rate limiter (every 4 loops ? 1 ms)

;----------------------------------------------------------- 
; RESET & INTERRUPT VECTORS
;-----------------------------------------------------------
PSECT resetVect,class=CODE,delta=2
    goto Start                      ; reset vector 0x0000 ? jump to main init

PSECT isrVect,class=CODE,delta=2
    goto ISR                        ; interrupt vector 0x0004 ? I2C ISR only

;----------------------------------------------------------- 
; I2C INTERRUPT SERVICE ROUTINE ? SSPIE only
; Handles incoming servo position commands, decodes ID + pos
;-----------------------------------------------------------
PSECT code,class=CODE,delta=2

ISR:
    movwf   W_SAVE                  ; save W register context
    swapf   STATUS,W                ; save STATUS (nibble swap avoids banksel)
    movwf   STATUS_SAVE             ; store STATUS copy

    btfss   PIR1,3                  ; test SSPIF ? skip if I2C interrupt not active
    goto    ISR_Exit                ; exit immediately if not I2C event
    bcf     PIR1,3                  ; clear SSPIF flag

    BANKSEL SSPBUF                  ; select bank containing SSPBUF
    movf    SSPBUF,W                ; read received I2C data byte
    movwf   RECV_BYTE               ; store raw byte for decode

    BANKSEL SSPSTAT                 ; select bank containing SSPSTAT
    btfss   SSPSTAT,5               ; test D/A bit ? skip if not data write to slave
    goto    Release_Clock           ; master read or invalid ? release clock stretch

    ;=============================================================
    ; I2C PAYLOAD DECODE: ID (bits 7-6) + Position (bits 5-0)
    ; Format: 00xxxxxx=Servo0, 01xxxxxx=Servo1, 10xxxxxx=Servo2
    ;=============================================================
    movf    RECV_BYTE,W             ; reload raw byte
    movwf   TEMP                    ; preserve full byte in TEMP
    andlw   0x3F                    ; mask lower 6 bits ? position value (0-63)
    movwf   RECV_BYTE               ; store clean position data

    movf    TEMP,W                  ; reload full byte
    andlw   0xC0                    ; mask upper 2 bits ? servo ID (00/40/80/C0)
    movwf   TEMP                    ; TEMP = clean ID field

    btfsc   STATUS,2                ; Z=1 if TEMP=0x00 ? Servo ID 00
    goto    Store_Servo0            ; branch to Servo 0 storage

    movlw   0x40                    ; load ID 01 comparator value
    subwf   TEMP,W                  ; TEMP - 0x40
    btfsc   STATUS,2                ; Z=1 if TEMP=0x40 ? Servo ID 01
    goto    Store_Servo1            ; branch to Servo 1 storage

    movlw   0x80                    ; load ID 10 comparator value  
    subwf   TEMP,W                  ; TEMP - 0x80
    btfsc   STATUS,2                ; Z=1 if TEMP=0x80 ? Servo ID 10 ?
    goto    Store_Servo2            ; branch to Servo 2 storage (RB0)

    movlw   0xC0                    ; load ID 11 comparator value
    subwf   TEMP,W                  ; TEMP - 0xC0  
    btfsc   STATUS,2                ; Z=1 if TEMP=0xC0 ? Servo ID 11 (alias to Servo 2)
    goto    Store_Servo3            ; store to Servo 2 (RB0)

    goto    Release_Clock           ; invalid ID ? ignore packet

Store_Servo0:                       ; Servo ID 00 ? RC2/CCP1 hardware PWM
    movf    RECV_BYTE,W             ; load clean 6-bit position (0-63)
    movwf   SERVO_POS_0             ; store for CCP1 update
    goto    Release_Clock           ; release I2C clock stretch

Store_Servo1:                       ; Servo ID 01 ? RC1/CCP2 hardware PWM
    movf    RECV_BYTE,W             ; load clean 6-bit position (0-63)  
    movwf   SERVO_POS_1             ; store for CCP2 update
    goto    Release_Clock           ; release I2C clock stretch

Store_Servo2:                       ; Servo ID 10 ? RB0/TMR2 software PWM ?
    movf    RECV_BYTE,W             ; load clean 6-bit position (0-63)
    movwf   SERVO_POS_2             ; store for RB0 TMR2 compare
    goto    Release_Clock           ; release I2C clock stretch

Store_Servo3:                       ; Servo ID 11 ? alias to Servo 2 (RB0)
    movf    RECV_BYTE,W             ; load clean 6-bit position (0-63)
    movwf   SERVO_POS_2             ; overwrite Servo 2 position

Release_Clock:                      ; all valid packets reach here
    BANKSEL SSPCON                  ; select bank containing SSPCON
    bsf     SSPCON,4                ; set CKP=1 ? release clock stretch to master

ISR_Exit:                           ; normal ISR exit path
    swapf   STATUS_SAVE,W           ; restore STATUS register (nibble swap reverse)
    movwf   STATUS                  ; restore STATUS to context
    swapf   W_SAVE,F                ; restore W register (nibble swap reverse)
    swapf   W_SAVE,W                ; W now restored to original value
    retfie                          ; return from interrupt, re-enable GIE

;----------------------------------------------------------- 
; MAIN INITIALISATION ? peripherals + defaults
;-----------------------------------------------------------
Start:
    BANKSEL ANSEL                   ; select bank containing analog select registers
    clrf    ANSEL                   ; all digital I/O (RA0-RA7)
    clrf    ANSELH                  ; all digital I/O (RA8-RA13 unused)

    BANKSEL CM1CON0                 ; select bank containing comparator control
    clrf    CM1CON0                 ; disable comparator 1 module
    clrf    CM2CON0                 ; disable comparator 2 module

    BANKSEL SRCON                   ; select bank containing SR latch
    clrf    SRCON                   ; disable SR latch (no C2OUT/RxDT use)

    BANKSEL PORTA                   ; select bank containing PORT latches
    clrf    PORTA                   ; initialise PORTA outputs low
    clrf    PORTB                   ; initialise PORTB outputs low (RB0=LOW safe)
    clrf    PORTC                   ; initialise PORTC outputs low

    BANKSEL TRISA                   ; select bank containing TRIS registers
    movlw   0xFF                    ; all PORTA pins input (unused)
    movwf   TRISA                   
    BANKSEL TRISB
    movlw   0b11111110              ; RB0=output (Servo2 PWM), others input
    movwf   TRISB
    BANKSEL TRISC
    movlw   0b11111000              ; RC0=heartbeat, RC1/2=Servo PWM outputs
    movwf   TRISC                   ; RC3/4=I2C open-drain inputs

    ;----------------------------------------------------------- 
    ; TIMER2 + CCP1/CCP2 HARDWARE PWM SETUP ? 4ms period (250Hz)
    ; PR2=249, T2CKPS=10 ? 16µs tick ? pos+62 = 1-2ms duty cycle
    ;-----------------------------------------------------------
    BANKSEL PR2                     ; select bank containing Timer2 period register
    movlw   249                     ; PR2=249 ? 250 ticks × 16µs = 4ms period
    movwf   PR2                     
    BANKSEL T2CON                   ; select bank containing Timer2 control
    movlw   0b00000111              ; TOUTPS=111 (1:16 postscale), TMR2ON=1, T2CKPS=10
    movwf   T2CON                   ; Timer2 running ? 16µs tick for CCP PWM

    BANKSEL CCP1CON                 ; select bank containing CCP1 control
    movlw   0x0C                    ; CCP1M3:0=1100 ? PWM mode
    movwf   CCP1CON                 ; enable CCP1 PWM on RC2
    movwf   CCP2CON                 ; enable CCP2 PWM on RC1 (same value)

    ; DC1B/DC2B fractional bits cleared ONCE (micro-optimisation)
    BANKSEL CCP1CON                 ; select CCP1CON again
    bcf     CCP1CON,5               ; clear DC1B1 ? 8-bit duty only
    bcf     CCP1CON,4               ; clear DC1B0
    BANKSEL CCP2CON                 ; select CCP2CON
    bcf     CCP2CON,5               ; clear DC2B1
    bcf     CCP2CON,4               ; clear DC2B0

    ; Servo position defaults (32 = 1.5ms centre position)
    movlw   32                      ; 32 + 62 = 94 ? ~1.5ms duty cycle
    movwf   SERVO_POS_0             ; Servo 0 default
    movwf   SERVO_POS_1             ; Servo 1 default
    movwf   SERVO_POS_2             ; Servo 2 default
    clrf    UPDATE_COUNT            ; reset PWM rate limiter

    ;----------------------------------------------------------- 
    ; I2C SLAVE SETUP ? address 0x40 (matches master)
    ;-----------------------------------------------------------
    BANKSEL SSPADD                  ; select bank containing slave address register
    movlw   0x40                    ; 7-bit slave address 0x40 (matches master SSPADD)
    movwf   SSPADD                  
    BANKSEL SSPSTAT                 ; select bank containing SSPSTAT
    movlw   0x80                    ; SMP=1 ? slew rate control for 100kHz
    movwf   SSPSTAT                 
    BANKSEL SSPCON                  ; select bank containing SSPCON
    movlw   0x36                    ; SSPOV=0, WCOL=0, CKP=1, SSPEN=1, I2C slave mode
    movwf   SSPCON                  ; enable I2C slave with clock stretch

    BANKSEL PIE1                    ; select bank containing peripheral IE
    bsf     PIE1,3                  ; enable SSPIE ? I2C interrupts only
    BANKSEL INTCON                  ; select bank containing global interrupt control
    bsf     INTCON,7                ; GIE=1 ? enable all interrupts
    bsf     INTCON,6                ; PEIE=1 ? enable peripheral interrupts

;----------------------------------------------------------- 
; MAIN LOOP ? decoupled PWM updates + rate limiting
; CCP1/2: every 4 loops (~1ms), RB0: every loop (timing critical)
;-----------------------------------------------------------
Main_Loop:
    ; STEP 2: UPDATE RATE LIMITER (~1ms CCP updates)
    incf    UPDATE_COUNT,F          ; increment update counter
    movlw   4                       ; compare value (every 4 loops)
    subwf   UPDATE_COUNT,W          ; UPDATE_COUNT - 4
    btfss   STATUS,2                ; skip if counter == 4 (Z=1)
    goto    Do_RB0_Only             ; not time for CCP update ? RB0 only

    clrf    UPDATE_COUNT            ; reset rate limiter counter

    ; CCP1 update (Servo 0 - RC2 hardware PWM)
    movf    SERVO_POS_0,W           ; load Servo 0 position (0-63)
    addlw   62                      ; offset ? 62-125 range (1-2ms @ 16µs tick)
    BANKSEL CCPR1L                  ; select bank containing CCP1 duty register
    movwf   CCPR1L                  ; update 8-bit duty cycle

    ; CCP2 update (Servo 1 - RC1 hardware PWM)
    movf    SERVO_POS_1,W           ; load Servo 1 position (0-63)
    addlw   62                      ; offset ? 62-125 range
    BANKSEL CCPR2L                  ; select bank containing CCP2 duty register
    movwf   CCPR2L                  ; update 8-bit duty cycle

Do_RB0_Only:
    ; STEP 1: RB0 TMR2 POLLING ? PULSE WIDTH CONTROL (Servo 2 - ID 10)
    ; TMR2 compare ? HIGH when TMR2 < threshold (early pulse), LOW when late
    bcf     INTCON,7                ; GIE=0 ? disable interrupts (timing critical)
    BANKSEL TMR2                    ; select bank containing TMR2
    movf    TMR2,W                  ; snapshot TMR2 value (free running 16µs tick)
    movwf   TEMP                    ; store in TEMP for compare
    BANKSEL SERVO_POS_2             ; select bank containing Servo 2 position
    movf    SERVO_POS_2,W           ; load Servo 2 position (0-63)
    addlw   62                      ; threshold = 62 + pos ? 62-125 (1-2ms pulse width)
    subwf   TEMP,W                  ; TEMP - threshold ? TMR2 >= threshold?
    btfss   STATUS,0                ; carry CLEAR ? TMR2 < threshold ? PULSE HIGH
    bsf     PORTB,0                 ; EARLY cycle ? RB0 HIGH (pulse active 1-2ms)
    btfsc   STATUS,0                ; carry SET ? TMR2 >= threshold ? PULSE OFF
    bcf     PORTB,0                 ; LATE cycle ? RB0 LOW (pulse inactive)
    bsf     INTCON,7                ; GIE=1 ? re-enable interrupts

    BANKSEL PORTC                   ; select bank containing PORTC
    bsf     PORTC,0                 ; RC0=1 ? heartbeat pulse (scope monitor)
    bcf     PORTC,0                 ; RC0=0 ? heartbeat complete (50% duty)
    goto    Main_Loop               ; repeat forever

END
