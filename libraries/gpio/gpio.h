#ifndef __TINYSOC_GPIO__
#define __TINYSOC_GPIO__

#include <stdint.h>

#define reg_gpio  (*(volatile uint32_t*)0x03000000)

#define GPIO_UP    (1)
#define GPIO_RIGHT (2)
#define GPIO_LEFT  (4)
#define GPIO_DOWN  (8)
#define GPIO_X     (16)
#define GPIO_Y     (32)
#define GPIO_A     (64)
#define GPIO_B     (128)

enum button_t {
  BUTTON_UP = GPIO_UP,
  BUTTON_DOWN = GPIO_DOWN,
  BUTTON_LEFT = GPIO_LEFT,
  BUTTON_RIGHT = GPIO_RIGHT,
  BUTTON_X = GPIO_X,
  BUTTON_Y = GPIO_Y,
  BUTTON_A = GPIO_A,
  BUTTON_B = GPIO_B
};

void gpio_write_leds(uint32_t led_state);
uint32_t gpio_read();
uint32_t gpio_is_pressed(enum button_t button);

#endif
