`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R012_run_control_reset_clears_error_state_seq extends R_error_base_seq;
  `uvm_object_utils(R012_run_control_reset_clears_error_state_seq)

  function new(string name = "R012_run_control_reset_clears_error_state_seq");
    super.new(name);
  endfunction

  task body();
    bit [63:0] hits_v;

    drive_protocol_violation_real();
    poke_csr_state("error_count_drop_mid_packet", 32'd3);
    poke_csr_state("syndrome_drop_mid_packet", 32'h0000_4A42);
    sync_scoreboard_error_state(32'd1, 32'd3, protocol_syndrome_real_second_sop(3'b010), 32'h0000_4A42);
    send_runctl(runctl_seq_item::RUN_RESETTING_WORD_CONST);
    wait_cycles(12);
    expect_status_mask(32'h0003_F030, 32'h0000_0000);
    expect_csr32(ARB_REG_ERROR_COUNT_PROTOCOL_ADDR, 32'd0, "RESET protocol count");
    expect_csr32(ARB_REG_ERROR_COUNT_DROP_MID_ADDR, 32'd0, "RESET drop count");
    expect_csr32(ARB_REG_SYNDROME_PROTOCOL_ADDR, 32'd0, "RESET protocol syndrome");
    expect_csr32(ARB_REG_SYNDROME_DROP_MID_ADDR, 32'd0, "RESET drop syndrome");
    csr_read_pair(ARB_REG_INGRESS_REAL_HITS_L_ADDR, hits_v);
    expect64("RESET ingress real hits", hits_v, 64'd0);
  endtask
endclass
