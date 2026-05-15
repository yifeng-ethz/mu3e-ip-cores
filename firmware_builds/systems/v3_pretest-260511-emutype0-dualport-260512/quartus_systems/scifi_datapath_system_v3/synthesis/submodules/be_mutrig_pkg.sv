// be_mutrig_pkg.sv
// MuTRiG back-end constants, types, and hit packing helpers
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add the back-end MuTRiG package split from legacy shared constants.

package be_mutrig_pkg;

    localparam int N_CHANNELS           = 32;
    localparam int CHANNEL_WIDTH        = 5;
    localparam int N_GROUPS             = 4;
    localparam int N_CHAN_PER_GROUP     = 8;
    localparam int MAX_EMU_LANES        = 8;
    localparam int CLUSTER_LANE_WIDTH   = 4;
    localparam int GLOBAL_CHANNEL_WIDTH = 8;
    localparam int FRAME_INTERVAL_LONG  = 1550;
    localparam int FRAME_INTERVAL_SHORT = 910;
    localparam int TCC_WIDTH            = 15;
    localparam logic [14:0] LFSR15_INIT = 15'h0001;
    localparam int MUTRIG_COARSE_STEPS_PER_CYCLE = 5;
    localparam logic [7:0] K28_0 = 8'h1C;
    localparam logic [7:0] K28_4 = 8'h9C;
    localparam logic [7:0] K28_5 = 8'hBC;
    localparam logic [2:0] TX_MODE_LONG     = 3'b000;
    localparam logic [2:0] TX_MODE_PRBS_1   = 3'b001;
    localparam logic [2:0] TX_MODE_PRBS_SAT = 3'b010;
    localparam logic [2:0] TX_MODE_SHORT    = 3'b100;
    localparam int HIT_LONG_WIDTH           = 48;
    localparam int HIT_SHORT_WIDTH          = 28;
    localparam int N_BYTES_LONG             = 6;
    localparam int N_BYTES_SHORT            = 3;
    localparam int RAW_FIFO_DEPTH           = 256;
    localparam int FIFO_ALMOST_FULL_MARGIN  = 3;
    localparam int RAW_FIFO_DEPTH_CONST           = RAW_FIFO_DEPTH;
    localparam int FIFO_ALMOST_FULL_MARGIN_CONST  = FIFO_ALMOST_FULL_MARGIN;
    localparam int TICKET_FIFO_DEPTH_CONST        = 8;
    localparam int FRAME_INTERVAL_LONG_CONST      = FRAME_INTERVAL_LONG;
    localparam int FRAME_INTERVAL_SHORT_CONST     = FRAME_INTERVAL_SHORT;
    localparam int MUTRIG_COARSE_STEPS_PER_CYCLE_CONST = MUTRIG_COARSE_STEPS_PER_CYCLE;
    localparam logic [14:0] LFSR15_INIT_CONST     = LFSR15_INIT;
    localparam logic [7:0] K28_0_CONST            = K28_0;
    localparam logic [7:0] K28_4_CONST            = K28_4;
    localparam logic [7:0] K28_5_CONST            = K28_5;

    typedef enum logic [1:0] {
        HIT_MODE_POISSON     = 2'b00,
        HIT_MODE_BURST       = 2'b01,
        HIT_MODE_POISSON_IID = 2'b10,
        HIT_MODE_PERIODIC    = 2'b11
    } hit_mode_t;

    function automatic logic prbs15_feedback(input logic [14:0] state);
        return ~(state[14] ^ state[13]);
    endfunction

    function automatic logic [14:0] prbs15_step(input logic [14:0] state);
        return {state[13:0], prbs15_feedback(state)};
    endfunction

    function automatic logic [14:0] prbs15_step_n(
        input logic [14:0] state,
        input int unsigned step_count
    );
        logic [14:0] state_value;

        state_value = state;
        for (int step_idx = 0; step_idx < step_count; step_idx++) begin
            state_value = prbs15_step(state_value);
        end
        return state_value;
    endfunction

    function automatic logic [47:0] pack_hit_long(
        input logic [4:0]  channel,
        input logic        t_badhit,
        input logic [14:0] tcc,
        input logic [4:0]  t_fine,
        input logic        e_badhit,
        input logic [14:0] ecc,
        input logic [4:0]  e_fine,
        input logic        e_flag
    );
        return {channel, t_badhit, tcc, t_fine, e_badhit, ecc, e_fine, e_flag};
    endfunction

    function automatic logic [27:0] pack_hit_short(
        input logic [4:0]  channel,
        input logic        e_badhit,
        input logic [14:0] tcc,
        input logic [4:0]  t_fine,
        input logic        e_flag
    );
        return {channel, e_badhit, tcc, t_fine, e_flag, 1'b0};
    endfunction

    function automatic logic [44:0] pack_hit_type0(
        input logic [47:0] hit_word,
        input logic [3:0]  asic_id
    );
        return {
            asic_id,
            hit_word[47:43],
            hit_word[41:27],
            hit_word[26:22],
            hit_word[20:6],
            hit_word[0]
        };
    endfunction

    function automatic logic [4:0] clamp_fine_with_jitter(
        input logic [4:0] anchor,
        input logic [2:0] pos_rnd,
        input logic [2:0] neg_rnd
    );
        int signed jitter_value;
        int signed fine_value;

        jitter_value = $signed({1'b0, pos_rnd}) - $signed({1'b0, neg_rnd});
        if (jitter_value > 4) begin
            jitter_value = 4;
        end else if (jitter_value < -4) begin
            jitter_value = -4;
        end

        fine_value = anchor + jitter_value;
        if (fine_value < 0) begin
            fine_value = 0;
        end else if (fine_value > 31) begin
            fine_value = 31;
        end
        return fine_value[4:0];
    endfunction

    function automatic logic [63:0] saturating_inc64(input logic [63:0] value);
        if (value == 64'hFFFF_FFFF_FFFF_FFFF) begin
            return value;
        end
        return value + 64'd1;
    endfunction

endpackage
