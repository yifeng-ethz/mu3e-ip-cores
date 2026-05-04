import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B014_switch_back_to_back_seq_pkg::*;
`include "uvm_macros.svh"

class B014_switch_back_to_back_test extends B000_basic_base_test;
  `uvm_component_utils(B014_switch_back_to_back_test)

  function new(string name = "B014_switch_back_to_back_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B014_switch_back_to_back_seq seq_h;

    seq_h = B014_switch_back_to_back_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
