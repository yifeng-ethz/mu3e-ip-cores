// basic_dt_058_zero_hz_1ms_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-058.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_058_ZERO_HZ_1MS_SEQ_SV
`define BASIC_DT_058_ZERO_HZ_1MS_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_058_zero_hz_1ms_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_058_zero_hz_1ms_seq)

    localparam string CASE_ID = "BASIC-DT-058";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Zero-Hz one millisecond counter-quiescence baseline";

    function new(string name = "basic_dt_058_zero_hz_1ms_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
