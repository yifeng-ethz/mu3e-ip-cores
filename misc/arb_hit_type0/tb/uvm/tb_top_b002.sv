// tb_top_b002.sv
//
// Standalone simulation top for B002 nested-splitter run-control
// propagation repro.  Instantiates:
//   - Three altera_avalon_st_splitter_model stages (16-out → 2-out → 8-out)
//     wired in series to match the silicon topology.
//   - One arb_hit_type0 DUT whose asi_ctrl_* input is driven from the
//     leaf output of the 8-way splitter (output index 0).
//
// The UVM test R016_nested_splitter_runctl_propagation_test is elaborated
// with this top.  It drives the splitter input via uvm_hdl_force and
// observes the DUT's internal run_state via uvm_hdl_read.
//
// Only the run-control path is exercised; hit-data inputs are tied to zero.
// The CSR bus and egress port are left floating (unused in this repro).

`timescale 1ns/1ps

module tb_top_b002;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ------------------------------------------------------------------ //
    //  Clock / reset                                                       //
    // ------------------------------------------------------------------ //
    localparam int CLK_PERIOD_NS = 8;

    logic clk;
    logic rst;

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS / 2) clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        repeat (16) @(posedge clk);
        rst = 1'b0;
    end

    // ------------------------------------------------------------------ //
    //  Splitter chain input (driven by the test via uvm_hdl_force)         //
    // ------------------------------------------------------------------ //
    logic [8:0] splitter_in_data;
    logic       splitter_in_valid;
    logic       splitter_in_ready;  // tied 1 by model

    // ------------------------------------------------------------------ //
    //  Stage 1: 16-output splitter (models run_control_splitter)           //
    // ------------------------------------------------------------------ //
    logic [15:0][8:0] stage1_out_data;
    logic [15:0]      stage1_out_valid;

    altera_avalon_st_splitter_model #(
        .N_OUTPUTS  (16),
        .DATA_WIDTH (9)
    ) u_splitter_stage1 (
        .in_data   (splitter_in_data),
        .in_valid  (splitter_in_valid),
        .in_ready  (splitter_in_ready),
        .out_data  (stage1_out_data),
        .out_valid (stage1_out_valid)
    );

    // ------------------------------------------------------------------ //
    //  Stage 2: 2-output splitter (models type0_run_ctrl_splitter)         //
    //  Fed from stage1 output 2 (matching .out2 in the silicon topology)   //
    // ------------------------------------------------------------------ //
    logic [1:0][8:0] stage2_out_data;
    logic [1:0]      stage2_out_valid;

    altera_avalon_st_splitter_model #(
        .N_OUTPUTS  (2),
        .DATA_WIDTH (9)
    ) u_splitter_stage2 (
        .in_data   (stage1_out_data[2]),
        .in_valid  (stage1_out_valid[2]),
        .in_ready  (/* floating – USE_READY=0 */),
        .out_data  (stage2_out_data),
        .out_valid (stage2_out_valid)
    );

    // ------------------------------------------------------------------ //
    //  Stage 3: 8-output splitter (models supercore-internal              //
    //           run_ctrl_splitter driving each lane's run_ctrl input)      //
    //  Fed from stage2 output 0 (matching .out0 in the silicon topology)   //
    // ------------------------------------------------------------------ //
    logic [7:0][8:0] stage3_out_data;
    logic [7:0]      stage3_out_valid;

    altera_avalon_st_splitter_model #(
        .N_OUTPUTS  (8),
        .DATA_WIDTH (9)
    ) u_splitter_stage3 (
        .in_data   (stage2_out_data[0]),
        .in_valid  (stage2_out_valid[0]),
        .in_ready  (/* floating – USE_READY=0 */),
        .out_data  (stage3_out_data),
        .out_valid (stage3_out_valid)
    );

    // ------------------------------------------------------------------ //
    //  DUT: arb_hit_type0 driven by leaf output 0 of stage3               //
    //  (models arb_hit_type0_supercore lane 0)                             //
    // ------------------------------------------------------------------ //

    // Tie off unused hit-data inputs.
    logic [44:0] asi_real_data_tied;
    logic [44:0] asi_emu_data_tied;
    assign asi_real_data_tied = 45'd0;
    assign asi_emu_data_tied  = 45'd0;

    // CSR inputs (unused in this repro – address decoding not exercised)
    logic [4:0]  csr_address;
    logic        csr_write;
    logic        csr_read;
    logic [31:0] csr_writedata;
    logic [31:0] csr_readdata;
    logic        csr_waitrequest;

    assign csr_address   = 5'd0;
    assign csr_write     = 1'b0;
    assign csr_read      = 1'b0;
    assign csr_writedata = 32'd0;

    // DUT ctrl ready (should be 1'b1 per arb_hit_type0_runctl.sv:59)
    logic dut_ctrl_ready;

    arb_hit_type0 dut_b002 (
        .clk                        (clk),
        .rst                        (rst),

        .avs_csr_address            (csr_address),
        .avs_csr_write              (csr_write),
        .avs_csr_read               (csr_read),
        .avs_csr_writedata          (csr_writedata),
        .avs_csr_readdata           (csr_readdata),
        .avs_csr_waitrequest        (csr_waitrequest),

        .asi_ctrl_data              (stage3_out_data[0]),
        .asi_ctrl_valid             (stage3_out_valid[0]),
        .asi_ctrl_ready             (dut_ctrl_ready),

        .asi_real_data              (asi_real_data_tied),
        .asi_real_valid             (1'b0),
        .asi_real_error             (3'b0),
        .asi_real_channel           (4'b0),
        .asi_real_startofpacket     (1'b0),
        .asi_real_endofpacket       (1'b0),
        .asi_real_endofrun          (1'b0),

        .asi_emu_data               (asi_emu_data_tied),
        .asi_emu_valid              (1'b0),
        .asi_emu_error              (3'b0),
        .asi_emu_channel            (4'b0),
        .asi_emu_startofpacket      (1'b0),
        .asi_emu_endofpacket        (1'b0),
        .asi_emu_endofrun           (1'b0),

        .aso_data                   (/* floating */),
        .aso_valid                  (/* floating */),
        .aso_error                  (/* floating */),
        .aso_channel                (/* floating */),
        .aso_startofpacket          (/* floating */),
        .aso_endofpacket            (/* floating */),
        .aso_endofrun               (/* floating */)
    );

    // ------------------------------------------------------------------ //
    //  UVM startup                                                         //
    // ------------------------------------------------------------------ //
    initial begin
        splitter_in_data  = 9'd0;
        splitter_in_valid = 1'b0;
        run_test();
    end

endmodule
