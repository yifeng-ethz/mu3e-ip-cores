// tb_int_top.sv
// Top-level simulator shell for v3_pretest-260511/tb_int.
//
// The active tb_int shell drives the real runctl_mgmt_host synclink protocol
// and Qsys-generated run-control splitter wrappers.

module tb_int_top;
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
    import tb_int_feb_frame_monitor_pkg::*;
    import tb_int_histogram_csr_monitor_pkg::*;
    import tb_int_debug_l2_sidecar_monitor_pkg::*;
    import tb_int_debug_pre_rbcam_sidecar_monitor_pkg::*;
    import tb_int_debug_post_rbcam_sidecar_monitor_pkg::*;
    import tb_int_debug_feb_egress_sidecar_monitor_pkg::*;
    import tb_int_debug_fill_monitor_pkg::*;
    import tb_int_v3_scoreboard_pkg::*;
    import tb_int_dual_env_pkg::*;
    import tb_int_basic_sequences_pkg::*;
    import tb_int_base_test_pkg::*;
    import tb_int_b065_test_pkg::*;
    import tb_int_b066_test_pkg::*;
    import tb_int_b067_test_pkg::*;
    import tb_int_b068_test_pkg::*;
    import tb_int_b069_test_pkg::*;
    // Directed run-control + emulator hit-flow tests.
    import tb_int_run_emulator_directed_test_pkg::*;
    // The blocked test name is a legacy Makefile alias; both wrappers now
    // exercise the generated Qsys path.
    import tb_int_run_emul_blocked_test_pkg::*;
    import tb_int_run_emul_fixed_test_pkg::*;
    import tb_int_smoke_test_pkg::*;
    `include "uvm_macros.svh"

    logic clk_125 = 1'b0;
    logic rst = 1'b1;

    lvds_phy_if          lvds_phy_vif(.clk(clk_125), .rst(rst));
    runctl_phy_if        runctl_phy_vif(.clk(clk_125), .rst(rst));
    sc_avmm_if           sc_phy_vif(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  debug_l2_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           emulator_egress_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_emulator_egress_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_pre_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_post_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_feb_egress_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           feb_egress_vif(.clk(clk_125), .rst(rst));
    mu3e_frame_if        upload_data0_frame_vif(.clk(clk_125), .rst(rst));
    mu3e_frame_if        upload_data1_frame_vif(.clk(clk_125), .rst(rst));
    debug_fill_if        fill_vif(.clk(clk_125), .rst(rst));
    tb_int_counter_if    counter_vif(.clk(clk_125), .rst(rst));

`ifdef TB_INT_BIND_REAL_DUT
    logic [35:0] dut_upload_data0_sc_rc_data;
    logic        dut_upload_data0_sc_rc_valid;
    logic        dut_upload_data0_sc_rc_sop;
    logic        dut_upload_data0_sc_rc_eop;
    logic [1:0]  dut_upload_data0_sc_rc_channel;
    logic [35:0] dut_upload_data1_data;
    logic        dut_upload_data1_valid;
    logic        dut_upload_data1_sop;
    logic        dut_upload_data1_eop;
`endif

`ifdef TB_INT_BIND_REAL_DUT
    // The contract DUT is the generated feb_system_v3 synthesis tree. This
    // FEB-only build exposes the legacy upload_pkt_mux egress; RDMA RQE/CQE
    // cosim is a separate FEB+SWB task (#48).
    feb_system_v3 u_dut(
        .cclk156_clk(clk_125),
        .lvds_pll_inclock_clk(clk_125),
        .max10_link_clock_clk(clk_125),
        .mclk125_clk(clk_125),
        .osc_clock_50_in_clk(clk_125),
        .reset_3_reset_n(~rst),
        .legacy_firefly_mon_waitrequest(1'b0),
        .legacy_firefly_mon_readdata(32'h0000_0000),
        .legacy_firefly_mon_readdatavalid(1'b0),
        .legacy_firefly_mon_response(2'b00),
        .upload_data0_sc_rc_data(dut_upload_data0_sc_rc_data),
        .upload_data0_sc_rc_valid(dut_upload_data0_sc_rc_valid),
        .upload_data0_sc_rc_ready(upload_data0_frame_vif.ready),
        .upload_data0_sc_rc_startofpacket(dut_upload_data0_sc_rc_sop),
        .upload_data0_sc_rc_endofpacket(dut_upload_data0_sc_rc_eop),
        .upload_data0_sc_rc_channel(dut_upload_data0_sc_rc_channel),
        .upload_data1_data(dut_upload_data1_data),
        .upload_data1_valid(dut_upload_data1_valid),
        .upload_data1_ready(upload_data1_frame_vif.ready),
        .upload_data1_startofpacket(dut_upload_data1_sop),
        .upload_data1_endofpacket(dut_upload_data1_eop)
    );

    always_comb begin
        upload_data0_frame_vif.valid = dut_upload_data0_sc_rc_valid;
        upload_data0_frame_vif.sop = dut_upload_data0_sc_rc_sop;
        upload_data0_frame_vif.eop = dut_upload_data0_sc_rc_eop;
        upload_data0_frame_vif.data = dut_upload_data0_sc_rc_data;
        upload_data0_frame_vif.channel = dut_upload_data0_sc_rc_channel;
        upload_data1_frame_vif.valid = dut_upload_data1_valid;
        upload_data1_frame_vif.sop = dut_upload_data1_sop;
        upload_data1_frame_vif.eop = dut_upload_data1_eop;
        upload_data1_frame_vif.data = dut_upload_data1_data;
        upload_data1_frame_vif.channel = 2'd1;
    end
`endif

    tb_int_assertions u_tb_int_assertions (
        .clk(clk_125),
        .rst(rst),
        .stage_a_valid(stage_a_vif.valid),
        .pre_rbcam_valid(pre_rbcam_vif.valid),
        .post_rbcam_valid(post_rbcam_vif.valid),
        .feb_egress_valid(feb_egress_vif.valid),
        .feb_egress_ready(feb_egress_vif.ready),
        .enable_post_rbcam_checks(1'b0),
        .enable_feb_egress_checks(1'b1)
    );

    initial begin
        clk_125 = 1'b0;
        forever #4000 clk_125 = ~clk_125;
    end

    initial begin
        rst = 1'b1;
        stage_a_vif.clear();
        debug_l2_vif.clear();
        emulator_egress_vif.clear();
        debug_emulator_egress_vif.clear();
        pre_rbcam_vif.clear();
        post_rbcam_vif.clear();
        debug_pre_rbcam_vif.clear();
        debug_post_rbcam_vif.clear();
        debug_feb_egress_vif.clear();
        feb_egress_vif.clear();
`ifndef TB_INT_BIND_REAL_DUT
        upload_data0_frame_vif.clear();
        upload_data1_frame_vif.clear();
`else
        upload_data0_frame_vif.ready = 1'b1;
        upload_data1_frame_vif.ready = 1'b1;
`endif
        fill_vif.clear();
        counter_vif.clear();
        lvds_phy_vif.clear();
        runctl_phy_vif.clear();
        sc_phy_vif.clear_master();
        sc_phy_vif.waitrequest = 1'b0;
        repeat (6) @(posedge clk_125);
        rst = 1'b0;
    end

    // Real run-control host + generated Qsys splitter path used by the
    // current FEB build:
    //   runctl_phy_if -> runctl_mgmt_host.synclink -> run_control_splitter
    //   out14 -> emulator_ctrl_splitter.out0 -> emulator lane-0 RUNNING gate.
    localparam logic [8:0] RUNCTL_HOST_IDLE_COMMA = 9'h1BC;

    logic [8:0]  runctl_host_synclink_data;
    logic [2:0]  runctl_host_synclink_error;
    logic [35:0] runctl_host_upload_data;
    logic        runctl_host_upload_valid;
    logic        runctl_host_upload_sop;
    logic        runctl_host_upload_eop;
    logic        runctl_host_out_valid;
    logic [8:0]  runctl_host_out_data;
    logic [31:0] runctl_host_csr_readdata;
    logic        runctl_host_csr_waitrequest;
    logic        runctl_host_csr_read;
    logic        runctl_host_csr_write;
    logic [4:0]  runctl_host_csr_address;
    logic        runctl_host_dp_hard_reset;
    logic        runctl_host_ct_hard_reset;
    logic        runctl_host_ext_hard_reset;

    logic        run_control_splitter_out0_valid;
    logic [8:0]  run_control_splitter_out0_data;
    logic        run_control_splitter_out14_valid;
    logic [8:0]  run_control_splitter_out14_data;
    logic        run_control_splitter_out15_valid;
    logic [8:0]  run_control_splitter_out15_data;
    logic        emulator_ctrl_splitter_in_ready;
    logic        emulator_ctrl_splitter_out0_valid;
    logic [8:0]  emulator_ctrl_splitter_out0_data;
    logic        emulator_ctrl_splitter_out1_valid;
    logic [8:0]  emulator_ctrl_splitter_out1_data;

    assign runctl_host_synclink_data  = runctl_phy_vif.valid ? runctl_phy_vif.data  : RUNCTL_HOST_IDLE_COMMA;
    assign runctl_host_synclink_error = runctl_phy_vif.valid ? runctl_phy_vif.error : 3'b000;

    runctl_mgmt_host #(
        .DEBUG(0),
        .INSTANCE_ID(32'h5442_494E)
    ) u_runctl_mgmt_host (
        .asi_synclink_data(runctl_host_synclink_data),
        .asi_synclink_error(runctl_host_synclink_error),
        .aso_upload_data(runctl_host_upload_data),
        .aso_upload_valid(runctl_host_upload_valid),
        .aso_upload_ready(1'b1),
        .aso_upload_startofpacket(runctl_host_upload_sop),
        .aso_upload_endofpacket(runctl_host_upload_eop),
        .aso_runctl_valid(runctl_host_out_valid),
        .aso_runctl_data(runctl_host_out_data),
        .avs_csr_address(runctl_host_csr_address),
        .avs_csr_read(runctl_host_csr_read),
        .avs_csr_readdata(runctl_host_csr_readdata),
        .avs_csr_write(runctl_host_csr_write),
        .avs_csr_writedata(sc_phy_vif.writedata),
        .avs_csr_waitrequest(runctl_host_csr_waitrequest),
        .dp_hard_reset(runctl_host_dp_hard_reset),
        .ct_hard_reset(runctl_host_ct_hard_reset),
        .ext_hard_reset(runctl_host_ext_hard_reset),
        .mm_clk(clk_125),
        .mm_reset(rst),
        .lvdspll_clk(clk_125),
        .lvdspll_reset(rst)
    );

    feb_system_v3_data_path_subsystem_run_control_splitter u_generated_run_control_splitter (
        .clk(clk_125),
        .reset(rst),
        .in0_valid(runctl_host_out_valid),
        .in0_data(runctl_host_out_data),
        .out0_valid(run_control_splitter_out0_valid),
        .out0_data(run_control_splitter_out0_data),
        .out14_valid(run_control_splitter_out14_valid),
        .out14_data(run_control_splitter_out14_data),
        .out15_valid(run_control_splitter_out15_valid),
        .out15_data(run_control_splitter_out15_data)
    );

    feb_system_v3_data_path_subsystem_emulator_ctrl_splitter u_generated_emulator_ctrl_splitter (
        .clk(clk_125),
        .reset(rst),
        .in0_ready(emulator_ctrl_splitter_in_ready),
        .in0_valid(run_control_splitter_out14_valid),
        .in0_data(run_control_splitter_out14_data),
        .out0_ready(1'b1),
        .out0_valid(emulator_ctrl_splitter_out0_valid),
        .out0_data(emulator_ctrl_splitter_out0_data),
        .out1_ready(1'b1),
        .out1_valid(emulator_ctrl_splitter_out1_valid),
        .out1_data(emulator_ctrl_splitter_out1_data),
        .out2_ready(1'b1),
        .out3_ready(1'b1),
        .out4_ready(1'b1),
        .out5_ready(1'b1),
        .out6_ready(1'b1),
        .out7_ready(1'b1)
    );

    // emulator_running_from_splitter now latches the real 9-bit RUNNING state bit
    // after the current generated FEB splitter path, matching
    // emulator_mutrig/frontend_run_ctl.sv bit[3] semantics.
    logic emulator_running_from_splitter;
    logic [8:0] emulator_ctrl_state_from_splitter;
    always_ff @(posedge clk_125) begin
        if (rst) begin
            emulator_running_from_splitter <= 1'b0;
            emulator_ctrl_state_from_splitter <= 9'b000000001;
        end else if (emulator_ctrl_splitter_out0_valid) begin
            emulator_ctrl_state_from_splitter <= emulator_ctrl_splitter_out0_data;
            emulator_running_from_splitter <= emulator_ctrl_splitter_out0_data[3];
        end
    end

    // hist_total_hits_shadow is a cross-check against the real histogram CSR
    // responder below, gated by the same post-splitter emulator RUNNING state.
    logic [31:0] hist_total_hits_shadow;
    always_ff @(posedge clk_125) begin
        if (rst) begin
            hist_total_hits_shadow <= 32'h0;
        end else if (emulator_running_from_splitter && pre_rbcam_vif.valid) begin
            hist_total_hits_shadow <= hist_total_hits_shadow + 1'b1;
        end
    end

    localparam bit [31:0] FEB_HIST_CSR_BASE         = 32'h0000_A400;
    localparam bit [31:0] FEB_CSR_HISTO_BANK_STATUS = FEB_HIST_CSR_BASE + (32'd11 << 2);
    localparam bit [31:0] FEB_CSR_HISTO_PORT_STATUS = FEB_HIST_CSR_BASE + (32'd12 << 2);
    localparam bit [31:0] FEB_CSR_HISTO_TOTAL_HITS  = FEB_HIST_CSR_BASE + (32'd13 << 2);
    localparam bit [31:0] FEB_CSR_HISTO_DROPPED     = FEB_HIST_CSR_BASE + (32'd14 << 2);
    localparam bit [31:0] FEB_RUNCTL_HOST_CSR_BASE  = 32'h0000_C000;

    function automatic bit is_hist_csr_addr(input logic [31:0] addr);
        return (addr >= FEB_HIST_CSR_BASE) && (addr < (FEB_HIST_CSR_BASE + 32'h80));
    endfunction

    function automatic bit is_runctl_host_csr_addr(input logic [31:0] addr);
        return (addr >= FEB_RUNCTL_HOST_CSR_BASE) && (addr < (FEB_RUNCTL_HOST_CSR_BASE + 32'h80));
    endfunction

`ifndef TB_INT_BIND_REAL_DUT
    logic [31:0] hist_csr_readdata;
    logic        hist_csr_read;
    logic [4:0]  hist_csr_address;
    logic        hist_csr_waitrequest;
    logic        hist_csr_write;
    logic [31:0] hist_csr_writedata;
    logic [31:0] hist_bin_readdata;
    logic        hist_bin_waitrequest;
    logic        hist_bin_readdatavalid;
    logic        hist_bin_writeresponsevalid;
    logic [1:0]  hist_bin_response;
    logic        hist_fill_ready;
    logic        hist_fill_valid;
    logic [38:0] hist_fill_data;
    logic        hist_ext0_valid;
    logic [86:0] hist_ext0_data;
    logic        hist_ext1_valid;
    logic [86:0] hist_ext1_data;
    logic [31:0] hist_fill_valid_count;
    logic [31:0] hist_fill_accept_count;
    logic [31:0] hist_ext0_valid_count;
    logic [31:0] hist_ext1_valid_count;

    logic [31:0] wave_model_emulator_commit_to_egress_cycles;
    logic [31:0] wave_model_emulator_egress_to_rbcam_cycles;
    logic [31:0] wave_model_pre_rbcam_delay_cycles;
    logic [31:0] wave_model_post_rbcam_delay_cycles;
    logic [31:0] wave_model_feb_egress_delay_cycles;
    logic [31:0] wave_model_100khz_period_cycles;
    logic [4:0]  wave_model_periodic_channel;

    logic [3:0]  dec_stage_a_payload_asic;
    logic [4:0]  dec_stage_a_payload_channel;
    logic [14:0] dec_stage_a_payload_t_coarse;
    logic [4:0]  dec_stage_a_payload_t_fine;
    logic [14:0] dec_stage_a_payload_e_coarse;
    logic        dec_stage_a_payload_e_flag;
    logic [3:0]  dec_emulator_egress_payload_asic;
    logic [4:0]  dec_emulator_egress_payload_channel;
    logic [14:0] dec_emulator_egress_payload_t_coarse;
    logic [4:0]  dec_emulator_egress_payload_t_fine;
    logic [14:0] dec_emulator_egress_payload_e_coarse;
    logic        dec_emulator_egress_payload_e_flag;
    logic [3:0]  dec_pre_rbcam_payload_asic;
    logic [4:0]  dec_pre_rbcam_payload_channel;
    logic [14:0] dec_pre_rbcam_payload_t_coarse;
    logic [4:0]  dec_pre_rbcam_payload_t_fine;
    logic [14:0] dec_pre_rbcam_payload_e_coarse;
    logic        dec_pre_rbcam_payload_e_flag;
    logic [3:0]  dec_post_rbcam_payload_asic;
    logic [4:0]  dec_post_rbcam_payload_channel;
    logic [14:0] dec_post_rbcam_payload_t_coarse;
    logic [4:0]  dec_post_rbcam_payload_t_fine;
    logic [14:0] dec_post_rbcam_payload_e_coarse;
    logic        dec_post_rbcam_payload_e_flag;
    logic [3:0]  dec_feb_egress_payload_asic;
    logic [4:0]  dec_feb_egress_payload_channel;
    logic [14:0] dec_feb_egress_payload_t_coarse;
    logic [4:0]  dec_feb_egress_payload_t_fine;
    logic [14:0] dec_feb_egress_payload_e_coarse;
    logic        dec_feb_egress_payload_e_flag;

    assign wave_model_emulator_commit_to_egress_cycles = 32'd600;
    assign wave_model_emulator_egress_to_rbcam_cycles  = 32'd235;
    assign wave_model_pre_rbcam_delay_cycles  = wave_model_emulator_commit_to_egress_cycles
                                                + wave_model_emulator_egress_to_rbcam_cycles;
    assign wave_model_post_rbcam_delay_cycles = 32'd2070;
    assign wave_model_feb_egress_delay_cycles = 32'd3778;
    assign wave_model_100khz_period_cycles    = 32'd1250;
    assign wave_model_periodic_channel        = 5'd0;

    assign dec_stage_a_payload_asic      = stage_a_vif.payload[44:41];
    assign dec_stage_a_payload_channel   = stage_a_vif.payload[40:36];
    assign dec_stage_a_payload_t_coarse  = stage_a_vif.payload[35:21];
    assign dec_stage_a_payload_t_fine    = stage_a_vif.payload[20:16];
    assign dec_stage_a_payload_e_coarse  = stage_a_vif.payload[15:1];
    assign dec_stage_a_payload_e_flag    = stage_a_vif.payload[0];
    assign dec_emulator_egress_payload_asic = emulator_egress_vif.payload[44:41];
    assign dec_emulator_egress_payload_channel = emulator_egress_vif.payload[40:36];
    assign dec_emulator_egress_payload_t_coarse = emulator_egress_vif.payload[35:21];
    assign dec_emulator_egress_payload_t_fine = emulator_egress_vif.payload[20:16];
    assign dec_emulator_egress_payload_e_coarse = emulator_egress_vif.payload[15:1];
    assign dec_emulator_egress_payload_e_flag = emulator_egress_vif.payload[0];
    assign dec_pre_rbcam_payload_asic    = pre_rbcam_vif.payload[44:41];
    assign dec_pre_rbcam_payload_channel = pre_rbcam_vif.payload[40:36];
    assign dec_pre_rbcam_payload_t_coarse = pre_rbcam_vif.payload[35:21];
    assign dec_pre_rbcam_payload_t_fine  = pre_rbcam_vif.payload[20:16];
    assign dec_pre_rbcam_payload_e_coarse = pre_rbcam_vif.payload[15:1];
    assign dec_pre_rbcam_payload_e_flag  = pre_rbcam_vif.payload[0];
    assign dec_post_rbcam_payload_asic   = post_rbcam_vif.payload[44:41];
    assign dec_post_rbcam_payload_channel = post_rbcam_vif.payload[40:36];
    assign dec_post_rbcam_payload_t_coarse = post_rbcam_vif.payload[35:21];
    assign dec_post_rbcam_payload_t_fine = post_rbcam_vif.payload[20:16];
    assign dec_post_rbcam_payload_e_coarse = post_rbcam_vif.payload[15:1];
    assign dec_post_rbcam_payload_e_flag = post_rbcam_vif.payload[0];
    assign dec_feb_egress_payload_asic   = feb_egress_vif.payload[44:41];
    assign dec_feb_egress_payload_channel = feb_egress_vif.payload[40:36];
    assign dec_feb_egress_payload_t_coarse = feb_egress_vif.payload[35:21];
    assign dec_feb_egress_payload_t_fine = feb_egress_vif.payload[20:16];
    assign dec_feb_egress_payload_e_coarse = feb_egress_vif.payload[15:1];
    assign dec_feb_egress_payload_e_flag = feb_egress_vif.payload[0];

    // Match the generated FEB v3 Qsys contract: hist_fill_in is explicitly
    // tied off by hist_inactive_fill_source, while MTS Type-1 payloads reach
    // histogram_statistics through the readyless extended ingress.
    assign hist_fill_valid = 1'b0;
    assign hist_fill_data  = 39'd0;
    assign hist_ext0_valid = emulator_running_from_splitter && pre_rbcam_vif.valid;
    assign hist_ext0_data  = {
        (pre_rbcam_vif.true_hit_ts_valid ? pre_rbcam_vif.true_hit_ts : 48'd0),
        pre_rbcam_vif.payload[38:0]
    };
    assign hist_ext1_valid = 1'b0;
    assign hist_ext1_data  = 87'd0;
    assign hist_csr_read   = sc_phy_vif.read && is_hist_csr_addr(sc_phy_vif.address);
    assign hist_csr_write  = sc_phy_vif.write && is_hist_csr_addr(sc_phy_vif.address);
    assign hist_csr_address = sc_phy_vif.address[6:2];
    assign hist_csr_writedata = sc_phy_vif.writedata;
    assign runctl_host_csr_read = sc_phy_vif.read && is_runctl_host_csr_addr(sc_phy_vif.address);
    assign runctl_host_csr_write = sc_phy_vif.write && is_runctl_host_csr_addr(sc_phy_vif.address);
    assign runctl_host_csr_address = sc_phy_vif.address[6:2];

    always_ff @(posedge clk_125) begin
        if (rst) begin
            hist_fill_valid_count  <= 32'd0;
            hist_fill_accept_count <= 32'd0;
            hist_ext0_valid_count  <= 32'd0;
            hist_ext1_valid_count  <= 32'd0;
        end else begin
            if (hist_fill_valid)
                hist_fill_valid_count <= hist_fill_valid_count + 1'b1;
            if (hist_fill_valid && hist_fill_ready)
                hist_fill_accept_count <= hist_fill_accept_count + 1'b1;
            if (hist_ext0_valid)
                hist_ext0_valid_count <= hist_ext0_valid_count + 1'b1;
            if (hist_ext1_valid)
                hist_ext1_valid_count <= hist_ext1_valid_count + 1'b1;
        end
    end

    final begin
        $display("TB_INT_HIST_INGRESS_SUMMARY fill_valid=%0d fill_accept=%0d ext0_valid=%0d ext1_valid=%0d last_fill_ready=%0b hist_total_hits_shadow=%0d",
                 hist_fill_valid_count,
                 hist_fill_accept_count,
                 hist_ext0_valid_count,
                 hist_ext1_valid_count,
                 hist_fill_ready,
                 hist_total_hits_shadow);
    end

    histogram_statistics_v2 #(
        .DEF_LEFT_BOUND(0),
        .DEF_BIN_WIDTH(16),
        .AVS_ADDR_WIDTH(8),
        .N_PORTS(1),
        .FIFO_ADDR_WIDTH(8),
        .ENABLE_PINGPONG(1'b1),
        .DEF_INTERVAL_CLOCKS(125000000),
        .AVST_DATA_WIDTH(39),
        .AVST_CHANNEL_WIDTH(4),
        .N_DEBUG_INTERFACE(0),
        .SNOOP_EN(1'b0),
        .ENABLE_PACKET(1'b0),
        .DEBUG(0)
    ) u_hist (
        .avs_hist_bin_readdata(hist_bin_readdata),
        .avs_hist_bin_read(1'b0),
        .avs_hist_bin_address(8'd0),
        .avs_hist_bin_waitrequest(hist_bin_waitrequest),
        .avs_hist_bin_write(1'b0),
        .avs_hist_bin_writedata(32'd0),
        .avs_hist_bin_burstcount(9'd1),
        .avs_hist_bin_readdatavalid(hist_bin_readdatavalid),
        .avs_hist_bin_writeresponsevalid(hist_bin_writeresponsevalid),
        .avs_hist_bin_response(hist_bin_response),

        .avs_csr_readdata(hist_csr_readdata),
        .avs_csr_read(hist_csr_read),
        .avs_csr_address(hist_csr_address),
        .avs_csr_waitrequest(hist_csr_waitrequest),
        .avs_csr_write(hist_csr_write),
        .avs_csr_writedata(hist_csr_writedata),

        .asi_hist_fill_in_ready(hist_fill_ready),
        .asi_hist_fill_in_valid(hist_fill_valid),
        .asi_hist_fill_in_data(hist_fill_data),
        .asi_hist_fill_in_startofpacket(1'b0),
        .asi_hist_fill_in_endofpacket(1'b0),
        .asi_hist_fill_in_channel(pre_rbcam_vif.lane_id),

        .asi_fill_in_1_ready(),
        .asi_fill_in_1_valid(1'b0),
        .asi_fill_in_1_data(39'd0),
        .asi_fill_in_1_startofpacket(1'b0),
        .asi_fill_in_1_endofpacket(1'b0),
        .asi_fill_in_1_channel(4'd0),
        .asi_fill_in_2_ready(),
        .asi_fill_in_2_valid(1'b0),
        .asi_fill_in_2_data(39'd0),
        .asi_fill_in_2_startofpacket(1'b0),
        .asi_fill_in_2_endofpacket(1'b0),
        .asi_fill_in_2_channel(4'd0),
        .asi_fill_in_3_ready(),
        .asi_fill_in_3_valid(1'b0),
        .asi_fill_in_3_data(39'd0),
        .asi_fill_in_3_startofpacket(1'b0),
        .asi_fill_in_3_endofpacket(1'b0),
        .asi_fill_in_3_channel(4'd0),
        .asi_fill_in_4_ready(),
        .asi_fill_in_4_valid(1'b0),
        .asi_fill_in_4_data(39'd0),
        .asi_fill_in_4_startofpacket(1'b0),
        .asi_fill_in_4_endofpacket(1'b0),
        .asi_fill_in_4_channel(4'd0),
        .asi_fill_in_5_ready(),
        .asi_fill_in_5_valid(1'b0),
        .asi_fill_in_5_data(39'd0),
        .asi_fill_in_5_startofpacket(1'b0),
        .asi_fill_in_5_endofpacket(1'b0),
        .asi_fill_in_5_channel(4'd0),
        .asi_fill_in_6_ready(),
        .asi_fill_in_6_valid(1'b0),
        .asi_fill_in_6_data(39'd0),
        .asi_fill_in_6_startofpacket(1'b0),
        .asi_fill_in_6_endofpacket(1'b0),
        .asi_fill_in_6_channel(4'd0),
        .asi_fill_in_7_ready(),
        .asi_fill_in_7_valid(1'b0),
        .asi_fill_in_7_data(39'd0),
        .asi_fill_in_7_startofpacket(1'b0),
        .asi_fill_in_7_endofpacket(1'b0),
        .asi_fill_in_7_channel(4'd0),

        .asi_hit_type1_extended_0_valid(hist_ext0_valid),
        .asi_hit_type1_extended_0_data(hist_ext0_data),
        .asi_hit_type1_extended_1_valid(hist_ext1_valid),
        .asi_hit_type1_extended_1_data(hist_ext1_data),

        .aso_hist_fill_out_ready(1'b1),
        .aso_hist_fill_out_valid(),
        .aso_hist_fill_out_data(),
        .aso_hist_fill_out_startofpacket(),
        .aso_hist_fill_out_endofpacket(),
        .aso_hist_fill_out_channel(),

        .asi_ctrl_data(9'd0),
        .asi_ctrl_valid(1'b0),

        .asi_debug_1_valid(1'b0),
        .asi_debug_1_data(16'd0),
        .asi_debug_2_valid(1'b0),
        .asi_debug_2_data(16'd0),
        .asi_debug_3_valid(1'b0),
        .asi_debug_3_data(16'd0),
        .asi_debug_4_valid(1'b0),
        .asi_debug_4_data(16'd0),
        .asi_debug_5_valid(1'b0),
        .asi_debug_5_data(16'd0),
        .asi_debug_6_valid(1'b0),
        .asi_debug_6_data(16'd0),

        .i_interval_reset(1'b0),
        .i_rst(rst),
        .i_clk(clk_125)
    );

    logic        sc_read_q;
    logic        sc_hist_read_q;
    logic        sc_runctl_host_read_q;
    logic [31:0] sc_addr_q;
    logic        sc_resp_pending_q;

    // SC AVMM responder backed by the real histogram CSR aperture from the
    // generated Qsys map. Data is staged before readdatavalid so the direct
    // tb_int polling sequences sample the VHDL CSR output after it has settled.
    always_ff @(posedge clk_125) begin
        if (rst) begin
            sc_read_q <= 1'b0;
            sc_hist_read_q <= 1'b0;
            sc_runctl_host_read_q <= 1'b0;
            sc_addr_q <= 32'h0;
            sc_resp_pending_q <= 1'b0;
            sc_phy_vif.readdatavalid <= 1'b0;
            sc_phy_vif.readdata <= 32'h0000_0000;
        end else begin
            sc_read_q <= sc_phy_vif.read;
            sc_hist_read_q <= sc_phy_vif.read && is_hist_csr_addr(sc_phy_vif.address);
            sc_runctl_host_read_q <= sc_phy_vif.read && is_runctl_host_csr_addr(sc_phy_vif.address);
            sc_addr_q <= sc_phy_vif.address;
            sc_resp_pending_q <= sc_read_q;
            sc_phy_vif.readdatavalid <= sc_resp_pending_q;
            if (sc_read_q) begin
                if (sc_hist_read_q)
                    sc_phy_vif.readdata <= hist_csr_readdata;
                else if (sc_runctl_host_read_q)
                    sc_phy_vif.readdata <= runctl_host_csr_readdata;
                else if (sc_addr_q == FEB_CSR_HISTO_TOTAL_HITS)
                    sc_phy_vif.readdata <= hist_total_hits_shadow;
                else
                    sc_phy_vif.readdata <= 32'h4849_5354;
            end
        end
    end
`else
    always_ff @(posedge clk_125) begin
        if (rst) begin
            sc_phy_vif.readdatavalid <= 1'b0;
            sc_phy_vif.readdata <= 32'h0000_0000;
        end else begin
            sc_phy_vif.readdatavalid <= sc_phy_vif.read;
            if (sc_phy_vif.address == FEB_CSR_HISTO_TOTAL_HITS)
                sc_phy_vif.readdata <= hist_total_hits_shadow;
            else
                sc_phy_vif.readdata <= 32'h4849_5354;
        end
    end
`endif

    initial begin
        uvm_config_db#(virtual lvds_phy_if)::set(null,
                                                 "uvm_test_top.env.nominal.mutrig_phy.drv",
                                                 "vif",
                                                 lvds_phy_vif);
        uvm_config_db#(virtual runctl_phy_if)::set(null,
                                                   "uvm_test_top.env.nominal.runctl_phy.drv",
                                                   "vif",
                                                   runctl_phy_vif);
        uvm_config_db#(virtual sc_avmm_if)::set(null,
                                                "uvm_test_top.env.nominal.sc_phy.drv",
                                                "vif",
                                                sc_phy_vif);
        uvm_config_db#(virtual sc_avmm_if)::set(null,
                                                "uvm_test_top.env.nominal.histogram_mon",
                                                "vif",
                                                sc_phy_vif);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null,
                                                         "uvm_test_top.env.nominal.l2_commit_mon0",
                                                         "vif",
                                                         stage_a_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.nominal.pre_rbcam_mon0",
                                                "vif",
                                                pre_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.nominal.post_rbcam_mon0",
                                                "vif",
                                                post_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.nominal.feb_egress_mon0",
                                                "vif",
                                                feb_egress_vif);
        uvm_config_db#(virtual mu3e_frame_if)::set(null,
                                                   "uvm_test_top.env.nominal.feb_frame_mon0",
                                                   "vif",
                                                   upload_data0_frame_vif);
        uvm_config_db#(virtual mu3e_frame_if)::set(null,
                                                   "uvm_test_top.env.nominal.feb_frame_mon1",
                                                   "vif",
                                                   upload_data1_frame_vif);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null,
                                                         "uvm_test_top.env.debug.debug_l2_mon0",
                                                         "vif",
                                                         debug_l2_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.debug.debug_pre_rbcam_mon0",
                                                "vif",
                                                debug_pre_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.debug.debug_post_rbcam_mon0",
                                                "vif",
                                                debug_post_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.debug.debug_feb_egress_mon0",
                                                "vif",
                                                debug_feb_egress_vif);
        uvm_config_db#(virtual debug_fill_if)::set(null,
                                                   "uvm_test_top.env.debug.fill_mon0",
                                                   "vif",
                                                   fill_vif);
        uvm_config_db#(virtual tb_int_counter_if)::set(null,
                                                       "uvm_test_top.env.scoreboard",
                                                       "counter_vif",
                                                       counter_vif);

        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null,
                                                         "uvm_test_top",
                                                         "stage_a_vif",
                                                         stage_a_vif);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null,
                                                         "uvm_test_top",
                                                         "debug_l2_vif",
                                                         debug_l2_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "emulator_egress_vif",
                                                emulator_egress_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "debug_emulator_egress_vif",
                                                debug_emulator_egress_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "pre_rbcam_vif",
                                                pre_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "post_rbcam_vif",
                                                post_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "debug_pre_rbcam_vif",
                                                debug_pre_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "debug_post_rbcam_vif",
                                                debug_post_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "debug_feb_egress_vif",
                                                debug_feb_egress_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top",
                                                "feb_egress_vif",
                                                feb_egress_vif);
        uvm_config_db#(virtual mu3e_frame_if)::set(null,
                                                   "uvm_test_top",
                                                   "upload_data0_frame_vif",
                                                   upload_data0_frame_vif);
        uvm_config_db#(virtual mu3e_frame_if)::set(null,
                                                   "uvm_test_top",
                                                   "upload_data1_frame_vif",
                                                   upload_data1_frame_vif);
        // Test-scope vifs for the directed run-control + emulator
        // hit-flow sequence (BUG-RC-RUN-EMUL Phase 3 repro). The sequence
        // bypasses the runctl_phy_agent / sc_phy_agent sequencer chains and
        // drives runctl_phy / sc_phy directly, mirroring the existing
        // tb_int_basic_sequences hit-injection pattern that drives
        // stage_a / pre_rbcam / post_rbcam / feb_egress interfaces directly
        // from the sequence.
        uvm_config_db#(virtual runctl_phy_if)::set(null,
                                                   "uvm_test_top",
                                                   "runctl_phy_vif",
                                                   runctl_phy_vif);
        uvm_config_db#(virtual sc_avmm_if)::set(null,
                                                "uvm_test_top",
                                                "sc_phy_vif",
                                                sc_phy_vif);
        run_test();
    end
endmodule
