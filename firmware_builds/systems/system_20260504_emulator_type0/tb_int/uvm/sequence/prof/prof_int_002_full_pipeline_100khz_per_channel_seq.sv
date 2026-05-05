// prof_int_002_full_pipeline_100khz_per_channel_seq.sv
// PROF-INT-002 sequence shell for the full-pipeline real-RTL integration run.
//
// Author: Yifeng Wang <yifenwan@phys.ethz.ch>
// Version : 26.2.0
// Date    : 20260505
// Change  : New -- wait for the full-pipeline top-level controller.

interface prof_int_002_ctrl_if (
    input logic clk,
    input logic rst
);
    logic sim_started;
    logic sim_done;
    logic sim_failed;
    longint unsigned run_cycles;
    longint unsigned drain_cycles;
    longint unsigned stage_a_count;
    longint unsigned pre_rbcam_count;
    longint unsigned post_rbcam_count;
    longint unsigned feb_egress_count;

    task automatic clear();
        sim_started = 1'b0;
        sim_done = 1'b0;
        sim_failed = 1'b0;
        run_cycles = 64'd0;
        drain_cycles = 64'd0;
        stage_a_count = 64'd0;
        pre_rbcam_count = 64'd0;
        post_rbcam_count = 64'd0;
        feb_egress_count = 64'd0;
    endtask
endinterface

package prof_int_002_full_pipeline_100khz_per_channel_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class prof_int_002_full_pipeline_100khz_per_channel_seq
        extends uvm_sequence #(uvm_sequence_item);

        `uvm_object_utils(prof_int_002_full_pipeline_100khz_per_channel_seq)

        virtual prof_int_002_ctrl_if ctrl_vif;

        function new(string name = "prof_int_002_full_pipeline_100khz_per_channel_seq");
            super.new(name);
        endfunction

        virtual task body();
            if (ctrl_vif == null)
                `uvm_fatal("PROF_INT_002_SEQ", "ctrl_vif not configured")

            @(negedge ctrl_vif.rst);
            wait (ctrl_vif.sim_started === 1'b1);
            `uvm_info("PROF_INT_002_SEQ",
                      $sformatf("full-pipeline run started run_cycles=%0d drain_cycles=%0d",
                                ctrl_vif.run_cycles,
                                ctrl_vif.drain_cycles),
                      UVM_LOW)
            wait (ctrl_vif.sim_done === 1'b1);
            if (ctrl_vif.sim_failed === 1'b1)
                `uvm_error("PROF_INT_002_SEQ", "top-level full-pipeline controller reported failure")
            `uvm_info("PROF_INT_002_SEQ",
                      $sformatf("full-pipeline controller done A=%0d PRE=%0d POST=%0d FEB=%0d",
                                ctrl_vif.stage_a_count,
                                ctrl_vif.pre_rbcam_count,
                                ctrl_vif.post_rbcam_count,
                                ctrl_vif.feb_egress_count),
                      UVM_LOW)
        endtask
    endclass

endpackage
