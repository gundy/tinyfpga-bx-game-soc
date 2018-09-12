#include <stdint.h>
#include <stdbool.h>

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)
#define reg_leds  (*(volatile uint32_t*)0x03000000)
#define reg_audio ((volatile uint32_t*)0x04000000)

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss,_heap_start;

uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart_data = c;
}

void print(const char *p)
{
	while (*p)
		putchar(*(p++));
}

void main() {
    set_irq_mask(0xff);

    reg_uart_clkdiv = 138;  // 16,000,000 / 115,200
    print("Booting..\n");

    // zero out .bss section
    for (uint32_t *dest = &_sbss; dest < &_ebss;) {
        *dest++ = 0;
    }

    print("Switching to dual IO SPI mode..\n");

    // switch to dual IO mode
    reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

    print("Playing triangle wave on voice #1 @ 50Hz ..\n");

    // start a triangle wave @ 50 Hz
    *(reg_audio+12) = 0x00;        // voice 1, gate off

    *(reg_audio+0)  = 838;         // frequency = fOut * 16777216 / 1000000
    *(reg_audio+4)  = 2048;        // 50% duty cycle if pulse wave selected
    *(reg_audio+8)  = 0x080111fa;  // voice enabled, triangle wave, ADSR envelope
    *(reg_audio+12) = 0x01;        // gate on

    // blink the user LED
    uint32_t led_timer = 0;

    while (1) {
        reg_leds = led_timer >> 16;
        led_timer = led_timer + 1;
    }
}
