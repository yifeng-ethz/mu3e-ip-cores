`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R011_error_counter_saturation_seq extends R_error_base_seq;
  `uvm_object_utils(R011_error_counter_saturation_seq)

  function new(string name = "R011_error_counter_saturation_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] protocol_syndrome_v;
    bit [31:0] drop_syndrome_v;

    protocol_syndrome_v = 32'h0000_A501;
    drop_syndrome_v     = 32'h0001_4A42;
    poke_csr_state("error_count_protocol", 32'hFFFF_FFFE);
    poke_csr_state("error_count_drop_mid_packet", 32'hFFFF_FFFE);
    poke_csr_state("syndrome_protocol", protocol_syndrome_v);
    poke_csr_state("syndrome_drop_mid_packet", drop_syndrome_v);
    sync_scoreboard_error_state(32'hFFFF_FFFE, 32'hFFFF_FFFE, protocol_syndrome_v, drop_syndrome_v);
    expect_csr32(ARB_REG_ERROR_COUNT_PROTOCOL_ADDR, 32'hFFFF_FFFE, "pre-saturation protocol count");
    drive_protocol_violation_real(3'b011);
    expect_csr32(ARB_REG_ERROR_COUNT_PROTOCOL_ADDR, 32'hFFFF_FFFF, "saturated protocol count");
    expect_csr32(ARB_REG_ERROR_COUNT_DROP_MID_ADDR, 32'hFFFF_FFFE, "near-saturated drop count");
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST, 1'b0, 1'b0, 1'b1, 1'b1));
    wait_cycles(4);
    expect_csr32(ARB_REG_ERROR_COUNT_PROTOCOL_ADDR, 32'd0, "cleared protocol count");
    expect_csr32(ARB_REG_ERROR_COUNT_DROP_MID_ADDR, 32'd0, "cleared drop count");
    expect_csr32(ARB_REG_SYNDROME_PROTOCOL_ADDR, 32'd0, "cleared protocol syndrome");
    expect_csr32(ARB_REG_SYNDROME_DROP_MID_ADDR, 32'd0, "cleared drop syndrome");
  endtask
endclass
