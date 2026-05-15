// frontend_run_ctl.sv
// Run-control decode and inject-pulse merge for emulator_mutrig.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add frontend run-control contract.

module frontend_run_ctl (
    input  logic       i_clk,
    input  logic       i_rst,

    input  logic [8:0] asi_ctrl_data,
    input  logic       asi_ctrl_valid,
    output logic       asi_ctrl_ready,

    input  logic       coe_inject_pulse,
    input  logic       fire_inject_pulse_csr,

    output logic       run_generating,
    output logic       run_draining,
    output logic       emu_rst,
    output logic       frame_rst,
    output logic       inject_pulse,
    output logic [8:0] ctrl_state_q
);

    logic coe_inject_d1;
    logic coe_inject_d2;
    logic coe_inject_edge;

    assign asi_ctrl_ready  = 1'b1;
    assign run_generating  = ctrl_state_q[3];
    assign run_draining    = ctrl_state_q[3] | ctrl_state_q[4];
    assign emu_rst         = i_rst | (asi_ctrl_valid & (asi_ctrl_data[2] | asi_ctrl_data[7]));
    assign frame_rst       = emu_rst | ~run_draining;
    assign coe_inject_edge = coe_inject_d1 & ~coe_inject_d2;
    assign inject_pulse    = coe_inject_edge | fire_inject_pulse_csr;

    always_ff @(posedge i_clk) begin : state_latch
        if (i_rst) begin
            ctrl_state_q <= 9'b0_0000_0001;
        end else if (asi_ctrl_valid) begin
            ctrl_state_q <= asi_ctrl_data;
        end
    end

    always_ff @(posedge i_clk) begin : inject_sync
        if (i_rst) begin
            coe_inject_d1    <= 1'b0;
            coe_inject_d2    <= 1'b0;
        end else begin
            coe_inject_d1    <= coe_inject_pulse;
            coe_inject_d2    <= coe_inject_d1;
        end
    end

endmodule
