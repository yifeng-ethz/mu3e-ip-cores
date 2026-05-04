package B002_uid_write_ignored_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B002_uid_write_ignored_seq extends B000_basic_base_seq;
  `uvm_object_utils(B002_uid_write_ignored_seq)

  function new(string name = "B002_uid_write_ignored_seq");
    super.new(name);
  endfunction

  task body();
    case_B002_uid_write_ignored();
  endtask
endclass
endpackage
