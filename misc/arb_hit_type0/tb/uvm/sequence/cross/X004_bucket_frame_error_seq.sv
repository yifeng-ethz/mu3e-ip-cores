import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X004_bucket_frame_error_seq extends X000_cross_base_seq;
  `uvm_object_utils(X004_bucket_frame_error_seq)

  function new(string name = "X004_bucket_frame_error_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status_v;

    clear_all(ARB_MODE_REAL_CONST);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_RESERVED_CONST));
    wait_clocks(8);
    read_status(status_v);
    if ((status_v[1:0] !== ARB_MODE_REAL_CONST) || (status_v[13] !== 1'b1)) begin
      `uvm_error(get_type_name(), $sformatf("reserved mode status unexpected: 0x%08h", status_v))
    end

    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST, .clear_sticky(1'b1)));
    wait_clocks(8);
    read_status(status_v);
    if (status_v[13] !== 1'b0) begin
      `uvm_error(get_type_name(), $sformatf("reserved-mode sticky did not clear: 0x%08h", status_v))
    end

    set_mode(ARB_MODE_EMU_CONST);
    run_stream(1'b0, 20, 1, 4'h0, 3'h0, 0, 0, 1'b0, 45'h0400_0000_0000, 32'h0000_0401);
    wait_clocks(24);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd16, "error real accepted before full");
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd4, "error real drops");

    run_preparing_subframe();
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd16, "run-prep preserves hit counters");

    run_resetting_subframe();
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd0, "run-reset clears hit counters");
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "run-reset clears drops");

    set_mode(ARB_MODE_REAL_CONST);
    run_stream(1'b1, 20, 1, 4'h8, 3'h0, 0, 0, 1'b0, 45'h0410_0000_0000, 32'h0000_0402);
    wait_clocks(24);
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd16, "error emu accepted before full");
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd4, "error emu drops");

    run_resetting_subframe();
    poll_defined_csrs();
  endtask
endclass
