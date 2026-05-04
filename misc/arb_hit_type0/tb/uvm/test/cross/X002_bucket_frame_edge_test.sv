import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X002_bucket_frame_edge_test extends X000_cross_base_test;
  `uvm_component_utils(X002_bucket_frame_edge_test)

  function new(string name = "X002_bucket_frame_edge_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    X002_bucket_frame_edge_seq seq;

    seq = X002_bucket_frame_edge_seq::type_id::create("seq");
    run_cross_sequence(phase, seq);
  endtask
endclass
