/*
 * Video peripheral for TinyFPGA game SoC
 *
 * 320x240 tile map based graphics adaptor
 *  texture memory mapped to 0x0510_0000
 *  tile memory mapped to 0x0520_0000
 */

`ifndef __GAME_SOC_VIDEO__
`define __GAME_SOC_VIDEO__

`include "VGASyncGen.vh"
`include "sprite_memory.vh"
`include "texture_memory.vh"
`include "tile_memory.vh"
`include "sprite.v"

module video
(
  input resetn,
  input clk,
	input iomem_valid,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
  output vga_hsync,
  output vga_vsync,
  output vga_r,
  output vga_g,
  output vga_b);

  reg[9:0] xpos;
  reg[9:0] ypos;

  wire[8:0] half_xpos = xpos[8:0];  // no longer being halved
  wire[8:0] half_ypos = ypos[9:1];

  wire[8:0] next_xpos = half_xpos+1;
  wire video_active;

  // video registers
  // 0: x scroll offset
  // 1: y scroll offset
  // 2,3,4,5: sprite registers for sprites 1-4

  localparam NUM_SPRITES = 8;

	reg [31:0] config_register_bank [0:NUM_SPRITES+1];
  wire [3:0] bank_addr = iomem_addr[5:2];

  // todo sprites
  // sprite_memory spritemem();

  wire reg_write = (iomem_addr[23:20]==4'h0);
  wire texmem_write = (iomem_valid && iomem_wstrb[0] && iomem_addr[23:20]==4'h1);
  wire tilemem_write = (iomem_valid && iomem_wstrb[0] && iomem_addr[23:20]==4'h2);
  wire spritemem_write = (iomem_valid && iomem_wstrb[0] && iomem_addr[23:20]==4'h3);

  wire [5:0] tile_read_data;
  wire [2:0] texture_read_data;

  wire [9:0] xofs = config_register_bank[0][8:0];
  wire [9:0] yofs = config_register_bank[1][8:0];

  wire [9:0] effective_y = half_ypos+yofs;
  wire [9:0] effective_x = half_xpos+xofs;
  wire [9:0] effective_next_x = next_xpos+xofs;

  // need to read ahead with tile memory to prevent edge-artifacts
  wire [11:0] tile_read_address = { effective_y[8:3], effective_next_x[8:3] };
  tile_memory tilemem(
    .rclk(clk), .ren(video_active), .raddr(tile_read_address), .rdata(tile_read_data),
    .wclk(clk), .wen(tilemem_write), .waddr(iomem_addr[13:2]), .wdata(iomem_wdata[5:0])
  );

  wire [11:0] texture_read_address = { tile_read_data[5:0], effective_y[2:0], effective_x[2:0] };
  texture_memory texturemem(
    .rclk(clk), .ren(video_active), .raddr(texture_read_address), .rdata(texture_read_data),
    .wclk(clk), .wen(texmem_write), .waddr(iomem_addr[13:2]), .wdata(iomem_wdata[2:0])
  );


  wire[NUM_SPRITES-1:0] inbb;
  wire[13:0] sprite_mem_addr[0:NUM_SPRITES-1];

  generate
    genvar i;
    /* generate some voices and wire them to the per-MIDI-note gates */
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

  localparam CONFIG_R = 26;
  localparam CONFIG_G = 27;
  localparam CONFIG_B = 28;

  wire [13:0] sprite_read_address = inbb[0]?sprite_mem_addr[0][13:0]:
                                  inbb[1]?sprite_mem_addr[1][13:0]:
                                  inbb[2]?sprite_mem_addr[2][13:0]:
                                  inbb[3]?sprite_mem_addr[3][13:0]:
                                  inbb[4]?sprite_mem_addr[4][13:0]:
                                  inbb[5]?sprite_mem_addr[5][13:0]:
                                  inbb[6]?sprite_mem_addr[6][13:0]:
                                  inbb[7]?sprite_mem_addr[7][13:0]:
                                  14'h0;
  wire sprite_r = (
                    inbb[0]?config_register_bank[2][CONFIG_R]
                    :inbb[1]?config_register_bank[3][CONFIG_R]
                    :inbb[2]?config_register_bank[4][CONFIG_R]
                    :inbb[3]?config_register_bank[5][CONFIG_R]
                    :inbb[4]?config_register_bank[6][CONFIG_R]
                    :inbb[5]?config_register_bank[7][CONFIG_R]
                    :inbb[6]?config_register_bank[8][CONFIG_R]
                    :inbb[7]?config_register_bank[9][CONFIG_R]
                    :1'b0
                  );
  wire sprite_g = (
                    inbb[0]?config_register_bank[2][CONFIG_G]
                    :inbb[1]?config_register_bank[3][CONFIG_G]
                    :inbb[2]?config_register_bank[4][CONFIG_G]
                    :inbb[3]?config_register_bank[5][CONFIG_G]
                    :inbb[4]?config_register_bank[6][CONFIG_G]
                    :inbb[5]?config_register_bank[7][CONFIG_G]
                    :inbb[6]?config_register_bank[8][CONFIG_G]
                    :inbb[7]?config_register_bank[9][CONFIG_G]
                    :1'b0
                  );
  wire sprite_b = (
                    inbb[0]?config_register_bank[2][CONFIG_B]
                    :inbb[1]?config_register_bank[3][CONFIG_B]
                    :inbb[2]?config_register_bank[4][CONFIG_B]
                    :inbb[3]?config_register_bank[5][CONFIG_B]
                    :inbb[4]?config_register_bank[6][CONFIG_B]
                    :inbb[5]?config_register_bank[7][CONFIG_B]
                    :inbb[6]?config_register_bank[8][CONFIG_B]
                    :inbb[7]?config_register_bank[9][CONFIG_B]
                    :1'b0
                  );

  wire sprite_read_data;

  sprite_memory spritemem(
    .rclk(clk), .ren(video_active), .raddr(sprite_read_address), .rdata(sprite_read_data),
    .wclk(clk), .wen(spritemem_write), .waddr(iomem_addr[15:2]), .wdata(iomem_wdata[0])
  );

  // assign vga_r = video_active && ((sprite_read_data && sprite_r) || (~sprite_read_data && texture_read_data[0]));
  // assign vga_g = video_active && ((sprite_read_data && sprite_g) || (~sprite_read_data && texture_read_data[1]));
  // assign vga_b = video_active && ((sprite_read_data && sprite_b) || (~sprite_read_data && texture_read_data[2]));

  //assign vga_r = video_active && (inbb[0] || (!sprite_read_data && texture_read_data[0]));
  //assign vga_g = video_active && (inbb[1] || (!sprite_read_data && texture_read_data[1]));
  //assign vga_b = video_active && (inbb[2] || (!sprite_read_data && texture_read_data[2]));

  assign vga_r = video_active && ((sprite_read_data && sprite_r) || (!sprite_read_data && texture_read_data[0]));
  assign vga_g = video_active && ((sprite_read_data && sprite_g) || (!sprite_read_data && texture_read_data[1]));
  assign vga_b = video_active && ((sprite_read_data && sprite_b) || (!sprite_read_data && texture_read_data[2]));

	always @(posedge clk) begin
		if (iomem_valid && reg_write) begin
			if (iomem_wstrb[0]) config_register_bank[bank_addr][ 7: 0] <= iomem_wdata[ 7: 0];
			if (iomem_wstrb[1]) config_register_bank[bank_addr][15: 8] <= iomem_wdata[15: 8];
			if (iomem_wstrb[2]) config_register_bank[bank_addr][23:16] <= iomem_wdata[23:16];
			if (iomem_wstrb[3]) config_register_bank[bank_addr][31:24] <= iomem_wdata[31:24];
		end
    if (!resetn) begin
      config_register_bank[0]<=32'h0;
      config_register_bank[1]<=32'h0;
      config_register_bank[2]<=32'h0;
      config_register_bank[3]<=32'h0;
      config_register_bank[4]<=32'h0;
      config_register_bank[5]<=32'h0;
      config_register_bank[6]<=32'h0;
      config_register_bank[7]<=32'h0;
      config_register_bank[8]<=32'h0;
      config_register_bank[9]<=32'h0;
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

`endif
