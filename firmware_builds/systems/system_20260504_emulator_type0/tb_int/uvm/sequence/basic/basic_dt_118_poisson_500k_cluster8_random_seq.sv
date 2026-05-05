// basic_dt_118_poisson_500k_cluster8_random_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-118.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_118_POISSON_500K_CLUSTER8_RANDOM_SEQ_SV
`define BASIC_DT_118_POISSON_500K_CLUSTER8_RANDOM_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_118_poisson_500k_cluster8_random_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_118_poisson_500k_cluster8_random_seq)

    localparam string CASE_ID = "BASIC-DT-118";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Poisson 500 kHz per channel cluster mean 8 random spatial spread";

    function new(string name = "basic_dt_118_poisson_500k_cluster8_random_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
