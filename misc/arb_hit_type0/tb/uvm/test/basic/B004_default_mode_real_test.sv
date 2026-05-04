import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B004_default_mode_real_seq_pkg::*;
`include "uvm_macros.svh"

class B004_default_mode_real_test extends B000_basic_base_test;
  `uvm_component_utils(B004_default_mode_real_test)

  function new(string name = "B004_default_mode_real_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B004_default_mode_real_seq seq_h;

    seq_h = B004_default_mode_real_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
