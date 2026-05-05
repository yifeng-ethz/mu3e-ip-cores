// prof_int_002_full_pipeline_top.sv
// Standalone PROF-INT-002 full-pipeline real-RTL simulation top.
//
// Author: Yifeng Wang <yifenwan@phys.ethz.ch>
// Version : 26.2.0
// Date    : 20260505
// Change  : New -- wrap full8lane_type0_system and passive stage taps.

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

    localparam logic [8:0] RUNCTL_IDLE_SYM        = 9'h001;
    localparam logic [8:0] RUNCTL_RUN_PREP_SYM    = 9'h002;
    localparam logic [8:0] RUNCTL_SYNC_SYM        = 9'h004;
    localparam logic [8:0] RUNCTL_RUNNING_SYM     = 9'h008;
    localparam logic [8:0] RUNCTL_TERMINATING_SYM = 9'h010;

    localparam logic [3:0] EMU_CSR_SIGNAL_ADDR      = 4'h8;
    localparam logic [3:0] EMU_CSR_RATES_ADDR       = 4'hB;
    localparam logic [3:0] EMU_CSR_CLUSTER_FIX_ADDR = 4'hC;
    localparam logic [4:0] ARB_CSR_CONTROL_ADDR     = 5'h02;
    localparam logic [31:0] ARB_MODE_EMU            = 32'h0000_0001;

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
    int unsigned active_lane_count;
    int unsigned active_lane_mask_popcount;
    int unsigned runctl_cpp_gap_cycles;
    int unsigned runctl_settle_timeout_cycles;
    logic [2:0] stage_a_lane_index;
    logic [7:0]  active_lane_mask;
        logic [3:0]  csr_force_addr;
        logic [31:0] csr_force_wdata;
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
    hit_tap_if           pre_rbcam_vif0(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif1(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif2(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif3(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif0(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif1(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif2(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif3(.clk(clk_125), .rst(rst));
    hit_tap_if           feb_egress_vif(.clk(clk_125), .rst(rst));
    prof_int_002_ctrl_if ctrl_vif(.clk(clk_125), .rst(rst));
    logic                stage_a_any_valid;
    logic                pre_rbcam_any_valid;
    logic                post_rbcam_any_valid;

    assign stage_a_any_valid = stage_a_vif0.valid | stage_a_vif1.valid |
                               stage_a_vif2.valid | stage_a_vif3.valid |
                               stage_a_vif4.valid | stage_a_vif5.valid |
                               stage_a_vif6.valid | stage_a_vif7.valid;
    assign pre_rbcam_any_valid = pre_rbcam_vif0.valid | pre_rbcam_vif1.valid |
                                 pre_rbcam_vif2.valid | pre_rbcam_vif3.valid;
    assign post_rbcam_any_valid = post_rbcam_vif0.valid | post_rbcam_vif1.valid |
                                  post_rbcam_vif2.valid | post_rbcam_vif3.valid;

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
        .feb_egress_valid (feb_egress_vif.valid)
    );

    function automatic logic [44:0] raw48_to_hit0(
        input logic [47:0] raw_word,
        input logic [3:0]  asic
    );
        return {asic, raw_word[47:43], raw_word[41:27],
                raw_word[26:22], raw_word[19:5], raw_word[20]};
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

    always_comb begin
        logic [44:0] stage_a_payload;
        stage_a_payload = raw48_to_hit0(u_dut.data_path_subsystem.emulator_mutrig_0
            .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_word, 4'd0);
        stage_a_vif0.valid = active_lane_mask[0] &&
            u_dut.data_path_subsystem.emulator_mutrig_0
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.pending_valid &&
            u_dut.data_path_subsystem.emulator_mutrig_0
                .u_emulator_mutrig.lane_gen[0].u_lane_emitter.l2_wr_ready;
        stage_a_vif0.payload = stage_a_payload;
        stage_a_vif0.lane_id = 4'd0;
        stage_a_vif0.channel = stage_a_payload[40:36];
        stage_a_vif0.t_coarse = stage_a_payload[35:21];
        stage_a_vif0.t_fine = stage_a_payload[20:16];

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

        pre_rbcam_vif0.valid = hit1_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_empty[0],
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_error[0]);
        pre_rbcam_vif0.ready = 1'b1;
        pre_rbcam_vif0.payload = hit1_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_data);
        pre_rbcam_vif0.lane_id =
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_data[38:35];
        pre_rbcam_vif0.hit_id = 64'd0;
        pre_rbcam_vif0.hit_id_valid = 1'b0;
        pre_rbcam_vif0.root_hit_id = 64'd0;
        pre_rbcam_vif0.root_hit_id_valid = 1'b0;
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
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_data[38:35];
        pre_rbcam_vif1.hit_id = 64'd0;
        pre_rbcam_vif1.hit_id_valid = 1'b0;
        pre_rbcam_vif1.root_hit_id = 64'd0;
        pre_rbcam_vif1.root_hit_id_valid = 1'b0;
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
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_data[38:35];
        pre_rbcam_vif2.hit_id = 64'd0;
        pre_rbcam_vif2.hit_id_valid = 1'b0;
        pre_rbcam_vif2.root_hit_id = 64'd0;
        pre_rbcam_vif2.root_hit_id_valid = 1'b0;
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
            u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_data[38:35];
        pre_rbcam_vif3.hit_id = 64'd0;
        pre_rbcam_vif3.hit_id_valid = 1'b0;
        pre_rbcam_vif3.root_hit_id = 64'd0;
        pre_rbcam_vif3.root_hit_id_valid = 1'b0;
        pre_rbcam_vif3.run_origin = 1'b0;

        post_rbcam_vif0.valid = hit2_tap_valid(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_error,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_data);
        post_rbcam_vif0.ready = 1'b1;
        post_rbcam_vif0.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_data);
        post_rbcam_vif0.lane_id = post_rbcam_vif0.payload[44:41];
        post_rbcam_vif0.hit_id = 64'd0;
        post_rbcam_vif0.hit_id_valid = 1'b0;
        post_rbcam_vif0.root_hit_id = 64'd0;
        post_rbcam_vif0.root_hit_id_valid = 1'b0;
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
        post_rbcam_vif1.hit_id = 64'd0;
        post_rbcam_vif1.hit_id_valid = 1'b0;
        post_rbcam_vif1.root_hit_id = 64'd0;
        post_rbcam_vif1.root_hit_id_valid = 1'b0;
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
        post_rbcam_vif2.hit_id = 64'd0;
        post_rbcam_vif2.hit_id_valid = 1'b0;
        post_rbcam_vif2.root_hit_id = 64'd0;
        post_rbcam_vif2.root_hit_id_valid = 1'b0;
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
        post_rbcam_vif3.hit_id = 64'd0;
        post_rbcam_vif3.hit_id_valid = 1'b0;
        post_rbcam_vif3.root_hit_id = 64'd0;
        post_rbcam_vif3.root_hit_id_valid = 1'b0;
        post_rbcam_vif3.run_origin = 1'b0;

        feb_egress_vif.valid = u_dut.data_path_subsystem
            .hit_stack_subsystem_0_hit_type3_valid &&
            u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready &&
            feb_frame_active &&
            (feb_frame_word_index >= 5) &&
            hit2_word_is_hit(u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data);
        feb_egress_vif.ready = 1'b1;
        feb_egress_vif.payload = hit2_to_hit0(
            u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_data);
        feb_egress_vif.lane_id = feb_egress_vif.payload[44:41];
        feb_egress_vif.hit_id = 64'd0;
        feb_egress_vif.hit_id_valid = 1'b0;
        feb_egress_vif.root_hit_id = 64'd0;
        feb_egress_vif.root_hit_id_valid = 1'b0;
        feb_egress_vif.run_origin = 1'b0;
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
        end else begin
            ctrl_vif.stage_a_count <= ctrl_vif.stage_a_count +
                {63'd0, stage_a_vif0.valid} + {63'd0, stage_a_vif1.valid} +
                {63'd0, stage_a_vif2.valid} + {63'd0, stage_a_vif3.valid} +
                {63'd0, stage_a_vif4.valid} + {63'd0, stage_a_vif5.valid} +
                {63'd0, stage_a_vif6.valid} + {63'd0, stage_a_vif7.valid};
            ctrl_vif.pre_rbcam_count <= ctrl_vif.pre_rbcam_count +
                {63'd0, pre_rbcam_vif0.valid} + {63'd0, pre_rbcam_vif1.valid} +
                {63'd0, pre_rbcam_vif2.valid} + {63'd0, pre_rbcam_vif3.valid};
            ctrl_vif.post_rbcam_count <= ctrl_vif.post_rbcam_count +
                {63'd0, post_rbcam_vif0.valid} + {63'd0, post_rbcam_vif1.valid} +
                {63'd0, post_rbcam_vif2.valid} + {63'd0, post_rbcam_vif3.valid};
            if (feb_egress_vif.valid)
                ctrl_vif.feb_egress_count <= ctrl_vif.feb_egress_count + 64'd1;
            if (u_dut.data_path_subsystem.avalon_st_adapter_026_out_0_valid &&
                u_dut.data_path_subsystem.avalon_st_adapter_026_out_0_ready)
                dbg_arb_bp_accept <= dbg_arb_bp_accept + 64'd1;
            if (u_dut.data_path_subsystem.backpressure_fifo_0_out_valid &&
                u_dut.data_path_subsystem.backpressure_fifo_0_out_ready)
                dbg_bp_mux_accept <= dbg_bp_mux_accept + 64'd1;
            if (u_dut.data_path_subsystem.mux_mutrig2processor_out_valid &&
                u_dut.data_path_subsystem.mux_mutrig2processor_out_ready)
                dbg_mux_mts_accept <= dbg_mux_mts_accept + 64'd1;
            if (u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid &&
                u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_ready) begin
                dbg_mts_out_accept <= dbg_mts_out_accept + 64'd1;
                if (u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_error)
                    dbg_mts_out_error <= dbg_mts_out_error + 64'd1;
            end
            if (u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_valid &&
                u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_ready) begin
                dbg_hisb_pre_accept <= dbg_hisb_pre_accept + 64'd1;
                if (u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_error)
                    dbg_hisb_pre_error <= dbg_hisb_pre_error + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_ready) begin
                dbg_ds0_accept <= dbg_ds0_accept + 64'd1;
                if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out0_error[0])
                    dbg_ds_error <= dbg_ds_error + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_ready) begin
                dbg_ds1_accept <= dbg_ds1_accept + 64'd1;
                if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out1_error[0])
                    dbg_ds_error <= dbg_ds_error + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_ready) begin
                dbg_ds2_accept <= dbg_ds2_accept + 64'd1;
                if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out2_error[0])
                    dbg_ds_error <= dbg_ds_error + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_ready) begin
                dbg_ds3_accept <= dbg_ds3_accept + 64'd1;
                if (u_dut.data_path_subsystem.hit_stack_subsystem_0.data_splitter_0_out3_error[0])
                    dbg_ds_error <= dbg_ds_error + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid) begin
                dbg_rb_any_accept <= dbg_rb_any_accept + 64'd1;
                dbg_rb_hit_accept <= dbg_rb_hit_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_valid) begin
                dbg_rb_any_accept <= dbg_rb_any_accept + 64'd1;
                dbg_rb_hit_accept <= dbg_rb_hit_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_valid) begin
                dbg_rb_any_accept <= dbg_rb_any_accept + 64'd1;
                dbg_rb_hit_accept <= dbg_rb_hit_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_valid) begin
                dbg_rb_any_accept <= dbg_rb_any_accept + 64'd1;
                dbg_rb_hit_accept <= dbg_rb_hit_accept + 64'd1;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_valid &&
                u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready) begin
                dbg_feb_any_accept <= dbg_feb_any_accept + 64'd1;
                if (feb_egress_vif.valid)
                    dbg_feb_hit_accept <= dbg_feb_hit_accept + 64'd1;
                if (u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_startofpacket) begin
                    feb_frame_active <= 1'b1;
                    feb_frame_word_index <= 1;
                end else if (u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_endofpacket) begin
                    feb_frame_active <= 1'b0;
                    feb_frame_word_index <= 0;
                end else if (feb_frame_active) begin
                    feb_frame_word_index <= feb_frame_word_index + 1;
                end
            end
            if (u_dut.data_path_subsystem.run_control_splitter_out6_valid) begin
                dbg_dp_hs_runctl_accept <= dbg_dp_hs_runctl_accept + 64'd1;
                dbg_last_hs_runctl_symbol <=
                    u_dut.data_path_subsystem.run_control_splitter_out6_data;
            end
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out0_valid)
                dbg_hs_rbcam_runctl_accept <= dbg_hs_rbcam_runctl_accept + 64'd1;
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out1_valid)
                dbg_hs_rbcam_runctl_accept <= dbg_hs_rbcam_runctl_accept + 64'd1;
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out2_valid)
                dbg_hs_rbcam_runctl_accept <= dbg_hs_rbcam_runctl_accept + 64'd1;
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out3_valid)
                dbg_hs_rbcam_runctl_accept <= dbg_hs_rbcam_runctl_accept + 64'd1;
            if (u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_valid)
                dbg_hs_feb_runctl_accept <= dbg_hs_feb_runctl_accept + 64'd1;
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

    task automatic configure_active_emulators();
        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_global_enable = active_lane_mask[0];
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_global_enable = active_lane_mask[1];
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_global_enable = active_lane_mask[2];
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_global_enable = active_lane_mask[3];
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_global_enable = active_lane_mask[4];
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_global_enable = active_lane_mask[5];
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_global_enable = active_lane_mask[6];
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_global_enable = active_lane_mask[7];

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

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_geom_fix_left_low = 7'd0;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_geom_fix_left_high = 7'd15;

        force u_dut.data_path_subsystem.emulator_mutrig_0.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_1.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_2.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_3.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_4.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_5.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_6.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
        force u_dut.data_path_subsystem.emulator_mutrig_7.u_emulator_mutrig.cfg_geom_fix_left_enable = 1'b1;
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

    function automatic logic [5:0] hit_stack0_runctl_ready_vec();
        hit_stack0_runctl_ready_vec = {
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_cmd_fifo_5_out_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_cmd_fifo_4_out_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_cmd_fifo_3_out_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_cmd_fifo_2_out_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_cmd_fifo_1_out_ready,
            u_dut.data_path_subsystem.hit_stack_subsystem_0.run_control_cmd_fifo_0_out_ready
        };
    endfunction

    task automatic wait_hit_stack_runctl_settled(input string tag,
                                                 input logic [5:0] ready_mask,
                                                 input bit fail_on_timeout = 1'b0);
        int unsigned waited_cycles;
        logic [5:0] ready_vec;

        waited_cycles = 0;
        ready_vec = hit_stack0_runctl_ready_vec();
        while (((ready_vec & ready_mask) != ready_mask) &&
               (waited_cycles < runctl_settle_timeout_cycles)) begin
            @(posedge clk_125);
            waited_cycles++;
            ready_vec = hit_stack0_runctl_ready_vec();
        end

        if ((ready_vec & ready_mask) != ready_mask) begin
            if (fail_on_timeout) begin
                `uvm_error("PROF_INT_002_TOP",
                           $sformatf("%s run-control sink-settle timeout ready=%06b mask=%06b waited_cycles=%0d timeout=%0d",
                                     tag,
                                     ready_vec,
                                     ready_mask,
                                     waited_cycles,
                                     runctl_settle_timeout_cycles))
            end else begin
                `uvm_warning("PROF_INT_002_TOP",
                             $sformatf("%s run-control sink-settle timeout ready=%06b mask=%06b waited_cycles=%0d timeout=%0d",
                                       tag,
                                       ready_vec,
                                       ready_mask,
                                       waited_cycles,
                                       runctl_settle_timeout_cycles))
            end
        end else begin
            `uvm_info("PROF_INT_002_TOP",
                      $sformatf("%s observed legacy run-control sinks settled ready=%06b mask=%06b waited_cycles=%0d",
                                tag,
                                ready_vec,
                                ready_mask,
                                waited_cycles),
                      UVM_LOW)
        end
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

    task automatic csr_write_arb0(input logic [4:0] addr, input logic [31:0] data);
        arb_csr_force_addr = addr;
        arb_csr_force_wdata = data;
        @(negedge clk_125);
        force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_address = arb_csr_force_addr;
        force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_writedata = arb_csr_force_wdata;
        force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_read = 1'b0;
        force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_write = 1'b1;
        @(negedge clk_125);
        force u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_write = 1'b0;
        repeat (2) @(posedge clk_125);
        release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_write;
        release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_read;
        release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_writedata;
        release u_dut.data_path_subsystem.mm_interconnect_0_arb_hit_type0_supercore_0_csr_0_address;
    endtask

    task automatic report_datapath_state(input string tag);
        `uvm_info("PROF_INT_002_TOP",
                  $sformatf("%s rst_top=%0b rst_dp=%0b emu_ctrl=%03h emu_ctrl_valid=%0b type0_ctrl=%03h type0_ctrl_valid=%0b ctrl_state=%03h run_gen=%0b cfg_global=%0b cfg_rate=%0d l2_level=%0d lane_hits=%0d arb_mode=%0d arb_run=%0d emu_h0_v=%0b emu_h0_ch=%0d emu_accept=%0b emu_drop=%0b emu_depth=%0d emu_empty=%0b arb_aso_v=%0b bp0_in_v=%0b bp0_out_v=%0b mux_v=%0b mts1_v=%0b hisb_pre_v=%0b hs_in_rdy=%0b rc_rdy=%06b rb_v=%04b rb_rdy=%04b hit3_v=%0b hit3_rdy=%0b",
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
                                u_dut.data_path_subsystem.emulator_mutrig_0_hit_type0_valid,
                                u_dut.data_path_subsystem.emulator_mutrig_0_hit_type0_channel,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_push_accept,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_push_drop,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_fifo_depth,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0.lane_0.emu_fifo_empty,
                                u_dut.data_path_subsystem.arb_hit_type0_supercore_0_selected_out_0_valid,
                                u_dut.data_path_subsystem.avalon_st_adapter_026_out_0_valid,
                                u_dut.data_path_subsystem.backpressure_fifo_0_out_valid,
                                u_dut.data_path_subsystem.mux_mutrig2processor_out_valid,
                                u_dut.data_path_subsystem.mts_preprocessor_0_hit_type1_out_valid,
                                u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_valid,
                                u_dut.data_path_subsystem.histogram_ingress_bridge_0_pre_out_ready,
                                hit_stack0_runctl_ready_vec(),
                                {u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_valid,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_valid},
                                {u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_3_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_2_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_1_hit_type2_ready,
                                 u_dut.data_path_subsystem.hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_ready},
                                u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_valid,
                                u_dut.data_path_subsystem.hit_stack_subsystem_0_hit_type3_ready),
                  UVM_LOW)
        `uvm_info("PROF_INT_002_COUNTERS",
                  $sformatf("%s counts arb_bp=%0d bp_mux=%0d mux_mts=%0d mts_out=%0d mts_err=%0d hisb_pre=%0d hisb_err=%0d ds={%0d,%0d,%0d,%0d} ds_err=%0d rb_any=%0d rb_hit=%0d feb_any=%0d feb_hit=%0d hs_runctl=%0d rb_runctl=%0d feb_runctl=%0d last_hs_runctl=%03h",
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
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon0", "vif", pre_rbcam_vif0);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon1", "vif", pre_rbcam_vif1);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon2", "vif", pre_rbcam_vif2);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.pre_rbcam_mon3", "vif", pre_rbcam_vif3);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon0", "vif", post_rbcam_vif0);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon1", "vif", post_rbcam_vif1);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon2", "vif", post_rbcam_vif2);
        uvm_config_db#(virtual hit_tap_if)::set(null, "uvm_test_top.env.post_rbcam_mon3", "vif", post_rbcam_vif3);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.feb_egress_mon",
                                                "vif",
                                                feb_egress_vif);
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
        int plus_runctl_cpp_gap_cycles;
        int plus_runctl_settle_timeout_cycles;
        bit legacy_guard_plus_seen;

        run_cycles = 12_500_000;
        drain_cycles = 16_384;
        stable_window_cycles = 0;
        stable_capture_cycles = 0;
        stable_pre_guard_cycles = 0;
        stable_post_guard_cycles = 0;
        hit_rate_q16 = 52;
        runctl_cpp_gap_cycles = 125_000;
        runctl_settle_timeout_cycles = 1_250_000;
        active_lane_count = 1;
        active_lane_mask = 8'h01;
        active_lane_mask_popcount = 0;
        stage_a_lane_index = 3'd0;
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

        @(negedge rst);
        repeat (64) @(posedge clk_125);

        configure_active_emulators();
        csr_write_emu0(EMU_CSR_SIGNAL_ADDR, 32'h0000_0000);
        csr_write_emu0(EMU_CSR_RATES_ADDR, {16'h0000, hit_rate_q16[15:0]});
        csr_write_emu0(EMU_CSR_CLUSTER_FIX_ADDR, 32'h0000_4780);

        tb_int_run_window_db::reset();
        tb_int_run_window_db::configure_guards(stable_pre_guard_cycles,
                                               stable_post_guard_cycles);
        `uvm_info("PROF_INT_002_TOP",
                  $sformatf("RUN_CONFIG run_cycles=%0d drain_cycles=%0d stable_window=%0d stable_pre_guard=%0d stable_post_guard=%0d active_lanes=%0d mask=%0h stage_a_lane=%0d runctl_mode=readyless runctl_cpp_gap=%0d runctl_settle_timeout=%0d",
                            run_cycles,
                            drain_cycles,
                            stable_capture_cycles,
                            stable_pre_guard_cycles,
                            stable_post_guard_cycles,
                            active_lane_count,
                            active_lane_mask,
                            stage_a_lane_index,
                            runctl_cpp_gap_cycles,
                            runctl_settle_timeout_cycles),
                  UVM_LOW)

        ctrl_vif.sim_started = 1'b1;
        drive_runctl(RUNCTL_RUN_PREP_SYM, 4);
        wait_hit_stack_runctl_settled("after RUN_PREPARE", 6'b001111, 1'b1);
        observe_runctl_cpp_gap("RUN_PREPARE_to_SYNC");
        repeat (4) @(posedge clk_125);
        csr_write_arb0(ARB_CSR_CONTROL_ADDR, ARB_MODE_EMU);
        drive_runctl(RUNCTL_SYNC_SYM, 2);
        observe_runctl_cpp_gap("SYNC_to_RUNNING");
        drive_runctl(RUNCTL_RUNNING_SYM, 2);
        repeat (16) @(posedge clk_125);
        report_datapath_state("after RUNNING");
        tb_int_run_window_db::note_run_start($time);
        repeat (stable_pre_guard_cycles) @(posedge clk_125);
        tb_int_run_window_db::note_stable_start($time);
        repeat (stable_capture_cycles) @(posedge clk_125);
        tb_int_run_window_db::note_stable_end($time);
        repeat (stable_post_guard_cycles) @(posedge clk_125);
        tb_int_run_window_db::note_run_end($time);
        report_datapath_state("before TERMINATING");
        drive_runctl(RUNCTL_TERMINATING_SYM, 8);
        wait_hit_stack_runctl_settled("after TERMINATING", 6'b001111, 1'b0);
        observe_runctl_cpp_gap("TERMINATING_to_IDLE");
        repeat (drain_cycles) @(posedge clk_125);
        report_datapath_state("after drain");
        drive_runctl(RUNCTL_IDLE_SYM, 4);
        repeat (512) @(posedge clk_125);
        ctrl_vif.sim_done = 1'b1;
    end
endmodule
