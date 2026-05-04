import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B032_frame_counters_native_eop_seq_pkg::*;
`include "uvm_macros.svh"

class B032_frame_counters_native_eop_test extends B000_basic_base_test;
  `uvm_component_utils(B032_frame_counters_native_eop_test)

  function new(string name = "B032_frame_counters_native_eop_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B032_frame_counters_native_eop_seq seq_h;

    seq_h = B032_frame_counters_native_eop_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
