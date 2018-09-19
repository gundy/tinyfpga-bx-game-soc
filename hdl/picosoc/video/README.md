# TODO document the video driver

# Current thoughts

- 3 bits per pixel
- 64 8x8 textures @ 3bpp
- 80x50 tile map  (6-bits per tile to address all 64 textures)
- 640x480 display

## If possible

### Sprites
8 16x16 sprites @ 8 colours  (4bpp; high bit = transparency).

# Operation

The following will be mapped into IO memory:

- block RAMs (for texture/tile/sprite definitions) (write-only as far as the CPU is concerned).
- scroll x/y offset registers

## If possible

- 16 x sprite location registers
- maybe palette registers


# BRAM usage
- textures: 3
- tiles: 6
- sprites: 4

- total: 13
