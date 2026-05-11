// tb_int_run_emul_blocked_test.sv
// FEB BUG-RC-RUN-EMUL behavioural topology repro test (PRE-FIX).
//
// Author : Claude Opus
// Date   : 20260511
// Scope  : Phase 3 BUG-RC-RUN-EMUL repro. Drives start-run (0x12) + 16
//          emulator hits against the behavioural topology model in
//          tb_int_top.sv. With BUG_RC_RUN_EMUL_FIXED UNDEFINED the
//          mock_run_control_splitter's outN_ready inputs are dangling
//          (resolve as logic 0 by AND default), so the RUNNING broadcast
//          to emulator_mutrig is blocked. mock_total_hits_cnt stays 0 and
//          the SC AVMM read at CSR_HISTO_TOTAL_HITS returns 0. The test
//          PASSes when the blocked signature (TOTAL_HITS == 0) is
//          observed (the bug is "verified live" in behavioural sim).

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
                          pre_rbcam_vif,
                          post_rbcam_vif,
                          debug_pre_rbcam_vif,
                          debug_post_rbcam_vif,
                          debug_feb_egress_vif,
                          feb_egress_vif);
            seq.emul_check_mode = EMUL_MODE_EXPECT_BLOCKED;
            seq.body(hit_count);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
