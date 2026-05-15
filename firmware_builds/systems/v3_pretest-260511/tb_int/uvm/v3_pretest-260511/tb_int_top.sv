// tb_int_top.sv
// Top-level simulator shell for v3_pretest-260511/tb_int.
//
// Behavioural topology stubs (BUG-RC-RUN-EMUL Phase 3 repro). The
// mock_run_control_splitter + mock_run_state_latch + macros are defined in
// tb_int_topology_models.sv. The SV macro scope is per-compilation-unit,
// so the file is `included here to bring the macros and module typedefs
// into tb_int_top's compilation unit. The header-guard inside the file
// prevents redefinition when it is also referenced from elsewhere.
`include "tb_int_topology_models.sv"

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
    // Directed run-control + emulator hit-flow test (BUG-RC-RUN-EMUL Phase 3 repro)
    import tb_int_run_emulator_directed_test_pkg::*;
    // BUG-RC-RUN-EMUL behavioural topology repro: pre-fix (blocked) and post-fix
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
    hit_tap_if           pre_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_pre_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_post_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           debug_feb_egress_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           feb_egress_vif(.clk(clk_125), .rst(rst));
    debug_fill_if        fill_vif(.clk(clk_125), .rst(rst));
    tb_int_counter_if    counter_vif(.clk(clk_125), .rst(rst));

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
        .upload_data0_sc_rc_ready(1'b1),
        .upload_data1_ready(1'b1)
    );
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
        pre_rbcam_vif.clear();
        post_rbcam_vif.clear();
        debug_pre_rbcam_vif.clear();
        debug_post_rbcam_vif.clear();
        debug_feb_egress_vif.clear();
        feb_egress_vif.clear();
        fill_vif.clear();
        counter_vif.clear();
        lvds_phy_vif.clear();
        runctl_phy_vif.clear();
        sc_phy_vif.clear_master();
        sc_phy_vif.waitrequest = 1'b0;
        repeat (6) @(posedge clk_125);
        rst = 1'b0;
    end

    // BUG-RC-RUN-EMUL behavioural topology model. Models the
    // run_control_splitter inside scifi_datapath_system_v3_pipe.qsys:
    //   - mock_run_state_latch decodes opcode 0x12 (START_RUN) and latches a
    //     RUNNING one-hot that the splitter then broadcasts.
    //   - mock_run_control_splitter is USE_READY=0 on paper but its silicon
    //     implementation still has internal outN_ready inputs. Dangling
    //     outN_ready (no driver) collapses out_valid to 0 by AND default.
    //   - mock_emulator_running latches the splitter output corresponding
    //     to the emulator_mutrig RUNNING enable. Without the fix the
    //     dangling-ready collapse keeps mock_emulator_running=0; with the
    //     BUG_RC_RUN_EMUL_FIXED guard, the outN_ready inputs are tied to
    //     1'b1 and the broadcast propagates.
    //   - mock_total_hits_cnt counts stage_a_vif.valid edges that occur
    //     while mock_emulator_running is high. The SC AVMM responder
    //     below returns this counter when address 0x0000_2000
    //     (CSR_HISTO_TOTAL_HITS) is read, mirroring the on-board
    //     histogram_statistics.TOTAL_HITS register.
    logic [7:0] mock_run_state_onehot;
    logic       mock_run_state_valid;

    logic                                  splitter_out_valid [TB_INT_SPLITTER_FANOUT_PORTS];
    logic [7:0]                            splitter_out_data  [TB_INT_SPLITTER_FANOUT_PORTS];
    // outN_ready inputs to the splitter. PRE-FIX: keep these as unassigned
    // `logic` (no driver) -- the splitter treats X as 0 and the broadcast
    // collapses, modelling the B002 silicon symptom. POST-FIX (define
    // BUG_RC_RUN_EMUL_FIXED): the splitter ignores out_ready and ties
    // internal readies to 1'b1, so the broadcast passes through.
    logic                                  splitter_out_ready [TB_INT_SPLITTER_FANOUT_PORTS];

    // PRE-FIX: explicitly leave splitter_out_ready dangling (no continuous
    // assignment). SV defaults Z; mock_run_control_splitter resolves Z as
    // 0 internally (see ready_int comb in tb_int_topology_models.sv).
    // POST-FIX: don't touch -- the model ignores out_ready entirely.

    mock_run_state_latch u_mock_run_state_latch (
        .clk             (clk_125),
        .rst             (rst),
        .runctl_data     (runctl_phy_vif.data),
        .runctl_valid    (runctl_phy_vif.valid),
        .run_state_onehot(mock_run_state_onehot),
        .run_state_valid (mock_run_state_valid)
    );

    mock_run_control_splitter u_mock_run_control_splitter (
        .clk     (clk_125),
        .rst     (rst),
        .in_valid(mock_run_state_valid),
        .in_data (mock_run_state_onehot),
        .out_valid(splitter_out_valid),
        .out_data (splitter_out_data),
        .out_ready(splitter_out_ready)
    );

    // mock_emulator_running: latched RUNNING enable seen at splitter port 0
    // (== emulator_mutrig lane 0 RUNNING). On silicon this is the signal
    // that gates emulator_mutrig hit emission during the run window.
    logic mock_emulator_running;
    always_ff @(posedge clk_125) begin
        if (rst) begin
            mock_emulator_running <= 1'b0;
        end else if (splitter_out_valid[0]) begin
            mock_emulator_running <= splitter_out_data[0][0];
        end
    end

    // mock_total_hits_cnt: counts stage_a_vif.valid edges seen while the
    // splitter delivered RUNNING. Mirrors the on-board
    // histogram_statistics.TOTAL_HITS register.
    logic [31:0] mock_total_hits_cnt;
    always_ff @(posedge clk_125) begin
        if (rst) begin
            mock_total_hits_cnt <= 32'h0;
        end else if (mock_emulator_running && stage_a_vif.valid) begin
            mock_total_hits_cnt <= mock_total_hits_cnt + 1'b1;
        end
    end

    // SC AVMM responder. Default returns 32'h4849_5354 ("HIST"). When the
    // master reads CSR_HISTO_TOTAL_HITS (byte addr 0x0000_2000), return the
    // mock_total_hits_cnt so the run_emulator_directed sequence can
    // distinguish the pre-fix (0) vs post-fix (16) cases.
    localparam bit [31:0] FEB_CSR_HISTO_TOTAL_HITS = 32'h0000_2000;
    always_ff @(posedge clk_125) begin
        if (rst) begin
            sc_phy_vif.readdatavalid <= 1'b0;
            sc_phy_vif.readdata <= 32'h0000_0000;
        end else begin
            sc_phy_vif.readdatavalid <= sc_phy_vif.read;
            if (sc_phy_vif.address == FEB_CSR_HISTO_TOTAL_HITS)
                sc_phy_vif.readdata <= mock_total_hits_cnt;
            else
                sc_phy_vif.readdata <= 32'h4849_5354;
        end
    end

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
