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

    logic clk_125;
    logic rst;

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
    feb_system_v3 u_dut();
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
    //     outN_ready (no driver) used to collapse out_valid to 0 by AND
    //     default. The fixed model ties the internal ready terms high.
    //   - mock_emulator_running latches the splitter output corresponding
    //     to the emulator_mutrig RUNNING enable. Without the fix the
    //     historical TB_INT_REPRO_DANGLING_READY repro keeps
    //     mock_emulator_running=0; the default fixed model ties the internal
    //     outN_ready terms to 1'b1 and the broadcast propagates.
    //   - the histogram CSR model counts the selected Type-1 timestamp tap
    //     while mock_emulator_running is high. The SC AVMM responder below
    //     exposes the V3 histogram and ingress-bridge CSR windows, including
    //     ping-pong live/last counters.
    logic [7:0] mock_run_state_onehot;
    logic       mock_run_state_valid;

    logic                                  splitter_out_valid [TB_INT_SPLITTER_FANOUT_PORTS];
    logic [7:0]                            splitter_out_data  [TB_INT_SPLITTER_FANOUT_PORTS];
    // outN_ready inputs to the splitter. The fixed readyless model ignores
    // these and ties internal readies to 1'b1. The explicit
    // TB_INT_REPRO_DANGLING_READY build keeps them unassigned so the old
    // zero-hit signature can still be reproduced.
    logic                                  splitter_out_ready [TB_INT_SPLITTER_FANOUT_PORTS];

    // Deliberately no continuous assignment here: fixed builds ignore the
    // port, while the explicit repro build resolves the dangling value as 0.

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

    // Histogram/bridge CSR model. This mirrors the V3 parent map used by
    // refresh_v3_histogram_parent_binding.tcl closely enough for tb_int to
    // configure the histogram before RUNNING, let the ping-pong interval
    // roll, and read back the rate counters through SC AVMM.
    localparam bit [31:0] FEB_HIST_CSR_BASE                 = 32'h0000_A400;
    localparam bit [31:0] FEB_HIST_CSR_CONTROL              = FEB_HIST_CSR_BASE + 32'h008;
    localparam bit [31:0] FEB_HIST_CSR_INTERVAL_CFG         = FEB_HIST_CSR_BASE + 32'h028;
    localparam bit [31:0] FEB_HIST_CSR_BANK_STATUS          = FEB_HIST_CSR_BASE + 32'h02C;
    localparam bit [31:0] FEB_HIST_CSR_PORT_STATUS          = FEB_HIST_CSR_BASE + 32'h030;
    localparam bit [31:0] FEB_HIST_CSR_TOTAL_HITS           = FEB_HIST_CSR_BASE + 32'h034;
    localparam bit [31:0] FEB_HIST_CSR_DROPPED_HITS         = FEB_HIST_CSR_BASE + 32'h038;
    localparam bit [31:0] FEB_HIST_CSR_LAST_TOTAL_HITS      = FEB_HIST_CSR_BASE + 32'h044;
    localparam bit [31:0] FEB_HIST_CSR_LAST_DROPPED_HITS    = FEB_HIST_CSR_BASE + 32'h048;
    localparam bit [31:0] FEB_HIST_BRIDGE_CSR_BASE          = 32'h0000_AC00;
    localparam bit [31:0] FEB_HIST_BRIDGE_CSR_CONTROL       = FEB_HIST_BRIDGE_CSR_BASE + 32'h008;
    localparam bit [31:0] FEB_HIST_BRIDGE_CSR_STATUS        = FEB_HIST_BRIDGE_CSR_BASE + 32'h00C;
    localparam bit [31:0] FEB_HIST_BRIDGE_CSR_PRE_COUNT     = FEB_HIST_BRIDGE_CSR_BASE + 32'h010;
    localparam bit [31:0] FEB_HIST_BRIDGE_CSR_POST_COUNT    = FEB_HIST_BRIDGE_CSR_BASE + 32'h014;
    localparam bit [31:0] FEB_HIST_BRIDGE_CSR_HIST_COUNT    = FEB_HIST_BRIDGE_CSR_BASE + 32'h018;
    localparam bit [31:0] FEB_HIST_BRIDGE_CSR_DROP_COUNT    = FEB_HIST_BRIDGE_CSR_BASE + 32'h01C;
    localparam bit [31:0] FEB_LEGACY_CSR_HISTO_TOTAL_HITS   = 32'h0000_2000;

    logic [31:0] mock_hist_interval_cfg;
    logic [31:0] mock_hist_interval_counter;
    logic [31:0] mock_hist_current_total_cnt;
    logic [31:0] mock_hist_last_interval_total_cnt;
    logic [31:0] mock_hist_current_drop_cnt;
    logic [31:0] mock_hist_last_interval_drop_cnt;
    logic        mock_hist_active_bank;
    logic [3:0]  mock_hist_mode;
    logic        mock_hist_key_unsigned;
    logic        mock_hist_filter_enable;
    logic        mock_hist_filter_reject;
    logic        mock_bridge_select_post_req;
    logic        mock_bridge_select_post_live;
    logic [31:0] mock_bridge_pre_seen_cnt;
    logic [31:0] mock_bridge_post_seen_cnt;
    logic [31:0] mock_bridge_hist_emit_cnt;
    logic [31:0] mock_bridge_hist_drop_cnt;

    wire mock_pre_type1_valid  = pre_rbcam_vif.valid  && pre_rbcam_vif.true_hit_ts_valid;
    wire mock_post_type1_valid = post_rbcam_vif.valid && post_rbcam_vif.true_hit_ts_valid;
    wire mock_selected_hist_valid = mock_bridge_select_post_live ? mock_post_type1_valid : mock_pre_type1_valid;
    wire mock_hist_count_valid = mock_emulator_running && mock_selected_hist_valid;
    wire mock_hist_interval_fire = (mock_hist_interval_cfg != 32'h0)
        && (mock_hist_interval_counter >= (mock_hist_interval_cfg - 32'd1));

    function automatic bit [31:0] hist_control_readback();
        hist_control_readback = 32'h0;
        hist_control_readback[7:4] = mock_hist_mode;
        hist_control_readback[8] = mock_hist_key_unsigned;
        hist_control_readback[12] = mock_hist_filter_enable;
        hist_control_readback[13] = mock_hist_filter_reject;
    endfunction

    function automatic bit [31:0] hist_bank_status_readback();
        hist_bank_status_readback = 32'h0;
        hist_bank_status_readback[0] = mock_hist_active_bank;
    endfunction

    function automatic bit [31:0] hist_port_status_readback();
        hist_port_status_readback = 32'h0;
        hist_port_status_readback[7:0] = mock_selected_hist_valid ? 8'hFE : 8'hFF;
        hist_port_status_readback[15:8] = (mock_bridge_hist_emit_cnt != 32'h0) ? 8'h01 : 8'h00;
    endfunction

    function automatic bit [31:0] bridge_status_readback();
        bridge_status_readback = 32'h0;
        bridge_status_readback[0] = mock_bridge_select_post_live;
        bridge_status_readback[1] = mock_bridge_select_post_req;
    endfunction

    always_ff @(posedge clk_125) begin
        if (rst) begin
            mock_hist_interval_cfg <= 32'd125000000;
            mock_hist_interval_counter <= 32'h0;
            mock_hist_current_total_cnt <= 32'h0;
            mock_hist_last_interval_total_cnt <= 32'h0;
            mock_hist_current_drop_cnt <= 32'h0;
            mock_hist_last_interval_drop_cnt <= 32'h0;
            mock_hist_active_bank <= 1'b0;
            mock_hist_mode <= 4'h0;
            mock_hist_key_unsigned <= 1'b1;
            mock_hist_filter_enable <= 1'b0;
            mock_hist_filter_reject <= 1'b0;
            mock_bridge_select_post_req <= 1'b0;
            mock_bridge_select_post_live <= 1'b0;
            mock_bridge_pre_seen_cnt <= 32'h0;
            mock_bridge_post_seen_cnt <= 32'h0;
            mock_bridge_hist_emit_cnt <= 32'h0;
            mock_bridge_hist_drop_cnt <= 32'h0;
            sc_phy_vif.readdatavalid <= 1'b0;
            sc_phy_vif.readdata <= 32'h0000_0000;
        end else begin
            sc_phy_vif.readdatavalid <= sc_phy_vif.read;

            if (sc_phy_vif.write) begin
                case (sc_phy_vif.address)
                    FEB_HIST_CSR_CONTROL: begin
                        mock_hist_mode <= sc_phy_vif.writedata[7:4];
                        mock_hist_key_unsigned <= sc_phy_vif.writedata[8];
                        mock_hist_filter_enable <= sc_phy_vif.writedata[12];
                        mock_hist_filter_reject <= sc_phy_vif.writedata[13];
                    end
                    FEB_HIST_CSR_INTERVAL_CFG: begin
                        mock_hist_interval_cfg <= sc_phy_vif.writedata;
                        mock_hist_interval_counter <= 32'h0;
                        mock_hist_current_total_cnt <= 32'h0;
                        mock_hist_current_drop_cnt <= 32'h0;
                    end
                    FEB_HIST_BRIDGE_CSR_CONTROL: begin
                        mock_bridge_select_post_req <= sc_phy_vif.writedata[0];
                        mock_bridge_select_post_live <= sc_phy_vif.writedata[0];
                        if (sc_phy_vif.writedata[8]) begin
                            mock_bridge_pre_seen_cnt <= 32'h0;
                            mock_bridge_post_seen_cnt <= 32'h0;
                            mock_bridge_hist_emit_cnt <= 32'h0;
                            mock_bridge_hist_drop_cnt <= 32'h0;
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (mock_hist_interval_fire) begin
                mock_hist_last_interval_total_cnt <= mock_hist_current_total_cnt;
                mock_hist_last_interval_drop_cnt <= mock_hist_current_drop_cnt;
                mock_hist_current_total_cnt <= 32'h0;
                mock_hist_current_drop_cnt <= 32'h0;
                mock_hist_interval_counter <= 32'h0;
                mock_hist_active_bank <= ~mock_hist_active_bank;
            end else if (mock_hist_interval_cfg != 32'h0) begin
                mock_hist_interval_counter <= mock_hist_interval_counter + 32'd1;
            end

            if (mock_emulator_running && mock_pre_type1_valid && mock_bridge_pre_seen_cnt != 32'hFFFF_FFFF)
                mock_bridge_pre_seen_cnt <= mock_bridge_pre_seen_cnt + 32'd1;
            if (mock_emulator_running && mock_post_type1_valid && mock_bridge_post_seen_cnt != 32'hFFFF_FFFF)
                mock_bridge_post_seen_cnt <= mock_bridge_post_seen_cnt + 32'd1;
            if (mock_hist_count_valid) begin
                if (mock_hist_interval_fire)
                    mock_hist_current_total_cnt <= 32'd1;
                else if (mock_hist_current_total_cnt != 32'hFFFF_FFFF)
                    mock_hist_current_total_cnt <= mock_hist_current_total_cnt + 32'd1;

                if (mock_bridge_hist_emit_cnt != 32'hFFFF_FFFF)
                    mock_bridge_hist_emit_cnt <= mock_bridge_hist_emit_cnt + 32'd1;
            end

            case (sc_phy_vif.address)
                FEB_HIST_CSR_CONTROL:
                    sc_phy_vif.readdata <= hist_control_readback();
                FEB_HIST_CSR_INTERVAL_CFG:
                    sc_phy_vif.readdata <= mock_hist_interval_cfg;
                FEB_HIST_CSR_BANK_STATUS:
                    sc_phy_vif.readdata <= hist_bank_status_readback();
                FEB_HIST_CSR_PORT_STATUS:
                    sc_phy_vif.readdata <= hist_port_status_readback();
                FEB_HIST_CSR_TOTAL_HITS,
                FEB_LEGACY_CSR_HISTO_TOTAL_HITS:
                    sc_phy_vif.readdata <= mock_hist_current_total_cnt;
                FEB_HIST_CSR_DROPPED_HITS:
                    sc_phy_vif.readdata <= mock_hist_current_drop_cnt;
                FEB_HIST_CSR_LAST_TOTAL_HITS:
                    sc_phy_vif.readdata <= mock_hist_last_interval_total_cnt;
                FEB_HIST_CSR_LAST_DROPPED_HITS:
                    sc_phy_vif.readdata <= mock_hist_last_interval_drop_cnt;
                FEB_HIST_BRIDGE_CSR_CONTROL:
                    sc_phy_vif.readdata <= {31'h0, mock_bridge_select_post_req};
                FEB_HIST_BRIDGE_CSR_STATUS:
                    sc_phy_vif.readdata <= bridge_status_readback();
                FEB_HIST_BRIDGE_CSR_PRE_COUNT:
                    sc_phy_vif.readdata <= mock_bridge_pre_seen_cnt;
                FEB_HIST_BRIDGE_CSR_POST_COUNT:
                    sc_phy_vif.readdata <= mock_bridge_post_seen_cnt;
                FEB_HIST_BRIDGE_CSR_HIST_COUNT:
                    sc_phy_vif.readdata <= mock_bridge_hist_emit_cnt;
                FEB_HIST_BRIDGE_CSR_DROP_COUNT:
                    sc_phy_vif.readdata <= mock_bridge_hist_drop_cnt;
                default:
                    sc_phy_vif.readdata <= 32'h4849_5354;
            endcase
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
