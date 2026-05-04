import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X001_bucket_frame_basic_seq extends X000_cross_base_seq;
  `uvm_object_utils(X001_bucket_frame_basic_seq)

  function new(string name = "X001_bucket_frame_basic_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] read_v;

    csr_read(ARB_REG_UID_ADDR, read_v);
    if (read_v !== ARB_UID_CONST) begin
      `uvm_error(get_type_name(), $sformatf("UID expected 0x%08h observed 0x%08h", ARB_UID_CONST, read_v))
    end

    for (int sel_v = 0; sel_v < 4; sel_v++) begin
      read_v = sel_v;
      csr_write(ARB_REG_META_ADDR, read_v);
      csr_read(ARB_REG_META_ADDR, read_v);
    end

    expect_status_mode(ARB_MODE_REAL_CONST, "reset default");
    clear_all(ARB_MODE_REAL_CONST);

    run_stream(1'b0, 4, 4, 4'h0, 3'h0, 0, 0, 1'b0, 45'h0010_0000_0000, 32'h0000_0101);
    wait_clocks(24);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd4, "basic real ingress");
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd4, "basic real egress");

    set_mode(ARB_MODE_EMU_CONST);
    expect_status_mode(ARB_MODE_EMU_CONST, "emu mode");
    run_stream(1'b1, 3, 3, 4'h8, 3'h1, 0, 0, 1'b0, 45'h0020_0000_0000, 32'h0000_0102);
    wait_clocks(24);
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd3, "basic emu ingress");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd3, "basic emu egress");

    set_mode(ARB_MODE_MIX_RR_CONST);
    expect_status_mode(ARB_MODE_MIX_RR_CONST, "mix mode");
    fork
      run_stream(1'b0, 4, 4, 4'h3, 3'h2, 0, 0, 1'b0, 45'h0030_0000_0000, 32'h0000_0103);
      run_stream(1'b1, 2, 2, 4'hb, 3'h3, 0, 0, 1'b0, 45'h0040_0000_0000, 32'h0000_0104);
    join
    wait_clocks(48);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd8, "basic mixed real ingress");
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd5, "basic mixed emu ingress");
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd8, "basic mixed real egress");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd5, "basic mixed emu egress");

    run_invalid_beat(1'b0, 4'h1, 45'h0000_0000_001);
    wait_clocks(8);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd8, "valid-low ignored");

    clear_all(ARB_MODE_REAL_CONST);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd0, "counter clear real ingress");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd0, "counter clear emu egress");
    poll_defined_csrs();
  endtask
endclass
