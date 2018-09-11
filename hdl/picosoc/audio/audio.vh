/*
 * audio peripheral for game soc
 *
 */

// TODO everything

`ifndef __GAME_SOC_AUDIO__
`define __GAME_SOC_AUDIO__

`include "pdm_dac.vh"

module audio
(
  input resetn,
  input clk,
	input iomem_valid,
	output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
	output reg [31:0] iomem_rdata,
  output audio_left,
  output audio_right);

	reg [31:0] config_register_bank [0:15];

	always @(posedge clk) begin
		if (!resetn) begin
      // reset config registers to default values
		end else begin
			iomem_ready <= 0;
			if (iomem_valid && !iomem_ready) begin
				iomem_ready <= 1;
				iomem_rdata <= config_register_bank[iomem_addr[3:0]];
				if (iomem_wstrb[0]) config_register_bank[iomem_addr[3:0]][ 7: 0] <= iomem_wdata[ 7: 0];
				if (iomem_wstrb[1]) config_register_bank[iomem_addr[3:0]][15: 8] <= iomem_wdata[15: 8];
				if (iomem_wstrb[2]) config_register_bank[iomem_addr[3:0]][23:16] <= iomem_wdata[23:16];
				if (iomem_wstrb[3]) config_register_bank[iomem_addr[3:0]][31:24] <= iomem_wdata[31:24];
			end
		end
	end

  reg signed [11:0] audio_out = 12'sd0;

  pdm_dac left_dac(.din(audio_out), .dout(audio_left), .clk(clk));
  pdm_dac right_dac(.din(audio_out), .dout(audio_right), .clk(clk));

endmodule

`endif
