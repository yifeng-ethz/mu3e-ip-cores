module ip_madd_altera_fpdsp_block_181_bs3fhgi  (
    input  wire                          clk,
    input  wire                          ena,
    input  wire [1:0]                    aclr,
    input  wire [31:0]                   ax,
    input  wire [31:0]                   ay,
    input  wire [31:0]                   az,
    output wire [31:0]                   result

	);
    wire [1-1:0] clk_vec;
    wire [1-1:0] ena_vec;
    assign clk_vec[0] = clk;
    assign ena_vec[0] = ena;

twentynm_fp_mac  #(
    .ax_clock("0"),
    .ay_clock("0"),
    .az_clock("0"),
    .output_clock("0"),
    .accumulate_clock("NONE"),
    .ax_chainin_pl_clock("0"),
    .accum_pipeline_clock("NONE"),
    .mult_pipeline_clock("0"),
    .adder_input_clock("0"),
    .accum_adder_clock("NONE"),
    .use_chainin("false"),
    .operation_mode("sp_mult_add"),
    .adder_subtract("false")
) sp_mult_add (
    .clk({1'b0,1'b0,clk_vec[0]}),
    .ena({1'b0,1'b0,ena_vec[0]}),
    .aclr(aclr),
    .ax(ax),
    .ay(ay),
    .az(az),

    .chainin(32'b0),
    .resulta(result),
    .chainout()
);
endmodule

