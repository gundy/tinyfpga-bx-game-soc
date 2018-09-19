upload: hardware.bin
	tinyprog -p hardware.bin

hardware.bin: hardware.asc
	icetime -d hx8k -c 12 -mtr hardware.rpt hardware.asc
	icepack hardware.asc hardware.bin

hardware.blif: top.v
	yosys -ql hardware.log -p 'synth_ice40 -top top -blif hardware.blif' $^

hardware.asc: pins.pcf hardware.blif
	arachne-pnr -r -m 400 -d 8k -P cm81 -o hardware.asc -p pins.pcf hardware.blif

clean:
	rm -f hardware.blif hardware.log hardware.asc hardware.rpt hardware.bin
