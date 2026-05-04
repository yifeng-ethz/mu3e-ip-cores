import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X003_bucket_frame_prof_seq extends X000_cross_base_seq;
  `uvm_object_utils(X003_bucket_frame_prof_seq)

  function new(string name = "X003_bucket_frame_prof_seq");
    super.new(name);
  endfunction

  task body();
    clear_all(ARB_MODE_REAL_CONST);
    expect_status_mode(ARB_MODE_REAL_CONST, "prof initial real");

    run_stream(1'b0, 128, 4, 4'h0, 3'h0, 0, 0, 1'b0, 45'h0300_0000_0000, 32'h0000_0301);
    wait_clocks(384);

    set_mode(ARB_MODE_EMU_CONST);
    run_stream(1'b1, 128, 4, 4'h8, 3'h0, 0, 0, 1'b0, 45'h0310_0000_0000, 32'h0000_0302);
    wait_clocks(384);

    set_mode(ARB_MODE_MIX_RR_CONST);
    run_stream(1'b0, 32, 4, 4'h3, 3'h0, 0, 0, 1'b0, 45'h0320_0000_0000, 32'h0000_0303);
    wait_clocks(128);
    run_stream(1'b1, 32, 4, 4'hb, 3'h0, 0, 0, 1'b0, 45'h0330_0000_0000, 32'h0000_0304);
    wait_clocks(128);

    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "prof real drops");
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd0, "prof emu drops");
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd160, "prof real ingress");
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd160, "prof emu ingress");
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd160, "prof real egress");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd160, "prof emu egress");
    poll_defined_csrs();
  endtask
endclass
