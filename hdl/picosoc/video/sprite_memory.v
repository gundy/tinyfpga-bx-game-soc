
// 4 BRAMS
// sprite memory = 64 sprites @ 16x16 resolution @ 1bpp = 16384 bits or 2048 bytes
module sprite_memory (
    input clk, wen, ren,
    input [12:0] waddr, raddr,
    input [1:0] wdata,
    output reg [1:0] rdata
);
    reg [1:0] mem [0:8191];   // enough memory for 64 16x16 sprites @ 1bpp
    always @(posedge clk) begin
      if (ren)
        rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
