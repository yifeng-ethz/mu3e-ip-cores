`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R013_watchdog_synthesis_real_test extends R_error_base_test;
  `uvm_component_utils(R013_watchdog_synthesis_real_test)

  function new(string name = "R013_watchdog_synthesis_real_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    R013_watchdog_synthesis_real_seq seq_h;

    seq_h = R013_watchdog_synthesis_real_seq::type_id::create("seq_h");
    run_case_sequence(phase, seq_h);
  endtask
endclass
