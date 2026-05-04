package B014_switch_back_to_back_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B014_switch_back_to_back_seq extends B000_basic_base_seq;
  `uvm_object_utils(B014_switch_back_to_back_seq)

  function new(string name = "B014_switch_back_to_back_seq");
    super.new(name);
  endfunction

  task body();
    case_B014_switch_back_to_back();
  endtask
endclass
endpackage
