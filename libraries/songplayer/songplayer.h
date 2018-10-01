#ifndef __SONG_PLAYER_H__
#define __SONG_PLAYER_H__

#include <stdint.h>

#define FIRST_USER_INSTRUMENT 5  // 1,2,3,4 = percussion


struct envelope_t {
  int32_t num_points;
  uint8_t points[];
};

struct song_instrument_t {
  int32_t waveform_select :4;
  int32_t pulsewidth : 12;
  int32_t pulsewidth_modulation_depth : 8;
  int32_t pulsewidth_modulation_speed : 8;
  int32_t vibrato_depth : 8;
  int32_t vibrato_speed : 8;
  int32_t default_volume: 8;
  int32_t volume_rampdown_rate: 8;
  int32_t envelope_enable: 1;
  const struct envelope_t *envelope;
  //uint32_t tremolo_depth;
  //uint32_t tremolo_speed;
  //uint32_t effect;
};

struct globalctrl_t {
  int32_t active;
  int32_t ticks_per_div;

  int32_t next_pos_override; /* override for next song position */
  int32_t song_pos;
  int32_t song_row;
  int32_t tick_div_count;
  int32_t sound_fx_bar;
  int32_t sound_fx_row;
};

struct songnote_expanded_t {
  uint32_t instrument :5;
  uint32_t new_note :7;    /* 7 bits for note */
  uint32_t volume: 8;
  uint32_t effect: 4;
  uint32_t effect_parameter: 8;
};

struct songnote_shortform_t {
  uint32_t i :5;
  uint32_t n :7;    /* 7 bits for note */
  uint32_t v :8;  /* how long in 1/50th second increments to hold gate on */
  uint32_t e :4;
  uint32_t p :8;
};

union songnote_t {
  struct songnote_expanded_t note;
  struct songnote_shortform_t n;
  uint32_t raw;
};

struct channelctrl_t {
  union songnote_t note;
  int32_t note_on_time;
  int8_t volume;
};


struct song_bar_t {
  union songnote_t notes[16];
};

struct song_pattern_t {
  uint32_t bar[4];
};

struct song_t {
  int32_t rows_per_bar;
  int32_t song_length;
  int32_t ticks_per_div;

  struct song_instrument_t instruments[16];
  int32_t pattern_map[256];
  struct song_bar_t bars[256];
  struct song_pattern_t patterns[256];
};


// instruments
// drum instruments (0-8)
//  - kick (noise @ 1/50s followed by pulse wave sliding down in frequency)
//  - high-hat (high frequency noise, short duration)
//  -
// normal instruments (8-15)
//
// effects
// - octave arpeggio
// - normal arpeggio @ notes
// - slide pulsewidth @ speed
// - slide up  (flag for glissando)
// - slide down
// - slide to note
// - slide + octave arpeggio
// - key-on / key-off
// - vol slide
// - filter on/off for current channel
// - global filter controls
// - set ticks per div

// call to load a new song into memory
void songplayer_init(const struct song_t *song);

// call to start playing the song (from the given position)
void songplayer_start(int pos);

// call to stop playing the song
void songplayer_stop();

// this needs to be called @ 50Hz
void songplayer_tick();

// call this to trigger a "sound effect" from the given song bar (this is played on channel 4).
void songplayer_trigger_effect(uint32_t bar_num);

#endif
