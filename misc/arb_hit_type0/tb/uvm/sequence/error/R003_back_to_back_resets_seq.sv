`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R003_back_to_back_resets_seq extends R_error_base_seq;
  `uvm_object_utils(R003_back_to_back_resets_seq)

  function new(string name = "R003_back_to_back_resets_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status_a_v;
    bit [31:0] status_b_v;

    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_RESERVED_CONST));
    wait_cycles(4);
    pulse_hard_reset(2);
    csr_read(ARB_REG_STATUS_ADDR, status_a_v);
    pulse_hard_reset(2);
    pulse_hard_reset(3);
    csr_read(ARB_REG_STATUS_ADDR, status_b_v);
    expect32("back-to-back reset STATUS", status_b_v, status_a_v);
  endtask
endclass
