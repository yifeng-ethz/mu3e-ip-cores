// debug_fill_if.sv
// Generic DEBUG_LEVEL=1 fill/status conduit observation interface.

interface debug_fill_if #(
    parameter int unsigned DATA_W = 32
) (
    input logic clk,
    input logic rst
);
    logic                  valid;
    logic [DATA_W-1:0]     data;

    task automatic clear();
        valid = 1'b0;
        data  = '0;
    endtask

    task automatic drive_sample(input logic [DATA_W-1:0] drive_data);
        @(negedge clk);
        data  = drive_data;
        valid = 1'b1;
        @(negedge clk);
        valid = 1'b0;
    endtask
endinterface
