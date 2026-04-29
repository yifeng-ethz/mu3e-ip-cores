// pulse_fanout8.sv
// Simple conduit pulse fanout for emulator injection distribution.
//
// Version : 26.2.0
// Date    : 20260429
// Change  : Remove the deprecated auxiliary injection input from the packaged
//           fanout. The active source is the local mutrig_injector pulse only.

module pulse_fanout8 (
    input  logic csi_clk,
    input  logic rsi_reset,
    input  logic coe_inject_pulse,
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

    assign merged_inject_pulse = coe_inject_pulse;

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
