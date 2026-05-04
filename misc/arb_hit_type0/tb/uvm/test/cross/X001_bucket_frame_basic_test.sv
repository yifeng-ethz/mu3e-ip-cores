import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X001_bucket_frame_basic_test extends X000_cross_base_test;
  `uvm_component_utils(X001_bucket_frame_basic_test)

  function new(string name = "X001_bucket_frame_basic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    X001_bucket_frame_basic_seq seq;

    seq = X001_bucket_frame_basic_seq::type_id::create("seq");
    run_cross_sequence(phase, seq);
  endtask
endclass
