// basic_dt_080_clustered4_real_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-080.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_080_CLUSTERED4_REAL_SEQ_SV
`define BASIC_DT_080_CLUSTERED4_REAL_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_080_clustered4_real_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_080_clustered4_real_seq)

    localparam string CASE_ID = "BASIC-DT-080";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Clustered contiguous size 4 source REAL";

    function new(string name = "basic_dt_080_clustered4_real_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
