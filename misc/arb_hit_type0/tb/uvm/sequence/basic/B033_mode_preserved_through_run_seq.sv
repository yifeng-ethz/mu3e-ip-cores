package B033_mode_preserved_through_run_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B033_mode_preserved_through_run_seq extends B000_basic_base_seq;
  `uvm_object_utils(B033_mode_preserved_through_run_seq)

  function new(string name = "B033_mode_preserved_through_run_seq");
    super.new(name);
  endfunction

  task body();
    case_B033_mode_preserved_through_run_seq();
  endtask
endclass
endpackage
