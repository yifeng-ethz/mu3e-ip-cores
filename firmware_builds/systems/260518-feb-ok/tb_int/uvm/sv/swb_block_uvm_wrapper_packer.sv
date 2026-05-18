// -----------------------------------------------------------------------------
// File      : swb_block_uvm_wrapper_packer.sv
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Version   : 26.3.8
// Date      : 20260513
// Change    : Cosim-only SWB wrapper that routes FEB OPQ egress through the
//             Mu3e wire-format DMA packer instead of the legacy event builder.
// -----------------------------------------------------------------------------

`default_nettype none

module swb_block_uvm_wrapper_packer (
    input  wire         clk,
    input  wire         reset_n,
    input  wire [127:0] feb_data,
    input  wire [15:0]  feb_datak,
    input  wire [3:0]   feb_valid,
    input  wire [11:0]  feb_err_desc,
    input  wire [3:0]   feb_enable_mask,
    input  wire         use_merge,
    input  wire         enable_dma,
    input  wire [31:0]  get_n_words,
    input  wire [31:0]  lookup_ctrl,
    input  wire         dma_half_full,
    output wire [31:0]  opq_data,
    output wire [3:0]   opq_datak,
    output wire         opq_valid,
    output wire [255:0] dma_data,
    output wire         dma_wren,
    output wire         end_of_event,
    output wire         dma_done
);

    localparam int unsigned N_LANES_CONST = 4;

    logic [N_LANES_CONST-1:0][31:0] feb_lane_data;
    logic [N_LANES_CONST-1:0][3:0]  feb_lane_datak;
    logic [35:0]                    opq_egress_data;
    logic                           opq_egress_valid;
    logic                           opq_egress_sop;
    logic                           opq_egress_eop;
    logic [31:0]                    dma_datak;
    logic [31:0]                    input_word_cnt;
    logic [31:0]                    output_word_cnt;
    logic [31:0]                    event_cnt;
    logic [31:0]                    halt_cnt;

    logic [31:0]                    dma_word_count;
    logic [31:0]                    get_n_words_q;
    logic                           dma_done_q;
    logic                           dma_done_armed;

    // This wrapper preserves the legacy UVM-facing port set. These controls are
    // consumed by the legacy SWB block but not by the cosim packer path.
    wire                            unused_use_merge = use_merge;
    wire [11:0]                     unused_feb_err_desc = feb_err_desc;
    wire [31:0]                     unused_lookup_ctrl = lookup_ctrl;
    wire [31:0]                     unused_input_word_cnt = input_word_cnt;
    wire [31:0]                     unused_event_cnt = event_cnt;
    wire [31:0]                     unused_halt_cnt = halt_cnt;
    wire [31:0]                     unused_dma_datak = dma_datak;
    wire                            unused_opq_egress_sop = opq_egress_sop;
    wire                            unused_opq_egress_eop = opq_egress_eop;

    genvar lane;
    generate
        for (lane = 0; lane < N_LANES_CONST; lane++) begin : g_lane_split
            assign feb_lane_data[lane]  = feb_data[lane*32 +: 32];
            assign feb_lane_datak[lane] = feb_datak[lane*4 +: 4];
        end
    endgenerate

    swb_opq_dma_pipeline #(
        .N_LANES(N_LANES_CONST)
    ) u_pipeline (
        .i_clk              (clk),
        .i_reset_n          (reset_n),
        .i_feb_data         (feb_lane_data),
        .i_feb_datak        (feb_lane_datak),
        .i_feb_valid        (feb_valid),
        .i_lane_mask_n      (feb_enable_mask),
        .i_dma_enable       (enable_dma),
        .i_dma_halffull     (dma_half_full),
        .o_opq_egress_data  (opq_egress_data),
        .o_opq_egress_valid (opq_egress_valid),
        .o_opq_egress_sop   (opq_egress_sop),
        .o_opq_egress_eop   (opq_egress_eop),
        .o_dma_data         (dma_data),
        .o_dma_datak        (dma_datak),
        .o_dma_wen          (dma_wren),
        .o_end_of_event     (end_of_event),
        .o_input_word_cnt   (input_word_cnt),
        .o_output_word_cnt  (output_word_cnt),
        .o_event_cnt        (event_cnt),
        .o_halt_cnt         (halt_cnt)
    );

    assign opq_data  = opq_egress_data[31:0];
    assign opq_datak = opq_egress_data[35:32];
    assign opq_valid = opq_egress_valid;
    assign dma_done  = dma_done_q;

    always_ff @(posedge clk or negedge reset_n) begin : dma_done_counter
        if (!reset_n) begin
            dma_word_count <= '0;
            get_n_words_q  <= '0;
            dma_done_q     <= 1'b0;
            dma_done_armed <= 1'b1;
        end else begin
            dma_done_q <= 1'b0;

            if (!enable_dma || get_n_words == 32'h0 || get_n_words != get_n_words_q) begin
                dma_word_count <= '0;
                get_n_words_q  <= get_n_words;
                dma_done_armed <= 1'b1;
            end else if (dma_wren && dma_done_armed) begin
                dma_word_count <= dma_word_count + 1'b1;
                if ((dma_word_count + 1'b1) >= get_n_words) begin
                    dma_done_q     <= 1'b1;
                    dma_done_armed <= 1'b0;
                end
            end
        end
    end

endmodule

`default_nettype wire
