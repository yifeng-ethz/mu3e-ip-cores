package B001_uid_read_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B001_uid_read_seq extends B000_basic_base_seq;
  `uvm_object_utils(B001_uid_read_seq)

  function new(string name = "B001_uid_read_seq");
    super.new(name);
  endfunction

  task body();
    case_B001_uid_read();
  endtask
endclass
endpackage
