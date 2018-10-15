/*
 * Video peripheral for TinyFPGA game SoC
 *
 * 320x240 tile map based graphics adaptor
 */

module video_vga
(
  input resetn,
  input clk,
	input iomem_valid,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
  output vga_hsync,
  output vga_vsync,
  output [7:0] vga_rgb);

  reg[9:0] xpos;
  reg[9:0] ypos;

  wire[8:0] half_xpos = xpos[8:0];  // no longer being halved since we're using a slower (16MHz) pixel clock
  wire[8:0] half_ypos = ypos[9:1];

  wire[8:0] next_xpos = half_xpos+1;
  wire video_active;

  // video registers
  // 0: x scroll offset
  // 1: y scroll offset
  // 2,3,4,5: sprite registers for sprites 1-4

  localparam NUM_SPRITES = 8;

	reg [31:0] config_register_bank [0:2+NUM_SPRITES-1];  /* x/y pos + sprite config */
  reg [7:0] palette [0:15];
  reg [15:0] sub_palette[0:15];  // 4-colours per sub-palette entry; each colour index 0-15

  wire [3:0] bank_addr = iomem_addr[5:2];

  // todo sprites
  // sprite_memory spritemem();

  wire reg_write = (iomem_addr[23:20]==4'h0);
  wire texmem_write = (iomem_valid && iomem_wstrb[0] && iomem_addr[23:20]==4'h1);
  wire tilemem_write = (iomem_valid && iomem_wstrb[0] && iomem_addr[23:20]==4'h2);
  wire colourmem_write = (iomem_valid && iomem_wstrb[1] && iomem_addr[23:20]==4'h2);
  wire spritemem_write = (iomem_valid && iomem_wstrb[0] && iomem_addr[23:20]==4'h3);
  wire palette_write = (iomem_valid && iomem_addr[23:20]==4'h4);
  wire sub_palette_write = (iomem_valid && iomem_addr[23:20]==4'h5);

  wire [7:0] tile_read_data;
  wire [3:0] tile_palette_select_read_data;
  wire [1:0] texture_read_data;

  wire [8:0] xofs = config_register_bank[0][8:0];
  wire [7:0] yofs = config_register_bank[1][7:0];

  wire [8:0] effective_y = half_ypos+yofs;
  wire [8:0] effective_x = half_xpos+xofs;
  wire [8:0] effective_next_x = next_xpos+xofs;

  // The below is for a 40x25 tile map
  //  --- need to read ahead with tile memory to prevent edge-artifacts
  //  --- y/8, x/8 (8 pixels per tile)
  // wire [5:0] y_over_eight = effective_y[8:3];  // y / 8 ()
  //  --- (y/8)*40 + x      ((y/8)*32) + ((y/8)*8) + x
  // wire [11:0] tile_read_address = (y_over_eight << 5) + (y_over_eight << 3) + effective_next_x[8:3];

  // the below is for an 64x32 tile map
  //  [ y y y y y y x x x x x x ]
  // - eg. y*64+x
  wire [11:0] tile_read_address = { effective_y[8:3], effective_next_x[8:3] };

  tile_memory tilemem(
    .clk(clk),
    .ren(video_active), .raddr(tile_read_address), .rdata(tile_read_data),
    .wen(tilemem_write), .waddr(iomem_addr[13:2]), .wdata(iomem_wdata[7:0])
  );

  tile_colour_memory tilecolourmem(
    .clk(clk),
    .ren(video_active),
    .raddr(tile_read_address),
    .rdata(tile_palette_select_read_data),
    .wen(colourmem_write),
    .waddr(iomem_addr[13:2]),
    .wdata(iomem_wdata[11:8])
  );

  wire [13:0] texture_read_address = { tile_read_data[7:0], effective_y[2:0], effective_x[2:0] };
  texture_memory texturemem(
    .clk(clk),
    .ren(video_active), .raddr(texture_read_address), .rdata(texture_read_data),
    .wen(texmem_write), .waddr(iomem_addr[15:2]), .wdata(iomem_wdata[1:0])
  );

  wire [15:0] tile_palette = sub_palette[tile_palette_select_read_data];
  wire [7:0] texture_colour_index = (texture_read_data == 2'b00) ? tile_palette[3:0]
                            : (texture_read_data == 2'b01) ? tile_palette[7:4]
                            : (texture_read_data == 2'b10) ? tile_palette[11:8]
                            : tile_palette[15:12];
  wire[7:0] texture_colour = palette[texture_colour_index];

  wire[NUM_SPRITES-1:0] inbb;
  wire[12:0] sprite_mem_addr[0:NUM_SPRITES-1];

  generate
    genvar i;
    for (i=0; i<NUM_SPRITES; i=i+1)
    begin : sprites
      sprite sprite (
        .screen_xpos(next_xpos), .screen_ypos(half_ypos),
        .configuration(config_register_bank[i+2][31:0]),
        .in_sprite_bounding_box(inbb[i]),
        .sprite_mem_addr(sprite_mem_addr[i])
      );
    end
  endgenerate

  wire [12:0] sprite_read_address = inbb[0]?sprite_mem_addr[0][12:0]:
                                  inbb[1]?sprite_mem_addr[1][12:0]:
                                  inbb[2]?sprite_mem_addr[2][12:0]:
                                  inbb[3]?sprite_mem_addr[3][12:0]:
                                  inbb[4]?sprite_mem_addr[4][12:0]:
                                  inbb[5]?sprite_mem_addr[5][12:0]:
                                  inbb[6]?sprite_mem_addr[6][12:0]:
                                  inbb[7]?sprite_mem_addr[7][12:0]:
                                  14'h0;

  // RRRGGGBB colour value for sprite
  wire[15:0] sprite_sub_palette = (
                    inbb[0]?sub_palette[config_register_bank[2][27:24]]   // palette needs another layer of indirection;
                    :inbb[1]?sub_palette[config_register_bank[3][27:24]]
                    :inbb[2]?sub_palette[config_register_bank[4][27:24]]
                    :inbb[3]?sub_palette[config_register_bank[5][27:24]]
                    :inbb[4]?sub_palette[config_register_bank[6][27:24]]
                    :inbb[5]?sub_palette[config_register_bank[7][27:24]]
                    :inbb[6]?sub_palette[config_register_bank[8][27:24]]
                    :inbb[7]?sub_palette[config_register_bank[9][27:24]]
                    :7'b0
                  );


  wire [1:0] sprite_read_data;

  sprite_memory spritemem(
    .clk(clk),
    .ren(video_active), .raddr(sprite_read_address), .rdata(sprite_read_data),
    .wen(spritemem_write), .waddr(iomem_addr[14:2]), .wdata(iomem_wdata[1:0])
  );

  wire[3:0] sprite_colour_idx = (sprite_read_data == 2'b00) ? sprite_sub_palette[3:0]
                          : (sprite_read_data == 2'b01) ? sprite_sub_palette[7:4]
                          : (sprite_read_data == 2'b10) ? sprite_sub_palette[11:8]
                          : sprite_sub_palette[15:12];

  wire sprite_pixel_visible = !(sprite_colour_idx == 2'b00);

  wire[7:0] sprite_colour = palette[sprite_colour_idx];

  assign vga_rgb = (!video_active) ? 8'b0
                      : sprite_pixel_visible ? sprite_colour
                      : texture_colour;

	always @(posedge clk) begin
		if (iomem_valid) begin
      if (reg_write) begin
        if (iomem_wstrb[0]) config_register_bank[bank_addr][ 7: 0] <= iomem_wdata[ 7: 0];
  			if (iomem_wstrb[1]) config_register_bank[bank_addr][15: 8] <= iomem_wdata[15: 8];
  			if (iomem_wstrb[2]) config_register_bank[bank_addr][23:16] <= iomem_wdata[23:16];
  			if (iomem_wstrb[3]) config_register_bank[bank_addr][31:24] <= iomem_wdata[31:24];
      end else if (palette_write) begin
        if (iomem_wstrb[0]) palette[bank_addr] <= iomem_wdata[ 7: 0];
      end else if (sub_palette_write) begin
        if (iomem_wstrb[0]) sub_palette[bank_addr][7:0] <= iomem_wdata[ 7: 0];
        if (iomem_wstrb[1]) sub_palette[bank_addr][15:8] <= iomem_wdata[15: 8];
        // if (iomem_wstrb[2]) sub_palette[bank_addr][23:16] <= iomem_wdata[23:16];
        // if (iomem_wstrb[3]) sub_palette[bank_addr][31:24] <= iomem_wdata[31:24];
      end
		end
    if (!resetn) begin
      config_register_bank[0]<=32'h0;  // xpos
      config_register_bank[1]<=32'h0;  // ypos
      config_register_bank[2]<=32'h0;  // sprite 0
      config_register_bank[4]<=32'h0;  // sprite 1
      config_register_bank[3]<=32'h0;  // sprite 2
      config_register_bank[5]<=32'h0;  // sprite 3
      config_register_bank[6]<=32'h0;  // sprite 4
      config_register_bank[7]<=32'h0;  // sprite 5
      config_register_bank[8]<=32'h0;  // sprite 6
      config_register_bank[9]<=32'h0;  // sprite 7

      // pacman 8-bit RGB colour palette
      // {0,0,0},{255,0,0},{222,151,81},{255,184,255},{0,0,0},{0,255,255},{71,184,255},{255,184,81},
      // {0,0,0},{255,255,0},{0,0,0},{33,33,255},{0,255,0},{71,184,174},{255,184,174},{222,222,255}
      // 2-bit colour map: 0->0, 1->85, 2->170, 3->255
      // 3-bit colour map: 0->7, 1->36, 2->72, 3->108, 4->146, 5->182, 6->218, 7->255
      palette[0]<={3'd0, 3'd0, 2'd0};
      palette[1]<={3'd7, 3'd0, 2'd0};
      palette[2]<={3'd6, 3'd4, 2'd1};
      palette[4]<={3'd7, 3'd5, 2'd3};
      palette[5]<={3'd0, 3'd0, 2'd0};
      palette[6]<={3'd0, 3'd7, 2'd3};
      palette[7]<={3'd2, 3'd5, 2'd3};

      palette[8]<={3'd0, 3'd0, 2'd0};
      palette[9]<={3'd7, 3'd7, 2'd0};
      palette[10]<={3'd0, 3'd0, 2'd0};
      palette[11]<={3'd1, 3'd1, 2'd3};
      palette[12]<={3'd0, 3'd7, 2'd0};
      palette[13]<={3'd2, 3'd5, 2'd2};
      palette[14]<={3'd7, 3'd5, 2'd2};
      palette[15]<={3'd6, 3'd6, 2'd3};
    end
	end

  VGASyncGen vga_generator(
    .clk(clk),
    .hsync(vga_hsync),
    .vsync(vga_vsync),
    .x_px(xpos),
    .y_px(ypos),
    .activevideo(video_active)
  );

endmodule
