// basic_sc_010_burst_arb_first_half_seq.sv
// BASIC bucket sequence wrapper for BASIC-SC-010.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_SC_010_BURST_ARB_FIRST_HALF_SEQ_SV
`define BASIC_SC_010_BURST_ARB_FIRST_HALF_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_sc_010_burst_arb_first_half_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_sc_010_burst_arb_first_half_seq)

    localparam string CASE_ID = "BASIC-SC-010";
    localparam string CASE_SECTION = "SC";
    localparam string CASE_SUMMARY = "Burst read arb_hit_type0 first half";

    function new(string name = "basic_sc_010_burst_arb_first_half_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
