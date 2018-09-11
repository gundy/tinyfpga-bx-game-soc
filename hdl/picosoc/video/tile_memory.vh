`ifndef __TILE_MEMORY__
`define __TILE_MEMORY__

module tile_memory (
    input clk, wen, ren,
    input [11:0] waddr, raddr,
    input [7:0] wdata,
    output reg [6:0] rdata
);
    reg [6:0] mem [0:4095];   // enough memory for 64x64 map of tiles // uses ~6 BRAMS of Ice40
    always @(posedge clk) begin
      if (wen)
        mem[waddr] <= wdata;
      if (ren)
        rdata <= mem[raddr];
    end
endmodule

`endif
