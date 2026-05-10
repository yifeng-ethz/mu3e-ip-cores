// basic_rc_022_rp_at_frame_close_seq.sv
// BASIC bucket sequence wrapper for BASIC-RC-022.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_RC_022_RP_AT_FRAME_CLOSE_SEQ_SV
`define BASIC_RC_022_RP_AT_FRAME_CLOSE_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_rc_022_rp_at_frame_close_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_rc_022_rp_at_frame_close_seq)

    localparam string CASE_ID = "BASIC-RC-022";
    localparam string CASE_SECTION = "RC";
    localparam string CASE_SUMMARY = "RUN_PREP reasserted on frame-close cycle";

    function new(string name = "basic_rc_022_rp_at_frame_close_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
