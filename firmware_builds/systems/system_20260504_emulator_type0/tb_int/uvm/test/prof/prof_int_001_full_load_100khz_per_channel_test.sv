// prof_int_001_full_load_100khz_per_channel_test.sv
// UVM test for PROF-INT-001 full-load latency benchmark.
//
// This file is compiled by the prof_int_001 bucket Makefile target.
// It is NOT loaded into tb_int_top.
//
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : New — PROF INT 001 full-load test.

package prof_int_001_full_load_100khz_per_channel_test_pkg;

    import uvm_pkg::*;
    import prof_int_001_full_load_100khz_per_channel_seq_pkg::*;
    `include "uvm_macros.svh"

    class prof_int_001_full_load_100khz_per_channel_test extends uvm_test;
        `uvm_component_utils(prof_int_001_full_load_100khz_per_channel_test)

        virtual prof_int_001_dut_if dut_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual prof_int_001_dut_if)::get(
                    this, "", "dut_vif", dut_vif))
                `uvm_fatal("PROF_INT_001_TEST", "dut_vif not configured in uvm_config_db")
        endfunction

        virtual task run_phase(uvm_phase phase);
            prof_int_001_full_load_100khz_per_channel_seq seq;
            string sim_dir;

            phase.raise_objection(this);
            sim_dir = "sim/prof_int_001_full_load_100khz_per_channel_test";
            if ($value$plusargs("TB_INT_SIM_DIR=%s", sim_dir)) begin
                /* use plusarg value */
            end

            seq = prof_int_001_full_load_100khz_per_channel_seq::type_id::create("seq");
            seq.dut_vif    = dut_vif;
            seq.output_dir = sim_dir;
            seq.start(null);

            repeat (32) @(posedge dut_vif.clk);
            `uvm_info("PROF_INT_001_TEST",
                      $sformatf("PROF-INT-001 complete: emitted=%0d captured=%0d drops=%0d",
                                seq.emitted_hits, seq.captured_hits, seq.drop_count),
                      UVM_LOW)
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
