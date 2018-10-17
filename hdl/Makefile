HDL_DIR = .
VERILOG_FILES = \
	$(HDL_DIR)/top.v \
	$(HDL_DIR)/picosoc/memory/spimemio.v \
	$(HDL_DIR)/picosoc/uart/simpleuart.v \
	$(HDL_DIR)/picosoc/picosoc.v \
	$(HDL_DIR)/picorv32/picorv32.v \
	$(HDL_DIR)/picosoc/common/clock_divider.v \
	$(HDL_DIR)/picosoc/audio/audio.v \
	$(HDL_DIR)/picosoc/audio/pdm_dac.v \
	$(HDL_DIR)/picosoc/video/sprite_memory.v \
	$(HDL_DIR)/picosoc/video/texture_memory.v \
	$(HDL_DIR)/picosoc/video/tile_memory.v \
	$(HDL_DIR)/picosoc/video/sprite.v \
	$(HDL_DIR)/picosoc/video/VGASyncGen.v \
	$(HDL_DIR)/picosoc/video/video_vga.v \
	$(HDL_DIR)/picosoc/ili9341/ili9341.v \
  $(HDL_DIR)/picosoc/nunchuk/I2C_master.v \
	$(HDL_DIR)/picosoc/i2c/i2c.v \
	$(HDL_DIR)/picosoc/gpio/gpio.v

PCF_FILE = $(HDL_DIR)/portable.pcf
DEFINES = -Dpdm_audio -Dgpio -Dvga -Di2c

include $(HDL_DIR)/tiny_soc.mk
