package B008_emu_only_drain_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B008_emu_only_drain_seq extends B000_basic_base_seq;
  `uvm_object_utils(B008_emu_only_drain_seq)

  function new(string name = "B008_emu_only_drain_seq");
    super.new(name);
  endfunction

  task body();
    case_B008_emu_only_drain();
  endtask
endclass
endpackage
