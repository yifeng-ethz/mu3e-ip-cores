// lvds_phy_if.sv
// Minimal LVDS PHY boundary abstraction for virtual MuTRiG stimulus.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable LVDS byte-stream interface shell for tb_int.

interface lvds_phy_if (
    input logic clk,
    input logic rst
);
    logic [8:0] data;
    logic       valid;
    logic [3:0] channel;

    task automatic clear();
        data = '0;
        valid = 1'b0;
        channel = '0;
    endtask
endinterface
