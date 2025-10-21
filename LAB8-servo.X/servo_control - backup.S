;=================================================================
; Servo Control with ADC and LED Display - this section sets up
; PIC16F883 for servo control with 4MHz XT osc, Timer1 1:4 (4µs
; ticks), 20ms PWM/ADC cycle, RB0 PWM (0.5-2.5ms), PORTC LEDs
; (8-bit ADC), AN0 pot input, polling-based, no interrupts for
; simple, low-power demo with synced ADC/PWM, easy MPLAB debug
;=================================================================
    PROCESSOR 16F883
    #include <xc.inc>

;=================================================================
; Device Configuration - this section configures 4MHz XT osc, MCLR
; on, disables WDT/PWRTE/BOREN to save power, no code protection
; for simple lab demo with precise timing
;=================================================================
    CONFIG  FOSC = XT         ; 4MHz crystal oscillator
    CONFIG  WDTE = OFF        ; No watchdog timer
    CONFIG  PWRTE = OFF       ; No power-up timer
    CONFIG  MCLRE = ON        ; MCLR pin enabled
    CONFIG  CP = OFF          ; No code protection
    CONFIG  CPD = OFF         ; No EEPROM protection
    CONFIG  BOREN = OFF       ; No brown-out reset
    CONFIG  IESO = OFF        ; No int/ext clock switch
    CONFIG  FCMEN = OFF       ; No fail-safe clock monitor
    CONFIG  LVP = OFF         ; No low-voltage programming
    CONFIG  WRT = OFF         ; No flash write protection

;=================================================================
; Variables (Bank0) - this section allocates registers in Bank0
; for ADC, PWM, and calc data for fast access in polling loop
;=================================================================
    PSECT udata_bank0, class=BANK0, space=1
ACQ_CNT:    DS 1            ; Counter for ~20µs ADC acquisition delay
OLD_ADC:    DS 1            ; Prev ADC value (8-bit, AN0)
NEW_ADC:    DS 1            ; Curr ADC value (8-bit, AN0)
STEP:       DS 1            ; Servo steps (0-63, ADC >> 2)
OLD_STEP:   DS 1            ; Prev STEP value
PULSE_LO:   DS 1            ; PWM pulse width low byte (ticks)
PULSE_HI:   DS 1            ; PWM pulse width high byte (ticks)
OFF_LO:     DS 1            ; PWM off-time low byte (ticks)
OFF_HI:     DS 1            ; PWM off-time high byte (ticks)
TEMP_LO:    DS 1            ; Temp calc low byte
TEMP_HI:    DS 1            ; Temp calc high byte

;=================================================================
; Reset Vector - this section starts program at 0x0000, no
; interrupt vector for polling-based design, simple startup
;=================================================================
    PSECT   resetVect, class=CODE, delta=2
    GOTO    MAIN            ; Jump to MAIN at 0x0000 for program start

;=================================================================
; Main Program - this section inits 4MHz XT osc, ADC (AN0, 8-bit,
; Fosc/8), Timer1 (1:4), PORTC LEDs (RC0=LSB), RB0 PWM out, runs
; polling loop for 20ms PWM-then-ADC cycle for synced updates
;=================================================================
    PSECT   code, class=CODE, delta=2
MAIN:
    BANKSEL OSCCON
    CLRF    OSCCON          ; Clear OSCCON to use 4MHz XT osc (FOSC=XT)
    ; Disable unused peripherals to save power, reduce noise
    BANKSEL ANSEL
    MOVLW   0x01            ; Set ANSEL=0x01 to enable AN0, others digital
    MOVWF   ANSEL           ; Configure PORTA for AN0 analog input
    BANKSEL ANSELH
    CLRF    ANSELH          ; Clear ANSELH, PORTB all digital (no analog)
    BANKSEL CM1CON0
    CLRF    CM1CON0         ; Clear CM1CON0 to disable comparator 1
    CLRF    CM2CON0         ; Clear CM2CON0 to disable comparator 2
    BANKSEL SRCON
    CLRF    SRCON           ; Clear SRCON to disable SR latch
    BANKSEL CCP1CON
    CLRF    CCP1CON         ; Clear CCP1CON to disable CCP1 module
    CLRF    CCP2CON         ; Clear CCP2CON to disable CCP2 module
    ; ADC: AN0, left-justified, VDD/VSS ref, Fosc/8 (2µs TAD)
    BANKSEL ADCON1
    MOVLW   0b00000000      ; Set ADCON1=0 (ADFM=0: 8-bit, VCFG=00: VDD/VSS)
    MOVWF   ADCON1          ; Configure ADC for left-justified, VDD ref
    BANKSEL ADCON0
    MOVLW   0b01000001      ; Set ADCON0=0b01000001 (Fosc/8, AN0, ADON=1)
    MOVWF   ADCON0          ; Enable ADC, select AN0, 2µs TAD
    ; PORTC: 8-bit LED out (RC0=LSB, RC7=MSB)
    BANKSEL TRISC
    CLRF    TRISC           ; Clear TRISC to set PORTC as outputs
    BANKSEL PORTC
    CLRF    PORTC           ; Clear PORTC to init LEDs off
    ; Timer1: 1:4 prescale (4µs ticks), off
    BANKSEL T1CON
    MOVLW   0b00100000      ; Set T1CON=0b00100000 (1:4 prescale, TMR1ON=0)
    MOVWF   T1CON           ; Configure Timer1 for 4µs ticks, stopped
    ; RB0: PWM output
    BANKSEL TRISB
    BCF     TRISB, 0        ; Clear TRISB.0 to set RB0 as output
    BANKSEL PORTB
    BCF     PORTB, 0        ; Clear PORTB.0 to init RB0 low
    ; Init vars
    BANKSEL OLD_ADC
    MOVLW   0xFF            ; Set OLD_ADC=0xFF to force first update
    MOVWF   OLD_ADC         ; Store initial OLD_ADC value
    MOVWF   OLD_STEP        ; Set OLD_STEP=0xFF to force first update
    CLRF    ACQ_CNT         ; Clear ACQ_CNT for ADC delay counter
    CLRF    NEW_ADC         ; Clear NEW_ADC for initial ADC value
    CLRF    STEP            ; Clear STEP for initial servo position
    CLRF    PULSE_LO        ; Clear PULSE_LO for PWM pulse width
    CLRF    PULSE_HI        ; Clear PULSE_HI for PWM pulse width
    CLRF    OFF_LO          ; Clear OFF_LO for PWM off-time
    CLRF    OFF_HI          ; Clear OFF_HI for PWM off-time
    CLRF    TEMP_LO         ; Clear TEMP_LO for calculations
    CLRF    TEMP_HI         ; Clear TEMP_HI for calculations

; Main loop - this section runs 20ms PWM (pulse + off), then ADC
; (~30µs), updates LEDs/servo if changed for efficient 50Hz sync
LOOP:
    CALL    GENERATE_PWM    ; Call PWM subroutine for 20ms cycle
    ; ADC: ~20µs acquisition delay (5 × 4µs)
    MOVLW   0x05            ; Set ACQ_CNT=5 for ~20µs ADC acquisition
    MOVWF   ACQ_CNT         ; Load counter for delay loop
DELAY_ACQ:
    NOP                     ; Delay 1µs to meet ADC acquisition time
    NOP                     ; Delay 1µs to meet ADC acquisition time
    NOP                     ; Delay 1µs to meet ADC acquisition time
    NOP                     ; Delay 1µs to meet ADC acquisition time
    DECFSZ  ACQ_CNT, F      ; Dec ACQ_CNT, skip if 0 (5 loops = 20µs)
    GOTO    DELAY_ACQ       ; Loop for acquisition delay
    ; Start ADC conversion (~22µs, 11 TAD × 2µs)
    BANKSEL ADCON0
    BSF     ADCON0, 1       ; Set GO/DONE=1 to start ADC conversion
WAIT_ADC:
    BTFSC   ADCON0, 1       ; Check GO/DONE, loop if 1 (wait ~22µs)
    GOTO    WAIT_ADC        ; Wait for ADC conversion complete
    ; Read 8-bit ADC (ADRESH)
    BANKSEL ADRESH
    MOVF    ADRESH, W       ; Load W with ADRESH (8 MSB of ADC)
    MOVWF   NEW_ADC         ; Store ADC value in NEW_ADC
    ; Check ADC change
    SUBWF   OLD_ADC, W      ; W = NEW_ADC - OLD_ADC to check change
    BTFSC   STATUS, 2       ; Skip if not zero (ADC changed)
    GOTO    LOOP            ; No change, skip to next PWM cycle
    MOVF    NEW_ADC, W      ; Load W with NEW_ADC for update
    MOVWF   OLD_ADC         ; Update OLD_ADC with new value
    ; Update LEDs
    BANKSEL PORTC
    MOVWF   PORTC           ; Set PORTC = ADC value (RC0=LSB)
    ; Calc STEP = ADC >> 2 (0-63 range)
    MOVWF   STEP            ; Store ADC value in STEP
    BCF     STATUS, 0       ; Clear carry for right shift
    RRF     STEP, F         ; Shift STEP right (/2) for scaling
    BCF     STATUS, 0       ; Clear carry for right shift
    RRF     STEP, F         ; Shift STEP right (/4) to get 0-63
    ; Check STEP change
    MOVF    STEP, W         ; Load W with STEP for comparison
    SUBWF   OLD_STEP, W     ; W = STEP - OLD_STEP to check change
    BTFSC   STATUS, 2       ; Skip if not zero (STEP changed)
    GOTO    LOOP            ; No change, skip to next PWM cycle
    MOVF    STEP, W         ; Load W with STEP for update
    MOVWF   OLD_STEP        ; Update OLD_STEP with new value
    ; Calc PULSE_ticks = 125 + (STEP * 127) >> 4
    MOVWF   TEMP_LO         ; Set TEMP_LO = STEP for calc
    CLRF    TEMP_HI         ; Clear TEMP_HI for 16-bit calc
    BCF     STATUS, 0       ; Clear carry for left shifts
    ; STEP * 128 via left shifts
    RLF     TEMP_LO, F      ; Shift left TEMP_LO (*2)
    RLF     TEMP_HI, F      ; Shift carry to TEMP_HI
    RLF     TEMP_LO, F      ; Shift left TEMP_LO (*4)
    RLF     TEMP_HI, F      ; Shift carry to TEMP_HI
    RLF     TEMP_LO, F      ; Shift left TEMP_LO (*8)
    RLF     TEMP_HI, F      ; Shift carry to TEMP_HI
    RLF     TEMP_LO, F      ; Shift left TEMP_LO (*16)
    RLF     TEMP_HI, F      ; Shift carry to TEMP_HI
    RLF     TEMP_LO, F      ; Shift left TEMP_LO (*32)
    RLF     TEMP_HI, F      ; Shift carry to TEMP_HI
    RLF     TEMP_LO, F      ; Shift left TEMP_LO (*64)
    RLF     TEMP_HI, F      ; Shift carry to TEMP_HI
    RLF     TEMP_LO, F      ; Shift left TEMP_LO (*128)
    RLF     TEMP_HI, F      ; Shift carry to TEMP_HI
    ; STEP * 127 = (STEP * 128) - STEP
    MOVF    STEP, W         ; Load W with STEP for subtraction
    SUBWF   TEMP_LO, F      ; TEMP_LO -= STEP for *127
    BTFSS   STATUS, 0       ; Check borrow, adjust TEMP_HI
    DECF    TEMP_HI, F      ; Decrement TEMP_HI if borrow
    ; Divide by 16 (>> 4)
    BCF     STATUS, 0       ; Clear carry for right shift
    RRF     TEMP_HI, F      ; Shift right TEMP_HI
    RRF     TEMP_LO, F      ; Shift right TEMP_LO
    BCF     STATUS, 0       ; Clear carry for right shift
    RRF     TEMP_HI, F      ; Shift right TEMP_HI
    RRF     TEMP_LO, F      ; Shift right TEMP_LO
    BCF     STATUS, 0       ; Clear carry for right shift
    RRF     TEMP_HI, F      ; Shift right TEMP_HI
    RRF     TEMP_LO, F      ; Shift right TEMP_LO
    BCF     STATUS, 0       ; Clear carry for right shift
    RRF     TEMP_HI, F      ; Shift right TEMP_HI
    RRF     TEMP_LO, F      ; Shift right TEMP_LO
    ; Add base 125 ticks (0.5ms)
    MOVLW   0x7D            ; Load W = 125 for base pulse
    ADDWF   TEMP_LO, F      ; TEMP_LO += 125 for min pulse
    BTFSC   STATUS, 0       ; Check carry, adjust TEMP_HI
    INCF    TEMP_HI, F      ; Increment TEMP_HI if carry
    MOVF    TEMP_LO, W      ; Load W with TEMP_LO for store
    MOVWF   PULSE_LO        ; Store TEMP_LO in PULSE_LO
    MOVF    TEMP_HI, W      ; Load W with TEMP_HI for store
    MOVWF   PULSE_HI        ; Store TEMP_HI in PULSE_HI
    ; Calc OFF = 5000 - PULSE (20ms frame)
    MOVLW   0x88            ; Load OFF_LO = 0x1388 low (5000 ticks)
    MOVWF   OFF_LO          ; Set OFF_LO for 20ms frame
    MOVLW   0x13            ; Load OFF_HI = 0x1388 high
    MOVWF   OFF_HI          ; Set OFF_HI for 20ms frame
    MOVF    PULSE_LO, W     ; Load W with PULSE_LO for subtract
    SUBWF   OFF_LO, F       ; OFF_LO -= PULSE_LO
    BTFSS   STATUS, 0       ; Check borrow, adjust OFF_HI
    DECF    OFF_HI, F       ; Decrement OFF_HI if borrow
    MOVF    PULSE_HI, W     ; Load W with PULSE_HI for subtract
    SUBWF   OFF_HI, F       ; OFF_HI -= PULSE_HI
    GOTO    LOOP            ; Jump to next PWM/ADC cycle

;=================================================================
; PWM Generation Subroutine - this section generates 0.5-2.5ms
; pulse on RB0, off-time to 20ms using Timer1 (4µs ticks),
; polling TMR1IF for software PWM flexibility, RB0 usage
;=================================================================
GENERATE_PWM:
    BANKSEL PORTB
    BSF     PORTB, 0        ; Set RB0 high to start PWM pulse
    ; Preload = ~(PULSE) + 1
    MOVF    PULSE_LO, W     ; Load W with PULSE_LO for invert
    XORLW   0xFF            ; W = ~PULSE_LO for preload
    MOVWF   TEMP_LO         ; Store ~PULSE_LO in TEMP_LO
    MOVF    PULSE_HI, W     ; Load W with PULSE_HI for invert
    XORLW   0xFF            ; W = ~PULSE_HI for preload
    MOVWF   TEMP_HI         ; Store ~PULSE_HI in TEMP_HI
    INCF    TEMP_LO, F      ; TEMP_LO += 1 for two's complement
    BTFSC   STATUS, 2       ; Check zero, adjust TEMP_HI
    INCF    TEMP_HI, F      ; Increment TEMP_HI if TEMP_LO zero
    MOVF    TEMP_LO, W      ; Load W with TEMP_LO for Timer1
    MOVWF   TMR1L           ; Set TMR1L for pulse duration
    MOVF    TEMP_HI, W      ; Load W with TEMP_HI for Timer1
    MOVWF   TMR1H           ; Set TMR1H for pulse duration
    BANKSEL PIR1
    BCF     PIR1, 0         ; Clear TMR1IF to reset Timer1 flag
    BANKSEL T1CON
    BSF     T1CON, 0        ; Set TMR1ON=1 to start Timer1
WAIT_PULSE:
    BANKSEL PIR1
    BTFSS   PIR1, 0         ; Check TMR1IF, loop if 0 (pulse active)
    GOTO    WAIT_PULSE      ; Wait for pulse duration
    BANKSEL T1CON
    BCF     T1CON, 0        ; Clear TMR1ON to stop Timer1
    BANKSEL PORTB
    BCF     PORTB, 0        ; Clear RB0 to end PWM pulse
    ; Off-time preload = ~(OFF) + 1
    MOVF    OFF_LO, W       ; Load W with OFF_LO for invert
    XORLW   0xFF            ; W = ~OFF_LO for preload
    MOVWF   TEMP_LO         ; Store ~OFF_LO in TEMP_LO
    MOVF    OFF_HI, W       ; Load W with OFF_HI for invert
    XORLW   0xFF            ; W = ~OFF_HI for preload
    MOVWF   TEMP_HI         ; Store ~OFF_HI in TEMP_HI
    INCF    TEMP_LO, F      ; TEMP_LO += 1 for two's complement
    BTFSC   STATUS, 2       ; Check zero, adjust TEMP_HI
    INCF    TEMP_HI, F      ; Increment TEMP_HI if TEMP_LO zero
    MOVF    TEMP_LO, W      ; Load W with TEMP_LO for Timer1
    MOVWF   TMR1L           ; Set TMR1L for off-time duration
    MOVF    TEMP_HI, W      ; Load W with TEMP_HI for Timer1
    MOVWF   TMR1H           ; Set TMR1H for off-time duration
    BANKSEL PIR1
    BCF     PIR1, 0         ; Clear TMR1IF to reset Timer1 flag
    BANKSEL T1CON
    BSF     T1CON, 0        ; Set TMR1ON=1 to start Timer1
WAIT_OFF:
    BANKSEL PIR1
    BTFSS   PIR1, 0         ; Check TMR1IF, loop if 0 (off-time active)
    GOTO    WAIT_OFF        ; Wait for off-time duration
    BANKSEL T1CON
    BCF     T1CON, 0        ; Clear TMR1ON to stop Timer1
    RETURN                  ; End PWM cycle

    END