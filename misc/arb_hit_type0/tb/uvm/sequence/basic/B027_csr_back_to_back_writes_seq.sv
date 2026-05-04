package B027_csr_back_to_back_writes_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B027_csr_back_to_back_writes_seq extends B000_basic_base_seq;
  `uvm_object_utils(B027_csr_back_to_back_writes_seq)

  function new(string name = "B027_csr_back_to_back_writes_seq");
    super.new(name);
  endfunction

  task body();
    case_B027_csr_back_to_back_writes();
  endtask
endclass
endpackage
