#include <stdint.h>
#include <stdbool.h>

#include <audio/audio.h>
#include <video/video.h>
#include <songplayer/songplayer.h>
#include <uart/uart.h>
#include <nunchuk/nunchuk.h>

#include "includes/palette.h"
#include "includes/sprites.h"
#include "includes/textures.h"
#include "includes/tile_map.h"

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_leds  (*(volatile uint32_t*)0x03000000)

#define NUM_SPRITES (8)

const uint32_t counter_frequency = 16000000/50;  /* 50 times per second */
uint32_t tick_counter;

// Set the IRQ mask
uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

// Set the timer counter
uint32_t set_timer_counter(uint32_t val); asm (
    ".global set_timer_counter\n"
    "set_timer_counter:\n"
    ".word 0x0a05650b\n"
    "ret\n"
);

// Interrupt handling used for playing audio
void irq_handler(uint32_t irqs, uint32_t* regs)
{
  /* timer IRQ */
  if ((irqs & 1) != 0) {
    // retrigger timer
    set_timer_counter(counter_frequency);
//    print(".\n");
  }
}

// Set up all the graphics data for board portion of screen
void setup_screen() {
  // Initialse the video and set offset to (0,0)
  vid_init();
  vid_set_x_ofs(0);
  vid_set_y_ofs(0);

  // set up the palette
  for (int i=0; i<16; i++) {
    vid_set_palette(i,palette_data[i]);
  }

  for (int i=0; i<16; i++) {
    vid_set_sub_palette(i,sub_palette_data[i]);
  }

  // copy sprite data into sprite memory
  vid_write_sprite_memory(sprite_data);

  // copy texture data into texture memory
  vid_write_texture_memory(texture_data);

  // Set up the tile memory
  for (int y = 0; y < 30; y++) {
    // y * 40 = (y*32)+(y*8)
    int tileofs = (y<<5)+(y<<3);
    for (int x = 0; x < 40; x++) {
      vid_set_tile(x,y,0x00000100|tile_map[tileofs++]); // bits 11-8 of tile are colour data (initiase all to 1).
    }
  }

  struct sprite_config_reg_t config;
  config.flipxy=0;
  config.enable=1;
  config.palette=7;
  config.image=2;
  config.xpos=100;
  config.ypos=100;
  vid_set_all_sprite_config(0, &config);
  config.xpos=116;
  config.flipxy=2;
  vid_set_all_sprite_config(1, &config);
  config.xpos=150;
  config.ypos=150;
  config.flipxy=0;
  config.palette=12;
  config.image=1;
  vid_set_all_sprite_config(2,&config);
  config.image=0;
  config.palette=2;
  config.xpos=110;
  vid_set_all_sprite_config(3,&config);


}

const uint32_t sub_palettes[4]={ 0xfc60, 0xf710, 0xfb50, 0xfd40 };

// Main entry point
void main() {
  //reg_leds = 0x01;
  reg_uart_clkdiv = 138;  // 16,000,000 / 115,200

  print("Initialising..\n");
  reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

  setup_screen();


  // set timer interrupt to happen 1/50th sec from now
  // (the music routine runs from the timer interrupt)
  //set_timer_counter(counter_frequency);



  uint32_t time_waster = 0;

  // Main loop
  while (1) {
    time_waster = time_waster + 1;
    if ((time_waster & 0xffff) == 0xffff) {
      // Update tick counter
      tick_counter++;
      reg_leds=tick_counter&0x01;
      vid_set_sub_palette(1, sub_palettes[1]);
    }
  }
}
