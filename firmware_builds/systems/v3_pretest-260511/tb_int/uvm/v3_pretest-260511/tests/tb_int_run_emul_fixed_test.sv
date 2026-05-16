// tb_int_run_emul_fixed_test.sv
// FEB BUG-RC-RUN-EMUL host-driven run-control regression test.
//
// Author : Claude Opus
// Date   : 20260511
// Scope  : Drives real host command bytes through runctl_mgmt_host and the
//          generated Qsys splitter wrappers, then checks end-to-end hit
//          evidence and histogram extended ingress.

package tb_int_run_emul_fixed_test_pkg;

    import uvm_pkg::*;
    import tb_int_base_test_pkg::*;
    import tb_int_run_emulator_directed_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_run_emul_fixed_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_run_emul_fixed_test)

        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        int unsigned hit_count = 16;
        bit realistic_latency_model = 1'b0;
        int unsigned periodic_channel = 0;
        bit periodic_channel_forced = 1'b0;
        bit periodic_channel_seed_valid = 1'b0;
        int unsigned periodic_channel_seed = 0;
        int unsigned periodic_hit_period_cycles = 1250;
        int unsigned run_prep_flush_cycles = 5000;
        int unsigned upload_frames_per_lane = 2;

        function new(string name = "tb_int_run_emul_fixed_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            int unsigned plusarg_hits;

            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_phy_if)::get(this, "", "runctl_phy_vif", rc_vif))
                `uvm_fatal("RC_EMUL_FIX", "runctl_phy_vif not configured")
            if (!uvm_config_db#(virtual sc_avmm_if)::get(this, "", "sc_phy_vif", sc_vif))
                `uvm_fatal("RC_EMUL_FIX", "sc_phy_vif not configured")
            if ($value$plusargs("TB_INT_RC_EMUL_HIT_COUNT=%d", plusarg_hits))
                hit_count = plusarg_hits;
            realistic_latency_model = $test$plusargs("TB_INT_REALISTIC_LATENCY");
            periodic_channel_forced = $value$plusargs("TB_INT_PERIODIC_CHANNEL=%d", periodic_channel);
            periodic_channel &= 32'h1F;
            periodic_channel_seed_valid = $value$plusargs("ARB_SEED=%d", periodic_channel_seed);
            void'($value$plusargs("TB_INT_PERIODIC_HIT_PERIOD_CYCLES=%d",
                                  periodic_hit_period_cycles));
            void'($value$plusargs("TB_INT_RUN_PREP_FLUSH_CYCLES=%d",
                                  run_prep_flush_cycles));
            void'($value$plusargs("TB_INT_FEB_UPLOAD_FRAMES_PER_LANE=%d",
                                  upload_frames_per_lane));
        endfunction

        virtual task run_phase(uvm_phase phase);
            run_emulator_directed seq;

            phase.raise_objection(this);
            wait (stage_a_vif.rst === 1'b0);
            repeat (8) @(posedge stage_a_vif.clk);
            seq = run_emulator_directed::type_id::create("run_emulator_directed_fixed_seq");
            seq.configure(rc_vif,
                          sc_vif,
                          stage_a_vif,
                          debug_l2_vif,
                          emulator_egress_vif,
                          debug_emulator_egress_vif,
                          pre_rbcam_vif,
                          post_rbcam_vif,
                          debug_pre_rbcam_vif,
                          debug_post_rbcam_vif,
                          debug_feb_egress_vif,
                          feb_egress_vif,
                          upload_data0_frame_vif,
                          upload_data1_frame_vif);
            seq.emul_check_mode = EMUL_MODE_EXPECT_FIXED;
            seq.realistic_latency_model = realistic_latency_model;
            seq.periodic_channel = periodic_channel;
            seq.periodic_channel_forced = periodic_channel_forced;
            seq.periodic_channel_seed_valid = periodic_channel_seed_valid;
            seq.periodic_channel_seed = periodic_channel_seed;
            seq.periodic_hit_period_cycles = periodic_hit_period_cycles;
            seq.run_prep_flush_cycles = run_prep_flush_cycles;
            seq.upload_frames_per_lane = upload_frames_per_lane;
            if ($test$plusargs("TB_INT_RC_EMUL_SNAPSHOT_ONLY"))
                seq.emul_check_mode = EMUL_MODE_NONE;
            seq.body(hit_count);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
