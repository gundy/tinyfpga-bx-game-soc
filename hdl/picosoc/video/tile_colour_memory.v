
module tile_and_colour_memory (
    input clk, wen, ren,
    input [11:0] waddr, raddr,
    input [11:0] wdata,
    output reg [11:0] rdata
);
    reg [11:0] mem [0:2047];   // enough memory for 64x32 map of tiles (8-bits) and sub-palette indexes (4-bits)
    always @(posedge clk) begin
      if (ren)
        rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
