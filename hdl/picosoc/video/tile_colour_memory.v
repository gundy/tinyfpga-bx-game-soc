
// 2 BRAMS
// for each tile position, colour memory contains the palette to apply to the tile
module tile_colour_memory (
    input clk, wen, ren,
    input [11:0] waddr, raddr,
    input [3:0] wdata,
    output reg [3:0] rdata
);
    reg [3:0] mem [0:2047];   // enough memory for 80*25 (or 40*50) map of tile palette indexes; 8192 bits == 2 BRAMS
    always @(posedge clk) begin
      if (ren)
        rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
