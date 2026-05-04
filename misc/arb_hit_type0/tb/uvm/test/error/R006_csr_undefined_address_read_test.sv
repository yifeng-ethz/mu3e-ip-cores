`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R006_csr_undefined_address_read_test extends R_error_base_test;
  `uvm_component_utils(R006_csr_undefined_address_read_test)

  function new(string name = "R006_csr_undefined_address_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    R006_csr_undefined_address_read_seq seq_h;

    seq_h = R006_csr_undefined_address_read_seq::type_id::create("seq_h");
    run_case_sequence(phase, seq_h);
  endtask
endclass
