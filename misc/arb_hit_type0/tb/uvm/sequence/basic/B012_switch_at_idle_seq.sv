package B012_switch_at_idle_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B012_switch_at_idle_seq extends B000_basic_base_seq;
  `uvm_object_utils(B012_switch_at_idle_seq)

  function new(string name = "B012_switch_at_idle_seq");
    super.new(name);
  endfunction

  task body();
    case_B012_switch_at_idle();
  endtask
endclass
endpackage
