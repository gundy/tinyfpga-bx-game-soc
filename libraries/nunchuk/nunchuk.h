#ifndef __NUNCHUK_H__
#define __NUNCHUK_H__

#include <stdint.h>

uint32_t i2c_get_status(void);

void i2c_write(uint8_t r, uint8_t d);

void i2c_writei_reg(uint8_t r);

void i2c_send_cmd(uint8_t r, uint8_t d);

void i2c_send_reg(uint8_t r);

uint8_t i2c_read(void);

#endif
