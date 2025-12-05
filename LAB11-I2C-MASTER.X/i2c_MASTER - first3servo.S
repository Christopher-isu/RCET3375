;=================================================================
; PIC16F883 I2C MASTER ? STEP 4: TRIPLE ADC CONTROL (Servo 0,1,2)
; - AN0 (RA0) ? Servo ID 00
; - AN1 (RA1) ? Servo ID 01
; - AN3 (RA3) ? Servo ID 02
; - All pots continuously sampled and sent in round-robin
; - Packet format: [START][0x40][data_byte][STOP]
;   where data_byte = (servo_id << 6) | (pos & 0x3F)
;=================================================================
#include <xc.inc>

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

PSECT udata_acs
W_SAVE:         DS 1
STATUS_SAVE:    DS 1
TMP:            DS 1
SLAVE_ADDR:     DS 1
servo_id:       DS 1
servo_pos:      DS 1
data_byte:      DS 1

PSECT resetVect,class=CODE,delta=2
goto Start

PSECT isrVect,class=CODE,delta=2
goto ISR

PSECT code,class=CODE,delta=2

ISR:
movwf   W_SAVE
swapf   STATUS,W
movwf   STATUS_SAVE
swapf   STATUS_SAVE,W
movwf   STATUS
swapf   W_SAVE,F
swapf   W_SAVE,W
retfie

; Wait for I2C bus idle
I2C_WaitIdle:
I2C_IdleLoop:
BANKSEL SSPSTAT
btfsc   SSPSTAT,2
goto    I2C_IdleLoop
BANKSEL SSPCON2
movf    SSPCON2,W
andlw   0x1F
btfss   STATUS,2
goto    I2C_IdleLoop
return

; I2C start condition
I2C_Start:
call    I2C_WaitIdle
BANKSEL SSPCON2
bsf     SSPCON2,0
I2C_WaitStart:
btfsc   SSPCON2,0
goto    I2C_WaitStart
BANKSEL PIR1
bcf     PIR1,3
return

; I2C stop condition
I2C_Stop:
BANKSEL PIR1
bcf     PIR1,3
BANKSEL SSPCON2
bsf     SSPCON2,2
I2C_WaitStop:
btfsc   SSPCON2,2
goto    I2C_WaitStop
return

; I2C write byte
I2C_WriteByte:
BANKSEL SSPBUF
movwf   SSPBUF
I2C_WaitTX:
BANKSEL PIR1
btfss   PIR1,3
goto    I2C_WaitTX
BANKSEL SSPCON2
btfsc   SSPCON2,6
goto    I2C_NackStop
BANKSEL PIR1
bcf     PIR1,3
return
I2C_NackStop:
call    I2C_Stop
return

; Delay ~10us
Delay_InterPacket:
movlw   40
movwf   TMP
Delay_Loop:
decfsz  TMP,F
goto    Delay_Loop
return

; Build data byte and send I2C packet
I2C_SendFullPacket:
movf    servo_id,W
andlw   0x03
movwf   data_byte
bcf     STATUS,0
rlf     data_byte,F
bcf     STATUS,0
rlf     data_byte,F
bcf     STATUS,0
rlf     data_byte,F
bcf     STATUS,0
rlf     data_byte,F
bcf     STATUS,0
rlf     data_byte,F
bcf     STATUS,0
rlf     data_byte,F
movf    servo_pos,W
andlw   0x3F
iorwf   data_byte,F
call    I2C_Start
movf    SLAVE_ADDR,W
movwf   TMP
addwf   TMP,W
call    I2C_WriteByte
movf    data_byte,W
call    I2C_WriteByte
call    I2C_Stop
call    Delay_InterPacket
return

; Read ADC channel (0=AN0,1=AN1,3=AN3)
Read_ADC_Channel:
movwf   TMP
BANKSEL ADCON0
movlw   0b00000001
movwf   ADCON0
movf    TMP,W
bcf     STATUS,0
rlf     TMP,F
bcf     STATUS,0
rlf     TMP,F
movf    TMP,W
iorwf   ADCON0,F
call    Delay_InterPacket
bsf     ADCON0,1
Wait_ADC:
btfsc   ADCON0,1
goto    Wait_ADC
BANKSEL ADRESH
movf    ADRESH,W
andlw   0xFC
movwf   servo_pos
bcf     STATUS,0
rrf     servo_pos,F
bcf     STATUS,0
rrf     servo_pos,F
return

Start:
BANKSEL ANSEL
clrf    ANSEL
clrf    ANSELH
BANKSEL CM1CON0
clrf    CM1CON0
clrf    CM2CON0
BANKSEL SRCON
clrf    SRCON

BANKSEL PORTA
clrf    PORTA
BANKSEL PORTB
clrf    PORTB
BANKSEL PORTC
clrf    PORTC

BANKSEL ANSEL
bsf     ANSEL,0 ; AN0 analog
bsf     ANSEL,1 ; AN1 analog
bsf     ANSEL,3 ; AN3 analog

BANKSEL TRISA
bsf     TRISA,0 ; RA0 input
bsf     TRISA,1 ; RA1 input
bsf     TRISA,3 ; RA3 input

BANKSEL TRISC
movlw   0b00011000 ; RC3=SCL RC4=SDA inputs
movwf   TRISC

BANKSEL ADCON1
movlw   0b00000000 ; left-justified, VDD ref
movwf   ADCON1

BANKSEL ADCON0
movlw   0b00000001
movwf   ADCON0

; Setup SSP Master @ 100 KHz
BANKSEL SSPSTAT
movlw   0x80
movwf   SSPSTAT
BANKSEL SSPCON
movlw   0x28 ; Master mode
movwf   SSPCON
BANKSEL SSPADD
movlw   9 ; for 100KHz
movwf   SSPADD

movlw   0x20
movwf   SLAVE_ADDR

Main_Loop:
; Servo 0 update
clrf    servo_id
movlw   0
call    Read_ADC_Channel
call    I2C_SendFullPacket

; Servo 1 update
movlw   1
movwf   servo_id
movlw   1
call    Read_ADC_Channel
call    I2C_SendFullPacket

; Servo 2 update
movlw   2
movwf   servo_id
movlw   3
call    Read_ADC_Channel
call    I2C_SendFullPacket

goto    Main_Loop

END
