// hit_type0_fanout8.sv
// Eight-way Avalon-ST hit_type0 fanout for the FEB v3 emulator-type0 build.
//
// Version : 26.0.1
// Date    : 20260517
// Change  : Readyless build-local fanout that preserves hit_type0 endofrun.
//           Outputs are lane-qualified so the single emulator source models
//           the FEB's eight physical ASIC inputs instead of eight copies of
//           one ASIC.  Also phase-qualifies T/E timestamps so header-sync
//           mimic hits have one common histogram-ingress latency.

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

    localparam int TCC_HI_CONST = 35;
    localparam int TCC_LO_CONST = 21;
    localparam int ECC_HI_CONST = 15;
    localparam int ECC_LO_CONST = 1;
    localparam int MUTRIG_COARSE_STEPS_PER_CYCLE_CONST = 5;

    logic unused_clock_reset;

    function automatic logic [14:0] prbs15_step(input logic [14:0] state);
        return {state[13:0], ~(state[14] ^ state[13])};
    endfunction

    function automatic logic [14:0] prbs15_step_n(
        input logic [14:0] state,
        input int unsigned step_count
    );
        logic [14:0] state_v;

        state_v = state;
        for (int step_idx = 0; step_idx < step_count; step_idx++) begin
            state_v = prbs15_step(state_v);
        end
        return state_v;
    endfunction

    function automatic int unsigned lane_phase_cycles(input int unsigned lane_id);
        return (lane_id + 3) & 3;
    endfunction

    function automatic logic [DATA_WIDTH-1:0] lane_qualified_data(
        input logic [DATA_WIDTH-1:0] in_data,
        input int unsigned           lane_id
    );
        logic [DATA_WIDTH-1:0] data_v;
        int unsigned phase_steps_v;

        data_v = in_data;
        data_v[44:41] = lane_id[3:0];
        phase_steps_v = lane_phase_cycles(lane_id) * MUTRIG_COARSE_STEPS_PER_CYCLE_CONST;
        data_v[TCC_HI_CONST:TCC_LO_CONST] = prbs15_step_n(
            in_data[TCC_HI_CONST:TCC_LO_CONST],
            phase_steps_v
        );
        data_v[ECC_HI_CONST:ECC_LO_CONST] = prbs15_step_n(
            in_data[ECC_HI_CONST:ECC_LO_CONST],
            phase_steps_v
        );
        return data_v;
    endfunction

    always_comb begin : route_hit_type0
        aso_out0_data          = lane_qualified_data(asi_in_data, 4'd0);
        aso_out0_valid         = asi_in_valid;
        aso_out0_error         = asi_in_error;
        aso_out0_channel       = CHANNEL_WIDTH'(4'd0);
        aso_out0_startofpacket = asi_in_startofpacket;
        aso_out0_endofpacket   = asi_in_endofpacket;
        aso_out0_endofrun      = asi_in_endofrun;

        aso_out1_data          = lane_qualified_data(asi_in_data, 4'd1);
        aso_out1_valid         = asi_in_valid;
        aso_out1_error         = asi_in_error;
        aso_out1_channel       = CHANNEL_WIDTH'(4'd1);
        aso_out1_startofpacket = asi_in_startofpacket;
        aso_out1_endofpacket   = asi_in_endofpacket;
        aso_out1_endofrun      = asi_in_endofrun;

        aso_out2_data          = lane_qualified_data(asi_in_data, 4'd2);
        aso_out2_valid         = asi_in_valid;
        aso_out2_error         = asi_in_error;
        aso_out2_channel       = CHANNEL_WIDTH'(4'd2);
        aso_out2_startofpacket = asi_in_startofpacket;
        aso_out2_endofpacket   = asi_in_endofpacket;
        aso_out2_endofrun      = asi_in_endofrun;

        aso_out3_data          = lane_qualified_data(asi_in_data, 4'd3);
        aso_out3_valid         = asi_in_valid;
        aso_out3_error         = asi_in_error;
        aso_out3_channel       = CHANNEL_WIDTH'(4'd3);
        aso_out3_startofpacket = asi_in_startofpacket;
        aso_out3_endofpacket   = asi_in_endofpacket;
        aso_out3_endofrun      = asi_in_endofrun;

        aso_out4_data          = lane_qualified_data(asi_in_data, 4'd4);
        aso_out4_valid         = asi_in_valid;
        aso_out4_error         = asi_in_error;
        aso_out4_channel       = CHANNEL_WIDTH'(4'd4);
        aso_out4_startofpacket = asi_in_startofpacket;
        aso_out4_endofpacket   = asi_in_endofpacket;
        aso_out4_endofrun      = asi_in_endofrun;

        aso_out5_data          = lane_qualified_data(asi_in_data, 4'd5);
        aso_out5_valid         = asi_in_valid;
        aso_out5_error         = asi_in_error;
        aso_out5_channel       = CHANNEL_WIDTH'(4'd5);
        aso_out5_startofpacket = asi_in_startofpacket;
        aso_out5_endofpacket   = asi_in_endofpacket;
        aso_out5_endofrun      = asi_in_endofrun;

        aso_out6_data          = lane_qualified_data(asi_in_data, 4'd6);
        aso_out6_valid         = asi_in_valid;
        aso_out6_error         = asi_in_error;
        aso_out6_channel       = CHANNEL_WIDTH'(4'd6);
        aso_out6_startofpacket = asi_in_startofpacket;
        aso_out6_endofpacket   = asi_in_endofpacket;
        aso_out6_endofrun      = asi_in_endofrun;

        aso_out7_data          = lane_qualified_data(asi_in_data, 4'd7);
        aso_out7_valid         = asi_in_valid;
        aso_out7_error         = asi_in_error;
        aso_out7_channel       = CHANNEL_WIDTH'(4'd7);
        aso_out7_startofpacket = asi_in_startofpacket;
        aso_out7_endofpacket   = asi_in_endofpacket;
        aso_out7_endofrun      = asi_in_endofrun;

        unused_clock_reset     = csi_clk ^ rsi_reset ^ (^asi_in_channel);
    end

    // synthesis translate_off
    initial begin : parameter_guard
        if (DATA_WIDTH != 45 || CHANNEL_WIDTH != 4 || ERROR_WIDTH != 3) begin
            $error("hit_type0_fanout8 only supports the FEB hit_type0 stream profile");
        end
    end
    // synthesis translate_on

endmodule
