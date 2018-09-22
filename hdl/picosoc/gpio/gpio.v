
/*
 * IO mapped module for PicoSOC to drive the TinyFPGA BX LED, and to return button state
 *
 */
module gpio
(
  input resetn,
  input clk,
	input iomem_valid,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
  output reg [31:0] iomem_rdata,
  output reg iomem_ready,
	input [31:0] iomem_wdata,
  inout [7:0] BUTTONS, /* buttons in from FPGA pins */
  output led);

  wire[7:0] gpio_buttons;

  SB_IO #(
      .PIN_TYPE(6'b 0000_01),
      .PULLUP(1'b 1)
  ) buttons_input [7:0] (
      .PACKAGE_PIN(BUTTONS),
      .D_IN_0(gpio_buttons)
  );

	reg [31:0] gpio;
	assign led = gpio[0];

	always @(posedge clk) begin
		if (!resetn) begin
			gpio <= 0;
		end else begin
      iomem_ready <= 0;
			if (iomem_valid && !iomem_ready) begin
        iomem_ready <= 1;
				if (iomem_wstrb[0]) gpio[ 7: 0] <= iomem_wdata[ 7: 0];
				if (iomem_wstrb[1]) gpio[15: 8] <= iomem_wdata[15: 8];
				if (iomem_wstrb[2]) gpio[23:16] <= iomem_wdata[23:16];
				if (iomem_wstrb[3]) gpio[31:24] <= iomem_wdata[31:24];
		    iomem_rdata <= ~gpio_buttons;  // read of GPIO always returns button state
			end
		end
	end

endmodule
