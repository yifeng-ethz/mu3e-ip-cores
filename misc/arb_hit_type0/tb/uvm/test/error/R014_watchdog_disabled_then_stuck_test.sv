`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R014_watchdog_disabled_then_stuck_test extends R_error_base_test;
  `uvm_component_utils(R014_watchdog_disabled_then_stuck_test)

  function new(string name = "R014_watchdog_disabled_then_stuck_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    R014_watchdog_disabled_then_stuck_seq seq_h;

    seq_h = R014_watchdog_disabled_then_stuck_seq::type_id::create("seq_h");
    run_case_sequence(phase, seq_h);
  endtask
endclass
