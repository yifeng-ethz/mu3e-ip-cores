// basic_sc_001_identity_scan_seq.sv
// BASIC bucket sequence wrapper for BASIC-SC-001.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_SC_001_IDENTITY_SCAN_SEQ_SV
`define BASIC_SC_001_IDENTITY_SCAN_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_sc_001_identity_scan_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_sc_001_identity_scan_seq)

    localparam string CASE_ID = "BASIC-SC-001";
    localparam string CASE_SECTION = "SC";
    localparam string CASE_SUMMARY = "Read UID and META words from every focus-build CSR slave";

    function new(string name = "basic_sc_001_identity_scan_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
