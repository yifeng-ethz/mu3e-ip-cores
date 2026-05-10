// emulator_mutrig.sv
// Packaged MuTRiG emulator top with central trigger frontend and per-lane backend.
// Author: Yifeng Wang
// Version : 26.3.0
// Date    : 20260506
// Change  : Add DEBUG_LEVEL FIFO observability and per-hit metadata sidebands.

module emulator_mutrig
#(
    parameter int LANE_COUNT = 8,
    parameter bit BYTE_STREAM_ENABLE = 0,
    parameter logic [31:0] IP_UID = 32'h454D5554,
    parameter int VERSION_MAJOR = 26,
    parameter int VERSION_MINOR = 3,
    parameter int VERSION_PATCH = 0,
    parameter int BUILD = 506,
    parameter int VERSION_DATE = 20260506,
    parameter logic [31:0] VERSION_GIT = 32'h0,
    parameter logic [31:0] INSTANCE_ID = 32'h0,
    parameter logic [3:0] ASIC_ID_BASE_DEFAULT = 4'd0,
    parameter int DEBUG_LEVEL = 0
) (
    input  logic i_clk,
    input  logic i_rst,

    input  logic [8:0] asi_ctrl_data,
    input  logic       asi_ctrl_valid,
    output logic       asi_ctrl_ready,

    input  logic coe_inject_pulse,

    input  logic [5:0]  avs_csr_address,
    input  logic        avs_csr_read,
    input  logic        avs_csr_write,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    output logic [LANE_COUNT-1:0][44:0] aso_hit_type0_data,
    output logic [LANE_COUNT-1:0]       aso_hit_type0_valid,
    output logic [LANE_COUNT-1:0]       aso_hit_type0_startofpacket,
    output logic [LANE_COUNT-1:0]       aso_hit_type0_endofpacket,
    output logic [LANE_COUNT-1:0]       aso_hit_type0_endofrun,
    output logic [LANE_COUNT-1:0][2:0]  aso_hit_type0_error,
    output logic [LANE_COUNT-1:0][3:0]  aso_hit_type0_channel,
    output logic [LANE_COUNT-1:0][15:0] coe_debug_fifo_fill_level,
    output logic [LANE_COUNT-1:0][63:0] aso_hit_debug_data,
    output logic [LANE_COUNT-1:0]       aso_hit_debug_valid,
    output logic [LANE_COUNT-1:0][3:0]  aso_hit_debug_channel,
    output logic [LANE_COUNT-1:0]       aso_hit_debug_startofpacket,
    output logic [LANE_COUNT-1:0]       aso_hit_debug_endofpacket,
    output logic [LANE_COUNT-1:0]       aso_hit_debug_endofrun,

    output logic [LANE_COUNT-1:0][8:0] aso_tx8b1k_data,
    output logic [LANE_COUNT-1:0]      aso_tx8b1k_valid,
    output logic [LANE_COUNT-1:0][2:0] aso_tx8b1k_error,
    output logic [LANE_COUNT-1:0][3:0] aso_tx8b1k_channel
);

    import frontend_ticket_bus_pkg::*;
    import be_mutrig_pkg::*;

    localparam int LANE_INDEX_WIDTH = (LANE_COUNT > 1) ? $clog2(LANE_COUNT) : 1;
    localparam int FRAME_COUNTER_WIDTH = 11;

    logic cfg_global_enable;
    logic cfg_hit_mode_sig;
    logic cfg_internal_sub_mode;
    logic cfg_cluster_geom_mode;
    logic cfg_hit_mode_bkg;
    logic cfg_short_mode;
    logic cfg_gen_idle;
    logic [2:0] cfg_tx_mode;
    logic cfg_enable_type0_stream;
    logic [15:0] cfg_hit_rate;
    logic [15:0] cfg_noise_rate;
    // GEOM_FIX dual-side bridge to legacy single-pair engine input.
    // The CSR exposes left/right halves with low/high/enable each;
    // the trigger engine (until its own dual-side refactor lands) still
    // takes one (low, high) pair. We synthesise that pair from the
    // currently-enabled side, defaulting to side A when both are set.
    // Per RTL_PLAN section 3, dual-side simultaneous launch is a
    // follow-up patch in the trigger engine.
    logic [6:0] cfg_geom_fix_left_low;
    logic [6:0] cfg_geom_fix_left_high;
    logic       cfg_geom_fix_left_enable;
    logic [6:0] cfg_geom_fix_right_low;
    logic [6:0] cfg_geom_fix_right_high;
    logic       cfg_geom_fix_right_enable;
    logic [7:0] cfg_hit_channel_low;
    logic [7:0] cfg_hit_channel_high;
    always_comb begin
        if (cfg_geom_fix_left_enable) begin
            cfg_hit_channel_low  = {1'b0, cfg_geom_fix_left_low};
            cfg_hit_channel_high = {1'b0, cfg_geom_fix_left_high};
        end else if (cfg_geom_fix_right_enable) begin
            cfg_hit_channel_low  = {1'b1, cfg_geom_fix_right_low};
            cfg_hit_channel_high = {1'b1, cfg_geom_fix_right_high};
        end else begin
            cfg_hit_channel_low  = 8'd0;
            cfg_hit_channel_high = 8'd0;
        end
    end
    logic [7:0] cfg_cluster_size_random;
    logic [1:0] cfg_mirror_mode;
    logic signed [7:0] cfg_mirror_offset;
    logic [7:0] cfg_random_center_seed;
    logic [31:0] cfg_prng_seed;
    logic [14:0] cfg_tcc_seed;
    logic [14:0] cfg_ecc_seed;
    logic [7:0] cfg_lane_enable_mask;
    logic [3:0] cfg_asic_id_base;
    logic [2:0] cfg_type0_error_inject_mask;
    logic [7:0] cfg_lane_error_target_mask;
    logic fire_inject_pulse_csr;
    logic csr_timebase_seed_load;

    logic run_generating;
    logic run_draining;
    logic emu_rst;
    logic frame_rst;
    logic inject_pulse;
    logic engine_inject_pulse;
    logic [8:0] ctrl_state_q;

    logic [14:0] tcc_lfsr;
    logic [14:0] ecc_lfsr;
    logic [FRAME_COUNTER_WIDTH-1:0] frame_interval_cnt;
    logic [FRAME_COUNTER_WIDTH-1:0] frame_interval_max;
    logic frame_start_req;

    logic sig_offer_valid;
    logic [LANE_INDEX_WIDTH-1:0] sig_offer_lane;
    frontend_ticket_t sig_offer_ticket;
    logic sig_offer_ready;
    logic [15:0] sig_ticket_overflow_count;
    logic [7:0] engine_busy_high_water;

    logic bkg_offer_valid;
    logic [LANE_INDEX_WIDTH-1:0] bkg_offer_lane;
    frontend_ticket_t bkg_offer_ticket;
    logic bkg_offer_ready;

    frontend_ticket_t fe_ticket_data [LANE_COUNT];
    logic [LANE_COUNT-1:0] fe_ticket_valid;
    logic [LANE_COUNT-1:0] fe_ticket_ready;

    logic [LANE_COUNT-1:0][47:0] lane_l2_rd_data;
    logic [LANE_COUNT-1:0] lane_l2_rd_valid;
    logic [LANE_COUNT-1:0] lane_l2_empty;
    logic [LANE_COUNT-1:0] lane_l2_full;
    logic [LANE_COUNT-1:0] lane_l2_almost_full;
    logic [LANE_COUNT-1:0][9:0] lane_l2_event_count;
    logic [LANE_COUNT-1:0][3:0] lane_ticket_fifo_level;
    logic [LANE_COUNT-1:0][9:0] lane_l2_fifo_level;
    logic [LANE_COUNT-1:0] lane_l2_rd_en;
    logic [LANE_COUNT-1:0] type0_l2_rd_en;
    logic [LANE_COUNT-1:0] frame_l2_rd_en;
    logic [LANE_COUNT-1:0] lane_frame_start;
    logic [7:0][63:0] lane_frame_count;
    logic [7:0][63:0] lane_hit_count;
    logic [7:0] lane_fifo_full_sticky;
    logic [7:0] lane_ticket_overflow_sticky;
    logic [7:0] clear_fifo_full_sticky;
    logic [7:0] clear_ticket_overflow_sticky;

    function automatic logic [3:0] lane_asic_id(input int lane_idx);
        logic [4:0] asic_sum;

        asic_sum = {1'b0, cfg_asic_id_base} + 5'(lane_idx);
        return {1'b0, asic_sum[2:0]};
    endfunction

    function automatic logic [14:0] prbs15_step(input logic [14:0] state);
        return {state[13:0], ~(state[14] ^ state[13])};
    endfunction

    function automatic logic [14:0] prbs15_step_n(input logic [14:0] state, input int step_count);
        logic [14:0] step_state;

        step_state = state;
        for (int step_idx = 0; step_idx < step_count; step_idx++) begin
            step_state = prbs15_step(step_state);
        end
        return step_state;
    endfunction

    assign frame_interval_max = cfg_short_mode ?
        FRAME_COUNTER_WIDTH'(be_mutrig_pkg::FRAME_INTERVAL_SHORT_CONST) :
        FRAME_COUNTER_WIDTH'(be_mutrig_pkg::FRAME_INTERVAL_LONG_CONST);
    assign csr_timebase_seed_load = avs_csr_write && (avs_csr_address == 6'h0F);
    assign engine_inject_pulse = cfg_global_enable && inject_pulse;

    frontend_csr #(
        .IP_UID       (IP_UID),
        .VERSION_MAJOR(VERSION_MAJOR),
        .VERSION_MINOR(VERSION_MINOR),
        .VERSION_PATCH(VERSION_PATCH),
        .BUILD        (BUILD),
        .VERSION_DATE (VERSION_DATE),
        .VERSION_GIT  (VERSION_GIT),
        .INSTANCE_ID  (INSTANCE_ID),
        .ASIC_ID_BASE_DEFAULT(ASIC_ID_BASE_DEFAULT)
    ) u_frontend_csr (
        .i_clk                                           (i_clk),
        .i_rst                                           (i_rst),
        .avs_csr_address                                 (avs_csr_address),
        .avs_csr_read                                    (avs_csr_read),
        .avs_csr_write                                   (avs_csr_write),
        .avs_csr_writedata                               (avs_csr_writedata),
        .avs_csr_readdata                                (avs_csr_readdata),
        .avs_csr_waitrequest                             (avs_csr_waitrequest),
        .cfg_central_global_enable                       (cfg_global_enable),
        .cfg_signal_hit_mode_sig                         (cfg_hit_mode_sig),
        .cfg_signal_internal_sub_mode                    (cfg_internal_sub_mode),
        .cfg_signal_cluster_geom_mode                    (cfg_cluster_geom_mode),
        .cfg_bkg_hit_mode_bkg                            (cfg_hit_mode_bkg),
        .cfg_mutrig_format_short_mode                    (cfg_short_mode),
        .cfg_mutrig_format_gen_idle                      (cfg_gen_idle),
        .cfg_mutrig_format_tx_mode                       (cfg_tx_mode),
        .cfg_mutrig_format_enable_type0_stream           (cfg_enable_type0_stream),
        .cfg_rates_hit_rate                              (cfg_hit_rate),
        .cfg_rates_noise_rate                            (cfg_noise_rate),
        .cfg_geom_fix_left_low                            (cfg_geom_fix_left_low),
        .cfg_geom_fix_left_high                           (cfg_geom_fix_left_high),
        .cfg_geom_fix_left_enable                         (cfg_geom_fix_left_enable),
        .cfg_geom_fix_right_low                           (cfg_geom_fix_right_low),
        .cfg_geom_fix_right_high                          (cfg_geom_fix_right_high),
        .cfg_geom_fix_right_enable                        (cfg_geom_fix_right_enable),
        .cfg_cluster_geom_random_cluster_size_random     (cfg_cluster_size_random),
        .cfg_cluster_geom_random_mirror_mode             (cfg_mirror_mode),
        .cfg_cluster_geom_random_mirror_offset           (cfg_mirror_offset),
        .cfg_cluster_geom_random_random_center_seed      (cfg_random_center_seed),
        .cfg_prng_seed                                   (cfg_prng_seed),
        .cfg_timebase_seed_tcc_seed                      (cfg_tcc_seed),
        .cfg_timebase_seed_ecc_seed                      (cfg_ecc_seed),
        .cfg_lane_enable_lane_enable_mask                (cfg_lane_enable_mask),
        .cfg_lane_enable_asic_id_base                    (cfg_asic_id_base),
        .cfg_error_inject_type0_error_inject_mask        (cfg_type0_error_inject_mask),
        .cfg_error_inject_lane_error_target_mask         (cfg_lane_error_target_mask),
        .fire_inject_pulse_csr                           (fire_inject_pulse_csr),
        .status_frame_count                              (lane_frame_count),
        .status_hit_count                                (lane_hit_count),
        .status_fifo_full_sticky                         (lane_fifo_full_sticky),
        .status_ticket_overflow_sticky                   (lane_ticket_overflow_sticky),
        .bank_ticket_overflow_count                      (sig_ticket_overflow_count),
        .bank_engine_busy_high_water                     (engine_busy_high_water),
        .clear_fifo_full_sticky                          (clear_fifo_full_sticky),
        .clear_ticket_overflow_sticky                    (clear_ticket_overflow_sticky)
    );

    frontend_run_ctl u_frontend_run_ctl (
        .i_clk                 (i_clk),
        .i_rst                 (i_rst),
        .asi_ctrl_data         (asi_ctrl_data),
        .asi_ctrl_valid        (asi_ctrl_valid),
        .asi_ctrl_ready        (asi_ctrl_ready),
        .coe_inject_pulse      (coe_inject_pulse),
        .fire_inject_pulse_csr (fire_inject_pulse_csr),
        .run_generating        (run_generating),
        .run_draining          (run_draining),
        .emu_rst               (emu_rst),
        .frame_rst             (frame_rst),
        .inject_pulse          (inject_pulse),
        .ctrl_state_q          (ctrl_state_q)
    );

    always_ff @(posedge i_clk) begin
        if (emu_rst || csr_timebase_seed_load) begin
            tcc_lfsr    <= (cfg_tcc_seed == 15'h0000) ? be_mutrig_pkg::LFSR15_INIT_CONST : cfg_tcc_seed;
            ecc_lfsr    <= (cfg_ecc_seed == 15'h0000) ? be_mutrig_pkg::LFSR15_INIT_CONST : cfg_ecc_seed;
        end else if (run_draining) begin
            tcc_lfsr    <= prbs15_step_n(tcc_lfsr, be_mutrig_pkg::MUTRIG_COARSE_STEPS_PER_CYCLE_CONST);
            ecc_lfsr    <= prbs15_step_n(ecc_lfsr, be_mutrig_pkg::MUTRIG_COARSE_STEPS_PER_CYCLE_CONST);
        end
    end

    always_ff @(posedge i_clk) begin
        if (frame_rst) begin
            frame_interval_cnt    <= frame_interval_max - FRAME_COUNTER_WIDTH'(1);
            frame_start_req       <= 1'b0;
        end else if (frame_interval_cnt == '0) begin
            frame_interval_cnt    <= frame_interval_max - FRAME_COUNTER_WIDTH'(1);
            frame_start_req       <= 1'b1;
        end else begin
            frame_interval_cnt    <= frame_interval_cnt - FRAME_COUNTER_WIDTH'(1);
            frame_start_req       <= 1'b0;
        end
    end

    frontend_trigger_engine #(
        .LANE_COUNT(LANE_COUNT)
    ) u_frontend_trigger_engine (
        .clk                    (i_clk),
        .rst                    (emu_rst),
        .cfg_global_enable      (cfg_global_enable),
        .run_generating         (run_generating),
        .inject_pulse           (engine_inject_pulse),
        .cfg_hit_mode_sig       (cfg_hit_mode_sig),
        .cfg_internal_sub_mode  (cfg_internal_sub_mode),
        .cfg_cluster_geom_mode  (cfg_cluster_geom_mode),
        .cfg_hit_rate           (cfg_hit_rate),
        .cfg_hit_channel_low    (cfg_hit_channel_low),
        .cfg_hit_channel_high   (cfg_hit_channel_high),
        .cfg_cluster_size_random(cfg_cluster_size_random),
        .cfg_mirror_mode        (cfg_mirror_mode),
        .cfg_mirror_offset      (cfg_mirror_offset),
        .cfg_random_center_seed (cfg_random_center_seed),
        .cfg_prng_seed          (cfg_prng_seed),
        .tcc_anchor             (tcc_lfsr),
        .ecc_anchor             (ecc_lfsr),
        .sig_offer_valid        (sig_offer_valid),
        .sig_offer_lane         (sig_offer_lane),
        .sig_offer_ticket       (sig_offer_ticket),
        .sig_offer_ready        (sig_offer_ready),
        .ticket_overflow_count  (sig_ticket_overflow_count),
        .engine_busy_high_water (engine_busy_high_water)
    );

    frontend_bkg_generator #(
        .LANE_COUNT(LANE_COUNT)
    ) u_frontend_bkg_generator (
        .clk                 (i_clk),
        .rst                 (emu_rst),
        .cfg_global_enable   (cfg_global_enable),
        .run_generating      (run_generating),
        .cfg_hit_mode_bkg    (cfg_hit_mode_bkg),
        .cfg_noise_rate      (cfg_noise_rate),
        .cfg_prng_seed       (cfg_prng_seed),
        .tcc_anchor          (tcc_lfsr),
        .ecc_anchor          (ecc_lfsr),
        .cfg_lane_enable_mask(cfg_lane_enable_mask[LANE_COUNT-1:0]),
        .bkg_offer_valid     (bkg_offer_valid),
        .bkg_offer_lane      (bkg_offer_lane),
        .bkg_offer_ticket    (bkg_offer_ticket),
        .bkg_offer_ready     (bkg_offer_ready)
    );

    frontend_ticket_distributor #(
        .LANE_COUNT(LANE_COUNT)
    ) u_frontend_ticket_distributor (
        .sig_offer_valid (sig_offer_valid),
        .sig_offer_lane  (sig_offer_lane),
        .sig_offer_ticket(sig_offer_ticket),
        .sig_offer_ready (sig_offer_ready),
        .bkg_offer_valid (bkg_offer_valid),
        .bkg_offer_lane  (bkg_offer_lane),
        .bkg_offer_ticket(bkg_offer_ticket),
        .bkg_offer_ready (bkg_offer_ready),
        .fe_ticket_data  (fe_ticket_data),
        .fe_ticket_valid (fe_ticket_valid),
        .fe_ticket_ready (fe_ticket_ready)
    );

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin : lane_gen
            localparam logic [31:0] LANE_SEED_XOR_CONST = 32'h0000_9E37 * (lane_idx + 1);
            logic lane_frame_allowed;
            logic [8:0] tx_data_int;
            logic tx_valid_int;
            logic frame_start_int;

            assign lane_frame_allowed = run_draining &&
                cfg_global_enable &&
                cfg_lane_enable_mask[lane_idx] &&
                (!lane_l2_empty[lane_idx] || cfg_gen_idle);

            be_mutrig_lane_emitter #(
                .FIFO_DEPTH(be_mutrig_pkg::RAW_FIFO_DEPTH_CONST)
            ) u_lane_emitter (
                .clk                    (i_clk),
                .rst                    (emu_rst),
                .enable                 (cfg_global_enable && cfg_lane_enable_mask[lane_idx]),
                .cfg_prng_seed          (cfg_prng_seed ^ LANE_SEED_XOR_CONST),
                .frame_count_pulse      (lane_frame_start[lane_idx]),
                .ticket_data            (fe_ticket_data[lane_idx]),
                .ticket_valid           (fe_ticket_valid[lane_idx]),
                .ticket_ready           (fe_ticket_ready[lane_idx]),
                .l2_rd_en               (lane_l2_rd_en[lane_idx]),
                .l2_rd_data             (lane_l2_rd_data[lane_idx]),
                .l2_rd_valid            (lane_l2_rd_valid[lane_idx]),
                .l2_empty               (lane_l2_empty[lane_idx]),
                .l2_full                (lane_l2_full[lane_idx]),
                .l2_almost_full         (lane_l2_almost_full[lane_idx]),
                .l2_event_count         (lane_l2_event_count[lane_idx]),
                .debug_ticket_fifo_level(lane_ticket_fifo_level[lane_idx]),
                .debug_l2_fifo_level    (lane_l2_fifo_level[lane_idx]),
                .frame_count            (lane_frame_count[lane_idx]),
                .hit_count              (lane_hit_count[lane_idx]),
                .clear_fifo_full_sticky (clear_fifo_full_sticky[lane_idx]),
                .clear_ticket_overflow_sticky(clear_ticket_overflow_sticky[lane_idx]),
                .fifo_full_sticky       (lane_fifo_full_sticky[lane_idx]),
                .ticket_overflow_sticky (lane_ticket_overflow_sticky[lane_idx])
            );

            be_mutrig_lane_type0_emit #(
                .DEBUG_LEVEL(DEBUG_LEVEL)
            ) u_lane_type0_emit (
                .clk                         (i_clk),
                .rst                         (emu_rst),
                .enable                      (cfg_enable_type0_stream && cfg_lane_enable_mask[lane_idx]),
                .own_drain                   (!BYTE_STREAM_ENABLE),
                .frame_start_req             (frame_start_req),
                .frame_start_allowed         (lane_frame_allowed),
                .run_terminating             (ctrl_state_q[4]),
                .run_idle                    (ctrl_state_q[0]),
                .cfg_short_mode              (cfg_short_mode),
                .asic_id                     (lane_asic_id(lane_idx)),
                .error_inject_mask           (cfg_type0_error_inject_mask),
                .error_target_lane           (cfg_lane_error_target_mask[lane_idx]),
                .l2_empty                    (lane_l2_empty[lane_idx]),
                .l2_level                    (lane_l2_event_count[lane_idx]),
                .l2_rd_en                    (type0_l2_rd_en[lane_idx]),
                .l2_rd_data                  (lane_l2_rd_data[lane_idx]),
                .l2_rd_valid                 (lane_l2_rd_valid[lane_idx]),
                .aso_hit_type0_channel       (aso_hit_type0_channel[lane_idx]),
                .aso_hit_type0_startofpacket (aso_hit_type0_startofpacket[lane_idx]),
                .aso_hit_type0_endofpacket   (aso_hit_type0_endofpacket[lane_idx]),
                .aso_hit_type0_endofrun      (aso_hit_type0_endofrun[lane_idx]),
                .aso_hit_type0_error         (aso_hit_type0_error[lane_idx]),
                .aso_hit_type0_data          (aso_hit_type0_data[lane_idx]),
                .aso_hit_type0_valid         (aso_hit_type0_valid[lane_idx]),
                .aso_hit_debug_data          (aso_hit_debug_data[lane_idx]),
                .aso_hit_debug_valid         (aso_hit_debug_valid[lane_idx]),
                .aso_hit_debug_channel       (aso_hit_debug_channel[lane_idx]),
                .aso_hit_debug_startofpacket (aso_hit_debug_startofpacket[lane_idx]),
                .aso_hit_debug_endofpacket   (aso_hit_debug_endofpacket[lane_idx]),
                .aso_hit_debug_endofrun      (aso_hit_debug_endofrun[lane_idx])
            );

            assign coe_debug_fifo_fill_level[lane_idx] =
                (DEBUG_LEVEL >= 1) ? {2'b00, lane_ticket_fifo_level[lane_idx], lane_l2_fifo_level[lane_idx]} : 16'h0000;

            if (BYTE_STREAM_ENABLE) begin : byte_stream_gen
                be_mutrig_frame_assembler u_frame_assembler (
                    .i_clk            (i_clk),
                    .i_rst            (frame_rst),
                    .frame_start_req  (frame_start_req && lane_frame_allowed),
                    .cfg_short_mode   (cfg_short_mode),
                    .cfg_gen_idle     (cfg_gen_idle),
                    .cfg_tx_mode      (cfg_tx_mode),
                    .fifo_rd_en       (frame_l2_rd_en[lane_idx]),
                    .fifo_data        (lane_l2_rd_data[lane_idx]),
                    .event_count      (lane_l2_event_count[lane_idx]),
                    .fifo_empty       (lane_l2_empty[lane_idx]),
                    .fifo_almost_full (lane_l2_almost_full[lane_idx]),
                    .frame_start      (frame_start_int),
                    .tx_data          (tx_data_int),
                    .tx_valid         (tx_valid_int)
                );

                assign lane_l2_rd_en[lane_idx] = frame_l2_rd_en[lane_idx];
                assign lane_frame_start[lane_idx] = frame_start_int;
                assign aso_tx8b1k_data[lane_idx] = tx_data_int;
                assign aso_tx8b1k_valid[lane_idx] = tx_valid_int &&
                    (tx_data_int != {1'b1, be_mutrig_pkg::K28_5_CONST});
            end else begin : no_byte_stream_gen
                assign frame_l2_rd_en[lane_idx] = 1'b0;
                assign lane_l2_rd_en[lane_idx] = type0_l2_rd_en[lane_idx];
                assign lane_frame_start[lane_idx] = frame_start_req && lane_frame_allowed;
                assign aso_tx8b1k_data[lane_idx] = {1'b1, be_mutrig_pkg::K28_5_CONST};
                assign aso_tx8b1k_valid[lane_idx] = 1'b0;
            end

            assign aso_tx8b1k_channel[lane_idx] = lane_asic_id(lane_idx);
            assign aso_tx8b1k_error[lane_idx] = 3'b000;
        end

        for (lane_idx = LANE_COUNT; lane_idx < 8; lane_idx++) begin : inactive_csr_lane_gen
            assign lane_frame_count[lane_idx] = 64'h0000_0000_0000_0000;
            assign lane_hit_count[lane_idx] = 64'h0000_0000_0000_0000;
            assign lane_fifo_full_sticky[lane_idx] = 1'b0;
            assign lane_ticket_overflow_sticky[lane_idx] = 1'b0;
        end
    endgenerate

endmodule
