// error_rc_026_reset_mid_sc_single_write_seq.sv
// ERROR bucket directed sequence for ERROR-RC-026.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated ERROR case stimulus.

import uvm_pkg::*;
import tb_int_hit_key_pkg::*;
import tb_int_run_window_pkg::*;
`include "uvm_macros.svh"

class error_rc_026_reset_mid_sc_single_write_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(error_rc_026_reset_mid_sc_single_write_seq)

    function new(string name = "error_rc_026_reset_mid_sc_single_write_seq");
        super.new(name);
    endfunction

    task automatic get_stage_vifs(
        output virtual mutrig_l2_commit_if stage_a_vif,
        output virtual hit_tap_if pre_rbcam_vif,
        output virtual hit_tap_if post_rbcam_vif,
        output virtual hit_tap_if feb_egress_vif
    );
        if (!uvm_config_db#(virtual mutrig_l2_commit_if)::get(null, "uvm_test_top", "stage_a_vif", stage_a_vif))
            `uvm_fatal("ERROR_SEQ", "stage_a_vif not configured")
        if (!uvm_config_db#(virtual hit_tap_if)::get(null, "uvm_test_top", "pre_rbcam_vif", pre_rbcam_vif))
            `uvm_fatal("ERROR_SEQ", "pre_rbcam_vif not configured")
        if (!uvm_config_db#(virtual hit_tap_if)::get(null, "uvm_test_top", "post_rbcam_vif", post_rbcam_vif))
            `uvm_fatal("ERROR_SEQ", "post_rbcam_vif not configured")
        if (!uvm_config_db#(virtual hit_tap_if)::get(null, "uvm_test_top", "feb_egress_vif", feb_egress_vif))
            `uvm_fatal("ERROR_SEQ", "feb_egress_vif not configured")
    endtask

    task automatic get_control_vifs(
        output virtual runctl_phy_if runctl_vif,
        output virtual sc_avmm_if sc_vif
    );
        if (!uvm_config_db#(virtual runctl_phy_if)::get(null, "uvm_test_top.env.runctl_phy.drv", "vif", runctl_vif))
            `uvm_fatal("ERROR_SEQ", "runctl_vif not configured")
        if (!uvm_config_db#(virtual sc_avmm_if)::get(null, "uvm_test_top.env.sc_phy.drv", "vif", sc_vif))
            `uvm_fatal("ERROR_SEQ", "sc_vif not configured")
    endtask

    task automatic drive_run_symbol(
        virtual runctl_phy_if runctl_vif,
        bit [8:0] symbol,
        int unsigned hold_cycles
    );
        @(negedge runctl_vif.clk);
        runctl_vif.data = symbol;
        runctl_vif.error = 3'b000;
        runctl_vif.valid = 1'b1;
        repeat (hold_cycles) @(posedge runctl_vif.clk);
        @(negedge runctl_vif.clk);
        runctl_vif.valid = 1'b0;
    endtask

    task automatic drive_truncated_run_symbol(
        virtual runctl_phy_if runctl_vif,
        bit [8:0] symbol
    );
        @(negedge runctl_vif.clk);
        runctl_vif.data = symbol;
        runctl_vif.error = 3'b101;
        runctl_vif.valid = 1'b1;
        @(posedge runctl_vif.clk);
        @(negedge runctl_vif.clk);
        runctl_vif.valid = 1'b0;
        runctl_vif.error = 3'b000;
    endtask

    task automatic drive_sc_access(
        virtual sc_avmm_if sc_vif,
        bit is_write,
        bit [31:0] address,
        bit [31:0] writedata,
        bit [7:0] burstcount,
        int unsigned idle_cycles
    );
        repeat (idle_cycles) @(posedge sc_vif.clk);
        @(negedge sc_vif.clk);
        sc_vif.address = address;
        sc_vif.writedata = writedata;
        sc_vif.byteenable = 4'hf;
        sc_vif.burstcount = burstcount;
        sc_vif.write = is_write;
        sc_vif.read = !is_write;
        repeat (2) @(posedge sc_vif.clk);
        @(negedge sc_vif.clk);
        sc_vif.write = 1'b0;
        sc_vif.read = 1'b0;
        sc_vif.burstcount = 8'd1;
    endtask

    task automatic drive_hit_path(
        virtual mutrig_l2_commit_if stage_a_vif,
        virtual hit_tap_if pre_rbcam_vif,
        virtual hit_tap_if post_rbcam_vif,
        virtual hit_tap_if feb_egress_vif,
        int unsigned pattern,
        int unsigned hit_count
    );
        bit [44:0] payload;
        bit [3:0] lane_id;
        bit [4:0] channel;
        bit drive_pre;
        bit drive_post;
        bit drive_feb;

        for (int unsigned hit_idx = 0; hit_idx < hit_count; hit_idx++) begin
            lane_id = 4'((26 + hit_idx) % 2);
            channel = 5'((14 + hit_idx) % 16);
            if (pattern == 0 && 0 != 0)
                channel = 5'd8;
            payload = build_hit0_payload(4'(8 + lane_id),
                                         channel,
                                         15'(1442 + hit_idx),
                                         5'((2 + hit_idx) % 32),
                                         15'(2442 + hit_idx),
                                         1'b1);
            drive_pre = (pattern != 1);
            drive_post = (pattern != 1) && (pattern != 2);
            drive_feb = (pattern != 1) && (pattern != 2) && (pattern != 3);
            stage_a_vif.drive_commit(lane_id, payload);
            if (drive_pre)
                pre_rbcam_vif.drive_hit(lane_id, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1);
            if (drive_post)
                post_rbcam_vif.drive_hit(lane_id, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1);
            if (drive_feb)
                feb_egress_vif.drive_hit(lane_id, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1);
        end

        if (pattern == 4 || pattern == 5) begin
            payload = build_hit0_payload(4'd8,
                                         5'd8,
                                         15'(1442 + 15'd200),
                                         5'((2 + 17) % 32),
                                         15'(2442 + 15'd200),
                                         1'b1);
            pre_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1);
            post_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1);
            feb_egress_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1);
        end
    endtask

    virtual task body();
        virtual mutrig_l2_commit_if stage_a_vif;
        virtual hit_tap_if pre_rbcam_vif;
        virtual hit_tap_if post_rbcam_vif;
        virtual hit_tap_if feb_egress_vif;
        virtual runctl_phy_if runctl_vif;
        virtual sc_avmm_if sc_vif;

        get_stage_vifs(stage_a_vif, pre_rbcam_vif, post_rbcam_vif, feb_egress_vif);
        get_control_vifs(runctl_vif, sc_vif);
        wait (stage_a_vif.rst === 1'b0);
        repeat (4) @(posedge stage_a_vif.clk);

        `uvm_info("ERROR_CASE", "ERROR-RC-026: RESET issued in the middle of a single SC write", UVM_LOW)
        tb_int_run_window_db::reset();
        drive_run_symbol(runctl_vif, 9'h002, 2);
        if (4 == 3)
            drive_truncated_run_symbol(runctl_vif, 9'(2));
        drive_run_symbol(runctl_vif, 9'h004, 2);
        drive_run_symbol(runctl_vif, 9'h008, 2);
        tb_int_run_window_db::note_run_start($time);
        tb_int_run_window_db::note_stable_start($time);

        if (2 != 0)
            drive_sc_access(sc_vif,
                            1'b0,
                            32'h00000ff0,
                            32'hace0001a,
                            8'(1),
                            1);
        drive_hit_path(stage_a_vif,
                       pre_rbcam_vif,
                       post_rbcam_vif,
                       feb_egress_vif,
                       0,
                       4);
        if (4 == 1)
            drive_run_symbol(runctl_vif, 9'h100, 2);
        if (4 == 2) begin
            drive_run_symbol(runctl_vif, 9'h100, 1);
            drive_run_symbol(runctl_vif, 9'h100, 1);
        end
        if (4 == 4) begin
            drive_sc_access(sc_vif,
                            1'b0,
                            32'h00001068,
                            32'h5a5a001a,
                            8'd2,
                            0);
            drive_run_symbol(runctl_vif, 9'h100, 2);
        end

        repeat (6) @(posedge stage_a_vif.clk);
        tb_int_run_window_db::note_stable_end($time);
        drive_run_symbol(runctl_vif, 9'h010, 2);
        tb_int_run_window_db::note_run_end($time);
        drive_run_symbol(runctl_vif, 9'h001, 2);
        `uvm_info("ERROR_CASE",
                  $sformatf("ERROR-RC-026 expected_syndrome=0x%08h pattern=0 hits=4", 32'h0000401a),
                  UVM_LOW)
        repeat (8) @(posedge stage_a_vif.clk);
    endtask
endclass

module error_rc_026_reset_mid_sc_single_write_seq_factory_anchor;
    uvm_object_wrapper anchor_wrapper = error_rc_026_reset_mid_sc_single_write_seq::type_id::get();
endmodule

bind tb_int_top error_rc_026_reset_mid_sc_single_write_seq_factory_anchor u_error_rc_026_reset_mid_sc_single_write_seq_factory_anchor();
