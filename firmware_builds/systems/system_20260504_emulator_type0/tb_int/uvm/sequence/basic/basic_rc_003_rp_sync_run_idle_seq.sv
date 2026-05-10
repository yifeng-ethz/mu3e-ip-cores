// basic_rc_003_rp_sync_run_idle_seq.sv
// BASIC bucket sequence wrapper for BASIC-RC-003.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_RC_003_RP_SYNC_RUN_IDLE_SEQ_SV
`define BASIC_RC_003_RP_SYNC_RUN_IDLE_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_rc_003_rp_sync_run_idle_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_rc_003_rp_sync_run_idle_seq)

    localparam string CASE_ID = "BASIC-RC-003";
    localparam string CASE_SECTION = "RC";
    localparam string CASE_SUMMARY = "IDLE -> RUN_PREP -> SYNC -> RUNNING -> IDLE";

    function new(string name = "basic_rc_003_rp_sync_run_idle_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
