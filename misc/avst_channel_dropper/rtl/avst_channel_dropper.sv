// avst_channel_dropper.sv
// Drop Avalon-ST channel sideband while preserving data/valid beats.

module avst_channel_dropper #(
    parameter integer DATA_WIDTH    = 9,
    parameter integer CHANNEL_WIDTH = 1
) (
    input  logic                      clk,
    input  logic                      rst,

    input  logic [DATA_WIDTH-1:0]     asi_data,
    input  logic                      asi_valid,
    output logic                      asi_ready,
    input  logic [CHANNEL_WIDTH-1:0]  asi_channel,

    output logic [DATA_WIDTH-1:0]     aso_data,
    output logic                      aso_valid
);

    logic unused_inputs;

    always_comb begin : drop_channel
        asi_ready     = 1'b1;
        aso_data      = asi_data;
        aso_valid     = asi_valid;
        unused_inputs = clk ^ rst ^ (^asi_channel);
    end

endmodule
