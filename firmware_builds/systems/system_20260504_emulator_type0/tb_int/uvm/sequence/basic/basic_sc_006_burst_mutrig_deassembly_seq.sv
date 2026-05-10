// basic_sc_006_burst_mutrig_deassembly_seq.sv
// BASIC bucket sequence wrapper for BASIC-SC-006.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_SC_006_BURST_MUTRIG_DEASSEMBLY_SEQ_SV
`define BASIC_SC_006_BURST_MUTRIG_DEASSEMBLY_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_sc_006_burst_mutrig_deassembly_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_sc_006_burst_mutrig_deassembly_seq)

    localparam string CASE_ID = "BASIC-SC-006";
    localparam string CASE_SECTION = "SC";
    localparam string CASE_SUMMARY = "Burst read mutrig_frame_deassembly aperture";

    function new(string name = "basic_sc_006_burst_mutrig_deassembly_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
