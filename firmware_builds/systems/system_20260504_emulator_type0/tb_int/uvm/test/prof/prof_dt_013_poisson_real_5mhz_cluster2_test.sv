// prof_dt_013_poisson_real_5mhz_cluster2_test.sv
// Generated PROF bucket test for tb_int.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add generated PROF bucket test coverage.

package prof_dt_013_poisson_real_5mhz_cluster2_test_pkg;

    import uvm_pkg::*;
    import tb_int_base_test_pkg::*;
    import prof_dt_013_poisson_real_5mhz_cluster2_seq_pkg::*;
    `include "uvm_macros.svh"

    class prof_dt_013_poisson_real_5mhz_cluster2_test extends tb_int_base_test;
        `uvm_component_utils(prof_dt_013_poisson_real_5mhz_cluster2_test)

        virtual mutrig_l2_commit_if stage_a_vif;
        virtual hit_tap_if          pre_rbcam_vif;
        virtual hit_tap_if          post_rbcam_vif;
        virtual hit_tap_if          feb_egress_vif;
        virtual sc_avmm_if          sc_vif;
        virtual runctl_phy_if       runctl_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual mutrig_l2_commit_if)::get(this, "", "stage_a_vif", stage_a_vif))
                `uvm_fatal("PROF_TEST", "stage_a_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "pre_rbcam_vif", pre_rbcam_vif))
                `uvm_fatal("PROF_TEST", "pre_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "post_rbcam_vif", post_rbcam_vif))
                `uvm_fatal("PROF_TEST", "post_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "feb_egress_vif", feb_egress_vif))
                `uvm_fatal("PROF_TEST", "feb_egress_vif not configured")
        endfunction

        virtual task run_phase(uvm_phase phase);
            prof_dt_013_poisson_real_5mhz_cluster2_seq seq;

            phase.raise_objection(this);
            reset_per_test_delay();
            sc_vif = env.sc_phy.drv.vif;
            runctl_vif = env.runctl_phy.drv.vif;
            if (sc_vif == null)
                `uvm_fatal("PROF_TEST", "sc_vif not available from env.sc_phy.drv")
            if (runctl_vif == null)
                `uvm_fatal("PROF_TEST", "runctl_vif not available from env.runctl_phy.drv")
            seq = prof_dt_013_poisson_real_5mhz_cluster2_seq::type_id::create("seq");
            seq.stage_a_vif = stage_a_vif;
            seq.pre_rbcam_vif = pre_rbcam_vif;
            seq.post_rbcam_vif = post_rbcam_vif;
            seq.feb_egress_vif = feb_egress_vif;
            seq.sc_vif = sc_vif;
            seq.runctl_vif = runctl_vif;
            seq.start(null);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage

module prof_dt_013_poisson_real_5mhz_cluster2_anchor;
    import prof_dt_013_poisson_real_5mhz_cluster2_test_pkg::*;
endmodule

bind tb_int_top prof_dt_013_poisson_real_5mhz_cluster2_anchor prof_dt_013_poisson_real_5mhz_cluster2_anchor_i();
