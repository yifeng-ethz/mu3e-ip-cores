// basic_rc_030_random_depth12_d4_seq.sv
// BASIC bucket sequence wrapper for BASIC-RC-030.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_RC_030_RANDOM_DEPTH12_D4_SEQ_SV
`define BASIC_RC_030_RANDOM_DEPTH12_D4_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_rc_030_random_depth12_d4_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_rc_030_random_depth12_d4_seq)

    localparam string CASE_ID = "BASIC-RC-030";
    localparam string CASE_SECTION = "RC";
    localparam string CASE_SUMMARY = "Seeded random run-control sequence depth 12 seed 0xD4";

    function new(string name = "basic_rc_030_random_depth12_d4_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
