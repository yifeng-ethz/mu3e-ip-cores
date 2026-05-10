// basic_dt_116_poisson_1m_cluster4_random_seq.sv
// BASIC bucket sequence wrapper for BASIC-DT-116.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case sequence.

`ifndef BASIC_DT_116_POISSON_1M_CLUSTER4_RANDOM_SEQ_SV
`define BASIC_DT_116_POISSON_1M_CLUSTER4_RANDOM_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class basic_dt_116_poisson_1m_cluster4_random_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(basic_dt_116_poisson_1m_cluster4_random_seq)

    localparam string CASE_ID = "BASIC-DT-116";
    localparam string CASE_SECTION = "DT";
    localparam string CASE_SUMMARY = "Poisson 1 MHz per channel cluster mean 4 random spatial spread";

    function new(string name = "basic_dt_116_poisson_1m_cluster4_random_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("BASIC_SEQ",
                  $sformatf("%s %s: %s", CASE_ID, CASE_SECTION, CASE_SUMMARY),
                  UVM_LOW)
    endtask
endclass


`endif
