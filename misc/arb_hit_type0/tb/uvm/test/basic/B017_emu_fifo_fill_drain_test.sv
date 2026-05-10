import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B017_emu_fifo_fill_drain_seq_pkg::*;
`include "uvm_macros.svh"

class B017_emu_fifo_fill_drain_test extends B000_basic_base_test;
  `uvm_component_utils(B017_emu_fifo_fill_drain_test)

  function new(string name = "B017_emu_fifo_fill_drain_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B017_emu_fifo_fill_drain_seq seq_h;

    seq_h = B017_emu_fifo_fill_drain_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
