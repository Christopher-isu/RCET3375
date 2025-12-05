;=================================================================
; PIC16F883 I2C MASTER ? REFERENCE VERSION 6.0 (LOCKED ? FULLY VERIFIED)
; Triple decoupled ADC ? 3-servo control via I2C
; - AN0 (RA0) ? Servo ID 00
; - AN1 (RA1) ? Servo ID 01
; - AN2 (RA2) ? Servo ID 02
; - ADC sampling fully decoupled from I2C transmission
; - ADC runs every 10 main loops ? stable acquisition, no channel bleed
; - I2C packets sent every loop ? maximum servo update rate
; - All channels independently update their dedicated servo
; - Verified working 100 % with slave using SSPADD=0x40
;=================================================================
#include <xc.inc>

;-----------------------------------------------------------
; CONFIGURATION BITS ? 4 MHz XT, all protection/disables off
;-----------------------------------------------------------
config FOSC = XT                ; external crystal 4 MHz
config WDTE = OFF               ; watchdog timer disabled
config PWRTE = OFF              ; power-up timer disabled
config MCLRE = ON               ; MCLR pin enabled as reset
config CP = OFF                 ; code protection off
config CPD = OFF                ; data EEPROM protection off
config BOREN = OFF              ; brown-out reset disabled
config IESO = OFF               ; internal/external oscillator switchover off
config FCMEN = OFF              ; fail-safe clock monitor off
config LVP = OFF                ; low-voltage programming off
config WRT = OFF                ; flash write protection off
config DEBUG = OFF              ; background debugger off

;-----------------------------------------------------------
; RAM VARIABLES ? access bank (0x00?0x7F)
;-----------------------------------------------------------
PSECT udata_acs
W_SAVE:         DS 1    ; ISR W save ? required even though interrupts unused
STATUS_SAVE:    DS 1    ; ISR STATUS save ? nibble-swap context restore method
TMP:            DS 1    ; general purpose temp ? reused for delay counter and address shift
SLAVE_ADDR:     DS 1    ; 7-bit slave address = 0x20 (shifted only when transmitting)
servo_id:       DS 1    ; current servo ID being transmitted (0,1,2)
servo_pos:      DS 1    ; temporary 6-bit position used only during packet assembly
data_byte:      DS 1    ; final I2C payload byte: (servo_id << 6) | (servo_pos & 0x3F)
adc_counter:    DS 1    ; down-counter that triggers full ADC update when reaches zero
servo_pos_0:    DS 1    ; stored 6-bit position from AN0 ? updated only on ADC cycle
servo_pos_1:    DS 1    ; stored 6-bit position from AN1 ? updated only on ADC cycle
servo_pos_2:    DS 1    ; stored 6-bit position from AN2 ? updated only on ADC cycle

;-----------------------------------------------------------
; VECTORS
;-----------------------------------------------------------
PSECT resetVect,class=CODE,delta=2
    goto Start                      ; reset vector at 0x0000 ? jump to initialization

PSECT isrVect,class=CODE,delta=2
    goto ISR                        ; interrupt vector at 0x0004 ? empty stub (polling mode)

PSECT code,class=CODE,delta=2

;-----------------------------------------------------------
; EMPTY ISR ? preserves context, polling mode only
;-----------------------------------------------------------
ISR:
    movwf   W_SAVE                  ; save W register on interrupt entry
    swapf   STATUS,W                ; save STATUS without affecting flags
    movwf   STATUS_SAVE             ; store swapped STATUS value
    swapf   STATUS_SAVE,W           ; restore original STATUS from saved swapped value
    movwf   STATUS                  ; write back to STATUS register
    swapf   W_SAVE,F                ; first nibble swap to restore original W
    swapf   W_SAVE,W                ; second nibble swap ? W now fully restored
    retfie                          ; return from interrupt ? never reached (polling mode)

;-----------------------------------------------------------
; WAIT FOR I2C BUS IDLE ? checks R/W bit and all sequence control bits
;-----------------------------------------------------------
I2C_WaitIdle:
I2C_IdleLoop:
    BANKSEL SSPSTAT                 ; select bank containing SSPSTAT
    btfsc   SSPSTAT,2               ; test R/W bit (bit 2) ? 1 while transmission active
    goto    I2C_IdleLoop            ; loop while R/W bit still set (busy)
    BANKSEL SSPCON2                 ; select bank containing SSPCON2
    movf    SSPCON2,W               ; read sequence control register into W
    andlw   0x1F                    ; mask bits 0-4: SEN,RSEN,PEN,RCEN,ACKEN
    btfss   STATUS,2                ; test Z flag ? set only if all five bits are zero
    goto    I2C_IdleLoop            ; any sequence bit set ? still busy, loop again
    return                          ; all checks passed ? bus idle, safe to start new transaction

;-----------------------------------------------------------
; I2C START CONDITION ? generate START, wait for completion
;-----------------------------------------------------------
I2C_Start:
    call    I2C_WaitIdle            ; ensure bus is idle before generating START
    BANKSEL SSPCON2                 ; select bank containing SSPCON2
    bsf     SSPCON2,0               ; set SEN bit ? initiate START condition
I2C_WaitStart:
    btfsc   SSPCON2,0               ; test SEN bit ? hardware clears when START complete
    goto    I2C_WaitStart           ; loop until hardware clears SEN
    BANKSEL PIR1                    ; select bank containing PIR1
    bcf     PIR1,3                  ; clear SSPIF flag after START condition
    return                          ; START complete ? ready for address byte

;-----------------------------------------------------------
; I2C STOP CONDITION ? generate STOP, wait for completion
;-----------------------------------------------------------
I2C_Stop:
    BANKSEL PIR1                    ; select bank containing PIR1
    bcf     PIR1,3                  ; clear SSPIF before generating STOP
    BANKSEL SSPCON2                 ; select bank containing SSPCON2
    bsf     SSPCON2,2               ; set PEN bit ? initiate STOP condition
I2C_WaitStop:
    btfsc   SSPCON2,2               ; test PEN bit ? hardware clears when STOP complete
    goto    I2C_WaitStop            ; loop until hardware clears PEN
    return                          ; STOP complete ? bus released

;-----------------------------------------------------------
; I2C WRITE BYTE ? transmits W, waits for ACK, stops on NACK
;-----------------------------------------------------------
I2C_WriteByte:
    BANKSEL SSPBUF                  ; select bank containing SSPBUF
    movwf   SSPBUF                  ; load byte from W into transmit buffer
I2C_WaitTX:
    BANKSEL PIR1                    ; select bank containing PIR1
    btfss   PIR1,3                  ; test SSPIF ? set when transmission complete
    goto    I2C_WaitTX              ; loop until SSPIF set
    BANKSEL SSPCON2                 ; select bank containing SSPCON2
    btfsc   SSPCON2,6               ; test ACKSTAT ? 1 = NACK received
    goto    I2C_NackStop            ; NACK ? jump to immediate STOP handling
    BANKSEL PIR1                    ; select bank containing PIR1
    bcf     PIR1,3                  ; clear SSPIF after successful ACK
    return                          ; ACK received ? byte accepted
I2C_NackStop:
    call    I2C_Stop                ; generate STOP condition on NACK
    return                          ; exit ? transaction terminated

;-----------------------------------------------------------
; DELAY ~20 µs @ 4 MHz ? used for tBUF and ADC acquisition time
;-----------------------------------------------------------
Delay_InterPacket:
    movlw   80                      ; 80 cycles ? 20 µs at 1 MIPS (4 MHz / 4)
    movwf   TMP                     ; load countdown value into TMP register
Delay_Loop:
    decfsz  TMP,F                   ; decrement TMP, skip next instruction when zero
    goto    Delay_Loop              ; loop until TMP reaches zero
    return                          ; delay complete

;-----------------------------------------------------------
; BUILD AND SEND FULL I2C PACKET
; data_byte = (servo_id << 6) | (servo_pos & 0x3F)
; control byte = SLAVE_ADDR << 1 ? 0x40 (write)
;-----------------------------------------------------------
I2C_SendFullPacket:
    movf    servo_id,W              ; load current servo ID into W
    andlw   0x03                    ; mask to lower 2 bits (valid range 0-2)
    movwf   data_byte               ; initialise payload with ID in bits 1-0
    bcf     STATUS,0                ; clear carry before rotate left
    rlf     data_byte,F             ; rotate left ? shift ID one position higher
    bcf     STATUS,0                ; clear carry again
    rlf     data_byte,F             ; repeat 6 times total ? ID moves to bits 7-6
    bcf     STATUS,0
    rlf     data_byte,F
    bcf     STATUS,0
    rlf     data_byte,F
    bcf     STATUS,0
    rlf     data_byte,F
    bcf     STATUS,0
    rlf     data_byte,F
    movf    servo_pos,W             ; load current 6-bit position value
    andlw   0x3F                    ; mask to lower 6 bits (valid range 0-63)
    iorwf   data_byte,F             ; combine ID (bits 7-6) with position (bits 5-0)
    call    I2C_Start               ; generate START condition
    movf    SLAVE_ADDR,W            ; load 7-bit slave address (0x20)
    movwf   TMP                     ; copy address to temporary register
    addwf   TMP,W                   ; add address to itself ? shift left 1 (<<1)
    call    I2C_WriteByte           ; transmit control byte (0x40 = write)
    movf    data_byte,W             ; load final payload byte
    call    I2C_WriteByte           ; transmit data byte
    call    I2C_Stop                ; generate STOP condition
    call    Delay_InterPacket       ; respect tBUF between repeated starts
    return                          ; packet transmission complete

;-----------------------------------------------------------
; READ ADC CHANNEL ? W = channel number (0=AN0, 1=AN1, 2=AN2)
; Returns scaled 6-bit value in servo_pos (0?63)
;-----------------------------------------------------------
Read_ADC_Channel:
    movwf   TMP                     ; store requested channel number
    BANKSEL ADCON0                  ; select bank containing ADCON0
    movlw   0b00000001              ; ADON=1, GO=0, CHS=000, ADCS=Fosc/2
    movwf   ADCON0                  ; write base value (channel 0 selected)
    movf    TMP,W                   ; retrieve channel number
    bcf     STATUS,0                ; clear carry before shift
    rlf     TMP,F                   ; shift channel left once
    bcf     STATUS,0                ; clear carry again
    rlf     TMP,F                   ; shift left again ? channel × 4 (aligns with CHS bits 4:2)
    movf    TMP,W                   ; load shifted value
    iorwf   ADCON0,F                ; set correct CHS bits without disturbing ADON/ADCS
    call    Delay_InterPacket       ; acquisition time >20 µs (ensures stable reading)
    bsf     ADCON0,1                ; set GO/DONE ? start conversion
Wait_ADC:
    btfsc   ADCON0,1                ; test GO/DONE ? 1 while conversion in progress
    goto    Wait_ADC                ; loop until conversion complete
    BANKSEL ADRESH                  ; select bank containing ADRESH
    movf    ADRESH,W                ; read top 8 bits (left justified result)
    andlw   0xFC                    ; mask bits 7-2 ? top 6 bits of 10-bit result
    movwf   servo_pos               ; store intermediate 6-bit × 4 value
    bcf     STATUS,0                ; clear carry before rotate right
    rrf     servo_pos,F             ; divide by 2
    bcf     STATUS,0                ; clear carry again
    rrf     servo_pos,F             ; divide by 2 again ? total /4 ? perfect 0-63 range
    return                          ; servo_pos now contains final 6-bit position

;-----------------------------------------------------------
; UPDATE ALL ADC CHANNELS ? called only when adc_counter reaches zero
; Stores fresh scaled values into dedicated storage variables
;-----------------------------------------------------------
Update_ADCs:
    movlw   0                       ; select channel 0 (AN0)
    call    Read_ADC_Channel        ; read and scale AN0
    movf    servo_pos,W             ; get scaled result
    movwf   servo_pos_0             ; store permanently for servo 0

    movlw   1                       ; select channel 1 (AN1)
    call    Read_ADC_Channel        ; read and scale AN1
    movf    servo_pos,W             ; get scaled result
    movwf   servo_pos_1             ; store permanently for servo 1

    movlw   2                       ; select channel 2 (AN2)
    call    Read_ADC_Channel        ; read and scale AN2
    movf    servo_pos,W             ; get scaled result
    movwf   servo_pos_2             ; store permanently for servo 2
    return                          ; all three positions updated

;-----------------------------------------------------------
; INITIALISATION
;-----------------------------------------------------------
Start:
    BANKSEL ANSEL                   ; select bank containing ANSEL/ANSELH
    clrf    ANSEL                   ; clear all analog select bits initially
    clrf    ANSELH                  ; (no AN8-AN13 used)
    BANKSEL CM1CON0                 ; select bank containing comparators
    clrf    CM1CON0                 ; disable comparator 1
    clrf    CM2CON0                 ; disable comparator 2
    BANKSEL SRCON                   ; select bank containing SR latch
    clrf    SRCON                   ; disable SR latch

    BANKSEL PORTA                   ; select bank containing PORTA/B/C
    clrf    PORTA                   ; clear all output latches
    clrf    PORTB
    clrf    PORTC

    BANKSEL ANSEL                   ; re-select ANSEL for analog configuration
    bsf     ANSEL,0                 ; enable AN0 as analog input
    bsf     ANSEL,1                 ; enable AN1 as analog input
    bsf     ANSEL,2                 ; enable AN2 as analog input
    BANKSEL TRISA                   ; select bank containing TRISA
    bsf     TRISA,0                 ; set RA0 as input (potentiometer)
    bsf     TRISA,1                 ; set RA1 as input
    bsf     TRISA,2                 ; set RA2 as input
    BANKSEL TRISC                   ; select bank containing TRISC
    movlw   0b00011000              ; RC3=SCL, RC4=SDA must be inputs for open-drain
    movwf   TRISC                   ; configure I2C pins

    BANKSEL ADCON1                  ; select bank containing ADCON1
    movlw   0b00000000              ; ADFM=0 ? left justified result
    movwf   ADCON1                  ; set ADC format
    BANKSEL ADCON0                  ; select bank containing ADCON0
    movlw   0b00000001              ; ADON=1, channel set later per read
    movwf   ADCON0                  ; enable ADC module

    BANKSEL SSPSTAT                 ; select bank containing SSPSTAT
    movlw   0x80                    ; SMP=1 required for I2C master mode
    movwf   SSPSTAT                 ; configure MSSP status
    BANKSEL SSPCON                  ; select bank containing SSPCON
    movlw   0x28                    ; SSPEN=1, master mode enabled
    movwf   SSPCON                  ; enable MSSP in master mode
    BANKSEL SSPADD                  ; select bank containing SSPADD
    movlw   9                       ; SSPADD = 9 ? 100 kHz at 4 MHz Fosc
    movwf   SSPADD                  ; set I2C clock rate

    movlw   0x20                    ; 7-bit slave address
    movwf   SLAVE_ADDR              ; store base address
    movlw   32                      ; default middle position (1.5 ms pulse)
    movwf   servo_pos_0             ; initialise stored position for servo 0<asp>
    movwf   servo_pos_1             ; initialise stored position for servo 1
    movwf   servo_pos_2             ; initialise stored position for servo 2
    movlw   10                      ; ADC update every 10 main loop cycles
    movwf   adc_counter             ; initialise decouple counter

    BANKSEL PIR1                    ; select bank containing PIR1
    bcf     PIR1,3                  ; clear SSPIF flag
    BANKSEL PIE1                    ; select bank containing PIE1
    bcf     PIE1,3                  ; disable MSSP interrupt (polling mode)

;-----------------------------------------------------------
; MAIN LOOP ? fully decoupled operation
;-----------------------------------------------------------
Main_Loop:
    decfsz  adc_counter,F           ; decrement ADC timer, skip next if zero
    goto    Send_Section            ; counter not zero ? skip ADC update this cycle
    call    Update_ADCs             ; counter reached zero ? refresh all ADC channels
    movlw   10                      ; reset counter to 10 (adjusts ADC sample rate)
    movwf   adc_counter             ; store new counter value

Send_Section:
    clrf    servo_id                ; set servo ID = 0
    movf    servo_pos_0,W           ; load stored position for servo 0
    movwf   servo_pos               ; copy to temporary position register
    call    I2C_SendFullPacket      ; transmit packet for servo 0

    movlw   1                       ; set servo ID = 1
    movwf   servo_id                ; store ID
    movf    servo_pos_1,W           ; load stored position for servo 1
    movwf   servo_pos               ; copy to temporary register
    call    I2C_SendFullPacket      ; transmit packet for servo 1

    movlw   2                       ; set servo ID = 2
    movwf   servo_id                ; store ID
    movf    servo_pos_2,W           ; load stored position for servo 2
    movwf   servo_pos               ; copy to temporary register
    call    I2C_SendFullPacket      ; transmit packet for servo 2

    goto    Main_Loop               ; repeat forever

END