#include "video.h"

struct sprite_config_reg_t sprite_state[4];

void vid_init()
{
  for (int i=0; i<4; i++) {
    sprite_state[i].enable = 0;
    vid_set_all_sprite_config(i, &sprite_state[i]);
  }
}

void vid_enable_sprite(uint32_t sprite_num, uint32_t enable)
{
  sprite_state[sprite_num].enable = enable&0x01;
  vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_set_image_for_sprite(uint32_t sprite_num, uint32_t image_num)
{
    sprite_state[sprite_num].image = image_num & 0x3f;
    vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_set_sprite_pos(uint32_t sprite_num, uint32_t x, uint32_t y) {
  sprite_state[sprite_num].xpos = x & 1023;
  sprite_state[sprite_num].ypos = y & 1023;
  vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_set_all_sprite_config(uint32_t sprite_num, struct sprite_config_reg_t *sprite_config) {
  uint32_t out = (sprite_config->enable << 29)
                  | (sprite_config->colour << 26)
                  | (sprite_config->image << 20)
                  | (sprite_config->xpos << 10)
                  | (sprite_config->ypos);
  reg_video_spriteconfig[sprite_num]=out;
};

void vid_set_sprite_colour(uint32_t sprite_num, uint32_t sprite_colour)
{
  sprite_state[sprite_num].colour = sprite_colour & 0x07;
  vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_random_init_sprite_memory()
{
  for (int i = 0; i < 16384; i++) {
    reg_video_spritemem[i] = i & 0x01;
  }
}

void vid_write_sprite_memory(uint32_t image_num, const uint32_t *data)
{
  for (int y = 0; y<16; y++) {
    uint32_t rowdata = data[y];
    for (int x = 0; x<16; x++) {
      int memaddr = (image_num << 8) + (y << 4) + x;
      uint32_t sprite_pixel = ((rowdata & 0x8000) == 0x8000) ? 1 : 0;
      reg_video_spritemem[memaddr] = sprite_pixel;
      rowdata = (rowdata & 0x7fff) << 1;
    }
  }
}

void vid_set_texture_pixel(uint32_t texnum, uint32_t x, uint32_t y, uint32_t pixel)
{
  reg_video_texmem[(texnum << 6) + (y << 3) + x] = pixel;
}

void vid_set_texture(uint32_t texnum, const uint32_t *data)
{
  int ofs = 0;
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      reg_video_texmem[texnum<<6 + ofs] = data[ofs];
      ++ofs;
    }
  }
}

void vid_set_tile(uint32_t x, uint32_t y, uint32_t texture)
{
  reg_video_tilemem[(y<<6)+x]=texture;
}

void vid_set_x_ofs(uint32_t x)
{
  reg_video_xofs = x;
}

void vid_set_y_ofs(uint32_t y)
{
  reg_video_yofs = y;
}
