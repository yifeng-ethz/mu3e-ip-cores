package B010_mix_rr_single_beat_absorbed_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B010_mix_rr_single_beat_absorbed_seq extends B000_basic_base_seq;
  `uvm_object_utils(B010_mix_rr_single_beat_absorbed_seq)

  function new(string name = "B010_mix_rr_single_beat_absorbed_seq");
    super.new(name);
  endfunction

  task body();
    case_B010_mix_rr_single_beat_absorbed();
  endtask
endclass
endpackage
