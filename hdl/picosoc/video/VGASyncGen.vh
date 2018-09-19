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
  output wire      activevideo,   // Video is actived.
  output wire      px_clk         // Pixel clock.
);

    // generated values for 640x480X60Hz, 25.175Mhz pixel clock (achieved 25MHz)
    // based on input clock 16MHz

    SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),		// DIVR =  0
      .DIVF(7'b0110001),	// DIVF = 49
      .DIVQ(3'b101),		// DIVQ =  5
      .FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
    ) pixel_clock_generator (
      .REFERENCECLK(clk),
      .PLLOUTCORE(px_clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
    );

    //////////////////////////////////////////////////////////////
    // https://arachnoid.com/modelines/  - 640x480 @ 60Hz
    //////////////////////////////////////////////////////////////
    // 21: [PIXEL FREQ]                :    25.263360
    //  1: [H PIXELS RND]              :   640.000000
    //  2: [V LINES RND]               :   480.000000
    // 14: [V FRAME RATE]              :    60.000000
    //  4: [TOP MARGIN (LINES)]        :     9.000000
    //  5: [BOT MARGIN (LINES)]        :     9.000000
    //  8: [V SYNC+BP]                 :    17.000000
    //  9: [V BACK PORCH]              :    14.000000
    // 15: [LEFT MARGIN (PIXELS)]      :     8.000000
    // 16: [RIGHT MARGIN (PIXELS)]     :     8.000000
    // 17: [TOTAL ACTIVE PIXELS]       :   656.000000
    // 19: [H BLANK (PIXELS)]          :   160.000000
    // 17: [H SYNC (PIXELS)]           :    64.000000
    // 18: [H FRONT PORCH (PIXELS)]    :    16.000000
    // 36: [V ODD FRONT PORCH(LINES)]  :     1.000000

    // 20: [TOTAL PIXELS]              :   816.000000
    //  3: [V FIELD RATE RQD]          :    60.000000
    //  6: [INTERLACE]                 :     0.000000
    //  7: [H PERIOD EST]              :    32.297929
    // 10: [TOTAL V LINES]             :   516.000000
    // 11: [V FIELD RATE EST]          :    60.003367
    // 12: [H PERIOD]                  :    32.299742
    // 13: [V FIELD RATE]              :    60.000000
    // 18: [IDEAL DUTY CYCLE]          :    20.310078
    // 22: [H FREQ]                    :    30.960000

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
    parameter activeHvideo = 640;               // Number of horizontal pixels.
    parameter hfp = 10;                         // Horizontal front porch length.
    parameter hpulse = 96;                      // Hsync pulse length.
    parameter hbp = 54;                         // Horizontal blank (back porch) length.

    parameter activeVvideo =  480;              // Number of vertical lines.
    parameter vfp = 2;                          // Vertical front porch length.
    parameter vpulse = 2;                       // Vsync pulse length.
    parameter vbp = 41;                         // Vertical back porch length.
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
    always @(posedge px_clk)
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
