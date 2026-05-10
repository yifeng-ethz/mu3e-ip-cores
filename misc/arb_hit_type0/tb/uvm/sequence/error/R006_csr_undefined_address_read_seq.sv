`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R006_csr_undefined_address_read_seq extends R_error_base_seq;
  `uvm_object_utils(R006_csr_undefined_address_read_seq)

  function new(string name = "R006_csr_undefined_address_read_seq");
    super.new(name);
  endfunction

  task body();
    expect_csr32(5'h1E, 32'd0, "reserved CSR 0x1E");
    expect_csr32(5'h1F, 32'd0, "reserved CSR 0x1F");
  endtask
endclass
