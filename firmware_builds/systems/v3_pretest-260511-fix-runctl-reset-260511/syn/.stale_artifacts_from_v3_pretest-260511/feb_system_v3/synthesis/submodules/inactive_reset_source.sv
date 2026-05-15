// inactive_reset_source.sv
// Constant inactive reset source for Qsys-only reset sink tie-off.
//
// Version : 26.0.0
// Date    : 20260425
// Change  : Initial utility IP for keeping PLL reset inputs outside live reset
//           trees while satisfying Platform Designer reset-source validation.

module inactive_reset_source (
    input  logic csi_clk,
    output logic rso_reset
);
    assign rso_reset = 1'b0;

endmodule
