// pulse_fanout8.sv
// Simple conduit pulse fanout for emulator injection distribution.
//
// Version : 1.1.0
// Date    : 20260418
// Change  : Merge the local injector pulse with one auxiliary external pulse
//           source and fan out the combined edge to the datapath monitor seam
//           plus the 8 emulator conduits. The masked-trigger legs stay tied low
//           until the external masked path is integrated explicitly.

module pulse_fanout8 (
    input  logic csi_clk,
    input  logic rsi_reset,
    input  logic coe_inject_pulse,
    input  logic coe_aux_inject_pulse,
    output logic coe_out0_pulse,
    output logic coe_out0_masked_pulse,
    output logic coe_out1_pulse,
    output logic coe_out1_masked_pulse,
    output logic coe_out2_pulse,
    output logic coe_out2_masked_pulse,
    output logic coe_out3_pulse,
    output logic coe_out3_masked_pulse,
    output logic coe_out4_pulse,
    output logic coe_out4_masked_pulse,
    output logic coe_out5_pulse,
    output logic coe_out5_masked_pulse,
    output logic coe_out6_pulse,
    output logic coe_out6_masked_pulse,
    output logic coe_out7_pulse,
    output logic coe_out7_masked_pulse,
    output logic coe_out8_pulse,
    output logic coe_out8_masked_pulse
);
    logic merged_inject_pulse;

    assign merged_inject_pulse = coe_inject_pulse | coe_aux_inject_pulse;

    always_comb begin
        coe_out0_pulse        = merged_inject_pulse;
        coe_out0_masked_pulse = 1'b0;
        coe_out1_pulse        = merged_inject_pulse;
        coe_out1_masked_pulse = 1'b0;
        coe_out2_pulse        = merged_inject_pulse;
        coe_out2_masked_pulse = 1'b0;
        coe_out3_pulse        = merged_inject_pulse;
        coe_out3_masked_pulse = 1'b0;
        coe_out4_pulse        = merged_inject_pulse;
        coe_out4_masked_pulse = 1'b0;
        coe_out5_pulse        = merged_inject_pulse;
        coe_out5_masked_pulse = 1'b0;
        coe_out6_pulse        = merged_inject_pulse;
        coe_out6_masked_pulse = 1'b0;
        coe_out7_pulse        = merged_inject_pulse;
        coe_out7_masked_pulse = 1'b0;
        coe_out8_pulse        = merged_inject_pulse;
        coe_out8_masked_pulse = 1'b0;
    end

endmodule
