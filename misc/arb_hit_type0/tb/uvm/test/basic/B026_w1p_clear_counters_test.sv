import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B026_w1p_clear_counters_seq_pkg::*;
`include "uvm_macros.svh"

class B026_w1p_clear_counters_test extends B000_basic_base_test;
  `uvm_component_utils(B026_w1p_clear_counters_test)

  function new(string name = "B026_w1p_clear_counters_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B026_w1p_clear_counters_seq seq_h;

    seq_h = B026_w1p_clear_counters_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
