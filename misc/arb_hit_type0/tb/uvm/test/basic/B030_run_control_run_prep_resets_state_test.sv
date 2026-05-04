import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B030_run_control_run_prep_resets_state_seq_pkg::*;
`include "uvm_macros.svh"

class B030_run_control_run_prep_resets_state_test extends B000_basic_base_test;
  `uvm_component_utils(B030_run_control_run_prep_resets_state_test)

  function new(string name = "B030_run_control_run_prep_resets_state_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B030_run_control_run_prep_resets_state_seq seq_h;

    seq_h = B030_run_control_run_prep_resets_state_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
