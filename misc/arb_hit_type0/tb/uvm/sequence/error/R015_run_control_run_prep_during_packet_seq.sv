`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R015_run_control_run_prep_during_packet_seq extends R_error_base_seq;
  `uvm_object_utils(R015_run_control_run_prep_during_packet_seq)

  function new(string name = "R015_run_control_run_prep_during_packet_seq");
    super.new(name);
  endfunction

  task body();
    bit [63:0] ingress_hits_v;
    bit [63:0] egress_hits_v;

    drive_hit(ARB_SRC_REAL, 45'h015_0000_0001, 3'b000, 4'h1, 1'b1, 1'b0, 1'b0);
    wait_cycles(4);
    send_runctl(runctl_seq_item::RUN_PREPARING_WORD_CONST);
    wait_cycles(12);
    expect_status_mask(32'h0000_0070, 32'h0000_0000);
    csr_read_pair(ARB_REG_INGRESS_REAL_HITS_L_ADDR, ingress_hits_v);
    expect64("RUN_PREP preserves ingress hit counters", ingress_hits_v, 64'd1);
    drive_packet(ARB_SRC_REAL, 1, 45'h015_0000_0002, 3'b000, 4'h1);
    wait_cycles(10);
    csr_read_pair(ARB_REG_INGRESS_REAL_HITS_L_ADDR, ingress_hits_v);
    csr_read_pair(ARB_REG_EGRESS_REAL_HITS_L_ADDR, egress_hits_v);
    expect64("post-RUN_PREP ingress hits", ingress_hits_v, 64'd2);
    expect64("post-RUN_PREP egress hits", egress_hits_v, 64'd2);
  endtask
endclass
