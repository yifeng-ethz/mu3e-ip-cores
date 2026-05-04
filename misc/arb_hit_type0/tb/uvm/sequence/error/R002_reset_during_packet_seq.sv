`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R002_reset_during_packet_seq extends R_error_base_seq;
  `uvm_object_utils(R002_reset_during_packet_seq)

  function new(string name = "R002_reset_during_packet_seq");
    super.new(name);
  endfunction

  task body();
    drive_hit(ARB_SRC_REAL, 45'h002_0000_0001, 3'b000, 4'h1, 1'b1, 1'b0, 1'b0);
    wait_cycles(3);
    pulse_hard_reset();
    wait_cycles(4);
    expect_status_mask(32'h0000_1030, 32'h0000_0000);
    if (cfg_h.egress_vif.valid !== 1'b0) begin
      `uvm_error(get_type_name(), "egress valid remained asserted after reset")
    end
  endtask
endclass
