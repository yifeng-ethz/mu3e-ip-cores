import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X004_bucket_frame_error_test extends X000_cross_base_test;
  `uvm_component_utils(X004_bucket_frame_error_test)

  function new(string name = "X004_bucket_frame_error_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    X004_bucket_frame_error_seq seq;

    seq = X004_bucket_frame_error_seq::type_id::create("seq");
    run_cross_sequence(phase, seq);
  endtask
endclass
