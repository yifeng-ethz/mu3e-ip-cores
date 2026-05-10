import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X005_all_buckets_frame_test extends X000_cross_base_test;
  `uvm_component_utils(X005_all_buckets_frame_test)

  function new(string name = "X005_all_buckets_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    X005_all_buckets_frame_seq seq;

    seq = X005_all_buckets_frame_seq::type_id::create("seq");
    run_cross_sequence(phase, seq);
  endtask
endclass
