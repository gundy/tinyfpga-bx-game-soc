/*
 * timer/counter peripheral for game soc
 *
 */

`ifndef __GAME_SOC_TIMER_COUNTER__
`define __GAME_SOC_TIMER_COUNTER__


module timer_counter
(
  input resetn,
  input clk,
	input iomem_valid,
	output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
	output reg [31:0] iomem_rdata,
  output wire overflow);

	reg [32:0] accumulator;
  reg [31:0] increment;

  assign overflow = accumulator[32];

  initial begin
    accumulator <= 0;
    increment <= 0;    /* timer-counter disabled */
  end

	always @(posedge clk) begin
		if (!resetn) begin
      // reset config registers to default values
		end else begin
      accumulator <= accumulator[31:0] + increment;

			iomem_ready <= 0;
			if (iomem_valid && !iomem_ready) begin
        iomem_ready <= 1;
        case (iomem_addr[2:0])
          3'd0: begin /* accumulator register */
            iomem_rdata <= accumulator;
            if (iomem_wstrb[0]) accumulator[ 7: 0] <= iomem_wdata[ 7: 0];
    				if (iomem_wstrb[1]) accumulator[15: 8] <= iomem_wdata[15: 8];
    				if (iomem_wstrb[2]) accumulator[23:16] <= iomem_wdata[23:16];
    				if (iomem_wstrb[3]) accumulator[31:24] <= iomem_wdata[31:24];
          end
          3'd4: begin  /* increment value */
            iomem_rdata <= increment;
            if (iomem_wstrb[0]) increment[ 7: 0] <= iomem_wdata[ 7: 0];
            if (iomem_wstrb[1]) increment[15: 8] <= iomem_wdata[15: 8];
            if (iomem_wstrb[2]) increment[23:16] <= iomem_wdata[23:16];
            if (iomem_wstrb[3]) increment[31:24] <= iomem_wdata[31:24];
          end
        endcase
			end
		end
	end

endmodule

`endif
