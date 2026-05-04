import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B018_idle_does_not_consume_seq_pkg::*;
`include "uvm_macros.svh"

class B018_idle_does_not_consume_test extends B000_basic_base_test;
  `uvm_component_utils(B018_idle_does_not_consume_test)

  function new(string name = "B018_idle_does_not_consume_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B018_idle_does_not_consume_seq seq_h;

    seq_h = B018_idle_does_not_consume_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
