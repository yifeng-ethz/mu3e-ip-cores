// hit_type0_tap2.sv
// Two-way readyless Avalon-ST hit_type0 tap for direct histogram integration.

module hit_type0_tap2 #(
    parameter int DATA_WIDTH    = 45,
    parameter int CHANNEL_WIDTH = 4,
    parameter int ERROR_WIDTH   = 3
) (
    input  logic                     csi_clk,
    input  logic                     rsi_reset,

    input  logic [DATA_WIDTH-1:0]    asi_in_data,
    input  logic                     asi_in_valid,
    input  logic [ERROR_WIDTH-1:0]   asi_in_error,
    input  logic [CHANNEL_WIDTH-1:0] asi_in_channel,
    input  logic                     asi_in_startofpacket,
    input  logic                     asi_in_endofpacket,
    input  logic                     asi_in_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_primary_data,
    output logic                     aso_primary_valid,
    output logic [ERROR_WIDTH-1:0]   aso_primary_error,
    output logic [CHANNEL_WIDTH-1:0] aso_primary_channel,
    output logic                     aso_primary_startofpacket,
    output logic                     aso_primary_endofpacket,
    output logic                     aso_primary_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_hist_data,
    output logic                     aso_hist_valid,
    output logic [ERROR_WIDTH-1:0]   aso_hist_error,
    output logic [CHANNEL_WIDTH-1:0] aso_hist_channel,
    output logic                     aso_hist_startofpacket,
    output logic                     aso_hist_endofpacket,
    output logic                     aso_hist_endofrun
);

    logic unused_clock_reset;

    always_comb begin : route_hit_type0
        aso_primary_data          = asi_in_data;
        aso_primary_valid         = asi_in_valid;
        aso_primary_error         = asi_in_error;
        aso_primary_channel       = asi_in_channel;
        aso_primary_startofpacket = asi_in_startofpacket;
        aso_primary_endofpacket   = asi_in_endofpacket;
        aso_primary_endofrun      = asi_in_endofrun;

        aso_hist_data             = asi_in_data;
        aso_hist_valid            = asi_in_valid;
        aso_hist_error            = asi_in_error;
        aso_hist_channel          = asi_in_channel;
        aso_hist_startofpacket    = asi_in_startofpacket;
        aso_hist_endofpacket      = asi_in_endofpacket;
        aso_hist_endofrun         = asi_in_endofrun;

        unused_clock_reset        = csi_clk ^ rsi_reset;
    end

endmodule
