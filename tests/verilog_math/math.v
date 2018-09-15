// simple instantiation of the clock divider module
module math(
  input signed [8:0] a,
  input signed [11:0] b,
  output signed [11:0] p);

  assign p = ({12'b0,a}*b)>>>8;
endmodule
