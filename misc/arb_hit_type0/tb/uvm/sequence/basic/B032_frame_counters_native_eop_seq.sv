package B032_frame_counters_native_eop_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B032_frame_counters_native_eop_seq extends B000_basic_base_seq;
  `uvm_object_utils(B032_frame_counters_native_eop_seq)

  function new(string name = "B032_frame_counters_native_eop_seq");
    super.new(name);
  endfunction

  task body();
    case_B032_frame_counters_native_eop();
  endtask
endclass
endpackage
