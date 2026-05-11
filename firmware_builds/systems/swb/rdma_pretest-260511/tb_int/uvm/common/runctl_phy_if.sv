// runctl_phy_if.sv
// Synclink Avalon-ST 9-bit run-control PHY abstraction.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable run-control PHY interface shell for tb_int.

interface runctl_phy_if (
    input logic clk,
    input logic rst
);
    logic [8:0] data;
    logic       valid;
    logic [2:0] error;

    task automatic clear();
        data = '0;
        valid = 1'b0;
        error = '0;
    endtask
endinterface
