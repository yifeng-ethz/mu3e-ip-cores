// tb_int_base_test.sv
// Base UVM test for v3_pretest-260511 dual-env integration tb_int.

package tb_int_base_test_pkg;

    import uvm_pkg::*;
    import tb_int_dual_env_pkg::*;
    import tb_int_run_window_pkg::*;
    import tb_int_basic_sequences_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        TB_INT_EXEC_ISOLATED,
        TB_INT_EXEC_BUCKET_FRAME,
        TB_INT_EXEC_ALL_BUCKETS_FRAME
    } tb_int_exec_mode_e;

    class tb_int_base_test extends uvm_test;
        `uvm_component_utils(tb_int_base_test)

        tb_int_dual_env env;
        tb_int_exec_mode_e exec_mode;

        virtual mutrig_l2_commit_if stage_a_vif;
        virtual mutrig_l2_commit_if debug_l2_vif;
        virtual hit_tap_if emulator_egress_vif;
        virtual hit_tap_if debug_emulator_egress_vif;
        virtual hit_tap_if pre_rbcam_vif;
        virtual hit_tap_if post_rbcam_vif;
        virtual hit_tap_if debug_pre_rbcam_vif;
        virtual hit_tap_if debug_post_rbcam_vif;
        virtual hit_tap_if debug_feb_egress_vif;
        virtual hit_tap_if feb_egress_vif;
        virtual mu3e_frame_if upload_data0_frame_vif;
        virtual mu3e_frame_if upload_data1_frame_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            exec_mode = TB_INT_EXEC_ISOLATED;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            string mode_name;

            super.build_phase(phase);
            if ($value$plusargs("TB_INT_EXEC_MODE=%s", mode_name)) begin
                if (mode_name == "bucket_frame")
                    exec_mode = TB_INT_EXEC_BUCKET_FRAME;
                else if (mode_name == "all_buckets_frame")
                    exec_mode = TB_INT_EXEC_ALL_BUCKETS_FRAME;
                else
                    exec_mode = TB_INT_EXEC_ISOLATED;
            end
            env = tb_int_dual_env::type_id::create("env", this);
            get_required_vifs();
        endfunction

        virtual function void get_required_vifs();
            if (!uvm_config_db#(virtual mutrig_l2_commit_if)::get(this, "", "stage_a_vif", stage_a_vif))
                `uvm_fatal("TB_INT_BASE", "stage_a_vif not configured")
            if (!uvm_config_db#(virtual mutrig_l2_commit_if)::get(this, "", "debug_l2_vif", debug_l2_vif))
                `uvm_fatal("TB_INT_BASE", "debug_l2_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "emulator_egress_vif", emulator_egress_vif))
                `uvm_fatal("TB_INT_BASE", "emulator_egress_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "debug_emulator_egress_vif", debug_emulator_egress_vif))
                `uvm_fatal("TB_INT_BASE", "debug_emulator_egress_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "pre_rbcam_vif", pre_rbcam_vif))
                `uvm_fatal("TB_INT_BASE", "pre_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "post_rbcam_vif", post_rbcam_vif))
                `uvm_fatal("TB_INT_BASE", "post_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "debug_pre_rbcam_vif", debug_pre_rbcam_vif))
                `uvm_fatal("TB_INT_BASE", "debug_pre_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "debug_post_rbcam_vif", debug_post_rbcam_vif))
                `uvm_fatal("TB_INT_BASE", "debug_post_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "debug_feb_egress_vif", debug_feb_egress_vif))
                `uvm_fatal("TB_INT_BASE", "debug_feb_egress_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "feb_egress_vif", feb_egress_vif))
                `uvm_fatal("TB_INT_BASE", "feb_egress_vif not configured")
            if (!uvm_config_db#(virtual mu3e_frame_if)::get(this, "", "upload_data0_frame_vif", upload_data0_frame_vif))
                `uvm_fatal("TB_INT_BASE", "upload_data0_frame_vif not configured")
            if (!uvm_config_db#(virtual mu3e_frame_if)::get(this, "", "upload_data1_frame_vif", upload_data1_frame_vif))
                `uvm_fatal("TB_INT_BASE", "upload_data1_frame_vif not configured")
        endfunction

        virtual task reset_per_test_delay();
            if (exec_mode == TB_INT_EXEC_ISOLATED)
                tb_int_run_window_db::reset();
        endtask

        virtual task run_basic_sequence(string case_id, int unsigned hit_count);
            tb_int_basic_sequence basic_seq;

            reset_per_test_delay();
            basic_seq = tb_int_basic_sequence::type_id::create($sformatf("%s_seq", case_id));
            basic_seq.drive_case(case_id,
                                 hit_count,
                                 stage_a_vif,
                                 debug_l2_vif,
                                 pre_rbcam_vif,
                                 post_rbcam_vif,
                                 debug_pre_rbcam_vif,
                                 debug_post_rbcam_vif,
                                 debug_feb_egress_vif,
                                 feb_egress_vif);
        endtask
    endclass

endpackage
