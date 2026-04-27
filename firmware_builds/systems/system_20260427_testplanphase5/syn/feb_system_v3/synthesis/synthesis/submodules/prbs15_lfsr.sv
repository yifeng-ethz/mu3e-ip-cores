// prbs15_lfsr.sv
// PRBS-15 LFSR coarse counter matching MuTRiG 3 ASIC TDC
//
// Integrated FEB/MTS-compatible dark coarse-code sequence
// Feedback:   new_bit = ~(sreg[14] XOR sreg[13])
// Init state: 15'h0001
// Period:     2^15 - 1 = 32767
//
// The real MuTRiG TDC has a dual-edge coarse counter (CCM on rising, CCS on falling
// of thermometer code bit 8). For the emulator we provide a single LFSR that advances
// on each byte-clock tick, representing the coarse time reference.

module prbs15_lfsr #(
    parameter int STEP_COUNT = 1
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,       // advance LFSR by STEP_COUNT steps
    output logic [14:0] lfsr_out
);

    logic [14:0] sreg;

    function automatic logic [14:0] advance_steps(input logic [14:0] state);
        logic [14:0] state_v;

        state_v = state;
        for (int idx = 0; idx < STEP_COUNT; idx++)
            state_v = {state_v[13:0], ~(state_v[14] ^ state_v[13])};
        return state_v;
    endfunction

    assign lfsr_out = sreg;

    always_ff @(posedge clk) begin
        if (rst) begin
            sreg <= 15'h0001;
        end else if (en) begin
            sreg <= advance_steps(sreg);
        end
    end

endmodule
