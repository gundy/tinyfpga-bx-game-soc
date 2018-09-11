`ifndef __TINYFPGA_GAME_SOC_LED__
`define __TINYFPGA_GAME_SOC_LED__

/*
 * IO mapped module for PicoSOC to drive the TinyFPGA BX LED
 *
 * Reads are mapped to IO region in picosoc.v; writes get checked
 * to ensure that they're going to the correct address by each
 * peripheral (ie. here).
 */
module gpio_led
(
  input resetn,
  input clk,
	input iomem_valid,
	output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
	output reg [31:0] iomem_rdata,
  output led);

	reg [31:0] gpio;
	assign led = gpio[0];

	always @(posedge clk) begin
		if (!resetn) begin
			gpio <= 0;
		end else begin
			iomem_ready <= 0;
			if (iomem_valid && !iomem_ready) begin
				iomem_ready <= 1;
				iomem_rdata <= gpio;
				if (iomem_wstrb[0]) gpio[ 7: 0] <= iomem_wdata[ 7: 0];
				if (iomem_wstrb[1]) gpio[15: 8] <= iomem_wdata[15: 8];
				if (iomem_wstrb[2]) gpio[23:16] <= iomem_wdata[23:16];
				if (iomem_wstrb[3]) gpio[31:24] <= iomem_wdata[31:24];
			end
		end
	end

endmodule

`endif
