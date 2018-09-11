`ifndef __TEXTURE_MEMORY__
`define __TEXTURE_MEMORY__

module texture_memory (
    input clk, wen, ren,
    input [11:0] waddr, raddr,
    input [7:0] wdata,
    output reg [7:0] rdata
);
    reg [3:0] mem [0:4095];   // enough memory for 64 8x8 texture tiles @ 4bpp // uses 4/32 BRAMS of Ice40
    always @(posedge clk) begin
      if (wen)
        mem[waddr] <= wdata;
      if (ren)
        rdata <= mem[raddr];
    end
endmodule

`endif
