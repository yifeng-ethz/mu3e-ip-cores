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

    class tb_int_env extends uvm_env;
        `uvm_component_utils(tb_int_env)

        mutrig_phy_agent              mutrig_phy;
        runctl_phy_agent              runctl_phy;
        sc_phy_agent                  sc_phy;
        l2_fifo_commit_monitor        l2_commit_mon;
        lvds_decoded_monitor          pre_rbcam_mon;
        rbcam_egress_monitor          post_rbcam_mon;
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
            l2_commit_mon  = l2_fifo_commit_monitor::type_id::create("l2_commit_mon", this);
            pre_rbcam_mon  = lvds_decoded_monitor::type_id::create("pre_rbcam_mon", this);
            post_rbcam_mon = rbcam_egress_monitor::type_id::create("post_rbcam_mon", this);
            feb_egress_mon = feb_egress_monitor::type_id::create("feb_egress_mon", this);
            histogram_mon  = histogram_csr_monitor::type_id::create("histogram_mon", this);
            scoreboard     = per_bucket_ledger_scoreboard::type_id::create("scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            l2_commit_mon.ap.connect(scoreboard.stage_a_imp);
            pre_rbcam_mon.ap.connect(scoreboard.pre_rbcam_imp);
            post_rbcam_mon.ap.connect(scoreboard.post_rbcam_imp);
            feb_egress_mon.ap.connect(scoreboard.feb_egress_imp);
            histogram_mon.ap.connect(scoreboard.histogram_imp);
        endfunction
    endclass

endpackage
