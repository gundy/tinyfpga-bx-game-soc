#include <stdint.h>
#include <stdbool.h>

#include <audio/audio.h>
#include <video/video.h>
#include <songplayer/songplayer.h>
#include <uart/uart.h>
#include <sine_table/sine_table.h>
#include "graphics_data.h"

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_leds  (*(volatile uint32_t*)0x03000000)

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss, _heap_start;

extern const struct song_t song_pacman;

uint32_t counter_frequency = 16000000/50;  /* 50 times per second */
uint32_t led_state = 0x00000000;

uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

uint32_t set_timer_counter(uint32_t val); asm (
    ".global set_timer_counter\n"
    "set_timer_counter:\n"
    ".word 0x0a05650b\n"
    "ret\n"
);

void setup_screen() {
  print("Vid init..\n");

  vid_init();

  print("Vid set offsets..\n");
  vid_set_x_ofs(32<<3);
  vid_set_y_ofs(32<<3);
  int tex,x,y;

  print("Vid set textures..\n");
  for (tex = 0; tex < 64; tex++) {
    for (x = 0; x < 8; x++) {
      for (y = 0 ; y < 8; y++) {
        int texrow = tex >> 3;   // 0-7, row in texture map
        int texcol = tex & 0x07; // 0-7, column in texture map
        int pixx = (texcol<<3)+x;
        int pixy = (texrow<<3)+y;
        uint32_t pixel = texture_data[(pixy<<6)+pixx];
        vid_set_texture_pixel(tex, x, y, pixel);
      }
    }
  }
  print("Vid set tiles..\n");
  for (x = 0; x < 64; x++) {
    for (y = 0; y < 64; y++) {
      vid_set_tile(x,y,tile_data[(y<<6)+x]);
    }
  }
  print("Vid init sprites..\n");

  //vid_random_init_sprite_memory();
  uint32_t cols[] = { 1,2,3,4,5,6,7,6 };
  vid_write_sprite_memory(0, sprites[0]);
  for (int i=0; i<8; i++) {
    vid_set_sprite_pos(i,64+(i<<6),64+(i<<5));
    vid_set_sprite_colour(i,cols[i]);
    vid_set_image_for_sprite(i, 0);
    vid_enable_sprite(i, 1);
  }
}

void irq_handler(uint32_t irqs, uint32_t* regs)
{
  /* fast IRQ (4) */
  if ((irqs & (1<<4)) != 0) {
		// print_str("[EXT-IRQ-4]");
	}

  /* slow IRQ (5) */
	if ((irqs & (1<<5)) != 0) {
    // print_str("[EXT-IRQ-5]");
	}

  /* timer IRQ */
	if ((irqs & 1) != 0) {
    // retrigger timer
    set_timer_counter(counter_frequency);

    led_state = led_state ^ 0x01;
    reg_leds = led_state;
    songplayer_tick();
  }

}

void main() {

    reg_uart_clkdiv = 138;  // 16,000,000 / 115,200
    print("\n\nBooting..\n");
    print("Enabling IRQs..\n");
    set_irq_mask(0x00);

    print("Setting up screen..\n");
    setup_screen();

    print("Initialising song player..\n");
    songplayer_init(&song_pacman);

    print("Switching to dual IO SPI mode..\n");

    // switch to dual IO mode
    reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

    print("Playing song and blinking\n");

    // set timer interrupt to happen 1/50th sec from now
    // (the music routine runs from the timer interrupt)
    set_timer_counter(counter_frequency);

    int xofs = 0;
    int xincr = 1;
    int yofs = 15<<3;
    int yincr = 1;

    int maxx = (63-40) << 3;
    int maxy = (63-30) << 3;

    uint32_t time_waster = 0;
    uint32_t sprite_pos = 0;
    while (1) {
        time_waster = time_waster + 1;
        if ((time_waster & 0x7ff) == 0x7ff) {
          /* update screen tile map offsets */
          xofs += xincr;
          if ((xofs >= maxx) || (xofs == 0)) {
            xincr = -xincr;
          }
          yofs += yincr;
          if ((yofs == 0) || (yofs >= maxy)) {
            yincr = -yincr;
          }
          vid_set_x_ofs(xofs&511);
          vid_set_y_ofs(yofs&511);

          /* update sprite locations */
          for (int i=0; i<8; i++) {
            int xp = 160+sine_table[(sprite_pos+(i<<4))&0xff];
            int yp = 120+sine_table[64+(sprite_pos+(i<<4))&0xff];
            vid_set_sprite_pos(i,xp,yp);
          }
          sprite_pos++;
        }
    }
}
