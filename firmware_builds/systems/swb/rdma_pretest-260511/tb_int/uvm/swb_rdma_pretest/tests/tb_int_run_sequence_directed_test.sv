// tb_int_run_sequence_directed_test.sv
// Directed run-control opcode sweep test for SWB rdma_pretest-260511 tb_int.
//
// Author: codex / Claude Opus
// Date  : 20260511
// Scope : Phase 3 GOOD-sequence directed coverage (10 PASS opcodes) plus the
//         eleventh CMD_RESET step that exercises the BUG-RC-RESET-SCWEDGE
//         expectation. See run_sequence_directed.sv for the per-step
//         encoding and SC-WEDGE behavioural-stub note.

package tb_int_run_sequence_directed_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_run_sequence_directed_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_run_sequence_directed_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_run_sequence_directed_test)

        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        function new(string name = "tb_int_run_sequence_directed_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_phy_if)::get(this, "", "runctl_phy_vif", rc_vif))
                `uvm_fatal("RC_DIR", "runctl_phy_vif not configured")
            if (!uvm_config_db#(virtual sc_avmm_if)::get(this, "", "sc_phy_vif", sc_vif))
                `uvm_fatal("RC_DIR", "sc_phy_vif not configured")
        endfunction

        virtual task run_phase(uvm_phase phase);
            run_sequence_directed seq;

            phase.raise_objection(this);
            wait (rdma_rqe_vif.reset_n === 1'b1);
            repeat (8) @(posedge rdma_rqe_vif.clk);
            seq = run_sequence_directed::type_id::create("run_sequence_directed_seq");
            seq.configure(rc_vif, sc_vif);
            seq.body();
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
