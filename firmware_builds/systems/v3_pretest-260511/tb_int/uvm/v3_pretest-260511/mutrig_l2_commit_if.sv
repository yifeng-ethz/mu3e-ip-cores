// mutrig_l2_commit_if.sv
// v3_pretest L2 FIFO commit probe interface.

interface mutrig_l2_commit_if (
    input logic clk,
    input logic rst
);
    logic        valid;
    logic [44:0] payload;
    logic [3:0]  lane_id;
    logic [4:0]  channel;
    logic [14:0] t_coarse;
    logic [4:0]  t_fine;
    logic [63:0] hit_id;
    logic        hit_id_valid;
    logic [63:0] root_hit_id;
    logic        root_hit_id_valid;
    logic [1:0]  debug_level;

    task automatic clear();
        valid = 1'b0;
        payload = '0;
        lane_id = '0;
        channel = '0;
        t_coarse = '0;
        t_fine = '0;
        hit_id = '0;
        hit_id_valid = 1'b0;
        root_hit_id = '0;
        root_hit_id_valid = 1'b0;
        debug_level = 2'd0;
    endtask

    task automatic drive_commit(
        input logic [3:0]  drive_lane_id,
        input logic [44:0] drive_payload,
        input logic [63:0] drive_hit_id = 64'd0,
        input logic        drive_hit_id_valid = 1'b0,
        input logic [63:0] drive_root_hit_id = 64'd0,
        input logic        drive_root_hit_id_valid = 1'b0,
        input logic [1:0]  drive_debug_level = 2'd0
    );
        @(negedge clk);
        lane_id = drive_lane_id;
        payload = drive_payload;
        channel = drive_payload[40:36];
        t_coarse = drive_payload[35:21];
        t_fine = drive_payload[20:16];
        hit_id = drive_hit_id;
        hit_id_valid = drive_hit_id_valid;
        root_hit_id = drive_root_hit_id;
        root_hit_id_valid = drive_root_hit_id_valid;
        debug_level = drive_debug_level;
        valid = 1'b1;
        @(negedge clk);
        valid = 1'b0;
    endtask
endinterface
