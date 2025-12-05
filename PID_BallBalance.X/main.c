/*
 * MAIN Generated Driver File
 * 
 * @file main.c
 * 
 * @defgroup main MAIN
 * 
 * @brief This is the generated driver implementation file for the MAIN driver.
 *
 * @version MAIN Driver Version 1.0.2
 *
 * @version Package Version: 3.1.2
*/

/*
© [2025] Microchip Technology Inc. and its subsidiaries.

    Subject to your compliance with these terms, you may use Microchip 
    software and any derivatives exclusively with Microchip products. 
    You are responsible for complying with 3rd party license terms  
    applicable to your use of 3rd party software (including open source  
    software) that may accompany Microchip software. SOFTWARE IS ?AS IS.? 
    NO WARRANTIES, WHETHER EXPRESS, IMPLIED OR STATUTORY, APPLY TO THIS 
    SOFTWARE, INCLUDING ANY IMPLIED WARRANTIES OF NON-INFRINGEMENT,  
    MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT 
    WILL MICROCHIP BE LIABLE FOR ANY INDIRECT, SPECIAL, PUNITIVE, 
    INCIDENTAL OR CONSEQUENTIAL LOSS, DAMAGE, COST OR EXPENSE OF ANY 
    KIND WHATSOEVER RELATED TO THE SOFTWARE, HOWEVER CAUSED, EVEN IF 
    MICROCHIP HAS BEEN ADVISED OF THE POSSIBILITY OR THE DAMAGES ARE 
    FORESEEABLE. TO THE FULLEST EXTENT ALLOWED BY LAW, MICROCHIP?S 
    TOTAL LIABILITY ON ALL CLAIMS RELATED TO THE SOFTWARE WILL NOT 
    EXCEED AMOUNT OF FEES, IF ANY, YOU PAID DIRECTLY TO MICROCHIP FOR 
    THIS SOFTWARE.
*/

#include <system.h>
#include <adc.h>      // Fixed path: adc/adc.h
#include <ccp1.h>   // Fixed path: ccp1/ccp1.h

/*
    BALL BALANCE TEST - ADC RA0(AN0) ? RB0(CCP1) PWM 1ms-2ms
    GP2Y0A21 Vo ? RA0, Servo PWM ? RB0, VDD=5V reference
*/

// Global vars - ADC to PWM mapping
bool adc_ready = false;
uint16_t raw_adc = 0;
uint16_t servo_duty = 0;

/*
    Main application
*/

int main(void)
{
    SYSTEM_Initialize();
    
    // FORCE RA0 ANALOG - MCC pins.c ANSELA bug workaround
    ANSELA |= 0x01;  // bit0=1 ? RA0=AN0 analog input
    
    // Startup: 50% duty (1.5ms neutral servo) until ADC ready
    CCP1_LoadDutyValue(307);  // 307/1024=30% ? 1.5ms @50Hz/20ms
    
    // ADC settle + prime first reading (discard transient)
    __delay_ms(100);
    raw_adc = ADC_GetConversion(AN0_CHANNEL, AN0_NEG_CHANNEL);
    adc_ready = true;
    
    // If using interrupts in PIC18 High/Low Priority Mode you need to enable the Global High and Low Interrupts 
    // If using interrupts in PIC Mid-Range Compatibility Mode you need to enable the Global and Peripheral Interrupts 
    // Use the following macros to: 

    // Enable the Global Interrupts 
    //INTERRUPT_GlobalInterruptEnable(); 

    // Disable the Global Interrupts 
    //INTERRUPT_GlobalInterruptDisable(); 

    // Enable the Peripheral Interrupts 
    //INTERRUPT_PeripheralInterruptEnable(); 

    // Disable the Peripheral Interrupts 
    //INTERRUPT_PeripheralInterruptDisable(); 

    while(1)
    {
        // Read GP2Y0A21 or pot on RA0/AN0 (10-bit, 0-1023)
        raw_adc = ADC_GetConversion(AN0_CHANNEL, AN0_NEG_CHANNEL);
        
        // Map ADC(0-1023) ? PWM duty(205-410) = 1ms-2ms @50Hz
        // 0V   ? 205/1024*20ms = 1ms   (servo CCW max)
        // 2.5V ? 307/1024*20ms = 1.5ms (servo CENTER)  
        // 5V   ? 410/1024*20ms = 2ms   (servo CW max)
        servo_duty = 205 + (raw_adc * 205 / 1023);
        
        // Update servo PWM duty cycle
        CCP1_LoadDutyValue(servo_duty);
        
        // 50Hz loop matches servo PWM period (20ms)
        __delay_ms(20);
    }    
    
    return -1;
}
