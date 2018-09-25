#include "audio.h"

void audio_set_global_volume(uint32_t volume)
{
  uint32_t v = volume;
  if (v > 255) {
    v = 255;
  }
  reg_audio[REG_GLOBAL_VOLUME] = v;
}
