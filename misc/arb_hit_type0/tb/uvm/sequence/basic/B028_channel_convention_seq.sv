package B028_channel_convention_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B028_channel_convention_seq extends B000_basic_base_seq;
  `uvm_object_utils(B028_channel_convention_seq)

  function new(string name = "B028_channel_convention_seq");
    super.new(name);
  endfunction

  task body();
    case_B028_channel_convention();
  endtask
endclass
endpackage
