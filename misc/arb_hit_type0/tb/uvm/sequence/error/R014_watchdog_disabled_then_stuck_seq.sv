`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R014_watchdog_disabled_then_stuck_seq extends R_error_base_seq;
  `uvm_object_utils(R014_watchdog_disabled_then_stuck_seq)

  function new(string name = "R014_watchdog_disabled_then_stuck_seq");
    super.new(name);
  endfunction

  task body();
    csr_write(ARB_REG_WATCHDOG_ADDR, 32'd0);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(4);
    drive_hit(ARB_SRC_REAL, 45'h014_0000_0001, 3'b000, 4'h3, 1'b1, 1'b0, 1'b0);
    wait_cycles(2);
    drive_hit(ARB_SRC_EMU, 45'h014_0000_1001, 3'b000, 4'h8, 1'b1, 1'b1, 1'b1);
    wait_cycles(30);
    expect_status_mask(32'h0001_0030, 32'h0000_0030);
    send_runctl(runctl_seq_item::RUN_RESETTING_WORD_CONST);
    wait_cycles(12);
    expect_status_mask(32'h0000_0030, 32'h0000_0000);
  endtask
endclass
