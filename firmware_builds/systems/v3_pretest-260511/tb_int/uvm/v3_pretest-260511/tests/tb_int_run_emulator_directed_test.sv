// tb_int_run_emulator_directed_test.sv
// Directed run-control to emulator_mutrig hit-flow test for v3_pretest-260511.
//
// Author: codex / Claude Opus
// Date  : 20260511
// Scope : Phase 3 BUG-RC-RUN-EMUL repro (run_control_splitter dangling-ready
//         pattern). See run_emulator_directed.sv for the per-step encoding
//         and the silicon-vs-stub signature note.

package tb_int_run_emulator_directed_test_pkg;

    import uvm_pkg::*;
    import tb_int_base_test_pkg::*;
    import tb_int_run_emulator_directed_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_run_emulator_directed_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_run_emulator_directed_test)

        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        // Default emulator hit burst length. Overridable via
        // +TB_INT_RC_EMUL_HIT_COUNT plusarg.
        int unsigned hit_count = 16;

        function new(string name = "tb_int_run_emulator_directed_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            int unsigned plusarg_hits;

            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_phy_if)::get(this, "", "runctl_phy_vif", rc_vif))
                `uvm_fatal("RC_EMU", "runctl_phy_vif not configured")
            if (!uvm_config_db#(virtual sc_avmm_if)::get(this, "", "sc_phy_vif", sc_vif))
                `uvm_fatal("RC_EMU", "sc_phy_vif not configured")
            if ($value$plusargs("TB_INT_RC_EMUL_HIT_COUNT=%d", plusarg_hits))
                hit_count = plusarg_hits;
        endfunction

        virtual task run_phase(uvm_phase phase);
            run_emulator_directed seq;

            phase.raise_objection(this);
            wait (stage_a_vif.rst === 1'b0);
            repeat (8) @(posedge stage_a_vif.clk);
            seq = run_emulator_directed::type_id::create("run_emulator_directed_seq");
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
            seq.body(hit_count);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
