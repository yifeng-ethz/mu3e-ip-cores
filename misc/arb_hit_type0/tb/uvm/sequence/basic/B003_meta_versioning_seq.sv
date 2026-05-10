package B003_meta_versioning_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B003_meta_versioning_seq extends B000_basic_base_seq;
  `uvm_object_utils(B003_meta_versioning_seq)

  function new(string name = "B003_meta_versioning_seq");
    super.new(name);
  endfunction

  task body();
    case_B003_meta_versioning();
  endtask
endclass
endpackage
