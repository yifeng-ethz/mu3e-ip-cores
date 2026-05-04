`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R009_eor_without_sop_seq extends R_error_base_seq;
  `uvm_object_utils(R009_eor_without_sop_seq)

  function new(string name = "R009_eor_without_sop_seq");
    super.new(name);
  endfunction

  task body();
    bit [63:0] egress_hits_v;

    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST));
    wait_cycles(4);
    drive_hit(ARB_SRC_REAL, 45'h009_0000_0001, 3'b000, 4'h1, 1'b0, 1'b0, 1'b1);
    wait_cycles(10);
    drive_packet(ARB_SRC_REAL, 1, 45'h009_0000_0002, 3'b000, 4'h1);
    wait_cycles(10);
    csr_read_pair(ARB_REG_EGRESS_REAL_HITS_L_ADDR, egress_hits_v);
    expect64("egress real hits after eor lock", egress_hits_v, 64'd1);
  endtask
endclass
