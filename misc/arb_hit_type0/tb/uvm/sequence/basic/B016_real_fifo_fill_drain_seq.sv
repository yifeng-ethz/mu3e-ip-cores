package B016_real_fifo_fill_drain_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B016_real_fifo_fill_drain_seq extends B000_basic_base_seq;
  `uvm_object_utils(B016_real_fifo_fill_drain_seq)

  function new(string name = "B016_real_fifo_fill_drain_seq");
    super.new(name);
  endfunction

  task body();
    case_B016_real_fifo_fill_drain();
  endtask
endclass
endpackage
