
module sprite(
  input [31:0] configuration,
  input [8:0] screen_xpos,
  input [8:0] screen_ypos,
  output in_sprite_bounding_box,
  output [13:0] sprite_mem_addr    /* index into sprite memory of current sprite pixel (if sprite_data_valid is asserted) */
);

  /////////////////////////////////////////////////////////////////
  // Sprite configuration register unpacking
  /////////////////////////////////////////////////////////////////
  // | 31-30 | 29     | 28-26   |     25-20      | 19-10 | 9:0  |
  // | N/A   | enable | colour  | 0-64 sprite #  | xpos  | ypos |
  /////////////////////////////////////////////////////////////////

  wire [9:0] sprite_ypos    = configuration[ 9: 0];
  wire [9:0] sprite_xpos    = configuration[19:10];
  wire [9:0] sprite_end_xpos = sprite_xpos+16;
  wire [9:0] sprite_end_ypos = sprite_ypos+16;
  wire [5:0] sprite_mem_ofs = configuration[25:20];
  wire sprite_enable        = configuration[   29];

  assign in_sprite_bounding_box =  sprite_enable && (
                                   ((screen_xpos>=sprite_xpos) && (screen_xpos<sprite_end_xpos))
                                && ((screen_ypos>=sprite_ypos) && (screen_ypos<sprite_end_ypos))
                            );

  assign sprite_mem_addr = in_sprite_bounding_box
                          ? {sprite_mem_ofs, screen_ypos[3:0]-sprite_ypos[3:0], screen_xpos[3:0]-sprite_xpos[3:0]}
                          : 14'h000;

endmodule
