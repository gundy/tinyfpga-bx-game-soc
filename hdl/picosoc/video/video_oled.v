
module video_oled
(
  input resetn,
  input clk,
	input iomem_valid,
  output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
  inout OLED_SPI_SCL,
  inout OLED_SPI_SDA,
  inout OLED_SPI_RES,
  inout OLED_SPI_DC,
  inout OLED_SPI_CS);

  reg spi_wr, spi_rd;
  reg [31:0] spi_rdata;
  reg spi_ready;
  spi_oled #(.CLOCK_FREQ_HZ(16000000)) oled (
      .clk(CLK),
      .resetn(resetn),
      .ctrl_wr(spi_wr),
      .ctrl_rd(spi_rd),
      .ctrl_addr(iomem_addr[7:0]),
      .ctrl_wdat(iomem_wdata),
      .ctrl_rdat(spi_rdata),
      .ctrl_done(spi_ready),
      .mosi(OLED_SPI_SDA),
      .sclk(OLED_SPI_SCL),
      .cs(OLED_SPI_CS),
      .dc(OLED_SPI_DC),
      .rst(OLED_SPI_RES));


	always @(posedge clk) begin
    spi_wr <= 0;
    spi_rd <= 0;
    if (iomem_valid && !iomem_ready) begin
         iomem_ready <= spi_ready;
         iomem_rdata <= spi_rdata;
         spi_wr <= |iomem_wstrb;
         spi_rd <= ~(|iomem_wstrb);
    end
	end

endmodule
