`ifndef __TEXTURE_MEMORY__
`define __TEXTURE_MEMORY__

// 3 BRAMS
module texture_memory (
    input rclk, wclk, wen, ren,
    input [11:0] waddr, raddr,
    input [2:0] wdata,
    output reg [2:0] rdata
);
    reg [2:0] mem [0:4095];   // enough memory for 64 8x8 texture tiles @ 3bpp // uses 4/32 BRAMS of Ice40
    always @(posedge rclk) begin
      if (ren)
        rdata <= mem[raddr];
    end
    always @(posedge wclk) begin
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule

`endif
