`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R004_illegal_mode_encoding_seq extends R_error_base_seq;
  `uvm_object_utils(R004_illegal_mode_encoding_seq)

  function new(string name = "R004_illegal_mode_encoding_seq");
    super.new(name);
  endfunction

  task body();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_RESERVED_CONST));
    wait_cycles(4);
    expect_status_mask(32'h0000_200F, 32'h0000_2000);
  endtask
endclass
