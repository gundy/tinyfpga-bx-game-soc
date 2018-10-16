
// 4 BRAMS
// sprite memory = 32 sprites @ 16 lines of 16 pixels at 2bpp resolution (32-bits per line)
module sprite_memory (
    input clk,
    input [3:0] wen,
    input [8:0] waddr,
    input [8:0] raddr,
    input [31:0] wdata,
    output reg [31:0] rdata
);
    reg [31:0] mem [0:511];   // enough memory for 64 16x16 sprites @ 1bpp
    always @(posedge clk) begin
      rdata <= mem[raddr];

      if (wen[0]) mem[waddr][ 7: 0] <= wdata[ 7: 0];
  		if (wen[1]) mem[waddr][15: 8] <= wdata[15: 8];
  		if (wen[2]) mem[waddr][23:16] <= wdata[23:16];
  		if (wen[3]) mem[waddr][31:24] <= wdata[31:24];
    end
endmodule
