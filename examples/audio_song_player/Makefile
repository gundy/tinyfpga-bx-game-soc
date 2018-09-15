
upload: firmware.bin
		tinyprog -u firmware.bin

firmware.elf: sections.lds start.S firmware.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostartfiles -Wl,-Bstatic,-T,sections.lds,--strip-debug,-Map=firmware.map,--cref  -ffreestanding -nostdlib -o firmware.elf start.S firmware.c

firmware.bin: firmware.elf
	/opt/riscv32i/bin/riscv32-unknown-elf-objcopy -O binary firmware.elf /dev/stdout > firmware.bin

firmware.s: firmware.c
	/opt/riscv32i/bin/riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostartfiles -Wl,-Bstatic,-T,sections.lds,--strip-debug,-Map=firmware.map,--cref  -ffreestanding -nostdlib -S firmware.c


clean:
	rm -f firmware.elf firmware.hex firmware.bin firmware.o firmware.map
