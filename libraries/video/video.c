#include "video.h"

struct sprite_config_reg_t sprite_state[8];
uint32_t vid_xyofs;

void vid_init()
{
//  for (int i=0; i<8; i++) {
//    sprite_state[i].enable = 0;
//    vid_set_all_sprite_config(i, &sprite_state[i]);
//  }
  vid_xyofs = 0;
}

void vid_set_palette(uint32_t idx, uint32_t rrggbb)
{
    reg_video_palette[idx]=(uint32_t)rrggbb;
}

void vid_set_sub_palette(uint32_t idx, uint32_t pal4)
{
    reg_video_sub_palette[idx]=((uint32_t)pal4);
}

void vid_enable_sprite(uint32_t sprite_num, uint32_t enable)
{
  sprite_state[sprite_num].enable = enable&0x01;
  vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_set_image_for_sprite(uint32_t sprite_num, uint32_t image_num)
{
    sprite_state[sprite_num].image = image_num & 0x1f;
    vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_set_sprite_pos(uint32_t sprite_num, uint32_t x, uint32_t y) {
  sprite_state[sprite_num].xpos = x & 511;
  sprite_state[sprite_num].ypos = y & 511;
  vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_set_all_sprite_config(uint32_t sprite_num, struct sprite_config_reg_t *sprite_config) {
  uint32_t out =  (sprite_config->flipxy << 29)
                  | (sprite_config->enable << 28)
                  | (sprite_config->palette << 24)
                  | (sprite_config->image << 19)
                  | (sprite_config->xpos << 9)
                  | (sprite_config->ypos);
  reg_video_spriteconfig[sprite_num]=out;
};

void vid_set_sprite_flipxy(uint32_t sprite_num, uint32_t flipxy)
{
  sprite_state[sprite_num].flipxy = flipxy&0x03;
  vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_set_sprite_palette(uint32_t sprite_num, uint32_t sprite_palette)
{
  sprite_state[sprite_num].palette = sprite_palette & 0x0f;
  vid_set_all_sprite_config(sprite_num, &sprite_state[sprite_num]);
}

void vid_random_init_sprite_memory()
{
  for (int i = 0; i < 511; i++) {
    reg_video_spritemem[i] = i & 0xffff;
  }
}

/* designed to work with a 128x128 image (8x8 tiles of 16x16 sprites) */
void vid_write_sprite_memory(const uint32_t *data)
{
  for (int image_num = 0; image_num < 32; image_num++) {
    int tex_row = (image_num&0x38)>>3;
    int tex_col = (image_num&0x07);
    uint32_t sprite_pixels;
    int memaddr = (image_num << 4);
    for (int y = 0; y<16; y++) {
      int dataaddr = (tex_row<<11) + (y<<7) + (tex_col<<4);
      sprite_pixels=0;
      for (int x = 0; x<16; x++) {
        sprite_pixels=(sprite_pixels<<2) | data[dataaddr++];
      }
      reg_video_spritemem[memaddr++] = sprite_pixels;
    }
  }
}

void vid_write_texture_memory(const uint32_t *data)
{
  // Set up the 256 8x8 textures
  // texture data is arranged in a 16x16 grid of 8x8 squares (image size is 128x128)
  for (int tex = 0; tex < 256; tex++) {
    int texrow = tex >> 4;   // 0-15, row in texture map
    int texcol = tex & 0x0f; // 0-15, column in texture map
    for (int y = 0; y < 8; y++) {
      int pixel_data_ofs = (texrow<<10)+(y<<7)+(texcol<<3);
      int texmem_offset =  (tex << 6) + (y << 3);
      for (int x = 0 ; x < 8; x++) {
        reg_video_texmem[texmem_offset++] = data[pixel_data_ofs++];
      }
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
      reg_video_texmem[(texnum<<6) + ofs] = data[ofs];
      ++ofs;
    }
  }
}

void vid_set_tile(uint32_t x, uint32_t y, uint32_t texture)
{
  reg_video_tilemem[(y<<6)+x]=texture;
}

void vid_set_y_ofs(uint32_t y)
{
  vid_xyofs = (vid_xyofs & 0x0000ffff) | (y << 16);
  reg_video_xyofs = vid_xyofs;
}

void vid_set_x_ofs(uint32_t x)
{
  vid_xyofs = (vid_xyofs & 0xffff0000) | x;
  reg_video_xyofs = vid_xyofs;
}

void vid_enable_window(uint32_t line_start, uint32_t line_end)
{
    reg_video_windowctrl = (0x80000000 | (line_end << 8) | (line_start));
}

void vid_disable_window()
{
    reg_video_windowctrl = 0;
}

void vid_write_window_memory(uint32_t x, uint32_t y, uint32_t value)
{
    reg_video_window_ram[(y<<6) + x] = value;
}

void vid_set_raster_interrupt_line(uint32_t y)
{
  reg_video_interrupt_y = y&0xff;
}
