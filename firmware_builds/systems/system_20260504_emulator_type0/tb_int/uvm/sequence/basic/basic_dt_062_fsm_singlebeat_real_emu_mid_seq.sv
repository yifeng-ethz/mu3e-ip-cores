// basic_dt_062_fsm_singlebeat_real_emu_mid_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-062.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_062_FSM_SINGLEBEAT_REAL_EMU_MID_SEQ_SV
`define BASIC_DT_062_FSM_SINGLEBEAT_REAL_EMU_MID_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_062_fsm_singlebeat_real_emu_mid_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_062_fsm_singlebeat_real_emu_mid_seq)

    localparam string CASE_ID = "BASIC-DT-062";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Single-beat real packet while emu packet is mid-flight";

    function new(string name = "basic_dt_062_fsm_singlebeat_real_emu_mid_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
