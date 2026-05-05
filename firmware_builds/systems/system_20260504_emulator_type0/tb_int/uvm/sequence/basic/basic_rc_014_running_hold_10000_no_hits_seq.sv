// basic_rc_014_running_hold_10000_no_hits_seq.sv
// BASIC bucket sequence wrapper for BASIC-RC-014.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_RC_014_RUNNING_HOLD_10000_NO_HITS_SEQ_SV
`define BASIC_RC_014_RUNNING_HOLD_10000_NO_HITS_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_rc_014_running_hold_10000_no_hits_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_rc_014_running_hold_10000_no_hits_seq)

    localparam string CASE_ID = "BASIC-RC-014";
    localparam string CASE_SECTION = "RC";
    localparam string CASE_SUMMARY = "RUNNING held for 10000 cycles with no hits";

    function new(string name = "basic_rc_014_running_hold_10000_no_hits_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
