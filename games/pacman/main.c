#include <stdint.h>
#include <stdbool.h>

#include <audio/audio.h>
#include <video/video.h>
#include <songplayer/songplayer.h>
#include <uart/uart.h>
#include <sine_table/sine_table.h>
#include <nunchuk/nunchuk.h>

#include "graphics_data.h"

#define debug 1

#define abs(x) (x < 0 ? -x : x)

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_leds  (*(volatile uint32_t*)0x03000000)

extern const struct song_t song_pacman;

#define TILE_SIZE 8

#define CAN_GO_LEFT 1
#define CAN_GO_RIGHT 2
#define CAN_GO_UP 4
#define CAN_GO_DOWN 8
#define FOOD 16
#define BIG_FOOD 32
#define FRUIT 64

#define BLANK_TILE 0

#define FOOD_TILE1 4
#define FOOD_TILE2 5
#define FOOD_TILE3 12
#define FOOD_TILE4 13

#define BIG_FOOD_TILE1 40
#define BIG_FOOD_TILE2 41
#define BIG_FOOD_TILE3 48
#define BIG_FOOD_TILE4 49

#define ZERO_TILE 16

#define U_TILE 26
#define P_TILE 27

#define H_TILE 32
#define I_TILE 33
#define S_TILE 34
#define C_TILE 35
#define O_TILE 36
#define R_TILE 37
#define E_TILE 38

#define CHERRY_TILE 42
#define PACMAN_TILE 46

#define FOOD_POINTS 10
#define BIG_FOOD_POINTS 50
#define FRUIT_POINTS 100
#define GHOST_POINTS 200

#define FRUIT_X 7
#define FRUIT_Y 3

#define UP 2
#define DOWN 1
#define LEFT 3
#define RIGHT 0

#define BLACK 0
#define RED 1
#define GREEN 2
#define YELLOW 3
#define BLUE 4
#define MAGENTA 5
#define CYAN 6
#define WHITE 7

#define HUNT_TICKS 30

const uint8_t pacman = 0;
const uint8_t inky = 1;
const uint8_t pinky = 2;
const uint8_t blinky = 3;
const uint8_t clyde = 4;

uint32_t counter_frequency = 16000000/50;  /* 50 times per second */
uint32_t led_state = 0x00000000;

uint8_t board[14][15];
uint8_t pacman_image, pac_x, pac_y, ghost_image;
uint8_t inky_x, blinky_x, pinky_x, clyde_x;
uint8_t inky_y, blinky_y, pinky_y, clyde_y;
uint16_t score, hi_score;
bool play, chomp;
uint8_t direction;
uint8_t pacman_images[8];
uint8_t ghost_images[8];
uint8_t hunting;
uint32_t hunt_start;
uint32_t tick_counter;
uint16_t food_items;
bool game_over, new_stage;
uint8_t stage;
uint8_t num_cherries, num_lives;
bool inky_active, pinky_active, blnk_active, clyde_active;

uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

uint32_t set_timer_counter(uint32_t val); asm (
    ".global set_timer_counter\n"
    "set_timer_counter:\n"
    ".word 0x0a05650b\n"
    "ret\n"
);

void clear_screen() {
 for (int x = 0; x < 32; x++) {
    for (int y = 0; y < 32; y++) {
      vid_set_tile(x,y,BLANK_TILE);
    }
  }
}

void setup_board() {
  food_items = 0;
  for(int y = 0; y < 14; y++) {
    for(int x = 0;  x < 15; x++) {
      uint8_t n = 0;
      uint8_t t = tile_data[((y*2 + 1) << 5) + x*2 + 1];

      if (t != BLANK_TILE && t != FOOD_TILE1 && t != BIG_FOOD_TILE1) continue;

      if (x == FRUIT_X && y == FRUIT_Y) {
        n |= FRUIT;
        food_items++;
      } else if (t == FOOD_TILE1) {
        n |= FOOD;
        food_items++;
      } else if (t == BIG_FOOD_TILE1) {
        n |= BIG_FOOD;
        food_items++;
      }

      if (y > 0) {
        uint8_t above = tile_data[(((y-1)*2 + 2) << 5) + x*2 + 1];
        if (above == BLANK_TILE || above == FOOD_TILE3 || above == BIG_FOOD_TILE3) n |= CAN_GO_UP;
      }

      if (y < 13) {
        uint8_t below = tile_data[(((y+1)*2 + 1) << 5) + x*2 + 1];
        if (below == BLANK_TILE || below == FOOD_TILE1 || below == BIG_FOOD_TILE1) n |= CAN_GO_DOWN;
      }

      if (x > 0) {
        uint8_t left = tile_data[((y*2 + 1) << 5) + (x-1)*2 + 2];
        if (left == BLANK_TILE || left == FOOD_TILE2 || left == BIG_FOOD_TILE2) n |= CAN_GO_LEFT;
      }

      if (x < 14) {
        uint8_t right = tile_data[((y*2 + 1) << 5) + (x+1)*2 + 1];
        if (right == BLANK_TILE || right == FOOD_TILE1 || right == BIG_FOOD_TILE1) n |= CAN_GO_RIGHT;
      }

      board[y][x] = n;
    }
  }
}

void show_board() {
  for (int x = 0; x < 32; x++) {
    for (int y = 0; y < 32; y++) {
     uint8_t t = tile_data[(y<<5)+x];
     if (t < 16 && t != 4 && t != 5 && t != 12 && t != 13) vid_set_tile(x,y,t);
    }
  }
}

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

void reset_positions() {
  pac_x = 7;
  pac_y = 11;
  direction = RIGHT;
  inky_x = 7;
  inky_y = 7;
  pinky_x = 6;
  pinky_y = 10;
  blinky_x = 7;
  blinky_y = 10;
  clyde_x = 8;
  clyde_y = 10;
  num_cherries = 1;
  num_lives = 3;
  chomp = true;
}

void add_fruit(uint8_t x, uint8_t y) {
  vid_set_tile(2*x + 1,2*y + 1, CHERRY_TILE);
  vid_set_tile(2*x + 2,2*y + 1, CHERRY_TILE+1);
  vid_set_tile(2*x + 1,2*y + 2, CHERRY_TILE+8);
  vid_set_tile(2*x + 2,2*y + 2, CHERRY_TILE+9);
}

void set_ghost_colours() {
  vid_set_sprite_colour(inky, CYAN);
  vid_set_sprite_colour(pinky, MAGENTA);
  vid_set_sprite_colour(blinky, RED);
  vid_set_sprite_colour(clyde, GREEN);
}

void setup_screen() {
  vid_init();
  vid_set_x_ofs(0);
  vid_set_y_ofs(0);
  int tex,x,y;

  for (tex = 0; tex < 64; tex++) {
    for (x = 0; x < 8; x++) {
      for (y = 0 ; y < 8; y++) {
        int texrow = tex >> 3;   // 0-7, row in texture map
        int texcol = tex & 0x07; // 0-7, column in texture map
        int pixx = (texcol<<3)+x;
        int pixy = (texrow<<3)+y;
        uint32_t pixel = texture_data[(pixy<<6)+pixx];
        vid_set_texture_pixel(tex, x, y, pixel);
      }
    }
  }

  for (x = 0; x < 32; x++) {
    for (y = 0; y < 32; y++) {
      vid_set_tile(x,y,tile_data[(y<<5)+x]);
    }
  }

  add_fruit(FRUIT_X, FRUIT_Y);

  reset_positions();

  for(int i=0;i<8;i++) pacman_images[i] = i;
  for(int i=0; i<8; i++) vid_write_sprite_memory(pacman_images[i], pacman_sprites[i]);
  pacman_image = pacman_images[0];

  for(int i=0;i<8;i++) ghost_images[i] = 8+i;
  for(int i=0; i<8; i++) vid_write_sprite_memory(ghost_images[i], ghost_sprites[i]);
  ghost_image = ghost_images[0];

  set_ghost_colours();
  vid_set_sprite_colour(pacman, YELLOW);

  vid_set_sprite_pos(pacman, 8 + (pac_x << 4), 8 + (pac_y << 4));
  vid_set_sprite_pos(inky, 8 + (inky_x << 4), 8 + (inky_y << 4));
  vid_set_sprite_pos(pinky, 8 + (pinky_x << 4), 8 + (pinky_y << 4));
  vid_set_sprite_pos(blinky, 8 + (blinky_x << 4), 8 + (blinky_y << 4));
  vid_set_sprite_pos(clyde, 8 + (clyde_x << 4), 8 + (clyde_y << 4));

  vid_set_image_for_sprite(pacman, pacman_image);
  vid_set_image_for_sprite(inky, ghost_image);
  vid_set_image_for_sprite(pinky, ghost_image);
  vid_set_image_for_sprite(blinky, ghost_image);
  vid_set_image_for_sprite(clyde, ghost_image);

  vid_enable_sprite(pacman, 1);
  vid_enable_sprite(inky, 1);
  vid_enable_sprite(pinky, 1);
  vid_enable_sprite(blinky, 1);
  vid_enable_sprite(clyde, 1);
}

void show_cherries() {
  for(int i=0;i<num_cherries;i++) {
    vid_set_tile(32 + i*2, 16, CHERRY_TILE);
    vid_set_tile(33 + i*2, 16, CHERRY_TILE+1);
    vid_set_tile(32 + i*2, 17, CHERRY_TILE+8);
    vid_set_tile(33 + i*2, 17, CHERRY_TILE+9);
  }
}

void show_lives() {
  for(int i=0;i<num_lives;i++) {
    vid_set_tile(32 + i*2, 22, PACMAN_TILE);
    vid_set_tile(33 + i*2, 22, PACMAN_TILE+1);
    vid_set_tile(32 + i*2, 23, PACMAN_TILE+8);
    vid_set_tile(33 + i*2, 23, PACMAN_TILE+9);
  }
}

void irq_handler(uint32_t irqs, uint32_t* regs)
{
  /* fast IRQ (4) */
  if ((irqs & (1<<4)) != 0) {
    // print_str("[EXT-IRQ-4]");
  }

  /* slow IRQ (5) */
  if ((irqs & (1<<5)) != 0) {
    // print_str("[EXT-IRQ-5]");
  }

  /* timer IRQ */
  if ((irqs & 1) != 0) {
    // retrigger timer
    set_timer_counter(counter_frequency);

    led_state = led_state ^ 0x01;
    reg_leds = led_state;
    songplayer_tick();
  }
}

const int divisor[] = {10000,1000,100,10};

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

void move_inky() {
  if (!inky_active) return;
  uint8_t n = board[inky_y][inky_x];

  if (hunting == 0) {
    if (pac_x < inky_x && (n & CAN_GO_LEFT)) inky_x--;
    else if (pac_x > inky_x && (n & CAN_GO_RIGHT)) inky_x++;
    else if (pac_y < inky_y && (n & CAN_GO_UP)) inky_y--;
    else if (pac_y > inky_y && (n & CAN_GO_DOWN)) inky_y++;
    else if (n & CAN_GO_LEFT) inky_x--;
    else if (n & CAN_GO_RIGHT) inky_x++;
    else if (n & CAN_GO_DOWN) inky_y--;
    else if (n & CAN_GO_UP) inky_y++;
  } else {
    if (pac_x > inky_x && (n & CAN_GO_LEFT)) inky_x--;
    else if (pac_x < inky_x && (n & CAN_GO_RIGHT)) inky_x++;
    else if (pac_y > inky_y && (n & CAN_GO_UP)) inky_y--;
    else if (pac_y < inky_y && (n & CAN_GO_DOWN)) inky_y++;
    else if (n & CAN_GO_LEFT) inky_x--;
    else if (n & CAN_GO_RIGHT) inky_x++;
    else if (n & CAN_GO_DOWN) inky_y--;
    else if (n & CAN_GO_UP) inky_y++;
  }
}


void move_pinky() {
  if (!pinky_active) return;
  uint8_t n = board[inky_y][inky_x];

  if (hunting == 0) {
    if (pac_x < inky_x && (n & CAN_GO_LEFT)) inky_x--;
    else if (pac_x > inky_x && (n & CAN_GO_RIGHT)) inky_x++;
    else if (pac_y < inky_y && (n & CAN_GO_UP)) inky_y--;
    else if (pac_y > inky_y && (n & CAN_GO_DOWN)) inky_y++;
    else if (n & CAN_GO_LEFT) inky_x--;
    else if (n & CAN_GO_RIGHT) inky_x++;
    else if (n & CAN_GO_DOWN) inky_y--;
    else if (n & CAN_GO_UP) inky_y++;
  } else {
    if (pac_x > inky_x && (n & CAN_GO_LEFT)) inky_x--;
    else if (pac_x < inky_x && (n & CAN_GO_RIGHT)) inky_x++;
    else if (pac_y > inky_y && (n & CAN_GO_UP)) inky_y--;
    else if (pac_y < inky_y && (n & CAN_GO_DOWN)) inky_y++;
    else if (n & CAN_GO_LEFT) inky_x--;
    else if (n & CAN_GO_RIGHT) inky_x++;
    else if (n & CAN_GO_DOWN) inky_y--;
    else if (n & CAN_GO_UP) inky_y++;
  }
}

void move_blinky() {
}

void move_clyde() {
}

void move_eyes() {
}

void delay(uint32_t n) {
  for (uint32_t i = 0; i < n; i++) asm volatile ("");
}

void main() {
  reg_uart_clkdiv = 138;  // 16,000,000 / 115,200
  set_irq_mask(0x00);

  audio_set_global_volume(0xff);
  setup_screen();

  setup_board();
  print_board();

  songplayer_init(&song_pacman);

  // switch to dual IO mode
  reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

  // set timer interrupt to happen 1/50th sec from now
  // (the music routine runs from the timer interrupt)
  set_timer_counter(counter_frequency);

  // Initialize the Nunchuk
  i2c_send_cmd(0x40, 0x00);

  int old_x = 255, old_y = 255, old2_x = 255, old2_y = 255;
  score = 0;
  hi_score = 10000;

  // Score HI-SCORE
  vid_set_tile(32,2, H_TILE);
  vid_set_tile(33,2, I_TILE);
  vid_set_tile(35,2, S_TILE);
  vid_set_tile(36,2, C_TILE);
  vid_set_tile(37,2, O_TILE);
  vid_set_tile(38,2, R_TILE);
  vid_set_tile(39,2, E_TILE);

  play = false;
  new_stage = false;

  // Show cherries
  show_cherries();

  // Show lives
  show_lives();

  inky_active = true;

  uint32_t time_waster = 0;

  // Main loop
  while (1) {
    time_waster = time_waster + 1;
    if ((time_waster & 0xfff) == 0xfff) {
      // Update tick counter
      tick_counter++;

      // Get Nunchuk data
      i2c_send_reg(0x00);
      delay(100);

      uint8_t jx = i2c_read();
#ifdef debug
      print("Joystick x: ");
      print_hex(jx, 2);
      print("\n");
#endif

      uint8_t jy = i2c_read();
#ifdef debug
      print("Joystick y: ");
      print_hex(jy, 2);
      print("\n:1");
#endif

      uint8_t ax = i2c_read();
#ifdef debug
      print("Accel  x: ");
      print_hex(ax, 2);
      print("\n");
#endif

      uint8_t ay = i2c_read();
#ifdef debug
      print("Accel  x: ");
      print_hex(ay, 2);
      print("\n");
#endif

      uint8_t az = i2c_read();
#ifdef debug
      print("Accel  x: ");
      print_hex(az, 2);
      print("\n");
#endif

      uint8_t rest = i2c_read();
#ifdef debug
      print("Buttons: ");
      print_hex(rest & 3, 2);
      print("\n");
#endif
      uint8_t buttons = rest & 3;

      // Check buttons for start or restart
      if (buttons < 2) {
        new_stage = false;
        setup_screen();
        setup_board();
        score = 0;
        inky_active = true;
        hunting = 0;
        show_score(34, 12, stage);
        play = (buttons == 0);
      }

      // Save last Pacman position and one before last
      old2_x = old_x;
      old2_y = old_y;
      old_x = pac_x;
      old_y = pac_y;

      /* Update Pacman location. If playing, pacman is moved by joystick, otherwise moves himself.
         Direction of moves is determined and chomp alternates as pacman moves. */
      int n = board[pac_y][pac_x];
      if (play) { // Playing a game
         if (pac_x < 30 && jx > 0xc0 && (n & CAN_GO_RIGHT)) {chomp = !chomp; pac_x++; direction=RIGHT;}

         else if (pac_x > 0 && jx < 0x40 && (n & CAN_GO_LEFT) ) {chomp = !chomp; pac_x--; direction=LEFT;}
         else if (pac_y < 28 && jy < 0x40 && (n & CAN_GO_DOWN)) {chomp = !chomp; pac_y++; direction=DOWN;}
         else if (pac_y > 0 && jy > 0xc0 && (n & CAN_GO_UP)) {chomp = !chomp; pac_y--; direction=UP;}
       } else { // Game animation
        if ((n & CAN_GO_UP) && (pac_y-1 != old2_y)) {pac_y--; direction=UP;}
        else if ((n & CAN_GO_RIGHT) && (pac_x+1 != old2_x)) {pac_x++; direction=RIGHT;}
        else if ((n & CAN_GO_DOWN) && (pac_y+1 != old2_y)) {pac_y++; direction=DOWN;}
        else if ((n & CAN_GO_LEFT) && (pac_x-1 == old2_x)) {pac_x--; direction=LEFT;}
        chomp = !chomp;
      }

      // Set Pacman sprite position
      vid_set_sprite_pos(pacman, TILE_SIZE + (pac_x << 4), TILE_SIZE + (pac_y << 4));

      // Move inky
      if ((time_waster & 0x7FFF) == 0x7FFF) move_inky();

      // Check for death
      if (pac_x == inky_x && pac_y == inky_y) {
        if (hunting > 0) {
          score += GHOST_POINTS;
          vid_set_image_for_sprite(inky, ghost_images[1]);
          vid_set_sprite_colour(inky, WHITE);
        } else {
          clear_screen();
          game_over = true;
          pac_x = 3; pac_y = 3;
          inky_x = 5; inky_y = 3;
          pinky_x = 7; pinky_y = 3;
          blinky_x = 9; blinky_y = 3;
          clyde_x = 11; clyde_y = 3;
          play = false;
          stage = 0;
        }
      }

      // Set the approriate Pacman image
      vid_set_image_for_sprite(pacman, pacman_images[chomp ?  pacman_images[1 + direction] : 0]);

      // Set ghost sprite positions
      bool ghost_up = tick_counter & 1;
      vid_set_sprite_pos(inky, TILE_SIZE + (inky_x << 4),
                               TILE_SIZE + (inky_y << 4));
      vid_set_sprite_pos(pinky, TILE_SIZE + (pinky_x << 4),
                                TILE_SIZE + ((pinky_y - ghost_up) << 4));
      vid_set_sprite_pos(blinky, TILE_SIZE + (blinky_x << 4),
                                 TILE_SIZE + ((blinky_y - ghost_up) << 4));
      vid_set_sprite_pos(clyde, TILE_SIZE + (clyde_x << 4),
                                 TILE_SIZE + ((clyde_y - ghost_up) << 4));

      // Eat your food
      n = board[pac_y][pac_x];
      if (n & FOOD || n & BIG_FOOD || n & FRUIT) {
         food_items--;
         vid_set_tile(pac_x*2 + 1, pac_y*2 + 1, BLANK_TILE);
         vid_set_tile(pac_x*2 + 2, pac_y*2 + 1, BLANK_TILE);
         vid_set_tile(pac_x*2 + 1, pac_y*2 + 2, BLANK_TILE);
         vid_set_tile(pac_x*2 + 2, pac_y*2 + 2, BLANK_TILE);
         score += (n & BIG_FOOD ? BIG_FOOD_POINTS : ( n & FRUIT ? FRUIT_POINTS : FOOD_POINTS));
         board[pac_y][pac_x] &= ~(FOOD | BIG_FOOD | FRUIT);

         if (n & BIG_FOOD) {
           hunting = 1;
           hunt_start = tick_counter;
           vid_set_sprite_colour(inky, BLUE);
           vid_set_sprite_colour(pinky, BLUE);
           vid_set_sprite_colour(blinky, BLUE);
           vid_set_sprite_colour(clyde, BLUE);
         }
      }

      // Check for end of hunting
      if (hunting == 1 && (tick_counter - hunt_start) > HUNT_TICKS) { // End of blue phase
         vid_set_sprite_colour(inky, WHITE);
         vid_set_sprite_colour(pinky, WHITE);
         vid_set_sprite_colour(blinky, WHITE);
         vid_set_sprite_colour(clyde, WHITE);
         hunting = 2;
         hunt_start = tick_counter;
      } else if (hunting == 2 && (tick_counter - hunt_start) > HUNT_TICKS) { // End of white phase
         hunting = 0;
         set_ghost_colours();
         vid_enable_sprite(inky, 1);
         vid_set_image_for_sprite(inky, ghost_images[0]);
      }

      // Flash ghosts when hunting
      if (hunting == 2) vid_enable_sprite(inky, tick_counter & 1);

      // Show the score
      show_score(34, 8, score);

      // Show hi-score
      if (score > hi_score) hi_score = score;
      show_score(34, 4, hi_score);

      // Show number of food items
      show_score(34, 10, food_items);

      // Check for stage won
      if (food_items == 0) {
        clear_screen();
        hunting = 0;
        vid_enable_sprite(inky, 1);
        set_ghost_colours();
        new_stage = true;
        if (play) stage++;
        play = false;
      }

      // Flash board for new stage
      if (new_stage) {
        if (tick_counter & 2) clear_screen();
        else show_board();
      }

      // Flash 1UP
      if ((tick_counter & 1) == 1) {
        vid_set_tile(32, 7, ZERO_TILE + 1);
        vid_set_tile(33, 7, U_TILE);
        vid_set_tile(34, 7, P_TILE);

      } else {
        for(int i=0;i<3;i++) vid_set_tile(32+i, 7, BLANK_TILE);
      }
    }
  }
}
