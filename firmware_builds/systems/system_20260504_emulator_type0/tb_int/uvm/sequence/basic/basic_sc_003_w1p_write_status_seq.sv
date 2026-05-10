// basic_sc_003_w1p_write_status_seq.sv
// BASIC bucket sequence wrapper for BASIC-SC-003.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_SC_003_W1P_WRITE_STATUS_SEQ_SV
`define BASIC_SC_003_W1P_WRITE_STATUS_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_sc_003_w1p_write_status_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_sc_003_w1p_write_status_seq)

    localparam string CASE_ID = "BASIC-SC-003";
    localparam string CASE_SECTION = "SC";
    localparam string CASE_SUMMARY = "Single-word W1P clear path and sticky status read";

    function new(string name = "basic_sc_003_w1p_write_status_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
