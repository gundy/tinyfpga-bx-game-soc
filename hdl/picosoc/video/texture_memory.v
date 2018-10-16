
module texture_memory (
    input clk, wen,
    input [13:0] waddr, raddr,
    input [1:0] wdata,
    output reg [1:0] rdata
);
    reg [1:0] mem [0:16383];   // enough memory for 256 8x8 textures @ 2bpp
    always @(posedge clk) begin
      rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
