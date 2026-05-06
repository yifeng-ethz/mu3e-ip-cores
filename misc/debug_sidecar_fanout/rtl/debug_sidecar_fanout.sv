// debug_sidecar_fanout.sv
// Four-way combinational fanout for 64-bit DEBUG hit metadata conduits.
//
// Version : 26.0.0
// Date    : 20260506
// Change  : Initial Qsys component for legal one-to-many metadata fanout.

module debug_sidecar_fanout #(
    parameter int DATA_WIDTH = 64
) (
    input  logic                  i_clk,
    input  logic                  i_rst,

    input  logic [DATA_WIDTH-1:0] coe_in_metadata,
    input  logic                  coe_in_valid,

    output logic [DATA_WIDTH-1:0] coe_out0_metadata,
    output logic                  coe_out0_valid,
    output logic [DATA_WIDTH-1:0] coe_out1_metadata,
    output logic                  coe_out1_valid,
    output logic [DATA_WIDTH-1:0] coe_out2_metadata,
    output logic                  coe_out2_valid,
    output logic [DATA_WIDTH-1:0] coe_out3_metadata,
    output logic                  coe_out3_valid
);

    assign coe_out0_metadata = coe_in_metadata;
    assign coe_out1_metadata = coe_in_metadata;
    assign coe_out2_metadata = coe_in_metadata;
    assign coe_out3_metadata = coe_in_metadata;

    assign coe_out0_valid = coe_in_valid;
    assign coe_out1_valid = coe_in_valid;
    assign coe_out2_valid = coe_in_valid;
    assign coe_out3_valid = coe_in_valid;

    logic unused_clock_reset;
    assign unused_clock_reset = i_clk ^ i_rst;

    // synthesis translate_off
    initial begin : parameter_guard
        if (DATA_WIDTH != 64) begin
            $error("debug_sidecar_fanout currently supports DATA_WIDTH=64 only");
        end
    end
    // synthesis translate_on

endmodule
