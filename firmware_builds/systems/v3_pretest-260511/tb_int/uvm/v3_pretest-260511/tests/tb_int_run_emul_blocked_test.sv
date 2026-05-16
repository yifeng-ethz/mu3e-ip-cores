// tb_int_run_emul_blocked_test.sv
// FEB run-control/emulator path regression. The legacy PRE-FIX test name is
// retained for Makefile compatibility; the active tb_int shell no longer uses
// the old behavioural splitter shortcut and therefore expects the generated
// run-control path to pass hits.
//
// Author : Claude Opus
// Date   : 20260511
// Scope  : Drives real runctl_mgmt_host synclink commands plus emulator hits
//          against the generated FEB run-control splitter path. The stale
//          pre-fix blocked expectation was removed because it hid a shortcut
//          model rather than verifying the current FEB topology.

package tb_int_run_emul_blocked_test_pkg;

    import uvm_pkg::*;
    import tb_int_base_test_pkg::*;
    import tb_int_run_emulator_directed_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_run_emul_blocked_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_run_emul_blocked_test)

        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        int unsigned hit_count = 16;

        function new(string name = "tb_int_run_emul_blocked_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            int unsigned plusarg_hits;

            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_phy_if)::get(this, "", "runctl_phy_vif", rc_vif))
                `uvm_fatal("RC_EMUL_BLK", "runctl_phy_vif not configured")
            if (!uvm_config_db#(virtual sc_avmm_if)::get(this, "", "sc_phy_vif", sc_vif))
                `uvm_fatal("RC_EMUL_BLK", "sc_phy_vif not configured")
            if ($value$plusargs("TB_INT_RC_EMUL_HIT_COUNT=%d", plusarg_hits))
                hit_count = plusarg_hits;
        endfunction

        virtual task run_phase(uvm_phase phase);
            run_emulator_directed seq;

            phase.raise_objection(this);
            wait (stage_a_vif.rst === 1'b0);
            repeat (8) @(posedge stage_a_vif.clk);
            seq = run_emulator_directed::type_id::create("run_emulator_directed_blocked_seq");
            seq.configure(rc_vif,
                          sc_vif,
                          stage_a_vif,
                          debug_l2_vif,
                          emulator_egress_vif,
                          debug_emulator_egress_vif,
                          pre_rbcam_vif,
                          post_rbcam_vif,
                          debug_pre_rbcam_vif,
                          debug_post_rbcam_vif,
                          debug_feb_egress_vif,
                          feb_egress_vif,
                          upload_data0_frame_vif,
                          upload_data1_frame_vif);
            seq.emul_check_mode = EMUL_MODE_EXPECT_FIXED;
            seq.body(hit_count);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
