/*
 * Audio related functions and structures
 */
#ifndef __TINYSOC_AUDIO__
#define __TINYSOC_AUDIO__

#include <stdint.h>

#define FREQ_HZ_TO_DIVIDER(H) ((uint32_t)(H * 16777216 / 1000000))
#define FREQ_DIVIDER_TO_HZ(D) ((uint32_t)(D * 1000000 / 16777216))

#define REG_FREQ        0
#define REG_PULSEWIDTH  1
#define REG_WAVESELECT  2
#define REG_VOLUME      3

#define WAVE_NOISE    8
#define WAVE_SQUARE   4
#define WAVE_SAWTOOTH 2
#define WAVE_TRIANGLE 1
#define WAVE_NONE     0

#define reg_audio ((volatile uint32_t*)0x04000000)

#endif
