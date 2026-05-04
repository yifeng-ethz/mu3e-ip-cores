package B030_run_control_run_prep_resets_state_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B030_run_control_run_prep_resets_state_seq extends B000_basic_base_seq;
  `uvm_object_utils(B030_run_control_run_prep_resets_state_seq)

  function new(string name = "B030_run_control_run_prep_resets_state_seq");
    super.new(name);
  endfunction

  task body();
    case_B030_run_control_run_prep_resets_state();
  endtask
endclass
endpackage
