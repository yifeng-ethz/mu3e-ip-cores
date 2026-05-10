// basic_dt_044_rate2m_emu_full32_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-044.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_044_RATE2M_EMU_FULL32_SEQ_SV
`define BASIC_DT_044_RATE2M_EMU_FULL32_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_044_rate2m_emu_full32_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_044_rate2m_emu_full32_seq)

    localparam string CASE_ID = "BASIC-DT-044";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Rate sweep 2mHz per channel source emu channel-set full32";

    function new(string name = "basic_dt_044_rate2m_emu_full32_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
