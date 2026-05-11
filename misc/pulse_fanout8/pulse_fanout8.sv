// pulse_fanout8.sv
// Simple conduit pulse fanout for emulator injection distribution.
//
// Version : 1.2
// Date    : 20260504
// Change  : Register each exported pulse port directly. This keeps the
//           VHDL/SystemVerilog Platform Designer boundary from collapsing the
//           real output fanout to a stale internal alias while preserving the
//           one-cycle fixed latency.

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
    logic merged_inject_pulse_d;

    assign merged_inject_pulse_d = coe_inject_pulse | coe_aux_inject_pulse;

    always_ff @(posedge csi_clk) begin
        if (rsi_reset) begin
            coe_out0_pulse        <= 1'b0;
            coe_out1_pulse        <= 1'b0;
            coe_out2_pulse        <= 1'b0;
            coe_out3_pulse        <= 1'b0;
            coe_out4_pulse        <= 1'b0;
            coe_out5_pulse        <= 1'b0;
            coe_out6_pulse        <= 1'b0;
            coe_out7_pulse        <= 1'b0;
            coe_out8_pulse        <= 1'b0;
            coe_out0_masked_pulse <= 1'b0;
            coe_out1_masked_pulse <= 1'b0;
            coe_out2_masked_pulse <= 1'b0;
            coe_out3_masked_pulse <= 1'b0;
            coe_out4_masked_pulse <= 1'b0;
            coe_out5_masked_pulse <= 1'b0;
            coe_out6_masked_pulse <= 1'b0;
            coe_out7_masked_pulse <= 1'b0;
            coe_out8_masked_pulse <= 1'b0;
        end else begin
            coe_out0_pulse        <= merged_inject_pulse_d;
            coe_out1_pulse        <= merged_inject_pulse_d;
            coe_out2_pulse        <= merged_inject_pulse_d;
            coe_out3_pulse        <= merged_inject_pulse_d;
            coe_out4_pulse        <= merged_inject_pulse_d;
            coe_out5_pulse        <= merged_inject_pulse_d;
            coe_out6_pulse        <= merged_inject_pulse_d;
            coe_out7_pulse        <= merged_inject_pulse_d;
            coe_out8_pulse        <= merged_inject_pulse_d;
            coe_out0_masked_pulse <= 1'b0;
            coe_out1_masked_pulse <= 1'b0;
            coe_out2_masked_pulse <= 1'b0;
            coe_out3_masked_pulse <= 1'b0;
            coe_out4_masked_pulse <= 1'b0;
            coe_out5_masked_pulse <= 1'b0;
            coe_out6_masked_pulse <= 1'b0;
            coe_out7_masked_pulse <= 1'b0;
            coe_out8_masked_pulse <= 1'b0;
        end
    end

endmodule
