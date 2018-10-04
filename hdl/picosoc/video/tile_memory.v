
// 4 BRAMS
module tile_memory (
    input clk, wen, ren,
    input [11:0] waddr, raddr,
    input [7:0] wdata,
    output reg [7:0] rdata
);
    reg [7:0] mem [0:2047];   // enough memory for 80*25 (or 40*50) map of tiles - 256 possible tiles = 8 bits per location; 16384 bits == 4 BRAMS
    always @(posedge clk) begin
      if (ren)
        rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
