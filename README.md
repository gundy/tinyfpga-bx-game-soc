# Overview

The idea behind this project is to use PicoSoC (from Clifford Wolf), and add some verilog peripherals to make it suitable for writing simple games on the TinyFPGA BX..

The PicoRV CPU variant chosen will be, by necessity, very cut-down in functionality - along the lines of the "small" profile.  Unfortunately the larger profiles with support for things like multipliers/dividers would be impossible to fit into the space available on the ice40hx8k part.

The planned peripherals are:

* On-board LED
* Serial UART
* [planned] an IRQ-based timer/counter
* [planned] a 3-channel audio synthesizer
* [planned] Graphics output
 * 320x240 resolution
 * palette of 16 colours from ~262k
 * tile/map based support
 * sprites
* [planned] joystick port(s)

Planned IO locations for the devices are:

| IOMEM_ADDR (hex) | Peripheral |
| ---------- | ---------- |
| 0x0200_0000 | SPI config |
| 0x0200_0004 | UART divider |
| 0x0200_0008 | UART data register |
| 0x03xx_xxxx | On-board LED |
| 0x04xx_xxxx | Audio device |
| 0x05xx_xxxx | Video device |
| 0x06xx_xxxx | Timer/counter |


Documentation for each of the peripherals, including more detailed register mappings will be placed in their respective folders under hdl/picosoc (as they are developed).

# Discussion

This project was kicked off by a [discussion](https://discourse.tinyfpga.com/t/bx-portable-game-console-project-collaboration/553/7)
on the TinyFPGA forums.

Feel free to join in there!

# Credits

Of course, none of this would be possible without the amazing work of a great number of people.  

## Clifford Wolf (PicoRV32 & PicoSOC)

Clifford Wolf is the author of the icestorm toolchain, and creator of the PicoRV32 RISC-V CPU core used in this project.

PicoRV32 is free and open hardware licensed under the ISC license (a license that is similar in terms to the MIT license or the 2-clause BSD license).

Source code can be found here: https://github.com/cliffordwolf/picorv32

## Luke Valenty (Tiny FPGA)

Luke is the mastermind behind the breadboard-friendly "Tiny" FPGA series that this project is designed to use.  You can order your TinyFPGA from crowdsupply.
