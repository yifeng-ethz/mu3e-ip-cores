package B006_set_mode_mix_rr_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B006_set_mode_mix_rr_seq extends B000_basic_base_seq;
  `uvm_object_utils(B006_set_mode_mix_rr_seq)

  function new(string name = "B006_set_mode_mix_rr_seq");
    super.new(name);
  endfunction

  task body();
    case_B006_set_mode_mix_rr();
  endtask
endclass
endpackage
