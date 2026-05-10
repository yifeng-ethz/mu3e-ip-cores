`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R005_clear_sticky_w1p_test extends R_error_base_test;
  `uvm_component_utils(R005_clear_sticky_w1p_test)

  function new(string name = "R005_clear_sticky_w1p_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    R005_clear_sticky_w1p_seq seq_h;

    seq_h = R005_clear_sticky_w1p_seq::type_id::create("seq_h");
    run_case_sequence(phase, seq_h);
  endtask
endclass
