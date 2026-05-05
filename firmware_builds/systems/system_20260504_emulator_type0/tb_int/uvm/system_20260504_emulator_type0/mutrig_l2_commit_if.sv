// mutrig_l2_commit_if.sv
// Focus-build L2 FIFO commit probe interface.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add interface for be_mutrig_lane_emitter pending_valid/l2_wr_ready.

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

    task automatic clear();
        valid = 1'b0;
        payload = '0;
        lane_id = '0;
        channel = '0;
        t_coarse = '0;
        t_fine = '0;
    endtask

    task automatic drive_commit(
        input logic [3:0]  drive_lane_id,
        input logic [44:0] drive_payload
    );
        @(negedge clk);
        lane_id = drive_lane_id;
        payload = drive_payload;
        channel = drive_payload[40:36];
        t_coarse = drive_payload[35:21];
        t_fine = drive_payload[20:16];
        valid = 1'b1;
        @(negedge clk);
        valid = 1'b0;
    endtask
endinterface
