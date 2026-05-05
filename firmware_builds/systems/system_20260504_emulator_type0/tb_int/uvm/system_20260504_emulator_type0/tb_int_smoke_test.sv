// tb_int_smoke_test.sv
// Infrastructure smoke for deterministic Stage-A through FEB-egress closure.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add 16-hit deterministic infra smoke test.

package tb_int_smoke_test_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_run_window_pkg::*;
    import tb_int_base_test_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_smoke_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_smoke_test)

        virtual mutrig_l2_commit_if stage_a_vif;
        virtual hit_tap_if          pre_rbcam_vif;
        virtual hit_tap_if          post_rbcam_vif;
        virtual hit_tap_if          feb_egress_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual mutrig_l2_commit_if)::get(this, "", "stage_a_vif", stage_a_vif))
                `uvm_fatal("SMOKE", "stage_a_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "pre_rbcam_vif", pre_rbcam_vif))
                `uvm_fatal("SMOKE", "pre_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "post_rbcam_vif", post_rbcam_vif))
                `uvm_fatal("SMOKE", "post_rbcam_vif not configured")
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "feb_egress_vif", feb_egress_vif))
                `uvm_fatal("SMOKE", "feb_egress_vif not configured")
        endfunction

        virtual task run_phase(uvm_phase phase);
            bit [44:0] payload;

            phase.raise_objection(this);
            reset_per_test_delay();
            repeat (8) @(posedge stage_a_vif.clk);

            tb_int_run_window_db::reset();
            tb_int_run_window_db::note_run_start($time);
            tb_int_run_window_db::note_stable_start($time);

            for (int hit_idx = 0; hit_idx < 16; hit_idx++) begin
                payload = build_hit0_payload(4'd8,
                                             5'(hit_idx),
                                             15'(100 + hit_idx),
                                             5'(hit_idx),
                                             15'(200 + hit_idx),
                                             1'b1);
                @(negedge stage_a_vif.clk);
                stage_a_vif.lane_id = 4'd0;
                stage_a_vif.payload = payload;
                stage_a_vif.channel = payload[40:36];
                stage_a_vif.t_coarse = payload[35:21];
                stage_a_vif.t_fine = payload[20:16];
                stage_a_vif.valid = 1'b1;

                pre_rbcam_vif.lane_id = 4'd0;
                pre_rbcam_vif.payload = payload;
                pre_rbcam_vif.hit_id_valid = 1'b0;
                pre_rbcam_vif.root_hit_id_valid = 1'b0;
                pre_rbcam_vif.run_origin = 1'b1;
                pre_rbcam_vif.valid = 1'b1;

                post_rbcam_vif.lane_id = 4'd0;
                post_rbcam_vif.payload = payload;
                post_rbcam_vif.hit_id_valid = 1'b0;
                post_rbcam_vif.root_hit_id_valid = 1'b0;
                post_rbcam_vif.run_origin = 1'b1;
                post_rbcam_vif.valid = 1'b1;

                feb_egress_vif.lane_id = 4'd0;
                feb_egress_vif.payload = payload;
                feb_egress_vif.hit_id_valid = 1'b0;
                feb_egress_vif.root_hit_id_valid = 1'b0;
                feb_egress_vif.run_origin = 1'b1;
                feb_egress_vif.valid = 1'b1;

                @(negedge stage_a_vif.clk);
                stage_a_vif.valid = 1'b0;
                pre_rbcam_vif.valid = 1'b0;
                post_rbcam_vif.valid = 1'b0;
                feb_egress_vif.valid = 1'b0;
            end

            repeat (4) @(posedge stage_a_vif.clk);
            tb_int_run_window_db::note_stable_end($time);
            tb_int_run_window_db::note_run_end($time);
            repeat (8) @(posedge stage_a_vif.clk);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
