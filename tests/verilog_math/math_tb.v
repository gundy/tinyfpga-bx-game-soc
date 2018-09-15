`default_nettype none
`timescale 100 ns / 10 ns

module math_tb();

//-- Simulation time: 1us (10 * 100ns)
parameter DURATION = 100;

//-- Clock signal. Running at 1MHz
reg clkin = 0;
always #0.5 clkin = ~clkin;


reg signed [8:0] a1 = 9'sd255;
reg signed [11:0] b1 = -12'sd2047;
wire signed[11:0] p1;

math matha(.a(a1), .b(b1), .p(p1));

initial begin

  //-- File were to store the simulation results
  $dumpfile("math_tb.vcd");
  $dumpvars(0, math_tb);

   #(DURATION) $display("End of simulation");
  $finish;
end

endmodule
