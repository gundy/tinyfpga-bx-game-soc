FIRMWARE_DIR = ../../firmware
HDL_DIR = ../../hdl
INCLUDE_DIR = ../../libraries
VERILOG_FILES = \
	$(HDL_DIR)/top.v \
	$(HDL_DIR)/picosoc/memory/spimemio.v \
	$(HDL_DIR)/picosoc/uart/simpleuart.v \
	$(HDL_DIR)/picosoc/picosoc.v \
	$(HDL_DIR)/picorv32/picorv32.v \
  $(HDL_DIR)/picosoc/nunchuk/I2C_master.v \
	$(HDL_DIR)/picosoc/i2c/i2c.v \
	$(HDL_DIR)/picosoc/gpio/gpio.v

PCF_FILE = $(HDL_DIR)/pins.pcf
LDS_FILE = $(FIRMWARE_DIR)/sections.lds
START_FILE = $(FIRMWARE_DIR)/start.S
C_FILES = main.c \
	$(INCLUDE_DIR)/uart/uart.c \
	$(INCLUDE_DIR)/nunchuk/nunchuk.c
DEFINES = -Dgpio -Di2c

include $(HDL_DIR)/tiny_soc.mk
