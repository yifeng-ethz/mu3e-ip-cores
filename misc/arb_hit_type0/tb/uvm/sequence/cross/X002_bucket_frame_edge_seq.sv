import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X002_bucket_frame_edge_seq extends X000_cross_base_seq;
  `uvm_object_utils(X002_bucket_frame_edge_seq)

  function new(string name = "X002_bucket_frame_edge_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status_v;

    clear_all(ARB_MODE_REAL_CONST);
    run_stream(1'b0, 1, 1, 4'h7, 3'h0, 0, 0, 1'b0, 45'h01a2_b3c4_d5e6, 32'h0000_0201);
    wait_clocks(16);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd1, "edge single-beat real ingress");
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd1, "edge single-beat real egress");

    set_mode(ARB_MODE_EMU_CONST);
    run_stream(1'b1, 1, 1, 4'hf, 3'h7, 0, 0, 1'b0, 45'h01ff_ffff_ffff, 32'h0000_0202);
    wait_clocks(16);
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd1, "edge max-channel emu ingress");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd1, "edge max-channel emu egress");

    set_mode(ARB_MODE_MIX_RR_CONST);
    run_stream(1'b0, 16, 16, 4'h1, 3'h0, 0, 0, 1'b0, 45'h0200_0000_0000, 32'h0000_0203);
    wait_clocks(96);
    run_stream(1'b1, 3, 1, 4'hf, 3'h7, 0, 0, 1'b0, 45'h0210_0000_0000, 32'h0000_0204);
    wait_clocks(48);
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "edge real drops");
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd0, "edge emu drops");

    set_mode(ARB_MODE_REAL_CONST);
    run_stream(1'b0, 1, 1, 4'h2, 3'h0, 0, 0, 1'b1, 45'h0220_0000_0000, 32'h0000_0205);
    wait_clocks(24);
    read_status(status_v);
    run_stream(1'b0, 1, 1, 4'h2, 3'h0, 0, 0, 1'b0, 45'h0220_0000_0010, 32'h0000_0206);
    wait_clocks(16);
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd18, "edge eor locks later grants");

    run_resetting_subframe();
    expect_status_mode(ARB_MODE_REAL_CONST, "edge reset subframe");
    poll_defined_csrs();
  endtask
endclass
