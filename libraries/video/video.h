
/*
 * Video related functions and structures
 */

#ifndef __TINYSOC_VIDEO__
#define __TINYSOC_VIDEO__

#include <stdint.h>

#define reg_video_texmem       ((volatile uint32_t*)0x05100000)
#define reg_video_tilemem      ((volatile uint32_t*)0x05200000)
#define reg_video_spritemem    ((volatile uint32_t*)0x05300000)
#define reg_video_xofs        (*(volatile uint32_t*)0x05000000)
#define reg_video_yofs        (*(volatile uint32_t*)0x05000004)
#define reg_video_spriteconfig ((volatile uint32_t*)0x05000008)

void vid_init();

void vid_set_texture(uint32_t texnum, const uint32_t *data);
void vid_set_texture_pixel(uint32_t texnum, uint32_t x, uint32_t y, uint32_t pixel);
void vid_set_tile(uint32_t x, uint32_t y, uint32_t texture);

void vid_set_x_ofs(uint32_t x);
void vid_set_y_ofs(uint32_t y);

struct sprite_config_reg_t {
  uint32_t enable;
  uint32_t colour;
  uint32_t image;
  uint32_t xpos;
  uint32_t ypos;
};

void vid_enable_sprite(uint32_t sprite_num, uint32_t enable);
void vid_set_image_for_sprite(uint32_t sprite_num, uint32_t image_num);
void vid_set_sprite_pos(uint32_t sprite_num, uint32_t x, uint32_t y);
void vid_set_sprite_colour(uint32_t sprite_num, uint32_t sprite_colour);
void vid_set_all_sprite_config(uint32_t sprite_num, struct sprite_config_reg_t *config);
void vid_write_sprite_memory(uint32_t image_num, const uint32_t *data);
void vid_random_init_sprite_memory();

#endif
