#include "nunchuk.h"

#define reg_i2c_write (*(volatile uint32_t*)0x07000000)
#define reg_i2c_read (*(volatile uint32_t*)0x07000004)

#define ADDRESS 0x52

uint32_t i2c_get_status(void) {
  return reg_i2c_write;
}

void i2c_write(uint8_t r, uint8_t d) {
  reg_i2c_write = (ADDRESS << 24) | (r << 16) | (d << 8) | 0x80000000;
}
 
void i2c_write_reg(uint8_t r) {
  reg_i2c_write = (ADDRESS << 24) | (r << 16);
}

void i2c_send_cmd(uint8_t r, uint8_t d) {
  uint32_t status;

  i2c_write(r, d);

  do {
    status = i2c_get_status();
  } while ((status >> 31) != 0);
}

void i2c_send_reg(uint8_t r) {
  uint32_t status;

  i2c_write_reg(r);

  do {
    status = i2c_get_status();
  } while ((status >> 31) != 0);
}

uint8_t i2c_read(void) { // Read without write cycle
  uint32_t status;

  reg_i2c_read = (ADDRESS << 24) | 1;
  // Nunchuk seems to need a delay
  for (uint32_t i = 0; i < 100; i++) asm volatile (""); 
	
  do {
    status = i2c_get_status();

  } while((status >> 31) != 0);
 
  return status & 0xFF;
}

