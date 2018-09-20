`ifndef __SPRITE_MEMORY__
`define __SPRITE_MEMORY__

// 4 BRAMS
module sprite_memory (
    input rclk, wclk, wen, ren,
    input [13:0] waddr, raddr,
    input wdata,
    output reg rdata
);
    reg [0:0] mem [0:16383];   // enough memory for 64 16x16 sprites @ 1bpp
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
