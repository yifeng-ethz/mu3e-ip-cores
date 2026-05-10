package B004_default_mode_real_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B004_default_mode_real_seq extends B000_basic_base_seq;
  `uvm_object_utils(B004_default_mode_real_seq)

  function new(string name = "B004_default_mode_real_seq");
    super.new(name);
  endfunction

  task body();
    case_B004_default_mode_real();
  endtask
endclass
endpackage
