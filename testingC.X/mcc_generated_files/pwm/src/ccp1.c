/**
 * PWM1 Generated Driver File.
 * 
 * @file ccp1.c
 * 
 * @ingroup pwm1
 * 
 * @brief This file contains the API implementations for the PWM1 driver.
 *
 * @version PWM1 Driver Version 1.1.0
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

 /**
   Section: Included Files
 */

#include <xc.h>
#include "../ccp1.h"

/**
  Section: Macro Declarations
*/

#define PWM1_INITIALIZE_DUTY_VALUE    19

/**
  Section: PWM1 Module APIs
*/

void CCP1_Initialize(void)
{
    // Set the PWM1 to the options selected in the User Interface
    
    // CCPM PWM; DCB 3; 
    CCP1CON = 0x3C;
    
    // CCPRH 0; 
    CCPR1H = 0x0;
    
    // CCPRL 4; 
    CCPR1L = 0x4;
    
}

void CCP1_LoadDutyValue(uint16_t dutyValue)
{
	  dutyValue &= 0x03FF;
    
    // Writing to 8 MSBs of pwm duty cycle in CCPRL register
    CCPR1L = ((dutyValue & 0x03FC) >> 2);

    // Writing to 2 LSBs of pwm duty cycle in CCPCON register
    CCP1CON = (uint8_t)((CCP1CON & 0xCF) | ((dutyValue & 0x0003) << 4));
}

/**
 End of File
*/
