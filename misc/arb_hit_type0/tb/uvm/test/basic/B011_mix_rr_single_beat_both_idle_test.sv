import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B011_mix_rr_single_beat_both_idle_seq_pkg::*;
`include "uvm_macros.svh"

class B011_mix_rr_single_beat_both_idle_test extends B000_basic_base_test;
  `uvm_component_utils(B011_mix_rr_single_beat_both_idle_test)

  function new(string name = "B011_mix_rr_single_beat_both_idle_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B011_mix_rr_single_beat_both_idle_seq seq_h;

    seq_h = B011_mix_rr_single_beat_both_idle_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
