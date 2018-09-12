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

`default_nettype none

`include "./picosoc/gpio_led/gpio_led.vh"
`include "./picosoc/audio/audio.vh"
`include "./picosoc/timer_counter/timer_counter.vh"
// `include "./picosoc/memory/spiflash.v"
`include "./picosoc/memory/spimemio.v"
`include "./picosoc/uart/simpleuart.v"
`include "./picosoc/picosoc.v"
`include "./picorv32/picorv32.v"

 // look in pins.pcf for all the pin names on the TinyFPGA BX board
module top (
	input CLK,      // 16MHz clock
	output USBPU,  // USB pull-up resistor
	output LED,    // on-board LED

	// Audio PDM output - PIN 1 = left, PIN 2 = right
	output AUDIO_LEFT,
	output AUDIO_RIGHT,

	/* UART output (pin 11 = RX, pin 13 = TX) */
	output SER_TX,
	input SER_RX,

	/* SPI flash */
	output SPI_SS,
	output SPI_SCK,
	inout SPI_IO0,
	inout SPI_IO1,
	inout SPI_IO2,
	inout SPI_IO3);

	// drive USB pull-up resistor to '0' to disable USB
	assign USBPU = 0;

	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge CLK) begin
		reset_cnt <= reset_cnt + !resetn;
	end

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

	wire        iomem_valid;
	reg         led_iomem_ready;
	reg         audio_iomem_ready;
	reg         timer_iomem_ready;
	reg         iomem_ready;
	reg         iomem_ready;
	wire [3:0]  iomem_wstrb;
	wire [31:0] iomem_addr;
	wire [31:0] iomem_wdata;
	wire  [31:0] iomem_rdata;

	wire iomem_ready = led_iomem_ready || audio_iomem_ready || timer_iomem_ready;

	// enable signals for each of the peripherals
	wire gpio_en, audio_en, video_en, timer_counter_en;
	assign gpio_en = (iomem_addr[31:24] == 8'h03);  /* LED mapped to 0x03xx_xxxx */
	assign audio_en = (iomem_addr[31:24] == 8'h04); /* Audio device mapped to 0x04xx_xxxx */
  assign video_en = (iomem_addr[31:24] == 8'h05); /* Video device mapped to 0x05xx_xxxx */
	assign timer_counter_en = (iomem_addr[31:24] == 8'h06); /* timer/counter device mapped to 0x06xx_xxxx */

	wire [31:0] iomem_gpio_rdata, iomem_audio_rdata, iomem_video_rdata, iomem_timer_counter_rdata;
	assign iomem_rdata = gpio_en ? iomem_gpio_rdata
											: audio_en ? iomem_audio_rdata
											: video_en ? iomem_video_rdata
											: timer_counter_en ? iomem_timer_counter_rdata
											: 32'h 0000_0000;



	/* map peripherals into IO space */
	gpio_led led_peripheral(
		.clk(CLK),
		.resetn(resetn),
		.iomem_valid(iomem_valid && gpio_en),
		.iomem_ready(led_iomem_ready),
		.iomem_wstrb(iomem_wstrb),
		.iomem_addr(iomem_addr),
		.iomem_wdata(iomem_wdata),
		.iomem_rdata(iomem_gpio_rdata),
		.led(LED)
	);

	wire audio_data;
	assign AUDIO_LEFT = audio_data;
	assign AUDIO_RIGHT = audio_data;

	audio audio_peripheral(
		.clk(CLK),
		.resetn(resetn),
		.audio_out(audio_data),
		.iomem_valid(iomem_valid && gpio_en),
		.iomem_ready(audio_iomem_ready),
		.iomem_wstrb(iomem_wstrb),
		.iomem_addr(iomem_addr),
		.iomem_wdata(iomem_wdata),
		.iomem_rdata(iomem_audio_rdata),
	);

	wire timer_counter_overflow;  /* maybe this could be used to generate an interrupt? */
	timer_counter timer_counter_peripheral(
		.clk(CLK),
		.resetn(resetn),
		.iomem_valid(iomem_valid && timer_counter_en),
		.iomem_ready(timer_iomem_ready),
		.iomem_wstrb(iomem_wstrb),
		.iomem_addr(iomem_addr),
		.iomem_wdata(iomem_wdata),
		.iomem_rdata(iomem_timer_counter_rdata),
		.overflow(timer_counter_overflow)
	);

	picosoc soc (
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

		.irq_5        (timer_counter_overflow),
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
