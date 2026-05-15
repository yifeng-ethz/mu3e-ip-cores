// tb_int_top.sv
// Top-level simulator shell for v3_pretest-260511/tb_int.

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

    always_ff @(posedge clk_125) begin
        if (rst) begin
            sc_phy_vif.readdatavalid <= 1'b0;
            sc_phy_vif.readdata <= 32'h0000_0000;
        end else begin
            sc_phy_vif.readdatavalid <= sc_phy_vif.read;
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
        run_test();
    end
endmodule
