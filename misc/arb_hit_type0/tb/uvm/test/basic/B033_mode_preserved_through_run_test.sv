import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B033_mode_preserved_through_run_seq_pkg::*;
`include "uvm_macros.svh"

class B033_mode_preserved_through_run_test extends B000_basic_base_test;
  `uvm_component_utils(B033_mode_preserved_through_run_test)

  function new(string name = "B033_mode_preserved_through_run_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B033_mode_preserved_through_run_seq seq_h;

    seq_h = B033_mode_preserved_through_run_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
