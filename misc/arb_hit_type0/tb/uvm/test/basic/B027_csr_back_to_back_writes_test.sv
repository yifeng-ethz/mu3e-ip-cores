import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B027_csr_back_to_back_writes_seq_pkg::*;
`include "uvm_macros.svh"

class B027_csr_back_to_back_writes_test extends B000_basic_base_test;
  `uvm_component_utils(B027_csr_back_to_back_writes_test)

  function new(string name = "B027_csr_back_to_back_writes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B027_csr_back_to_back_writes_seq seq_h;

    seq_h = B027_csr_back_to_back_writes_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
