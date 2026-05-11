// tb_int_counter_if.sv
// Optional monitor-counter snapshot bridge for tb_int scoreboards.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260506
// Change  : Add generic counter-agreement interface for integration tops.

interface tb_int_counter_if (
    input logic clk,
    input logic rst
);
    logic available;
    longint unsigned stage_a_count;
    longint unsigned pre_rbcam_count;
    longint unsigned post_rbcam_count;
    longint unsigned feb_egress_count;

    task automatic clear();
        available = 1'b0;
        stage_a_count = 64'd0;
        pre_rbcam_count = 64'd0;
        post_rbcam_count = 64'd0;
        feb_egress_count = 64'd0;
    endtask
endinterface
