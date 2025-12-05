/**
 * TMR2 Generated Timer Driver File
 *
 * @file tmr2.c
 * 
 * @ingroup  timerdriver
 * 
 * @brief This file contains the Timer driver implementation for the TMR2 driver
 *
 * @version TMR2 Timer Driver Version 2.0.0
 *
 * @version Package Version 2.0.0
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
#include "../tmr2.h"

const struct TIMER_INTERFACE Timer2 = {
    .Initialize = TMR2_Initialize,
    .Deinitialize = TMR2_Deinitialize,
    .Start = TMR2_Start,
    .Stop = TMR2_Stop,
    .PeriodSet = TMR2_PeriodSet,
    .PeriodGet = TMR2_PeriodGet,
    .CounterGet = TMR2_CounterGet,
    .CounterSet = TMR2_CounterSet,
    .MaxCountGet = TMR2_MaxCountGet,
    .TimeoutCallbackRegister = TMR2_PeriodMatchCallbackRegister,
    .Tasks = TMR2_Tasks
};

static void (*TMR2_PeriodMatchCallback)(void);
static void TMR2_DefaultPeriodMatchCallback(void);

/**
  Section: TMR2 APIs
*/

void TMR2_Initialize(void)
{
    PR2 = 0x9;              // Period 0; Frequency 1000000Hz; Count 9 
    TMR2 = 0x0;
    TMR2_PeriodMatchCallback = TMR2_DefaultPeriodMatchCallback;
    PIR1bits.TMR2IF = false;
    T2CON = (0 << _T2CON_T2CKPS_POSN)   // T2CKPS 1:1
        | (1 << _T2CON_TMR2ON_POSN)   // TMR2ON on
        | (0 << _T2CON_T2OUTPS_POSN);  // T2OUTPS 1:1
}

void TMR2_Deinitialize(void)
{
    T2CONbits.TMR2ON = 0;
    
    PIR1bits.TMR2IF = false;	   
    PIE1bits.TMR2IE = false;		
    
    T2CON = 0x0;
    PR2 = 0xFF;
    TMR2 =0x0;
}



void TMR2_Start(void)
{   
    T2CONbits.TMR2ON = true;
}

void TMR2_Stop(void)
{   
    T2CONbits.TMR2ON = false;
}

uint32_t TMR2_CounterGet(void)
{
    return (uint32_t)TMR2;
}

void TMR2_CounterSet(uint32_t counterValue)
{  
    TMR2 = (uint8_t) counterValue;
}

void TMR2_PeriodSet(uint32_t periodCount)
{
    PR2 = (uint8_t)periodCount;
}

uint32_t TMR2_PeriodGet(void)
{
    return (uint32_t)PR2;
}

uint32_t TMR2_MaxCountGet(void)
{
    return (uint32_t)TMR2_MAX_COUNT;
}


void TMR2_PeriodMatchCallbackRegister(void (* callbackHandler)(void))
{
   TMR2_PeriodMatchCallback = callbackHandler;
}

static void TMR2_DefaultPeriodMatchCallback(void)
{
    // Default callback function
}

void TMR2_Tasks(void)
{
    if(true == PIR1bits.TMR2IF)
    {
        if(NULL != TMR2_PeriodMatchCallback)
        {
            TMR2_PeriodMatchCallback();
        }
        PIR1bits.TMR2IF = false;
    }
}

