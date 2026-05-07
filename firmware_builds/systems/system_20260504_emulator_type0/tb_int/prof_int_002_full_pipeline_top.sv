// prof_int_002_full_pipeline_top.sv
// Standalone PROF-INT-002 full-pipeline real-RTL simulation top.
//
// Author: Yifeng Wang <yifenwan@phys.ethz.ch>
// Version : 26.2.6
// Date    : 20260506
// Change  : Rename the virtual MuTRiG source mode and keep the old string as an alias.

module prof_int_002_full_pipeline_top;
    timeunit 1ps;
    timeprecision 1ps;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_run_window_pkg::*;
    import tb_int_record_pkg::*;
    import tb_int_mutrig_phy_agent_pkg::*;
    import tb_int_runctl_phy_agent_pkg::*;
    import tb_int_sc_phy_agent_pkg::*;
    import tb_int_l2_fifo_commit_monitor_pkg::*;
    import tb_int_lvds_decoded_monitor_pkg::*;
    import tb_int_rbcam_egress_monitor_pkg::*;
    import tb_int_feb_egress_monitor_pkg::*;
    import tb_int_histogram_csr_monitor_pkg::*;
    import tb_int_scoreboard_pkg::*;
    import tb_int_env_pkg::*;
    import tb_int_base_test_pkg::*;
    import prof_int_002_full_pipeline_100khz_per_channel_seq_pkg::*;
    import prof_int_002_full_pipeline_100khz_per_channel_test_pkg::*;
    `include "uvm_macros.svh"

    `define PROF_INT_002_CLEAR_DEBUG(TAP) \
        TAP.hit_id = 64'd0; \
        TAP.hit_id_valid = 1'b0; \
        TAP.root_hit_id = 64'd0; \
        TAP.root_hit_id_valid = 1'b0; \
        TAP.debug_level = 2'd0;

    `define PROF_INT_002_BIND_DEBUG(TAP, DATA, VALID) \
        TAP.hit_id = DATA; \
        TAP.hit_id_valid = TAP.valid && VALID; \
        TAP.root_hit_id = DATA; \
        TAP.root_hit_id_valid = TAP.valid && VALID; \
        TAP.debug_level = (TAP.valid && VALID) ? 2'd2 : 2'd0;

    `define PROF_INT_002_CLEAR_HIT_TAP(TAP) \
        TAP.valid = 1'b0; \
        TAP.ready = 1'b1; \
        TAP.lane_id = 4'd0; \
        TAP.payload = 45'd0; \
        TAP.run_origin = 1'b0; \
        `PROF_INT_002_CLEAR_DEBUG(TAP)

    `define PROF_INT_002_BIND_DEBUG_SOURCE(TAP, VALID, DATA, LANE, META, META_VALID) \
        TAP.valid = active_lane_mask[LANE] && VALID; \
        TAP.ready = 1'b1; \
        TAP.payload = DATA; \
        TAP.lane_id = LANE; \
        TAP.run_origin = 1'b0; \
        `PROF_INT_002_BIND_DEBUG(TAP, META, META_VALID)

    localparam logic [8:0] RUNCTL_IDLE_SYM        = 9'h001;
    localparam logic [8:0] RUNCTL_RUN_PREP_SYM    = 9'h002;
    localparam logic [8:0] RUNCTL_SYNC_SYM        = 9'h004;
    localparam logic [8:0] RUNCTL_RUNNING_SYM     = 9'h008;
    localparam logic [8:0] RUNCTL_TERMINATING_SYM = 9'h010;

    localparam logic [3:0] EMU_CSR_SIGNAL_ADDR      = 4'h8;
    localparam logic [3:0] EMU_CSR_RATES_ADDR       = 4'hB;
    localparam logic [3:0] EMU_CSR_CLUSTER_FIX_ADDR = 4'hC;
    localparam logic [3:0] INJ_CSR_MODE_ADDR        = 4'h2;
    localparam logic [3:0] INJ_CSR_HEADER_DELAY_ADDR = 4'h3;
    localparam logic [3:0] INJ_CSR_HEADER_INTERVAL_ADDR = 4'h4;
    localparam logic [3:0] INJ_CSR_MULTIPLICITY_ADDR = 4'h5;
    localparam logic [3:0] INJ_CSR_HEADER_CH_ADDR   = 4'h6;
    localparam logic [3:0] INJ_CSR_PULSE_HIGH_ADDR  = 4'h8;
    localparam logic [31:0] INJ_MODE_OFF            = 32'h0000_0000;
    localparam logic [31:0] INJ_MODE_HEADER_SYNC    = 32'h0000_0001;
    localparam logic [2:0] EMU_TX_MODE_LONG         = 3'b000;
    localparam logic [2:0] EMU_TX_MODE_SHORT        = 3'b100;
    localparam logic [4:0] ARB_CSR_CONTROL_ADDR     = 5'h02;
    localparam logic [31:0] ARB_MODE_REAL           = 32'h0000_0000;
    localparam logic [31:0] ARB_MODE_EMU            = 32'h0000_0001;
    localparam int unsigned MUTRIG_FRAME_CYCLES_SHORT = 910;
    localparam int unsigned MUTRIG_FRAME_CYCLES_LONG  = 1550;

    logic clk_125;
    logic cclk156;
        logic clk_50;
        logic max10_clk;
        logic rst;
        logic reset_n;
        logic datapath_reset_req = 1'b1;

    logic [31:0] download_sc_data;
    logic [3:0]  download_sc_datak;
    wire         download_sc_ready;
    wire         inject_pulse;
    wire         inject_masked_pulse;
    wire         legacy_firefly_mon_burstcount;
    wire [31:0] legacy_firefly_mon_writedata;
    wire [7:0]  legacy_firefly_mon_address;
    wire        legacy_firefly_mon_write;
    wire        legacy_firefly_mon_read;
    wire [3:0]  legacy_firefly_mon_byteenable;
    wire        legacy_firefly_mon_debugaccess;
    wire        max10_link_csn;
    wire        max10_link_clk;
    wire        max10_link_mosi_out;
    wire        max10_link_mosi_oe;
    wire        max10_link_miso_out;
    wire        max10_link_miso_oe;
    wire        max10_link_d1_out;
    wire        max10_link_d1_oe;
    wire        max10_link_d2_out;
    wire        max10_link_d2_oe;
    wire        max10_link_d3_out;
    wire        max10_link_d3_oe;
    wire        mutrig_cfg_ctrl_0_spi_export2top_mosi;
    wire        mutrig_cfg_ctrl_0_spi_export2top_sclk;
    wire [7:0]  mutrig_cfg_ctrl_0_spi_export2top_ssn;
    wire [1:0]  mutrig_reset_reset;
    wire        pulse_out_conduit_pulse;
    wire [5:0]  sense_dq_out;
    wire [5:0]  sense_dq_oe;
    wire [15:0] si_gpio_out_export;
    tri         to_firefly_ucc8_scl;
    tri         to_firefly_ucc8_sda;
    wire [1:0]  to_firefly_ucc8_reset_n;
    wire [1:0]  to_firefly_ucc8_select_n;
    wire [35:0] upload_data0_sc_rc_data;
    wire        upload_data0_sc_rc_valid;
    wire        upload_data0_sc_rc_startofpacket;
    wire        upload_data0_sc_rc_endofpacket;
    wire [1:0]  upload_data0_sc_rc_channel;
    wire [35:0] upload_data1_data;
    wire        upload_data1_valid;
    wire        upload_data1_startofpacket;
    wire        upload_data1_endofpacket;

    int unsigned run_cycles;
    int unsigned drain_cycles;
    int unsigned stable_window_cycles;
    int unsigned stable_capture_cycles;
    int unsigned stable_pre_guard_cycles;
    int unsigned stable_post_guard_cycles;
    int unsigned hit_rate_q16;
    int unsigned hit_channel_low;
    int unsigned hit_channel_high;
    int unsigned mutrig_short_mode;
    int unsigned inject_phase_cycles;
    int unsigned inject_pulse_count;
    int unsigned inject_pulse_high_cycles;
    int unsigned inject_frame_count;
    int unsigned inject_burst_count;
    int unsigned inject_burst_spacing_cycles;
    int unsigned active_lane_count;
    int unsigned active_lane_mask_popcount;
    int unsigned runctl_cpp_gap_cycles;
    int unsigned runctl_settle_timeout_cycles;
    string       traffic_mode;
    string       inject_driver;
    string       source_mode;
    string       latency_scope;
    int          rbcam_ingress_trace_fd;
    int          mts_latency_trace_fd;
    logic [2:0] stage_a_lane_index;
    logic [7:0]  active_lane_mask;
        logic        injection_window_active;
        logic        enable_post_rbcam_checks;
        logic        enable_feb_egress_checks;
        logic        virtual_mutrig0_offer_valid;
        logic        virtual_mutrig0_offer_ready;
        logic [47:0] virtual_mutrig0_offer_word;
        logic        virtual_mutrig0_accept_pulse;
        logic        virtual_mutrig0_fifo_rd_en;
        logic [9:0]  virtual_mutrig0_event_count;
        logic        virtual_mutrig0_fifo_empty;
        logic        virtual_mutrig0_fifo_full;
        logic        virtual_mutrig0_fifo_almost_full;
        logic [8:0]  virtual_mutrig0_tx_data;
        logic        virtual_mutrig0_tx_valid;
        logic [31:0] virtual_mutrig0_rate_accum;
        logic [4:0]  virtual_mutrig0_next_channel;
        int unsigned virtual_mutrig0_header_delay_count;
        int unsigned virtual_mutrig0_burst_remaining;
        int unsigned virtual_mutrig0_burst_spacing_count;
        int unsigned virtual_mutrig0_frame_seen_count;
        int unsigned virtual_mutrig0_source_hit_count;
        logic [3:0]  csr_force_addr;
        logic [31:0] csr_force_wdata;
        logic [3:0]  inj_csr_force_addr;
        logic [31:0] inj_csr_force_wdata;
        logic [4:0]  arb_csr_force_addr;
        logic [31:0] arb_csr_force_wdata;
        logic [8:0]  runctl_force_symbol;
        logic [63:0] dbg_arb_bp_accept;
        logic [63:0] dbg_bp_mux_accept;
        logic [63:0] dbg_mux_mts_accept;
        logic [63:0] dbg_mts_out_accept;
        logic [63:0] dbg_mts_out_error;
        logic [63:0] dbg_hisb_pre_accept;
        logic [63:0] dbg_hisb_pre_error;
        logic [63:0] dbg_ds0_accept;
        logic [63:0] dbg_ds1_accept;
        logic [63:0] dbg_ds2_accept;
        logic [63:0] dbg_ds3_accept;
        logic [63:0] dbg_ds4_accept;
        logic [63:0] dbg_ds5_accept;
        logic [63:0] dbg_ds6_accept;
        logic [63:0] dbg_ds7_accept;
        logic [63:0] dbg_ds_error;
        logic [63:0] dbg_rb_any_accept;
        logic [63:0] dbg_rb_hit_accept;
        logic [63:0] dbg_feb_any_accept;
        logic [63:0] dbg_feb_hit_accept;
        logic [63:0] dbg_dp_hs_runctl_accept;
        logic [63:0] dbg_hs_rbcam_runctl_accept;
        logic [63:0] dbg_hs_feb_runctl_accept;
        logic [8:0]  dbg_last_hs_runctl_symbol;
        logic        feb_frame_active;
        int unsigned feb_frame_word_index;
        logic        feb_payload_hit_region;
        logic        feb1_frame_active;
        int unsigned feb1_frame_word_index;
        logic        feb1_payload_hit_region;

    lvds_phy_if          lvds_phy_vif(.clk(clk_125), .rst(rst));
    runctl_phy_if        runctl_phy_vif(.clk(clk_125), .rst(rst));
    sc_avmm_if           sc_phy_vif(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif0(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif1(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif2(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif3(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif4(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif5(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif6(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif7(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif0(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif1(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif2(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif3(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif4(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif5(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif6(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_source_vif7(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif0(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif1(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif2(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif3(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif4(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif5(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif6(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif7(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif0(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif1(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif2(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif3(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif4(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif5(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif6(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif7(.clk(clk_125), .rst(rst));
    hit_tap_if           feb_egress_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           feb_egress_vif1(.clk(clk_125), .rst(rst));
    prof_int_002_ctrl_if ctrl_vif(.clk(clk_125), .rst(rst));
    tb_int_counter_if    counter_vif(.clk(clk_125), .rst(rst));
    logic                stage_a_any_valid;
    logic                pre_rbcam_any_valid;
    logic                post_rbcam_any_valid;

    assign stage_a_any_valid = stage_a_vif0.valid | stage_a_vif1.valid |
                               stage_a_vif2.valid | stage_a_vif3.valid |
                               stage_a_vif4.valid | stage_a_vif5.valid |
                               stage_a_vif6.valid | stage_a_vif7.valid;
    assign pre_rbcam_any_valid = pre_rbcam_vif0.valid | pre_rbcam_vif1.valid |
                                 pre_rbcam_vif2.valid | pre_rbcam_vif3.valid |
                                 pre_rbcam_vif4.valid | pre_rbcam_vif5.valid |
                                 pre_rbcam_vif6.valid | pre_rbcam_vif7.valid;
    assign post_rbcam_any_valid = post_rbcam_vif0.valid | post_rbcam_vif1.valid |
                                  post_rbcam_vif2.valid | post_rbcam_vif3.valid |
                                  post_rbcam_vif4.valid | post_rbcam_vif5.valid |
                                  post_rbcam_vif6.valid | post_rbcam_vif7.valid;

    always_comb begin
        counter_vif.available = ctrl_vif.sim_done;
        counter_vif.stage_a_count = ctrl_vif.stage_a_count;
        counter_vif.pre_rbcam_count = ctrl_vif.pre_rbcam_count;
        counter_vif.post_rbcam_count = ctrl_vif.post_rbcam_count;
        counter_vif.feb_egress_count = ctrl_vif.feb_egress_count;
    end

    full8lane_type0_system u_dut (
        .cclk156_clk                           (cclk156),
        .download_sc_data                      (download_sc_data),
        .download_sc_datak                     (download_sc_datak),
        .download_sc_ready                     (download_sc_ready),
        .inject_pulse                          (inject_pulse),
        .inject_masked_pulse                   (inject_masked_pulse),
        .legacy_firefly_mon_waitrequest        (1'b0),
        .legacy_firefly_mon_readdata           (32'h0000_0000),
        .legacy_firefly_mon_readdatavalid      (1'b0),
        .legacy_firefly_mon_response           (2'b00),
        .legacy_firefly_mon_burstcount         (legacy_firefly_mon_burstcount),
        .legacy_firefly_mon_writedata          (legacy_firefly_mon_writedata),
        .legacy_firefly_mon_address            (legacy_firefly_mon_address),
        .legacy_firefly_mon_write              (legacy_firefly_mon_write),
        .legacy_firefly_mon_read               (legacy_firefly_mon_read),
        .legacy_firefly_mon_byteenable         (legacy_firefly_mon_byteenable),
        .legacy_firefly_mon_debugaccess        (legacy_firefly_mon_debugaccess),
        .lvds_pll_inclock_clk                  (clk_125),
        .max10_link_csn                        (max10_link_csn),
        .max10_link_clk                        (max10_link_clk),
        .max10_link_mosi_in                    (1'b0),
        .max10_link_mosi_out                   (max10_link_mosi_out),
        .max10_link_mosi_oe                    (max10_link_mosi_oe),
        .max10_link_miso_in                    (1'b0),
        .max10_link_miso_out                   (max10_link_miso_out),
        .max10_link_miso_oe                    (max10_link_miso_oe),
        .max10_link_d1_in                      (1'b0),
        .max10_link_d1_out                     (max10_link_d1_out),
        .max10_link_d1_oe                      (max10_link_d1_oe),
        .max10_link_d2_in                      (1'b0),
        .max10_link_d2_out                     (max10_link_d2_out),
        .max10_link_d2_oe                      (max10_link_d2_oe),
        .max10_link_d3_in                      (1'b0),
        .max10_link_d3_out                     (max10_link_d3_out),
        .max10_link_d3_oe                      (max10_link_d3_oe),
        .max10_link_clock_clk                  (max10_clk),
        .mclk125_clk                           (clk_125),
        .mutrig_cfg_ctrl_0_spi_export2top_miso (1'b0),
        .mutrig_cfg_ctrl_0_spi_export2top_mosi (mutrig_cfg_ctrl_0_spi_export2top_mosi),
        .mutrig_cfg_ctrl_0_spi_export2top_sclk (mutrig_cfg_ctrl_0_spi_export2top_sclk),
        .mutrig_cfg_ctrl_0_spi_export2top_ssn  (mutrig_cfg_ctrl_0_spi_export2top_ssn),
        .mutrig_reset_reset                    (mutrig_reset_reset),
        .osc_clock_50_in_clk                   (clk_50),
        .pulse_out_conduit_pulse               (pulse_out_conduit_pulse),
        .redriver_losn                         (9'h1FF),
        .reset_3_reset_n                       (reset_n),
        .sense_dq_in                           (6'h00),
        .sense_dq_out                          (sense_dq_out),
        .sense_dq_oe                           (sense_dq_oe),
        .serial_data                           (9'h000),
        .si_gpio_out_export                    (si_gpio_out_export),
        .si_status_in_export                   (8'h00),
        .to_firefly_ucc8_scl                   (to_firefly_ucc8_scl),
        .to_firefly_ucc8_present_n             (2'b00),
        .to_firefly_ucc8_sda                   (to_firefly_ucc8_sda),
        .to_firefly_ucc8_reset_n               (to_firefly_ucc8_reset_n),
        .to_firefly_ucc8_select_n              (to_firefly_ucc8_select_n),
        .to_firefly_ucc8_int_n                 (2'b11),
        .upload_data0_sc_rc_data               (upload_data0_sc_rc_data),
        .upload_data0_sc_rc_valid              (upload_data0_sc_rc_valid),
        .upload_data0_sc_rc_ready              (1'b1),
        .upload_data0_sc_rc_startofpacket      (upload_data0_sc_rc_startofpacket),
        .upload_data0_sc_rc_endofpacket        (upload_data0_sc_rc_endofpacket),
        .upload_data0_sc_rc_channel            (upload_data0_sc_rc_channel),
        .upload_data1_data                     (upload_data1_data),
        .upload_data1_valid                    (upload_data1_valid),
        .upload_data1_ready                    (1'b1),
        .upload_data1_startofpacket            (upload_data1_startofpacket),
        .upload_data1_endofpacket              (upload_data1_endofpacket)
    );

    tb_int_assertions u_tb_int_assertions (
        .clk              (clk_125),
        .rst              (rst),
        .stage_a_valid    (stage_a_any_valid),
        .pre_rbcam_valid  (pre_rbcam_any_valid),
        .post_rbcam_valid (post_rbcam_any_valid),
        .feb_egress_valid (feb_egress_vif.valid | feb_egress_vif1.valid),
        .enable_post_rbcam_checks (enable_post_rbcam_checks),
        .enable_feb_egress_checks (enable_feb_egress_checks)
    );

    raw_mutrig_frame_top u_virtual_mutrig0 (
        .i_clk                 (clk_125),
        .i_rst                 (rst),
        .i_start_trans         (u_dut.data_path_subsystem.emulator_mutrig_0
                                    .u_emulator_mutrig.frame_start_req),
        .i_short_mode          (mutrig_short_mode[0]),
        .i_gen_idle            (1'b1),
        .i_offer_valid         (virtual_mutrig0_offer_valid),
        .i_offer_word          (virtual_mutrig0_offer_word),
        .o_offer_ready         (virtual_mutrig0_offer_ready),
        .o_accept_pulse        (virtual_mutrig0_accept_pulse),
        .o_fifo_rd_en          (virtual_mutrig0_fifo_rd_en),
        .o_event_count         (virtual_mutrig0_event_count),
        .o_fifo_empty          (virtual_mutrig0_fifo_empty),
        .o_fifo_full           (virtual_mutrig0_fifo_full),
        .o_fifo_almost_full    (virtual_mutrig0_fifo_almost_full),
        .o_tx_data             (virtual_mutrig0_tx_data),
        .o_tx_valid            (virtual_mutrig0_tx_valid)
    );

    function automatic logic [44:0] raw48_to_hit0(
        input logic [47:0] raw_word,
        input logic [3:0]  asic
    );
        return {asic, raw_word[47:43], raw_word[41:27],
                raw_word[26:22], raw_word[20:6], raw_word[0]};
    endfunction

    function automatic logic [47:0] build_virtual_mutrig_hit_word(
        input logic [4:0]  channel,
        input logic [14:0] tcc
    );
        return {channel, 1'b0, tcc, 5'd0, 1'b0, tcc, 5'd0, 1'b1};
    endfunction

    function automatic logic [44:0] hit2_to_hit0(input logic [35:0] hit2_word);
        return {hit2_word[25:22], hit2_word[21:17],
                15'h0000, hit2_word[13:9], 15'h0000, 1'b1};
    endfunction

    // rbCAM ingress hit_type1 layout from ring_buffer_cam_v2_core:
    // [38:35]=asic, [34:30]=channel, [29:17]=tcc_8n,
    // [16:14]=tcc_1n6, [13:9]=t_fine, [8:0]=et_1n6.
    // The monitor fabric carries hit_type0-shaped payloads, so only the
    // fields needed by the per-bucket key are projected into that shape.
    function automatic logic [44:0] hit1_to_hit0(input logic [38:0] hit1_word);
        return {hit1_word[38:35], hit1_word[34:30],
                {2'b00, hit1_word[29:17]},
                hit1_word[13:9], 15'h0000, 1'b1};
    endfunction

    function automatic logic hit2_word_is_hit(input logic [35:0] hit2_word);
        return (hit2_word[35:32] == 4'h0);
    endfunction

    function automatic int unsigned rbcam_age_mod8192(
        input logic [47:0] gts_8n,
        input logic [12:0] hit_ts8n
    );
        logic [12:0] age_v;

        age_v = gts_8n[12:0] - hit_ts8n;
        return int'(age_v);
    endfunction

    task automatic write_rbcam_ingress_trace(
        input int unsigned copy_idx,
        input logic [38:0] hit1_data,
        input logic        split_valid,
        input logic        split_ready,
        input logic        split_empty,
        input logic        split_error,
        input logic        meta_valid,
        input logic [63:0] meta_data,
        input logic        deassembly_wrreq,
        input logic        deassembly_full,
        input logic        deassembly_empty,
        input logic        in_payload_valid,
        input logic        push_write_req,
        input logic        push_write_grant,
        input logic [3:0]  run_state_code,
        input logic [2:0]  pop_state_code,
        input logic        push_state_code,
        input logic [47:0] gts_8n,
        input logic [47:0] read_time_ptr
    );
        logic [12:0] hit_ts8n;
        logic [7:0]  hit_key;
        logic [1:0]  expected_copy;
        logic [1:0]  copy_lsb;
        logic        split_accept;
        logic        lane_match;
        logic        would_enter_deassembly;
        int unsigned age_mod8192;

        if (rbcam_ingress_trace_fd == 0)
            return;
        if (!(split_valid || deassembly_wrreq || in_payload_valid ||
              push_write_req || push_write_grant))
            return;

        hit_ts8n = hit1_data[29:17];
        hit_key = hit1_data[28:21];
        expected_copy = hit1_data[22:21];
        copy_lsb = copy_idx[1:0];
        split_accept = split_valid && split_ready && !split_empty && !split_error;
        lane_match = (expected_copy == copy_lsb);
        would_enter_deassembly = split_accept && lane_match && !deassembly_full;
        age_mod8192 = rbcam_age_mod8192(gts_8n, hit_ts8n);

        $fdisplay(rbcam_ingress_trace_fd,
                  "%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%010h,%0d,0x%016h",
                  $time,
                  copy_idx,
                  split_valid,
                  split_ready,
                  split_empty,
                  split_error,
                  split_accept,
                  lane_match,
                  would_enter_deassembly,
                  deassembly_wrreq,
                  deassembly_full,
                  deassembly_empty,
                  in_payload_valid,
                  push_write_req,
                  push_write_grant,
                  run_state_code,
                  pop_state_code,
                  push_state_code,
                  gts_8n,
                  read_time_ptr,
                  age_mod8192,
                  hit_ts8n,
                  hit_key,
                  expected_copy,
                  hit1_data[38:35],
                  hit1_data[34:30],
                  hit1_data[13:9],
                  hit1_data[29],
                  hit1_data,
                  meta_valid,
                  meta_data);
    endtask

    initial begin : rbcam_trace_files
        string trace_output_dir;
        string rbcam_ingress_trace_path;
        string mts_latency_trace_path;

        if (!$value$plusargs("TB_INT_SIM_DIR=%s", trace_output_dir))
            trace_output_dir = ".";
        rbcam_ingress_trace_path = {trace_output_dir, "/rbcam_ingress_trace.csv"};
        mts_latency_trace_path = {trace_output_dir, "/mts_latency_trace.csv"};
        rbcam_ingress_trace_fd = $fopen(rbcam_ingress_trace_path, "w");
        mts_latency_trace_fd = $fopen(mts_latency_trace_path, "w");
        if (rbcam_ingress_trace_fd == 0)
            `uvm_fatal("PROF_INT_002_TRACE",
                       $sformatf("failed to open %s", rbcam_ingress_trace_path))
        if (mts_latency_trace_fd == 0)
            `uvm_fatal("PROF_INT_002_TRACE",
                       $sformatf("failed to open %s", mts_latency_trace_path))
        $fdisplay(rbcam_ingress_trace_fd,
                  "time_ps,copy,split_valid,split_ready,split_empty,split_error,split_accept,lane_match,would_enter_deassembly,deassembly_wrreq,deassembly_full,deassembly_empty,in_payload_valid,push_write_req,push_write_grant,run_state_code,pop_state_code,push_state_code,gts_8n,read_time_ptr,age_mod8192,hit_ts8n,hit_key,expected_copy,asic,channel,t_fine,ts12,hit1_data_hex,metadata_valid,metadata_hex");
        $fdisplay(mts_latency_trace_fd,
                  "time_ps,bank,debug_valid,debug_delay_cycles,hit1_valid,hit1_ready,hit1_empty,hit1_error,hit_ts8n,hit_key,asic,channel,t_fine,metadata_valid,metadata_hex");
    end

    final begin : rbcam_trace_close
        if (rbcam_ingress_trace_fd != 0)
            $fclose(rbcam_ingress_trace_fd);
        if (mts_latency_trace_fd != 0)
            $fclose(mts_latency_trace_fd);
    end

    function automatic logic type3_word_is_k(input logic [35:0] data);
        return (data[35:32] == 4'h1);
    endfunction

    function automatic logic type3_word_is_subheader(input logic [35:0] data);
        return type3_word_is_k(data) && (data[7:0] == 8'hf7);
    endfunction

    function automatic logic type3_word_is_frame_header(input logic [35:0] data);
        return type3_word_is_k(data) && (data[7:0] == 8'hbc);
    endfunction

    function automatic logic type3_word_is_frame_trailer(input logic [35:0] data);
        return type3_word_is_k(data) && (data[7:0] == 8'h9c);
    endfunction

    function automatic logic hit1_tap_valid(
        input logic valid,
        input logic ready,
        input logic empty,
        input logic error
    );
        return valid && ready && !empty && !error;
    endfunction

    function automatic logic hit2_tap_valid(
        input logic valid,
        input logic ready,
        input logic error,
        input logic [35:0] data
    );
        return valid && ready && !error && hit2_word_is_hit(data);
    endfunction

    function automatic logic type3_tap_valid(
        input logic valid,
        input logic ready,
        input logic payload_hit_region,
        input logic [35:0] data
    );
        return valid && ready && payload_hit_region && !type3_word_is_k(data);
    endfunction

    function automatic logic [63:0] count_if(input logic condition);
        return {63'd0, condition};
    endfunction

    function automatic logic [3:0] pre_rbcam_lane_id(input logic [38:0] hit1_word);
        // Single-active header_sync runs validate a physical source lane at a
        // time.  Use that source lane for the scoreboard because the direct
        // generated emulator path can project a logical hit_type1 ASIC field
        // that does not identify which qsys lane emitted the pulse.
        if ((traffic_mode == "header_sync") && (active_lane_mask_popcount == 1))
            return {1'b0, stage_a_lane_index};
        return hit1_word[38:35];
    endfunction

    always_ff @(posedge clk_125) begin : virtual_mutrig_source_driver
        logic emit_hit_v;
        logic [31:0] rate_acc_next_v;
        int unsigned rate_step_v;
        logic [4:0] channel_v;

        emit_hit_v = 1'b0;
        rate_acc_next_v = virtual_mutrig0_rate_accum;
        rate_step_v = 0;
        channel_v = virtual_mutrig0_next_channel;

        if (rst || (source_mode != "virtual_mutrig") || !injection_window_active) begin
            virtual_mutrig0_offer_valid <= 1'b0;
            virtual_mutrig0_offer_word <= 48'd0;
            virtual_mutrig0_rate_accum <= 32'd0;
            virtual_mutrig0_next_channel <= hit_channel_low[4:0];
            virtual_mutrig0_header_delay_count <= 0;
            virtual_mutrig0_burst_remaining <= 0;
            virtual_mutrig0_burst_spacing_count <= 0;
            virtual_mutrig0_frame_seen_count <= 0;
            virtual_mutrig0_source_hit_count <= 0;
        end else begin
            if (virtual_mutrig0_offer_valid && virtual_mutrig0_offer_ready) begin
                virtual_mutrig0_offer_valid <= 1'b0;
                virtual_mutrig0_source_hit_count <= virtual_mutrig0_source_hit_count + 1;
                if (virtual_mutrig0_next_channel >= hit_channel_high[4:0])
                    virtual_mutrig0_next_channel <= hit_channel_low[4:0];
                else
                    virtual_mutrig0_next_channel <= virtual_mutrig0_next_channel + 5'd1;
            end

            if (!virtual_mutrig0_offer_valid) begin
                if (traffic_is_periodic()) begin
                    rate_step_v = hit_rate_q16 * active_hit_channel_count();
                    rate_acc_next_v = virtual_mutrig0_rate_accum + rate_step_v;
                    if (hit_rate_q16 != 0 && rate_acc_next_v >= 32'd65536) begin
                        emit_hit_v = 1'b1;
                        virtual_mutrig0_rate_accum <= rate_acc_next_v - 32'd65536;
                    end else begin
                        virtual_mutrig0_rate_accum <= rate_acc_next_v;
                    end
                end else if (traffic_is_header_sync()) begin
                    if (active_frame_start_seen()) begin
                        if ((inject_frame_count == 0) ||
                            (virtual_mutrig0_frame_seen_count < inject_frame_count)) begin
                            virtual_mutrig0_header_delay_count <= inject_phase_cycles;
                            virtual_mutrig0_burst_remaining <= inject_burst_count;
                            virtual_mutrig0_burst_spacing_count <= 0;
                            virtual_mutrig0_frame_seen_count <= virtual_mutrig0_frame_seen_count + 1;
                        end
                    end else if (virtual_mutrig0_burst_remaining != 0) begin
                        if (virtual_mutrig0_header_delay_count != 0) begin
                            virtual_mutrig0_header_delay_count <= virtual_mutrig0_header_delay_count - 1;
                        end else if (virtual_mutrig0_burst_spacing_count != 0) begin
                            virtual_mutrig0_burst_spacing_count <= virtual_mutrig0_burst_spacing_count - 1;
                        end else begin
                            emit_hit_v = 1'b1;
                            virtual_mutrig0_burst_remaining <= virtual_mutrig0_burst_remaining - 1;
                            virtual_mutrig0_burst_spacing_count <=
                                (inject_burst_spacing_cycles > 1) ?
                                    (inject_burst_spacing_cycles - 2) : 0;
                        end
                    end
                end

                if (emit_hit_v) begin
                    virtual_mutrig0_offer_valid <= 1'b1;
                    // Keep virtual raw-hit timestamps on the generated MuTRiG timebase.
                    virtual_mutrig0_offer_word <= build_virtual_mutrig_hit_word(
                        channel_v,
                        u_dut.data_path_subsystem.emulator_mutrig_0
                            .u_emulator_mutrig.tcc_lfsr);
                end
            end
        end
    end

    always_comb begin
        logic [44:0] stage_a_payload;

        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif0)
        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif1)
        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif2)
        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif3)
        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif4)
        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif5)
        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif6)
        `PROF_INT_002_CLEAR_DEBUG(stage_a_vif7)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif0)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif1)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif2)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif3)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif4)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif5)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif6)
        `PROF_INT_002_CLEAR_HIT_TAP(debug_source_vif7)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif0)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif1)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif2)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif3)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif4)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif5)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif6)
        `PROF_INT_002_CLEAR_DEBUG(pre_rbcam_vif7)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif0)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif1)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif2)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif3)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif4)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif5)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif6)
        `PROF_INT_002_CLEAR_DEBUG(post_rbcam_vif7)
        `PROF_INT_002_CLEAR_DEBUG(feb_egress_vif)
        `PROF_INT_002_CLEAR_DEBUG(feb_egress_vif1)

        if (source_mode == "virtual_mutrig") begin
            stage_a_payload = raw48_to_hit0(virtual_mutrig0_offer_word, 4'd0);
            stage_a_vif0.valid = active_lane_mask[0] &&
                                 virtual_mutrig0_offer_valid &&
                                 virtual_mutrig0_offer_ready;
        end else begin
            stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_0
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd0);
            stage_a_vif0.valid = active_lane_mask[0] &&
                u_dut.data_path_subsystem.emulator_mutrig_0
                    .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
                u_dut.data_path_subsystem.emulator_mutrig_0
                    .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        end
        stage_a_vif0.payload = stage_a_payload;
        stage_a_vif0.lane_id = 4'd0;
        stage_a_vif0.channel = stage_a_payload[40:36];
        stage_a_vif0.t_coarse = stage_a_payload[35:21];
        stage_a_vif0.t_fine = stage_a_payload[20:16];
        if (source_mode == "virtual_mutrig") begin
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif0,
                u_dut.data_path_subsystem.mutrig_frame_deassembly_0_hit_type0_valid,
                u_dut.data_path_subsystem.mutrig_frame_deassembly_0_hit_type0_data,
                0,
                u_dut.data_path_subsystem.mutrig_frame_deassembly_0_debug_hit_metadata_metadata,
                u_dut.data_path_subsystem.mutrig_frame_deassembly_0_debug_hit_metadata_valid)
        end else begin
            `PROF_INT_002_BIND_DEBUG(
                stage_a_vif0,
                u_dut.data_path_subsystem.emulator_mutrig_0_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_0_hit_debug_metadata_valid)
        end

        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_1
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd1);
        stage_a_vif1.valid = active_lane_mask[1] &&
            u_dut.data_path_subsystem.emulator_mutrig_1
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_1
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif1.payload = stage_a_payload;
        stage_a_vif1.lane_id = 4'd1;
        stage_a_vif1.channel = stage_a_payload[40:36];
        stage_a_vif1.t_coarse = stage_a_payload[35:21];
        stage_a_vif1.t_fine = stage_a_payload[20:16];
        `PROF_INT_002_BIND_DEBUG(
            stage_a_vif1,
            u_dut.data_path_subsystem.emulator_mutrig_1_hit_debug_metadata_metadata,
            u_dut.data_path_subsystem.emulator_mutrig_1_hit_debug_metadata_valid)

        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_2
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd2);
        stage_a_vif2.valid = active_lane_mask[2] &&
            u_dut.data_path_subsystem.emulator_mutrig_2
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_2
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif2.payload = stage_a_payload;
        stage_a_vif2.lane_id = 4'd2;
        stage_a_vif2.channel = stage_a_payload[40:36];
        stage_a_vif2.t_coarse = stage_a_payload[35:21];
        stage_a_vif2.t_fine = stage_a_payload[20:16];
        `PROF_INT_002_BIND_DEBUG(
            stage_a_vif2,
            u_dut.data_path_subsystem.emulator_mutrig_2_hit_debug_metadata_metadata,
            u_dut.data_path_subsystem.emulator_mutrig_2_hit_debug_metadata_valid)

        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_3
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd3);
        stage_a_vif3.valid = active_lane_mask[3] &&
            u_dut.data_path_subsystem.emulator_mutrig_3
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_3
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif3.payload = stage_a_payload;
        stage_a_vif3.lane_id = 4'd3;
        stage_a_vif3.channel = stage_a_payload[40:36];
        stage_a_vif3.t_coarse = stage_a_payload[35:21];
        stage_a_vif3.t_fine = stage_a_payload[20:16];
        `PROF_INT_002_BIND_DEBUG(
            stage_a_vif3,
            u_dut.data_path_subsystem.emulator_mutrig_3_hit_debug_metadata_metadata,
            u_dut.data_path_subsystem.emulator_mutrig_3_hit_debug_metadata_valid)

        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_4
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd4);
        stage_a_vif4.valid = active_lane_mask[4] &&
            u_dut.data_path_subsystem.emulator_mutrig_4
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_4
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif4.payload = stage_a_payload;
        stage_a_vif4.lane_id = 4'd4;
        stage_a_vif4.channel = stage_a_payload[40:36];
        stage_a_vif4.t_coarse = stage_a_payload[35:21];
        stage_a_vif4.t_fine = stage_a_payload[20:16];
        `PROF_INT_002_BIND_DEBUG(
            stage_a_vif4,
            u_dut.data_path_subsystem.emulator_mutrig_4_hit_debug_metadata_metadata,
            u_dut.data_path_subsystem.emulator_mutrig_4_hit_debug_metadata_valid)

        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_5
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd5);
        stage_a_vif5.valid = active_lane_mask[5] &&
            u_dut.data_path_subsystem.emulator_mutrig_5
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_5
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif5.payload = stage_a_payload;
        stage_a_vif5.lane_id = 4'd5;
        stage_a_vif5.channel = stage_a_payload[40:36];
        stage_a_vif5.t_coarse = stage_a_payload[35:21];
        stage_a_vif5.t_fine = stage_a_payload[20:16];
        `PROF_INT_002_BIND_DEBUG(
            stage_a_vif5,
            u_dut.data_path_subsystem.emulator_mutrig_5_hit_debug_metadata_metadata,
            u_dut.data_path_subsystem.emulator_mutrig_5_hit_debug_metadata_valid)

        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_6
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd6);
        stage_a_vif6.valid = active_lane_mask[6] &&
            u_dut.data_path_subsystem.emulator_mutrig_6
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_6
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif6.payload = stage_a_payload;
        stage_a_vif6.lane_id = 4'd6;
        stage_a_vif6.channel = stage_a_payload[40:36];
        stage_a_vif6.t_coarse = stage_a_payload[35:21];
        stage_a_vif6.t_fine = stage_a_payload[20:16];
        `PROF_INT_002_BIND_DEBUG(
            stage_a_vif6,
            u_dut.data_path_subsystem.emulator_mutrig_6_hit_debug_metadata_metadata,
            u_dut.data_path_subsystem.emulator_mutrig_6_hit_debug_metadata_valid)

        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_7
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd7);
        stage_a_vif7.valid = active_lane_mask[7] &&
            u_dut.data_path_subsystem.emulator_mutrig_7
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_7
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif7.payload = stage_a_payload;
        stage_a_vif7.lane_id = 4'd7;
        stage_a_vif7.channel = stage_a_payload[40:36];
        stage_a_vif7.t_coarse = stage_a_payload[35:21];
        stage_a_vif7.t_fine = stage_a_payload[20:16];
        `PROF_INT_002_BIND_DEBUG(
            stage_a_vif7,
            u_dut.data_path_subsystem.emulator_mutrig_7_hit_debug_metadata_metadata,
            u_dut.data_path_subsystem.emulator_mutrig_7_hit_debug_metadata_valid)

        if (source_mode != "virtual_mutrig") begin
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif0,
                u_dut.data_path_subsystem.emulator_mutrig_0_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_0_hit_type0_data,
                0,
                u_dut.data_path_subsystem.emulator_mutrig_0_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_0_hit_debug_metadata_valid)
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif1,
                u_dut.data_path_subsystem.emulator_mutrig_1_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_1_hit_type0_data,
                1,
                u_dut.data_path_subsystem.emulator_mutrig_1_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_1_hit_debug_metadata_valid)
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif2,
                u_dut.data_path_subsystem.emulator_mutrig_2_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_2_hit_type0_data,
                2,
                u_dut.data_path_subsystem.emulator_mutrig_2_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_2_hit_debug_metadata_valid)
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif3,
                u_dut.data_path_subsystem.emulator_mutrig_3_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_3_hit_type0_data,
                3,
                u_dut.data_path_subsystem.emulator_mutrig_3_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_3_hit_debug_metadata_valid)
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif4,
                u_dut.data_path_subsystem.emulator_mutrig_4_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_4_hit_type0_data,
                4,
                u_dut.data_path_subsystem.emulator_mutrig_4_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_4_hit_debug_metadata_valid)
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif5,
                u_dut.data_path_subsystem.emulator_mutrig_5_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_5_hit_type0_data,
                5,
                u_dut.data_path_subsystem.emulator_mutrig_5_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_5_hit_debug_metadata_valid)
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif6,
                u_dut.data_path_subsystem.emulator_mutrig_6_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_6_hit_type0_data,
                6,
                u_dut.data_path_subsystem.emulator_mutrig_6_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_6_hit_debug_metadata_valid)
            `PROF_INT_002_BIND_DEBUG_SOURCE(
                debug_source_vif7,
                u_dut.data_path_subsystem.emulator_mutrig_7_hit_type0_valid,
                u_dut.data_path_subsystem.emulator_mutrig_7_hit_type0_data,
                7,
                u_dut.data_path_subsystem.emulator_mutrig_7_hit_debug_metadata_metadata,
                u_dut.data_path_subsystem.emulator_mutrig_7_hit_debug_metadata_valid)
        end

        pre_rbcam_vif0.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_error[0]);
        pre_rbcam_vif0.ready = 1'b1;
        pre_rbcam_vif0.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_data);
        pre_rbcam_vif0.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif0,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out0_metadata,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out0_valid)
        pre_rbcam_vif0.run_origin = 1'b0;

        pre_rbcam_vif1.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_error[0]);
        pre_rbcam_vif1.ready = 1'b1;
        pre_rbcam_vif1.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_data);
        pre_rbcam_vif1.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif1,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out1_metadata,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out1_valid)
        pre_rbcam_vif1.run_origin = 1'b0;

        pre_rbcam_vif2.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_error[0]);
        pre_rbcam_vif2.ready = 1'b1;
        pre_rbcam_vif2.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_data);
        pre_rbcam_vif2.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif2,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out2_metadata,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out2_valid)
        pre_rbcam_vif2.run_origin = 1'b0;

        pre_rbcam_vif3.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_error[0]);
        pre_rbcam_vif3.ready = 1'b1;
        pre_rbcam_vif3.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_data);
        pre_rbcam_vif3.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif3,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out3_metadata,
            u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out3_valid)
        pre_rbcam_vif3.run_origin = 1'b0;

        pre_rbcam_vif4.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_error[0]);
        pre_rbcam_vif4.ready = 1'b1;
        pre_rbcam_vif4.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_data);
        pre_rbcam_vif4.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif4,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out0_metadata,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out0_valid)
        pre_rbcam_vif4.run_origin = 1'b0;

        pre_rbcam_vif5.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_error[0]);
        pre_rbcam_vif5.ready = 1'b1;
        pre_rbcam_vif5.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_data);
        pre_rbcam_vif5.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif5,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out1_metadata,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out1_valid)
        pre_rbcam_vif5.run_origin = 1'b0;

        pre_rbcam_vif6.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_error[0]);
        pre_rbcam_vif6.ready = 1'b1;
        pre_rbcam_vif6.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_data);
        pre_rbcam_vif6.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif6,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out2_metadata,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out2_valid)
        pre_rbcam_vif6.run_origin = 1'b0;

        pre_rbcam_vif7.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_error[0]);
        pre_rbcam_vif7.ready = 1'b1;
        pre_rbcam_vif7.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_data);
        pre_rbcam_vif7.lane_id =
            pre_rbcam_lane_id(
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_data);
        `PROF_INT_002_BIND_DEBUG(
            pre_rbcam_vif7,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out3_metadata,
            u_dut.data_path_subsystem.mts1_hit_type1_sidecar_fanout_out3_valid)
        pre_rbcam_vif7.run_origin = 1'b0;

        post_rbcam_vif0.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_data);
        post_rbcam_vif0.ready = 1'b1;
        post_rbcam_vif0.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_data);
        post_rbcam_vif0.lane_id = post_rbcam_vif0.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif0,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_metadata_valid)
        post_rbcam_vif0.run_origin = 1'b0;

        post_rbcam_vif1.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_data);
        post_rbcam_vif1.ready = 1'b1;
        post_rbcam_vif1.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_data);
        post_rbcam_vif1.lane_id = post_rbcam_vif1.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif1,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_metadata_valid)
        post_rbcam_vif1.run_origin = 1'b0;

        post_rbcam_vif2.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_data);
        post_rbcam_vif2.ready = 1'b1;
        post_rbcam_vif2.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_data);
        post_rbcam_vif2.lane_id = post_rbcam_vif2.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif2,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_metadata_valid)
        post_rbcam_vif2.run_origin = 1'b0;

        post_rbcam_vif3.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_data);
        post_rbcam_vif3.ready = 1'b1;
        post_rbcam_vif3.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_data);
        post_rbcam_vif3.lane_id = post_rbcam_vif3.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif3,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_metadata_valid)
        post_rbcam_vif3.run_origin = 1'b0;

        post_rbcam_vif4.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_data);
        post_rbcam_vif4.ready = 1'b1;
        post_rbcam_vif4.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_data);
        post_rbcam_vif4.lane_id = post_rbcam_vif4.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif4,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_metadata_valid)
        post_rbcam_vif4.run_origin = 1'b0;

        post_rbcam_vif5.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_data);
        post_rbcam_vif5.ready = 1'b1;
        post_rbcam_vif5.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_data);
        post_rbcam_vif5.lane_id = post_rbcam_vif5.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif5,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_metadata_valid)
        post_rbcam_vif5.run_origin = 1'b0;

        post_rbcam_vif6.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_data);
        post_rbcam_vif6.ready = 1'b1;
        post_rbcam_vif6.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_data);
        post_rbcam_vif6.lane_id = post_rbcam_vif6.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif6,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_metadata_valid)
        post_rbcam_vif6.run_origin = 1'b0;

        post_rbcam_vif7.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_data);
        post_rbcam_vif7.ready = 1'b1;
        post_rbcam_vif7.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_data);
        post_rbcam_vif7.lane_id = post_rbcam_vif7.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            post_rbcam_vif7,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_metadata_metadata,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_metadata_valid)
        post_rbcam_vif7.run_origin = 1'b0;

        feb_egress_vif.valid = u_dut.data_path_subsystem
            .hit_stack_subsystem_0_hit_type3_valid &&
            u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready &&
            type3_tap_valid(
                u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready,
                feb_payload_hit_region,
                u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data);
        feb_egress_vif.ready = 1'b1;
        feb_egress_vif.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data);
        feb_egress_vif.lane_id = feb_egress_vif.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            feb_egress_vif,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.frame_debug_hit_sidecar_data,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.frame_debug_hit_sidecar_valid)
        feb_egress_vif.run_origin = 1'b0;

        feb_egress_vif1.valid = u_dut.data_path_subsystem.hit_type3_lower_valid &&
            u_dut.data_path_subsystem.hit_type3_lower_ready &&
            type3_tap_valid(
                u_dut.data_path_subsystem.hit_type3_lower_valid,
                u_dut.data_path_subsystem.hit_type3_lower_ready,
                feb1_payload_hit_region,
                u_dut.data_path_subsystem.hit_type3_lower_data);
        feb_egress_vif1.ready = 1'b1;
        feb_egress_vif1.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_type3_lower_data);
        feb_egress_vif1.lane_id = feb_egress_vif1.payload[44:41];
        `PROF_INT_002_BIND_DEBUG(
            feb_egress_vif1,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.frame_debug_hit_sidecar_data,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.frame_debug_hit_sidecar_valid)
        feb_egress_vif1.run_origin = 1'b0;
    end

    always @(posedge clk_125) begin : rbcam_ingress_trace
        if (!rst) begin
            if (mts_latency_trace_fd != 0) begin
                if (u_dut.data_path_subsystem.mts_preprocessor_0_debug_ts_valid ||
                    u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid) begin
                    $fdisplay(mts_latency_trace_fd,
                              "%0t,0,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%016h",
                              $time,
                              u_dut.data_path_subsystem.mts_preprocessor_0_debug_ts_valid,
                              $signed(u_dut.data_path_subsystem.mts_preprocessor_0_debug_ts_data),
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid,
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_ready,
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_empty,
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_error,
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_data[29:17],
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_data[28:21],
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_data[38:35],
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_data[34:30],
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_data[13:9],
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_sidecar_valid,
                              u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_sidecar_metadata);
                end
                if (u_dut.data_path_subsystem.mts_preprocessor_1_debug_ts_valid ||
                    u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_valid) begin
                    $fdisplay(mts_latency_trace_fd,
                              "%0t,1,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%016h",
                              $time,
                              u_dut.data_path_subsystem.mts_preprocessor_1_debug_ts_valid,
                              $signed(u_dut.data_path_subsystem.mts_preprocessor_1_debug_ts_data),
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_valid,
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_ready,
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_empty,
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_error,
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_data[29:17],
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_data[28:21],
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_data[38:35],
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_data[34:30],
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_data[13:9],
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_sidecar_valid,
                              u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_sidecar_metadata);
                end
            end

            write_rbcam_ingress_trace(
                0,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_data,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_ready,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_empty[0],
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_error[0],
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out0_valid,
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out0_metadata,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.deassembly_fifo_wrreq,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.deassembly_fifo_full,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.deassembly_fifo_empty,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.in_payload_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.push_write_req,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.push_write_grant,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.dbg_run_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.dbg_pop_engine_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.dbg_push_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.gts_8n,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0.v2_core.read_time_ptr);
            write_rbcam_ingress_trace(
                1,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_data,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_ready,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_empty[0],
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_error[0],
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out1_valid,
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out1_metadata,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.deassembly_fifo_wrreq,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.deassembly_fifo_full,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.deassembly_fifo_empty,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.in_payload_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.push_write_req,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.push_write_grant,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.dbg_run_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.dbg_pop_engine_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.dbg_push_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.gts_8n,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1.v2_core.read_time_ptr);
            write_rbcam_ingress_trace(
                2,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_data,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_ready,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_empty[0],
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_error[0],
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out2_valid,
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out2_metadata,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.deassembly_fifo_wrreq,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.deassembly_fifo_full,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.deassembly_fifo_empty,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.in_payload_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.push_write_req,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.push_write_grant,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.dbg_run_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.dbg_pop_engine_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.dbg_push_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.gts_8n,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2.v2_core.read_time_ptr);
            write_rbcam_ingress_trace(
                3,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_data,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_ready,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_empty[0],
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_error[0],
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out3_valid,
                u_dut.data_path_subsystem.mts0_hit_type1_sidecar_fanout_out3_metadata,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.deassembly_fifo_wrreq,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.deassembly_fifo_full,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.deassembly_fifo_empty,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.in_payload_valid,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.push_write_req,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.push_write_grant,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.dbg_run_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.dbg_pop_engine_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.dbg_push_state_code,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.gts_8n,
                u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3.v2_core.read_time_ptr);
        end
    end

    always @(posedge clk_125) begin
        if (rst) begin
            ctrl_vif.stage_a_count <= 64'd0;
            ctrl_vif.pre_rbcam_count <= 64'd0;
            ctrl_vif.post_rbcam_count <= 64'd0;
            ctrl_vif.feb_egress_count <= 64'd0;
            dbg_arb_bp_accept <= 64'd0;
            dbg_bp_mux_accept <= 64'd0;
            dbg_mux_mts_accept <= 64'd0;
            dbg_mts_out_accept <= 64'd0;
            dbg_mts_out_error <= 64'd0;
            dbg_hisb_pre_accept <= 64'd0;
            dbg_hisb_pre_error <= 64'd0;
            dbg_ds0_accept <= 64'd0;
            dbg_ds1_accept <= 64'd0;
            dbg_ds2_accept <= 64'd0;
            dbg_ds3_accept <= 64'd0;
            dbg_ds4_accept <= 64'd0;
            dbg_ds5_accept <= 64'd0;
            dbg_ds6_accept <= 64'd0;
            dbg_ds7_accept <= 64'd0;
            dbg_ds_error <= 64'd0;
            dbg_rb_any_accept <= 64'd0;
            dbg_rb_hit_accept <= 64'd0;
            dbg_feb_any_accept <= 64'd0;
            dbg_feb_hit_accept <= 64'd0;
            dbg_dp_hs_runctl_accept <= 64'd0;
            dbg_hs_rbcam_runctl_accept <= 64'd0;
            dbg_hs_feb_runctl_accept <= 64'd0;
            dbg_last_hs_runctl_symbol <= RUNCTL_IDLE_SYM;
            feb_frame_active <= 1'b0;
            feb_frame_word_index <= 0;
            feb_payload_hit_region <= 1'b0;
            feb1_frame_active <= 1'b0;
            feb1_frame_word_index <= 0;
            feb1_payload_hit_region <= 1'b0;
        end else begin
            ctrl_vif.stage_a_count <= ctrl_vif.stage_a_count +
                {63'd0, stage_a_vif0.valid} + {63'd0, stage_a_vif1.valid} +
                {63'd0, stage_a_vif2.valid} + {63'd0, stage_a_vif3.valid} +
                {63'd0, stage_a_vif4.valid} + {63'd0, stage_a_vif5.valid} +
                {63'd0, stage_a_vif6.valid} + {63'd0, stage_a_vif7.valid};
            ctrl_vif.pre_rbcam_count <= ctrl_vif.pre_rbcam_count +
                {63'd0, pre_rbcam_vif0.valid} + {63'd0, pre_rbcam_vif1.valid} +
                {63'd0, pre_rbcam_vif2.valid} + {63'd0, pre_rbcam_vif3.valid} +
                {63'd0, pre_rbcam_vif4.valid} + {63'd0, pre_rbcam_vif5.valid} +
                {63'd0, pre_rbcam_vif6.valid} + {63'd0, pre_rbcam_vif7.valid};
            ctrl_vif.post_rbcam_count <= ctrl_vif.post_rbcam_count +
                {63'd0, post_rbcam_vif0.valid} + {63'd0, post_rbcam_vif1.valid} +
                {63'd0, post_rbcam_vif2.valid} + {63'd0, post_rbcam_vif3.valid} +
                {63'd0, post_rbcam_vif4.valid} + {63'd0, post_rbcam_vif5.valid} +
                {63'd0, post_rbcam_vif6.valid} + {63'd0, post_rbcam_vif7.valid};
            ctrl_vif.feb_egress_count <= ctrl_vif.feb_egress_count +
                {63'd0, feb_egress_vif.valid} + {63'd0, feb_egress_vif1.valid};
            if (u_dut.data_path_subsystem.avalon_st_adapter_026_out_0_valid &&
                u_dut.data_path_subsystem.avalon_st_adapter_026_out_0_ready)
                dbg_arb_bp_accept <= dbg_arb_bp_accept + 64'd1;
            if (u_dut.data_path_subsystem.backpressure_fifo_0_out_valid &&
                u_dut.data_path_subsystem.backpressure_fifo_0_out_ready)
                dbg_bp_mux_accept <= dbg_bp_mux_accept + 64'd1;
            dbg_mux_mts_accept <= dbg_mux_mts_accept +
                count_if(u_dut.data_path_subsystem.mux_mutrig2processor_out_valid &&
                         u_dut.data_path_subsystem.mux_mutrig2processor_out_ready) +
                count_if(u_dut.data_path_subsystem.mux_mutrig2processor_0_out_valid &&
                         u_dut.data_path_subsystem.mux_mutrig2processor_0_out_ready);
            dbg_mts_out_accept <= dbg_mts_out_accept +
                count_if(u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid &&
                         u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_ready) +
                count_if(u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_valid &&
                         u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_ready);
            dbg_mts_out_error <= dbg_mts_out_error +
                count_if(u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid &&
                         u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_ready &&
                         u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_error) +
                count_if(u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_valid &&
                         u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_ready &&
                         u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_error);
            if (u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_valid &&
                u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_ready) begin
                dbg_hisb_pre_accept <= dbg_hisb_pre_accept + 64'd1;
                if (u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_error)
                    dbg_hisb_pre_error <= dbg_hisb_pre_error + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_ready) begin
                dbg_ds0_accept <= dbg_ds0_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_ready) begin
                dbg_ds1_accept <= dbg_ds1_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_ready) begin
                dbg_ds2_accept <= dbg_ds2_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_ready) begin
                dbg_ds3_accept <= dbg_ds3_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_ready) begin
                dbg_ds4_accept <= dbg_ds4_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_ready) begin
                dbg_ds5_accept <= dbg_ds5_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_ready) begin
                dbg_ds6_accept <= dbg_ds6_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_ready) begin
                dbg_ds7_accept <= dbg_ds7_accept + 64'd1;
            end
            dbg_ds_error <= dbg_ds_error +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_error[0]) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_error[0]) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_error[0]) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_error[0]) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out0_error[0]) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out1_error[0]) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out2_error[0]) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_ready &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.data_splitter_0_out3_error[0]);
            dbg_rb_any_accept <= dbg_rb_any_accept +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_ready) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_ready) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_ready) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_ready) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_ready) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_ready) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_ready) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_ready);
            dbg_rb_hit_accept <= dbg_rb_hit_accept +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_data)) +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_data)) +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_data)) +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_data)) +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_data)) +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_data)) +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_data)) +
                count_if(hit2_tap_valid(u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_valid,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_ready,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_error,
                                        u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_data));
            dbg_feb_any_accept <= dbg_feb_any_accept +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_valid &&
                         u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready) +
                count_if(u_dut.data_path_subsystem.hit_type3_lower_valid &&
                         u_dut.data_path_subsystem.hit_type3_lower_ready);
            dbg_feb_hit_accept <= dbg_feb_hit_accept +
                count_if(feb_egress_vif.valid) + count_if(feb_egress_vif1.valid);
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready) begin
                if (u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_startofpacket) begin
                    feb_frame_active <= 1'b1;
                    feb_frame_word_index <= 1;
                    feb_payload_hit_region <= 1'b0;
                end else if (type3_word_is_subheader(
                    u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data)) begin
                    feb_payload_hit_region <= 1'b1;
                    if (feb_frame_active)
                        feb_frame_word_index <= feb_frame_word_index + 1;
                end else if (type3_word_is_frame_header(
                    u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data) ||
                    type3_word_is_frame_trailer(
                    u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data)) begin
                    feb_payload_hit_region <= 1'b0;
                    if (u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_endofpacket) begin
                        feb_frame_active <= 1'b0;
                        feb_frame_word_index <= 0;
                    end else if (feb_frame_active) begin
                        feb_frame_word_index <= feb_frame_word_index + 1;
                    end
                end else if (u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_endofpacket) begin
                    feb_frame_active <= 1'b0;
                    feb_frame_word_index <= 0;
                    feb_payload_hit_region <= 1'b0;
                end else if (feb_frame_active) begin
                    feb_frame_word_index <= feb_frame_word_index + 1;
                end
            end
            if (u_dut.data_path_subsystem.hit_type3_lower_valid &&
                u_dut.data_path_subsystem.hit_type3_lower_ready) begin
                if (u_dut.data_path_subsystem.hit_type3_lower_startofpacket) begin
                    feb1_frame_active <= 1'b1;
                    feb1_frame_word_index <= 1;
                    feb1_payload_hit_region <= 1'b0;
                end else if (type3_word_is_subheader(
                    u_dut.data_path_subsystem.hit_type3_lower_data)) begin
                    feb1_payload_hit_region <= 1'b1;
                    if (feb1_frame_active)
                        feb1_frame_word_index <= feb1_frame_word_index + 1;
                end else if (type3_word_is_frame_header(
                    u_dut.data_path_subsystem.hit_type3_lower_data) ||
                    type3_word_is_frame_trailer(
                    u_dut.data_path_subsystem.hit_type3_lower_data)) begin
                    feb1_payload_hit_region <= 1'b0;
                    if (u_dut.data_path_subsystem.hit_type3_lower_endofpacket) begin
                        feb1_frame_active <= 1'b0;
                        feb1_frame_word_index <= 0;
                    end else if (feb1_frame_active) begin
                        feb1_frame_word_index <= feb1_frame_word_index + 1;
                    end
                end else if (u_dut.data_path_subsystem.hit_type3_lower_endofpacket) begin
                    feb1_frame_active <= 1'b0;
                    feb1_frame_word_index <= 0;
                    feb1_payload_hit_region <= 1'b0;
                end else if (feb1_frame_active) begin
                    feb1_frame_word_index <= feb1_frame_word_index + 1;
                end
            end
            if (u_dut.data_path_subsystem.run_control_splitter_out6_valid) begin
                dbg_dp_hs_runctl_accept <= dbg_dp_hs_runctl_accept + 64'd1;
                dbg_last_hs_runctl_symbol <=
                    u_dut.data_path_subsystem.run_control_splitter_out6_data;
            end
            dbg_hs_rbcam_runctl_accept <= dbg_hs_rbcam_runctl_accept +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out0_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out1_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out2_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out3_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out0_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out1_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out2_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out3_valid);
            dbg_hs_feb_runctl_accept <= dbg_hs_feb_runctl_accept +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_valid) +
                count_if(u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_valid);
        end
    end

    initial begin
        clk_125 = 1'b0;
        forever #4000 clk_125 = ~clk_125;
    end

    initial begin
        cclk156 = 1'b0;
        forever #3200 cclk156 = ~cclk156;
    end

    initial begin
        clk_50 = 1'b0;
        forever #10000 clk_50 = ~clk_50;
    end

    initial begin
        max10_clk = 1'b0;
        forever #10000 max10_clk = ~max10_clk;
    end

    initial begin
        force u_dut.data_path_subsystem_lvds_outclock_clk = clk_125;
        force u_dut.data_path_subsystem.master_datapath_master_reset_reset = datapath_reset_req;
        force u_dut.data_path_subsystem.inject_aux_pulse = 1'b0;
    end

    initial begin
        rst = 1'b1;
        reset_n = 1'b0;
        download_sc_data = 32'h0000_0000;
        download_sc_datak = 4'h0;
        ctrl_vif.clear();
        lvds_phy_vif.clear();
        runctl_phy_vif.clear();
            sc_phy_vif.clear_master();
            sc_phy_vif.waitrequest = 1'b0;
            datapath_reset_req = 1'b1;
            repeat (32) @(posedge clk_125);
            reset_n = 1'b1;
            repeat (16) @(posedge clk_125);
            datapath_reset_req = 1'b0;
            rst = 1'b0;
        end

    always @(posedge clk_125) begin
        if (rst) begin
            sc_phy_vif.readdatavalid <= 1'b0;
            sc_phy_vif.readdata <= 32'h0000_0000;
        end else begin
            sc_phy_vif.readdatavalid <= sc_phy_vif.read;
            sc_phy_vif.readdata <= 32'h4849_5354;
        end
    end

    task automatic csr_write_emu0(input logic [3:0] addr, input logic [31:0] data);
        csr_force_addr = addr;
        csr_force_wdata = data;
        @(negedge clk_125);
        force u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_address = csr_force_addr;
        force u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_writedata = csr_force_wdata;
        force u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_read = 1'b0;
        force u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_write = 1'b1;
        @(negedge clk_125);
        force u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_write = 1'b0;
        repeat (2) @(posedge clk_125);
        release u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_write;
        release u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_read;
        release u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_writedata;
        release u_dut.data_path_subsystem.mm_interconnect_0_emulator_mutrig_0_csr_address;
    endtask

    task automatic csr_write_injector(input logic [3:0] addr, input logic [31:0] data);
        inj_csr_force_addr = addr;
        inj_csr_force_wdata = data;
        @(negedge clk_125);
        force u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_address = inj_csr_force_addr;
        force u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_writedata = inj_csr_force_wdata;
        force u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_read = 1'b0;
        force u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_write = 1'b1;
        @(negedge clk_125);
        force u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_write = 1'b0;
        repeat (2) @(posedge clk_125);
        release u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_write;
        release u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_read;
        release u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_writedata;
        release u_dut.data_path_subsystem.mm_interconnect_0_mutrig_injector_0_csr_address;
    endtask

    function automatic logic traffic_is_header_sync();
        return (traffic_mode == "header_sync");
    endfunction

    function automatic logic traffic_is_periodic();
        return (traffic_mode == "periodic");
    endfunction

    function automatic logic traffic_is_poisson();
        return (traffic_mode == "poisson");
    endfunction

    function automatic logic source_is_emu_direct();
        return (source_mode == "emu_direct");
    endfunction

    function automatic logic source_is_virtual_mutrig();
        return ((source_mode == "virtual_mutrig") || (source_mode == "virtual_mutrig_raw"));
    endfunction

    function automatic int unsigned active_hit_channel_count();
        if (hit_channel_high >= hit_channel_low)
            return hit_channel_high - hit_channel_low + 1;
        return 1;
    endfunction

    function automatic logic traffic_uses_rtl_injector();
        return traffic_is_header_sync() && (inject_driver == "rtl_injector");
    endfunction

    task automatic force_rtl_injector_headerinfo_idle();
        force u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_valid = 1'b0;
        force u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_data = 42'd0;
        force u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_channel = 4'd0;
    endtask

    task automatic release_rtl_injector_headerinfo();
        release u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_valid;
        release u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_data;
        release u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_channel;
    endtask

    task automatic configure_rtl_injector();
        force_rtl_injector_headerinfo_idle();
        csr_write_injector(INJ_CSR_MODE_ADDR, INJ_MODE_OFF);
        csr_write_injector(INJ_CSR_HEADER_CH_ADDR, 32'd0);
        csr_write_injector(INJ_CSR_HEADER_INTERVAL_ADDR, 32'd1);
        csr_write_injector(INJ_CSR_MULTIPLICITY_ADDR, 32'd1);
        csr_write_injector(INJ_CSR_PULSE_HIGH_ADDR, inject_pulse_high_cycles[31:0]);
        csr_write_injector(INJ_CSR_HEADER_DELAY_ADDR, inject_phase_cycles[31:0]);
        csr_write_injector(INJ_CSR_MODE_ADDR, INJ_MODE_HEADER_SYNC);
        `uvm_info("PROF_INT_002_INJECT",
                  $sformatf("programmed RTL mutrig_injector_0 mode=header_sync header_ch=0 delay=%0d interval=1 multiplicity=1 pulse_high=%0d",
                            inject_phase_cycles,
                            inject_pulse_high_cycles),
                  UVM_LOW)
    endtask

    task automatic configure_active_emulators();
        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_global_enable =
            active_lane_mask[0] || traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_global_enable = active_lane_mask[1];
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_global_enable = active_lane_mask[2];
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_global_enable = active_lane_mask[3];
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_global_enable = active_lane_mask[4];
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_global_enable = active_lane_mask[5];
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_global_enable = active_lane_mask[6];
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_global_enable = active_lane_mask[7];

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_hit_mode_sig = traffic_is_header_sync();

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_internal_sub_mode = traffic_is_periodic();

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_cluster_geom_mode = 1'b0;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_short_mode = mutrig_short_mode[0];

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_tx_mode = mutrig_short_mode[0] ? EMU_TX_MODE_SHORT : EMU_TX_MODE_LONG;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_gen_idle = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_gen_idle = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_gen_idle = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_gen_idle = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_gen_idle = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_gen_idle = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_gen_idle = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_gen_idle = 1'b1;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_enable_type0_stream = 1'b1;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_hit_rate = hit_rate_q16[15:0];

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_noise_rate = 16'h0000;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_noise_rate = 16'h0000;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_noise_rate = 16'h0000;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_noise_rate = 16'h0000;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_noise_rate = 16'h0000;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_noise_rate = 16'h0000;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_noise_rate = 16'h0000;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_noise_rate = 16'h0000;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_geom_fix_left_low = hit_channel_low[6:0];

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_geom_fix_left_high = hit_channel_high[6:0];

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_geom_fix_right_enable = 1'b0;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_lane_enable_mask = 8'h01;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_asic_id_base = 4'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_asic_id_base = 4'd1;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_asic_id_base = 4'd2;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_asic_id_base = 4'd3;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_asic_id_base = 4'd4;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_asic_id_base = 4'd5;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_asic_id_base = 4'd6;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_asic_id_base = 4'd7;

        if (!traffic_uses_rtl_injector()) begin
            force u_dut.data_path_subsystem.emulator_mutrig_0.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_1.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_2.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_3.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_4.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_5.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_6.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_7.coe_inject_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_0.coe_inject_masked_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_1.coe_inject_masked_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_2.coe_inject_masked_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_3.coe_inject_masked_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_4.coe_inject_masked_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_5.coe_inject_masked_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_6.coe_inject_masked_pulse = 1'b0;
            force u_dut.data_path_subsystem.emulator_mutrig_7.coe_inject_masked_pulse = 1'b0;
        end
        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.fire_inject_pulse_csr = 1'b0;
    endtask

    task automatic configure_virtual_mutrig_source();
        force u_dut.data_path_subsystem.lvds_rx_controller_pro_0_decoded0_data =
            virtual_mutrig0_tx_data;
        force u_dut.data_path_subsystem.lvds_rx_controller_pro_0_decoded0_error =
            3'b000;
        force u_dut.data_path_subsystem.lvds_rx_controller_pro_0_decoded0_channel =
            4'd0;
        `uvm_info("PROF_INT_002_SOURCE",
                  $sformatf("configured source=%s on generated decoded lane0; raw_tx_valid=%0b fifo_empty=%0b fifo_full=%0b",
                            source_mode,
                            virtual_mutrig0_tx_valid,
                            virtual_mutrig0_fifo_empty,
                            virtual_mutrig0_fifo_full),
                  UVM_LOW)
    endtask

    function automatic logic active_frame_start_seen();
        // The type0 Qsys lane wrappers use BYTE_STREAM_ENABLE=0, so there is
        // no serialized 8b/10b header pulse.  frame_start_req is the common
        // MuTRiG frame-pack boundary; the selected active ASIC still receives
        // the injection pulse through active_lane_mask.
        return u_dut.data_path_subsystem.emulator_mutrig_0
            .u_emulator_mutrig.frame_start_req;
    endfunction

    function automatic int unsigned active_frame_interval_cycles();
        return mutrig_short_mode ? MUTRIG_FRAME_CYCLES_SHORT :
                                   MUTRIG_FRAME_CYCLES_LONG;
    endfunction

    task automatic wait_active_frame_start(output logic seen);
        int unsigned wait_cycles;
        int unsigned warn_cycles;

        seen = 1'b0;
        wait_cycles = 0;
        warn_cycles = active_frame_interval_cycles() * 2;
        while (injection_window_active && !seen) begin
            @(negedge clk_125);
            if (!rst && active_frame_start_seen()) begin
                seen = 1'b1;
            end else begin
                wait_cycles++;
                if (wait_cycles == warn_cycles) begin
                    `uvm_warning("PROF_INT_002_INJECT",
                                 $sformatf("no MuTRiG frame boundary seen after %0d cycles; frame_rst0=%0b run_drain0=%0b frame_cnt0=%0d frame_req0=%0b",
                                           wait_cycles,
                                           u_dut.data_path_subsystem.emulator_mutrig_0
                                               .u_emulator_mutrig.frame_rst,
                                           u_dut.data_path_subsystem.emulator_mutrig_0
                                               .u_emulator_mutrig.run_draining,
                                           u_dut.data_path_subsystem.emulator_mutrig_0
                                               .u_emulator_mutrig.frame_interval_cnt,
                                           u_dut.data_path_subsystem.emulator_mutrig_0
                                               .u_emulator_mutrig.frame_start_req))
                end
            end
        end
    endtask

    task automatic force_emulator_inject_pulse_high(input int unsigned lane_idx);
        case (lane_idx)
            0: force u_dut.data_path_subsystem.emulator_mutrig_0.coe_inject_pulse = 1'b1;
            1: force u_dut.data_path_subsystem.emulator_mutrig_1.coe_inject_pulse = 1'b1;
            2: force u_dut.data_path_subsystem.emulator_mutrig_2.coe_inject_pulse = 1'b1;
            3: force u_dut.data_path_subsystem.emulator_mutrig_3.coe_inject_pulse = 1'b1;
            4: force u_dut.data_path_subsystem.emulator_mutrig_4.coe_inject_pulse = 1'b1;
            5: force u_dut.data_path_subsystem.emulator_mutrig_5.coe_inject_pulse = 1'b1;
            6: force u_dut.data_path_subsystem.emulator_mutrig_6.coe_inject_pulse = 1'b1;
            7: force u_dut.data_path_subsystem.emulator_mutrig_7.coe_inject_pulse = 1'b1;
            default: begin end
        endcase
    endtask

    task automatic force_emulator_inject_pulse_low(input int unsigned lane_idx);
        case (lane_idx)
            0: force u_dut.data_path_subsystem.emulator_mutrig_0.coe_inject_pulse = 1'b0;
            1: force u_dut.data_path_subsystem.emulator_mutrig_1.coe_inject_pulse = 1'b0;
            2: force u_dut.data_path_subsystem.emulator_mutrig_2.coe_inject_pulse = 1'b0;
            3: force u_dut.data_path_subsystem.emulator_mutrig_3.coe_inject_pulse = 1'b0;
            4: force u_dut.data_path_subsystem.emulator_mutrig_4.coe_inject_pulse = 1'b0;
            5: force u_dut.data_path_subsystem.emulator_mutrig_5.coe_inject_pulse = 1'b0;
            6: force u_dut.data_path_subsystem.emulator_mutrig_6.coe_inject_pulse = 1'b0;
            7: force u_dut.data_path_subsystem.emulator_mutrig_7.coe_inject_pulse = 1'b0;
            default: begin end
        endcase
    endtask

    task automatic drive_active_emulator_inject_pulse(
        input int unsigned pulse_idx,
        input logic        post_debug
    );
        @(negedge clk_125);
        for (int lane_idx = 0; lane_idx < 8; lane_idx++) begin
            if (active_lane_mask[lane_idx])
                force_emulator_inject_pulse_high(lane_idx);
        end
        `uvm_info("PROF_INT_002_INJECT",
                  $sformatf("header_sync pulse=%0d phase_cycles=%0d active_mask=%02h t=%0t coe0=%0b inj0=%0b sig0=%0b pending0=%0b ticket0=%0b",
                            pulse_idx,
                            inject_phase_cycles,
                            active_lane_mask,
                            $time,
                            u_dut.data_path_subsystem.emulator_mutrig_0.coe_inject_pulse,
                            u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.inject_pulse,
                            u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.sig_offer_valid,
                            u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                .lane_gen[0].u_lane_emitter.pending_valid,
                            u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                .lane_gen[0].u_lane_emitter.ticket_valid),
                  UVM_LOW)
        @(negedge clk_125);
        for (int lane_idx = 0; lane_idx < 8; lane_idx++) begin
            if (active_lane_mask[lane_idx])
                force_emulator_inject_pulse_low(lane_idx);
        end
        if (post_debug && pulse_idx < 8) begin
            repeat (6) @(posedge clk_125);
            `uvm_info("PROF_INT_002_INJECT",
                      $sformatf("header_sync pulse=%0d post6 inj0=%0b sig0=%0b sig_ready0=%0b ticket0=%0b ticket_ready0=%0b ticket_count0=%0d pending0=%0b l2_level0=%0d hit_count0=%0d",
                                pulse_idx,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.inject_pulse,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.sig_offer_valid,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.sig_offer_ready,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.fe_ticket_valid[0],
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.fe_ticket_ready[0],
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                    .lane_gen[0].u_lane_emitter.ticket_count,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                    .lane_gen[0].u_lane_emitter.pending_valid,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                    .lane_gen[0].u_lane_emitter.l2_level,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                    .lane_hit_count[0]),
                      UVM_LOW)
        end
    endtask

    task automatic drive_rtl_injector_headerinfo_pulse(input int unsigned pulse_idx);
        force u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_valid = 1'b1;
        force u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_data = 42'd0;
        force u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_channel = 4'd0;
        `uvm_info("PROF_INT_002_INJECT",
                  $sformatf("rtl_injector virtual MuTRiG header=%0d interval=%0d csr_delay=%0d active_mask=%02h t=%0t inj_raw=%0b fanout=%0b emu0_inj=%0b",
                            pulse_idx,
                            active_frame_interval_cycles(),
                            inject_phase_cycles,
                            active_lane_mask,
                            $time,
                            u_dut.data_path_subsystem.mutrig_injector_0_inject_pulse,
                            inject_pulse,
                            u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.inject_pulse),
                  UVM_LOW)
        @(negedge clk_125);
        force u_dut.data_path_subsystem.mutrig_frame_deassembly_0_headerinfo_valid = 1'b0;
    endtask

    task automatic drive_header_sync_injections();
        int unsigned sent;
        int unsigned frame_interval;
        logic frame_seen;

        sent = 0;
        frame_interval = active_frame_interval_cycles();
        if (traffic_uses_rtl_injector()) begin
            wait_active_frame_start(frame_seen);
            while (injection_window_active &&
                   frame_seen &&
                   (inject_pulse_count == 0 || sent < inject_pulse_count)) begin
                drive_rtl_injector_headerinfo_pulse(sent);
                sent++;
                if (!injection_window_active ||
                    (inject_pulse_count != 0 && sent >= inject_pulse_count))
                    break;
                if (frame_interval > 1)
                    repeat (frame_interval - 1) @(posedge clk_125);
                @(negedge clk_125);
            end
            force_rtl_injector_headerinfo_idle();
            `uvm_info("PROF_INT_002_INJECT",
                      $sformatf("rtl_injector virtual-header driver done headers=%0d requested=%0d interval=%0d",
                                sent, inject_pulse_count, frame_interval),
                      UVM_LOW)
            return;
        end
        if (inject_frame_count != 0) begin
            int unsigned frame_sent;

            frame_sent = 0;
            while (injection_window_active && frame_sent < inject_frame_count) begin
                wait_active_frame_start(frame_seen);
                if (!injection_window_active || !frame_seen)
                    break;
                repeat (inject_phase_cycles) @(posedge clk_125);
                for (int unsigned burst_idx = 0;
                     burst_idx < inject_burst_count && injection_window_active;
                     burst_idx++) begin
                    drive_active_emulator_inject_pulse(sent, 1'b0);
                    sent++;
                    if (burst_idx + 1 < inject_burst_count &&
                        inject_burst_spacing_cycles > 1)
                        repeat (inject_burst_spacing_cycles - 1) @(posedge clk_125);
                end
                frame_sent++;
            end
            `uvm_info("PROF_INT_002_INJECT",
                      $sformatf("header_sync frame-burst injection driver done frames=%0d requested_frames=%0d pulses=%0d burst_count=%0d burst_spacing=%0d phase=%0d active_mask=%02h",
                                frame_sent,
                                inject_frame_count,
                                sent,
                                inject_burst_count,
                                inject_burst_spacing_cycles,
                                inject_phase_cycles,
                                active_lane_mask),
                      UVM_LOW)
            return;
        end
        while (injection_window_active &&
               (inject_pulse_count == 0 || sent < inject_pulse_count)) begin
            wait_active_frame_start(frame_seen);
            if (!injection_window_active || !frame_seen)
                break;
            repeat (inject_phase_cycles) @(posedge clk_125);
            if (!injection_window_active)
                break;
            drive_active_emulator_inject_pulse(sent, 1'b1);
            sent++;
        end
        `uvm_info("PROF_INT_002_INJECT",
                  $sformatf("header_sync injection driver done pulses=%0d requested=%0d",
                            sent, inject_pulse_count),
                  UVM_LOW)
    endtask

    task automatic drive_runctl(input logic [8:0] symbol,
                                input int unsigned hold_cycles);
        runctl_force_symbol = symbol;
        @(negedge clk_125);
        force u_dut.upload_subsystem_runctl_mgmt_host_data = runctl_force_symbol;
        force u_dut.upload_subsystem_runctl_mgmt_host_valid = 1'b1;
        repeat (hold_cycles)
            @(negedge clk_125);
        `uvm_info("PROF_INT_002_TOP",
                  $sformatf("run-control %03h driven readyless for %0d cycles",
                            symbol,
                            hold_cycles),
                  UVM_LOW)
        force u_dut.upload_subsystem_runctl_mgmt_host_valid = 1'b0;
        @(negedge clk_125);
        release u_dut.upload_subsystem_runctl_mgmt_host_valid;
        release u_dut.upload_subsystem_runctl_mgmt_host_data;
        endtask

    function automatic logic [5:0] hit_stack0_runctl_valid_vec();
        hit_stack0_runctl_valid_vec = {
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out5_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out3_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out1_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out0_valid
        };
    endfunction

    function automatic logic [5:0] hit_stack1_runctl_valid_vec();
        hit_stack1_runctl_valid_vec = {
            u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out5_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out3_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out1_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out0_valid
        };
    endfunction

    function automatic logic [15:0] arb_csr_mode_vec();
        arb_csr_mode_vec = {
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_7.csr_mode,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_6.csr_mode,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_5.csr_mode,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_4.csr_mode,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_3.csr_mode,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_2.csr_mode,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_1.csr_mode,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.csr_mode
        };
    endfunction

    function automatic logic [23:0] arb_runctl_state_vec();
        arb_runctl_state_vec = {
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_7.runctl_state,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_6.runctl_state,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_5.runctl_state,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_4.runctl_state,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_3.runctl_state,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_2.runctl_state,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_1.runctl_state,
            u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.runctl_state
        };
    endfunction

    task automatic report_hit_stack_runctl_broadcast(input string tag);
        `uvm_info("PROF_INT_002_TOP",
                  $sformatf("%s readyless run-control broadcast valid={%06b,%06b}; acceptance is checked by MTS/rbCAM CSR state",
                            tag,
                            hit_stack1_runctl_valid_vec(),
                            hit_stack0_runctl_valid_vec()),
                  UVM_LOW)
    endtask

    task automatic observe_runctl_cpp_gap(input string tag);
        if (runctl_cpp_gap_cycles != 0)
            repeat (runctl_cpp_gap_cycles) @(posedge clk_125);
        `uvm_info("PROF_INT_002_TOP",
                  $sformatf("%s observed software-scale run-control gap cycles=%0d",
                            tag,
                            runctl_cpp_gap_cycles),
                  UVM_LOW)
    endtask

    task automatic csr_write_arb_lane(input int unsigned lane_idx,
                                      input logic [4:0] addr,
                                      input logic [31:0] data);
        arb_csr_force_addr = addr;
        arb_csr_force_wdata = data;
        @(negedge clk_125);
        case (lane_idx)
            0: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_write = 1'b1;
            end
            1: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_write = 1'b1;
            end
            2: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_write = 1'b1;
            end
            3: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_write = 1'b1;
            end
            4: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_write = 1'b1;
            end
            5: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_write = 1'b1;
            end
            6: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_write = 1'b1;
            end
            7: begin
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_address = arb_csr_force_addr;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_writedata = arb_csr_force_wdata;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_read = 1'b0;
                force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_write = 1'b1;
            end
            default: begin
                `uvm_error("PROF_INT_002_ARB_CSR",
                           $sformatf("invalid arb CSR lane index %0d", lane_idx))
                return;
            end
        endcase
        @(negedge clk_125);
        case (lane_idx)
            0: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_write = 1'b0;
            1: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_write = 1'b0;
            2: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_write = 1'b0;
            3: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_write = 1'b0;
            4: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_write = 1'b0;
            5: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_write = 1'b0;
            6: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_write = 1'b0;
            7: force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_write = 1'b0;
            default: begin end
        endcase
        repeat (2) @(posedge clk_125);
        case (lane_idx)
            0: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_address;
            end
            1: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_1_address;
            end
            2: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_2_address;
            end
            3: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_3_address;
            end
            4: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_4_address;
            end
            5: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_5_address;
            end
            6: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_6_address;
            end
            7: begin
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_write;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_read;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_writedata;
                release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_7_address;
            end
            default: begin end
        endcase
    endtask

    task automatic configure_active_arb_lanes();
        int unsigned programmed;
        logic [31:0] selected_mode;

        programmed = 0;
        selected_mode = source_is_virtual_mutrig() ? ARB_MODE_REAL : ARB_MODE_EMU;
        for (int lane_idx = 0; lane_idx < 8; lane_idx++) begin
            if (active_lane_mask[lane_idx]) begin
                csr_write_arb_lane(lane_idx, ARB_CSR_CONTROL_ADDR, selected_mode);
                programmed++;
            end
        end
        `uvm_info("PROF_INT_002_ARB_CSR",
                  $sformatf("programmed active arb lanes source=%s mode=%0d mask=%02h count=%0d mode_vec=%04h",
                            source_mode,
                            selected_mode,
                            active_lane_mask,
                            programmed,
                            arb_csr_mode_vec()),
                  UVM_LOW)
    endtask

`define PROF_INT_002_CSR_READ(ADDR_SIG, READ_SIG, WRITE_SIG, ADDR_VALUE, RDATA_SIG, DATA_VAR) \
    begin \
        @(negedge clk_125); \
        force ADDR_SIG = ADDR_VALUE; \
        force READ_SIG = 1'b1; \
        force WRITE_SIG = 1'b0; \
        @(posedge clk_125); \
        @(negedge clk_125); \
        DATA_VAR = RDATA_SIG; \
        force READ_SIG = 1'b0; \
        release WRITE_SIG; \
        release READ_SIG; \
        release ADDR_SIG; \
    end

    task automatic report_rbcam_csr_state(input string tag);
        logic [31:0] ctrl [0:7];
        logic [31:0] fill [0:7];
        logic [31:0] push [0:7];
        logic [31:0] pop  [0:7];
        logic [3:0]  state_code [0:7];
        logic [7:0]  go_vec;
        logic [7:0]  running_vec;

        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_readdata,
                               ctrl[0])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_readdata,
                               ctrl[1])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_readdata,
                               ctrl[2])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_readdata,
                               ctrl[3])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_readdata,
                               ctrl[4])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_readdata,
                               ctrl[5])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_readdata,
                               ctrl[6])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_write,
                               5'd2,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_readdata,
                               ctrl[7])

        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_readdata,
                               fill[0])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_readdata,
                               fill[1])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_readdata,
                               fill[2])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_readdata,
                               fill[3])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_readdata,
                               fill[4])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_readdata,
                               fill[5])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_readdata,
                               fill[6])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_write,
                               5'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_readdata,
                               fill[7])

        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_readdata,
                               push[0])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_readdata,
                               push[1])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_readdata,
                               push[2])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_readdata,
                               push[3])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_readdata,
                               push[4])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_readdata,
                               push[5])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_readdata,
                               push[6])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_write,
                               5'd6,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_readdata,
                               push[7])

        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_0_csr_readdata,
                               pop[0])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_1_csr_readdata,
                               pop[1])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_2_csr_readdata,
                               pop[2])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_0_ring_buffer_cam_3_csr_readdata,
                               pop[3])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_0_csr_readdata,
                               pop[4])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_1_csr_readdata,
                               pop[5])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_2_csr_readdata,
                               pop[6])
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_write,
                               5'd7,
                               u_dut.data_path_subsystem.mm_interconnect_0_hit_stack_subsystem_1_ring_buffer_cam_3_csr_readdata,
                               pop[7])

        state_code[0] = u_dut.data_path_subsystem.hit_stack_subsystem_0
            .ring_buffer_cam_0.v2_core.dbg_run_state_code;
        state_code[1] = u_dut.data_path_subsystem.hit_stack_subsystem_0
            .ring_buffer_cam_1.v2_core.dbg_run_state_code;
        state_code[2] = u_dut.data_path_subsystem.hit_stack_subsystem_0
            .ring_buffer_cam_2.v2_core.dbg_run_state_code;
        state_code[3] = u_dut.data_path_subsystem.hit_stack_subsystem_0
            .ring_buffer_cam_3.v2_core.dbg_run_state_code;
        state_code[4] = u_dut.data_path_subsystem.hit_stack_subsystem_1
            .ring_buffer_cam_0.v2_core.dbg_run_state_code;
        state_code[5] = u_dut.data_path_subsystem.hit_stack_subsystem_1
            .ring_buffer_cam_1.v2_core.dbg_run_state_code;
        state_code[6] = u_dut.data_path_subsystem.hit_stack_subsystem_1
            .ring_buffer_cam_2.v2_core.dbg_run_state_code;
        state_code[7] = u_dut.data_path_subsystem.hit_stack_subsystem_1
            .ring_buffer_cam_3.v2_core.dbg_run_state_code;
        go_vec = {ctrl[7][0], ctrl[6][0], ctrl[5][0], ctrl[4][0],
                  ctrl[3][0], ctrl[2][0], ctrl[1][0], ctrl[0][0]};
        running_vec = {(state_code[7] == 4'd3), (state_code[6] == 4'd3),
                       (state_code[5] == 4'd3), (state_code[4] == 4'd3),
                       (state_code[3] == 4'd3), (state_code[2] == 4'd3),
                       (state_code[1] == 4'd3), (state_code[0] == 4'd3)};
        `uvm_info("PROF_INT_002_RBCAM_CSR",
                  $sformatf("%s rbcam_csr go=%08b run_state_running=%08b run_state_code_direct={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d} ctrl={%08h,%08h,%08h,%08h,%08h,%08h,%08h,%08h} fill={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d} push={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d} pop={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d}",
                            tag,
                            go_vec,
                            running_vec,
                            state_code[7], state_code[6], state_code[5], state_code[4],
                            state_code[3], state_code[2], state_code[1], state_code[0],
                            ctrl[7], ctrl[6], ctrl[5], ctrl[4],
                            ctrl[3], ctrl[2], ctrl[1], ctrl[0],
                            fill[7], fill[6], fill[5], fill[4],
                            fill[3], fill[2], fill[1], fill[0],
                            push[7], push[6], push[5], push[4],
                            push[3], push[2], push[1], push[0],
                            pop[7], pop[6], pop[5], pop[4],
                            pop[3], pop[2], pop[1], pop[0]),
                  UVM_LOW)
        if (go_vec !== 8'hff) begin
            `uvm_error("PROF_INT_002_RBCAM_CSR",
                       $sformatf("%s rbCAM GO readback not all asserted: go=%08b",
                                 tag,
                                 go_vec))
        end
        if (running_vec !== 8'hff) begin
            `uvm_error("PROF_INT_002_RBCAM_CSR",
                       $sformatf("%s rbCAM run_state not all RUNNING: running=%08b state_code={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d}",
                                 tag,
                                 running_vec,
                                 state_code[7], state_code[6], state_code[5], state_code[4],
                                 state_code[3], state_code[2], state_code[1], state_code[0]))
        end
    endtask

    task automatic report_mts_csr_state(input string tag);
        logic [31:0] ctrl0;
        logic [31:0] ctrl1;
        logic [31:0] discard0;
        logic [31:0] discard1;
        logic [31:0] total_hi0;
        logic [31:0] total_hi1;
        logic [31:0] total_lo0;
        logic [31:0] total_lo1;
        logic [1:0]  go_vec;

        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_write,
                               3'd0,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_readdata,
                               ctrl0)
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_write,
                               3'd0,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_readdata,
                               ctrl1)
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_write,
                               3'd1,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_readdata,
                               discard0)
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_write,
                               3'd1,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_readdata,
                               discard1)
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_write,
                               3'd3,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_readdata,
                               total_hi0)
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_write,
                               3'd3,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_readdata,
                               total_hi1)
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_write,
                               3'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_0_csr_readdata,
                               total_lo0)
        `PROF_INT_002_CSR_READ(u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_address,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_read,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_write,
                               3'd4,
                               u_dut.data_path_subsystem.mm_interconnect_0_mts_preprocessor_1_csr_readdata,
                               total_lo1)

        go_vec = {ctrl1[0], ctrl0[0]};
        `uvm_info("PROF_INT_002_MTS_CSR",
                  $sformatf("%s mts_csr go=%02b ctrl={%08h,%08h} discard={%0d,%0d} total={%04h_%08h,%04h_%08h}",
                            tag,
                            go_vec,
                            ctrl1,
                            ctrl0,
                            discard1,
                            discard0,
                            total_hi1[15:0],
                            total_lo1,
                            total_hi0[15:0],
                            total_lo0),
                  UVM_LOW)
        if (go_vec !== 2'b11) begin
            `uvm_error("PROF_INT_002_MTS_CSR",
                       $sformatf("%s MTS GO not both asserted in CSR readback: go=%02b ctrl={%08h,%08h}",
                                 tag,
                                 go_vec,
                                 ctrl1,
                                 ctrl0))
        end
    endtask

    task automatic report_datapath_state(input string tag);
        `uvm_info("PROF_INT_002_TOP",
                  $sformatf("%s rst_top=%0b rst_dp=%0b emu_ctrl=%03h emu_ctrl_valid=%0b type0_ctrl=%03h type0_ctrl_valid=%0b ctrl_state=%03h run_gen=%0b cfg_global=%0b cfg_rate=%0d l2_level=%0d lane_hits=%0d arb_mode=%0d arb_run=%0d arb_mode_vec=%04h arb_run_vec=%06h emu_h0_v=%0b emu_h0_ch=%0d emu_accept=%0b emu_drop=%0b emu_depth=%0d emu_empty=%0b arb_aso_v=%0b bp0_in_v=%0b bp0_out_v=%0b mux_v=%02b mts_v=%02b hisb_pre_v=%0b hs_in_rdy=%0b rc_v0=%06b rc_v1=%06b rb_v0=%04b rb_v1=%04b rb_rdy0=%04b rb_rdy1=%04b hit3_v=%02b hit3_rdy=%02b",
                            tag,
                            u_dut.rst_controller_reset_out_reset,
                                u_dut.data_path_subsystem.rst_controller_reset_out_reset,
                                u_dut.data_path_subsystem.emulator_ctrl_splitter_out0_data,
                                u_dut.data_path_subsystem.emulator_ctrl_splitter_out0_valid,
                                u_dut.data_path_subsystem.run_control_splitter_out2_data,
                                u_dut.data_path_subsystem.run_control_splitter_out2_valid,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.ctrl_state_q,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.run_generating,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_global_enable,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_hit_rate,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                    .lane_gen[0].u_lane_emitter.l2_level,
                                u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig
                                    .lane_hit_count[0],
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.csr_mode,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.runctl_state,
                                arb_csr_mode_vec(),
                                arb_runctl_state_vec(),
                                u_dut.data_path_subsystem.emulator_mutrig_0_hit_type0_valid,
                                u_dut.data_path_subsystem.emulator_mutrig_0_hit_type0_channel,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_push_accept,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_push_drop,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_fifo_depth,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_fifo_empty,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0_selected_out_0_valid,
                                u_dut.data_path_subsystem.avalon_st_adapter_026_out_0_valid,
                                u_dut.data_path_subsystem.backpressure_fifo_0_out_valid,
                                {u_dut.data_path_subsystem.mux_mutrig2processor_0_out_valid,
                                 u_dut.data_path_subsystem.mux_mutrig2processor_out_valid},
                                {u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_valid,
                                 u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid},
                                u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_valid,
                                u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_ready,
                                hit_stack0_runctl_valid_vec(),
                                hit_stack1_runctl_valid_vec(),
                                {u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid},
                                {u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_valid},
                                {u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_ready},
                                {u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_3_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_2_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_1_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_1.ring_buffer_cam_0_hit_type2_ready},
                                {u_dut.data_path_subsystem.hit_type3_lower_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_valid},
                                {u_dut.data_path_subsystem.hit_type3_lower_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready}),
                  UVM_LOW)
        `uvm_info("PROF_INT_002_MON_BIND",
                  $sformatf("%s monitor_bind stage_a=%08b pre=%08b post=%08b feb=%02b mts_in={v=%02b r=%02b} mts_out={v=%02b r=%02b err=%02b} stack_rc_valid={%06b,%06b}",
                            tag,
                            {stage_a_vif7.valid, stage_a_vif6.valid,
                             stage_a_vif5.valid, stage_a_vif4.valid,
                             stage_a_vif3.valid, stage_a_vif2.valid,
                             stage_a_vif1.valid, stage_a_vif0.valid},
                            {pre_rbcam_vif7.valid, pre_rbcam_vif6.valid,
                             pre_rbcam_vif5.valid, pre_rbcam_vif4.valid,
                             pre_rbcam_vif3.valid, pre_rbcam_vif2.valid,
                             pre_rbcam_vif1.valid, pre_rbcam_vif0.valid},
                            {post_rbcam_vif7.valid, post_rbcam_vif6.valid,
                             post_rbcam_vif5.valid, post_rbcam_vif4.valid,
                             post_rbcam_vif3.valid, post_rbcam_vif2.valid,
                             post_rbcam_vif1.valid, post_rbcam_vif0.valid},
                            {feb_egress_vif1.valid, feb_egress_vif.valid},
                            {u_dut.data_path_subsystem.mux_mutrig2processor_0_out_valid,
                             u_dut.data_path_subsystem.mux_mutrig2processor_out_valid},
                            {u_dut.data_path_subsystem.mux_mutrig2processor_0_out_ready,
                             u_dut.data_path_subsystem.mux_mutrig2processor_out_ready},
                            {u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_valid,
                             u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid},
                            {u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_ready,
                             u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_ready},
                            {u_dut.data_path_subsystem.mts_preprocessor_1_hit_type1_out_error,
                             u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_error},
                            hit_stack1_runctl_valid_vec(),
                            hit_stack0_runctl_valid_vec()),
                  UVM_LOW)
        `uvm_info("PROF_INT_002_COUNTERS",
                  $sformatf("%s counts arb_bp=%0d bp_mux=%0d mux_mts=%0d mts_out=%0d mts_err=%0d hisb_pre=%0d hisb_err=%0d ds={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d} ds_err=%0d rb_any=%0d rb_hit=%0d feb_any=%0d feb_hit=%0d hs_runctl=%0d rb_runctl=%0d feb_runctl=%0d last_hs_runctl=%03h",
                                tag,
                                dbg_arb_bp_accept,
                                dbg_bp_mux_accept,
                                dbg_mux_mts_accept,
                                dbg_mts_out_accept,
                                dbg_mts_out_error,
                                dbg_hisb_pre_accept,
                                dbg_hisb_pre_error,
                                dbg_ds0_accept,
                                dbg_ds1_accept,
                                dbg_ds2_accept,
                                dbg_ds3_accept,
                                dbg_ds4_accept,
                                dbg_ds5_accept,
                                dbg_ds6_accept,
                                dbg_ds7_accept,
                                dbg_ds_error,
                                dbg_rb_any_accept,
                                dbg_rb_hit_accept,
                                dbg_feb_any_accept,
                                dbg_feb_hit_accept,
                                dbg_dp_hs_runctl_accept,
                                dbg_hs_rbcam_runctl_accept,
                                dbg_hs_feb_runctl_accept,
                                dbg_last_hs_runctl_symbol),
                  UVM_LOW)
    endtask

    initial begin : uvm_setup
        uvm_config_db#(virtual lvds_phy_if)::set(null,
                                                 "uvm_test_top.env.mutrig_phy.drv",
                                                 "vif",
                                                 lvds_phy_vif);
        uvm_config_db#(virtual runctl_phy_if)::set(null,
                                                   "uvm_test_top.env.runctl_phy.drv",
                                                   "vif",
                                                   runctl_phy_vif);
        uvm_config_db#(virtual sc_avmm_if)::set(null,
                                                "uvm_test_top.env.sc_phy.drv",
                                                "vif",
                                                sc_phy_vif);
        uvm_config_db#(virtual sc_avmm_if)::set(null,
                                                "uvm_test_top.env.histogram_mon",
                                                "vif",
                                                sc_phy_vif);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon0", "vif", stage_a_vif0);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon1", "vif", stage_a_vif1);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon2", "vif", stage_a_vif2);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon3", "vif", stage_a_vif3);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon4", "vif", stage_a_vif4);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon5", "vif", stage_a_vif5);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon6", "vif", stage_a_vif6);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top.env.l2_commit_mon7", "vif", stage_a_vif7);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null, "uvm_test_top", "stage_a_vif", stage_a_vif0);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon0", "vif", debug_source_vif0);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon1", "vif", debug_source_vif1);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon2", "vif", debug_source_vif2);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon3", "vif", debug_source_vif3);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon4", "vif", debug_source_vif4);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon5", "vif", debug_source_vif5);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon6", "vif", debug_source_vif6);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.debug_source_mon7", "vif", debug_source_vif7);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon0", "vif", pre_rbcam_vif0);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon1", "vif", pre_rbcam_vif1);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon2", "vif", pre_rbcam_vif2);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon3", "vif", pre_rbcam_vif3);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon4", "vif", pre_rbcam_vif4);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon5", "vif", pre_rbcam_vif5);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon6", "vif", pre_rbcam_vif6);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon7", "vif", pre_rbcam_vif7);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon0", "vif", post_rbcam_vif0);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon1", "vif", post_rbcam_vif1);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon2", "vif", post_rbcam_vif2);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon3", "vif", post_rbcam_vif3);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon4", "vif", post_rbcam_vif4);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon5", "vif", post_rbcam_vif5);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon6", "vif", post_rbcam_vif6);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon7", "vif", post_rbcam_vif7);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.feb_egress_mon0", "vif", feb_egress_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.feb_egress_mon1", "vif", feb_egress_vif1);
        uvm_config_db#(virtual tb_int_counter_if)::set(null,
                                                       "uvm_test_top.env.scoreboard",
                                                       "counter_vif",
                                                       counter_vif);
        uvm_config_db#(virtual prof_int_002_ctrl_if)::set(null,
                                                          "uvm_test_top",
                                                          "ctrl_vif",
                                                          ctrl_vif);
        run_test();
    end

    initial begin : full_pipeline_controller
        int unsigned plus_lane_count;
        int unsigned plus_lane_mask;
        int unsigned lane_idx;
        int plus_run_cycles;
        int plus_drain_cycles;
        int plus_stable_window_cycles;
        int plus_legacy_guard_cycles;
        int plus_hit_rate_q16;
        int plus_hit_channel_low;
        int plus_hit_channel_high;
        int plus_mutrig_short_mode;
        int plus_inject_phase_cycles;
        int plus_inject_pulse_count;
        int plus_inject_pulse_high_cycles;
        int plus_inject_frame_count;
        int plus_inject_burst_count;
        int plus_inject_burst_spacing_cycles;
        int plus_runctl_cpp_gap_cycles;
        int plus_runctl_settle_timeout_cycles;
        string plus_traffic_mode;
        string plus_inject_driver;
        string plus_source_mode;
        string plus_latency_scope;
        bit legacy_guard_plus_seen;

        run_cycles = 12_500_000;
        drain_cycles = 16_384;
        stable_window_cycles = 0;
        stable_capture_cycles = 0;
        stable_pre_guard_cycles = 0;
        stable_post_guard_cycles = 0;
        hit_rate_q16 = 52;
        hit_channel_low = 0;
        hit_channel_high = 15;
        mutrig_short_mode = 0;
        inject_phase_cycles = 100;
        inject_pulse_count = 0;
        inject_pulse_high_cycles = 5;
        inject_frame_count = 0;
        inject_burst_count = 1;
        inject_burst_spacing_cycles = 10;
        runctl_cpp_gap_cycles = 125_000;
        runctl_settle_timeout_cycles = 1_250_000;
        traffic_mode = "poisson";
        inject_driver = "tb_force";
        source_mode = "emu_direct";
        latency_scope = "full";
        active_lane_count = 1;
        active_lane_mask = 8'h01;
        active_lane_mask_popcount = 0;
        stage_a_lane_index = 3'd0;
        injection_window_active = 1'b0;
        legacy_guard_plus_seen = 1'b0;
        if ($value$plusargs("TB_INT_RUN_CYCLES=%d", plus_run_cycles))
            run_cycles = plus_run_cycles;
        if ($value$plusargs("TB_INT_DRAIN_CYCLES=%d", plus_drain_cycles))
            drain_cycles = plus_drain_cycles;
        if ($value$plusargs("TB_INT_STABLE_WINDOW_CYCLES=%d", plus_stable_window_cycles)) begin
            stable_window_cycles = plus_stable_window_cycles;
        end else if ($value$plusargs("TB_INT_STABLE_GUARD_CYCLES=%d", plus_legacy_guard_cycles)) begin
            legacy_guard_plus_seen = 1'b1;
        end
        if ($value$plusargs("PROF_INT_002_HIT_RATE_Q16=%d", plus_hit_rate_q16))
            hit_rate_q16 = plus_hit_rate_q16;
        if ($value$plusargs("TB_INT_HIT_CHANNEL_LOW=%d", plus_hit_channel_low))
            hit_channel_low = plus_hit_channel_low;
        if ($value$plusargs("TB_INT_HIT_CHANNEL_HIGH=%d", plus_hit_channel_high))
            hit_channel_high = plus_hit_channel_high;
        if ($value$plusargs("TB_INT_MUTRIG_SHORT_MODE=%d", plus_mutrig_short_mode))
            mutrig_short_mode = plus_mutrig_short_mode;
        if ($value$plusargs("TB_INT_INJECT_PHASE_CYCLES=%d", plus_inject_phase_cycles))
            inject_phase_cycles = plus_inject_phase_cycles;
        if ($value$plusargs("TB_INT_INJECT_PULSE_COUNT=%d", plus_inject_pulse_count))
            inject_pulse_count = plus_inject_pulse_count;
        if ($value$plusargs("TB_INT_INJECT_PULSE_HIGH_CYCLES=%d", plus_inject_pulse_high_cycles))
            inject_pulse_high_cycles = plus_inject_pulse_high_cycles;
        if ($value$plusargs("TB_INT_INJECT_FRAME_COUNT=%d", plus_inject_frame_count))
            inject_frame_count = plus_inject_frame_count;
        if ($value$plusargs("TB_INT_INJECT_BURST_COUNT=%d", plus_inject_burst_count))
            inject_burst_count = plus_inject_burst_count;
        if ($value$plusargs("TB_INT_INJECT_BURST_SPACING_CYCLES=%d", plus_inject_burst_spacing_cycles))
            inject_burst_spacing_cycles = plus_inject_burst_spacing_cycles;
        if ($value$plusargs("TB_INT_TRAFFIC_MODE=%s", plus_traffic_mode))
            traffic_mode = plus_traffic_mode;
        if ($value$plusargs("TB_INT_INJECT_DRIVER=%s", plus_inject_driver))
            inject_driver = plus_inject_driver;
        if ($value$plusargs("TB_INT_SOURCE=%s", plus_source_mode))
            source_mode = plus_source_mode;
        if ($value$plusargs("TB_INT_LATENCY_SCOPE=%s", plus_latency_scope))
            latency_scope = plus_latency_scope;
        if ($value$plusargs("TB_INT_RUNCTL_CPP_GAP_CYCLES=%d", plus_runctl_cpp_gap_cycles))
            runctl_cpp_gap_cycles = plus_runctl_cpp_gap_cycles;
        if ($value$plusargs("TB_INT_RUNCTL_SETTLE_TIMEOUT_CYCLES=%d", plus_runctl_settle_timeout_cycles))
            runctl_settle_timeout_cycles = plus_runctl_settle_timeout_cycles;
        if ($value$plusargs("TB_INT_ACTIVE_LANE_COUNT=%d", plus_lane_count))
            active_lane_count = plus_lane_count;
        if ($value$plusargs("TB_INT_ACTIVE_LANE_MASK=%h", plus_lane_mask))
            active_lane_mask = plus_lane_mask[7:0];
        if (active_lane_count < 1)
            active_lane_count = 1;
        if (active_lane_mask == 8'h00)
            active_lane_mask = 8'h01;
        if (!(traffic_is_header_sync() || traffic_is_periodic() || traffic_is_poisson())) begin
            `uvm_warning("PROF_INT_002_TOP",
                         $sformatf("unknown TB_INT_TRAFFIC_MODE=%s; falling back to poisson",
                                   traffic_mode))
            traffic_mode = "poisson";
        end
        if (!((inject_driver == "tb_force") || (inject_driver == "rtl_injector"))) begin
            `uvm_warning("PROF_INT_002_TOP",
                         $sformatf("unknown TB_INT_INJECT_DRIVER=%s; falling back to tb_force",
                                   inject_driver))
            inject_driver = "tb_force";
        end
        if (!(source_is_emu_direct() || source_is_virtual_mutrig())) begin
            `uvm_warning("PROF_INT_002_TOP",
                         $sformatf("unknown TB_INT_SOURCE=%s; falling back to emu_direct",
                                   source_mode))
            source_mode = "emu_direct";
        end
        if (source_mode == "virtual_mutrig_raw") begin
            `uvm_info("PROF_INT_002_TOP",
                      "TB_INT_SOURCE=virtual_mutrig_raw is deprecated; using virtual_mutrig",
                      UVM_LOW)
            source_mode = "virtual_mutrig";
        end
        if (!((latency_scope == "full") ||
              (latency_scope == "pre_rbcam") ||
              (latency_scope == "post_rbcam"))) begin
            `uvm_warning("PROF_INT_002_TOP",
                         $sformatf("unknown TB_INT_LATENCY_SCOPE=%s; falling back to full",
                                   latency_scope))
            latency_scope = "full";
        end
        if (((latency_scope == "full") || (latency_scope == "post_rbcam")) &&
            (runctl_cpp_gap_cycles < 125_000)) begin
            `uvm_error("PROF_INT_002_TOP",
                       $sformatf("TB_INT_RUNCTL_CPP_GAP_CYCLES=%0d is below the DV_PLAN 1 ms software-scale gap required for post-rbCAM/FEB latency closure",
                                 runctl_cpp_gap_cycles))
        end
        if (source_is_virtual_mutrig()) begin
            if (traffic_is_poisson()) begin
                `uvm_warning("PROF_INT_002_TOP",
                             "virtual_mutrig source supports periodic/header_sync in PROF-INT-002; falling back to periodic")
                traffic_mode = "periodic";
            end
            if ((active_lane_mask != 8'h01) || (active_lane_count != 1)) begin
                `uvm_warning("PROF_INT_002_TOP",
                             $sformatf("virtual_mutrig first bring-up is lane0-only; overriding active_lanes=%0d mask=%02h to 1/01",
                                       active_lane_count,
                                       active_lane_mask))
                active_lane_count = 1;
                active_lane_mask = 8'h01;
            end
        end
        if (inject_pulse_high_cycles < 1)
            inject_pulse_high_cycles = 1;
        if (inject_pulse_high_cycles > 255)
            inject_pulse_high_cycles = 255;
        if (inject_burst_count < 1)
            inject_burst_count = 1;
        if (inject_burst_count > 64)
            inject_burst_count = 64;
        if (inject_burst_spacing_cycles < 1)
            inject_burst_spacing_cycles = 1;
        if (hit_channel_low > 31)
            hit_channel_low = 31;
        if (hit_channel_high > 31)
            hit_channel_high = 31;
        if (hit_channel_high < hit_channel_low)
            hit_channel_high = hit_channel_low;

        active_lane_mask_popcount = 0;
        for (lane_idx = 0; lane_idx < 8; lane_idx++) begin
            if (active_lane_mask[lane_idx])
                active_lane_mask_popcount++;
        end
        for (lane_idx = 0; lane_idx < 8; lane_idx++) begin
            if (active_lane_mask[lane_idx]) begin
                stage_a_lane_index = lane_idx[2:0];
                break;
            end
        end

        ctrl_vif.sim_failed = 1'b0;
        if (active_lane_count != active_lane_mask_popcount) begin
            `uvm_warning("PROF_INT_002_TOP",
                         $sformatf("active lane count=%0d does not match popcount(active_mask=%02h)=%0d",
                                   active_lane_count, active_lane_mask, active_lane_mask_popcount))
            active_lane_count = active_lane_mask_popcount;
        end

        if (legacy_guard_plus_seen) begin
            stable_pre_guard_cycles = plus_legacy_guard_cycles;
            stable_post_guard_cycles = plus_legacy_guard_cycles;
            if (run_cycles > (2 * plus_legacy_guard_cycles))
                stable_capture_cycles = run_cycles - (2 * plus_legacy_guard_cycles);
            else
                stable_capture_cycles = run_cycles;
            stable_window_cycles = stable_capture_cycles;
        end else if (stable_window_cycles == 0 || stable_window_cycles >= run_cycles) begin
            stable_capture_cycles = run_cycles;
            stable_pre_guard_cycles = 0;
            stable_post_guard_cycles = 0;
        end else begin
            stable_capture_cycles = stable_window_cycles;
            stable_pre_guard_cycles = (run_cycles - stable_capture_cycles) / 2;
            stable_post_guard_cycles = run_cycles -
                                       stable_pre_guard_cycles -
                                       stable_capture_cycles;
        end

        ctrl_vif.run_cycles = run_cycles;
        ctrl_vif.drain_cycles = drain_cycles;
        enable_post_rbcam_checks = (latency_scope == "full") ||
                                    (latency_scope == "post_rbcam");
        enable_feb_egress_checks = (latency_scope == "full");

        @(negedge rst);
        repeat (64) @(posedge clk_125);

        configure_active_emulators();
        if (source_is_virtual_mutrig())
            configure_virtual_mutrig_source();
        if (traffic_uses_rtl_injector())
            configure_rtl_injector();
        csr_write_emu0(EMU_CSR_SIGNAL_ADDR, 32'h0000_0000);
        csr_write_emu0(EMU_CSR_RATES_ADDR, {16'h0000, hit_rate_q16[15:0]});
        csr_write_emu0(EMU_CSR_CLUSTER_FIX_ADDR, 32'h0000_4780);

        tb_int_run_window_db::reset();
        tb_int_run_window_db::configure_guards(stable_pre_guard_cycles,
                                               stable_post_guard_cycles);
        `uvm_info("PROF_INT_002_TOP",
                  $sformatf("RUN_CONFIG source=%s latency_scope=%s post_checks=%0b feb_checks=%0b run_cycles=%0d drain_cycles=%0d stable_window=%0d stable_pre_guard=%0d stable_post_guard=%0d active_lanes=%0d mask=%0h stage_a_lane=%0d traffic=%s inject_driver=%s hit_ch=%0d:%0d short_mode=%0d hit_rate_q16=%0d inject_phase=%0d inject_count=%0d inject_pulse_high=%0d inject_frame_count=%0d inject_burst_count=%0d inject_burst_spacing=%0d runctl_mode=readyless runctl_cpp_gap=%0d runctl_settle_timeout=%0d",
                            source_mode,
                            latency_scope,
                            enable_post_rbcam_checks,
                            enable_feb_egress_checks,
                            run_cycles,
                            drain_cycles,
                            stable_capture_cycles,
                            stable_pre_guard_cycles,
                            stable_post_guard_cycles,
                            active_lane_count,
                            active_lane_mask,
                            stage_a_lane_index,
                            traffic_mode,
                            inject_driver,
                            hit_channel_low,
                            hit_channel_high,
                            mutrig_short_mode,
                            hit_rate_q16,
                            inject_phase_cycles,
                            inject_pulse_count,
                            inject_pulse_high_cycles,
                            inject_frame_count,
                            inject_burst_count,
                            inject_burst_spacing_cycles,
                            runctl_cpp_gap_cycles,
                            runctl_settle_timeout_cycles),
                  UVM_LOW)

        ctrl_vif.sim_started = 1'b1;
        drive_runctl(RUNCTL_RUN_PREP_SYM, 4);
        observe_runctl_cpp_gap("RUN_PREPARE_to_SYNC");
        report_hit_stack_runctl_broadcast("after RUN_PREPARE software gap");
        repeat (4) @(posedge clk_125);
        configure_active_arb_lanes();
        drive_runctl(RUNCTL_SYNC_SYM, 2);
        observe_runctl_cpp_gap("SYNC_to_RUNNING");
        report_hit_stack_runctl_broadcast("after SYNC software gap");
        drive_runctl(RUNCTL_RUNNING_SYM, 2);
        repeat (16) @(posedge clk_125);
        report_datapath_state("after RUNNING");
        report_mts_csr_state("after RUNNING");
        report_rbcam_csr_state("after RUNNING");
        tb_int_run_window_db::note_run_start($time);
        injection_window_active = 1'b1;
        if (traffic_is_header_sync() && source_is_emu_direct()) begin
            fork
                drive_header_sync_injections();
            join_none
        end else if (traffic_is_header_sync() && source_is_virtual_mutrig()) begin
            `uvm_info("PROF_INT_002_INJECT",
                      $sformatf("virtual_mutrig header-sync source owns injection scheduling frames=%0d burst=%0d spacing=%0d phase=%0d",
                                inject_frame_count,
                                inject_burst_count,
                                inject_burst_spacing_cycles,
                                inject_phase_cycles),
                      UVM_LOW)
        end
        repeat (stable_pre_guard_cycles) @(posedge clk_125);
        tb_int_run_window_db::note_stable_start($time);
        repeat (stable_capture_cycles) @(posedge clk_125);
        tb_int_run_window_db::note_stable_end($time);
        repeat (stable_post_guard_cycles) @(posedge clk_125);
        tb_int_run_window_db::note_run_end($time);
        injection_window_active = 1'b0;
        report_datapath_state("before TERMINATING");
        report_mts_csr_state("before TERMINATING");
        report_rbcam_csr_state("before TERMINATING");
        drive_runctl(RUNCTL_TERMINATING_SYM, 8);
        observe_runctl_cpp_gap("TERMINATING_to_IDLE");
        report_hit_stack_runctl_broadcast("after TERMINATING software gap");
        repeat (drain_cycles) @(posedge clk_125);
        report_datapath_state("after drain");
        drive_runctl(RUNCTL_IDLE_SYM, 4);
        repeat (512) @(posedge clk_125);
        ctrl_vif.sim_done = 1'b1;
    end
endmodule
