`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R012_run_control_reset_clears_error_state_test extends R_error_base_test;
  `uvm_component_utils(R012_run_control_reset_clears_error_state_test)

  function new(string name = "R012_run_control_reset_clears_error_state_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    R012_run_control_reset_clears_error_state_seq seq_h;

    seq_h = R012_run_control_reset_clears_error_state_seq::type_id::create("seq_h");
    run_case_sequence(phase, seq_h);
  endtask
endclass
