;===========================================================
; PIC16F883 I2C MASTER ? STEP 3: DUAL ADC CONTROL (Servo 0 + Servo 1) ? FIXED CHANNEL SELECT
; - AN0 (RA0) ? Servo ID 00
; - AN1 (RA1) ? Servo ID 01
; - Both pots continuously sampled and sent alternately
; - Packet format: [START][0x40][data_byte][STOP] ? data_byte = (servo_id<<6) | (pos&0x3F)
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
servo_id:       DS 1    ; 2-bit servo ID ? 0 or 1 for this step
servo_pos:      DS 1    ; 6-bit position value from ADC (0?63)
data_byte:      DS 1    ; final packet byte: (servo_id<<6) | (servo_pos & 0x3F)
;-----------------------------------------------------------
; VECTORS
;-----------------------------------------------------------
PSECT resetVect,class=CODE,delta=2
goto Start                      ; reset vector
PSECT isrVect,class=CODE,delta=2
goto ISR                        ; interrupt vector (empty ? polling mode)
PSECT code,class=CODE,delta=2
;-----------------------------------------------------------
; INTERRUPT SERVICE ROUTINE ? empty stub, polling mode
;-----------------------------------------------------------
ISR:
movwf   W_SAVE                  ; save W
swapf   STATUS,W                ; save STATUS without altering
movwf   STATUS_SAVE             ; store
swapf   STATUS_SAVE,W           ; restore STATUS
movwf   STATUS                  ; to reg
swapf   W_SAVE,F                ; restore W (nibble swap twice)
swapf   W_SAVE,W                ; to W
retfie                          ; return from interrupt
;-----------------------------------------------------------
; WAIT FOR I2C BUS IDLE ? checks SSPSTAT bit2 (R/W) and SSPCON2 bits0-4 all clear
;-----------------------------------------------------------
I2C_WaitIdle:
I2C_IdleLoop:
BANKSEL SSPSTAT                 ; select bank0
btfsc   SSPSTAT,2               ; R/W bit (bit2) still active? skip if clear
goto    I2C_IdleLoop            ; loop if busy
BANKSEL SSPCON2                 ; select bank0
movf    SSPCON2,W               ; load control2
andlw   0x1F                    ; mask SEN,RSEN,PEN,RCEN,ACKEN
btfss   STATUS,2                ; Z=1 if all zero? skip if idle
goto    I2C_IdleLoop            ; loop if any set
return                          ; idle, exit
;-----------------------------------------------------------
; I2C START CONDITION ? set SEN, wait clear, clear flag
;-----------------------------------------------------------
I2C_Start:
call    I2C_WaitIdle            ; ensure idle before start
BANKSEL SSPCON2                 ; bank0
bsf     SSPCON2,0               ; SEN=1, generate START
I2C_WaitStart:
btfsc   SSPCON2,0               ; SEN still set? skip if done
goto    I2C_WaitStart           ; loop until clear
BANKSEL PIR1                    ; bank0
bcf     PIR1,3                  ; clear SSPIF after start
return                          ; exit
;-----------------------------------------------------------
; I2C STOP CONDITION ? clear flag first, set PEN, wait clear
;-----------------------------------------------------------
I2C_Stop:
BANKSEL PIR1                    ; bank0
bcf     PIR1,3                  ; clear SSPIF before stop
BANKSEL SSPCON2                 ; bank0
bsf     SSPCON2,2               ; PEN=1, generate STOP
I2C_WaitStop:
btfsc   SSPCON2,2               ; PEN still set? skip if done
goto    I2C_WaitStop            ; loop until clear
return                          ; exit
;-----------------------------------------------------------
; I2C WRITE BYTE ? load SSPBUF with W, wait flag, check ACKSTAT, stop on NACK
;-----------------------------------------------------------
I2C_WriteByte:
BANKSEL SSPBUF                  ; bank0
movwf   SSPBUF                  ; load byte to transmit
I2C_WaitTX:
BANKSEL PIR1                    ; bank0
btfss   PIR1,3                  ; SSPIF=1? skip if set (TX done)
goto    I2C_WaitTX              ; loop until flag
BANKSEL SSPCON2                 ; bank0
btfsc   SSPCON2,6               ; ACKSTAT=1? skip if ACK (0)
goto    I2C_NackStop            ; NACK, force stop
BANKSEL PIR1                    ; bank0
bcf     PIR1,3                  ; clear SSPIF after ACK check
return                          ; exit on ACK
I2C_NackStop:
call    I2C_Stop                ; NACK handling: immediate stop
return                          ; exit
;-----------------------------------------------------------
; Delay ~10us @4MHz ? for tBUF between packets, TMP countdown
;-----------------------------------------------------------
Delay_InterPacket:
movlw   40                      ; load count for ~10us (4MHz/4=1MIPS, 40 cycles)
movwf   TMP                     ; store in TMP
Delay_Loop:
decfsz  TMP,F                   ; decrement, skip if zero
goto    Delay_Loop              ; loop
return                          ; exit
;-----------------------------------------------------------
; Build data_byte from servo_pos and servo_id, then send full packet
; - data_byte = (servo_id & 0x03) << 6 | (servo_pos & 0x3F)
; - ctrl_byte = SLAVE_ADDR << 1 | 0 (write) computed in W
;-----------------------------------------------------------
I2C_SendFullPacket:
movf    servo_id,W              ; W = id
andlw   0x03                    ; mask to 2 bits
movwf   data_byte               ; store base
bcf     STATUS,0                ; clear carry for shift
rlf     data_byte,F             ; <<1
bcf     STATUS,0                ; clear carry
rlf     data_byte,F             ; <<1 (x4)
bcf     STATUS,0                ; clear carry
rlf     data_byte,F             ; <<1 (x8)
bcf     STATUS,0                ; clear carry
rlf     data_byte,F             ; <<1 (x16)
bcf     STATUS,0                ; clear carry
rlf     data_byte,F             ; <<1 (x32)
bcf     STATUS,0                ; clear carry
rlf     data_byte,F             ; <<1 (x64) - total <<6
movf    servo_pos,W             ; W = pos
andlw   0x3F                    ; mask to 6 bits
iorwf   data_byte,F             ; or into data_byte low bits
call    I2C_Start               ; issue start
movf    SLAVE_ADDR,W            ; W = addr
movwf   TMP                     ; TMP = addr for add
addwf   TMP,W                   ; W = addr + addr = addr<<1
call    I2C_WriteByte           ; send ctrl byte
movf    data_byte,W             ; W = data
call    I2C_WriteByte           ; send data byte
call    I2C_Stop                ; issue stop
call    Delay_InterPacket       ; inter-packet delay
return                          ; exit
;-----------------------------------------------------------
; READ ADC CHANNEL ? W = channel (0=AN0, 1=AN1), scales 10-bit left-justified to 6-bit servo_pos
; - Sets CHS2:0 = channel by shifting <<2 and ior into ADCON0 (CHS at bits4:2)
; - Fosc/2 clock, VDD ref, acquisition via Delay_InterPacket (>20us)
; - Scaling: (ADRESH & 0xFC) >>2 = 10-bit /16 ? 0-63 exact (ignores low 2 bits in ADRESL)
;-----------------------------------------------------------
Read_ADC_Channel:
movwf   TMP                     ; TMP = channel (0 or 1)
BANKSEL ADCON0                  ; bank0
movlw   0b00000001              ; base: ADCS=00 (Fosc/2), CHS=000, GO=0, ADON=1
movwf   ADCON0                  ; set default channel 0
movf    TMP,W                   ; W = channel
bcf     STATUS,0                ; clear carry
rlf     TMP,F                   ; channel <<1
bcf     STATUS,0                ; clear carry
rlf     TMP,F                   ; channel <<2 ? TMP = channel*4 (sets CHS bits4:2)
movf    TMP,W                   ; W = shifted channel
iorwf   ADCON0,F                ; ior into ADCON0 ? sets CHS without altering others
call    Delay_InterPacket       ; acquisition time >20us
bsf     ADCON0,1                ; GO/DONE=1, start conversion
Wait_ADC:
btfsc   ADCON0,1                ; wait GO/DONE clear
goto    Wait_ADC                ; loop
BANKSEL ADRESH                  ; bank0
movf    ADRESH,W                ; W = top 8 bits (bits9-2)
andlw   0xFC                    ; mask bits7-2 ? top 6 bits *4 (0-252 step 4)
movwf   servo_pos               ; store
bcf     STATUS,0                ; clear carry
rrf     servo_pos,F             ; >>1 = /2
bcf     STATUS,0                ; clear carry
rrf     servo_pos,F             ; >>1 = /4 total ? 0-63 exact
return                          ; exit with servo_pos ready
;-----------------------------------------------------------
; INITIALIZATION AND MAIN LOOP ? disable unused, setup MSSP master 100kHz
;-----------------------------------------------------------
Start:
; Disable analog and comparators - prevent interference on pins
BANKSEL ANSEL                   ; bank1
clrf    ANSEL                   ; all digital
BANKSEL ANSELH                  ; bank3
clrf    ANSELH                  ; all digital
BANKSEL CM1CON0                 ; bank1
clrf    CM1CON0                 ; comparator1 off
BANKSEL CM2CON0                 ; bank1
clrf    CM2CON0                 ; comparator2 off
BANKSEL SRCON                   ; bank1
clrf    SRCON                   ; SR latch off
; Enable AN0/AN1 as analog inputs
BANKSEL ANSEL                   ; bank1
bsf     ANSEL,0                 ; AN0 analog
bsf     ANSEL,1                 ; AN1 analog
BANKSEL TRISA                   ; bank1
bsf     TRISA,0                 ; RA0 input (pot0)
bsf     TRISA,1                 ; RA1 input (pot1)
; PORT configuration - I2C pins input for open-drain
BANKSEL TRISC                   ; bank1
movlw   0b00011000              ; RC3=SCL, RC4=SDA inputs
movwf   TRISC                   ; set
; Clear ports - start low
BANKSEL PORTA                   ; bank0
clrf    PORTA                   ; clear
BANKSEL PORTB                   ; bank0
clrf    PORTB                   ; clear
BANKSEL PORTC                   ; bank0
clrf    PORTC                   ; clear
; ADC setup - left justified, Fosc/2, VDD/VSS reference
BANKSEL ADCON1                  ; bank1
movlw   0b00000000              ; ADFM=0 (left), no voltage ref config
movwf   ADCON1                  ; set
BANKSEL ADCON0                  ; bank0
movlw   0b00000001              ; ADON=1, others set per read
movwf   ADCON0                  ; initial
; MSSP I2C Master mode, 100kHz @4MHz - SSPCON=0x28 (master), SSPADD=9
BANKSEL SSPSTAT                 ; bank0
movlw   0x80                    ; SMP=1 (standard speed master)
movwf   SSPSTAT                 ; set
BANKSEL SSPCON                  ; bank0
movlw   0x28                    ; SSPEN=1, master mode (FOSC/4(SSPADD+1))
movwf   SSPCON                  ; set
BANKSEL SSPADD                  ; bank0
movlw   9                       ; BRG for 100kHz: 4M/4 /100k -1 =9
movwf   SSPADD                  ; set
; Initialize variables - defaults for test
movlw   0x20                    ; base addr
movwf   SLAVE_ADDR              ; store
; Clear interrupt flags - polling, disable PIE
BANKSEL PIR1                    ; bank0
bcf     PIR1,3                  ; clear SSPIF
BANKSEL PIE1                    ; bank1
bcf     PIE1,3                  ; disable MSSP int
;-----------------------------------------------------------
; MAIN LOOP ? round-robin update Servo 0 (AN0) and Servo 1 (AN1)
;-----------------------------------------------------------
Main_Loop:
; --- Update Servo 0 from AN0 ---
clrf    servo_id                ; ID=0
movlw   0                       ; channel=0 (AN0)
call    Read_ADC_Channel        ; update servo_pos
call    I2C_SendFullPacket      ; send packet for ID0
; --- Update Servo 1 from AN1 ---
movlw   1                       ; ID=1
movwf   servo_id                ; store
movlw   1                       ; channel=1 (AN1)
call    Read_ADC_Channel        ; update servo_pos
call    I2C_SendFullPacket      ; send packet for ID1
goto    Main_Loop               ; repeat
END