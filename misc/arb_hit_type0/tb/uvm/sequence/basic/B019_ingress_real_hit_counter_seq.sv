package B019_ingress_real_hit_counter_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B019_ingress_real_hit_counter_seq extends B000_basic_base_seq;
  `uvm_object_utils(B019_ingress_real_hit_counter_seq)

  function new(string name = "B019_ingress_real_hit_counter_seq");
    super.new(name);
  endfunction

  task body();
    case_B019_ingress_real_hit_counter();
  endtask
endclass
endpackage
