/*
 * Video peripheral for TinyFPGA game SoC
 *
 */

// TODO everything


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
	output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
	output reg [31:0] iomem_rdata,
  output vga_hsync,
  output vga_vsync,
  output vga_r,
  output vga_g,
  output vga_b);

  wire pixel_clock;
  reg[9:0] xpos;
  reg[9:0] ypos;
  wire video_active;

  // video registers
  // x scroll offset
  // y scroll offset

	reg [31:0] config_register_bank [0:3];
  wire [3:0] bank_addr = iomem_addr[5:2];

  // todo sprites
  // sprite_memory spritemem();

  wire texmem_write = (iomem_wstrb[0] && iomem_addr[23:20]==4'h0);
  wire tilemem_write = (iomem_wstrb[0] && iomem_addr[23:20]==4'h1);

  wire [5:0] tile_read_data;
  wire [2:0] texture_read_data;

  wire [11:0] tile_read_address = 12'h0; // calculate tile read address

  tile_memory tilemem(
    .rclk(pixel_clock), .ren(video_active), .raddr(tile_read_address), .rdata(tile_read_data),
    .wclk(clk), .wen(tilemem_write), .waddr(iomem_addr[13:2]), .wdata(iomem_wdata[5:0])
  );

  wire [11:0] texture_read_address = {6'b0, tile_read_data}; // (tile_read_data<<6)+(tile_y_ofs<<3)+tile_x_ofs;
  texture_memory texturemem(
    .rclk(pixel_clock), .ren(video_active), .raddr(texture_read_address), .rdata(texture_read_data),
    .wclk(clk), .wen(texmem_write), .waddr(iomem_addr[13:2]), .wdata(iomem_wdata[2:0])
  );

  assign vga_r = texture_read_data[2];
  assign vga_g = texture_read_data[1];
  assign vga_b = texture_read_data[0];

	always @(posedge clk) begin
		if (!resetn) begin
      // reset config registers to default values
		end else begin
      // TODO also map texture/tile SRAM blocks to IO space
      // TODO connect output up
      // TODO ... do everything! :)
			iomem_ready <= 0;
			if (iomem_valid && !iomem_ready) begin
				iomem_ready <= 1;
				iomem_rdata <= config_register_bank[bank_addr];
				if (iomem_wstrb[0]) config_register_bank[bank_addr][ 7: 0] <= iomem_wdata[ 7: 0];
				if (iomem_wstrb[1]) config_register_bank[bank_addr][15: 8] <= iomem_wdata[15: 8];
				if (iomem_wstrb[2]) config_register_bank[bank_addr][23:16] <= iomem_wdata[23:16];
				if (iomem_wstrb[3]) config_register_bank[bank_addr][31:24] <= iomem_wdata[31:24];
			end
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
