/*
 * Video peripheral for TinyFPGA game SoC
 *
 * 320x240 tile map based graphics adaptor
 */
`default_nettype none
module video_vga
(
  input resetn,
  input clk,
	input iomem_valid,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
`ifdef ili9341
  output reg       nreset,
  output reg       cmd_data, // 1 => Data, 0 => Command
  //output           ncs, // Chip select (low enable)
  output reg       write_edge, // Write signal on rising edge
  output           read_edge, // Read signal on rising edge
  output reg [7:0] dout);
`else
  output vga_hsync,
  output vga_vsync,
  output [7:0] vga_rgb);
`endif

`ifndef ili9341
  reg[9:0] xpos;
  reg[9:0] ypos;

  wire[8:0] half_xpos = xpos[8:0];  // no longer being halved since we're using a slower (16MHz) pixel clock
  wire[8:0] half_ypos = ypos[9:1];
`endif

  wire[8:0] next_xpos = half_xpos+1;
  wire video_active;


  localparam NUM_SPRITES = 8;

  // video registers
  // 0,1,2,3,4,5,6,7 => sprite control
  // 8,9 => x,y offset into tile map
	reg [31:0] config_register_bank [0:2+NUM_SPRITES-1];  /* x/y pos + sprite config */
  reg [7:0] palette [0:15];
  reg [15:0] sub_palette[0:15];  // 4-colours per sub-palette entry; each colour index 0-15

  wire [3:0] bank_addr = iomem_addr[5:2];

  wire config_reg_select = (iomem_valid && (iomem_addr[23:20]==4'h0));
  wire texmem_write = (iomem_valid && (iomem_wstrb[0] && iomem_addr[23:20]==4'h1));
  wire colourmem_write = (iomem_valid && (iomem_wstrb[1] && iomem_addr[23:20]==4'h2));
  wire spritemem_select = (iomem_valid && (iomem_addr[23:20]==4'h3));
  wire palette_select = (iomem_valid && (iomem_addr[23:20]==4'h4));
  wire sub_palette_select = (iomem_valid && (iomem_addr[23:20]==4'h5));
  wire window_write = (iomem_valid && (iomem_wstrb[1] && iomem_addr[23:20]==4'h6));

  wire [11:0] window_tile_and_colourmem_data;
  wire [11:0] tile_and_colourmem_data;
  wire [1:0] texture_read_data;

  reg [8:0] xofs;
  reg [7:0] yofs;

  always @(posedge clk) begin
    if (!vga_vsync) begin
      xofs <= config_register_bank[8][8:0];   // 9 bits
      yofs <= config_register_bank[8][23:16]; // 8 bits
    end
  end

  wire window_enable = config_register_bank[9][31];
  wire [4:0] window_line_start = config_register_bank[9][4:0];  // 0 .. 30
  wire [4:0] window_line_end = config_register_bank[9][12:8];   // 0 .. 30

  wire [8:0] effective_y = half_ypos+yofs;
  wire [8:0] effective_x = half_xpos+xofs;
  wire [8:0] effective_next_x = next_xpos+xofs;

  // the below is for an 64x32 tile map
  //  [ y y y y y y x x x x x x ]
  // - eg. y*64+x
  wire [11:0] tile_read_address = { effective_y[8:3], effective_next_x[8:3] };

  // window_y_pos = current y index into the window (0-3);
  wire [1:0] window_y_pos = half_ypos[4:3] - window_line_start[1:0];
  wire [7:0] window_read_address = { window_y_pos, half_xpos[8:3] };

  // 64x32 tile (& tile colour) memory
  // memory is arranged in a 64x32 grid of 12-bit values
  // top 4-bits is colour (actually, index into sub-palette), bottom 8-bits is texture number
  tile_and_colour_memory tile_and_colourmem(
    .clk(clk),
    .ren(1'b1),
    .raddr(tile_read_address),
    .rdata(tile_and_colourmem_data),
    .wen(colourmem_write),
    .waddr(iomem_addr[13:2]),
    .wdata(iomem_wdata[11:0])
  );

  window_memory window_mem(
    .clk(clk),
    .raddr(window_read_address),
    .rdata(window_tile_and_colourmem_data),
    .wen(window_write),
    .waddr(iomem_addr[9:2]),
    .wdata(iomem_wdata[11:0])
  );

  wire [13:0] texture_read_address = in_window ? { tile_or_window_data[7:0], half_ypos[2:0], half_xpos[2:0] }
                                          : { tile_or_window_data[7:0], effective_y[2:0], effective_x[2:0] };
  texture_memory texturemem(
    .clk(clk),
    .raddr(texture_read_address), .rdata(texture_read_data),
    .wen(texmem_write), .waddr(iomem_addr[15:2]), .wdata(iomem_wdata[1:0])
  );

  wire in_window = window_enable && ((half_ypos[7:3] >= window_line_start) && (half_ypos[7:3] <= window_line_end));
  wire [11:0] tile_or_window_data = in_window ? window_tile_and_colourmem_data : tile_and_colourmem_data;

  wire [15:0] tile_palette = sub_palette[tile_or_window_data[11:8]];
  wire [7:0] texture_colour_index = (texture_read_data == 2'b00) ? tile_palette[3:0]
                            : (texture_read_data == 2'b01) ? tile_palette[7:4]
                            : (texture_read_data == 2'b10) ? tile_palette[11:8]
                            : tile_palette[15:12];
  wire[7:0] texture_colour = palette[texture_colour_index];

  // sub palette (4-colour palette) to use for the sprite
  // combined_sprite_pixel_palette is a combination of the sprite sub_palette index (bits 5:2), and the pixel data (bits 1:0)
  wire[15:0] actual_sprite_sub_palette = sub_palette[combined_sprite_pixel_palette[5:2]];

  // index into the global 16-colour palette for the sprite
  wire[3:0] sprite_colour_idx = (combined_sprite_pixel_palette[1:0] == 2'b00) ? actual_sprite_sub_palette[3:0]
                          : (combined_sprite_pixel_palette[1:0] == 2'b01) ? actual_sprite_sub_palette[7:4]
                          : (combined_sprite_pixel_palette[1:0] == 2'b10) ? actual_sprite_sub_palette[11:8]
                          : actual_sprite_sub_palette[15:12];

  // sprite pixel is visible if it's pixel is colour 01, 10, or 11.
  wire sprite_pixel_visible = |(combined_sprite_pixel_palette[1:0]);

  // look the sprite colour up in the global 16-colour palette (this returns an 8-bit RRRGGGBB colour).
  wire[7:0] sprite_colour = palette[sprite_colour_idx];

  assign vga_rgb = (!video_active) ? 8'b0
                      : sprite_pixel_visible ? sprite_colour
                      : texture_colour;

  wire [31:0] sprite_read_data;
  reg [8:0] sprite_read_address;
  sprite_memory spritemem(
    .clk(clk), .raddr(sprite_read_address), .rdata(sprite_read_data),
    .wen(spritemem_select ? iomem_wstrb[3:0] : 4'b0), .waddr(iomem_addr[10:2]), .wdata(iomem_wdata[31:0])
  );

  reg [31:0] sprite_line_buffer[0:7];
  reg [5:0] hsync_read_state;
  wire [2:0] current_hsync_sprite = hsync_read_state[4:2];
  wire [31:0] current_hsync_sprite_register=config_register_bank[current_hsync_sprite][31:0];
  wire [4:0] skipped_x_pixels = current_hsync_sprite_register[17:9] < 9'd16 ? { 1'b0, (~(current_hsync_sprite_register[12:9])) } + 5'd1  : 5'b0;
  //wire [31:0] current_hsync_sprite_register=config_register_bank[0][31:0];
  wire [3:0] yp = { half_ypos[3:0] - current_hsync_sprite_register[3:0] };
  wire [3:0] invyp = ((~yp) + 4'd1);
  wire [3:0] yindex = current_hsync_sprite_register[29] ? invyp : yp;

  reg sprite_y_visible;

  always @(posedge clk) begin
    // if we're in hsync, and on a currently active video line, then read sprite data for each sprite
    // and store it in the sprite_line_buffer[] and sprite_y_visible[] registers, ready to be rastered out

    if (vga_hsync) begin
      hsync_read_state <= 5'b0;
    end else begin
      if (hsync_read_state[5]) begin
      end else begin

        case (hsync_read_state[1:0])
          2'b00:
            begin
              sprite_y_visible <=
                 (current_hsync_sprite_register[28]
                 && (half_ypos > current_hsync_sprite_register[8:0])
                 && (half_ypos <= (current_hsync_sprite_register[8:0]+9'd16)));
              sprite_read_address <= { current_hsync_sprite_register[22:18], yindex };
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
              // pre-shift sprite pixels out of shift register if sprite position is < 16
              if (current_hsync_sprite_register[17:9]<16) begin
                sprite_line_buffer[current_hsync_sprite] <= (sprite_line_buffer[current_hsync_sprite] << { skipped_x_pixels, 1'b0 });
              end
            end
        endcase
        hsync_read_state <= hsync_read_state + !hsync_read_state[5];
      end
    end
  end



  // the above always block has figured out which sprites are visible on a given line, and provided us with a buffer of their X pixels.
  // The below block takes those pixels and merges them into two variables: "sprite_pixel[1:0]" and "sprite_palette[3:0]" based
  // on where in the current line the raster is.
  reg[1:0] sprite_pixel[0:7];
  reg[3:0] sprite_sub_palette_idx[0:7];

  wire[8:0] half_xpos_plus_16 = half_xpos+16;

  generate
    genvar i;

    for (i = 0; i < NUM_SPRITES; i = i + 1) begin : spritelines
      always @(posedge clk) begin
        sprite_sub_palette_idx[i][3:0] <= config_register_bank[i][27:24];

        // if screen xpos has exceeded sprite xpos, start shifting the pixels out
        if (video_active && config_register_bank[i][28] && (half_xpos_plus_16 > (config_register_bank[i][17:9]))) begin

          // if the flipx bit is clear, shift pixels out MSB first;
          // otherwise shift them out LSB first
          sprite_pixel[i][1:0] <= sprite_line_buffer[i][31:30];
          sprite_line_buffer[i][31:0] <= { sprite_line_buffer[i][29:0], 2'b0 };
        end else begin
          sprite_pixel[i][1:0] <= 2'b0;
        end
      end
    end
  endgenerate

  // the below line merges the sprite's pixels and palettes into a single value (based on sprite priority order) for display
  wire[5:0] combined_sprite_pixel_palette =  |(sprite_pixel[0][1:0]) ? {sprite_sub_palette_idx[0][3:0], sprite_pixel[0][1:0]}
                                    : |(sprite_pixel[1][1:0]) ? {sprite_sub_palette_idx[1][3:0], sprite_pixel[1][1:0]}
                                    : |(sprite_pixel[2][1:0]) ? {sprite_sub_palette_idx[2][3:0], sprite_pixel[2][1:0]}
                                    : |(sprite_pixel[3][1:0]) ? {sprite_sub_palette_idx[3][3:0], sprite_pixel[3][1:0]}
                                    : |(sprite_pixel[4][1:0]) ? {sprite_sub_palette_idx[4][3:0], sprite_pixel[4][1:0]}
                                    : |(sprite_pixel[5][1:0]) ? {sprite_sub_palette_idx[5][3:0], sprite_pixel[5][1:0]}
                                    : |(sprite_pixel[6][1:0]) ? {sprite_sub_palette_idx[6][3:0], sprite_pixel[6][1:0]}
                                    : |(sprite_pixel[7][1:0]) ? {sprite_sub_palette_idx[7][3:0], sprite_pixel[7][1:0]}
                                    : { 4'b0, 2'b0 };

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
        // if (iomem_wstrb[2]) sub_palette[bank_addr][23:16] <= iomem_wdata[23:16];
        // if (iomem_wstrb[3]) sub_palette[bank_addr][31:24] <= iomem_wdata[31:24];
      end
		end
	end

`ifdef ili9341
   reg        pix_clk = 0;
   reg        reset_cursor = 0;
   wire       busy;
   wire [7:0] vga_rgb;
   wire vga_hsync, vga_vsync;
   reg [8:0] lcd_x;
   reg [8:0] lcd_y;
   wire [8:0] half_xpos;
   wire [8:0] half_ypos;

   localparam hsync_pixels = 40;
   localparam maxx = 319;
   localparam maxy = 239;
   localparam vsync_lines = 2;

   wire [1:0] blue = vga_rgb[1:0];
   wire [2:0] red = vga_rgb[7:5];
   wire [2:0] green = vga_rgb[4:2];

   ili9341 lcd (
      .resetn(resetn),
      .clk_16MHz (clk),
      .nreset (nreset),
      .cmd_data (cmd_data),
      //.ncs (ncs),
      .write_edge (write_edge),
      .read_edge (read_edge),
      .dout (dout),
      .reset_cursor (reset_cursor),
      // ordering is G2G1G0B4B3B2B1B0  ... R4R3R2R1R0G5G4G3
      .pix_data ({ red, red[2:1], green, green, blue, blue, blue[1] }),
      // .pix_data ({ /* blue */ vga_rgb[1:0], vga_rgb[1:0], vga_rgb[1],  // B1B0B1B0B1
      //               /* green */ vga_rgb[4:2],vga_rgb[4:2],   // G2G1G0G2G1G0
      //               /* red */ vga_rgb[7:5], vga_rgb[7:6]}),  // R2R1R0R2R1
      .pix_clk (pix_clk),
      .busy (busy)
    );

   assign vga_hsync = !(lcd_x < hsync_pixels);
   assign vga_vsync = !(lcd_y < vsync_lines);
   assign half_xpos = lcd_x - hsync_pixels;
   assign half_ypos = lcd_y - vsync_lines;
   assign video_active = (lcd_x >= hsync_pixels) && (lcd_y >= vsync_lines);


   always @(posedge clk) begin
      reset_cursor <= 0;
      pix_clk <= 0;

      if (!busy && !pix_clk) begin
        lcd_x <= lcd_x + 1;

        if (lcd_x >= (maxx+hsync_pixels)) begin
          lcd_x <= 0;
          lcd_y <= lcd_y + 1;
          if (lcd_y >= (maxy+vsync_lines)) begin
            lcd_y <= 0;
            reset_cursor <= 1;
          end
        end
        if (video_active) pix_clk <= 1;
      end

   end
`else
  VGASyncGen vga_generator(
    .clk(clk),
    .hsync(vga_hsync),
    .vsync(vga_vsync),
    .x_px(xpos),
    .y_px(ypos),
    .activevideo(video_active)
  );
`endif

endmodule
