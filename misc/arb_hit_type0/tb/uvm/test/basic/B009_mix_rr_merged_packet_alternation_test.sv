import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B009_mix_rr_merged_packet_alternation_seq_pkg::*;
`include "uvm_macros.svh"

class B009_mix_rr_merged_packet_alternation_test extends B000_basic_base_test;
  `uvm_component_utils(B009_mix_rr_merged_packet_alternation_test)

  function new(string name = "B009_mix_rr_merged_packet_alternation_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B009_mix_rr_merged_packet_alternation_seq seq_h;

    seq_h = B009_mix_rr_merged_packet_alternation_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
