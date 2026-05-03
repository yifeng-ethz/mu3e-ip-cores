`timescale 1ns/1ps

`ifndef MLSM_REAL_ALWAYS_VALID
`define MLSM_REAL_ALWAYS_VALID 1
`endif

`ifndef MLSM_FIFO_DEPTH
`define MLSM_FIFO_DEPTH 16
`endif

module mlsm_downstream_input_probe (
    input  logic        clk,
    input  logic        rst,
    input  logic        clear,
    input  logic [8:0]  aso_data,
    input  logic        aso_valid,
    input  logic [2:0]  aso_error,
    input  logic [3:0]  aso_channel,
    output logic [31:0] valid_count,
    output logic [8:0]  last_data,
    output logic [2:0]  last_error,
    output logic [3:0]  last_channel
);
    always_ff @(posedge clk or posedge rst or posedge clear) begin : probe_reg
        if (rst || clear) begin
            valid_count     <= 32'd0;
            last_data       <= 9'd0;
            last_error      <= 3'd0;
            last_channel    <= 4'd0;
        end else if (aso_valid) begin
            valid_count     <= valid_count + 32'd1;
            last_data       <= aso_data;
            last_error      <= aso_error;
            last_channel    <= aso_channel;
        end
    end
endmodule

module tb_top;
    import uvm_pkg::*;
    import mlsm_env_pkg::*;

    localparam int REAL_ALWAYS_VALID_CONST = `MLSM_REAL_ALWAYS_VALID;
    localparam int FIFO_DEPTH_CONST        = `MLSM_FIFO_DEPTH;

    logic clk = 1'b0;

    always #4 clk = ~clk;

    mlsm_if mif(clk);

    mutrig_lane_source_mux #(
        .SELECT_EMULATOR(0),
        .FIFO_DEPTH(FIFO_DEPTH_CONST),
        .REAL_ALWAYS_VALID(REAL_ALWAYS_VALID_CONST),
        .VERSION_PATCH(1),
        .BUILD(503),
        .VERSION_DATE(20260503),
        .INSTANCE_ID(16'h51A0)
    ) dut (
        .clk(clk),
        .rst(mif.rst),
        .avs_csr_address(mif.avs_csr_address),
        .avs_csr_write(mif.avs_csr_write),
        .avs_csr_read(mif.avs_csr_read),
        .avs_csr_writedata(mif.avs_csr_writedata),
        .avs_csr_readdata(mif.avs_csr_readdata),
        .avs_csr_waitrequest(mif.avs_csr_waitrequest),
        .asi_real_data(mif.asi_real_data),
        .asi_real_valid(mif.asi_real_valid),
        .asi_real_error(mif.asi_real_error),
        .asi_real_channel(mif.asi_real_channel),
        .asi_emu_data(mif.asi_emu_data),
        .asi_emu_valid(mif.asi_emu_valid),
        .asi_emu_error(mif.asi_emu_error),
        .asi_emu_channel(mif.asi_emu_channel),
        .aso_data(mif.aso_data),
        .aso_valid(mif.aso_valid),
        .aso_error(mif.aso_error),
        .aso_channel(mif.aso_channel)
    );

    mlsm_downstream_input_probe probe (
        .clk(clk),
        .rst(mif.rst),
        .clear(mif.probe_clear),
        .aso_data(mif.aso_data),
        .aso_valid(mif.aso_valid),
        .aso_error(mif.aso_error),
        .aso_channel(mif.aso_channel),
        .valid_count(mif.probe_valid_count),
        .last_data(mif.probe_last_data),
        .last_error(mif.probe_last_error),
        .last_channel(mif.probe_last_channel)
    );

    initial begin : uvm_boot
        uvm_config_db#(virtual mlsm_if)::set(null, "*", "vif", mif);
        uvm_config_db#(int)::set(null, "*", "real_always_valid", REAL_ALWAYS_VALID_CONST);
        uvm_config_db#(int)::set(null, "*", "fifo_depth", FIFO_DEPTH_CONST);
        run_test();
    end
endmodule
