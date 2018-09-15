/*
 * Video peripheral for TinyFPGA game SoC
 *
 */

// TODO everything


`ifndef __GAME_SOC_VIDEO__
`define __GAME_SOC_VIDEO__

module video
(
  input resetn,
  input clk,
	input iomem_valid,
	output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
	output reg [31:0] iomem_rdata);

	reg [31:0] config_register_bank [0:15];

  wire [3:0] bank_addr = iomem_addr[5:2];

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

endmodule

`endif
