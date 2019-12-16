// See LICENSE for license details.

#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include <string.h>
#include "plic/plic_driver.h"
#include "encoding.h"
#include <unistd.h>
#include "stdatomic.h"

#define LED0_offset 0
#define LED1_offset 1
#define LED2_offset 2
#define LED3_offset 3
#define LED4_offset 4
#define LED5_offset 5
#define LED6_offset 6
#define LED7_offset 7

void reset_demo (void);

// Structures for registering different interrupt handlers
// for different parts of the application.
typedef void (*function_ptr_t) (void);

void no_interrupt_handler (void) {};

function_ptr_t g_ext_interrupt_handlers[PLIC_NUM_INTERRUPTS];


// Instance data for the PLIC.

plic_instance_t g_plic;


/*Entry Point for PLIC Interrupt Handler*/
void handle_m_ext_interrupt(){
  plic_source int_num  = PLIC_claim_interrupt(&g_plic);
  if ((int_num >=1 ) && (int_num < PLIC_NUM_INTERRUPTS)) {
    g_ext_interrupt_handlers[int_num]();
  }
  else {
    exit(1 + (uintptr_t) int_num);
  }
  PLIC_complete_interrupt(&g_plic, int_num);
}


/*Entry Point for Machine Timer Interrupt Handler*/
void handle_m_time_interrupt(){

  clear_csr(mie, MIP_MTIP);

  // Reset the timer for 3s in the future.
  // This also clears the existing timer interrupt.

  volatile uint64_t * mtime       = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIME);
  volatile uint64_t * mtimecmp    = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIMECMP);
  uint64_t now = *mtime;
  uint64_t then = now + 2 * RTC_FREQ;
  *mtimecmp = then;

  // read the current value of the LEDS and invert them.
  uint32_t leds = GPIO_REG(GPIO_OUTPUT_VAL);
  GPIO_REG(GPIO_OUTPUT_VAL) = ~leds;
  
  // Re-enable the timer interrupt.
  set_csr(mie, MIP_MTIP);

}


void reset_demo (){

  // Disable the machine & timer interrupts until setup is done.

  clear_csr(mie, MIP_MEIP);
  clear_csr(mie, MIP_MTIP);

  for (int ii = 0; ii < PLIC_NUM_INTERRUPTS; ii ++){
    g_ext_interrupt_handlers[ii] = no_interrupt_handler;
  }


    // Set the machine timer to go off in 3 seconds.
    // The
    volatile uint64_t * mtime       = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIME);
    volatile uint64_t * mtimecmp    = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIMECMP);
    uint64_t now = *mtime;
    uint64_t then = now + 2*RTC_FREQ;
    *mtimecmp = then;

    // Enable the Machine-External bit in MIE
    set_csr(mie, MIP_MEIP);

    // Enable the Machine-Timer bit in MIE
    set_csr(mie, MIP_MTIP);

    // Enable interrupts in general.
    set_csr(mstatus, MSTATUS_MIE);
}

int main(int argc, char **argv)
{
  // Set up the GPIOs such that the LED GPIO
  // can be used as Outputs.
  
  uint32_t leds = (0x1<< LED0_offset) | (0x1<< LED1_offset) | (0x1 << LED2_offset) | (0x1<< LED3_offset) | (0x1<< LED4_offset) | (0x1<< LED5_offset) | (0x1<< LED6_offset) | (0x1<< LED7_offset);
  GPIO_REG(GPIO_INPUT_EN) &= ~leds;
  GPIO_REG(GPIO_OUTPUT_EN) |= leds;
  GPIO_REG(GPIO_OUTPUT_VAL) = leds;
  
  /**************************************************************************
  * Set up the PLIC
  *
  *************************************************************************/
  PLIC_init(&g_plic,
	    PLIC_CTRL_ADDR,
	    PLIC_NUM_INTERRUPTS,
	    PLIC_NUM_PRIORITIES);


  reset_demo();

  return 0;

}
