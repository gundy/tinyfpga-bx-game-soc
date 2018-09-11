# TODO document the video driver

# Current thoughts

## Palette

16-colour palette, each colour chosen from 262144 colours (6-bits-per-colour).

## Texture memory

Enough memory for 64 textures at 8x8 resolution; 16 colours.   (64x8x8x4/4096 = 4 block RAMs)

## Tile memory

Enough memory for 64x64 tiles.  (64x64x6 / 4096) = 6 block RAMs

## Sprite memory

8 16x16 sprites @ 16 colours   (1 block RAM per sprite = 8 block RAMs)

# Operation

The following will be mapped into IO memory:

- block RAMs (for texture/tile/sprite definitions)
- 16 colour palette selection registers
- scroll x/y offset registers + x/y step factors (used for scale/rotate of screen image)

- The video logic should probably generate an IRQ on frame/line end too.
