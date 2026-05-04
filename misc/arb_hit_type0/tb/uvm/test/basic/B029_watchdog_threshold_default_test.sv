import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B029_watchdog_threshold_default_seq_pkg::*;
`include "uvm_macros.svh"

class B029_watchdog_threshold_default_test extends B000_basic_base_test;
  `uvm_component_utils(B029_watchdog_threshold_default_test)

  function new(string name = "B029_watchdog_threshold_default_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B029_watchdog_threshold_default_seq seq_h;

    seq_h = B029_watchdog_threshold_default_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
