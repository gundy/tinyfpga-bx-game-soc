
// 6 BRAMS
module tile_memory (
    input clk, wen, ren,
    input [11:0] waddr, raddr,
    input [5:0] wdata,
    output reg [5:0] rdata
);
    reg [5:0] mem [0:4095];   // enough memory for 64x64 map of tiles // uses ~6 BRAMS of Ice40
    always @(posedge clk) begin
      if (ren)
        rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
