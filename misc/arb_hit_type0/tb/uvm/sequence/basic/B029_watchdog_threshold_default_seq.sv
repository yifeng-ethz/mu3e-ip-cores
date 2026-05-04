package B029_watchdog_threshold_default_seq_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_pkg::*;
  import arb_hit_type0_basic_pkg::*;
  `include "uvm_macros.svh"

class B029_watchdog_threshold_default_seq extends B000_basic_base_seq;
  `uvm_object_utils(B029_watchdog_threshold_default_seq)

  function new(string name = "B029_watchdog_threshold_default_seq");
    super.new(name);
  endfunction

  task body();
    case_B029_watchdog_threshold_default();
  endtask
endclass
endpackage
