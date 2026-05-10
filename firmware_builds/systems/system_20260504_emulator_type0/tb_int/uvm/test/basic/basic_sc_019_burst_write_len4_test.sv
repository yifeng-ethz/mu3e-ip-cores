// basic_sc_019_burst_write_len4_test.sv
// BASIC bucket test wrapper for BASIC-SC-019.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated BASIC case test.

`ifndef BASIC_SC_019_BURST_WRITE_LEN4_TEST_SV
`define BASIC_SC_019_BURST_WRITE_LEN4_TEST_SV

import uvm_pkg::*;
import tb_int_hit_key_pkg::*;
import tb_int_run_window_pkg::*;
import tb_int_env_pkg::*;
import tb_int_base_test_pkg::*;
import tb_int_smoke_test_pkg::*;
`include "uvm_macros.svh"

class basic_sc_019_burst_write_len4_test extends tb_int_smoke_test;
    `uvm_component_utils(basic_sc_019_burst_write_len4_test)

    localparam string CASE_ID = "BASIC-SC-019";
    localparam string CASE_SEQUENCE = "basic_sc_019_burst_write_len4_seq";
    localparam string CASE_SUMMARY = "Burst write length 4 to consecutive RW fields";
    localparam int unsigned HIT_COUNT = 2;
    localparam int unsigned CHANNEL_BASE = 6;
    localparam int unsigned CHANNEL_SPAN = 8;
    localparam int unsigned CHANNEL_STRIDE = 2;
    localparam int unsigned FINE_BASE = 19;
    localparam int unsigned FINE_STRIDE = 5;
    localparam int unsigned HIT_GAP_CYCLES = 3;
    localparam bit [3:0] ASIC_ID = 4'd8;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_case_sequence();
        uvm_object obj;
        uvm_sequence_base seq;

        obj = uvm_factory::get().create_object_by_name(CASE_SEQUENCE,
                                                        get_full_name(),
                                                        "case_seq");
        if (obj == null) begin
            `uvm_info("BASIC_TEST",
                      $sformatf("%s sequence %s is not registered", CASE_ID, CASE_SEQUENCE),
                      UVM_LOW)
            return;
        end
        if (!$cast(seq, obj)) begin
            `uvm_info("BASIC_TEST",
                      $sformatf("%s factory object is not a uvm_sequence", CASE_ID),
                      UVM_LOW)
            return;
        end
        seq.start(null);
    endtask

    function automatic bit [4:0] case_channel(int unsigned hit_idx);
        int unsigned raw_channel;

        raw_channel = CHANNEL_BASE + ((hit_idx * CHANNEL_STRIDE) % CHANNEL_SPAN);
        return 5'(raw_channel % 32);
    endfunction

    function automatic bit [4:0] case_t_fine(int unsigned hit_idx);
        int unsigned raw_fine;

        raw_fine = FINE_BASE + (hit_idx * FINE_STRIDE);
        return 5'(raw_fine % 32);
    endfunction

    virtual task drive_case_hit(int unsigned hit_idx);
        bit [44:0] payload;

        payload = build_hit0_payload(ASIC_ID,
                                     case_channel(hit_idx),
                                     15'(100 + hit_idx),
                                     case_t_fine(hit_idx),
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
    endtask

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        reset_per_test_delay();
        run_case_sequence();
        env.scoreboard.expected_closed_records = HIT_COUNT;
        `uvm_info("BASIC_TEST",
                  $sformatf("%s: %s", CASE_ID, CASE_SUMMARY),
                  UVM_LOW)
        repeat (8) @(posedge stage_a_vif.clk);

        tb_int_run_window_db::reset();
        tb_int_run_window_db::note_run_start($time);
        tb_int_run_window_db::note_stable_start($time);

        for (int unsigned hit_idx = 0; hit_idx < HIT_COUNT; hit_idx++) begin
            drive_case_hit(hit_idx);
            repeat (HIT_GAP_CYCLES) @(posedge stage_a_vif.clk);
        end

        repeat (4) @(posedge stage_a_vif.clk);
        tb_int_run_window_db::note_stable_end($time);
        tb_int_run_window_db::note_run_end($time);
        repeat (8) @(posedge stage_a_vif.clk);
        $display("*** TEST PASSED ***");
        phase.drop_objection(this);
    endtask
endclass


`endif
