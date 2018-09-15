//
// audio peripheral for game soc
//

// TODO everything

`ifndef __GAME_SOC_AUDIO__
`define __GAME_SOC_AUDIO__

`include "clock_divider.vh"
`include "pdm_dac.vh"
`include "eight_bit_exponential_decay_lookup.vh"
`include "filter_svf_pipelined.vh"


module audio
(
  input resetn,
  input clk,
	input iomem_valid,
	output reg iomem_ready,
	input [3:0]  iomem_wstrb,
	input [31:0] iomem_addr,
	input [31:0] iomem_wdata,
	output reg [31:0] iomem_rdata,
  output audio_out);

  ////////////////////////////////////////////////////////////////////
  // Configurable parameters
  ////////////////////////////////////////////////////////////////////
  localparam SAMPLE_BITS = 12;
  localparam FREQ_BITS = 24;
  localparam PULSEWIDTH_BITS = 12;
  localparam ACCUMULATOR_BITS = 24;
  localparam NUM_VOICES = 3;
  localparam SAMPLE_CLK_FREQ = 44100;

	reg [31:0] config_register_bank [0:15];

  wire [3:0] bank_addr = iomem_addr[5:2];

  // some starting values for things
  localparam default_Fc = 0.2;
  localparam default_Q = 1.4;
  localparam signed [17:0] DEFAULT_FILTER_FREQ = $rtoi(2*$sin(3.141592*default_Fc/SAMPLE_CLK_FREQ) * 131072.0);
  localparam signed [17:0] DEFAULT_FILTER_Q = $rtoi((1.0 / default_Q) * 65536.0);

  ///////////////////////////////////////////////////////////////////
  //    Handle PicoSoC writing to the config register bank
  ///////////////////////////////////////////////////////////////////
	always @(posedge clk) begin
		if (!resetn) begin
      config_register_bank[2] <= 0;  // disable voice 1
      config_register_bank[6] <= 0;  // disable voice 2
      config_register_bank[10] <= 0; // disable voice 3

      // set some "sane" values for the filter too
      config_register_bank[12] <= { {6{1'b0}}, DEFAULT_FILTER_FREQ, {6{1'b0}}, DEFAULT_FILTER_Q };
		end else begin
			iomem_ready <= 0;
			if (iomem_valid && !iomem_ready) begin
				iomem_ready <= 1;
				iomem_rdata <= config_register_bank[bank_addr];
				if (iomem_wstrb[0]) config_register_bank[bank_addr][ 7: 0] <= iomem_wdata[ 7: 0];
				if (iomem_wstrb[1]) config_register_bank[bank_addr][15: 8] <= iomem_wdata[15: 8];
				if (iomem_wstrb[2]) config_register_bank[bank_addr][23:16] <= iomem_wdata[23:16];
				if (iomem_wstrb[3]) config_register_bank[bank_addr][31:24] <= iomem_wdata[31:24];
			end
		end
	end

  /////////////////////////////////////////////////////////////////////
  // Clocks :: Sample clock @ 44100Hz and accumulator clock @ 1MHz
  /////////////////////////////////////////////////////////////////////
  wire sclk, aclk;
  clock_divider #(.DIVISOR(16)) accumulator_clock(.cin(clk), .cout(aclk));
  clock_divider #(.DIVISOR($rtoi(16000000/SAMPLE_CLK_FREQ))) sample_clock(.cin(clk), .cout(sclk));

  /////////////////////////////////////////////////////////////////////
  // AUDIO Output
  /////////////////////////////////////////////////////////////////////
  reg signed [SAMPLE_BITS+2:0] tmp_mixed_voices_to_be_filtered;
  reg signed [SAMPLE_BITS+2:0] tmp_mixed_non_filtered_voices;
  reg signed [SAMPLE_BITS+2:0] mixed_voices_to_be_filtered;
  reg signed [SAMPLE_BITS+2:0] mixed_non_filtered_voices;

  // filter output goes in here
  wire signed [SAMPLE_BITS-1:0] filter_output;

  // Output samples are mixed into here
//  wire signed [SAMPLE_BITS+1:0] mixed_final_voices = (filter_output + mixed_non_filtered_voices)>>>1;
  wire signed [SAMPLE_BITS+2:0] mixed_final_voices = (mixed_voices_to_be_filtered + mixed_non_filtered_voices)>>>1;

/*
  filter_svf_pipelined filter(
    .clk(aclk),
    .sample_clk(sclk),
    .filter_select(config_register_bank[13][1:0]),
    .in(mixed_voices_to_be_filtered[13:2]),
    .out(filter_output),
    .F({config_register_bank[12][31:16],2'b0}),
    .Q1({config_register_bank[12][15:0],2'b0})
  );
*/

  localparam signed MAX_SAMPLE_VALUE = (2**(SAMPLE_BITS-1))-1;
  localparam signed MIN_SAMPLE_VALUE = -(2**(SAMPLE_BITS-1));

  // and final_mix samples are pulse-density modulated for output
  // (output DAC has extra resolution due to mixing)
  pdm_dac #(.SAMPLE_BITS(SAMPLE_BITS+2)) audio_dac(.din(mixed_final_voices[13:0]), .dout(audio_out), .clk(clk));

  ////////////////////////////////////////////////////////////////////
  // Voice accumulators
  ////////////////////////////////////////////////////////////////////
  reg[ACCUMULATOR_BITS-1:0] accumulator[0:NUM_VOICES-1];
  reg[ACCUMULATOR_BITS-1:0] prev_accumulator[0:NUM_VOICES-1];
  reg [22:0] lfsr[0:NUM_VOICES-1];

  initial begin
    lfsr[0] <= 23'b01101110010010000101011;
    lfsr[1] <= 23'b01101110010010000101011;
    lfsr[2] <= 23'b01101110010010000101011;
  end

  reg[2:0] state;
  wire [1:0] voice_num = (state<3)?state:0;
  wire[3:0] reg_index = voice_num<<2; // offset into config register file for current voice (4 words per voice)


  reg prev_aclk;      // previous accumulator (1MHz) clock value

  localparam REG_FREQ = 4'd0;
  localparam REG_PULSEWIDTH = 4'd1;
  localparam REG_WAVEPARAMS = 4'd2;
  localparam REG_GATE = 4'd3;

  wire [23:0] voice_accumulator = accumulator[voice_num];
  wire [23:0] prev_voice_accumulator = prev_accumulator[voice_num];
  wire [31:0] voice_wave_params = config_register_bank[reg_index+REG_WAVEPARAMS];
  wire [22:0] voice_lfsr = lfsr[voice_num];
  wire [23:0] voice_freq_increment = config_register_bank[reg_index+REG_FREQ][23:0];
  wire [11:0] voice_pulse_width = config_register_bank[reg_index+REG_PULSEWIDTH][11:0];
  wire voice_wave_select_noise = voice_wave_params[19];
  wire voice_wave_select_pulse = voice_wave_params[18];
  wire voice_wave_select_sawtooth = voice_wave_params[17];
  wire voice_wave_select_triangle = voice_wave_params[16];

  wire[2:0] voice_envelope_state = envelope_state[voice_num];
  wire [3:0] voice_attack = voice_wave_params[15:12];
  wire [3:0] voice_decay = voice_wave_params[11:8];
  wire [3:0] voice_sustain = voice_wave_params[7:4];
  wire [3:0] voice_release = voice_wave_params[3:0];
  wire voice_enable = voice_wave_params[27];
  wire voice_sync_enable = voice_wave_params[28];
  wire voice_filter_enable = voice_wave_params[26];
  wire voice_test = voice_wave_params[25];
  wire voice_ring_modulation_enable = voice_wave_params[24];
  wire[1:0] sync_source_for_voice = (voice_num == 0) ? 2 : (voice_num == 1) ? 0 : 1;
  wire voice_sync_source = config_register_bank[14][1<<sync_source_for_voice];
  wire voice_ringmod_source = config_register_bank[14][32'h00000100<<voice_sync_source];
  wire voice_gate = config_register_bank[reg_index+REG_GATE][0];
  reg prev_voice_gate[0:NUM_VOICES-1];



  ///////////////////////////////////////////////////////////////////
  // tone generation functions
  ///////////////////////////////////////////////////////////////////
  localparam MAX_SCALE = (2**SAMPLE_BITS) - 1;

  wire tone_triangle_invert_wave = (voice_ring_modulation_enable && voice_ringmod_source)
                                  || (!voice_ring_modulation_enable && voice_accumulator[ACCUMULATOR_BITS-1]);
  wire [SAMPLE_BITS-1:0] tone_triangle_unsigned_data  = tone_triangle_invert_wave ? ~voice_accumulator[ACCUMULATOR_BITS-2 -: SAMPLE_BITS]
                            : voice_accumulator[ACCUMULATOR_BITS-2 -: SAMPLE_BITS];
  wire [SAMPLE_BITS-1:0] tone_sawtooth_unsigned_data = voice_accumulator[ACCUMULATOR_BITS-1 -: SAMPLE_BITS];
  wire [SAMPLE_BITS-1:0] tone_noise_unsigned_data = { voice_lfsr[22], voice_lfsr[20], voice_lfsr[16], voice_lfsr[13], voice_lfsr[11], voice_lfsr[7], voice_lfsr[4], voice_lfsr[2], {(SAMPLE_BITS-8){1'b0}} };
  wire [SAMPLE_BITS-1:0] tone_pulse_unsigned_data = (voice_accumulator[ACCUMULATOR_BITS-1 -: PULSEWIDTH_BITS] <= voice_pulse_width) ? MAX_SCALE : 0;


  ///////////////////////////////////////////////////////////////////
  // ADSR envelope generator
  ///////////////////////////////////////////////////////////////////

    localparam ENVELOPE_ACCUMULATOR_BITS = 26;
    localparam  ENVELOPE_ACCUMULATOR_SIZE = 2**ENVELOPE_ACCUMULATOR_BITS;
    localparam  ENVELOPE_ACCUMULATOR_MAX  = ENVELOPE_ACCUMULATOR_SIZE-1;

    reg [ENVELOPE_ACCUMULATOR_BITS:0] envelope_accumulator[0:NUM_VOICES-1];
    reg [7:0] envelope_amplitude[0:NUM_VOICES-1];

    // calculate the amount to add to the accumulator each clock cycle to
    // achieve a full-scale value in n number of seconds. (n can be fractional seconds)
    `define CALCULATE_PHASE_INCREMENT(n) $rtoi(ENVELOPE_ACCUMULATOR_SIZE / (n * 1000000))


    localparam STATE_ENVELOPE_IDLE    = 3'd0;
    localparam STATE_ENVELOPE_ATTACK  = 3'd1;
    localparam STATE_ENVELOPE_DECAY   = 3'd2;
    localparam STATE_ENVELOPE_SUSTAIN = 3'd3;
    localparam STATE_ENVELOPE_RELEASE = 3'd4;

    reg[2:0] envelope_state[0:NUM_VOICES-1];

    initial begin
      envelope_state[0] <= STATE_ENVELOPE_IDLE;
      envelope_state[1] <= STATE_ENVELOPE_IDLE;
      envelope_state[2] <= STATE_ENVELOPE_IDLE;
      envelope_amplitude[0] <= 0;
      envelope_amplitude[1] <= 0;
      envelope_amplitude[2] <= 0;
      envelope_accumulator[0] <= 0;
      envelope_accumulator[1] <= 0;
      envelope_accumulator[2] <= 0;
    end


    wire [16:0] attack_inc, decay_rel_inc;
    assign attack_inc = (voice_attack == 4'b0000) ? `CALCULATE_PHASE_INCREMENT(0.002) :
                        (voice_attack == 4'b0001) ? `CALCULATE_PHASE_INCREMENT(0.008) :
                        (voice_attack == 4'b0010) ? `CALCULATE_PHASE_INCREMENT(0.016) :
                        (voice_attack == 4'b0011) ? `CALCULATE_PHASE_INCREMENT(0.024) :
                        (voice_attack == 4'b0100) ? `CALCULATE_PHASE_INCREMENT(0.038) :
                        (voice_attack == 4'b0101) ? `CALCULATE_PHASE_INCREMENT(0.056) :
                        (voice_attack == 4'b0110) ? `CALCULATE_PHASE_INCREMENT(0.068) :
                        (voice_attack == 4'b0111) ? `CALCULATE_PHASE_INCREMENT(0.080) :
                        (voice_attack == 4'b1000) ? `CALCULATE_PHASE_INCREMENT(0.100) :
                        (voice_attack == 4'b1001) ? `CALCULATE_PHASE_INCREMENT(0.250) :
                        (voice_attack == 4'b1010) ? `CALCULATE_PHASE_INCREMENT(0.500) :
                        (voice_attack == 4'b1011) ? `CALCULATE_PHASE_INCREMENT(0.800) :
                        (voice_attack == 4'b1100) ? `CALCULATE_PHASE_INCREMENT(1.000) :
                        (voice_attack == 4'b1101) ? `CALCULATE_PHASE_INCREMENT(3.000) :
                        (voice_attack == 4'b1110) ? `CALCULATE_PHASE_INCREMENT(5.000) :
                                                    `CALCULATE_PHASE_INCREMENT(8.000) ;


    wire [3:0] voice_dec_rel = (voice_envelope_state == STATE_ENVELOPE_RELEASE ? voice_release : voice_decay);

    assign decay_rel_inc = (voice_dec_rel == 4'b0000) ? `CALCULATE_PHASE_INCREMENT(0.006) :
                           (voice_dec_rel == 4'b0001) ? `CALCULATE_PHASE_INCREMENT(0.024) :
                        (voice_dec_rel == 4'b0010) ? `CALCULATE_PHASE_INCREMENT(0.048) :
                        (voice_dec_rel == 4'b0011) ? `CALCULATE_PHASE_INCREMENT(0.072) :
                        (voice_dec_rel == 4'b0100) ? `CALCULATE_PHASE_INCREMENT(0.114) :
                        (voice_dec_rel == 4'b0101) ? `CALCULATE_PHASE_INCREMENT(0.168) :
                        (voice_dec_rel == 4'b0110) ? `CALCULATE_PHASE_INCREMENT(0.204) :
                        (voice_dec_rel == 4'b0111) ? `CALCULATE_PHASE_INCREMENT(0.240) :
                        (voice_dec_rel == 4'b1000) ? `CALCULATE_PHASE_INCREMENT(0.300) :
                        (voice_dec_rel == 4'b1001) ? `CALCULATE_PHASE_INCREMENT(0.750) :
                        (voice_dec_rel == 4'b1010) ? `CALCULATE_PHASE_INCREMENT(1.500) :
                        (voice_dec_rel == 4'b1011) ? `CALCULATE_PHASE_INCREMENT(2.400) :
                        (voice_dec_rel == 4'b1100) ? `CALCULATE_PHASE_INCREMENT(3.000) :
                        (voice_dec_rel == 4'b1101) ? `CALCULATE_PHASE_INCREMENT(9.000) :
                        (voice_dec_rel == 4'b1110) ? `CALCULATE_PHASE_INCREMENT(15.000) :
                                                    `CALCULATE_PHASE_INCREMENT(24.000) ;

    wire [7:0] sustain_volume = { voice_sustain, voice_sustain };  // 4-bit volume expanded into an 8-bit value
    wire [7:0] sustain_gap = 255 - sustain_volume;     // gap between sustain-volume and full-scale (255)
                               // used to calculate decay scale factor

    wire [7:0] exp_out;  // exponential decay mapping of accumulator output; used for decay and release cycles
    eight_bit_exponential_decay_lookup exp_lookup(.din(voice_envelope_accumulator[ACCUMULATOR_BITS-1 -: 8]), .dout(exp_out));

    wire [3:0] sg = {voice_envelope_state,voice_gate};
    wire[2:0] next_envelope_state;
    assign next_envelope_state =
              (sg == {STATE_ENVELOPE_ATTACK,  1'b0}) ? STATE_ENVELOPE_RELEASE
            : (sg == {STATE_ENVELOPE_ATTACK,  1'b1}) ? STATE_ENVELOPE_DECAY
            : (sg == {STATE_ENVELOPE_DECAY,   1'b0}) ? STATE_ENVELOPE_RELEASE
            : (sg == {STATE_ENVELOPE_DECAY,   1'b1}) ? STATE_ENVELOPE_SUSTAIN
            : (sg == {STATE_ENVELOPE_SUSTAIN, 1'b0}) ? STATE_ENVELOPE_RELEASE
            : (sg == {STATE_ENVELOPE_SUSTAIN, 1'b1}) ? STATE_ENVELOPE_SUSTAIN
            : (sg == {STATE_ENVELOPE_RELEASE, 1'b0}) ? STATE_ENVELOPE_IDLE
            : (sg == {STATE_ENVELOPE_RELEASE, 1'b1}) ? STATE_ENVELOPE_ATTACK
            : (sg == {STATE_ENVELOPE_IDLE,    1'b0}) ? STATE_ENVELOPE_IDLE
            : (sg == {STATE_ENVELOPE_IDLE,    1'b1}) ? STATE_ENVELOPE_ATTACK
            : STATE_ENVELOPE_IDLE;

    wire [ENVELOPE_ACCUMULATOR_BITS:0] voice_envelope_accumulator = envelope_accumulator[voice_num];
    wire [7:0] voice_envelope_amplitude = envelope_amplitude[voice_num];

    wire voice_envelope_overflow = voice_envelope_accumulator[ENVELOPE_ACCUMULATOR_BITS];

    wire signed [20:0] voice_envelope_amplitude_signed = { 12'b0, voice_envelope_amplitude }; // amplitude with extra MSB (0)

    // produce audio samples
    wire signed [SAMPLE_BITS-1:0] unscaled_voice_output =
                        (12'b1000_0000_0000 ^  // invert MSB to convert unsigned to signed
                            (12'b1111_1111_1111
                                & (voice_wave_select_noise ? tone_noise_unsigned_data : 12'd4095)
                                & (voice_wave_select_pulse ? tone_pulse_unsigned_data : 12'd4095)
                                & (voice_wave_select_sawtooth ? tone_sawtooth_unsigned_data : 12'd4095)
                                & (voice_wave_select_triangle ? tone_triangle_unsigned_data : 12'd4095)
                              )
                          );

    wire signed [SAMPLE_BITS-1:0] scaled_voice_output = (unscaled_voice_output * voice_envelope_amplitude_signed) >>> 8;

  ///////////////////////////////////////////////////////////////////
  // handle voice logic
  ///////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    prev_aclk <= aclk;

    // accumulator clock has gone high; reset state machine
    if (!prev_aclk && aclk) begin
      state <= 3'd0;
    end

    /////////////////////////////////////////////////////////////////
    // state machine iterates through each voice, one-at-a-time,
    // increments the accumulators, noise LFSR's, and generates
    // waveforms
    /////////////////////////////////////////////////////////////////
    case (state)
      /////////////////////////////////////////////////////////////
      // state 0,1,2 => processing voice 1, 2, 3
      /////////////////////////////////////////////////////////////
      3'd0,
      3'd1,
      3'd2: begin
        // increment the accumulator and handle oscillator sync & test
        if ((voice_sync_enable && voice_sync_source) || voice_test) begin
          prev_accumulator[voice_num] <= 0;
          accumulator[voice_num] <= 0;
        end else begin
          prev_accumulator[voice_num] <= accumulator[voice_num];
          accumulator[voice_num] <= accumulator[voice_num] + voice_freq_increment;
        end

        // update noise LFSR
        if (accumulator[voice_num][19]) begin
          lfsr[voice_num] <= { lfsr[voice_num][21:0], lfsr[voice_num][22] ^ lfsr[voice_num][17] };
        end

        if (voice_test) begin  // reset the LFSR to it's initial position
          lfsr[voice_num] <=  23'b01101110010010000101011;
        end

        // produce sync output
        config_register_bank[14][1<<voice_num] <= (!(prev_voice_accumulator & 24'h800000) && (voice_accumulator & 24'h800000));

        // produce ring-mod output
        config_register_bank[14][256<<voice_num] <= voice_accumulator[ACCUMULATOR_BITS-1];

        // scale samples by envelope generator, and add them either to the filter chain, or non-filter chain
        if (voice_enable) begin
          if (voice_filter_enable) begin
            tmp_mixed_voices_to_be_filtered <= tmp_mixed_voices_to_be_filtered + scaled_voice_output;
          end else begin
            tmp_mixed_non_filtered_voices <= tmp_mixed_non_filtered_voices + scaled_voice_output;
          end
        end

        ///////////////////////////////////////////////////////////////////////
        // Envelope generator logic
        ///////////////////////////////////////////////////////////////////////

              // check for gate low->high transitions (straight to attack phase)
              prev_voice_gate[voice_num] <= voice_gate;
              if (voice_gate && !prev_voice_gate[voice_num])
                begin
                  envelope_accumulator[voice_num] <= 0;
                  envelope_state[voice_num] <= STATE_ENVELOPE_ATTACK;
                end

              // otherwise, flow through ADSR state machine
              if (voice_envelope_overflow)
                begin
                  envelope_accumulator[voice_num] <= 0;
                  envelope_state[voice_num] <= next_envelope_state;
                end
              else begin
                case (voice_envelope_state)
                  STATE_ENVELOPE_ATTACK:
                    begin
                      envelope_accumulator[voice_num] <= envelope_accumulator[voice_num] + attack_inc;
                      envelope_amplitude[voice_num] <= envelope_accumulator[voice_num][ACCUMULATOR_BITS-1 -: 8];
                    end
                  STATE_ENVELOPE_DECAY:
                    begin
                      envelope_accumulator[voice_num] <= envelope_accumulator[voice_num] + decay_rel_inc;
                      envelope_amplitude[voice_num] <= ({exp_out * sustain_gap} >> 8) + sustain_volume;
                    end
                  STATE_ENVELOPE_SUSTAIN:
                  begin
                    envelope_amplitude[voice_num] <= sustain_volume;
                    envelope_state[voice_num] <= next_envelope_state;
                  end
                  STATE_ENVELOPE_RELEASE:
                    begin
                      envelope_accumulator[voice_num] <= envelope_accumulator[voice_num] + decay_rel_inc;
                      envelope_amplitude[voice_num] <= ({exp_out * sustain_volume} >> 8);
                      if (voice_gate) begin
                        envelope_amplitude[voice_num] <= 0;
                        envelope_accumulator[voice_num] <= 0;
                        envelope_state[voice_num] <= next_envelope_state;
                      end
                    end
                  default:
                    begin
                      envelope_amplitude[voice_num] <= 0;
                      envelope_accumulator[voice_num] <= 0;
                      envelope_state[voice_num] <= next_envelope_state;
                    end
                endcase
            end


        // move on to the next voice
        state <= state + 1;
      end
      3'd3: begin
        // latch sample value out
        mixed_voices_to_be_filtered <= tmp_mixed_voices_to_be_filtered;
        mixed_non_filtered_voices <= tmp_mixed_non_filtered_voices;
        tmp_mixed_voices_to_be_filtered <= 0;
        tmp_mixed_non_filtered_voices <= 0;
        state <= 3'd4;
      end
    endcase


  end




endmodule

`endif
