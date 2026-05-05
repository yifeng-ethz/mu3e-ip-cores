// altera_avalon_st_splitter_model.sv
//
// Thin behavioural model of altera_avalon_st_splitter (Qsys 18.1) for the
// B002 nested-splitter repro.  Models the declared behaviour when
// configured with:
//   USE_READY=0, QUALIFY_VALID_OUT=0, USE_VALID=1, USE_PACKETS=0,
//   USE_DATA=1, USE_CHANNEL=0, USE_ERROR=0,
//   BITS_PER_SYMBOL=9, DATA_WIDTH=9, READY_LATENCY=0
//
// Under those parameters the IP spec reduces to pure combinational fan-out:
//   out[n]_valid = in_valid  for all n
//   out[n]_data  = in_data   for all n
//   in_ready     = 1'b1      (no sink back-pressure because USE_READY=0)
//
// This is the DECLARED behaviour.  If the real Qsys-generated RTL deviates
// from this spec (e.g. adds a registered pipeline stage that is not
// indicated by the parameter set), the structural repro in sim will NOT
// reproduce the silicon failure, confirming the root cause is in the Qsys
// splitter implementation rather than in the topology alone.
//
// Parameters
//   N_OUTPUTS  : number of fan-out outputs (pass 16, 2, or 8 to match
//                the three silicon splitter stages)

module altera_avalon_st_splitter_model #(
    parameter int unsigned N_OUTPUTS = 2,
    // The following are documentation-only; values must match B002 config.
    parameter int unsigned DATA_WIDTH      = 9,
    parameter int unsigned BITS_PER_SYMBOL = 9
) (
    // Source (input) side
    input  logic [DATA_WIDTH-1:0]             in_data,
    input  logic                              in_valid,
    output logic                              in_ready,

    // Sink (output) side – flat arrays of N_OUTPUTS ports
    output logic [N_OUTPUTS-1:0][DATA_WIDTH-1:0] out_data,
    output logic [N_OUTPUTS-1:0]                 out_valid
);

    // USE_READY=0: in_ready is tied 1 unconditionally.
    assign in_ready = 1'b1;

    // QUALIFY_VALID_OUT=0: each output valid mirrors the input valid
    // unconditionally (no per-output enable gate).
    genvar g;
    generate
        for (g = 0; g < N_OUTPUTS; g++) begin : fan_out
            assign out_valid[g] = in_valid;
            assign out_data[g]  = in_data;
        end
    endgenerate

endmodule
