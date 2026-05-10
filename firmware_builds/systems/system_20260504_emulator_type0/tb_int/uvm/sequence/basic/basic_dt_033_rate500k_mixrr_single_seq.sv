// basic_dt_033_rate500k_mixrr_single_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-033.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_033_RATE500K_MIXRR_SINGLE_SEQ_SV
`define BASIC_DT_033_RATE500K_MIXRR_SINGLE_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_033_rate500k_mixrr_single_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_033_rate500k_mixrr_single_seq)

    localparam string CASE_ID = "BASIC-DT-033";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Rate sweep 500kHz per channel source mixrr channel-set single";

    function new(string name = "basic_dt_033_rate500k_mixrr_single_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
