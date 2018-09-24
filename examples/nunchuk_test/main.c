#include <stdint.h>
#include <stdbool.h>
#include <nunchuk/nunchuk.h>
#include <uart/uart.h>

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)

uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

void irq_handler(uint32_t irqs, uint32_t* regs) { }

void delay(uint32_t n) {
  for (uint32_t i = 0; i < n; i++) asm volatile ("");
}

void main() {
    reg_uart_clkdiv = 139;

    set_irq_mask(0xff);

    // switch to dual IO mode
    reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;
 
    // Initialize the Nunchuk
    i2c_send_cmd(0x40, 0x00);

    uint32_t timer = 0;
       
    while (1) {
        timer = timer + 1;

        if ((timer & 0xffff) == 0xffff) {
          i2c_send_reg(0x00);
          delay(100);
          uint8_t jx = i2c_read();
          print("Joystick x: ");
          print_hex(jx, 2);
          print("\n");
          uint8_t jy = i2c_read();
          print("Joystick y: ");
          print_hex(jy, 2);
          print("\n");
          uint8_t ax = i2c_read();
          print("Acceleration x: ");
          print_hex(ax, 2);
          print("\n");
          uint8_t ay = i2c_read();
          print("Acceleration y: ");
          print_hex(ay, 2);
          print("\n");
          uint8_t az = i2c_read();
          print("Acceleration z: ");
          print_hex(az, 2);
          print("\n");
          uint8_t rest = i2c_read();
          print("Buttons: ");
          print_hex(rest & 3, 2);
          print("\n");
        } 
    } 
}
