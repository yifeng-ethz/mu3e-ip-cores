// tb_int_dual_env.sv
// Dual nominal/debug UVM environment for v3_pretest-260511.

package tb_int_dual_env_pkg;

    import uvm_pkg::*;
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
    `include "uvm_macros.svh"

    localparam int TB_INT_STAGE_A_TAPS = 8;
    localparam int TB_INT_RBCAM_TAPS = 8;
    localparam int TB_INT_FEB_EGRESS_TAPS = 2;
    localparam int TB_INT_FEB_FRAME_TAPS = 2;
    localparam int TB_INT_FILL_TAPS = 8;

    class tb_int_nominal_env extends uvm_env;
        `uvm_component_utils(tb_int_nominal_env)

        mutrig_phy_agent       mutrig_phy;
        runctl_phy_agent       runctl_phy;
        sc_phy_agent           sc_phy;
        l2_fifo_commit_monitor l2_commit_mon[TB_INT_STAGE_A_TAPS];
        lvds_decoded_monitor   pre_rbcam_mon[TB_INT_RBCAM_TAPS];
        rbcam_egress_monitor   post_rbcam_mon[TB_INT_RBCAM_TAPS];
        feb_egress_monitor      feb_egress_mon[TB_INT_FEB_EGRESS_TAPS];
        feb_frame_monitor       feb_frame_mon[TB_INT_FEB_FRAME_TAPS];
        histogram_csr_monitor  histogram_mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mutrig_phy = mutrig_phy_agent::type_id::create("mutrig_phy", this);
            runctl_phy = runctl_phy_agent::type_id::create("runctl_phy", this);
            sc_phy = sc_phy_agent::type_id::create("sc_phy", this);
            foreach (l2_commit_mon[tap_idx])
                l2_commit_mon[tap_idx] = l2_fifo_commit_monitor::type_id::create(
                    $sformatf("l2_commit_mon%0d", tap_idx), this);
            foreach (pre_rbcam_mon[tap_idx])
                pre_rbcam_mon[tap_idx] = lvds_decoded_monitor::type_id::create(
                    $sformatf("pre_rbcam_mon%0d", tap_idx), this);
            foreach (post_rbcam_mon[tap_idx])
                post_rbcam_mon[tap_idx] = rbcam_egress_monitor::type_id::create(
                    $sformatf("post_rbcam_mon%0d", tap_idx), this);
            foreach (feb_egress_mon[tap_idx])
                feb_egress_mon[tap_idx] = feb_egress_monitor::type_id::create(
                    $sformatf("feb_egress_mon%0d", tap_idx), this);
            foreach (feb_frame_mon[tap_idx]) begin
                feb_frame_mon[tap_idx] = feb_frame_monitor::type_id::create(
                    $sformatf("feb_frame_mon%0d", tap_idx), this);
                uvm_config_db#(int unsigned)::set(this,
                                                  $sformatf("feb_frame_mon%0d", tap_idx),
                                                  "lane_id",
                                                  tap_idx);
                uvm_config_db#(string)::set(this,
                                            $sformatf("feb_frame_mon%0d", tap_idx),
                                            "stream_name",
                                            (tap_idx == 0) ? "feb_upload_data0_sc_rc" : "feb_upload_data1");
            end
            histogram_mon = histogram_csr_monitor::type_id::create("histogram_mon", this);
        endfunction
    endclass

    class tb_int_debug_env extends uvm_env;
        `uvm_component_utils(tb_int_debug_env)

        debug_l2_sidecar_monitor         debug_l2_mon[TB_INT_STAGE_A_TAPS];
        debug_pre_rbcam_sidecar_monitor  debug_pre_rbcam_mon[TB_INT_RBCAM_TAPS];
        debug_post_rbcam_sidecar_monitor debug_post_rbcam_mon[TB_INT_RBCAM_TAPS];
        debug_feb_egress_sidecar_monitor debug_feb_egress_mon[TB_INT_FEB_EGRESS_TAPS];
        debug_fill_monitor               fill_mon[TB_INT_FILL_TAPS];

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            foreach (debug_l2_mon[tap_idx])
                debug_l2_mon[tap_idx] = debug_l2_sidecar_monitor::type_id::create(
                    $sformatf("debug_l2_mon%0d", tap_idx), this);
            foreach (debug_pre_rbcam_mon[tap_idx])
                debug_pre_rbcam_mon[tap_idx] = debug_pre_rbcam_sidecar_monitor::type_id::create(
                    $sformatf("debug_pre_rbcam_mon%0d", tap_idx), this);
            foreach (debug_post_rbcam_mon[tap_idx])
                debug_post_rbcam_mon[tap_idx] = debug_post_rbcam_sidecar_monitor::type_id::create(
                    $sformatf("debug_post_rbcam_mon%0d", tap_idx), this);
            foreach (debug_feb_egress_mon[tap_idx])
                debug_feb_egress_mon[tap_idx] = debug_feb_egress_sidecar_monitor::type_id::create(
                    $sformatf("debug_feb_egress_mon%0d", tap_idx), this);
            foreach (fill_mon[tap_idx])
                fill_mon[tap_idx] = debug_fill_monitor::type_id::create(
                    $sformatf("fill_mon%0d", tap_idx), this);
        endfunction
    endclass

    class tb_int_dual_env extends uvm_env;
        `uvm_component_utils(tb_int_dual_env)

        tb_int_nominal_env           nominal;
        tb_int_debug_env             debug;
        tb_int_v3_ledger_scoreboard  scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            nominal = tb_int_nominal_env::type_id::create("nominal", this);
            debug = tb_int_debug_env::type_id::create("debug", this);
            scoreboard = tb_int_v3_ledger_scoreboard::type_id::create("scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            foreach (nominal.l2_commit_mon[tap_idx])
                nominal.l2_commit_mon[tap_idx].ap.connect(scoreboard.stage_a_imp);
            foreach (nominal.pre_rbcam_mon[tap_idx])
                nominal.pre_rbcam_mon[tap_idx].ap.connect(scoreboard.pre_rbcam_imp);
            foreach (nominal.post_rbcam_mon[tap_idx])
                nominal.post_rbcam_mon[tap_idx].ap.connect(scoreboard.post_rbcam_imp);
            foreach (nominal.feb_egress_mon[tap_idx])
                nominal.feb_egress_mon[tap_idx].ap.connect(scoreboard.feb_egress_imp);
            nominal.histogram_mon.ap.connect(scoreboard.histogram_imp);
            foreach (debug.debug_l2_mon[tap_idx])
                debug.debug_l2_mon[tap_idx].ap.connect(scoreboard.debug_l2_sidecar_imp);
            foreach (debug.debug_pre_rbcam_mon[tap_idx])
                debug.debug_pre_rbcam_mon[tap_idx].ap.connect(scoreboard.debug_pre_sidecar_imp);
            foreach (debug.debug_post_rbcam_mon[tap_idx])
                debug.debug_post_rbcam_mon[tap_idx].ap.connect(scoreboard.debug_post_sidecar_imp);
            foreach (debug.debug_feb_egress_mon[tap_idx])
                debug.debug_feb_egress_mon[tap_idx].ap.connect(scoreboard.debug_feb_sidecar_imp);
        endfunction
    endclass

endpackage
