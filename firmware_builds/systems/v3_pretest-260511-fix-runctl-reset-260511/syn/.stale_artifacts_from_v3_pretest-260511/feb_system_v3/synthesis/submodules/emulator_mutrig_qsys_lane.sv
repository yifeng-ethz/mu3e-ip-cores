// emulator_mutrig_qsys_lane.sv
// Scalar Platform Designer wrapper for one lane of the rewritten MuTRiG
// emulator.  The internal emulator can generate multiple lanes, but the
// current FE SciFi Qsys system instantiates one emulator per lane and needs
// scalar Avalon-ST interfaces.

module emulator_mutrig_qsys_lane #(
    parameter int FIFO_DEPTH = 64,
    parameter int CSR_ADDR_WIDTH = 4,
    parameter logic [3:0] ASIC_ID_DEFAULT = 4'd0,
    parameter logic CLUSTER_CROSS_ASIC_DEFAULT = 1'b0,
    parameter logic [7:0] CLUSTER_CENTER_GLOBAL_DEFAULT = 8'd16,
    parameter logic [3:0] CLUSTER_LANE_INDEX_DEFAULT = 4'd0,
    parameter logic [3:0] CLUSTER_LANE_COUNT_DEFAULT = 4'd1,
    parameter bit BYTE_STREAM_ENABLE = 1'b0,
    parameter logic [31:0] IP_UID = 32'h454D_5554,
    parameter int VERSION_MAJOR = 26,
    parameter int VERSION_MINOR = 3,
    parameter int VERSION_PATCH = 0,
    parameter int BUILD = 506,
    parameter int VERSION_DATE = 20260506,
    parameter logic [31:0] VERSION_GIT = 32'h0000_0000,
    parameter logic [31:0] INSTANCE_ID = 32'h0000_0000,
    parameter int DEBUG_LEVEL = 0
) (
    input  logic        i_clk,
    input  logic        i_rst,

    output logic [44:0] aso_hit_type0_data,
    output logic        aso_hit_type0_valid,
    output logic [2:0]  aso_hit_type0_error,
    output logic [3:0]  aso_hit_type0_channel,
    output logic        aso_hit_type0_startofpacket,
    output logic        aso_hit_type0_endofpacket,
    output logic        aso_hit_type0_endofrun,
    output logic [15:0] coe_debug_fifo_fill_level,
    output logic [63:0] coe_debug_hit_metadata,
    output logic        coe_debug_hit_metadata_valid,
    output logic [63:0] aso_hit_debug_data,
    output logic        aso_hit_debug_valid,
    output logic [3:0]  aso_hit_debug_channel,
    output logic        aso_hit_debug_startofpacket,
    output logic        aso_hit_debug_endofpacket,
    output logic        aso_hit_debug_endofrun,

    output logic [8:0]  aso_tx8b1k_data,
    output logic        aso_tx8b1k_valid,
    output logic [3:0]  aso_tx8b1k_channel,
    output logic [2:0]  aso_tx8b1k_error,

    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    output logic        asi_ctrl_ready,

    input  logic        coe_inject_pulse,
    input  logic        coe_inject_masked_pulse,

    input  logic [CSR_ADDR_WIDTH-1:0] avs_csr_address,
    input  logic        avs_csr_read,
    input  logic        avs_csr_write,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest
);

    logic [0:0][44:0] hit_type0_data;
    logic [0:0]       hit_type0_valid;
    logic [0:0]       hit_type0_startofpacket;
    logic [0:0]       hit_type0_endofpacket;
    logic [0:0]       hit_type0_endofrun;
    logic [0:0][2:0]  hit_type0_error;
    logic [0:0][3:0]  hit_type0_channel;
    logic [0:0][15:0] debug_fifo_fill_level;
    logic [0:0][63:0] hit_debug_data;
    logic [0:0]       hit_debug_valid;
    logic [0:0][3:0]  hit_debug_channel;
    logic [0:0]       hit_debug_startofpacket;
    logic [0:0]       hit_debug_endofpacket;
    logic [0:0]       hit_debug_endofrun;
    logic [0:0][8:0]  tx8b1k_data;
    logic [0:0]       tx8b1k_valid;
    logic [0:0][2:0]  tx8b1k_error;
    logic [0:0][3:0]  tx8b1k_channel;

    logic [5:0] csr_address_extended;

    generate
        if (CSR_ADDR_WIDTH >= 6) begin : csr_addr_truncate_gen
            assign csr_address_extended = avs_csr_address[5:0];
        end else begin : csr_addr_extend_gen
            assign csr_address_extended = {{(6 - CSR_ADDR_WIDTH){1'b0}}, avs_csr_address};
        end
    endgenerate

    assign aso_hit_type0_data = hit_type0_data[0];
    assign aso_hit_type0_valid = hit_type0_valid[0];
    assign aso_hit_type0_startofpacket = hit_type0_startofpacket[0];
    assign aso_hit_type0_endofpacket = hit_type0_endofpacket[0];
    assign aso_hit_type0_endofrun = hit_type0_endofrun[0];
    assign aso_hit_type0_error = hit_type0_error[0];
    assign aso_hit_type0_channel = hit_type0_channel[0];
    assign coe_debug_fifo_fill_level = debug_fifo_fill_level[0];
    assign coe_debug_hit_metadata = hit_debug_data[0];
    assign coe_debug_hit_metadata_valid = hit_debug_valid[0];
    assign aso_hit_debug_data = hit_debug_data[0];
    assign aso_hit_debug_valid = hit_debug_valid[0];
    assign aso_hit_debug_channel = hit_debug_channel[0];
    assign aso_hit_debug_startofpacket = hit_debug_startofpacket[0];
    assign aso_hit_debug_endofpacket = hit_debug_endofpacket[0];
    assign aso_hit_debug_endofrun = hit_debug_endofrun[0];
    assign aso_tx8b1k_data = tx8b1k_data[0];
    assign aso_tx8b1k_valid = tx8b1k_valid[0];
    assign aso_tx8b1k_error = tx8b1k_error[0];
    assign aso_tx8b1k_channel = tx8b1k_channel[0];

    emulator_mutrig #(
        .LANE_COUNT(1),
        .BYTE_STREAM_ENABLE(BYTE_STREAM_ENABLE),
        .IP_UID(IP_UID),
        .VERSION_MAJOR(VERSION_MAJOR),
        .VERSION_MINOR(VERSION_MINOR),
        .VERSION_PATCH(VERSION_PATCH),
        .BUILD(BUILD),
        .VERSION_DATE(VERSION_DATE),
        .VERSION_GIT(VERSION_GIT),
        .INSTANCE_ID(INSTANCE_ID),
        .ASIC_ID_BASE_DEFAULT(ASIC_ID_DEFAULT),
        .DEBUG_LEVEL(DEBUG_LEVEL)
    ) u_emulator_mutrig (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .asi_ctrl_data(asi_ctrl_data),
        .asi_ctrl_valid(asi_ctrl_valid),
        .asi_ctrl_ready(asi_ctrl_ready),
        .coe_inject_pulse(coe_inject_pulse | coe_inject_masked_pulse),
        .avs_csr_address(csr_address_extended),
        .avs_csr_read(avs_csr_read),
        .avs_csr_write(avs_csr_write),
        .avs_csr_writedata(avs_csr_writedata),
        .avs_csr_readdata(avs_csr_readdata),
        .avs_csr_waitrequest(avs_csr_waitrequest),
        .aso_hit_type0_data(hit_type0_data),
        .aso_hit_type0_valid(hit_type0_valid),
        .aso_hit_type0_startofpacket(hit_type0_startofpacket),
        .aso_hit_type0_endofpacket(hit_type0_endofpacket),
        .aso_hit_type0_endofrun(hit_type0_endofrun),
        .aso_hit_type0_error(hit_type0_error),
        .aso_hit_type0_channel(hit_type0_channel),
        .coe_debug_fifo_fill_level(debug_fifo_fill_level),
        .aso_hit_debug_data(hit_debug_data),
        .aso_hit_debug_valid(hit_debug_valid),
        .aso_hit_debug_channel(hit_debug_channel),
        .aso_hit_debug_startofpacket(hit_debug_startofpacket),
        .aso_hit_debug_endofpacket(hit_debug_endofpacket),
        .aso_hit_debug_endofrun(hit_debug_endofrun),
        .aso_tx8b1k_data(tx8b1k_data),
        .aso_tx8b1k_valid(tx8b1k_valid),
        .aso_tx8b1k_error(tx8b1k_error),
        .aso_tx8b1k_channel(tx8b1k_channel)
    );

endmodule
