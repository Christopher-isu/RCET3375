;===========================================================
; PIC16F883 I2C MASTER ? STEP 2: SINGLE ADC CONTROL FOR SERVO 0
; - AN0 (RA0) potentiometer ? 10-bit ADC ? scaled to 6-bit (0?63)
; - servo_id fixed to 0 ? data byte = [00xxxxxx]
; - Sends continuously: [START][0x40][data][STOP] ? slave sees address 0x20 + W, data ID=00
; - Fully compatible with your confirmed working slave (SSPADD=0x40, SSPCON=0x36)
;===========================================================
#include <xc.inc>

;-----------------------------------------------------------
; CONFIGURATION BITS ? 4MHz XT, all protection/disables off
;-----------------------------------------------------------
config FOSC = XT
config WDTE = OFF
config PWRTE = OFF
config MCLRE = ON
config CP = OFF
config CPD = OFF
config BOREN = OFF
config IESO = OFF
config FCMEN = OFF
config LVP = OFF
config WRT = OFF
config DEBUG = OFF

;-----------------------------------------------------------
; RAM VARIABLES ? access bank
;-----------------------------------------------------------
PSECT udata_acs
W_SAVE:         DS 1    ; ISR W save ? unused but required for context save
STATUS_SAVE:    DS 1    ; ISR STATUS save ? nibble swap method
TMP:            DS 1    ; general temp ? reused for delay counter and address shift
SLAVE_ADDR:     DS 1    ; 7-bit base address = 0x20 (shifted only at transmit time)
servo_id:       DS 1    ; 2-bit servo ID ? fixed 0 for this step
servo_pos:      DS 1    ; 6-bit position value from ADC (0?63)
data_byte:      DS 1    ; final packet byte: (servo_id<<6) | (servo_pos & 0x3F)
adc_temp:       DS 2    ; temporary storage for ADRESH:ADRESL if needed (currently unused)

;-----------------------------------------------------------
; VECTORS
;-----------------------------------------------------------
PSECT resetVect,class=CODE,delta=2
    goto Start                      ; reset vector
PSECT isrVect,class=CODE,delta=2
    goto ISR                        ; interrupt vector (empty ? polling mode)

PSECT code,class=CODE,delta=2

;-----------------------------------------------------------
; EMPTY ISR ? preserves context, no MSSP interrupt used
;-----------------------------------------------------------
ISR:
    movwf   W_SAVE                  ; save W
    swapf   STATUS,W                ; save STATUS without affecting flags
    movwf   STATUS_SAVE
    swapf   STATUS_SAVE,W           ; restore STATUS
    movwf   STATUS
    swapf   W_SAVE,F                ; restore W (nibble swap twice)
    swapf   W_SAVE,W
    retfie                          ; return from interrupt

;-----------------------------------------------------------
; I2C BUS IDLE WAIT ? checks R/W bit and all sequence bits clear
;-----------------------------------------------------------
I2C_WaitIdle:
I2C_IdleLoop:
    BANKSEL SSPSTAT
    btfsc   SSPSTAT,2               ; bit2 = R/W active during transmission
    goto    I2C_IdleLoop
    BANKSEL SSPCON2
    movf    SSPCON2,W
    andlw   0x1F                    ; mask SEN,RSEN,PEN,RCEN,ACKEN
    btfss   STATUS,2                ; Z=1 only if all zero ? idle
    goto    I2C_IdleLoop
    return                          ; bus idle

;-----------------------------------------------------------
; I2C START CONDITION ? set SEN, wait clear, clear SSPIF
;-----------------------------------------------------------
I2C_Start:
    call    I2C_WaitIdle            ; ensure bus free
    BANKSEL SSPCON2
    bsf     SSPCON2,0               ; SEN=1 ? generate START
I2C_WaitStart:
    btfsc   SSPCON2,0               ; wait until hardware clears SEN
    goto    I2C_WaitStart
    BANKSEL PIR1
    bcf     PIR1,3                  ; clear SSPIF after START
    return

;-----------------------------------------------------------
; I2C STOP CONDITION ? clear flag first, set PEN, wait clear
;-----------------------------------------------------------
I2C_Stop:
    BANKSEL PIR1
    bcf     PIR1,3                  ; clear SSPIF before generating STOP
    BANKSEL SSPCON2
    bsf     SSPCON2,2               ; PEN=1 ? generate STOP
I2C_WaitStop:
    btfsc   SSPCON2,2               ; wait until hardware clears PEN
    goto    I2C_WaitStop
    return

;-----------------------------------------------------------
; I2C WRITE BYTE ? W contains byte, stops on NACK
;-----------------------------------------------------------
I2C_WriteByte:
    BANKSEL SSPBUF
    movwf   SSPBUF                  ; load byte into buffer
I2C_WaitTX:
    BANKSEL PIR1
    btfss   PIR1,3                  ; wait for SSPIF = transmission complete
    goto    I2C_WaitTX
    BANKSEL SSPCON2
    btfsc   SSPCON2,6               ; ACKSTAT=1 ? NACK received
    goto    I2C_NackStop
    BANKSEL PIR1
    bcf     PIR1,3                  ; clear flag after successful ACK
    return
I2C_NackStop:
    call    I2C_Stop                ; immediate STOP on NACK
    return

;-----------------------------------------------------------
; ~10µs delay @4MHz ? reused for tBUF and ADC acquisition
;-----------------------------------------------------------
Delay_InterPacket:
    movlw   40                      ; 40 cycles ? 10µs at 1MIPS
    movwf   TMP
Delay_Loop:
    decfsz  TMP,F
    goto    Delay_Loop
    return

;-----------------------------------------------------------
; BUILD AND SEND FULL PACKET
; data_byte = (servo_id << 6) | (servo_pos & 0x3F)
; control byte = SLAVE_ADDR << 1 | 0 ? 0x40
;-----------------------------------------------------------
I2C_SendFullPacket:
    movf    servo_id,W
    andlw   0x03                    ; mask to 2 bits
    movwf   data_byte               ; start with ID in low bits
    bcf     STATUS,0                ; clear carry before rotate
    rlf     data_byte,F             ; ×2
    bcf     STATUS,0
    rlf     data_byte,F             ; ×4
    bcf     STATUS,0
    rlf     data_byte,F             ; ×8
    bcf     STATUS,0
    rlf     data_byte,F             ; ×16
    bcf     STATUS,0
    rlf     data_byte,F             ; ×32
    bcf     STATUS,0
    rlf     data_byte,F             ; ×64 ? ID now in bits 7-6
    movf    servo_pos,W
    andlw   0x3F                    ; mask position to 6 bits
    iorwf   data_byte,F             ; combine ? final data byte ready

    call    I2C_Start
    movf    SLAVE_ADDR,W            ; W = 0x20
    movwf   TMP
    addwf   TMP,W                   ; W = 0x20 + 0x20 = 0x40 (<<1)
    call    I2C_WriteByte           ; send control byte 0x40
    movf    data_byte,W
    call    I2C_WriteByte           ; send data payload
    call    I2C_Stop
    call    Delay_InterPacket       ; respect tBUF between repeated starts
    return

;-----------------------------------------------------------
; READ ADC FROM AN0 (RA0) ? 10-bit ? scaled to 6-bit (0?63)
; Left justified, Fosc/2, VDD/VSS ref
; Uses existing Delay_InterPacket for acquisition time (>20µs guaranteed)
; Final scaling: 10-bit / 16 = 6-bit exact mapping (0?1023 ? 0?63)
;-----------------------------------------------------------
Read_ADC_AN0:
    BANKSEL ADCON0
    movlw   0b00000001              ; ADFM=0 (left justify), CHS=0000 (AN0), ADON=1, GO=0
    movwf   ADCON0                  ; select AN0, turn ADC on
    call    Delay_InterPacket       ; acquisition delay ? already >20µs
    bsf     ADCON0,1                ; GO/DONE = 1 ? start conversion
Wait_ADC:
    btfsc   ADCON0,1                ; wait for GO/DONE to clear
    goto    Wait_ADC
    BANKSEL ADRESH
    movf    ADRESH,W                ; read top 8 bits (left justified)
    movwf   servo_pos               ; store raw 8-bit value (contains top 6 bits + 2 junk)
    andlw   0xFC                    ; mask to top 6 bits ? 0?252 range
    movwf   servo_pos               ; now 0,4,8,...,252
    bcf     STATUS,0
    rrf     servo_pos,F             ; divide by 2 ? 0?126
    bcf     STATUS,0
    rrf     servo_pos,F             ; divide by 4 total ? perfect 0?63
    return                          ; servo_pos now ready for transmission

;-----------------------------------------------------------
; INITIALIZATION
;-----------------------------------------------------------
Start:
    ; Disable analog inputs globally first
    BANKSEL ANSEL
    clrf    ANSEL                   ; all PORTA digital by default
    clrf    ANSELH
    BANKSEL CM1CON0
    clrf    CM1CON0                 ; comparators off
    clrf    CM2CON0
    BANKSEL SRCON
    clrf    SRCON                   ; SR latch off

    ; Enable AN0 only as analog input
    BANKSEL ANSEL
    bsf     ANSEL,0                 ; AN0 = analog
    BANKSEL TRISA
    bsf     TRISA,0                 ; RA0 = input (pot)

    ; I2C pins ? SCL/SDA inputs for open-drain
    BANKSEL TRISC
    movlw   0b00011000              ; RC3=SCL, RC4=SDA inputs
    movwf   TRISC

    ; Clear all ports
    BANKSEL PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC

    ; ADC setup ? left justified, Fosc/2, VDD/VSS reference
    BANKSEL ADCON1
    movlw   0b00000000              ; no special voltage reference
    movwf   ADCON1
    BANKSEL ADCON0
    movlw   0b00000001              ; ADON=1, channel set later
    movwf   ADCON0

    ; MSSP Master mode ? 100kHz @4MHz
    BANKSEL SSPSTAT
    movlw   0x80                    ; SMP=1 (master mode requirement)
    movwf   SSPSTAT
    BANKSEL SSPCON
    movlw   0x28                    ; SSPEN=1, master mode
    movwf   SSPCON
    BANKSEL SSPADD
    movlw   9                       ; 4MHz / (4*(9+1)) = 100kHz
    movwf   SSPADD

    ; Initialize variables
    movlw   0x20
    movwf   SLAVE_ADDR              ; 7-bit base address
    clrf    servo_id                ; fixed servo 0
    clrf    servo_pos               ; will be filled by ADC

    ; Clear interrupt flags ? polling mode
    BANKSEL PIR1
    bcf     PIR1,3
    BANKSEL PIE1
    bcf     PIE1,3                  ; disable MSSP interrupt

;-----------------------------------------------------------
; MAIN LOOP ? continuously read pot and update servo 0
;-----------------------------------------------------------
Main_Loop:
    call    Read_ADC_AN0            ; update servo_pos from AN0
    call    I2C_SendFullPacket      ; transmit to slave
    goto    Main_Loop               ; repeat forever

END