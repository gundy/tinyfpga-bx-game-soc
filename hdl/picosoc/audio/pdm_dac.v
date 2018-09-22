
/* ============================
 * Pulse-density modulated DAC
 * ============================
 *
 * This module drives a digital output at an average level equivalent
 * to the data-in (din) value.  It can be filtered to an analog output
 * using a low-pass filter (eg. an RC filter).
 *
 * Principle of operation:
 *
 * This works by repeatedly adding the input (din) value to an accumulator of the
 * same width, and setting the output to "1" if the accumulator overflows.
 * The remainder after overflow is left in the accumulator for the next cycle,
 * and has the effect of averaging out any errors.
 *
 * (The accumulator has to be an extra bit wider than data-in to accomodate
 *  the overflow (output) bit).
 */
module pdm_dac #(parameter SAMPLE_BITS = 12)(
  input signed [SAMPLE_BITS-1:0] din,
  input wire clk,
  output wire dout
);

reg [SAMPLE_BITS:0] accumulator;
wire [SAMPLE_BITS-1:0] unsigned_din;

assign unsigned_din = din ^ (2**(SAMPLE_BITS-1));

always @(posedge clk) begin
  accumulator <= (accumulator[SAMPLE_BITS-1 : 0] + unsigned_din);
end

assign dout = accumulator[SAMPLE_BITS];

endmodule
