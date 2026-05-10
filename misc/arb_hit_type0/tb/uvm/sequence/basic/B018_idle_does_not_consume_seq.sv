package B018_idle_does_not_consume_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B018_idle_does_not_consume_seq extends B000_basic_base_seq;
  `uvm_object_utils(B018_idle_does_not_consume_seq)

  function new(string name = "B018_idle_does_not_consume_seq");
    super.new(name);
  endfunction

  task body();
    case_B018_idle_does_not_consume();
  endtask
endclass
endpackage
