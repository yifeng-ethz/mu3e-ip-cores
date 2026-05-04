package B005_set_mode_emu_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B005_set_mode_emu_seq extends B000_basic_base_seq;
  `uvm_object_utils(B005_set_mode_emu_seq)

  function new(string name = "B005_set_mode_emu_seq");
    super.new(name);
  endfunction

  task body();
    case_B005_set_mode_emu();
  endtask
endclass
endpackage
