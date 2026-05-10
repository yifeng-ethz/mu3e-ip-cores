// basic_dt_090_stride8_8_emu_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-090.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_090_STRIDE8_8_EMU_SEQ_SV
`define BASIC_DT_090_STRIDE8_8_EMU_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_090_stride8_8_emu_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_090_stride8_8_emu_seq)

    localparam string CASE_ID = "BASIC-DT-090";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Stride-8 cluster size 8 source EMU";

    function new(string name = "basic_dt_090_stride8_8_emu_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
