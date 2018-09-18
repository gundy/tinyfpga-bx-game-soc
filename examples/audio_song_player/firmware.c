#include <stdint.h>
#include <stdbool.h>

#include "audio.h"
#include "songplayer.h"
#include "uart.h"

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

//#define irq_handler_addr (*(volatile uint32_t*)0x00000008)

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_leds  (*(volatile uint32_t*)0x03000000)

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss,_heap_start;

extern const struct song_t song_petergun;

uint32_t counter_frequency = 16000000/50;  /* 50 times per second */
uint32_t led_state = 0x00000000;

uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

uint32_t set_timer_counter(uint32_t val); asm (
    ".global set_timer_counter\n"
    "set_timer_counter:\n"
    ".word 0x0a05650b\n"
    "ret\n"
);

void play_simple_note() {
  reg_audio[0]=0x00224;     /* C0 */
  reg_audio[1]=2048;        /* 50% duty cycle */
  reg_audio[2]=0x08040000;  /* square wave */
  reg_audio[3]=255;         /* volume 255 */
}

void irq_handler(uint32_t irqs, uint32_t* regs)
{
  /* fast IRQ (4) */
  if ((irqs & (1<<4)) != 0) {
		// print_str("[EXT-IRQ-4]");
	}

  /* slow IRQ (5) */
	if ((irqs & (1<<5)) != 0) {
    // print_str("[EXT-IRQ-5]");
	}

  /* timer IRQ */
	if ((irqs & 1) != 0) {
    // retrigger timer
    set_timer_counter(counter_frequency);

    led_state = led_state ^ 0x01;
    reg_leds = led_state;
    songplayer_tick();
  }

}

void main() {

    reg_uart_clkdiv = 138;  // 16,000,000 / 115,200
    print("\n\nBooting..\n");
    print("Enabling IRQs..\n");
    set_irq_mask(0x00);

    songplayer_init(&song_petergun);

    // zero out .bss section
    // commented out because this is done in start.S
    // for (uint32_t *dest = &_sbss; dest < &_ebss;) {
    //     *dest++ = 0;
    // }

    print("Switching to dual IO SPI mode..\n");

    // switch to dual IO mode
    reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

    print("Playing song and blinking\n");
    set_timer_counter(counter_frequency);

//    play_simple_note();

    // blink the user LED
    uint32_t time_waster = 0;
    while (1) {
        time_waster = time_waster + 1;
    }
}
