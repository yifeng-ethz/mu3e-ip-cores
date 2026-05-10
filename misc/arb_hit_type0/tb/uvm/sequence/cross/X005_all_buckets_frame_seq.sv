import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X005_all_buckets_frame_seq extends X000_cross_base_seq;
  `uvm_object_utils(X005_all_buckets_frame_seq)

  function new(string name = "X005_all_buckets_frame_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] read_v;
    bit [31:0] status_v;

    csr_read(ARB_REG_UID_ADDR, read_v);
    clear_all(ARB_MODE_REAL_CONST);

    run_stream(1'b0, 6, 3, 4'h0, 3'h0, 0, 0, 1'b0, 45'h0500_0000_0000, 32'h0000_0501);
    wait_clocks(32);
    set_mode(ARB_MODE_EMU_CONST);
    run_stream(1'b1, 6, 3, 4'h8, 3'h1, 0, 0, 1'b0, 45'h0510_0000_0000, 32'h0000_0502);
    wait_clocks(32);

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      run_stream(1'b0, 12, 4, 4'h7, 3'h0, 0, 0, 1'b0, 45'h0520_0000_0000, 32'h0000_0503);
      run_stream(1'b1, 12, 4, 4'hf, 3'h7, 2, 0, 1'b0, 45'h0530_0000_0000, 32'h0000_0504);
    join
    wait_clocks(128);

    fork
      run_stream(1'b0, 64, 4, 4'h3, 3'h0, 0, 1, 1'b0, 45'h0540_0000_0000, 32'h0000_0505);
      run_stream(1'b1, 64, 4, 4'hb, 3'h0, 1, 1, 1'b0, 45'h0550_0000_0000, 32'h0000_0506);
    join
    wait_clocks(384);
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "all-frame pre-error real drops");
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd0, "all-frame pre-error emu drops");

    run_stream(1'b0, 1, 1, 4'h2, 3'h0, 0, 0, 1'b1, 45'h0560_0000_0000, 32'h0000_0507);
    wait_clocks(24);
    run_resetting_subframe();

    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_RESERVED_CONST));
    wait_clocks(8);
    read_status(status_v);
    if ((status_v[1:0] !== ARB_MODE_REAL_CONST) || (status_v[13] !== 1'b1)) begin
      `uvm_error(get_type_name(), $sformatf("all-frame reserved status unexpected: 0x%08h", status_v))
    end

    set_mode(ARB_MODE_EMU_CONST);
    run_stream(1'b0, 18, 1, 4'h1, 3'h0, 0, 0, 1'b0, 45'h0570_0000_0000, 32'h0000_0508);
    wait_clocks(32);
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd2, "all-frame real drops after reserved segment");

    run_resetting_subframe();
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "all-frame final reset clears drops");
    poll_defined_csrs();
  endtask
endclass
