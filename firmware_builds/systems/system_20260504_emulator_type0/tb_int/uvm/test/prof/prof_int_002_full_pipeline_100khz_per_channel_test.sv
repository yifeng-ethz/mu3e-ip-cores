// prof_int_002_full_pipeline_100khz_per_channel_test.sv
// UVM test for PROF-INT-002 full datapath real-RTL integration profiling.
//
// Author: Yifeng Wang <yifenwan@phys.ethz.ch>
// Version : 26.2.0
// Date    : 20260505
// Change  : New -- full generated RTL pipeline test.

package prof_int_002_full_pipeline_100khz_per_channel_test_pkg;

    import uvm_pkg::*;
    import tb_int_base_test_pkg::*;
    import prof_int_002_full_pipeline_100khz_per_channel_seq_pkg::*;
    `include "uvm_macros.svh"

    class prof_int_002_full_pipeline_100khz_per_channel_test extends tb_int_base_test;
        `uvm_component_utils(prof_int_002_full_pipeline_100khz_per_channel_test)

        virtual prof_int_002_ctrl_if ctrl_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual prof_int_002_ctrl_if)::get(
                    this, "", "ctrl_vif", ctrl_vif))
                `uvm_fatal("PROF_INT_002_TEST", "ctrl_vif not configured in uvm_config_db")
        endfunction

        virtual task run_phase(uvm_phase phase);
            prof_int_002_full_pipeline_100khz_per_channel_seq seq;

            phase.raise_objection(this);
            reset_per_test_delay();
            seq = prof_int_002_full_pipeline_100khz_per_channel_seq::type_id::create("seq");
            seq.ctrl_vif = ctrl_vif;
            seq.start(null);
            if (ctrl_vif.sim_failed !== 1'b1)
                $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
