#include "gpio.h"

void gpio_write_leds(uint32_t led_state) {
  reg_gpio = led_state;
}

uint32_t gpio_read() {
  return reg_gpio;
};

uint32_t gpio_is_pressed(enum button_t button) {
  return (reg_gpio & button) != 0;
}
