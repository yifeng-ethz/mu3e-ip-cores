// tb_int_top.sv
// Top-level simulator shell for system_20260504_emulator_type0/tb_int.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add UVM top, clocks, reset, focus-DUT hook, and interface wiring.

module tb_int_top;
    timeunit 1ps;
    timeprecision 1ps;

`ifdef TB_INT_STATIC_SCREEN
`ifndef TB_INT_SIM
    logic clk_125;
    logic rst;

    assign clk_125 = 1'b0;
    assign rst     = 1'b0;
`else
`define TB_INT_FULL_SIM_TOP
`endif
`else
`define TB_INT_FULL_SIM_TOP
`endif

`ifdef TB_INT_FULL_SIM_TOP
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
    import tb_int_smoke_test_pkg::*;
    `include "uvm_macros.svh"

    logic clk_125;
    logic rst;

    lvds_phy_if          lvds_phy_vif(.clk(clk_125), .rst(rst));
    runctl_phy_if        runctl_phy_vif(.clk(clk_125), .rst(rst));
    sc_avmm_if           sc_phy_vif(.clk(clk_125), .rst(rst));
    mutrig_l2_commit_if  stage_a_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           pre_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           post_rbcam_vif(.clk(clk_125), .rst(rst));
    hit_tap_if           feb_egress_vif(.clk(clk_125), .rst(rst));

`ifdef TB_INT_BIND_REAL_DUT
    // The generated focus-build instance is kept behind an explicit define
    // until the full Qsys simulation filelist is promoted. The hook preserves
    // the binding point without editing generated Qsys XML/synthesis output.
    focus_emulator_type0_system u_focus_dut();
`endif

    tb_int_assertions u_tb_int_assertions (
        .clk              (clk_125),
        .rst              (rst),
        .stage_a_valid    (stage_a_vif.valid),
        .pre_rbcam_valid  (pre_rbcam_vif.valid),
        .post_rbcam_valid (post_rbcam_vif.valid),
        .feb_egress_valid (feb_egress_vif.valid)
    );

    initial begin
        clk_125 = 1'b0;
        forever #4000 clk_125 = ~clk_125;
    end

    initial begin
        rst = 1'b1;
        stage_a_vif.clear();
        pre_rbcam_vif.clear();
        post_rbcam_vif.clear();
        feb_egress_vif.clear();
        lvds_phy_vif.clear();
        runctl_phy_vif.clear();
        sc_phy_vif.clear_master();
        sc_phy_vif.waitrequest   = 1'b0;
        repeat (6) @(posedge clk_125);
        rst = 1'b0;
    end

    always_ff @(posedge clk_125) begin
        if (rst) begin
            sc_phy_vif.readdatavalid <= 1'b0;

            sc_phy_vif.readdata      <= 32'h0000_0000;
        end else begin
            sc_phy_vif.readdatavalid <= sc_phy_vif.read;

            sc_phy_vif.readdata      <= 32'h4849_5354;
        end
    end

    initial begin
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
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null,
                                                         "uvm_test_top.env.l2_commit_mon",
                                                         "vif",
                                                         stage_a_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.pre_rbcam_mon",
                                                "vif",
                                                pre_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.post_rbcam_mon",
                                                "vif",
                                                post_rbcam_vif);
        uvm_config_db#(virtual hit_tap_if)::set(null,
                                                "uvm_test_top.env.feb_egress_mon",
                                                "vif",
                                                feb_egress_vif);
        uvm_config_db#(virtual mutrig_l2_commit_if)::set(null,
                                                         "uvm_test_top",
                                                         "stage_a_vif",
                                                         stage_a_vif);
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
                                                "feb_egress_vif",
                                                feb_egress_vif);
        run_test();
    end
`endif
endmodule
