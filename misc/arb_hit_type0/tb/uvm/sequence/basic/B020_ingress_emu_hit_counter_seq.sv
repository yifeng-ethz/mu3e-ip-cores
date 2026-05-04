package B020_ingress_emu_hit_counter_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B020_ingress_emu_hit_counter_seq extends B000_basic_base_seq;
  `uvm_object_utils(B020_ingress_emu_hit_counter_seq)

  function new(string name = "B020_ingress_emu_hit_counter_seq");
    super.new(name);
  endfunction

  task body();
    case_B020_ingress_emu_hit_counter();
  endtask
endclass
endpackage
