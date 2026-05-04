package B013_switch_during_packet_defers_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B013_switch_during_packet_defers_seq extends B000_basic_base_seq;
  `uvm_object_utils(B013_switch_during_packet_defers_seq)

  function new(string name = "B013_switch_during_packet_defers_seq");
    super.new(name);
  endfunction

  task body();
    case_B013_switch_during_packet_defers();
  endtask
endclass
endpackage
