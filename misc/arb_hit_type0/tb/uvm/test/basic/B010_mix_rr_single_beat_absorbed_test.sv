import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B010_mix_rr_single_beat_absorbed_seq_pkg::*;
`include "uvm_macros.svh"

class B010_mix_rr_single_beat_absorbed_test extends B000_basic_base_test;
  `uvm_component_utils(B010_mix_rr_single_beat_absorbed_test)

  function new(string name = "B010_mix_rr_single_beat_absorbed_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B010_mix_rr_single_beat_absorbed_seq seq_h;

    seq_h = B010_mix_rr_single_beat_absorbed_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
