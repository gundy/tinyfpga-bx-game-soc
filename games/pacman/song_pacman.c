
#include <songplayer/songplayer.h>
#include <audio/audio.h>

const struct envelope_t envelope0 = {
  .num_points = 16,
  .points = {
    0x00, 0xff, 0xff, 0x80, 0x20, 0x10, 0x08, 0x04,
    0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
  }
};

const struct envelope_t envelope1 = {
  .num_points = 16,
  .points = {
    0x10, 0xb0, 0xb4, 0xa0, 0x80, 0x60, 0x40, 0x30,
    0x20, 0x10, 0x08, 0x04, 0x03, 0x02, 0x01, 0x00
  }
};

const struct envelope_t envelope2 = {
  .num_points = 16,
  .points = {
    0x80, 0x60, 0x40, 0x20, 0x10, 0x08, 0x02, 0x02,
    0x1, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
  }
};

const struct envelope_t envelope3 = {
  .num_points = 16,
  .points = {
    0xff, 0xff, 0xc0, 0x80, 0x40, 0x20, 0x10, 0x00,
    0x0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
  }
};

// notes
// octave   C  C#   D  D#   E   F   F#   G   G#    A   A#   B
//     -1   1   2   3   4   5   6    7   8    9   10   11  12
//      0  13  14  15  16  17  18   19  20   21   22   23  24
//      1  25  26  27  28  29  30   31  32   33   34   35  36
//      2  37  38  39  40  41  42   43  44   45   46   47  48

//      3  49  50  51  52  53  54   55  56   57   58   59  60
//      4  61  62  63  64  65  66   67  68   69   70   71  72

//      5  73  74  75  76  77  78   79  80   81   82   83  84
//      6  85  86  87  88  89  90   91  92   93   94   95  96
//      7  97  98  99  100



const struct song_t song_pacman = {
  .song_length = 8,
  .rows_per_bar = 16,
  .ticks_per_div = 4,
  .pattern_map = { 0,1,2,3,4,4,4,4 },
  .instruments = {
      {.waveform_select = WAVE_NONE, .envelope = &envelope1, .envelope_enable=1, .pulsewidth = 2048},  // 0 = no instrument
      {.waveform_select = WAVE_NONE, .envelope = &envelope0, .envelope_enable=1, .pulsewidth = 2048},  // 1 = kick drum
      {.waveform_select = WAVE_NONE, .envelope = &envelope2, .envelope_enable=1, .pulsewidth = 2048},  // 2 = closed hihat
      {.waveform_select = WAVE_NONE, .envelope = &envelope2, .envelope_enable=1, .pulsewidth = 2048},  // 3 = open hihat
      {.waveform_select = WAVE_NONE, .envelope = &envelope3, .envelope_enable=1, .pulsewidth = 2048},  // 4 = snare

      // first user defined instrument here:
      {.waveform_select = WAVE_SAWTOOTH|WAVE_TRIANGLE, .envelope = &envelope1, .envelope_enable=1, .pulsewidth = 400},  // 5 = bassline
      {.waveform_select = WAVE_SAWTOOTH|WAVE_TRIANGLE, .envelope = &envelope1, .envelope_enable=0, .default_volume=255, .pulsewidth = 400},  // 6 is used for pacman death sound effect
      {.waveform_select = WAVE_TRIANGLE, .envelope = &envelope1, .envelope_enable=0, .default_volume=255,.pulsewidth = 400},  // 7 is used for eat-pill effect
      {.waveform_select = WAVE_SAWTOOTH, .envelope = &envelope1, .envelope_enable=0, .default_volume=128,.pulsewidth = 2048}  // 8 is used for waka-waka noise
  },
  .bars = {
    { .notes = {
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }},
        { .n = {.n=0,.i=0 }}
      }
    },
    // bar 1 - treble clef
    { .notes = {
      { .n = {.n=60,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=72,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=67,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=64,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=72,.i=5 }},
      { .n = {.n=67,.i=5 }},
      { .n = {.n=60,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=64,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=0,.i=0 }}
      }
    },
    // bar 2 - treble clef
    { .notes = {
      { .n = {.n=61,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=73,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=68,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=65,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=73,.i=5 }},
      { .n = {.n=68,.i=5 }},
      { .n = {.n=61,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=65,.i=5 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=0,.i=0 }},
      { .n = {.n=0,.i=0 }}
      }
    },
    // bar 3 - treble clef
    { .notes = {
        { .n = {.n=64,.i=5 }},
        { .n = {.n=65,.i=5 }},
        { .n = {.n=66,.i=5 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=66,.i=5 }},
        { .n = {.n=67,.i=5 }},
        { .n = {.n=68,.i=5 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=68,.i=5 }},
        { .n = {.n=69,.i=5 }},
        { .n = {.n=70,.i=5 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=72,.i=5 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }}
      }
    },
    // bar 4 - bass #1
    //48
    //55
    //48
    //56

    { .notes = {
        { .n = {.n=48,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},  // snare
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n=55,.i=5 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=48,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }}, // snare
        { .n = {.n= 0,.i=0 }}, // closed hh
        { .n = {.n=56,.i=5 }},
        { .n = {.n= 0,.i=0 }}
      }
    },

    // bar 5 bass 2
    { .notes = {
        { .n = {.n=49,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},  // snare
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n=56,.i=5 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=49,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }}, // snare
        { .n = {.n= 0,.i=0 }}, // closed hh
        { .n = {.n=55,.i=5 }},
        { .n = {.n= 0,.i=0 }}
      }
    },

    // bar 6 bass 3
    { .notes = {
        { .n = {.n=48,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},  // snare
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n=55,.i=5 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=48,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }}, // snare
        { .n = {.n= 0,.i=0 }}, // closed hh
        { .n = {.n=55,.i=5 }},
        { .n = {.n= 0,.i=0 }}
      }
    },

    // bar 7 bass 4
    { .notes = {
        { .n = {.n=55,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=56,.i=5 }},  // snare
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=58,.i=5 }},  // kick
        { .n = {.n= 0,.i=0 }},  // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }},
        { .n = {.n=60,.i=5 }}, // snare
        { .n = {.n= 0,.i=0 }}, // closed hh
        { .n = {.n= 0,.i=0 }},
        { .n = {.n= 0,.i=0 }}
      }
    },


    // octave   C  C#   D  D#   E   F   F#   G   G#    A   A#   B
    //     -1   1   2   3   4   5   6    7   8    9   10   11  12
    //      0  13  14  15  16  17  18   19  20   21   22   23  24
    //      1  25  26  27  28  29  30   31  32   33   34   35  36
    //      2  37  38  39  40  41  42   43  44   45   46   47  48
    //      3  49  50  51  52  53  54   55  56   57   58   59  60
    //      4  61  62  63  64  65  66   67  68   69   70   71  72
    //      5  73  74  75  76  77  78   79  80   81   82   83  84
    //      6  85  86  87  88  89  90   91  92   93   94   95  96
    //      7  97  98  99  100

    // bar 8 = pacman death sound effect
    { .notes = {
        { .n = {.n=80,.i=6,.e=2,.p=1 }}, // G5, slide down
        { .n = {.n= 0,.i=0,.e=1,.p=1 }}, // slide back up
        { .n = {.n=78,.i=6,.e=2,.p=1 }}, // F5, slide down
        { .n = {.n= 0,.i=0,.e=1,.p=1 }}, // slide back up
        { .n = {.n=77,.i=6,.e=2,.p=1 }}, // E5, slide down
        { .n = {.n= 0,.i=0,.e=1,.p=1 }}, // slide back up
        { .n = {.n=75,.i=6,.e=2,.p=1 }}, // D5, slide down
        { .n = {.n= 0,.i=0,.e=1,.p=1 }}, // slide back up
        { .n = {.n=73,.i=6,.e=2,.p=1 }}, // C5, slide down
        { .n = {.n= 0,.i=0,.e=1,.p=1 }}, // slide back up
        { .n = {.n=72,.i=6,.e=2,.p=1 }}, // B5, slide down .. but .. break this one off early so there's room to cut the volume at the last row
        { .n = {.n=56,.i=6,.e=1,.p=5 }}, // start at G3, slide up 5 semitones at a time; "whup whup" at the end.
        { .n = {.n= 0,.i=0,.e=1,.p=5 }}, // .. keep sliding up
        { .n = {.n=56,.i=6,.e=1,.p=5 }}, // reset back to G3 ^^^^^
        { .n = {.n= 0,.i=0,.e=1,.p=5 }},  // ^^^^^^^^^^^^^^
        { .n = {.n= 0,.i=0,.e=12,.p=0 }} // set volume to zero to end effect
      }
    },

    // bar 9 = eat pill sound effect
    { .notes = {
        { .n = {.n=80,.i=7,.e=2,.p=4 }},  // G5, slide down
        { .n = {.n= 0,.i=0,.e=2,.p=4 }},  // keep sliding down
        { .n = {.n= 0,.i=0,.e=1,.p=4 }},  // slide back up
        { .n = {.n= 0,.i=0,.e=1,.p=4 }},  // keep sliding back up
        { .n = {.n= 0,.i=0,.e=12,.p=0 }}, // set volume to zero to end effect
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }}
      }
    },

    // bar 10 = waka waka
    { .notes = {
        { .n = {.n=72,.i=8,.e=2,.p=4 }},  // Start @ B5, slide down
        { .n = {.n= 0,.i=0,.e=12,.p=0 }},  // volume off
        { .n = {.n=56,.i=8,.e=1,.p=4 }},  // start @ G4 and slide up
        { .n = {.n= 0,.i=0,.e=12,.p=0 }}, // set volume to zero to end effect
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},  // keep sliding down
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},  // keep sliding up
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }},
        { .n = {.n= 0,.i=0,.e=0,.p=0 }}
      }
    },
  },
  .patterns = {
    { .bar = { 1,4,0,0 } },
    { .bar = { 2,5,0,0 } },
    { .bar = { 1,6,0,0 } },
    { .bar = { 3,7,0,0 } },
    { .bar = { 0,0,0,0 } }
  }
};
