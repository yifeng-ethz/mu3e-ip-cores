// basic_rc_011_rp_reenter_seq.sv
// BASIC bucket sequence wrapper for BASIC-RC-011.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_RC_011_RP_REENTER_SEQ_SV
`define BASIC_RC_011_RP_REENTER_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_rc_011_rp_reenter_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_rc_011_rp_reenter_seq)

    localparam string CASE_ID = "BASIC-RC-011";
    localparam string CASE_SECTION = "RC";
    localparam string CASE_SUMMARY = "RUN_PREP re-entered while already in RUN_PREP";

    function new(string name = "basic_rc_011_rp_reenter_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
