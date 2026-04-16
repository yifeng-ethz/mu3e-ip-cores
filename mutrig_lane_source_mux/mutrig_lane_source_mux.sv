module mutrig_lane_source_mux #(
    parameter bit SELECT_EMULATOR = 1'b0
) (
    input  logic        clk,
    input  logic        rst,

    input  logic [8:0]  asi_real_data,
    input  logic        asi_real_valid,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_real_channel,

    input  logic [8:0]  asi_emu_data,
    input  logic        asi_emu_valid,
    input  logic [2:0]  asi_emu_error,
    input  logic [3:0]  asi_emu_channel,

    output logic [8:0]  aso_data,
    output logic        aso_valid,
    output logic [2:0]  aso_error,
    output logic [3:0]  aso_channel
);

    logic unused_clk;
    logic unused_rst;

    assign unused_clk = clk;
    assign unused_rst = rst;

    always_comb begin
        if (SELECT_EMULATOR) begin
            aso_data    = asi_emu_data;
            aso_valid   = asi_emu_valid;
            aso_error   = asi_emu_error;
            aso_channel = asi_emu_channel;
        end else begin
            aso_data    = asi_real_data;
            aso_valid   = asi_real_valid;
            aso_error   = asi_real_error;
            aso_channel = asi_real_channel;
        end
    end
endmodule
