
/*
 * Video related functions and structures
 */

#ifndef __TINYSOC_VIDEO__
#define __TINYSOC_VIDEO__

#include <stdint.h>

#define reg_video_texmem ((volatile uint32_t*)0x05100000)
#define reg_video_tilemem ((volatile uint32_t*)0x05200000)
#define reg_video_xofs (*(volatile uint32_t*)0x05000000)
#define reg_video_yofs (*(volatile uint32_t*)0x05000004)

void vid_set_texture(uint32_t texnum, const uint32_t *data);
void vid_set_tile(uint32_t x, uint32_t y, uint32_t texture);
void vid_set_x_ofs(uint32_t x);
void vid_set_y_ofs(uint32_t y);

#endif
