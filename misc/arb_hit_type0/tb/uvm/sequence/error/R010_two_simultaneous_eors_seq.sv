`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R010_two_simultaneous_eors_seq extends R_error_base_seq;
  `uvm_object_utils(R010_two_simultaneous_eors_seq)

  function new(string name = "R010_two_simultaneous_eors_seq");
    super.new(name);
  endfunction

  task body();
    bit [63:0] real_hits_v;
    bit [63:0] emu_hits_v;

    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(4);
    fork
      drive_hit(ARB_SRC_REAL, 45'h010_0000_0001, 3'b000, 4'h1, 1'b1, 1'b0, 1'b0);
      drive_hit(ARB_SRC_EMU, 45'h010_0000_1001, 3'b000, 4'h8, 1'b1, 1'b0, 1'b0);
    join
    wait_cycles(8);
    drive_hit(ARB_SRC_REAL, 45'h010_0000_0002, 3'b000, 4'h1, 1'b0, 1'b1, 1'b1);
    drive_hit(ARB_SRC_EMU, 45'h010_0000_1002, 3'b000, 4'h8, 1'b0, 1'b1, 1'b1);
    wait_cycles(16);
    drive_packet(ARB_SRC_REAL, 1, 45'h010_0000_0003, 3'b000, 4'h1);
    wait_cycles(8);
    csr_read_pair(ARB_REG_EGRESS_REAL_HITS_L_ADDR, real_hits_v);
    csr_read_pair(ARB_REG_EGRESS_EMU_HITS_L_ADDR, emu_hits_v);
    expect64("egress real hits after adjacent eors", real_hits_v, 64'd2);
    expect64("egress emu hits after adjacent eors", emu_hits_v, 64'd2);
  endtask
endclass
