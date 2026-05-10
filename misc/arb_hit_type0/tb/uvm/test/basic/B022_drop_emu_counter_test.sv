import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B022_drop_emu_counter_seq_pkg::*;
`include "uvm_macros.svh"

class B022_drop_emu_counter_test extends B000_basic_base_test;
  `uvm_component_utils(B022_drop_emu_counter_test)

  function new(string name = "B022_drop_emu_counter_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B022_drop_emu_counter_seq seq_h;

    seq_h = B022_drop_emu_counter_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
