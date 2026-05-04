package B009_mix_rr_merged_packet_alternation_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B009_mix_rr_merged_packet_alternation_seq extends B000_basic_base_seq;
  `uvm_object_utils(B009_mix_rr_merged_packet_alternation_seq)

  function new(string name = "B009_mix_rr_merged_packet_alternation_seq");
    super.new(name);
  endfunction

  task body();
    case_B009_mix_rr_merged_packet_alternation();
  endtask
endclass
endpackage
