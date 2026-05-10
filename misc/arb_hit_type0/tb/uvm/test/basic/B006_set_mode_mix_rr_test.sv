import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B006_set_mode_mix_rr_seq_pkg::*;
`include "uvm_macros.svh"

class B006_set_mode_mix_rr_test extends B000_basic_base_test;
  `uvm_component_utils(B006_set_mode_mix_rr_test)

  function new(string name = "B006_set_mode_mix_rr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B006_set_mode_mix_rr_seq seq_h;

    seq_h = B006_set_mode_mix_rr_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
