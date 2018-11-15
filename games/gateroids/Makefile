FIRMWARE_DIR = ../../firmware
HDL_DIR = ../../hdl
INCLUDE_DIR = ../../libraries
VERILOG_FILES = \
	$(HDL_DIR)/top.v \
	$(HDL_DIR)/picosoc/memory/spimemio.v \
	$(HDL_DIR)/picosoc/uart/simpleuart.v \
	$(HDL_DIR)/picosoc/picosoc.v \
	$(HDL_DIR)/picorv32/picorv32.v \
	$(HDL_DIR)/picosoc/common/clock_divider.v \
	$(HDL_DIR)/picosoc/audio/audio_small.v \
	$(HDL_DIR)/picosoc/audio/pdm_dac.v \
	$(HDL_DIR)/picosoc/video/sprite_memory.v \
	$(HDL_DIR)/picosoc/video/texture_memory.v \
	$(HDL_DIR)/picosoc/video/window_memory.v \
	$(HDL_DIR)/picosoc/video/tile_colour_memory.v \
	$(HDL_DIR)/picosoc/video/VGASyncGen.v \
	$(HDL_DIR)/picosoc/video/video_lcd.v \
	$(HDL_DIR)/picosoc/ili9341/ili9341.v \
	$(HDL_DIR)/picosoc/gpio/gpio.v

PCF_FILE = $(HDL_DIR)/fpgc_pcb.pcf
LDS_FILE = $(FIRMWARE_DIR)/sections.lds
START_FILE = $(FIRMWARE_DIR)/start.S
C_FILES = main.c \
    song_petergunn.c \
  	$(INCLUDE_DIR)/video/video.c \
		$(INCLUDE_DIR)/audio/audio.c \
		$(INCLUDE_DIR)/gpio/gpio.c \
		$(INCLUDE_DIR)/songplayer/songplayer.c
DEFINES =  -Dgpio -Dvga -Dili9341 -Dpdm_audio
#DEFINES =  -Dgpio -Dvga -Dili9341

include $(HDL_DIR)/tiny_soc.mk
