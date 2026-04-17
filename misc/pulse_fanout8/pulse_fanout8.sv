// pulse_fanout8.sv
// Simple conduit pulse fanout for emulator injection distribution.
//
// Version : 1.0.0
// Date    : 20260410
// Change  : Export one shared pulse to datapath injector plus 8 emulators.

module pulse_fanout8 (
    input  logic csi_clk,
    input  logic rsi_reset,
    input  logic coe_inject_pulse,
    output logic coe_out0_pulse,
    output logic coe_out1_pulse,
    output logic coe_out2_pulse,
    output logic coe_out3_pulse,
    output logic coe_out4_pulse,
    output logic coe_out5_pulse,
    output logic coe_out6_pulse,
    output logic coe_out7_pulse,
    output logic coe_out8_pulse
);

    always_comb begin
        coe_out0_pulse = coe_inject_pulse;
        coe_out1_pulse = coe_inject_pulse;
        coe_out2_pulse = coe_inject_pulse;
        coe_out3_pulse = coe_inject_pulse;
        coe_out4_pulse = coe_inject_pulse;
        coe_out5_pulse = coe_inject_pulse;
        coe_out6_pulse = coe_inject_pulse;
        coe_out7_pulse = coe_inject_pulse;
        coe_out8_pulse = coe_inject_pulse;
    end

endmodule
