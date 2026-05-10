// basic_dt_083_clustered4_mixrr_cross_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-083.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_083_CLUSTERED4_MIXRR_CROSS_SEQ_SV
`define BASIC_DT_083_CLUSTERED4_MIXRR_CROSS_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_083_clustered4_mixrr_cross_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_083_clustered4_mixrr_cross_seq)

    localparam string CASE_ID = "BASIC-DT-083";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Clustered contiguous size 4 source MIX_RR cross-source";

    function new(string name = "basic_dt_083_clustered4_mixrr_cross_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
