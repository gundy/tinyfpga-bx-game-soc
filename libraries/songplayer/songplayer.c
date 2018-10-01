#include <stddef.h>
#include <audio/audio.h>
#include <songplayer/songplayer.h>
#include <uart/uart.h>

const struct song_t *player_song = NULL;
struct globalctrl_t globalctrl = {
  .song_row = -1,
  .song_pos = 0,
  .ticks_per_div = 6,
  .tick_div_count = 0,
  .sound_fx_row = 16,
  .sound_fx_bar = 0,
  .active = 0
};
struct channelctrl_t channelctrl[4] = {
  {.note.raw = 0, .note_on_time = 0 },
  {.note.raw = 0, .note_on_time = 0 },
  {.note.raw = 0, .note_on_time = 0 }
};


const uint32_t note_to_freq[] = {
  0x00000,
  // C       C#      D      D#       E       F       F#     G        G#     A        A#      B
  0x00089,0x00091,0x00099,0x000a3,0x000ac,0x000b7,0x000c1,0x000cd,0x000d9,0x000e6,0x000f4,0x00102, // octave -2
  0x00112,0x00122,0x00133,0x00146,0x00159,0x0016e,0x00183,0x0019b,0x001b3,0x001cd,0x001e8,0x00205, // octave -1
  0x00224,0x00245,0x00267,0x0028c,0x002b3,0x002dc,0x00307,0x00336,0x00366,0x0039a,0x003d1,0x0040b, // octave 0
  0x00449,0x0048a,0x004cf,0x00518,0x00566,0x005b8,0x0060f,0x0066c,0x006cd,0x00735,0x007a3,0x00817, // octave 1
  0x00892,0x00915,0x0099f,0x00a31,0x00acd,0x00b71,0x00c1f,0x00cd8,0x00d9b,0x00e6a,0x00f46,0x0102e, // octave 2
  0x01125,0x0122a,0x0133e,0x01463,0x0159a,0x016e2,0x0183f,0x019b0,0x01b37,0x01cd5,0x01e8c,0x0205d, // octave 3
  0x0224a,0x02454,0x0267d,0x028c7,0x02b34,0x02dc5,0x0307e,0x03360,0x0366f,0x039ab,0x03d19,0x040bb, // octave 4
  0x04495,0x048a8,0x04cfb,0x0518e,0x05668,0x05b8b,0x060fd,0x066c1,0x06cde,0x07357,0x07a33,0x08177, // octave 5
  0x0892a,0x09151,0x099f6,0x0a31d,0x0acd0,0x0b717,0x0c1fa,0x0cd83,0x0d9bc,0x0e6ae,0x0f466,0x102ee, // octave 6
  0x11254,0x122a3,0x133ec,0x1463b,0x159a1,0x16e2f,0x183f5,0x19b07,0x1b378,0x1cd5c,0x1e8cc,0x205dc, // octave 7
  0x224a8,0x24547,0x267d8,0x28c77,0x2b343,0x2dc5e,0x307ea  // ,0x3360e                             // octave 8
};


void songplayer_init(const struct song_t* song) {
  // reset song player to initial position
  globalctrl.song_pos = 0;
  globalctrl.song_row = -1;
  globalctrl.next_pos_override = -1;
  globalctrl.ticks_per_div = song->ticks_per_div;

  globalctrl.tick_div_count = globalctrl.ticks_per_div;
  globalctrl.active = 1;
  player_song = song;
  for (int chan = 0; chan < 3; chan++) {
    channelctrl[chan].note.raw = 0;
    channelctrl[chan].note_on_time = 0;
  }
}

void songplayer_stop() {
    globalctrl.active = 0;
}

void songplayer_start(int pos) {
  globalctrl.song_pos = pos;
  globalctrl.song_row = -1;
  globalctrl.next_pos_override = -1;
  globalctrl.active = 1;
}

void songplayer_trigger_effect(uint32_t bar_num) {
  globalctrl.sound_fx_bar = bar_num;
  globalctrl.sound_fx_row = 0;
}



void handle_percussion_div(int chan, int instrument) {
  switch(instrument) {
    case 1: // kick drum
      // kick drums have 1/50th sec noise followed by fast ramp down 50% pulse
      reg_audio[chan*4+REG_FREQ]=note_to_freq[90];
      reg_audio[chan*4+REG_WAVESELECT]=0x00080000;  /* enable, noise, fast attack/decay, full sustain volume */
      break;
    case 2: // hi-hat (closed)
      reg_audio[chan*4+REG_FREQ]=note_to_freq[100];
      reg_audio[chan*4+REG_WAVESELECT]=0x00080000;
      break;
    case 3: // hi-hat (open)
      reg_audio[chan*4+REG_FREQ]=note_to_freq[100];
      reg_audio[chan*4+REG_WAVESELECT]=0x00080000;  /* same as kick drum; noise enabled */
      break;
    case 4: // snare
      reg_audio[chan*4+REG_FREQ]=note_to_freq[50];
      reg_audio[chan*4+REG_WAVESELECT]=0x00090000;  /* combo triangle + noise (?!?!?) */
      break;
    default:
      break;
  }
}

void handle_effect_div(int chan, struct songnote_expanded_t *incoming_note) {
  struct songnote_expanded_t *note = &channelctrl[chan].note.note;
  switch(note->effect) {
    case 0x01: /* slide up */
        note->new_note = note->new_note + note->effect_parameter;
        if (!incoming_note->new_note) {
        reg_audio[chan*4+REG_FREQ] = note_to_freq[note->new_note];
      }
      break;
    case 0x02: /* slide down */
      if (!incoming_note->new_note) {
        note->new_note = note->new_note - note->effect_parameter;
        reg_audio[chan*4+REG_FREQ] = note_to_freq[note->new_note];
      }
      break;
    case 0x0c: /* set volume */
      channelctrl[chan].volume = channelctrl[chan].note.note.effect_parameter;
      reg_audio[chan*4+REG_VOLUME] = channelctrl[chan].volume;
      break;
    case 0x0b: /* position jump - jump to new pattern */
      globalctrl.next_pos_override = note->effect_parameter;
  }
}

void handle_effect_tick(int chan) {
  struct songnote_expanded_t *note = &channelctrl[chan].note.note;
  switch(note->effect) {
    case 0x01: /* slide up */
      note->new_note = note->new_note + note->effect_parameter;
      reg_audio[chan*4+REG_FREQ] = note_to_freq[note->new_note];
      break;
    case 0x02: /* slide down */
      note->new_note = note->new_note - note->effect_parameter;
      reg_audio[chan*4+REG_FREQ] = note_to_freq[note->new_note];
      break;
    case 0x0c: /* set volume */
      channelctrl[chan].volume = channelctrl[chan].note.note.effect_parameter;
      reg_audio[chan*4+REG_VOLUME] = channelctrl[chan].volume;
      break;
    default: break;
  }
}

void play_note_on_channel(int chan, struct songnote_expanded_t note) {
  channelctrl[chan].note.note.effect = note.effect;
  channelctrl[chan].note.note.effect_parameter = note.effect_parameter;

  // "disable" voice if we have a new note
  if (note.new_note != 0) {
    channelctrl[chan].note.note.new_note = note.new_note;
//            reg_audio[chan*4+REG_VOLUME]=0;
  }
  // switch out instrument waveform parameters for new voice
  if (note.instrument != 0) {
    channelctrl[chan].note.note.instrument = note.instrument;

    // set channel parameters based on instrument
    if (note.instrument >= FIRST_USER_INSTRUMENT) {
      struct song_instrument_t instrument = player_song->instruments[note.instrument];
      reg_audio[chan*4+REG_WAVESELECT]=
              (0x08<<24) /* enable voice */
              +(instrument.waveform_select<<16);
      reg_audio[chan*4+REG_PULSEWIDTH]=instrument.pulsewidth;
    }
  }
  // handle new note
  if (note.new_note != 0) {
    channelctrl[chan].note_on_time = 0;

    // set frequency of note
    reg_audio[chan*4+REG_FREQ] = note_to_freq[note.new_note];

    handle_percussion_div(chan, channelctrl[chan].note.note.instrument);

    struct song_instrument_t instrument = player_song->instruments[note.instrument];
    if (instrument.envelope_enable) {
      channelctrl[chan].volume = instrument.envelope->points[0];
    } else {
      channelctrl[chan].volume = instrument.default_volume;
    }
    reg_audio[chan*4+REG_VOLUME] = channelctrl[chan].volume;

  }
  // handle effects
  handle_effect_div(chan, &note);

}



  void divhandler() {

        int song_pattern = player_song->pattern_map[globalctrl.song_pos];

        // read in new note data
        if (globalctrl.active) {
          for (int chan = 0; chan < 3; chan++) {
            int current_bar_num = player_song->patterns[song_pattern].bar[chan];
            struct songnote_expanded_t note = player_song->bars[current_bar_num].notes[globalctrl.song_row].note;

            play_note_on_channel(chan, note);
          }

        }
        // deal with "sound fx" channel
        if (globalctrl.sound_fx_row < 16) {
          struct songnote_expanded_t note = player_song->bars[globalctrl.sound_fx_bar].notes[globalctrl.sound_fx_row].note;
          play_note_on_channel(3, note);
          globalctrl.sound_fx_row++;
        }
  }


  void handle_percussion_tick(int chan, int instrument) {
    switch (instrument) {
      case 1: // kick drum
        reg_audio[chan*4+REG_PULSEWIDTH]=2048;
        int kick_drum_note = 40-(channelctrl[chan].note_on_time << 2);
        if (kick_drum_note <= 27)
          kick_drum_note = 26;
        reg_audio[chan*4+REG_FREQ]=note_to_freq[kick_drum_note];
        reg_audio[chan*4+REG_WAVESELECT]=0x08040000;
    }
  }

  void tickhandler() {
    for (int chan = 0; chan < 4; chan++) {

      struct songnote_expanded_t note = channelctrl[chan].note.note;
      struct song_instrument_t instrument = player_song->instruments[note.instrument];

      channelctrl[chan].note_on_time++;
      if (instrument.envelope_enable) {
        int env_point = channelctrl[chan].note_on_time;
        if (env_point >= instrument.envelope->num_points) {
          env_point = instrument.envelope->num_points-1;
        }
        channelctrl[chan].volume = instrument.envelope->points[env_point];
      }

      reg_audio[chan*4+REG_VOLUME] = channelctrl[chan].volume;

      handle_percussion_tick(chan, channelctrl[chan].note.note.instrument);
      handle_effect_tick(chan);
  }
}


// audio interrupt routine -- call @ 50 times per second
void songplayer_tick() {
  globalctrl.tick_div_count++;
  if (globalctrl.tick_div_count < globalctrl.ticks_per_div) {
    tickhandler();
  } else {  /* advance song position and process new notes */
    globalctrl.tick_div_count = 0;

    globalctrl.song_row++;
    if (globalctrl.song_row >= player_song->rows_per_bar) {
      globalctrl.song_row = 0;
      globalctrl.song_pos++;
      if (globalctrl.song_pos >= player_song->song_length) {
        globalctrl.song_pos = 0;
      }
    }

    if (globalctrl.next_pos_override != -1) {
      globalctrl.song_pos = globalctrl.song_pos;
      globalctrl.song_row = 0;
    }

    divhandler();

  }
}
