/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

module top (
    input CLK,

    // hardware UART
    output SER_TX,
    input SER_RX,

    // onboard SPI flash interface
    output SPI_SS,
    output SPI_SCK,
    inout  SPI_IO0,
    inout  SPI_IO1,
    inout  SPI_IO2,
    inout  SPI_IO3,

`ifdef pdm_audio
    // Audio out pin
		output AUDIO_RIGHT,
    output AUDIO_LEFT,
`endif

`ifdef i2c
    // I2C pins
    inout I2C_SDA,
    inout I2C_SCL,
`endif

`ifdef oled
    inout OLED_SPI_SCL,
    inout OLED_SPI_SDA,
    inout OLED_SPI_RES,
    inout OLED_SPI_DC,
    inout OLED_SPI_CS,
`endif

`ifdef vga
    output VGA_VSYNC,
    output VGA_HSYNC,
    output VGA_R2,
    output VGA_R1,
    output VGA_R0,
    output VGA_G2,
    output VGA_G1,
    output VGA_G0,
    output VGA_B1,
    output VGA_B0,
`endif

`ifdef gpio
    // GPIO buttons
    inout  [7:0] BUTTONS,

    // onboard LED
    output LED,
`endif

    // onboard USB interface
    output USBPU
);
    // Disable USB
    assign USBPU = 1'b0;

    ///////////////////////////////////
    // Power-on Reset
    ///////////////////////////////////
    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge CLK) begin
        reset_cnt <= reset_cnt + !resetn;
    end

    ///////////////////////////////////
    // SPI Flash Interface
    ///////////////////////////////////
    wire flash_io0_oe, flash_io0_do, flash_io0_di;
    wire flash_io1_oe, flash_io1_do, flash_io1_di;
    wire flash_io2_oe, flash_io2_do, flash_io2_di;
    wire flash_io3_oe, flash_io3_do, flash_io3_di;

    SB_IO #(
        .PIN_TYPE(6'b 1010_01),
        .PULLUP(1'b 0)
    ) flash_io_buf [3:0] (
        .PACKAGE_PIN({SPI_IO3, SPI_IO2, SPI_IO1, SPI_IO0}),
        .OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
        .D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
        .D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
    );

    ///////////////////////////////////
    // Peripheral Bus
    ///////////////////////////////////
    wire        iomem_valid;
    wire        iomem_ready;

    wire [3:0]  iomem_wstrb;
    wire [31:0] iomem_addr;
    wire [31:0] iomem_wdata;
    wire  [31:0] iomem_rdata;

    // enable signals for each of the peripherals
    wire gpio_en   = (iomem_addr[31:24] == 8'h03); /* GPIO mapped to 0x03xx_xxxx */
    wire video_en  = (iomem_addr[31:24] == 8'h05); /* Video device mapped to 0x05xx_xxxx */
    wire i2c_en    = (iomem_addr[31:24] == 8'h07); /* I2C device mapped to 0x06xx_xxxx */
    wire audio_en  = (iomem_addr[31:24] == 8'h04); /* Audio device mapped to 0x04xx_xxxx */


`ifdef pdm_audio
    wire audio_data;
  	assign AUDIO_LEFT = audio_data;
  	assign AUDIO_RIGHT = audio_data;
  	audio audio_peripheral(
  		.clk(CLK),
  		.resetn(resetn),
  		.audio_out(audio_data),
  		.iomem_valid(iomem_valid && audio_en),
  		.iomem_wstrb(iomem_wstrb),
  		.iomem_addr(iomem_addr),
  		.iomem_wdata(iomem_wdata)
  );
`endif

`ifdef oled
  video_oled(
    .clk(CLK),
    .resetn(resetn),
    .iomem_valid(iomem_valid && video_en),
    .iomem_wstrb(iomem_wstrb),
    .iomem_addr(iomem_addr),
    .iomem_wdata(iomem_wdata),
    .OLED_SPI_SDA(OLED_SPI_SDA),
    .OLED_SPI_SCL(OLED_SPI_SCL),
    .OLED_SPI_CS(OLED_SPI_CS),
    .OLED_SPI_DC(OLED_SPI_DC),
    .OLED_SPI_RES(OLED_SPI_RES)
  );
`endif

`ifdef vga
      wire [7:0] VGA_RGB;
      assign {VGA_R2, VGA_R1, VGA_R0, VGA_G2, VGA_G1, VGA_G0, VGA_B1, VGA_B0 } = { VGA_RGB };

      video_vga vga_video_peripheral(
      		.clk(CLK),
      		.resetn(resetn),
      		.iomem_valid(iomem_valid && video_en),
      		.iomem_wstrb(iomem_wstrb),
      		.iomem_addr(iomem_addr),
      		.iomem_wdata(iomem_wdata),
      		.vga_hsync(VGA_HSYNC),
      		.vga_vsync(VGA_VSYNC),
      		.vga_rgb(VGA_RGB)
      	);
`endif

  wire [31:0] gpio_iomem_rdata;
  wire gpio_iomem_ready;

`ifdef gpio
  gpio gpio_peripheral(
    .clk(CLK),
    .resetn(resetn),
    .iomem_ready(gpio_iomem_ready),
    .iomem_rdata(gpio_iomem_rdata),
    .iomem_valid(iomem_valid && gpio_en),
    .iomem_wstrb(iomem_wstrb),
    .iomem_addr(iomem_addr),
    .iomem_wdata(iomem_wdata),
    .BUTTONS(BUTTONS),
    .led(LED)
  );
`else
  assign gpio_iomem_ready = 1'b1;
  assign gpio_iomem_rdata = 32'h0;
`endif


///////////////////////////
// Controller Peripheral
///////////////////////////

wire [31:0] i2c_iomem_rdata;
wire i2c_iomem_ready;

`ifdef i2c

  i2c i2c_peripheral(
    .clk(CLK),
    .resetn(resetn),
    .iomem_ready(i2c_iomem_ready),
    .iomem_rdata(i2c_iomem_rdata),
    .iomem_valid(iomem_valid && i2c_en),
    .iomem_wstrb(iomem_wstrb),
    .iomem_addr(iomem_addr),
    .iomem_wdata(iomem_wdata),
    .I2C_SCL(I2C_SCL),
    .I2C_SDA(I2C_SDA)
  );
`else
  assign i2c_iomem_ready = 1'b1;     /* if i2c peripheral is "disconnected", fake always available zero bytes */
  assign i2c_iomem_rdata = 32'h0;
`endif


assign iomem_ready = (i2c_en && i2c_iomem_ready)
                  || (gpio_en && gpio_iomem_ready)
                  || audio_en
                  || video_en;
assign iomem_rdata =  i2c_iomem_ready ? i2c_iomem_rdata
                    : gpio_iomem_ready ? gpio_iomem_rdata
                    : 32'h0;

picosoc #(
	.BARREL_SHIFTER(0),
	.ENABLE_MULDIV(0),
	.ENABLE_COMPRESSED(0),
	.ENABLE_COUNTERS(0),
	.ENABLE_IRQ_QREGS(1),
	.ENABLE_TWO_STAGE_SHIFT(0),
  .ENABLE_REGS_DUALPORT(1),
	.PROGADDR_RESET(32'h0005_0000), // beginning of user space in SPI flash
	.PROGADDR_IRQ(32'h0005_0010),
	.MEM_WORDS(1024),                // use 4KBytes of block RAM by default (8 RAMS)
	.STACKADDR(1024),   /* stack addr = byte offset; stack starts at 0x400, grows downward. Data starts at 0x400+. */
	.ENABLE_IRQ(1)
) soc (
	.clk          (CLK         ),
	.resetn       (resetn      ),

	.ser_tx       (SER_TX      ),
	.ser_rx       (SER_RX      ),

	.flash_csb    (SPI_SS   ),
	.flash_clk    (SPI_SCK  ),

	.flash_io0_oe (flash_io0_oe),
	.flash_io1_oe (flash_io1_oe),
	.flash_io2_oe (flash_io2_oe),
	.flash_io3_oe (flash_io3_oe),

	.flash_io0_do (flash_io0_do),
	.flash_io1_do (flash_io1_do),
	.flash_io2_do (flash_io2_do),
	.flash_io3_do (flash_io3_do),

	.flash_io0_di (flash_io0_di),
	.flash_io1_di (flash_io1_di),
	.flash_io2_di (flash_io2_di),
	.flash_io3_di (flash_io3_di),

	.irq_5        (1'b0),
	.irq_6        (1'b0        ),
	.irq_7        (1'b0        ),

	.iomem_valid  (iomem_valid ),
	.iomem_ready  (iomem_ready ),
	.iomem_wstrb  (iomem_wstrb ),
	.iomem_addr   (iomem_addr  ),
	.iomem_wdata  (iomem_wdata ),
	.iomem_rdata  (iomem_rdata )
);
endmodule
