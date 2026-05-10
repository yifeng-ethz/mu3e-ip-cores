`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R008_protocol_violation_two_sops_records_syndrome_seq extends R_error_base_seq;
  `uvm_object_utils(R008_protocol_violation_two_sops_records_syndrome_seq)

  function new(string name = "R008_protocol_violation_two_sops_records_syndrome_seq");
    super.new(name);
  endfunction

  task body();
    drive_protocol_violation_real(3'b010);
    expect_status_mask(32'h0000_4000, 32'h0000_4000);
    expect_csr32(ARB_REG_ERROR_COUNT_PROTOCOL_ADDR, 32'd1, "ERROR_COUNT_PROTOCOL");
    expect_csr32(
      ARB_REG_SYNDROME_PROTOCOL_ADDR,
      protocol_syndrome_real_second_sop(3'b010),
      "SYNDROME_PROTOCOL"
    );
  endtask
endclass
