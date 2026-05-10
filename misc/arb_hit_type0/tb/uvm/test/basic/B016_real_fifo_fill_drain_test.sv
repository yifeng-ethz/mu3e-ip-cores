import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B016_real_fifo_fill_drain_seq_pkg::*;
`include "uvm_macros.svh"

class B016_real_fifo_fill_drain_test extends B000_basic_base_test;
  `uvm_component_utils(B016_real_fifo_fill_drain_test)

  function new(string name = "B016_real_fifo_fill_drain_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B016_real_fifo_fill_drain_seq seq_h;

    seq_h = B016_real_fifo_fill_drain_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
