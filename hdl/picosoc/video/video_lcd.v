/*
 * Video peripheral for TinyFPGA game SoC
 *
 * 320x240 tile map based graphics adaptor
 *
 * register map:
 *
 * -------------
 *  reg #  | width  | description
 * -----------------|---------------
 * 0..7    | 32bits | sprite control
 *         |        |  [8:0] sprite y (9-bit signed)
 *         |        |  [18:9] sprite x (10-bit signed)
 *         |        |  [23:19] sprite index (0..32)
 *         |        |  [27:24] sprite palette (4-bit)
 *         |        |  [28] enable
 *         |        |  [30:29] sprite XY flip
 * --------+--------+----------------------------------
 * 8       | 32bits |  tile map offset
 *         |        |   [8:0]  xoffset (0..511)
 *         |        |  [23:16] y offset (0..255)
 * --------+--------+----------------------------------
 * 9       | 32bits |  window control
 *         |        |   [31]: window enable
 *         |        |    [4:0]: window start line  (0..29)
 *         |        |   [12:8]: window end line    (0..29)
 * --------+--------+----------------------------------
 * 10      | 32bits |  Y interrupt (work in progress)
 *         |        |  [8:0] - generate a raster interrupt when Y hits this line
 * --------+--------+----------------------------------
 * 11-14   | 32bits |  bullet Y/2 [7:0]
 *         |        |  bullet X/2 [15:8]
 * -------------------------------------------------------------------------------
 */
`default_nettype none

module video_lcd
(
  input resetn,
  input clk,
	input iomem_valid,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
  output reg       nreset,
  output reg       cmd_data, // 1 => Data, 0 => Command
  output reg       write_edge, // Write signal on rising edge
  output reg irq,
  output reg [7:0] dout);

  wire video_active;

  localparam NUM_SPRITES = 8;
  localparam NUM_BULLETS = 2;

  // registers as per register map above
	reg [31:0] config_register_bank [0:3+NUM_SPRITES+NUM_BULLETS-1];  /* 8xsprite config + x/y pos + window control + y interrupt + 4xbullet sprites */

  /* 15-colour global palette (each can be one of 64 total colours (RRGGBB))*/
  reg [5:0] palette [0:15];

  /* 16 x 4-colour sub-palette entries - sprites and tiles can choose an entry from
     here to define which 4 colours are available for that sprite/tile.
     Each "colour" is 4-bits (4 colours fit into the 16-bit value), and each
     4-bit colour is an index into the global palette above.
  */
  reg [15:0] sub_palette[0:15];

  /* IO mapping; determine where CPU writes go to */
  wire [3:0] bank_addr = iomem_addr[5:2];

  wire config_reg_select = (iomem_valid && (iomem_addr[23:20]==4'h0));
  wire texmem_write = (iomem_valid && (iomem_wstrb[0] && iomem_addr[23:20]==4'h1));
  wire colourmem_write = (iomem_valid && (iomem_wstrb[1] && iomem_addr[23:20]==4'h2));
  wire spritemem_select = (iomem_valid && (iomem_addr[23:20]==4'h3));
  wire palette_select = (iomem_valid && (iomem_addr[23:20]==4'h4));
  wire sub_palette_select = (iomem_valid && (iomem_addr[23:20]==4'h5));
  wire window_write = (iomem_valid && (iomem_wstrb[1] && iomem_addr[23:20]==4'h6));

  /* data coming from tile+tile colour memory
     - "tile" is an 8-bit index into the tile (character generator) RAM;
     - colour is a 4-bit index into the sub-palette to choose which 4-colour
       sub-palette to apply to this tile.
  */
  wire [11:0] tile_and_colourmem_data;

  /* tile+colour data coming from the windowed (non-moveable) screen area */
  wire [11:0] window_tile_and_colourmem_data;

  /* data coming from texture memory (after looking up tile and finding
     appropriate offset based on current raster position). */
  wire [1:0] texture_read_data;


  // -------------------------------------------------------------------

  /* x and y offsets for the tile map.

     The tile map is a 64x32 grid, but there's only room for 40x30 tiles on
     the screen at any given time.  These offset registers allow the viewport
     to be positioned anywhere in the tilemap.

     The registers are only updated during the vsync window to prevent screen
     tearing while scrolling.
   */
  reg [8:0] xofs;
  reg [7:0] yofs;

  always @(posedge clk) begin
    if (vga_vsync) begin
      xofs <= config_register_bank[8][8:0];   // 9 bits
      yofs <= config_register_bank[8][23:16]; // 8 bits
    end
  end

  // -------------------------------------------------------------------

  // The registers below control the "non-scrolling window".  This is a
  // separate tile map - stored in separate RAM - which has enough space for
  // 4 40-character lines of text.
  // When enabled, the window can be positioned by setting the start and end
  // tile lines (0..29) to display the window in.

  wire window_enable = config_register_bank[9][31];
  wire [4:0] window_line_start = config_register_bank[9][4:0];  // 0 .. 29
  wire [4:0] window_line_end = config_register_bank[9][12:8];   // 0 .. 29

  // calculate the effective x/y positions in the tile map of the raster,
  // when the viewport offset is taken into account
  wire [8:0] effective_y = half_ypos+yofs;
  wire [8:0] effective_x = half_xpos+xofs;

  // the below calculates the tile array index to read based on raster position.
  // tiles are 8 pixels wide/high, so X+Y co-ordinates are divided by 8.
  // - eg. y*64+x
  wire [11:0] tile_read_address = { effective_y[8:3], effective_x[8:3] };

  // and the below calculates the index into the non-moveable window memory
  // to read (y*64+x again).
  // window_y_pos = current y index into the window (0-3);
  wire [1:0] window_y_pos = half_ypos[4:3] - window_line_start[1:0];
  wire [7:0] window_read_address = { window_y_pos, half_xpos[8:3] };

  // 64x32 tile (& tile colour) memory
  // memory is arranged in a 64x32 grid of 12-bit values
  // top 4-bits is colour (actually, a 4-bit index into the sub-palette register)
  // the lower 8-bits is the texture/tile number.
  tile_and_colour_memory tile_and_colourmem(
    .clk(clk),
    .ren(1'b1),
    .raddr(tile_read_address),
    .rdata(tile_and_colourmem_data),
    .wen(colourmem_write),
    .waddr(iomem_addr[13:2]),
    .wdata(iomem_wdata[11:0])
  );

  // similar to tile memory above, but only enough data for a few lines of
  // non-scrolling data
  window_memory window_mem(
    .clk(clk),
    .raddr(window_read_address),
    .rdata(window_tile_and_colourmem_data),
    .wen(window_write),
    .waddr(iomem_addr[9:2]),
    .wdata(iomem_wdata[11:0])
  );

  // a flag to indicate whether the raster is currently in the non-scrollable window
  wire in_window = window_enable && ((half_ypos[7:3] >= window_line_start) && (half_ypos[7:3] <= window_line_end));

  // MUX that returns either window, or normal background texture data
  wire [11:0] tile_or_window_data = in_window ? window_tile_and_colourmem_data : tile_and_colourmem_data;

  // address to read texture data from - this changes depending on whether we're in the non-scrolling window or not,
  // because the non-scrolling window doesn't use the viewport offset.
  wire [13:0] texture_read_address = in_window ? { tile_or_window_data[7:0], half_ypos[2:0], half_xpos[2:0] }
                                          : { tile_or_window_data[7:0], effective_y[2:0], effective_x[2:0] };

  // texture (or tile) memory - contains 256 8x8 x 2-bit textures.
  texture_memory texturemem(
    .clk(clk),
    .raddr(texture_read_address), .rdata(texture_read_data),
    .wen(texmem_write), .waddr(iomem_addr[15:2]), .wdata(iomem_wdata[1:0])
  );

  // 4-entry sub-palette of the currently displayed tile
  wire [15:0] tile_palette = sub_palette[tile_or_window_data[11:8]];

  // calculated global-palette index based on the current 2-bit texture value
  // (this is looked up by selecting the appropriate bits out of the sub-palette above).
  wire [3:0] texture_colour_index = (texture_read_data == 2'b00) ? tile_palette[3:0]
                            : (texture_read_data == 2'b01) ? tile_palette[7:4]
                            : (texture_read_data == 2'b10) ? tile_palette[11:8]
                            : tile_palette[15:12];

  // finally, the 6-bit (RRGGBB) colour to display, found by looking up the colour index
  // above in the global palette.
  wire[5:0] texture_colour = palette[texture_colour_index];

  // sub palette (4-colour palette) to use for the sprite
  // combined_sprite_pixel_palette is a combination of the sprite sub_palette index (bits 5:2), and the pixel data (bits 1:0)
  wire[15:0] actual_sprite_sub_palette = sub_palette[combined_sprite_pixel_palette[5:2]];

  // index into the global 16-colour palette for the sprite
  wire[3:0] sprite_colour_idx = (combined_sprite_pixel_palette[1:0] == 2'b00) ? actual_sprite_sub_palette[3:0]
                          : (combined_sprite_pixel_palette[1:0] == 2'b01) ? actual_sprite_sub_palette[7:4]
                          : (combined_sprite_pixel_palette[1:0] == 2'b10) ? actual_sprite_sub_palette[11:8]
                          : actual_sprite_sub_palette[15:12];

  // sprite pixel is visible if it's pixel is colour 01, 10, or 11.
  // bit-pattern 00 is always the "transparent" colour for sprites.
  // "or" reduction operator is used to determine if any bits are set in the sprite pixel.
  wire sprite_pixel_visible = |(combined_sprite_pixel_palette[1:0]);

  // look the sprite colour up in the global 16-colour palette (this returns an 8-bit RRRGGGBB colour).
  wire[5:0] sprite_colour = palette[sprite_colour_idx];

  // multiplex bullets, sprites and textures into the RGB output value.
  assign vga_rgb = (!video_active) ? 6'b00_00_00
                      : bullet_active ? 6'b11_11_11
                      : sprite_pixel_visible ? sprite_colour
                      : texture_colour;

  // sprites contain 32-bits per line (16 pixels @ 2bpp).
  // each location in sprite memory contains an entire line of sprite data.
  // The sprite data for all eight sprites on a particular scan-line is
  // read sequentially during horizontal refresh.
  wire [31:0] sprite_read_data;
  reg [8:0] sprite_read_address;
  sprite_memory spritemem(
    .clk(clk), .raddr(sprite_read_address), .rdata(sprite_read_data),
    .wen(spritemem_select ? iomem_wstrb[3:0] : 4'b0), .waddr(iomem_addr[10:2]), .wdata(iomem_wdata[31:0])
  );

  // 32-bit shift registers for 8 sprites. Each 32-bit register contains all of the sprite's pixels for the current scanline.
  reg [31:0] sprite_line_buffer[0:7];

  // the sprite data read is handled by a state machine, which executes during hsync.
  // this register contains the current state.
  reg [5:0] hsync_read_state;

  // the current sprite that we're reading
  wire [2:0] current_hsync_sprite = hsync_read_state[4:2];

  // config register for this sprite
  wire [31:0] current_hsync_sprite_register=config_register_bank[current_hsync_sprite][31:0];

  // a little confusing perhaps, but these calculations determine the y index
  // into the current sprite, based on the current raster position and whether
  // or not we're doing a Y-flip on the sprite.
  wire [3:0] yp = { half_ypos[3:0] - current_hsync_sprite_register[3:0] };
  wire [3:0] invyp = ((~yp) + 4'd1);
  wire [3:0] yindex = current_hsync_sprite_register[29] ? invyp : yp;

  reg sprite_y_visible;

  // the state machine below reads a single line of data for each of the 8 sprites
  // from RAM into shift registers which are used to raster the sprite out
  // as the line is drawn.  This happens during the HSYNC period.
  always @(posedge clk) begin

    // if we're no longer in hsync, reset the state machine to state 0,
    // and do nothing else.
    if (!vga_hsync) begin
      hsync_read_state <= 5'b0;
    end else begin
      if (hsync_read_state[5]) begin  // if bit 5 is set, we've read all 8 sprites already.
      end else begin
        (* full_case, parallel_case *)
        case (hsync_read_state[1:0])
          2'b00:
            begin
              sprite_y_visible <=
                 (current_hsync_sprite_register[28]
                 && (lcd_y > $signed(current_hsync_sprite_register[8:0]))
                 && (lcd_y <= ($signed(current_hsync_sprite_register[8:0])+9'd16)));
              sprite_read_address <= { current_hsync_sprite_register[23:19], yindex };
            end
          2'b01:
            begin
                // sprite read address latched; wait another cycle for data to be available
            end
          2'b10: // 32-bits of sprite line data is available on RAM output; take it and load it into the sprite shift register
            begin
              if (sprite_y_visible) begin
                // if the sprite is x-flipped, then bit-twiddle (x-flip) the data before loading it in the shift register
                if (current_hsync_sprite_register[30]) begin
                  sprite_line_buffer[current_hsync_sprite] <= {
                    sprite_read_data[1:0],
                    sprite_read_data[3:2],
                    sprite_read_data[5:4],
                    sprite_read_data[7:6],
                    sprite_read_data[9:8],
                    sprite_read_data[11:10],
                    sprite_read_data[13:12],
                    sprite_read_data[15:14],
                    sprite_read_data[17:16],
                    sprite_read_data[19:18],
                    sprite_read_data[21:20],
                    sprite_read_data[23:22],
                    sprite_read_data[25:24],
                    sprite_read_data[27:26],
                    sprite_read_data[29:28],
                    sprite_read_data[31:30]
                  };
                end else begin   // no x-flip required
                  sprite_line_buffer[current_hsync_sprite] <= sprite_read_data;
                end
              end else begin
                sprite_line_buffer[current_hsync_sprite] <= 32'h0;
              end
            end
          2'b11:
            begin
              // null state
            end
        endcase
        hsync_read_state <= hsync_read_state + !hsync_read_state[5];
      end
    end
  end

  // the above always block has loaded data for each sprite into their respective shift registers.
  // The below block takes those pixels and merges them into two variables: "sprite_pixel[1:0]" and "sprite_palette[3:0]" based
  // on where in the current line the raster is.
  reg[1:0] sprite_pixel[0:7];

  // dirty way of determining when the pixel clock has been advanced.
  reg prev_xpos;

  wire newx = (half_xpos[0] != prev_xpos);
  always @(posedge clk) begin
    prev_xpos <= half_xpos[0];
  end

  always @(posedge clk) begin
    if (newx) begin
      // if screen xpos has exceeded sprite xpos, start shifting the pixels out
      if (lcd_x > ($signed(config_register_bank[0][18:9]))) begin
        sprite_pixel[0][1:0] <= sprite_line_buffer[0][31:30];
        sprite_line_buffer[0][31:0] <= { sprite_line_buffer[0][29:0], 2'b0 };
      end else begin
        sprite_pixel[0][1:0] <= 2'b0;
      end
      if (lcd_x > ($signed(config_register_bank[1][18:9]))) begin
        sprite_pixel[1][1:0] <= sprite_line_buffer[1][31:30];
        sprite_line_buffer[1][31:0] <= { sprite_line_buffer[1][29:0], 2'b0 };
      end else begin
        sprite_pixel[1][1:0] <= 2'b0;
      end
      if (lcd_x > ($signed(config_register_bank[2][18:9]))) begin
        sprite_pixel[2][1:0] <= sprite_line_buffer[2][31:30];
        sprite_line_buffer[2][31:0] <= { sprite_line_buffer[2][29:0], 2'b0 };
      end else begin
        sprite_pixel[2][1:0] <= 2'b0;
      end
      if (lcd_x > ($signed(config_register_bank[3][18:9]))) begin
        sprite_pixel[3][1:0] <= sprite_line_buffer[3][31:30];
        sprite_line_buffer[3][31:0] <= { sprite_line_buffer[3][29:0], 2'b0 };
      end else begin
        sprite_pixel[3][1:0] <= 2'b0;
      end
      if (lcd_x > ($signed(config_register_bank[4][18:9]))) begin
        sprite_pixel[4][1:0] <= sprite_line_buffer[4][31:30];
        sprite_line_buffer[4][31:0] <= { sprite_line_buffer[4][29:0], 2'b0 };
      end else begin
        sprite_pixel[4][1:0] <= 2'b0;
      end
      if (lcd_x > ($signed(config_register_bank[5][18:9]))) begin
        sprite_pixel[5][1:0] <= sprite_line_buffer[5][31:30];
        sprite_line_buffer[5][31:0] <= { sprite_line_buffer[5][29:0], 2'b0 };
      end else begin
        sprite_pixel[5][1:0] <= 2'b0;
      end
      if (lcd_x > ($signed(config_register_bank[6][18:9]))) begin
        sprite_pixel[6][1:0] <= sprite_line_buffer[6][31:30];
        sprite_line_buffer[6][31:0] <= { sprite_line_buffer[6][29:0], 2'b0 };
      end else begin
        sprite_pixel[6][1:0] <= 2'b0;
      end
      if (lcd_x > ($signed(config_register_bank[7][18:9]))) begin
        sprite_pixel[7][1:0] <= sprite_line_buffer[7][31:30];
        sprite_line_buffer[7][31:0] <= { sprite_line_buffer[7][29:0], 2'b0 };
      end else begin
        sprite_pixel[7][1:0] <= 2'b0;
      end
    end
  end

  // priority multiplex sprite pixel data
  wire[1:0] sprite_bits =
    |(sprite_pixel[0]) ? sprite_pixel[0]
    : |(sprite_pixel[1]) ? sprite_pixel[1]
    : |(sprite_pixel[2]) ? sprite_pixel[2]
    : |(sprite_pixel[3]) ? sprite_pixel[3]
    : |(sprite_pixel[4]) ? sprite_pixel[4]
    : |(sprite_pixel[5]) ? sprite_pixel[5]
    : |(sprite_pixel[6]) ? sprite_pixel[6]
    : |(sprite_pixel[7]) ? sprite_pixel[7]
    : 2'b0;

  // priority multiplex sprite palette selector
  wire[3:0] palette_select_bits =
    |(sprite_pixel[0]) ? config_register_bank[0][27:24]
    : |(sprite_pixel[1]) ? config_register_bank[1][27:24]
    : |(sprite_pixel[2]) ? config_register_bank[2][27:24]
    : |(sprite_pixel[3]) ? config_register_bank[3][27:24]
    : |(sprite_pixel[4]) ? config_register_bank[4][27:24]
    : |(sprite_pixel[5]) ? config_register_bank[5][27:24]
    : |(sprite_pixel[6]) ? config_register_bank[6][27:24]
    : |(sprite_pixel[7]) ? config_register_bank[7][27:24]
    : 4'b0;

    wire[5:0] combined_sprite_pixel_palette =  { palette_select_bits, sprite_bits };


	always @(posedge clk) begin
		if (iomem_valid) begin
      if (config_reg_select) begin
        if (iomem_wstrb[0]) config_register_bank[bank_addr][ 7: 0] <= iomem_wdata[ 7: 0];
  			if (iomem_wstrb[1]) config_register_bank[bank_addr][15: 8] <= iomem_wdata[15: 8];
  			if (iomem_wstrb[2]) config_register_bank[bank_addr][23:16] <= iomem_wdata[23:16];
  			if (iomem_wstrb[3]) config_register_bank[bank_addr][31:24] <= iomem_wdata[31:24];
      end else if (palette_select) begin
        if (iomem_wstrb[0]) palette[bank_addr] <= iomem_wdata[ 7: 0];
      end else if (sub_palette_select) begin
        if (iomem_wstrb[0]) sub_palette[bank_addr][7:0] <= iomem_wdata[ 7: 0];
        if (iomem_wstrb[1]) sub_palette[bank_addr][15:8] <= iomem_wdata[15: 8];
      end
		end
    if (!resetn) begin
      config_register_bank[10] <= 255;  // irq line ;; 255 is a safe value as it'll never normally be hit
    end
	end

   reg        pix_clk = 0;
   reg        reset_cursor = 0;
   wire       busy;
   wire [5:0] vga_rgb;
   wire vga_hsync, vga_vsync; // active high
   reg signed [9:0] lcd_x;
   reg signed [8:0] lcd_y;
   wire [8:0] half_xpos;
   wire [8:0] half_ypos;

   wire [15:0] current_half_xy = { half_xpos[8:1], half_ypos[8:1] };
   wire bullet_active =  (current_half_xy == config_register_bank[11][15:0])
                       || (current_half_xy == config_register_bank[12][15:0]);


   localparam hsync_pixels = 40;
   localparam maxx = 319;
   localparam maxy = 239;
   localparam vsync_lines = 2;

   wire [1:0] blue = vga_rgb[1:0];
   wire [1:0] red = vga_rgb[5:4];
   wire [1:0] green = vga_rgb[3:2];


   // -------------------------------------------------------------------

   /* IRQ GENERATION logic */

   /* a vertical line which, when reached by the raster, will trigger an interrupt */
   wire signed [8:0] y_irq_line = config_register_bank[10][8:0];

   reg yprev;
   always @(posedge clk) begin
    yprev <= lcd_y[0];
    irq <= 0;
    if (yprev != lcd_y[0] && (lcd_y == y_irq_line)) irq <= 1;
   end

   // -------------------------------------------------------------------


   ili9341 lcd (
      .resetn(resetn),
      .clk_16MHz (clk),
      .nreset (nreset),
      .cmd_data (cmd_data),
      //.ncs (ncs),
      .write_edge (write_edge),
      .dout (dout),
      .reset_cursor (reset_cursor),
      // ordering is G2G1G0B4B3B2B1B0  ... R4R3R2R1R0G5G4G3
      .pix_data ({ red, red, red[1], green, green, green, blue, blue, blue[1] }),
      // .pix_data ({ /* blue */ vga_rgb[1:0], vga_rgb[1:0], vga_rgb[1],  // B1B0B1B0B1
      //               /* green */ vga_rgb[4:2],vga_rgb[4:2],   // G2G1G0G2G1G0
      //               /* red */ vga_rgb[7:5], vga_rgb[7:6]}),  // R2R1R0R2R1
      .pix_clk (pix_clk),
      .busy (busy)
    );

   assign vga_hsync = lcd_x[9];
   assign vga_vsync = lcd_y[8];
   assign half_xpos = vga_hsync ? 0 : lcd_x[8:0];
   assign half_ypos = lcd_y;
   assign video_active = !vga_hsync && !vga_vsync;


   always @(posedge clk) begin
      reset_cursor <= 0;
      pix_clk <= 0;

      if (!busy && !pix_clk) begin
        lcd_x <= lcd_x + 1;

        if (lcd_x >= maxx) begin
          lcd_x <= -hsync_pixels;
          lcd_y <= lcd_y + 1;
          if (lcd_y >= maxy) begin
            lcd_y <= -vsync_lines;
            reset_cursor <= 1;
          end
        end
        if (video_active) pix_clk <= 1;
      end

   end

endmodule
