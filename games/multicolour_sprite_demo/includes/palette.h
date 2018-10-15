#ifndef __PALETTE_H__
#define __PALETTE_H__

// to be used with digilent VGA PMOD

// ------------------+----------------------
// tinyfpga output   | digilent pmod pins
// ------------------+----------------------
//  R[2:0]           | R[3:1]
//  G[2:0]           | G[3:1]
//  B[1:0]           | B[3:2]
//  B[0]             | B[1]
//

//
// 16 colour global palette
//
// RGB values for palette
// 0   0   0	#0
// 32  32 128	#1
// 32  64  96	#2
// 96  64   0	#3
// 96 192  96	#4
// 128  32   0	#5
// 128 128 128	#6
// 128 128 224	#7
// 160  96   0	#8
// 160  96 224	#9
// 160 192 224	#10
// 192 128 128	#11
// 192 192 224	#12
// 192 224 128	#13
// 224 224 128	#14
// 224 224 224	#15
//
// (These values are mapped into an RRRGGGBB byte value below)

const uint32_t palette_data[16] = {
    0x00, 0x26, 0x29, 0x68, 0x79, 0x84, 0x92, 0x93, 0xac, 0xaf, 0xbb, 0xd2, 0xdb, 0xde, 0xfe, 0xff
};

// a variety of different 4-colour mixes from the palette above
const uint32_t sub_palette_data[16] = {
    0xfc60, 0xf710, 0xfb50, 0xc214, 0xc978, 0xfd40, 0xa625, 0xfe50,
    0xf830, 0x6352, 0xa798, 0xb720, 0xb350, 0xb823, 0x2430, 0xfe85
};

#endif
