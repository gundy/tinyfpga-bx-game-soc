//-------------------------------------------------------------------
//-- Testbench for the tiny-synth clock divider module
//-------------------------------------------------------------------
`default_nettype none
`timescale 100 ns / 10 ns

module pipelined_multiplier_tb();

//-- Simulation time: Duration * 0.1us (timescale above)
parameter DURATION = 1000;  // 1000 = 0.1 milliseconds

//-- Clock signal. Running at 1MHz
reg clkin = 1'b1;
always #0.5 clkin = ~clkin;

wire clkin16;

clock_divider #(.DIVISOR(16)) cdiv_c16(.cin(clkin), .cout(clkin16));

wire signed[35:0] p;
reg signed [17:0] a = 18'sd50;
reg signed [17:0] b = -18'sd100;
wire signed[35:0] expected_result = a*b;
reg input_rdy = 1'b1;

wire busy;
reg prev_busy = 0;

always @(posedge clkin) begin
  prev_busy <= busy;

  if (!busy && prev_busy) begin
    if (expected_result == p) begin
      $display("SUCCESS: A(%h)*B(%h)=P(%h)",a,b,p);
    end else begin
      $display("**** ERROR: A(%h)*B(%h) got P(%h) but wanted E(%h)",a,b,p,expected_result);
    end
    a <= a + 18'sh12345;
    b <= b + 18'sh00123;
    input_rdy <= 1;
  end else begin
    input_rdy <= 0;
  end
end

pipelined_signed_18x18_multiplier mult(.clk(clkin),.a(a), .b(b), .p(p), .busy(busy), .input_rdy(input_rdy));

initial begin

  //-- File were to store the simulation results
  $dumpfile("pipelined_multiplier_tb.vcd");
  $dumpvars(0, pipelined_multiplier_tb);

   #(DURATION) $display("End of simulation");
  $finish;
end

endmodule
