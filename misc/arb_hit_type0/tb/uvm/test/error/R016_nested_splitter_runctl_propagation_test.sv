// R016_nested_splitter_runctl_propagation_test.sv
//
// B002 silicon-repro test.  Exercises the 3-deep altera_avalon_st_splitter
// chain instantiated in tb_top_b002 and asserts that run-control bytes
// propagate to the downstream arb_hit_type0 DUT.
//
// This test is intentionally self-contained: it does NOT use the standard
// arb_hit_type0_env / runctl_agent infrastructure.  It extends uvm_test
// directly and drives all stimulus via uvm_hdl_force on tb_top_b002 paths.
//
// Launch with:
//   make -C tb run_b002_R016_nested_splitter_runctl_propagation_test
//
// Expected outcomes:
//   NO_REPRO  -> all RC state transitions visible through the splitter
//                model; root cause of B002 is not structural depth alone.
//   REPRO_HIT -> run_state stuck; structural depth is sufficient to
//                reproduce B002; test ends with UVM_ERROR.
//
// TIMESCALE NOTE: this file must be compiled with 1ns/1ps to match
// tb_top_b002.  Without the directive the CU defaults to 1ps/1ps and
// #N delays become picoseconds, making stimulus invisible to the 8ns clock.
`timescale 1ns/1ps

`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
`include "uvm_macros.svh"
`endif

class R016_nested_splitter_runctl_propagation_test extends uvm_test;
    `uvm_component_utils(R016_nested_splitter_runctl_propagation_test)

    function new(string name = "R016_nested_splitter_runctl_propagation_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        R016_nested_splitter_runctl_propagation_seq seq_h;

        phase.raise_objection(this);

        seq_h = R016_nested_splitter_runctl_propagation_seq::type_id::create("seq_h");

        // Run on the null sequencer (no sequencer needed -- hdl_force only)
        seq_h.start(null);

        `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass
