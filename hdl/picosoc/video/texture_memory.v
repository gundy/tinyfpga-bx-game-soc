
// 3 BRAMS
module texture_memory (
    input clk, wen, ren,
    input [11:0] waddr, raddr,
    input [1:0] wdata,
    output reg [1:0] rdata
);
    reg [1:0] mem [0:16383];   // enough memory for 256 8x8 texture tiles @ 2bpp // uses 8/32 BRAMS of Ice40
    always @(posedge clk) begin
      if (ren)
        rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
