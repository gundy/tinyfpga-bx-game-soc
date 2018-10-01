#include <stdint.h>
#include <stdbool.h>

#include <audio/audio.h>
#include <video/video.h>
#include <songplayer/songplayer.h>
#include <uart/uart.h>
#include <sine_table/sine_table.h>
#include <nunchuk/nunchuk.h>

#include "graphics_data.h"

//#define debug 1
#define diag 1

#define abs(x) ((x) < 0 ? -(x) : (x))

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)

extern const struct song_t song_pacman;

// Board timensions
#define TILE_SIZE 8
#define BOARD_WIDTH 15
#define BOARD_HEIGHT 14

// Board properties
#define CAN_GO_LEFT 1
#define CAN_GO_RIGHT 2
#define CAN_GO_UP 4
#define CAN_GO_DOWN 8
#define FOOD 16
#define BIG_FOOD 32
#define FRUIT 64

// Tile definitions
#define BLANK_TILE 0

#define FOOD_TILE1 4
#define FOOD_TILE2 5
#define FOOD_TILE3 12
#define FOOD_TILE4 13

#define BIG_FOOD_TILE1 40
#define BIG_FOOD_TILE2 41
#define BIG_FOOD_TILE3 48
#define BIG_FOOD_TILE4 49

#define RED_ONE_TILE 15

#define ZERO_TILE 16

#define U_TILE 32

#define H_TILE 56

#define CHERRY_TILE 42
#define STRAWBERRY_TILE 44
#define ORANGE_TILE 26

#define GAME_OVER_TILE 28

#define PACMAN_TILE 46

#define POWER_PILL_TILE1 40
#define POWER_PILL_TILE2 41
#define POWER_PILL_TILE3 48
#define POWER_PILL_TILE4 49

// Point values
#define FOOD_POINTS 10
#define BIG_FOOD_POINTS 50

#define CHERRY_POINTS 100
#define STRAWBERRY_POINTS 300
#define ORANGE_POINTS 500
#define APPLE_POINTS 700
#define MELON_POINTS 1000
#define GALAXIAN_POINTS 2000
#define BELL_POINTS 3000
#define KEY_POINTS 5000

#define GHOST_POINTS 200

// Board positions
#define FRUIT_X 7
#define FRUIT_Y 3

#define GHOST_OUT_X 7
#define GHOST_OUT_Y 7

#define PINKY_HOME_X 6
#define PINKY_HOME_Y 9

#define INKY_HOME_X 7
#define INKY_HOME_Y 9

#define CLYDE_HOME_X 8
#define CLYDE_HOME_Y 9

#define PINKY_HOME_X 6
#define PINKY_HOME_Y 9

#define POWER_PILL1_X 0
#define POWER_PILL1_Y 1

#define POWER_PILL2_X 0
#define POWER_PILL2_Y 8

#define POWER_PILL3_X 14
#define POWER_PILL3_Y 1

#define POWER_PILL4_X 14
#define POWER_PILL4_Y 8

#define HI_SCORE_X 32
#define HI_SCORE_Y 2

#define LIVES_X 32
#define LIVES_Y 24

#define UP_X 32
#define UP_Y 7

#define SHOW_FRUIT_X 32
#define SHOW_FRUIT_Y 16

#define SCORE_X 34
#define SCORE_Y 8

#define READY_X 6
#define READY_Y 3

#define GAME_OVER_X 7
#define GAME_OVER_Y 3

// Directions
#define UP 2
#define DOWN 1
#define LEFT 3
#define RIGHT 0

// Colours
#define BLACK 0
#define RED 1
#define GREEN 2
#define YELLOW 3
#define BLUE 4
#define MAGENTA 5
#define CYAN 6
#define WHITE 7

// Sprite images
#define PACMAN_ROUND 0
#define PACMAN_RIGHT 1
#define PACMAN_DOWN 2
#define PACMAN_UP 3
#define PACMAN_LEFT 4

#define READY_IMAGE 5

#define GHOST_IMAGE 8
#define EYES_IMAGE 9
#define SCORE_IMAGE 10

#define EXPLODE_IMAGE1 14
#define EXPLODE_IMAGE2 15

// Period lengths
#define HUNT_TICKS 30
#define STAGE_OVER_TICKS 10
#define FRUIT_TICKS 100

#define PINKY_START 20
#define INKY_START 40
#define CLYDE_START 60

// Sprite numbers
#define NUM_SPRITES 5
#define NUM_GHOSTS 4

// Point thresholds
#define LIFE_POINTS 10000

// Ghost states
#define DOCKED 0
#define ACTIVE 1
#define SCORE 2
#define EYES 3

// Skip ticks
#define HUNT_SCORE_TICKS 5

// Screen positions
#define START_HI_SCORE_X 16
#define START_HI_SCORE_Y 33

#define START_1UP_SCORE_X 6
#define START_1UP_SCORE_Y 33

#define START_2UP_SCORE_X 26
#define START_2UP_SCORE_Y 33

#define INTRO_HI_SCORE_X 16
#define INTRO_HI_SCORE_Y 3

#define INTRO_1UP_SCORE_X 3
#define INTRO_1UP_SCORE_Y 3

#define INTRO_2UP_SCORE_X 26
#define INTRO_2UP_SCORE_Y 3

//Sprite numbers
#define PACMAN 0

#define INKY 1
#define PINKY 2
#define BLINKY 3
#define CLYDE 4
#define READY 5

const uint32_t counter_frequency = 16000000/50;  /* 50 times per second */

const uint8_t  ghost_colour[] = {CYAN, MAGENTA, RED, GREEN};

// Working data
uint8_t board[BOARD_HEIGHT][BOARD_WIDTH];
uint8_t sprite_x[NUM_SPRITES];
uint8_t sprite_y[NUM_SPRITES];
uint8_t old_sprite_x[NUM_SPRITES], old_sprite_y[NUM_SPRITES];
uint8_t old2_sprite_x[NUM_SPRITES], old2_sprite_y[NUM_SPRITES];
bool ghost_active[NUM_GHOSTS];
uint8_t old_sprite_x[NUM_SPRITES], old_sprite_y[NUM_SPRITES];
uint8_t old2_sprite_x[NUM_SPRITES], old2_sprite_y[NUM_SPRITES];
bool ghost_eyes[NUM_GHOSTS];
bool ghost_active[NUM_GHOSTS];
uint16_t score, hi_score, old_score, food_items, ghost_points;
uint16_t ghost_speed_counter, ghost_speed, fruit_counter;
uint8_t stage, direction, hunting, num_fruit, num_lives, kills, set_ghost_eyes;
uint32_t tick_counter, game_start, hunt_start, stage_over_start, skip_ticks, life_over_start;
bool play, chomp, game_over, life_over, new_stage;
bool auto_play;
uint8_t buttons, jx, jy, num_players, rand;

// Set the IRQ mask
uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

// Set the timer counter
uint32_t set_timer_counter(uint32_t val); asm (
    ".global set_timer_counter\n"
    "set_timer_counter:\n"
    ".word 0x0a05650b\n"
    "ret\n"
);

// Interrupt handling used for playing audio
void irq_handler(uint32_t irqs, uint32_t* regs)
{
  /* timer IRQ */
  if ((irqs & 1) != 0) {
    // retrigger timer
    set_timer_counter(counter_frequency);

    // Play song
    songplayer_tick();
  }
}

// Delay a few clock cycles - used by Nunchuk code
void delay(uint32_t n) {
  for (uint32_t i = 0; i < n; i++) asm volatile ("");
}

// Set up the player selection start screen
void setup_startscreen() {
  vid_init();
  vid_set_x_ofs(0);
  vid_set_y_ofs(0);

  // Set up the 64 8x8 textures
  for (int tex = 0; tex < 64; tex++) {
    for (int x = 0; x < 8; x++) {
      for (int y = 0 ; y < 8; y++) {
        int texrow = tex >> 3;   // 0-7, row in texture map
        int texcol = tex & 0x07; // 0-7, column in texture map
        int pixx = (texcol<<3)+x;
        int pixy = (texrow<<3)+y;
        uint32_t pixel = -startscreen_texture_data[(pixy<<6)+pixx];
        // Colour maping messed up - I don't know why
        vid_set_texture_pixel(tex, x, y, (8 - pixel) & 0x7);
      }
    }
  }

  // Set up the 40 x 30 tiles
  for (int x = 0; x < 40; x++) {
    for (int y = 0; y < 30; y++) {
      vid_set_tile(x,y + 30,startscreen_tile_data[(y*40)+x]);
    }
  }
}

// Set up the intro textures
void setup_intro_textures () {

  // Set up the 64 8x8 textures
  for (int tex = 0; tex < 64; tex++) {
    for (int x = 0; x < 8; x++) {
      for (int y = 0 ; y < 8; y++) {
        int texrow = tex >> 3;   // 0-7, row in texture map
        int texcol = tex & 0x07; // 0-7, column in texture map
        int pixx = (texcol<<3)+x;
        int pixy = (texrow<<3)+y;
        uint32_t pixel = - intro_texture_data[(pixy<<6)+pixx];
        // Colour maping messed up - I don't know why
        vid_set_texture_pixel(tex, x, y, (8 - pixel) & 0x7);
      }
    }
  }
}

// Set up the intro tiles
void setup_intro_tiles (uint8_t start, uint8_t end) {

  // Set up the 40 x 30 tiles
  for (int x = 0; x < 40; x++) {
    for (int y = start; y < end; y++) {
      vid_set_tile(x,y,intro_tile_data[(y*40)+x]);
    }
  }
}

// Set all tiles on board section of screen to blank
void clear_board() {
 for (int x = 0; x < 32; x++) {
    for (int y = 0; y < 32; y++) {
      vid_set_tile(x,y,BLANK_TILE);
    }
  }
}

// Set the whole screen to blank tiles
void clear_screen() {
 for (int x = 0; x < 40; x++) {
    for (int y = 0; y < 32; y++) {
      vid_set_tile(x,y,BLANK_TILE);
    }
  }
}

// Set up the board grid with cell properties
void setup_board() {
  food_items = 0;

  for(int y = 0; y < BOARD_HEIGHT; y++) {
    for(int x = 0;  x < BOARD_WIDTH; x++) {
      uint8_t n = 0;
      uint8_t t = tile_data[((y*2 + 1) << 5) + x*2 + 1];

      // Only process board tiles
      if (t != BLANK_TILE && t != FOOD_TILE1 && t != BIG_FOOD_TILE1) continue;

      // Check for food
      if (t == FOOD_TILE1) {
        n |= FOOD;
        food_items++;
      } else if (t == BIG_FOOD_TILE1) {
        n |= BIG_FOOD;
        food_items++;
      }

      // Set valid board directions
      if (y > 0) {
        uint8_t above = tile_data[(((y-1)*2 + 2) << 5) + x*2 + 1];
        if (above == BLANK_TILE || above == FOOD_TILE3 ||
            above == BIG_FOOD_TILE3) n |= CAN_GO_UP;
      }

      if (y < BOARD_HEIGHT - 1) {
        uint8_t below = tile_data[(((y+1)*2 + 1) << 5) + x*2 + 1];
        if (below == BLANK_TILE || below == FOOD_TILE1 ||
            below == BIG_FOOD_TILE1) n |= CAN_GO_DOWN;
      }

      if (x > 0) {
        uint8_t left = tile_data[((y*2 + 1) << 5) + (x-1)*2 + 2];
        if (left == BLANK_TILE || left == FOOD_TILE2 ||
            left == BIG_FOOD_TILE2) n |= CAN_GO_LEFT;
      }

      if (x < BOARD_WIDTH - 1) {
        uint8_t right = tile_data[((y*2 + 1) << 5) + (x+1)*2 + 1];
        if (right == BLANK_TILE || right == FOOD_TILE1 ||
            right == BIG_FOOD_TILE1) n |= CAN_GO_RIGHT;
      }

      board[y][x] = n;
    }
  }
}

// Display just the board, not its contents
void show_board() {
  for (int x = 0; x < 32; x++) {
    for (int y = 0; y < 32; y++) {
     uint8_t t = tile_data[(y<<5)+x];
     if (t < 16 && t != 4 && t != 5 && t != 12 && t != 13) vid_set_tile(x,y,t);
    }
  }
}

#ifdef debug
// Diagnostic print of board
void print_board() {
  print("Board:\n");
  for(int y = 0; y < 14; y++) {
    for(int x = 0; x < 15; x++) {
      print_hex(board[y][x],2);
      print(" ");
    }
    print("\n");
  }
}
#endif

// Reset sprites to their original positions, and reset other state data
void reset_positions() {
  sprite_x[PACMAN] = 7;
  sprite_y[PACMAN] = 11;
  direction = RIGHT;

  sprite_x[BLINKY] = 7;
  sprite_y[BLINKY] = 7;

  sprite_x[PINKY] = 6;
  sprite_y[PINKY] = 10;

  sprite_x[INKY] = 7;
  sprite_y[INKY] = 10;

  sprite_x[CLYDE] = 8;
  sprite_y[CLYDE] = 10;

  hunting = 0;
  new_stage = false;
}

// Add fruit to the board
void add_fruit(uint8_t x, uint8_t y) {
  if (board[y][x] & FRUIT) return;
  board[y][x] |= FRUIT;
  food_items++;
  uint8_t fruit_tile = (stage == 1 ?  CHERRY_TILE :
                        stage == 2 ? STRAWBERRY_TILE : ORANGE_TILE);
  vid_set_tile(2*x + 1,2*y + 1, fruit_tile);
  vid_set_tile(2*x + 2,2*y + 1, fruit_tile+1);
  vid_set_tile(2*x + 1,2*y + 2, fruit_tile+8);
  vid_set_tile(2*x + 2,2*y + 2, fruit_tile+9);
}

// Set ghosts to their initial colours
void set_ghost_colours() {
  vid_set_sprite_colour(INKY, CYAN);
  vid_set_sprite_colour(PINKY, MAGENTA);
  vid_set_sprite_colour(BLINKY, RED);
  vid_set_sprite_colour(CLYDE, GREEN);
}

void set_board_colour(uint8_t color) {
  // Set up the 64 8x8 textures
  for (int tex = 0; tex < 64; tex++) {
    for (int x = 0; x < 8; x++) {
      for (int y = 0 ; y < 8; y++) {
        int texrow = tex >> 3;   // 0-7, row in texture map
        int texcol = tex & 0x07; // 0-7, column in texture map
        int pixx = (texcol<<3)+x;
        int pixy = (texrow<<3)+y;
        uint32_t pixel = texture_data[(pixy<<6)+pixx];
        if (pixel != 0 && tex < 15 && tex != 0 && tex != 4 &&
            tex != 5 && tex != 12 && tex != 13)
          pixel = color;
        vid_set_texture_pixel(tex, x, y, pixel);
      }
    }
  }
}

void setup_sprites() {
  // Set up the Pacman sprite images as images 0-7 and set the image to the first one
  for(int i=0; i<8; i++) vid_write_sprite_memory(i, pacman_sprites[i]);
  vid_set_image_for_sprite(PACMAN, PACMAN_RIGHT);

  vid_set_image_for_sprite(READY, READY_IMAGE);
  vid_set_image_for_sprite(READY+1, READY_IMAGE+1);
  vid_set_image_for_sprite(READY+2, READY_IMAGE+2);

  // Set up the ghost sprite images as image 8-15 and set the current ghost image to the first one
  for(int i=0; i<8; i++) vid_write_sprite_memory(GHOST_IMAGE + i, ghost_sprites[i]);
  for(int i=0;i<NUM_GHOSTS;i++) vid_set_image_for_sprite(i+1, GHOST_IMAGE);

  // Set the sprite colours, to their defaults
  set_ghost_colours();
  vid_set_sprite_colour(PACMAN, YELLOW);
}

// Set up all the graphics data for board portion of screen
void setup_screen() {
  // Initialse the video and set offset to (0,0)
  vid_init();
  vid_set_x_ofs(0);
  vid_set_y_ofs(0);

  // Set up the 64 8x8 textures
  for (int tex = 0; tex < 64; tex++) {
    for (int x = 0; x < 8; x++) {
      for (int y = 0 ; y < 8; y++) {
        int texrow = tex >> 3;   // 0-7, row in texture map
        int texcol = tex & 0x07; // 0-7, column in texture map
        int pixx = (texcol<<3)+x;
        int pixy = (texrow<<3)+y;
        uint32_t pixel = texture_data[(pixy<<6)+pixx];
        vid_set_texture_pixel(tex, x, y, pixel);
      }
    }
  }

  // Set up the 32x32 tiles
  for (int x = 0; x < 32; x++) {
    for (int y = 0; y < 32; y++) {
      vid_set_tile(x,y,tile_data[(y<<5)+x]);
    }
  }

  // Blank the RHS of screen
  for (int x = 32; x < 40; x++) {
    for (int y = 0; y < 32; y++) {
      vid_set_tile(x,y,0);
    }
  }

  // Reset the sprite positions
  reset_positions();

  // Setup sprites
  setup_sprites();

  for(int i=0;i<3;i++) vid_set_sprite_colour(READY+i, YELLOW);

  // Position the sprites to their home positions
  for(int i=0;i<NUM_SPRITES;i++)
    vid_set_sprite_pos(i, 8 + (sprite_x[i] << 4), 8 + (sprite_y[i] << 4));

  // Enable all the sprites
  for(int i=0;i<NUM_SPRITES;i++) vid_enable_sprite(i, 1);

  // Disable ghost eyes and set ghosts inactive
  for(int i=0;i<NUM_GHOSTS;i++) ghost_eyes[i] = false;
  for(int i=0;i<NUM_GHOSTS;i++) ghost_active[i] = false;
}

// Display available fruit
void show_fruit() {
  for(int i=0;i<4;i++) {
    int tile = CHERRY_TILE;

    if (i == 1) tile = STRAWBERRY_TILE;
    else if (i >= 2) tile = ORANGE_TILE;

    vid_set_tile(SHOW_FRUIT_X + i*2, SHOW_FRUIT_Y, (i >= num_fruit ? BLANK_TILE : tile));
    vid_set_tile(SHOW_FRUIT_X + 1 + i*2, SHOW_FRUIT_Y, (i >= num_fruit ? BLANK_TILE : tile + 1));
    vid_set_tile(SHOW_FRUIT_X + i*2, SHOW_FRUIT_Y + 1, (i >= num_fruit ? BLANK_TILE : tile + 8));
    vid_set_tile(SHOW_FRUIT_X + 1 + i*2, SHOW_FRUIT_Y + 1, (i >= num_fruit ? BLANK_TILE : tile + 9));
  }
}

void show_big_tile(uint8_t x, uint8_t y, uint8_t t1, uint8_t t2,
                                         uint8_t t3, uint8_t t4) {
  vid_set_tile(2*x+1, 2*y+1, t1);
  vid_set_tile(2*x+2, 2*y+1, t2);
  vid_set_tile(2*x+1, 2*y+2, t3);
  vid_set_tile(2*x+2, 2*y+2, t4);
}

// Display available lives
void show_lives() {
  for(int i=0;i<4;i++) {
    vid_set_tile(LIVES_X + i*2, LIVES_Y, (i < num_lives ? PACMAN_TILE : BLANK_TILE));
    vid_set_tile(LIVES_X + 1 + i*2, LIVES_Y, (i < num_lives ? PACMAN_TILE+1 : BLANK_TILE));
    vid_set_tile(LIVES_X + i*2, LIVES_Y + 1, (i < num_lives ? PACMAN_TILE+8 : BLANK_TILE));
    vid_set_tile(LIVES_X + 1 + i*2, LIVES_Y + 1, (i < num_lives ? PACMAN_TILE+9 : BLANK_TILE));
  }
}

const int divisor[] = {10000,1000,100,10};

// Display score, hi-score or another numnber
void show_score(int x, int y, int score) {
  int s = score;
  bool blank = true;
  for(int i=0; i<5; i++) {
    int d = 0;
    if (i == 4) d = s;
    else {
      int div = divisor[i];
      while (s >= div) {
        s -= div;
        d++;
      }
      if (d !=0) blank = false;
    }
    int tile = blank && i != 4 ? BLANK_TILE : ZERO_TILE + d;
    vid_set_tile(x+i, y, tile);
  }
}

// Show ready message
void show_ready() {
  for(int i=0;i<3;i++) {
    vid_set_sprite_pos(READY + i, TILE_SIZE  - 1 + ((READY_X + i) <<4),
                              TILE_SIZE + (READY_Y <<4));
    vid_enable_sprite(READY + i, 1);
  }
}

// Remove ready message
void remove_ready() {
  for(int i=0;i<3;i++) vid_enable_sprite(READY + i, 0);
}

// Game over message
void show_game_over() {
  show_big_tile(GAME_OVER_X, GAME_OVER_Y,
                GAME_OVER_TILE, GAME_OVER_TILE + 1,
                GAME_OVER_TILE + 8, GAME_OVER_TILE + 9);
  show_big_tile(GAME_OVER_X + 1, GAME_OVER_Y,
                GAME_OVER_TILE + 2, GAME_OVER_TILE + 3,
                GAME_OVER_TILE + 10, GAME_OVER_TILE + 11);
}

// Chase a sprite or go to a target
void chase(uint8_t target_x, uint8_t target_y, uint8_t* x, uint8_t* y,
           uint8_t avoid_x, uint8_t avoid_y) {
  uint8_t n = board[*y][*x];
#ifdef debug
  print("Chasing ");
  print_hex(target_x,4);
  print(" ");
  print_hex(target_y,4);
  print("\n");
#endif
  if (target_x < *x && (n & CAN_GO_LEFT) && (*x)-1 != avoid_x) (*x)--;
  else if (target_x > *x && (n & CAN_GO_RIGHT) && (*x)+1 != avoid_x) (*x)++;
  else if (target_y < *y && (n & CAN_GO_UP) && (*y)-1 != avoid_y) (*y)--;
  else if (target_y > *y && (n & CAN_GO_DOWN) && (*y)+1 != avoid_y) (*y)++;
  else if (n & CAN_GO_LEFT) (*x)--;
  else if (n & CAN_GO_RIGHT) (*x)++;
  else if (n & CAN_GO_DOWN) (*y)--;
  else if (n & CAN_GO_UP) (*y)++;
}

// Evade a sprite or go away from a target
void evade(uint8_t target_x, uint8_t target_y, uint8_t* x, uint8_t* y,
           uint8_t avoid_x, uint8_t avoid_y) {
  uint8_t n = board[*y][*x];
#ifdef debug
  print("Evading ");
  print_hex(target_x,4);
  print(" ");
  print_hex(target_y,4);
  print("\n");
#endif
  if (target_x < *x && (n & CAN_GO_LEFT)) (*x)--;
  else if (target_x < *x && (n & CAN_GO_RIGHT)) (*x)++;
  else if (target_y > *y && (n & CAN_GO_UP)) (*y)--;
  else if (target_y < *y && (n & CAN_GO_DOWN)) (*y)++;
  else if (n & CAN_GO_LEFT) (*x)--;
  else if (n & CAN_GO_RIGHT) (*x)++;
  else if (n & CAN_GO_DOWN) (*y)--;
  else if (n & CAN_GO_UP) (*y)++;
}

// Ghost behaviour
void move_ghost(uint8_t g) {
  if (!ghost_active[g-1]) return;

  // Set the target
  uint8_t tx = sprite_x[PACMAN];
  uint8_t ty = sprite_y[PACMAN];

  bool chasing = hunting == 0 || ghost_eyes[g-1];

  if (hunting == 0 && !ghost_eyes[g-1]) {
    if (g == PINKY) {
      switch (direction) {
        case UP: ty-2; break;
        case DOWN: ty+2; break;
        case LEFT: tx-2; break;
        case RIGHT: tx+2; break;
      }
    } else if (g == CLYDE) {
      if (abs(sprite_x[g] - tx) < 2 ||
          abs(sprite_y[g] - ty) < 2) {
        tx = 0;
        ty = 13;
      }
    } else if (g == INKY) {
      if (tick_counter & 0x100) chasing = false;
    }
  }

  if (ghost_eyes[g-1]) {
    tx = 7;
    ty = 7;

    if (sprite_x[g] == 7 && sprite_y[g] == 7) {
      sprite_x[g] = 8;
      ghost_eyes[g-1] = false;
      vid_set_image_for_sprite(g, GHOST_IMAGE);
      vid_set_sprite_colour(g, ghost_colour[g-1]);
      return;
    } else if (sprite_x[g] == 7 && sprite_y[g] == 8) {
      sprite_y[g] = 9;
      return;
    }
  }

  if (chasing) {
    chase(tx, ty, &sprite_x[g], &sprite_y[g],
          old2_sprite_x[g], old2_sprite_y[g]);
  } else {
    evade(tx, ty, &sprite_x[g], &sprite_y[g],
          old2_sprite_x[g], old2_sprite_y[g]);
  }
}

// Test is square is occupied by ghost
bool ghost_square(uint8_t x, uint8_t y) {
  for(int i=0;i<NUM_GHOSTS;i++) if (x == sprite_x[i+1] && y == sprite_y[i+1]) return true;
  return false;
}

// Move Pacman when in auto-play
void move_pacman() {
  uint8_t valid = 0, num = 0;
  uint8_t x = sprite_x[PACMAN];
  uint8_t y = sprite_y[PACMAN];
  uint8_t n = board[sprite_y[PACMAN]][sprite_x[PACMAN]];

  // Find the valid moves
  if  ((n & CAN_GO_UP) && (hunting > 0 || !ghost_square(x,y-1))) {
    valid |= CAN_GO_UP;
    num++;
  }

  if ((n & CAN_GO_RIGHT) && (hunting > 0 || !ghost_square(x+1,y))) {
    valid |= CAN_GO_RIGHT;
    num++;
  }

  if ((n & CAN_GO_DOWN) &&(hunting > 0 ||  !ghost_square(x,y+1))) {
    valid |= CAN_GO_DOWN;
    num++;
  }

  if ((n & CAN_GO_LEFT) && (hunting > 0 || !ghost_square(x-1, y))) {
    valid |= CAN_GO_LEFT;
    num++;
  }

  uint8_t save = valid;
#ifdef debug
  print("Valid moves ");
  print_hex(valid,2);
  print("\n");
#endif
  // If there is more than one direction, pick one with food and then remove one at random
  if (num > 1) {
    if ((valid & CAN_GO_UP) && !(board[y-1][x] & (FOOD | BIG_FOOD | FRUIT))) valid &= ~CAN_GO_UP;
    if ((valid & CAN_GO_DOWN) && !(board[y+1][x] & (FOOD | BIG_FOOD | FRUIT))) valid &= ~CAN_GO_DOWN;
    if ((valid & CAN_GO_LEFT) && !(board[y][x-1] & (FOOD | BIG_FOOD | FRUIT))) valid &= ~CAN_GO_LEFT;
    if ((valid & CAN_GO_RIGHT) && !(board[y][x+1] & (FOOD | BIG_FOOD | FRUIT))) valid &= ~CAN_GO_RIGHT;
  }
#ifdef debug
  print("Valid moves with food");
  print_hex(valid,2);
  print("\n");
#endif
  if (valid == 0) {
    valid = save;

    if (num > 1) {
      uint8_t ox = old2_sprite_x[PACMAN], oy = old2_sprite_y[PACMAN];
      if ((valid & CAN_GO_UP) && x == ox && y-1 == oy) valid &= ~CAN_GO_UP;
      if ((valid & CAN_GO_DOWN) && x == ox && y+1 == oy) valid &= ~CAN_GO_DOWN;
      if ((valid & CAN_GO_LEFT) && x-1 == ox && y == oy) valid &= ~CAN_GO_LEFT;
      if ((valid & CAN_GO_RIGHT) && x+1 == ox && y == oy) valid &= ~CAN_GO_RIGHT;

      if (valid == 0) {
        uint8_t bit = 1, mask = (tick_counter >> 3) & 1;
        for (int i=0;num>1 && i<4;i++) {
          if (valid & bit) valid &= ~mask;
          if (!(valid & bit)) num--;
          bit << 1;
          mask = (mask ^ bit) << 1;
        }
#ifdef debug
        print("Valid moves random ");
        print_hex(valid,2);
        print("\n");
#endif
      }
    }
  }

  if (tick_counter & 2) {
    if (valid & CAN_GO_UP) {
      sprite_y[PACMAN]--;
      direction=UP;
    } else if (valid & CAN_GO_RIGHT) {
      sprite_x[PACMAN]++;
      direction=RIGHT;
    } else if (valid & CAN_GO_DOWN) {
      sprite_y[PACMAN]++;
      direction=DOWN;
    } else if (valid & CAN_GO_LEFT) {
      sprite_x[PACMAN]--;
      direction=LEFT;
    }
  } else {
    if (valid & CAN_GO_LEFT) {
      sprite_x[PACMAN]--;
      direction=LEFT;
    } else if (valid & CAN_GO_UP) {
      sprite_y[PACMAN]--;
      direction=UP;
    } else if (valid & CAN_GO_RIGHT) {
      sprite_x[PACMAN]++;
      direction=RIGHT;
    } else if (valid & CAN_GO_DOWN) {
      sprite_y[PACMAN]++;
      direction=DOWN;
    }
  }
}

// End the hunt
void end_hunt() {
  hunting = 0;
  kills = 0;
  set_ghost_colours();

  for(int i=0;i<NUM_GHOSTS;i++) {
    vid_enable_sprite(i+1, 1);
    vid_set_image_for_sprite(i+1, GHOST_IMAGE);
    ghost_eyes[i] = false;
  }

  // Let blinky out again
  if (sprite_x[BLINKY] == 7 && sprite_y[BLINKY] == 8) sprite_y[BLINKY] = 7;
}

void show_1up() {
  vid_set_tile(UP_X, UP_Y, RED_ONE_TILE);
  for(int i=0;i<2;i++) vid_set_tile(UP_X + i + 1, UP_Y, U_TILE + i);
}

// Display HI-SCORE label
void show_hiscore_label() {
  for (int i=0; i<8; i++) vid_set_tile(HI_SCORE_X + i, HI_SCORE_Y, H_TILE + i);
}

void get_input() {
  // Get Nunchuk data
  i2c_send_reg(0x00);
  delay(100);

  jx = i2c_read();
#ifdef debug
  print("Joystick x: ");
  print_hex(jx, 2);
  print("\n");
#endif

  jy = i2c_read();
#ifdef debug
  print("Joystick y: ");
  print_hex(jy, 2);
  print("\n:1");
#endif

  uint8_t ax = i2c_read();
  rand = ax & 1;

  uint8_t ay = i2c_read();

  uint8_t az = i2c_read();

  uint8_t rest = i2c_read();
#ifdef debug
  print("Buttons: ");
  print_hex(rest & 3, 2);
  print("\n");
#endif
  buttons = rest & 3;
}

// Show the intro screen
void show_intro_screen() {
  vid_set_x_ofs(0);
  vid_set_y_ofs(0);

// Set up the screen
  clear_screen();
  setup_intro_textures();
  setup_sprites();

  setup_intro_tiles(0,6);

  show_score(INTRO_HI_SCORE_X, INTRO_HI_SCORE_Y, hi_score);

  show_score(INTRO_1UP_SCORE_X, INTRO_1UP_SCORE_Y, score);

  show_score(INTRO_2UP_SCORE_X, INTRO_2UP_SCORE_Y, 0);

  delay(50000);

  for(int i = 0; i < 4; i++) {
    setup_intro_tiles(7 + 2*i, 9 + 2*i);
    vid_set_sprite_pos(i+1, 50, 60 + 16*i);
    vid_enable_sprite(i+1, 1);
    get_input();
    if (buttons == 2) break;
    delay(50000);
  }

  if (buttons != 2) {
    setup_intro_tiles(15, 30);
    delay(50000);

    // Place the pac-dot
    vid_set_tile(5,25, 28);
    vid_set_sprite_pos(PACMAN, 200, 196);
    vid_set_image_for_sprite(PACMAN, PACMAN_LEFT);
    vid_enable_sprite(PACMAN, 1);

    for(int i=0; i<NUM_GHOSTS; i++) {
      vid_set_sprite_pos(i+1, 224 + i*24, 196);
      vid_enable_sprite(i+1, 1);
    }

    for(int i=0; i<11; i++) {
      vid_set_sprite_pos(PACMAN, 200 - i * 16, 196);
      vid_set_image_for_sprite(PACMAN, (i &1 ? PACMAN_LEFT : PACMAN_ROUND));

      for(int j=0; j<NUM_GHOSTS; j++) {
        vid_set_sprite_pos(j+1, 224 + j*24 - i * 16, 196);
      }
      get_input();
      if (buttons == 2) break;

      delay(10000);
    }

    if (buttons != 2) delay(200000);
  }


  for(int i=0;i<NUM_SPRITES;i++) vid_enable_sprite(i, 0);
  clear_screen();
}

// Show the start screen
void show_start_screen() {
  // Set up the scree
  clear_screen();
  setup_startscreen();

  show_score(START_HI_SCORE_X, START_HI_SCORE_Y, hi_score);

  show_score(START_1UP_SCORE_X, START_1UP_SCORE_Y, score);

  show_score(START_2UP_SCORE_X, START_2UP_SCORE_Y, 0);

  num_players = 1;

  for(int i = 0; i < 1000; i++) {
    if (i < 240) vid_set_y_ofs(i);

    get_input();

    if (buttons == 1) {
      vid_set_tile(13, 30 + 13 + num_players*2, 0);
      num_players = (num_players == 1 ? 2 : 1);
      vid_set_tile(13, 30 + 13 + num_players*2,28);
      delay(20000);
    }

    if (buttons == 2) break;

    delay(100);
  }

  clear_screen();

  if (buttons != 2) show_intro_screen();
}

void new_life() {
  // Start a new life
  game_start = tick_counter;
  num_lives--;
  ghost_speed = (stage < 16 ? 16 - stage : 0);
  ghost_speed_counter = 0;
  // Start Blinky immediately
  ghost_active[BLINKY-1] = true;
  chomp = true; // Start with open mouth image
  game_over = false;
  life_over = false;
  num_fruit = (stage <= 7 ? stage : 7);
  fruit_counter = 0;
  skip_ticks = 0;
}

// Main entry point
void main() {
  reg_uart_clkdiv = 138;  // 16,000,000 / 115,200
  set_irq_mask(0x00);

  // Initialize the Nunchuk
  i2c_send_cmd(0x40, 0x00);

  // Default high score
  hi_score = 10000;
  score = 0;

  show_start_screen();

  setup_screen();

  // Set up the board
  setup_board();

#ifdef debug
  print_board();
#endif

  // Play music
  songplayer_init(&song_pacman);
  songplayer_start(0);

  // switch to dual IO mode

  reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

  // set timer interrupt to happen 1/50th sec from now
  // (the music routine runs from the timer interrupt)
  set_timer_counter(counter_frequency);

  play = false;
  auto_play = (buttons != 2);

  num_lives = 3;
  num_fruit = 1;
  stage = 1;

  skip_ticks = 0;
  life_over = false;

  // Display the ready message
  show_ready();

  if (auto_play) {
    new_life();
    remove_ready();
  }

  uint32_t time_waster = 0;

  // Main loop
  while (1) {
    time_waster = time_waster + 1;
    if ((time_waster & 0xfff) == 0xfff) {
      // Update tick counter
      tick_counter++;

      // Wait a while. Used to show ghost kill score
      if (skip_ticks > 0) {
        skip_ticks--;
        continue;
      }

      // Delayed set of sprite to eyes
      if (set_ghost_eyes > 0) {
        vid_set_image_for_sprite(set_ghost_eyes, EYES_IMAGE);
        vid_enable_sprite(PACMAN,1);
        set_ghost_eyes = 0;
      }

      // Lost life animation
      if (life_over) {
        if (tick_counter - life_over_start == 2)
          vid_set_image_for_sprite(PACMAN, PACMAN_UP);
        else if (tick_counter - life_over_start == 4)
          vid_set_image_for_sprite(PACMAN, EXPLODE_IMAGE1);
        else if (tick_counter - life_over_start == 6)
          vid_set_image_for_sprite(PACMAN, EXPLODE_IMAGE2);
        else if (tick_counter - life_over_start == 12) {
          vid_set_image_for_sprite(PACMAN, PACMAN_RIGHT);
          if (game_over) {
            // Disable sprites
            for(int i=0;i<NUM_SPRITES;i++) vid_enable_sprite(i, 0);
            clear_screen();
            show_start_screen();
            setup_screen();
            setup_board();
            songplayer_start(0);
          } else {
            reset_positions();
            // Position the sprites to their home positions
            for(int i=0;i<NUM_SPRITES;i++)
              vid_set_sprite_pos(i, 8 + (sprite_x[i] << 4),
                                    8 + (sprite_y[i] << 4));
          }

          if (!auto_play) show_ready();
          else new_life();

          life_over = false;
        }
      }

      if (life_over) continue;

      // Save score
      old_score = score;

      // Show hi-score
      show_hiscore_label();
      show_score(HI_SCORE_X + 2, HI_SCORE_Y + 2, hi_score);

      // Show score
      show_score(SCORE_X, SCORE_Y, score);

#ifdef diag
      // Show stage
      show_score(SCORE_X, SCORE_Y + 4, stage);

      // Show number of food items
      show_score(SCORE_X, SCORE_Y + 2, food_items);

      // Show the tick_counter since game start
      show_score(SCORE_X, SCORE_Y + 3, tick_counter - game_start);
#endif

      // Show fruit
      show_fruit();

      // Show lives
      show_lives();

      // Show 1UP
      show_1up();

      // Flash board for new stage
      if (new_stage) {
        show_board();
        if ((tick_counter - stage_over_start) < STAGE_OVER_TICKS) {
          set_board_colour(tick_counter & 1 ? WHITE : BLUE);
        } else {
          new_stage = false;
          set_board_colour(BLUE);
          setup_screen();
          setup_board();
          show_ready();
          num_lives = 3; // This is probably wrong
        }
      }

      // Get controller input
      get_input();

      // Check buttons for start or restart
      if (buttons < 3) {
        if (buttons == 0 || buttons == 2) {
          auto_play = false;
          if (!play) {
            remove_ready();
            new_life();
          }
          play = true;
          songplayer_stop();
        } else { // Auto play
          new_life();
          auto_play = true;
          play = false;
        }
      }

      // Wait for button to be pressed
      if (!play && !auto_play) continue;

      // Add fruit after a while
      if (fruit_counter++ == FRUIT_TICKS) {
        add_fruit(FRUIT_X, FRUIT_Y);
        fruit_counter = 0;
      }

      // Save last Pacman position and one before last
      old2_sprite_x[PACMAN] = old_sprite_x[PACMAN];
      old2_sprite_y[PACMAN] = old_sprite_y[PACMAN];
      old_sprite_x[PACMAN] = sprite_x[PACMAN];
      old_sprite_y[PACMAN] = sprite_y[PACMAN];

      /* Update Pacman location. If playing, pacman is moved by joystick, otherwise moves himself.
         Direction of moves is determined and chomp alternates as pacman moves. */
      int n = board[sprite_y[PACMAN]][sprite_x[PACMAN]];

      if (play) { // Playing a game
        if (sprite_x[PACMAN] < 30 && jx > 0xc0 && (n & CAN_GO_RIGHT)) {
          sprite_x[PACMAN]++;
          direction=RIGHT;
        } else if (sprite_x[PACMAN] > 0 && jx < 0x40 && (n & CAN_GO_LEFT) ) {
          sprite_x[PACMAN]--;
          direction=LEFT;
         } else if (sprite_y[PACMAN] < 28 && jy < 0x40 && (n & CAN_GO_DOWN)) {
          sprite_y[PACMAN]++;
          direction=DOWN;
         } else if (sprite_y[PACMAN] > 0 && jy > 0xc0 && (n & CAN_GO_UP)) {
          sprite_y[PACMAN]--;
          direction=UP;
         }
      } else { // Auto play
         move_pacman();
      }

      if (sprite_x[PACMAN] != old_sprite_x[PACMAN] ||
          sprite_y[PACMAN] != old_sprite_y[PACMAN]) chomp = !chomp;

      // Set Pacman sprite position
      vid_set_sprite_pos(PACMAN, TILE_SIZE + (sprite_x[PACMAN] << 4),
                                 TILE_SIZE + (sprite_y[PACMAN] << 4));

      // Is it time to let Pinky out?
      if (tick_counter == (game_start + PINKY_START)) {
        sprite_x[PINKY] = 7;
        sprite_y[PINKY] = 8;
      } else if (tick_counter == (game_start + PINKY_START+1)) {
        sprite_y[PINKY] = 7;
        ghost_active[PINKY-1] = true;
      }

      // What about Inky?
      if (tick_counter == (game_start + INKY_START)) {
        ghost_active[INKY-1] = true;
        sprite_x[INKY] = 7;
        sprite_y[INKY] = 7;
      }

      // What about Clyde?
      if (tick_counter == (game_start + CLYDE_START)) {
        ghost_active[CLYDE-1] = true;
        sprite_x[CLYDE] = 7;
        sprite_y[CLYDE] = 7;
      }

      // Move ghosts
      for(int i=0; i<NUM_GHOSTS;i++) {
        if (ghost_eyes[i] || (ghost_speed_counter == ghost_speed)) {
          // Save last ghost position and one before last
          old2_sprite_x[i+1] = old_sprite_x[i+1];
          old2_sprite_y[i+1] = old_sprite_y[i+1];
          old_sprite_x[i+1] = sprite_x[i+1];
          old_sprite_y[+1] = sprite_y[i+1];
          move_ghost(i+1);
        }
      }

      if (ghost_speed_counter++ == ghost_speed) ghost_speed_counter = 0;

      // Check for death
      for(int i=0;i<NUM_GHOSTS;i++) {
        if ((sprite_x[PACMAN] == sprite_x[i+1] &&
             sprite_y[PACMAN] == sprite_y[i+1]) && !ghost_eyes[i]) {
          if (hunting > 0) {
            score += ghost_points;
            vid_set_image_for_sprite(i+1, SCORE_IMAGE + kills++);
            vid_set_sprite_colour(i+1, WHITE);
            skip_ticks = HUNT_SCORE_TICKS;
            set_ghost_eyes = i+1;
            ghost_eyes[i] = true;
            ghost_points <= 1;
            vid_enable_sprite(PACMAN, 0);
          } else { // Lost a life
            if (num_lives == 0) {
              // Game over
              game_over = true;
              stage = 1;
              score = 0;
              // Reset lives and fruit
              num_lives = 3;
              show_game_over();
            } else {
              songplayer_trigger_effect(8);
            }
            life_over = true;

            // Set the ghosts inactive
            for(int i=0;i<NUM_GHOSTS;i++) ghost_active[i] = false;

            // Start the explode animation
            vid_set_image_for_sprite(PACMAN, PACMAN_ROUND);
            life_over_start = tick_counter;
            play = false;
            break;
          }
        }
      }

      if (life_over) continue;

      // Set the approriate Pacman image
      vid_set_image_for_sprite(PACMAN, PACMAN_ROUND + chomp ?  1 + direction : 0);

      // Set ghost sprite positions and make them jump (other than blinky)
      for(int i=0;i<NUM_GHOSTS;i++)
        vid_set_sprite_pos(i+1, TILE_SIZE + (sprite_x[i+1] << 4),
                                TILE_SIZE + ((sprite_y[i+1] -
                                ((!ghost_active[i] && i+1 != BLINKY) &
                                tick_counter & 1)) << 4));

      // Eat your food
      n = board[sprite_y[PACMAN]][sprite_x[PACMAN]];
      if (n & FOOD || n & BIG_FOOD || n & FRUIT) {
         if (n & FOOD | n & BIG_FOOD) food_items--;
         if (n & FRUIT) food_items--;

         vid_set_tile(sprite_x[PACMAN]*2 + 1, sprite_y[PACMAN]*2 + 1, BLANK_TILE);
         vid_set_tile(sprite_x[PACMAN]*2 + 2, sprite_y[PACMAN]*2 + 1, BLANK_TILE);
         vid_set_tile(sprite_x[PACMAN]*2 + 1, sprite_y[PACMAN]*2 + 2, BLANK_TILE);
         vid_set_tile(sprite_x[PACMAN]*2 + 2, sprite_y[PACMAN]*2 + 2, BLANK_TILE);

         score += (n & BIG_FOOD ? BIG_FOOD_POINTS :
                  ( n & FRUIT ? (stage == 1 ? CHERRY_POINTS :
                                (stage == 2 ? STRAWBERRY_POINTS : ORANGE_POINTS)) : FOOD_POINTS));
         board[sprite_y[PACMAN]][sprite_x[PACMAN]] &= ~(FOOD | BIG_FOOD | FRUIT);

         if (n & BIG_FOOD) {
           songplayer_trigger_effect(9);  /* trigger eat pill sound effect */
         } else if (n & FOOD) {
           songplayer_trigger_effect(10);  /* trigger waka waka noise */
         }
         if (n & BIG_FOOD && !hunting) {
           hunting = 1;
           kills = 0;
           hunt_start = tick_counter;
           ghost_points = GHOST_POINTS;
           for(int i=0;i<NUM_GHOSTS;i++) vid_set_sprite_colour(i+1, BLUE);
         }
      }

      // Check for end of hunting
      if (hunting == 1 && (tick_counter - hunt_start) > HUNT_TICKS) { // End of blue phase
        for(int i=0;i<NUM_GHOSTS;i++) vid_set_sprite_colour(i+1, WHITE);
        hunting = 2;
        hunt_start = tick_counter;
      } else if (hunting == 2 && (tick_counter - hunt_start) > HUNT_TICKS) { // End of white phase
        end_hunt();
        if (sprite_x[BLINKY] == 7 && sprite_y[BLINKY] == 8) sprite_y[BLINKY] = 7;
      }

      // Flash ghosts when hunting
      if (hunting == 2)
        for(int i=0;i<NUM_GHOSTS;i++)
          if (sprite_x[i+1] != 7 || sprite_y[i+1] != 8)
            vid_enable_sprite(i+1, tick_counter & 1);

      // Extra live after 10000 points
      if (score >= LIFE_POINTS && old_score < LIFE_POINTS) num_lives++;

      // If score goes over hi-score, set hi-score
      if (score > hi_score) hi_score = score;

      // Check for stage won
      if (play && food_items == 0) {
        end_hunt();
        clear_board();
        stage_over_start = tick_counter;
        new_stage = true;
        stage++;
        play = false;
        for(int i=0;i<NUM_SPRITES;i++) vid_enable_sprite(i,0);
      }

      // Flash 1UP and power pills
      if ((tick_counter & 1) == 1) {
        show_1up();
        if (board[POWER_PILL1_Y][POWER_PILL1_X] & BIG_FOOD)
          show_big_tile(POWER_PILL1_X, POWER_PILL1_Y,
                        POWER_PILL_TILE1, POWER_PILL_TILE2, POWER_PILL_TILE3, POWER_PILL_TILE4);
        if (board[POWER_PILL2_Y][POWER_PILL2_X] & BIG_FOOD)
          show_big_tile(POWER_PILL2_X, POWER_PILL2_Y,
                        POWER_PILL_TILE1, POWER_PILL_TILE2, POWER_PILL_TILE3, POWER_PILL_TILE4);
        if (board[POWER_PILL3_Y][POWER_PILL3_X] & BIG_FOOD)
          show_big_tile(POWER_PILL3_X, POWER_PILL3_Y,
                        POWER_PILL_TILE1, POWER_PILL_TILE2, POWER_PILL_TILE3, POWER_PILL_TILE4);
        if (board[POWER_PILL4_Y][POWER_PILL4_X] & BIG_FOOD)
          show_big_tile(POWER_PILL4_X, POWER_PILL4_Y,
                        POWER_PILL_TILE1, POWER_PILL_TILE2, POWER_PILL_TILE3, POWER_PILL_TILE4);
      } else {
        for(int i=0;i<3;i++) vid_set_tile(32+i, 7, BLANK_TILE);
        show_big_tile(POWER_PILL1_X, POWER_PILL1_Y,
                      BLANK_TILE, BLANK_TILE, BLANK_TILE, BLANK_TILE);
        show_big_tile(POWER_PILL2_X, POWER_PILL2_Y,
                      BLANK_TILE, BLANK_TILE, BLANK_TILE, BLANK_TILE);
        show_big_tile(POWER_PILL3_X, POWER_PILL3_Y,
                      BLANK_TILE, BLANK_TILE, BLANK_TILE, BLANK_TILE);
        show_big_tile(POWER_PILL4_X, POWER_PILL4_Y,
                      BLANK_TILE, BLANK_TILE, BLANK_TILE, BLANK_TILE);
      }
    }
  }
}
