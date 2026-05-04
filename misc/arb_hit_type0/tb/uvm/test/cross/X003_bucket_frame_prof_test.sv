import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X003_bucket_frame_prof_test extends X000_cross_base_test;
  `uvm_component_utils(X003_bucket_frame_prof_test)

  function new(string name = "X003_bucket_frame_prof_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    X003_bucket_frame_prof_seq seq;

    seq = X003_bucket_frame_prof_seq::type_id::create("seq");
    run_cross_sequence(phase, seq);
  endtask
endclass
