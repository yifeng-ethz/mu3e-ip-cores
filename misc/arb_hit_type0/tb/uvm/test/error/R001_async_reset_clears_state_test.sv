`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R_error_base_test extends arb_hit_type0_base_test;
  `uvm_component_utils(R_error_base_test)

  function new(string name = "R_error_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task automatic run_case_sequence(uvm_phase phase, uvm_sequence_base seq_h);
    phase.raise_objection(this);
    wait_reset_release();
    seq_h.start(env.vseqr);
    repeat (20) @(cfg.reset_vif.mon_cb);
    `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass

class R001_async_reset_clears_state_test extends R_error_base_test;
  `uvm_component_utils(R001_async_reset_clears_state_test)

  function new(string name = "R001_async_reset_clears_state_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    R001_async_reset_clears_state_seq seq_h;

    seq_h = R001_async_reset_clears_state_seq::type_id::create("seq_h");
    run_case_sequence(phase, seq_h);
  endtask
endclass
