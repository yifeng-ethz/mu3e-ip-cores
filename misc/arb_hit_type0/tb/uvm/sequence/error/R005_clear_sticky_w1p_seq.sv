`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R005_clear_sticky_w1p_seq extends R_error_base_seq;
  `uvm_object_utils(R005_clear_sticky_w1p_seq)

  function new(string name = "R005_clear_sticky_w1p_seq");
    super.new(name);
  endfunction

  task body();
    drive_protocol_violation_real();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_RESERVED_CONST));
    wait_cycles(4);
    expect_status_mask(32'h0000_6000, 32'h0000_6000);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST, 1'b0, 1'b1));
    wait_cycles(4);
    expect_status_mask(32'h0003_F000, 32'h0000_0000);
  endtask
endclass
