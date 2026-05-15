// hit_tap_if.sv
// Generic synchronous hit observation tap used by passive stage monitors.
// Author: Yifeng Wang
// Version : 26.2.1
// Date    : 20260504
// Change  : Keep optional debug lineage fields available for exact hit tracking.

interface hit_tap_if (
    input logic clk,
    input logic rst
);
    logic        valid;
    logic        ready;
    logic [3:0]  lane_id;
    logic [44:0] payload;
    logic [63:0] hit_id;
    logic        hit_id_valid;
    logic [63:0] root_hit_id;
    logic        root_hit_id_valid;
    logic [47:0] true_hit_ts;
    logic        true_hit_ts_valid;
    logic        run_origin;
    logic [1:0]  debug_level;

    task automatic clear();
        valid = 1'b0;
        ready = 1'b1;
        lane_id = '0;
        payload = '0;
        hit_id = '0;
        hit_id_valid = 1'b0;
        root_hit_id = '0;
        root_hit_id_valid = 1'b0;
        true_hit_ts = '0;
        true_hit_ts_valid = 1'b0;
        run_origin = 1'b0;
        debug_level = 2'd0;
    endtask

    task automatic drive_hit(
        input logic [3:0]  drive_lane_id,
        input logic [44:0] drive_payload,
        input logic [63:0] drive_hit_id,
        input logic        drive_hit_id_valid,
        input logic [63:0] drive_root_hit_id,
        input logic        drive_root_hit_id_valid,
        input logic        drive_run_origin,
        input logic [1:0]  drive_debug_level = 2'd0,
        input logic [47:0] drive_true_hit_ts = 48'd0,
        input logic        drive_true_hit_ts_valid = 1'b0
    );
        @(negedge clk);
        lane_id = drive_lane_id;
        payload = drive_payload;
        hit_id = drive_hit_id;
        hit_id_valid = drive_hit_id_valid;
        root_hit_id = drive_root_hit_id;
        root_hit_id_valid = drive_root_hit_id_valid;
        true_hit_ts = drive_true_hit_ts;
        true_hit_ts_valid = drive_true_hit_ts_valid;
        run_origin = drive_run_origin;
        debug_level = drive_debug_level;
        valid = 1'b1;
        @(negedge clk);
        valid = 1'b0;
    endtask
endinterface
