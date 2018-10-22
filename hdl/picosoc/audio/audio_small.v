//
// a very cut-down audio peripheral - wave generators + volume control
//

module audio_small
(
  input resetn,
  input clk,
	input iomem_valid,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
  output audio_out);

  ////////////////////////////////////////////////////////////////////
  // Configurable parameters
  ////////////////////////////////////////////////////////////////////
  localparam SAMPLE_BITS = 6;
  localparam FREQ_BITS = 24;
  localparam PULSEWIDTH_BITS = 4;
  localparam ACCUMULATOR_BITS = 20;
  localparam NUM_VOICES = 4;

	reg [31:0] config_register_bank [0:16];
  wire [4:0] bank_addr = iomem_addr[6:2];

  ///////////////////////////////////////////////////////////////////
  //    Handle PicoSoC writing to the config register bank
  ///////////////////////////////////////////////////////////////////
	always @(posedge clk) begin
    if (iomem_valid) begin
      if (iomem_wstrb[0]) config_register_bank[bank_addr][ 7: 0] <= iomem_wdata[ 7: 0];
      if (iomem_wstrb[1]) config_register_bank[bank_addr][15: 8] <= iomem_wdata[15: 8];
      if (iomem_wstrb[2]) config_register_bank[bank_addr][23:16] <= iomem_wdata[23:16];
      if (iomem_wstrb[3]) config_register_bank[bank_addr][31:24] <= iomem_wdata[31:24];
    end
    if (!resetn) begin
      config_register_bank[16]<=8'h0f;  /* global volume = full scale by default for backwards compatibility */
    end
	end

  /////////////////////////////////////////////////////////////////////
  // Clocks :: Sample clock @ 44100Hz and accumulator clock @ 1MHz
  /////////////////////////////////////////////////////////////////////
  wire aclk;
  clock_divider #(.DIVISOR(256)) accumulator_clock(.cin(clk), .cout(aclk));


  /////////////////////////////////////////////////////////////////////
  // AUDIO Output
  /////////////////////////////////////////////////////////////////////
  reg signed [SAMPLE_BITS+1:0] tmp_mixed_voices;
  reg signed [SAMPLE_BITS+1:0] mixed_voices;

  // and final_mix samples are pulse-density modulated for output
  // (output DAC has extra resolution due to mixing)
  pdm_dac #(.SAMPLE_BITS(SAMPLE_BITS+2)) audio_dac(.din(mixed_voices), .dout(audio_out), .clk(clk));

  ////////////////////////////////////////////////////////////////////
  // Voice accumulators
  ////////////////////////////////////////////////////////////////////
  reg[ACCUMULATOR_BITS-1:0] accumulator[0:NUM_VOICES-1];
  reg[ACCUMULATOR_BITS-1:0] prev_accumulator[0:NUM_VOICES-1];
  reg [22:0] lfsr[0:NUM_VOICES-1];

  reg[5:0] voice_pipeline_state;
  reg [1:0] voice_num;
  wire[3:0] reg_index = voice_num<<2; // offset into config register file for current voice (4 words per voice)

  reg prev_aclk;      // previous accumulator (1MHz) clock value

  localparam REG_FREQ = 4'd0;
  localparam REG_PULSEWIDTH = 4'd1;
  localparam REG_WAVEPARAMS = 4'd2;
  localparam REG_VOLUME     = 4'd3;

  wire [23:0] voice_accumulator = accumulator[voice_num];
  wire [31:0] voice_wave_params = config_register_bank[reg_index+REG_WAVEPARAMS];
  wire [22:0] voice_lfsr = lfsr[voice_num];
  wire [23:0] voice_freq_increment = config_register_bank[reg_index+REG_FREQ][23:0];
  wire [3:0] voice_pulse_width = config_register_bank[reg_index+REG_PULSEWIDTH][3:0];

  wire signed [4:0] voice_volume =  |(voice_pipeline_state[3:0])?  /* if we are currently mixing voices, choose channel volume */
                                        {1'b0,config_register_bank[reg_index+REG_VOLUME][7:4]}
                                      : {1'b0,config_register_bank[16][7:4]}; /* otherwise, select global volume */

  wire voice_wave_select_noise = voice_wave_params[19];
  wire voice_wave_select_pulse = voice_wave_params[18];
  wire voice_wave_select_sawtooth = voice_wave_params[17];
  wire voice_wave_select_triangle = voice_wave_params[16];
  //wire voice_ring_modulation_enable = voice_wave_params[24];

  //reg [3:0] ringmod_bit;
  //wire[1:0] sync_source_for_voice = (voice_num == 0) ? 3 : (voice_num == 1) ? 0 : (voice_num == 2) ? 1 : 2;
  //wire voice_ringmod_source = ringmod_bit[1<<sync_source_for_voice];


  ///////////////////////////////////////////////////////////////////
  // tone generation functions
  ///////////////////////////////////////////////////////////////////
  localparam MAX_SCALE = (2**SAMPLE_BITS) - 1;

  wire tone_triangle_invert_wave = /* (voice_ring_modulation_enable && voice_ringmod_source)
                                  || */ (voice_accumulator[ACCUMULATOR_BITS-1]);
  wire [SAMPLE_BITS-1:0] tone_triangle_unsigned_data  = tone_triangle_invert_wave ? ~voice_accumulator[ACCUMULATOR_BITS-2 -: SAMPLE_BITS]
                            : voice_accumulator[ACCUMULATOR_BITS-2 -: SAMPLE_BITS];
  wire [SAMPLE_BITS-1:0] tone_sawtooth_unsigned_data = voice_accumulator[ACCUMULATOR_BITS-1 -: SAMPLE_BITS];
//  wire [SAMPLE_BITS-1:0] tone_noise_unsigned_data = { voice_lfsr[22], voice_lfsr[20], voice_lfsr[16], voice_lfsr[13], voice_lfsr[11], voice_lfsr[7], voice_lfsr[4], voice_lfsr[2] };
  wire [SAMPLE_BITS-1:0] tone_noise_unsigned_data = { voice_lfsr[22], voice_lfsr[20], voice_lfsr[16], voice_lfsr[13], voice_lfsr[11], voice_lfsr[7] };
  wire [SAMPLE_BITS-1:0] tone_pulse_unsigned_data = (voice_accumulator[ACCUMULATOR_BITS-1 -: PULSEWIDTH_BITS] <= voice_pulse_width) ? MAX_SCALE : 0;

    /////////////////////////////////////////////////////////////////////////////
    // produce audio samples
    /////////////////////////////////////////////////////////////////////////////
    // this monstrocity may require some explaination..
    // because we need to re-use the channel-scale multiplier for doing global
    // volume scaling too, this mux selects the appropriate source to apply to
    // the scaler.
    // If we're mixing a normal voice (0-3), then take the logical AND of
    //  each of the enabled waveforms, and XOR it with 0x80000 to turn it
    //  into a signed value.
    // If we've mixed all of the normal voices already, then select the
    //  "mixed" data so that this can be further scaled by the global volume.
    //  (see the voice_volume wire definition above, and the scaled_voice_output
    //   definition below for more info).
    wire signed [SAMPLE_BITS-1:0] unscaled_voice_output =
       |(voice_pipeline_state[3:0])
       ?
        (8'b10_0000 ^  // invert MSB to convert unsigned to signed
            (8'b11_1111
                & (voice_wave_select_noise ? tone_noise_unsigned_data : 6'd63)
                & (voice_wave_select_pulse ? tone_pulse_unsigned_data : 6'd63)
                & (voice_wave_select_sawtooth ? tone_sawtooth_unsigned_data : 6'd63)
                & (voice_wave_select_triangle ? tone_triangle_unsigned_data : 6'd63)
              )
          )
        : tmp_mixed_voices[SAMPLE_BITS+1:2];  /* if voice_pipeline has mixed all voices, select output sample so it can be scaled by global volume */

  wire signed [SAMPLE_BITS+5-1:0] scaled_voice_output = (unscaled_voice_output * voice_volume) >>> 4;

  ///////////////////////////////////////////////////////////////////
  // handle voice logic
  ///////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    prev_aclk <= aclk;

    voice_pipeline_state <= 6'b100000;

    /////////////////////////////////////////////////////////////////
    // state machine iterates through each voice, one-at-a-time,
    // increments the accumulators, noise LFSR's, and generates
    // waveforms
    /////////////////////////////////////////////////////////////////
    (* full_case, parallel_case *)
    case (1'b1)
      /////////////////////////////////////////////////////////////
      // state 0,1,2,3 => processing voice 1, 2, 3, 4
      /////////////////////////////////////////////////////////////
      voice_pipeline_state[0],
      voice_pipeline_state[1],
      voice_pipeline_state[2],
      voice_pipeline_state[3]: begin
        // increment the accumulator
        prev_accumulator[voice_num] <= accumulator[voice_num];
        accumulator[voice_num] <= accumulator[voice_num] + voice_freq_increment;

        // update noise LFSR
        if (accumulator[voice_num][19] && !prev_accumulator[voice_num][19]) begin
          lfsr[voice_num] <= { lfsr[voice_num][21:0], lfsr[voice_num][22] ^ lfsr[voice_num][17] };
        end

        // produce ring-mod output
        //ringmod_bit[1<<voice_num] <= voice_accumulator[ACCUMULATOR_BITS-1];

        // scale samples by envelope generator, and add them either to the filter chain, or non-filter chain
        tmp_mixed_voices <= tmp_mixed_voices + scaled_voice_output[SAMPLE_BITS+1:0];

        // move on to the next voice
        voice_num <= voice_num + 1;
        voice_pipeline_state <= voice_pipeline_state << 1;
      end
      voice_pipeline_state[4]: begin
        // latch sample value out
        mixed_voices <= { scaled_voice_output[SAMPLE_BITS-1:0],2'b0 };   /* scaled voice output now contains (global_volume * tmp_mixed_voices) / 256 */
        voice_pipeline_state <= 6'b100000;  // move to "idle" state until next aclk
      end
      voice_pipeline_state[5]: begin
        // accumulator clock has gone high; reset state machine
        if (!prev_aclk && aclk) begin
          voice_pipeline_state <= 6'b000001;
          tmp_mixed_voices <= 0;
          voice_num <= 0;
        end
      end
    endcase

    if (!resetn) begin
      voice_num <= 0;
      voice_pipeline_state <= 6'b100000;
      lfsr[0] <= 23'b01101110010010000101011;
      lfsr[1] <= 23'b01101110010010000101011;
      lfsr[2] <= 23'b01101110010010000101011;
      lfsr[3] <= 23'b01101110010010000101011;
    end
  end

endmodule
