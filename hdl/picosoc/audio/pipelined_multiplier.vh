`ifndef __PIPELINED_18x18_MULTIPLIER__
`define __PIPELINED_18x18_MULTIPLIER__

module pipelined_signed_18x18_multiplier(
  input clk,
  input input_rdy,
  input wire signed[17:0] a,
  input wire signed[17:0] b,
  output reg signed[35:0] p,
  output reg busy);

  reg signed [17:0] correction;
  reg [8:0] m1, m2;
  wire [17:0] p1;

  reg[2:0] state;
  assign p1 = m1 * m2;  /* 9x9 multiplier */

  localparam STATE_IDLE = 3'd0;

  initial begin
    state = STATE_IDLE;
    busy = 0;
  end

  always @(posedge clk) begin
    (* full_case, parallel_case *)
    case (state)
      STATE_IDLE: begin
        if (input_rdy) begin
          m1 = a[8:0];
          m2 = b[8:0];
          busy = 1'b1;
          p = 0;
          correction <= (b[17] ? -a : 0) - (a[17] ? -b : 0);
          state <= state + 1;
        end
      end
      3'd1: begin
        p <= p + p1 - (correction << 18);  // apply signedness correction factors;
        m2 = b[17:9];
        state <= state+1;
      end
      3'd2: begin
        p <= p + (p1 << 9);
        m1 = a[17:9];
        m2 = b[8:0];
        state <= state + 1;
      end
      3'd3: begin
        p <= p + (p1 << 9);
        m2 = b[17:9];
        state <= state+1;
      end
      3'd4: begin
        p <= p + (p1 << 18);
        busy <= 1'b0;
        state <= STATE_IDLE;
      end
    endcase
  end
endmodule

`endif
