package B031_run_control_reset_clears_counters_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B031_run_control_reset_clears_counters_seq extends B000_basic_base_seq;
  `uvm_object_utils(B031_run_control_reset_clears_counters_seq)

  function new(string name = "B031_run_control_reset_clears_counters_seq");
    super.new(name);
  endfunction

  task body();
    case_B031_run_control_reset_clears_counters();
  endtask
endclass
endpackage
