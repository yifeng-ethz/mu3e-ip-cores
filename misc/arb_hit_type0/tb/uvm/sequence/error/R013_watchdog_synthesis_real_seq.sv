`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R013_watchdog_synthesis_real_seq extends R_error_base_seq;
  `uvm_object_utils(R013_watchdog_synthesis_real_seq)

  function new(string name = "R013_watchdog_synthesis_real_seq");
    super.new(name);
  endfunction

  task body();
    bit [63:0] real_hits_v;

    csr_write(ARB_REG_WATCHDOG_ADDR, 32'd20);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(4);
    drive_hit(ARB_SRC_REAL, 45'h013_0000_0001, 3'b000, 4'h3, 1'b1, 1'b0, 1'b0);
    wait_cycles(2);
    drive_hit(ARB_SRC_EMU, 45'h013_0000_1001, 3'b000, 4'h8, 1'b1, 1'b1, 1'b1);
    wait_cycles(8);
    predict_watchdog_real(4'h3);
    wait_cycles(40);
    expect_status_mask(32'h0001_0030, 32'h0001_0000);
    csr_read_pair(ARB_REG_EGRESS_REAL_HITS_L_ADDR, real_hits_v);
    expect64("watchdog synthesized beat excluded from real hit count", real_hits_v, 64'd1);
  endtask
endclass
