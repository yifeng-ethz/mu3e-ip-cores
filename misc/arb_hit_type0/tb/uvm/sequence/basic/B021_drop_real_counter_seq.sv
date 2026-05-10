package B021_drop_real_counter_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B021_drop_real_counter_seq extends B000_basic_base_seq;
  `uvm_object_utils(B021_drop_real_counter_seq)

  function new(string name = "B021_drop_real_counter_seq");
    super.new(name);
  endfunction

  task body();
    case_B021_drop_real_counter();
  endtask
endclass
endpackage
