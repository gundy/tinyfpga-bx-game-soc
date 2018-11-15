#include <stdint.h>
#include <stdbool.h>

#include <audio/audio.h>
#include <video/video.h>
#include <songplayer/songplayer.h>
#include <uart/uart.h>
#include <sine_table/sine_table.h>
#include <gpio/gpio.h>
#include <nunchuk/nunchuk.h>

#include "includes/palette.h"
#include "includes/sprites.h"
#include "includes/textures.h"
#include "includes/tile_map.h"

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)

#define NUM_SPRITES (8)

const uint32_t counter_frequency = 16000000/50;  /* 50 times per second */
uint32_t tick_counter;
uint32_t songplayer_active;

uint32_t game_pos_x;
uint32_t game_pos_y;

extern const struct song_t song_petergunn;

enum GAME_STATE {
  HOME_INIT,   // need to initialise the home screen
  HOME_ACTIVE, // home screen initialised; need to play home screen animations
  GAME_INIT,   // game board needs to be initialised
  GAME_ACTIVE  // game is active
};

enum GAME_STATE state;
int ship_orientation = 0;

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
  if ((irqs & 32) != 0) {  /* video interrupt; horizontal line counter match */
    // horizontal line interrupt fired
  }


  /* timer IRQ */
  if ((irqs & 1) != 0) {
    // retrigger timer
    if (songplayer_active) {
      set_timer_counter(counter_frequency);
      songplayer_tick();
    }
    // Update tick counter
    // tick_counter++;
    // gpio_write_leds(tick_counter&0x01);

    gpio_write_leds(gpio_read()&0x01);
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

  for (int x=0; x<40; x++) {
    for (int y=0; y<2; y++) {
      vid_write_window_memory(x,y,32);
    }
  }

  for (int i = 0; i<23; i++) {
    vid_write_window_memory(5+i, 0, (uint32_t)(("Score: 00000   Lives: 5")[i]));
//    vid_write_window_memory(5+i, 1, (uint32_t)(("Score: 00000   Lives: 0")[i]));
  }

  vid_disable_window();

  // set bullets offscreen
  vid_set_bullet_location(0,330,245);
  vid_set_bullet_location(1,330,245);

  // disable horizontal line interrupt
  // (raster never reaches line 250)
  vid_set_raster_interrupt_line(250);

//  vid_enable_window(28,29);

  // Set up the tile memory
  for (int y = 0; y < 32; y++) {
    for (int x = 0; x < 64; x++) {
      vid_set_tile(x,y,32);
    }
  }

}

static uint32_t ship_image[12] = { 0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1 };
static uint32_t ship_flip[12] =  { 0, 0, 0, 0, 1, 1, 1, 3, 3, 2, 2, 2 };

void place_ship(int sprite_num, int x, int y, int exhaust, int orientation) {
  struct sprite_config_reg_t config;
  config.enable=1;
  config.palette=6;
  config.xpos=x;
  config.ypos=y;

  config.image  = ship_image[orientation] + (exhaust<<2);
  config.flipxy = ship_flip[orientation];
  vid_set_all_sprite_config(sprite_num, &config);
}

void setup_game_screen() {
  // disable music
  songplayer_active = 0;
  audio_set_global_volume(0x00);


  game_pos_x = 0;
  game_pos_y = 0;
  vid_set_x_ofs(game_pos_x);
  vid_set_y_ofs(game_pos_y);

  for (int y = 0; y < 32; y++) {
    // y * 64 + x
    int tileofs = (y<<6);
    for (int x = 0; x < 64; x++) {
      vid_set_tile(x,y,playfield_tilemap[tileofs++]); // bits 11-8 of tile are colour data
    }
  }

  // disable all sprites
  struct sprite_config_reg_t config;
  config.flipxy=0;
  config.enable=0;
  config.palette=0;
  config.image=24;
  config.xpos=114;
  config.ypos=20;
  vid_set_all_sprite_config(0, &config);
  vid_set_all_sprite_config(1, &config);
  vid_set_all_sprite_config(2, &config);
  vid_set_all_sprite_config(3, &config);
  vid_set_all_sprite_config(4, &config);
  vid_set_all_sprite_config(5, &config);
  vid_set_all_sprite_config(6, &config);
  vid_set_all_sprite_config(7, &config);

  // set bullets offscreen
  vid_set_bullet_location(0,330,245);
  vid_set_bullet_location(1,330,245);

  for (int i = 0; i<40; i++) {
    vid_write_window_memory(i, 0, (uint32_t)(("                                        ")[i]));
    vid_write_window_memory(i, 1, (uint32_t)((" Level: 0    Score: 0000000    Lives: 0 ")[i]));
  }

  vid_enable_window(28,29);

}

void animate_game_screen() {
  place_ship(5, 152, 112, 1, ship_orientation);
  if (gpio_is_pressed(BUTTON_RIGHT)) {
    ship_orientation+=1;
    if (ship_orientation > 11)
      ship_orientation = 0;
  }
  if (gpio_is_pressed(BUTTON_LEFT)) {
    ship_orientation-=1;
    if (ship_orientation < 0) {
      ship_orientation = 11;
    }
  }

  game_pos_x = (game_pos_x+1)&0x1ff;
  game_pos_y = (game_pos_y+3)&0xff;
  vid_set_x_ofs(game_pos_x);
  vid_set_y_ofs(game_pos_y);

  if (gpio_is_pressed(BUTTON_X) || gpio_is_pressed(BUTTON_Y)) {
    state = HOME_INIT;
  }
}


void setup_home_screen() {

    vid_set_x_ofs(0);
    vid_set_y_ofs(0);
    vid_disable_window();

    // set bullets offscreen
    vid_set_bullet_location(0,330,245);
    vid_set_bullet_location(1,330,245);


      for (int y = 0; y < 32; y++) {
        // y * 64 + x
        int tileofs = (y<<6);
        for (int x = 0; x < 64; x++) {
          vid_set_tile(x,y,mainscreen_tile_map[tileofs++]); // bits 11-8 of tile are colour data
        }
      }
    struct sprite_config_reg_t config;
    config.flipxy=0;
    config.enable=1;
    config.palette=0;
    config.image=24;
    config.xpos=114;
    config.ypos=20;
    vid_set_all_sprite_config(0, &config);
    config.image=25;
    config.xpos = 130;
    vid_set_all_sprite_config(1, &config);
    config.image=26;
    config.xpos = 146;
    vid_set_all_sprite_config(2, &config);
    config.image=27;
    config.xpos = 162;
    vid_set_all_sprite_config(3, &config);
    config.image=28;
    config.xpos = 178;
    vid_set_all_sprite_config(4, &config);

    // set up music
    songplayer_init(&song_petergunn);
    songplayer_active = 1;
    audio_set_global_volume(0xff);
    // set timer interrupt to happen 1/50th sec from now
    // (the music routine runs from the timer interrupt)
    set_timer_counter(counter_frequency);
}

void animate_home_screen() {
  place_ship(5, 214, 20, 1, 11-ship_orientation);
  place_ship(6, 80, 20, 0, ship_orientation);
  if ((++ship_orientation) > 11) {
    ship_orientation=0;
  }
  if (gpio_is_pressed(BUTTON_A) || gpio_is_pressed(BUTTON_B)) {
    state = GAME_INIT;
  }
}


// Main entry point
void main() {
  //reg_leds = 0x01;
  //reg_uart_clkdiv = 138;  // 16,000,000 / 115,200

//  print("Initialising..\n");
  reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

  setup_screen();
  state = HOME_INIT;

  uint32_t time_waster = 0;


  // Main loop
  while (1) {
    time_waster = time_waster + 1;
    if (time_waster > 2000) {
      time_waster = 0;
      switch(state) {
        case HOME_INIT:
          setup_home_screen();
          state = HOME_ACTIVE;
          break;
        case HOME_ACTIVE:
          animate_home_screen();
          break;
        case GAME_INIT:
          setup_game_screen();
          state = GAME_ACTIVE;
          break;
        case GAME_ACTIVE:
          animate_game_screen();
          break;
      }
    }
  }
}
