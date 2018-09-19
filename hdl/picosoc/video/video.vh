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

  wire pixel_clock;
  reg[9:0] xpos;
  reg[9:0] ypos;
  wire[9:0] next_xpos = xpos+1;
  wire video_active;

  // video registers
  // x scroll offset
  // y scroll offset

	reg [31:0] config_register_bank [0:3];
  wire [3:0] bank_addr = iomem_addr[5:2];

  // todo sprites
  // sprite_memory spritemem();

  wire reg_write = (iomem_valid & iomem_wstrb[0] && iomem_addr[23:20]==4'h0);
  wire texmem_write = (iomem_valid & iomem_wstrb[0] && iomem_addr[23:20]==4'h1);
  wire tilemem_write = (iomem_valid & iomem_wstrb[0] && iomem_addr[23:20]==4'h2);

  wire [5:0] tile_read_data;
  wire [2:0] texture_read_data;

  wire [9:0] xofs = config_register_bank[0][8:0]<<1;
  wire [9:0] yofs = config_register_bank[0][8:0]<<1;

  wire [9:0] effective_y = ypos+yofs;
  wire [9:0] effective_x = xpos+xofs;
  wire [9:0] effective_next_x = next_xpos+xofs;

  // need to read ahead with tile memory to prevent edge-artifacts
  wire [11:0] tile_read_address = { effective_y[9:4], effective_next_x[9:4] };
  tile_memory tilemem(
    .rclk(pixel_clock), .ren(video_active), .raddr(tile_read_address), .rdata(tile_read_data),
    .wclk(clk), .wen(tilemem_write), .waddr(iomem_addr[13:2]), .wdata(iomem_wdata[5:0])
  );

  wire [11:0] texture_read_address = { tile_read_data[5:0], effective_y[3:1], effective_x[3:1] };
  texture_memory texturemem(
    .rclk(pixel_clock), .ren(video_active), .raddr(texture_read_address), .rdata(texture_read_data),
    .wclk(clk), .wen(texmem_write), .waddr(iomem_addr[13:2]), .wdata(iomem_wdata[2:0])
  );

  assign vga_r = video_active && texture_read_data[2];
  assign vga_g = video_active && texture_read_data[1];
  assign vga_b = video_active && texture_read_data[0];

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
    end
	end

  VGASyncGen vga_generator(
    .clk(clk),
    .hsync(vga_hsync),
    .vsync(vga_vsync),
    .x_px(xpos),
    .y_px(ypos),
    .activevideo(video_active),
    .px_clk(pixel_clock)
  );

endmodule

`endif
