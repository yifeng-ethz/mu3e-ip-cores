import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B012_switch_at_idle_seq_pkg::*;
`include "uvm_macros.svh"

class B012_switch_at_idle_test extends B000_basic_base_test;
  `uvm_component_utils(B012_switch_at_idle_test)

  function new(string name = "B012_switch_at_idle_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B012_switch_at_idle_seq seq_h;

    seq_h = B012_switch_at_idle_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
