// basic_dt_106_hits_after_terminating_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-106.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_106_HITS_AFTER_TERMINATING_SEQ_SV
`define BASIC_DT_106_HITS_AFTER_TERMINATING_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_106_hits_after_terminating_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_106_hits_after_terminating_seq)

    localparam string CASE_ID = "BASIC-DT-106";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Hits draining after TERMINATING complete in-flight frame";

    function new(string name = "basic_dt_106_hits_after_terminating_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
