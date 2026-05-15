// hit_type0_fanout8.sv
// Eight-way Avalon-ST hit_type0 fanout for the FEB v3 emulator-type0 build.
//
// Version : 26.0.0
// Date    : 20260512
// Change  : Readyless build-local fanout that preserves hit_type0 endofrun.

module hit_type0_fanout8 #(
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

    output logic [DATA_WIDTH-1:0]    aso_out0_data,
    output logic                     aso_out0_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out0_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out0_channel,
    output logic                     aso_out0_startofpacket,
    output logic                     aso_out0_endofpacket,
    output logic                     aso_out0_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_out1_data,
    output logic                     aso_out1_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out1_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out1_channel,
    output logic                     aso_out1_startofpacket,
    output logic                     aso_out1_endofpacket,
    output logic                     aso_out1_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_out2_data,
    output logic                     aso_out2_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out2_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out2_channel,
    output logic                     aso_out2_startofpacket,
    output logic                     aso_out2_endofpacket,
    output logic                     aso_out2_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_out3_data,
    output logic                     aso_out3_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out3_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out3_channel,
    output logic                     aso_out3_startofpacket,
    output logic                     aso_out3_endofpacket,
    output logic                     aso_out3_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_out4_data,
    output logic                     aso_out4_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out4_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out4_channel,
    output logic                     aso_out4_startofpacket,
    output logic                     aso_out4_endofpacket,
    output logic                     aso_out4_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_out5_data,
    output logic                     aso_out5_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out5_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out5_channel,
    output logic                     aso_out5_startofpacket,
    output logic                     aso_out5_endofpacket,
    output logic                     aso_out5_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_out6_data,
    output logic                     aso_out6_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out6_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out6_channel,
    output logic                     aso_out6_startofpacket,
    output logic                     aso_out6_endofpacket,
    output logic                     aso_out6_endofrun,

    output logic [DATA_WIDTH-1:0]    aso_out7_data,
    output logic                     aso_out7_valid,
    output logic [ERROR_WIDTH-1:0]   aso_out7_error,
    output logic [CHANNEL_WIDTH-1:0] aso_out7_channel,
    output logic                     aso_out7_startofpacket,
    output logic                     aso_out7_endofpacket,
    output logic                     aso_out7_endofrun
);

    logic unused_clock_reset;

    always_comb begin : route_hit_type0
        aso_out0_data          = asi_in_data;
        aso_out0_valid         = asi_in_valid;
        aso_out0_error         = asi_in_error;
        aso_out0_channel       = asi_in_channel;
        aso_out0_startofpacket = asi_in_startofpacket;
        aso_out0_endofpacket   = asi_in_endofpacket;
        aso_out0_endofrun      = asi_in_endofrun;

        aso_out1_data          = asi_in_data;
        aso_out1_valid         = asi_in_valid;
        aso_out1_error         = asi_in_error;
        aso_out1_channel       = asi_in_channel;
        aso_out1_startofpacket = asi_in_startofpacket;
        aso_out1_endofpacket   = asi_in_endofpacket;
        aso_out1_endofrun      = asi_in_endofrun;

        aso_out2_data          = asi_in_data;
        aso_out2_valid         = asi_in_valid;
        aso_out2_error         = asi_in_error;
        aso_out2_channel       = asi_in_channel;
        aso_out2_startofpacket = asi_in_startofpacket;
        aso_out2_endofpacket   = asi_in_endofpacket;
        aso_out2_endofrun      = asi_in_endofrun;

        aso_out3_data          = asi_in_data;
        aso_out3_valid         = asi_in_valid;
        aso_out3_error         = asi_in_error;
        aso_out3_channel       = asi_in_channel;
        aso_out3_startofpacket = asi_in_startofpacket;
        aso_out3_endofpacket   = asi_in_endofpacket;
        aso_out3_endofrun      = asi_in_endofrun;

        aso_out4_data          = asi_in_data;
        aso_out4_valid         = asi_in_valid;
        aso_out4_error         = asi_in_error;
        aso_out4_channel       = asi_in_channel;
        aso_out4_startofpacket = asi_in_startofpacket;
        aso_out4_endofpacket   = asi_in_endofpacket;
        aso_out4_endofrun      = asi_in_endofrun;

        aso_out5_data          = asi_in_data;
        aso_out5_valid         = asi_in_valid;
        aso_out5_error         = asi_in_error;
        aso_out5_channel       = asi_in_channel;
        aso_out5_startofpacket = asi_in_startofpacket;
        aso_out5_endofpacket   = asi_in_endofpacket;
        aso_out5_endofrun      = asi_in_endofrun;

        aso_out6_data          = asi_in_data;
        aso_out6_valid         = asi_in_valid;
        aso_out6_error         = asi_in_error;
        aso_out6_channel       = asi_in_channel;
        aso_out6_startofpacket = asi_in_startofpacket;
        aso_out6_endofpacket   = asi_in_endofpacket;
        aso_out6_endofrun      = asi_in_endofrun;

        aso_out7_data          = asi_in_data;
        aso_out7_valid         = asi_in_valid;
        aso_out7_error         = asi_in_error;
        aso_out7_channel       = asi_in_channel;
        aso_out7_startofpacket = asi_in_startofpacket;
        aso_out7_endofpacket   = asi_in_endofpacket;
        aso_out7_endofrun      = asi_in_endofrun;

        unused_clock_reset     = csi_clk ^ rsi_reset;
    end

    // synthesis translate_off
    initial begin : parameter_guard
        if (DATA_WIDTH != 45 || CHANNEL_WIDTH != 4 || ERROR_WIDTH != 3) begin
            $error("hit_type0_fanout8 only supports the FEB hit_type0 stream profile");
        end
    end
    // synthesis translate_on

endmodule
