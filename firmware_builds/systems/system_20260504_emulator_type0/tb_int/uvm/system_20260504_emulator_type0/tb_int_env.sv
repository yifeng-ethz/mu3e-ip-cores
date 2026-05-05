// tb_int_env.sv
// Focus-build integration UVM environment.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Instantiate reusable agents, monitors, and per-bucket scoreboard.

package tb_int_env_pkg;

    import uvm_pkg::*;
    import tb_int_mutrig_phy_agent_pkg::*;
    import tb_int_runctl_phy_agent_pkg::*;
    import tb_int_sc_phy_agent_pkg::*;
    import tb_int_l2_fifo_commit_monitor_pkg::*;
    import tb_int_lvds_decoded_monitor_pkg::*;
    import tb_int_rbcam_egress_monitor_pkg::*;
    import tb_int_feb_egress_monitor_pkg::*;
    import tb_int_histogram_csr_monitor_pkg::*;
    import tb_int_scoreboard_pkg::*;
    `include "uvm_macros.svh"

    localparam int TB_INT_STAGE_A_TAPS = 8;
    localparam int TB_INT_RBCAM_TAPS = 4;

    class tb_int_env extends uvm_env;
        `uvm_component_utils(tb_int_env)

        mutrig_phy_agent              mutrig_phy;
        runctl_phy_agent              runctl_phy;
        sc_phy_agent                  sc_phy;
        l2_fifo_commit_monitor        l2_commit_mon[TB_INT_STAGE_A_TAPS];
        lvds_decoded_monitor          pre_rbcam_mon[TB_INT_RBCAM_TAPS];
        rbcam_egress_monitor          post_rbcam_mon[TB_INT_RBCAM_TAPS];
        feb_egress_monitor            feb_egress_mon;
        histogram_csr_monitor         histogram_mon;
        per_bucket_ledger_scoreboard  scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mutrig_phy     = mutrig_phy_agent::type_id::create("mutrig_phy", this);
            runctl_phy     = runctl_phy_agent::type_id::create("runctl_phy", this);
            sc_phy         = sc_phy_agent::type_id::create("sc_phy", this);
            foreach (l2_commit_mon[tap_idx])
                l2_commit_mon[tap_idx] = l2_fifo_commit_monitor::type_id::create(
                    $sformatf("l2_commit_mon%0d", tap_idx), this);
            foreach (pre_rbcam_mon[tap_idx])
                pre_rbcam_mon[tap_idx] = lvds_decoded_monitor::type_id::create(
                    $sformatf("pre_rbcam_mon%0d", tap_idx), this);
            foreach (post_rbcam_mon[tap_idx])
                post_rbcam_mon[tap_idx] = rbcam_egress_monitor::type_id::create(
                    $sformatf("post_rbcam_mon%0d", tap_idx), this);
            feb_egress_mon = feb_egress_monitor::type_id::create("feb_egress_mon", this);
            histogram_mon  = histogram_csr_monitor::type_id::create("histogram_mon", this);
            scoreboard     = per_bucket_ledger_scoreboard::type_id::create("scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            foreach (l2_commit_mon[tap_idx])
                l2_commit_mon[tap_idx].ap.connect(scoreboard.stage_a_imp);
            foreach (pre_rbcam_mon[tap_idx])
                pre_rbcam_mon[tap_idx].ap.connect(scoreboard.pre_rbcam_imp);
            foreach (post_rbcam_mon[tap_idx])
                post_rbcam_mon[tap_idx].ap.connect(scoreboard.post_rbcam_imp);
            feb_egress_mon.ap.connect(scoreboard.feb_egress_imp);
            histogram_mon.ap.connect(scoreboard.histogram_imp);
        endfunction
    endclass

endpackage
