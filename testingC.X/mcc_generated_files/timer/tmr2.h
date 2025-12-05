/**
 * TMR2 Generated Driver API Header File
 * 
 * @file tmr2.h
 * 
 * @ingroup timerdriver
 * 
 * @brief This file contains the API prototypes and other data types for the Timer2 (TMR2) driver.
 *
 * @version TMR2 Driver Version 2.0.0
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

#ifndef TMR2_H
#define TMR2_H

#include <stdint.h>
#include <stdbool.h>
#include "timer_interface.h"

/**
 * @misradeviation{@advisory,2.5}
 * MCC Melody drivers provide macros that can be added to an application. 
 * It depends on the application whether a macro is used or not. 
 */

/**
 * @ingroup timerdriver
 * @brief Defines the maximum count value of the timer.
 */
#define TMR2_MAX_COUNT (255U)
/**
 * @ingroup timerdriver
 * @brief Defines the timer prescaled clock frequency in hertz.
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define TMR2_CLOCK_FREQ (1000000UL)

/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_MAX_COUNT
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define TIMER2_MAX_COUNT TMR2_MAX_COUNT
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_CLOCK_FREQ
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define TIMER2_CLOCK_FREQ TMR2_CLOCK_FREQ
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_Initialize API.
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_Initialize TMR2_Initialize
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_Deinitialize API.
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_Deinitialize TMR2_Deinitialize
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_Start API.
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_Start TMR2_Start
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_Stop API.
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_Stop TMR2_Stop
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_CounterGet API.
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_CounterGet TMR2_CounterGet
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_CounterSet API.
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_CounterSet TMR2_CounterSet
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_PeriodSet API
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_PeriodSet TMR2_PeriodSet
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_PeriodGet API
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_PeriodGet TMR2_PeriodGet
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_MaxCountGet API
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_MaxCountGet TMR2_MaxCountGet
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_PeriodMatchCallbackRegister API
 */
/* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_PeriodMatchCallbackRegister TMR2_PeriodMatchCallbackRegister
/**
 * @ingroup timerdriver
 * @brief Defines the Custom Name for the \ref TMR2_Tasks API
 */
 /* cppcheck-suppress misra-c2012-2.5 */
#define Timer2_Tasks TMR2_Tasks

/**
 @ingroup tmr2driver
 @struct TIMER_INTERFACE
 @brief Declares an instance of TIMER_INTERFACE for the TMR2 module.
 */
extern const struct TIMER_INTERFACE Timer2;

/**
 * @ingroup timerdriver
 * @brief Initializes the Timer2 (TMR2) module.
 *        This routine must be called before any other TMR2 routines.
 * @param None.
 * @return None.
 */
void TMR2_Initialize(void);

/**
 * @ingroup timerdriver
 * @brief Deinitializes the TMR2 module.
 * @param None.
 * @return None.
 */
void TMR2_Deinitialize(void);

/**
 * @ingroup timerdriver
 * @brief Starts the TMR2 timer.
 * @pre Initialize TMR2 with TMR2_Initialize() before calling this API.
 * @param None.
 * @return None.
 */
void TMR2_Start(void);

/**
 * @ingroup timerdriver
 * @brief Stops the TMR2 timer.
 * @pre Initialize TMR2 with TMR2_Initialize() before calling this API.
 * @param None.
 * @return None.
 */
void TMR2_Stop(void);

/**
 * @ingroup timer
 * @brief Returns the current counter value.
 * @pre Initialize TMR2 with TMR2_Initialize() before calling this API.
 * @param None.
 * @return Counter value from the TMR2 register
 */
uint32_t TMR2_CounterGet(void);

/**
 * @ingroup timerdriver
 * @brief Sets the counter value.
 * @pre Initialize TMR2 with TMR2_Initialize() before calling this API.
 * @param counterValue - Counter value to be written to the TMR2 register
 * @return None.
 */
void TMR2_CounterSet(uint32_t counterValue);

/**
 * @ingroup timerdriver
 * @brief Sets the period count value.
 * @pre Initialize TMR2 with TMR2_Initialize() before calling this API.
 * @param periodCount - Period count value to be written to the PR2 register
 * @return None.
 */
void TMR2_PeriodSet(uint32_t periodCount);

/**
 * @ingroup timerdriver
 * @brief Returns the current period value.
 * @pre Initialize TMR2 with TMR2_Initialize() before calling this API.
 * @param None.
 * @return Period count value
 */
uint32_t TMR2_PeriodGet(void);

/**
 * @ingroup timerdriver
 * @brief Returns the maximum count value.
 * @param None.
 * @return Maximum count value
 */
uint32_t TMR2_MaxCountGet(void);


/**
 * @ingroup timerdriver
 * @brief Registers a callback function for the TMR2 period match callback.
 * @param CallbackHandler - Address of the custom callback function
 * @return None.
 */
void TMR2_PeriodMatchCallbackRegister(void (* CallbackHandler)(void));

/**
 * @ingroup timerdriver
 * @brief Performs tasks to be executed during the TMR2 period match event.
 * @param None.
 * @return None.
 */
void TMR2_Tasks(void);

#endif // TMR2_H
/**
 End of File
*/
