// basic_dt_100_hit_at_running_terminating_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-100.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_100_HIT_AT_RUNNING_TERMINATING_SEQ_SV
`define BASIC_DT_100_HIT_AT_RUNNING_TERMINATING_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_100_hit_at_running_terminating_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_100_hit_at_running_terminating_seq)

    localparam string CASE_ID = "BASIC-DT-100";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Last hit exactly at RUNNING to TERMINATING transition";

    function new(string name = "basic_dt_100_hit_at_running_terminating_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
