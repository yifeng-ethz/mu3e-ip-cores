package B025_low_high_pair_atomicity_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B025_low_high_pair_atomicity_seq extends B000_basic_base_seq;
  `uvm_object_utils(B025_low_high_pair_atomicity_seq)

  function new(string name = "B025_low_high_pair_atomicity_seq");
    super.new(name);
  endfunction

  task body();
    case_B025_low_high_pair_atomicity();
  endtask
endclass
endpackage
