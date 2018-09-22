module ili9341 (
           input            clk_16MHz,
           output reg       nreset,
           output reg       cmd_data, // 1 => Data, 0 => Command
           output           ncs, // Chip select (low enable)
           output reg       write_edge, // Write signal on rising edge
           output           read_edge, // Read signal on rising edge
           output           backlight,
           output reg [7:0] dout,

           input            reset_cursor,
           input [15:0]     pix_data,
           input            pix_clk,
           output           busy
           );


   parameter  clk_freq = 16000000;
   parameter  tx_clk_freq = 16000000;
   localparam tx_clk_div = (clk_freq / tx_clk_freq) - 1;

   localparam sec_per_tick = (1.0 / tx_clk_freq);
   localparam ms120 = 0.120 / sec_per_tick;
   localparam ms50  = 0.050 / sec_per_tick;
   localparam ms5   = 0.005 / sec_per_tick;

   assign backlight = 1;
   assign ncs = 0;
   assign read_edge = 1;

   // Init Sequence Data (based upon
   // https://github.com/thekroko/ili9341_fpga/blob/master/tft_ili9341.sv)
   localparam INIT_SEQ_LEN = 86;
   reg [10:0] init_seq_counter = 11'b0;
   reg [8:0] INIT_SEQ [0:INIT_SEQ_LEN-1];

   localparam CURSOR_SEQ_LEN = 11;
   reg [10:0] cursor_seq_counter = 11'b0;
   reg [8:0] CURSOR_SEQ [0:CURSOR_SEQ_LEN-1];

   initial begin
      // Turn off Display
      INIT_SEQ[0] <= {1'b0, 8'h28};

      // Init (??)
      INIT_SEQ[1] <= {1'b0, 8'hCF};
      INIT_SEQ[2] <= {1'b1, 8'h00};
      INIT_SEQ[3] <= {1'b1, 8'hC3};
      INIT_SEQ[4] <= {1'b1, 8'h30};

      INIT_SEQ[5] <= {1'b0, 8'hED};
      INIT_SEQ[6] <= {1'b1, 8'h64};
      INIT_SEQ[7] <= {1'b1, 8'h03};
      INIT_SEQ[8] <= {1'b1, 8'h12};
      INIT_SEQ[9] <= {1'b1, 8'h81};

      INIT_SEQ[10] <= {1'b0, 8'hE8};
      INIT_SEQ[11] <= {1'b1, 8'h85};
      INIT_SEQ[12] <= {1'b1, 8'h10};
      INIT_SEQ[13] <= {1'b1, 8'h79};

      INIT_SEQ[14] <= {1'b0, 8'hCB};
      INIT_SEQ[15] <= {1'b1, 8'h39};
      INIT_SEQ[16] <= {1'b1, 8'h2C};
      INIT_SEQ[17] <= {1'b1, 8'h00};
      INIT_SEQ[18] <= {1'b1, 8'h34};
      INIT_SEQ[19] <= {1'b1, 8'h02};

      INIT_SEQ[20] <= {1'b0, 8'hF7};
      INIT_SEQ[21] <= {1'b1, 8'h20};

      INIT_SEQ[22] <= {1'b0, 8'hEA};
      INIT_SEQ[23] <= {1'b1, 8'h00};
      INIT_SEQ[24] <= {1'b1, 8'h00};

      // Power Control
      INIT_SEQ[25] <= {1'b0, 8'hC0};
      INIT_SEQ[26] <= {1'b1, 8'h22};

      INIT_SEQ[27] <= {1'b0, 8'hC1};
      INIT_SEQ[28] <= {1'b1, 8'h11};

      // VCOM control
      INIT_SEQ[29] <= {1'b0, 8'hC5};
      INIT_SEQ[30] <= {1'b1, 8'h3d};
      INIT_SEQ[31] <= {1'b1, 8'h20};

      // VCOM contrl 2
      INIT_SEQ[32] <= {1'b0, 8'hC7};
      INIT_SEQ[33] <= {1'b1, 8'hAA};

      // Memory Access Control
      INIT_SEQ[34] <= {1'b0, 8'h36};
      INIT_SEQ[35] <= {1'b1, 8'h08};
      INIT_SEQ[36] <= {1'b0, 8'h3A};
      INIT_SEQ[37] <= {1'b1, 8'h55};

      // Frame Rate
      INIT_SEQ[38] <= {1'b0, 8'hB1};
      INIT_SEQ[39] <= {1'b1, 8'h00};
      INIT_SEQ[40] <= {1'b1, 8'h13};

      // Display function control
      INIT_SEQ[41] <= {1'b0, 8'hB6};
      INIT_SEQ[42] <= {1'b1, 8'h0A};
      INIT_SEQ[43] <= {1'b1, 8'hA2};

      INIT_SEQ[44] <= {1'b0, 8'hF6};
      INIT_SEQ[45] <= {1'b1, 8'h01};
      INIT_SEQ[46] <= {1'b1, 8'h30};

      // Gamma function disable
      INIT_SEQ[47] <= {1'b0, 8'hF2};
      INIT_SEQ[48] <= {1'b1, 8'h00};

      // Gamma curve selected
      INIT_SEQ[49] <= {1'b0, 8'h26};
      INIT_SEQ[50] <= {1'b1, 8'h01};

      //Set Gamma
      INIT_SEQ[51] <= {1'b0, 8'hE0};
      INIT_SEQ[52] <= {1'b1, 8'h0F};
      INIT_SEQ[53] <= {1'b1, 8'h3F};
      INIT_SEQ[54] <= {1'b1, 8'h2F};
      INIT_SEQ[55] <= {1'b1, 8'h0C};
      INIT_SEQ[56] <= {1'b1, 8'h10};
      INIT_SEQ[57] <= {1'b1, 8'h0A};
      INIT_SEQ[58] <= {1'b1, 8'h53};
      INIT_SEQ[59] <= {1'b1, 8'hD5};
      INIT_SEQ[60] <= {1'b1, 8'h40};
      INIT_SEQ[61] <= {1'b1, 8'h0A};
      INIT_SEQ[62] <= {1'b1, 8'h13};
      INIT_SEQ[63] <= {1'b1, 8'h03};
      INIT_SEQ[64] <= {1'b1, 8'h08};
      INIT_SEQ[65] <= {1'b1, 8'h03};
      INIT_SEQ[66] <= {1'b1, 8'h00};

      //Set Gamma
      INIT_SEQ[67] <= {1'b0, 8'hE1};
      INIT_SEQ[68] <= {1'b1, 8'h00};
      INIT_SEQ[69] <= {1'b1, 8'h00};
      INIT_SEQ[70] <= {1'b1, 8'h10};
      INIT_SEQ[71] <= {1'b1, 8'h03};
      INIT_SEQ[72] <= {1'b1, 8'h0F};
      INIT_SEQ[73] <= {1'b1, 8'h05};
      INIT_SEQ[74] <= {1'b1, 8'h2C};
      INIT_SEQ[75] <= {1'b1, 8'hA2};
      INIT_SEQ[76] <= {1'b1, 8'h3F};
      INIT_SEQ[77] <= {1'b1, 8'h05};
      INIT_SEQ[78] <= {1'b1, 8'h0E};
      INIT_SEQ[79] <= {1'b1, 8'h0C};
      INIT_SEQ[80] <= {1'b1, 8'h37};
      INIT_SEQ[81] <= {1'b1, 8'h3C};
      INIT_SEQ[82] <= {1'b1, 8'h0F};

      // Brightness
      INIT_SEQ[83] <= {1'b0, 8'h51};
      INIT_SEQ[84] <= {1'b1, 8'hFF};

      INIT_SEQ[85] <= {1'b0, 8'h29}; // Enable Display

      // Column Address
      CURSOR_SEQ[0] <= {1'b0, 8'h2A};
      CURSOR_SEQ[1] <= {1'b1, 8'h00};
      CURSOR_SEQ[2] <= {1'b1, 8'h00};
      CURSOR_SEQ[3] <= {1'b1, 8'h00};
      CURSOR_SEQ[4] <= {1'b1, 8'hEF};

      // Page Address
      CURSOR_SEQ[5] <= {1'b0, 8'h2B};
      CURSOR_SEQ[6] <= {1'b1, 8'h00};
      CURSOR_SEQ[7] <= {1'b1, 8'h00};
      CURSOR_SEQ[8] <= {1'b1, 8'h01};
      CURSOR_SEQ[9] <= {1'b1, 8'h3F};

      CURSOR_SEQ[10] <= {1'b0, 8'h2C}; // Start Memory-Write

      dout <= 0;
      write_edge <= 0;
      cmd_data <= 0;
   end

   parameter RESET = 5'd0;
   parameter NOT_RESET = 5'd1;
   parameter WAKEUP = 5'd2;
   parameter INIT = 5'd3;
   parameter READY = 5'd4;
   parameter CURSOR = 5'd5;

   reg [2:0] state = RESET;

   parameter TX_IDLE = 1'd0;
   parameter TX_DATA_READY = 1'd1;
   reg       tx_state = TX_IDLE;

   reg [19:0] delay_ticks = 0;

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
                 dout <= 8'h11;
                 tx_state <= TX_DATA_READY;
                 state <= INIT;
                 delay_ticks <= ms5;
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
                 state <= CURSOR;
                 delay_ticks <= ms50;
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
   end

endmodule

