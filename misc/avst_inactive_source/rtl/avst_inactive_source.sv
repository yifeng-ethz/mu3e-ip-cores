// avst_inactive_source.sv
// Constant-valid-low Avalon-ST source used to tie off optional stream sinks.

module avst_inactive_source #(
    parameter integer DATA_WIDTH    = 39,
    parameter integer CHANNEL_WIDTH = 4
) (
    input  logic                     clk,
    input  logic                     rst,

    output logic [DATA_WIDTH-1:0]    aso_data,
    output logic                     aso_valid,
    input  logic                     aso_ready,
    output logic                     aso_startofpacket,
    output logic                     aso_endofpacket,
    output logic [CHANNEL_WIDTH-1:0] aso_channel
);

    logic unused_inputs;

    always_comb begin : drive_inactive
        aso_data          = '0;
        aso_valid         = 1'b0;
        aso_startofpacket = 1'b0;
        aso_endofpacket   = 1'b0;
        aso_channel       = '0;
        unused_inputs     = clk ^ rst ^ aso_ready;
    end

endmodule
