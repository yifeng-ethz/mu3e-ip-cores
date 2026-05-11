// sc_avmm_if.sv
// Avalon-MM slow-control master interface used by sc_phy_agent.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable slow-control AVMM interface shell for tb_int.

interface sc_avmm_if (
    input logic clk,
    input logic rst
);
    logic [31:0] address;
    logic [31:0] writedata;
    logic [31:0] readdata;
    logic        write;
    logic        read;
    logic        waitrequest;
    logic        readdatavalid;
    logic [3:0]  byteenable;
    logic [7:0]  burstcount;

    task automatic clear_master();
        address = '0;
        writedata = '0;
        write = 1'b0;
        read = 1'b0;
        byteenable = 4'hf;
        burstcount = 8'd1;
    endtask
endinterface
