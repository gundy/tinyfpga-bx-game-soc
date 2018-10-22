module ili9341 (
           input            resetn,
           input            clk_16MHz,
           output reg       nreset,
           output reg       cmd_data, // 1 => Data, 0 => Command
           output reg       write_edge, // Write signal on rising edge
           output           read_edge, // Read signal on rising edge
           output reg [7:0] dout,

           input            reset_cursor,
           input [15:0]     pix_data,
           input            pix_clk,
           output           busy
           );

  localparam CD_DATA = 1'b1;
  localparam CD_CMD  = 1'b0;

   parameter  clk_freq = 16000000;
   parameter  tx_clk_freq = 16000000;
   localparam tx_clk_div = (clk_freq / tx_clk_freq) - 1;

   localparam sec_per_tick = (1.0 / tx_clk_freq);
   localparam ms120 = $rtoi(0.120 / sec_per_tick);
   localparam ms50  = $rtoi(0.050 / sec_per_tick);
   localparam ms5   = $rtoi(0.005 / sec_per_tick);
   localparam ms500 = $rtoi(0.500 / sec_per_tick);

   // Init Sequence Data (based upon
   // https://github.com/thekroko/ili9341_fpga/blob/master/tft_ili9341.sv)
   localparam INIT_SEQ_LEN = 20;
   reg [4:0] init_seq_counter = 11'b0;
   reg [8:0] INIT_SEQ [0:INIT_SEQ_LEN-1];

   localparam CURSOR_SEQ_LEN = 11;
   reg [4:0] cursor_seq_counter = 11'b0;
   reg [8:0] CURSOR_SEQ [0:CURSOR_SEQ_LEN-1];

   localparam ILI9341_SOFTRESET      = 8'h01;
   localparam ILI9341_SLEEPIN        = 8'h10;
   localparam ILI9341_SLEEPOUT       = 8'h11;
   localparam ILI9341_NORMALDISP     = 8'h13;
   localparam ILI9341_INVERTOFF      = 8'h20;
   localparam ILI9341_INVERTON       = 8'h21;
   localparam ILI9341_GAMMASET       = 8'h26;
   localparam ILI9341_DISPLAYOFF     = 8'h28;
   localparam ILI9341_DISPLAYON      = 8'h29;
   localparam ILI9341_COLADDRSET     = 8'h2A;
   localparam ILI9341_PAGEADDRSET    = 8'h2B;
   localparam ILI9341_MEMORYWRITE    = 8'h2C;
   localparam ILI9341_PIXELFORMAT    = 8'h3A;
   localparam ILI9341_FRAMECONTROL   = 8'hB1;
   localparam ILI9341_DISPLAYFUNC    = 8'hB6;
   localparam ILI9341_ENTRYMODE      = 8'hB7;
   localparam ILI9341_POWERCONTROL1  = 8'hC0;
   localparam ILI9341_POWERCONTROL2  = 8'hC1;
   localparam ILI9341_VCOMCONTROL1   = 8'hC5;
   localparam ILI9341_VCOMCONTROL2   = 8'hC7;
   localparam ILI9341_MEMCONTROL     = 8'h36;
   localparam ILI9341_MADCTL         = 8'h36;

   // below 3-bits control MCU -> LCD memory read/write direction
   localparam ILI9341_MADCTL_MY  = 8'h80;  // row address order
   localparam ILI9341_MADCTL_MX  = 8'h40;  // column address order
   localparam ILI9341_MADCTL_MV  = 8'h20;  // row/column exchange

   localparam ILI9341_MADCTL_ML  = 8'h10;  // vertical refresh order (flip vertical) (set = bottom-to-top)
   localparam ILI9341_MADCTL_RGB = 8'h00;  // RGB bit ordering
   localparam ILI9341_MADCTL_BGR = 8'h08;  // BGR bit ordering
   localparam ILI9341_MADCTL_MH  = 8'h04;  // horizontal refresh order (flip horizontal)

   initial begin
      INIT_SEQ[0] <= { CD_CMD, ILI9341_DISPLAYOFF };

      // Set the GVDD level, which is a reference level for the VCOM level and the grayscale voltage level.
      INIT_SEQ[1] <= { CD_CMD, ILI9341_POWERCONTROL1 };
      INIT_SEQ[2] <= { CD_DATA, 8'h23 };  // 4.6v GVDD

      //Sets the factor used in the step-up circuits.
      INIT_SEQ[3] <= { CD_CMD, ILI9341_POWERCONTROL2 };
      INIT_SEQ[4] <= { CD_DATA, 8'h10 };  // 0 -> AVDD  = VCI*2, VGH = VCI*7, VGL = -VCI*4

      // this value was previously being set to 3D20, values below are from adafruit lib
      // Set VMH and VML voltages
      INIT_SEQ[5]  <= { CD_CMD, ILI9341_VCOMCONTROL1 };
      INIT_SEQ[6]  <= { CD_DATA, 8'h2b };  // VMH = 3.775v   (original values were 4.225 and -1.7v)
      INIT_SEQ[7] <= { CD_DATA, 8'h2b };  // VML = -1.425v

      //  Set the VCOM offset voltage.
      INIT_SEQ[8] <= { CD_CMD, ILI9341_VCOMCONTROL2 };
      INIT_SEQ[9] <= { CD_DATA, 8'hc0 };  // C0 = no offset - ie. VCOMH = VMH, VCOML = VML

      // see register descriptions above
      INIT_SEQ[10] <= { CD_CMD, ILI9341_MEMCONTROL };
      INIT_SEQ[11] <= { CD_DATA,  ILI9341_MADCTL_BGR | ILI9341_MADCTL_MV };  // BGR ordering,

      INIT_SEQ[12] <= { CD_CMD, ILI9341_PIXELFORMAT };
      INIT_SEQ[13] <= { CD_DATA, 8'h55 };  // 16 bits-per-pixel both MCU and display

      // frame rate control
      INIT_SEQ[14] <= { CD_CMD, ILI9341_FRAMECONTROL };
      INIT_SEQ[15] <= { CD_DATA, 8'h00 };  // divider = 00 = fosc (ie. no divider) - used when "normal mode"
      INIT_SEQ[16] <= { CD_DATA, 8'h1B };  // RTNA = 1B = 70 fps (default)

      INIT_SEQ[17] <= { CD_CMD,  ILI9341_ENTRYMODE };
      INIT_SEQ[18] <= { CD_DATA, 8'h07 };  // deep standby off, disable low voltage detection, display output gates 0-320 active in normal mode

      INIT_SEQ[19] <= { CD_CMD, ILI9341_SLEEPOUT };

      // Column Address
      // This command is used to define area of frame memory
      // where MCU can access. This command makes no change
      // on the other  driver  status.  The  values  of
      // SC[15:0]  and  EC[15:0]  are  referred  when  RAMWR
      // command  comes.  Each value represents one column
      // line in the Frame Memory.
      // SC = start column, EC = end column
      CURSOR_SEQ[0] <= {CD_CMD, ILI9341_COLADDRSET };
      CURSOR_SEQ[1] <= {CD_DATA, 8'h00}; // SC[15:8]
      CURSOR_SEQ[2] <= {CD_DATA, 8'h00}; // SC[7:0]   // SC = 0
      CURSOR_SEQ[3] <= {CD_DATA, 8'h01}; // EC[15:8]
      CURSOR_SEQ[4] <= {CD_DATA, 8'h3F}; // EC[7:0]   // 13F = 319

      // Page Address
      // This command is used to define area of frame memory
      // where MCU can access. This command makes no change on the
      // other  driver  status.  The  values  of  SP  [15:0]  and  EP
      //  [15:0]  are  referred  when  RAMWR  command  comes.  Each
      // value represents one Page line in the Frame Memory.
      CURSOR_SEQ[5] <= {CD_CMD, ILI9341_PAGEADDRSET };
      CURSOR_SEQ[6] <= {CD_DATA, 8'h00};
      CURSOR_SEQ[7] <= {CD_DATA, 8'h00};  // start page = 0
      CURSOR_SEQ[8] <= {CD_DATA, 8'h00};
      CURSOR_SEQ[9] <= {CD_DATA, 8'hEF};  // end page = EF = 239 ;

      CURSOR_SEQ[10] <= {CD_CMD, ILI9341_MEMORYWRITE}; // Start Memory-Write



      dout <= 0;
      write_edge <= 0;
      cmd_data <= 0;
   end

   parameter RESET = 5'd0;
   parameter NOT_RESET = 5'd1;
   parameter WAKEUP = 5'd2;
   parameter INIT = 5'd3;
   parameter INIT_FIN = 5'd4;
   parameter READY = 5'd5;
   parameter CURSOR = 5'd6;

   reg [2:0] state = RESET;

   parameter TX_IDLE = 1'd0;
   parameter TX_DATA_READY = 1'd1;
   reg       tx_state = TX_IDLE;

   reg [23:0] delay_ticks = 0;

   parameter PIX_IDLE = 1'd0;
   parameter PIX_SEND = 1'd1;

   reg [1:0]  pix_state = PIX_IDLE;

   assign busy = (state != READY) || (pix_state != PIX_IDLE);

   always @(posedge clk_16MHz) begin

     case (tx_state)
        TX_IDLE : begin
           write_edge <= 0;
        end
        TX_DATA_READY : begin
           write_edge <= 1;
           tx_state <= TX_IDLE;
        end
     endcase

     if (delay_ticks != 0) begin
        delay_ticks <= delay_ticks - 1;
     end else begin

        case (state)
           RESET : begin
              nreset <= 0;
              dout <= 0;
              write_edge <= 0;
              cmd_data <= 0;
              delay_ticks <= ms5;

              state <= NOT_RESET;
           end

           NOT_RESET : begin
              nreset <= 1;
              state <= WAKEUP;
              delay_ticks <= ms120;
           end

           WAKEUP : begin
              if (tx_state == TX_IDLE) begin
                 cmd_data <= 0;
                 dout <= 8'h01;  // SOFTWARE RESET
                 tx_state <= TX_DATA_READY;
                 init_seq_counter <= 0;
                 state <= INIT;
                 delay_ticks <= ms50;
              end
           end

           INIT: begin
              if (init_seq_counter < INIT_SEQ_LEN) begin
                 if (tx_state == TX_IDLE) begin
                    cmd_data <= INIT_SEQ[init_seq_counter][8];
                    dout <= INIT_SEQ[init_seq_counter][7:0];

                    init_seq_counter <= init_seq_counter + 1;
                    tx_state <= TX_DATA_READY;
                 end
              end else begin
                 state <= INIT_FIN;
                 delay_ticks <= ms120;
              end
           end

           // turn display on
           // wait 500 ms
           INIT_FIN: begin
              if (tx_state == TX_IDLE) begin
                cmd_data <= 0;
                dout <= ILI9341_DISPLAYON;
                tx_state <= TX_DATA_READY;
                state <= CURSOR;
                delay_ticks <= ms500;
              end
           end

           CURSOR: begin
              if (cursor_seq_counter < CURSOR_SEQ_LEN) begin
                 if (tx_state == TX_IDLE) begin
                    cmd_data <= CURSOR_SEQ[cursor_seq_counter][8];
                    dout <= CURSOR_SEQ[cursor_seq_counter][7:0];

                    cursor_seq_counter <= cursor_seq_counter + 1;
                    tx_state <= TX_DATA_READY;
                 end
              end else begin
                 state <= READY;
                 cursor_seq_counter <= 0;
              end
           end

           READY : begin

              case (pix_state)

                PIX_IDLE : begin
                   if (reset_cursor == 1) begin
                      state <= CURSOR;
                   end else if (pix_clk == 1 && tx_state == TX_IDLE) begin
                      cmd_data <= 1;
                      dout <= pix_data[15:8];
                      tx_state <= TX_DATA_READY;
                      pix_state <= PIX_SEND;
                   end
                end

                PIX_SEND: begin
                   if (tx_state == TX_IDLE) begin
                      cmd_data <= 1;
                      dout <= pix_data[7:0];
                      tx_state <= TX_DATA_READY;
                      pix_state <= PIX_IDLE;
                   end
                end
              endcase
           end
        endcase
     end

     if (!resetn) state <= RESET;

   end

endmodule
