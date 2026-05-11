// tb_int_run_sequence_directed_wedge_test.sv
// SWB BUG-RC-RESET-SCWEDGE behavioural topology repro test (PRE-FIX).
//
// Author : Claude Opus
// Date   : 20260511
// Scope  : Phase 3 BUG-RC-RESET-SCWEDGE repro. Drives the 11-opcode run-
//          control sweep against the behavioural topology model in
//          tb_int_top.sv. With BUG_RC_RESET_SCWEDGE_FIXED UNDEFINED the
//          mock_sc_plane_reset cascade is active and the post-CMD_RESET
//          (0x30) SC STATUS read returns 0xEEEE_EEEE (RSP3 payload).
//          The test PASSes when the wedge signature is observed (the bug
//          is "verified live" in behavioural sim).

package tb_int_run_sequence_directed_wedge_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_run_sequence_directed_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_run_sequence_directed_wedge_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_run_sequence_directed_wedge_test)

        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        function new(string name = "tb_int_run_sequence_directed_wedge_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_phy_if)::get(this, "", "runctl_phy_vif", rc_vif))
                `uvm_fatal("RC_WEDGE", "runctl_phy_vif not configured")
            if (!uvm_config_db#(virtual sc_avmm_if)::get(this, "", "sc_phy_vif", sc_vif))
                `uvm_fatal("RC_WEDGE", "sc_phy_vif not configured")
        endfunction

        virtual task run_phase(uvm_phase phase);
            run_sequence_directed seq;

            phase.raise_objection(this);
            wait (rdma_rqe_vif.reset_n === 1'b1);
            repeat (8) @(posedge rdma_rqe_vif.clk);
            seq = run_sequence_directed::type_id::create("run_sequence_directed_wedge_seq");
            seq.configure(rc_vif, sc_vif);
            seq.wedge_check_mode = WEDGE_MODE_EXPECT_WEDGE;
            seq.body();
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
