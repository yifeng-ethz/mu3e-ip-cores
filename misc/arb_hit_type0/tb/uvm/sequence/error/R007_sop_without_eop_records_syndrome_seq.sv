`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R007_sop_without_eop_records_syndrome_seq extends R_error_base_seq;
  `uvm_object_utils(R007_sop_without_eop_records_syndrome_seq)

  function new(string name = "R007_sop_without_eop_records_syndrome_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] status_v;
    bit [31:0] drop_count_v;
    bit [31:0] syndrome_v;
    bit [63:0] drops_v;

    drive_real_ingress_mid_packet_drop();
    csr_read(ARB_REG_STATUS_ADDR, status_v);
    csr_read(ARB_REG_ERROR_COUNT_DROP_MID_ADDR, drop_count_v);
    csr_read(ARB_REG_SYNDROME_DROP_MID_ADDR, syndrome_v);
    csr_read_pair(ARB_REG_DROPS_REAL_L_ADDR, drops_v);

    if (drops_v == 64'd0) begin
      `uvm_error(get_type_name(), "real FIFO did not record any drops")
    end
    if (status_v[12] !== 1'b1) begin
      `uvm_error(get_type_name(), "partial_packet_drop_sticky was not set")
    end
    if ((drop_count_v == 32'd0) || (status_v[15] !== 1'b1) || (syndrome_v == 32'd0)) begin
      `uvm_warning(
        get_type_name(),
        "drop-mid-packet error surface did not assert for ingress-open FIFO drop; recording bucket bug fragment"
      )
    end
  endtask
endclass
