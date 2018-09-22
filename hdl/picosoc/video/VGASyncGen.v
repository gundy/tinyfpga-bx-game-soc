//////////////////////////////////////////////////////////////////////////////////
// Company: Ridotech
// Engineer: Juan Manuel Rico
//
// Create Date:    25/03/2018
// Module Name:    VGASyncGen
// Description:    Basic control for 640x480@72Hz VGA signal.
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created for Roland Coeurjoly (RCoeurjoly) in 640x480@85Hz.
// Revision 0.02 - Change for 640x480@60Hz.
// Revision 0.03 - Solved some mistakes.
// Revision 0.04 - Change for 640x480@72Hz and output signals 'activevideo' and 'px_clk'.
// Revision 0.05 - Eliminate 'color_px' and 'red_monitor', green_monitor', 'blue_monitor' (Sergio Cuenca).
// Revision 0.06 - Create 'FDivider' parameter for PLL.
// Revision 0.07 - Attempt to create 320x240 resolution at standard TinyFPGA clock of 16MHz (ie. remove PLL)
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module VGASyncGen (
  input wire       clk,           // Input clock (12Mhz or 16Mhz)
  output wire      hsync,         // Horizontal sync out
  output wire      vsync,         // Vertical sync out
  output reg [9:0] x_px,          // X position for actual pixel.
  output reg [9:0] y_px,          // Y position for actual pixel.
  output wire      activevideo    // Video is actived.
);

    /////////////////////////////////////////////////////////////

    // Video structure constants.
    //
    //   Horizontal Dots          640 (activeHvideo)
    //   Horiz. Sync Polarity     NEG
    //   A (hpixels)              Scanline time
    //   B (hpulse)               Sync pulse lenght
    //   C (hbp)                  Back porch
    //   D (activeHvideo)         Active video time
    //   E (hfp)                  Front porch
    //              ______________________            ______________
    //   __________|        VIDEO         |__________| VIDEO (next line)
    //   |-E-| |-C-|----------D-----------|-E-|
    //   ____   ______________________________   ___________________
    //       |_|                              |_|
    //       |B|
    //       |---------------A----------------|
    //
    // (Same structure for vertical signals).
    //

    // shaving 6 pixels off standard timings to adjust for 25 vs 25.175 clock

    // 320x240 (640x480) @ 75Hz -- based on timings from here:
    // http://tinyvga.com/vga-timing/640x480@75Hz
    // horizontal parameters halved, and adjusted slightly to account
    // for 31.5/32Mhz difference

    // based on the link above, total horizontal pixels are 840 with a 31.5MHz
    // clock.  Our clock is 32MHz equivalent, so we need 853.333 pixels.
    // Except, everything is divided by two.  So we need about 427 pixels per line.
    // Basically, we need to find an extra 7 pixel times to pad the line spacing out.
    // I've added the timing to hfp + hbp.
    parameter activeHvideo = 320;    // Number of horizontal pixels.
    parameter hfp = 14;   // 8        // Horizontal front porch length.
    parameter hpulse = 32;           // Hsync pulse length.
    parameter hbp = 61;  // 60       // Horizontal blank (back porch) length.

    parameter activeVvideo =  480;              // Number of vertical lines.
    parameter vfp = 1;                          // Vertical front porch length.
    parameter vpulse = 3;                       // Vsync pulse length.
    parameter vbp = 16;                         // Vertical back porch length.
    parameter blackH = hfp + hpulse + hbp;      // Hide pixels in one line.
    parameter blackV = vfp + vpulse + vbp;      // Hide lines in one frame.
    parameter hpixels = blackH + activeHvideo;  // Total horizontal pixels.
    parameter vlines = blackV + activeVvideo;   // Total lines.

    // Registers for storing the horizontal & vertical counters.
    reg [9:0] hc;
    reg [9:0] vc;

    // Initial values.
    initial
    begin
      x_px <= 0;
      y_px <= 0;
      hc <= 0;
      vc <= 0;
    end

    // Counting pixels.
    always @(posedge clk)
    begin
        // Keep counting until the end of the line.
        if (hc < hpixels - 1)
            hc <= hc + 1;
        else
        // When we hit the end of the line, reset the horizontal
        // counter and increment the vertical counter.
        // If vertical counter is at the end of the frame, then
        // reset that one too.
        begin
            hc <= 0;
            if (vc < vlines - 1)
               vc <= vc + 1;
            else
               vc <= 0;
        end
     end

    // Generate horizontal and vertical sync pulses (active low) and active video.
    assign hsync = (hc >= hfp && hc < hfp + hpulse) ? 1'b0 : 1'b1;
    assign vsync = (vc >= vfp && vc < vfp + vpulse) ? 1'b0 : 1'b1;
    assign activevideo = (hc >= blackH) && (vc >= blackV) ? 1'b1 : 1'b0; //&& (hc < blackH + activeHvideo) && (vc < blackV + activeVvideo) ? 1'b1 : 1'b0;
//    assign endframe = (hc == hpixels-1 && vc == vlines-1) ? 1'b1 : 1'b0 ;

    // Generate new pixel position.
    always @(*)
    begin
        // First check if we are within vertical active video range.
        if (activevideo)
        begin
            x_px <= hc - blackH;
            y_px <= vc - blackV;
        end
        else
        // We are outside active video range so initial position it's ok.
        begin
            x_px <= 0;
            y_px <= 0;
        end
     end

endmodule
