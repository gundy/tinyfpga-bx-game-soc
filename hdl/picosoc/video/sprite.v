
module sprite(
  input [31:0] configuration,
  input [8:0] screen_xpos,
  input [8:0] screen_ypos,
  output in_sprite_bounding_box,
  output [12:0] sprite_mem_addr    /* index into sprite memory of current sprite pixel (if sprite_data_valid is asserted) */
);

  /////////////////////////////////////////////////////////////////
  // Sprite configuration register unpacking
  /////////////////////////////////////////////////////////////////
  // | 31   |  30   | 29    | 28     | 27-24   |     23-18      | 17-9 | 8:0  |
  // | N/A  | flipx | flipy | enable | palette | 0-64 sprite #  | xpos  | ypos |
  /////////////////////////////////////////////////////////////////

  wire [8:0] sprite_ypos    = configuration[ 8: 0];
  wire [8:0] sprite_xpos    = configuration[17:9];
  wire [8:0] sprite_end_xpos = sprite_xpos+16;
  wire [8:0] sprite_end_ypos = sprite_ypos+16;
  wire [5:0] sprite_mem_ofs = configuration[23:18];
  wire sprite_enable        = configuration[   28];
  wire flipy = configuration[29];
  wire flipx = configuration[30];

  assign in_sprite_bounding_box =  sprite_enable && (
                                   ((screen_xpos>=sprite_xpos) && (screen_xpos<sprite_end_xpos))
                                && ((screen_ypos>=sprite_ypos) && (screen_ypos<sprite_end_ypos))
                            );

  wire[3:0] yp = flipy ? ~sprite_ypos[3:0] : sprite_ypos[3:0];
  wire[3:0] xp = flipx ? ~sprite_xpos[3:0] : sprite_xpos[3:0];

  assign sprite_mem_addr = in_sprite_bounding_box
                          ? {sprite_mem_ofs[4:0], screen_ypos[3:0]-yp, screen_xpos[3:0]-xp}
                          : 14'h000;

endmodule
