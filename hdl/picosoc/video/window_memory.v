
module window_memory (
    input clk, wen,
    input [7:0] waddr, raddr,
    input [11:0] wdata,
    output reg [11:0] rdata
);
    reg [11:0] mem [0:255];   // enough memory for 64*4 lines of data for the window display
    always @(posedge clk) begin
      rdata <= mem[raddr];
      if (wen)
        mem[waddr] <= wdata;
    end
endmodule
