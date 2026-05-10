// basic_dt_095_mixrr_real_fast_emu_slow_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-095.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_095_MIXRR_REAL_FAST_EMU_SLOW_SEQ_SV
`define BASIC_DT_095_MIXRR_REAL_FAST_EMU_SLOW_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_095_mixrr_real_fast_emu_slow_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_095_mixrr_real_fast_emu_slow_seq)

    localparam string CASE_ID = "BASIC-DT-095";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "MIX_RR real 1 MHz and emu 10 kHz fairness";

    function new(string name = "basic_dt_095_mixrr_real_fast_emu_slow_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
