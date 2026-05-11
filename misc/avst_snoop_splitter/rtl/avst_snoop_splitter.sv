// avst_snoop_splitter.sv
// Avalon-ST primary path plus nonblocking snoop copy.
//
// Version : 26.0.0
// Date    : 20260502
// Change  : Initial reusable nonblocking snoop splitter.
//
// The input ready follows only out0. out1 is a diagnostic copy and its ready
// input is intentionally ignored, so an unconnected or stalled monitor cannot
// backpressure the observed datapath.

module avst_snoop_splitter #(
    parameter integer DATA_WIDTH    = 36,
    parameter integer CHANNEL_WIDTH = 4,
    parameter integer EMPTY_WIDTH   = 1,
    parameter integer ERROR_WIDTH   = 1
) (
    input  logic                         clk,
    input  logic                         rst,

    input  logic [DATA_WIDTH-1:0]        asi_data,
    input  logic                         asi_valid,
    output logic                         asi_ready,
    input  logic                         asi_startofpacket,
    input  logic                         asi_endofpacket,
    input  logic [EMPTY_WIDTH-1:0]       asi_empty,
    input  logic [CHANNEL_WIDTH-1:0]     asi_channel,
    input  logic [ERROR_WIDTH-1:0]       asi_error,

    output logic [DATA_WIDTH-1:0]        aso_out0_data,
    output logic                         aso_out0_valid,
    input  logic                         aso_out0_ready,
    output logic                         aso_out0_startofpacket,
    output logic                         aso_out0_endofpacket,
    output logic [EMPTY_WIDTH-1:0]       aso_out0_empty,
    output logic [CHANNEL_WIDTH-1:0]     aso_out0_channel,
    output logic [ERROR_WIDTH-1:0]       aso_out0_error,

    output logic [DATA_WIDTH-1:0]        aso_out1_data,
    output logic                         aso_out1_valid,
    input  logic                         aso_out1_ready,
    output logic                         aso_out1_startofpacket,
    output logic                         aso_out1_endofpacket,
    output logic [EMPTY_WIDTH-1:0]       aso_out1_empty,
    output logic [CHANNEL_WIDTH-1:0]     aso_out1_channel,
    output logic [ERROR_WIDTH-1:0]       aso_out1_error
);

    logic unused_inputs;

    always_comb begin : route_stream
        asi_ready              = aso_out0_ready;

        aso_out0_data          = asi_data;
        aso_out0_valid         = asi_valid;
        aso_out0_startofpacket = asi_startofpacket;
        aso_out0_endofpacket   = asi_endofpacket;
        aso_out0_empty         = asi_empty;
        aso_out0_channel       = asi_channel;
        aso_out0_error         = asi_error;

        aso_out1_data          = asi_data;
        aso_out1_valid         = asi_valid;
        aso_out1_startofpacket = asi_startofpacket;
        aso_out1_endofpacket   = asi_endofpacket;
        aso_out1_empty         = asi_empty;
        aso_out1_channel       = asi_channel;
        aso_out1_error         = asi_error;

        unused_inputs          = clk ^ rst ^ aso_out1_ready;
    end

endmodule
