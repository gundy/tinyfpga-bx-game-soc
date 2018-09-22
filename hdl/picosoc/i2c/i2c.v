
module i2c(
  input resetn,
  input clk,
	input iomem_valid,
	output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
  output reg [31:0] iomem_rdata,
  inout I2C_SDA,
  inout I2C_SCL
);

  reg i2c_enable = 0, i2c_read = 0;
  reg [31:0] i2c_write_reg = 0;
  reg [31:0] i2c_read_reg;

  I2C_master #(.freq(16)) i2c (
      .SDA(I2C_SDA),
      .SCL(I2C_SCL),
      .sys_clock(clk),
      .reset(~resetn),
      .ctrl_data(i2c_write_reg),
      .wr_ctrl(i2c_enable),
      .read(i2c_read),
      .status(i2c_read_reg));

  ///////////////////////////////////////////////////////////////////
  //    Handle PicoSoC writing to the config register bank
  ///////////////////////////////////////////////////////////////////
	always @(posedge clk) begin
    i2c_enable <= 0;
    iomem_ready <= 0;
    if (iomem_valid && !iomem_ready) begin
      iomem_ready <= 1;
      if (iomem_wstrb[0]) i2c_write_reg[ 7: 0] <= iomem_wdata[ 7: 0];
      if (iomem_wstrb[1]) i2c_write_reg[15: 8] <= iomem_wdata[15: 8];
      if (iomem_wstrb[2]) i2c_write_reg[23:16] <= iomem_wdata[23:16];
      if (iomem_wstrb[3]) i2c_write_reg[31:24] <= iomem_wdata[31:24];

      iomem_rdata <= i2c_read_reg;
      if (|iomem_wstrb) i2c_enable <= 1;
      if (iomem_addr[7:0] == 8'h00) begin
          i2c_read <= 0;
      end else if (iomem_addr[7:0] == 8'h04) begin
          i2c_read <= 1;
      end
    end

		// if (!resetn) begin
    //
		// end
end


endmodule
