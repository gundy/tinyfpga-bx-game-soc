`ifndef __SPRITE_MEMORY__
`define __SPRITE_MEMORY__

// 4 BRAMS
module sprite_memory (
    input rclk, wclk, wen, ren,
    input [11:0] waddr, raddr,
    input [5:0] wdata,
    output reg [5:0] rdata
);
    reg [3:0] mem [0:4095];   // enough memory for 16 16x16 sprites (with transparency)
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
