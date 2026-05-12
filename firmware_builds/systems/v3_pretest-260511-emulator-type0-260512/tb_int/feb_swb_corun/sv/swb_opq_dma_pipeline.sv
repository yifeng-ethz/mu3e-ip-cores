// -----------------------------------------------------------------------------
// swb_opq_dma_pipeline.sv
//
// Clean SWB datapath wrapper: 4 FEB lanes -> ingress register stage -> OPQ ->
// packer -> DMA. Replaces the entire chain after the FEB ingress flop.
//
// Per the user directive: keep OPQ unchanged, replace
//   ingress_egress_adaptor egress_mux + musip_mux_4_1 + musip_event_builder
// with a minimal honest packer that does no skipping.
//
// Also exposes a small CSR aperture for runtime control (link mask, dma enable).
// The OPQ already has its own CSR via the embedded JTAG master in DT builds.
// -----------------------------------------------------------------------------

`default_nettype none

module swb_opq_dma_pipeline #(
    parameter int unsigned N_LANES = 4
) (
    input  wire                          i_clk,
    input  wire                          i_reset_n,

    // 4 FEB ingress lanes (32b data + 4b datak + valid)
    input  wire [N_LANES-1:0][31:0]      i_feb_data,
    input  wire [N_LANES-1:0][3:0]       i_feb_datak,
    input  wire [N_LANES-1:0]            i_feb_valid,

    // CSR
    input  wire [N_LANES-1:0]            i_lane_mask_n,   // 1 = lane participates
    input  wire                          i_dma_enable,
    input  wire                          i_dma_halffull,

    // OPQ egress monitor (debug — exposed for STP / scoreboarding)
    output wire [35:0]                   o_opq_egress_data,
    output wire                          o_opq_egress_valid,
    output wire                          o_opq_egress_sop,
    output wire                          o_opq_egress_eop,

    // DMA writeback
    output wire [255:0]                  o_dma_data,
    output wire                          o_dma_wen,
    output wire                          o_end_of_event,

    // CSR readback counters
    output wire [31:0]                   o_input_word_cnt,
    output wire [31:0]                   o_output_word_cnt,
    output wire [31:0]                   o_event_cnt,
    output wire [31:0]                   o_halt_cnt
);

    // ----------------- Stage 1: ingress register w/ lane mask ----------------
    logic [N_LANES-1:0][35:0] ingress_data_q;
    logic [N_LANES-1:0]       ingress_valid_q;
    logic [N_LANES-1:0]       ingress_sop_q;
    logic [N_LANES-1:0]       ingress_eop_q;

    always_ff @(posedge i_clk or negedge i_reset_n) begin
        if (!i_reset_n) begin
            ingress_data_q  <= '0;
            ingress_valid_q <= '0;
            ingress_sop_q   <= '0;
            ingress_eop_q   <= '0;
        end else begin
            for (int lane = 0; lane < N_LANES; lane++) begin
                ingress_valid_q[lane] <= i_feb_valid[lane] & i_lane_mask_n[lane];
                ingress_data_q[lane]  <= {i_feb_datak[lane], i_feb_data[lane]};
                // Detect K28.5 (BC) for SOP and K28.4 (9C) for EOP
                ingress_sop_q[lane]   <= (i_feb_datak[lane] == 4'b0001) &&
                                          (i_feb_data[lane][7:0] == 8'hBC);
                ingress_eop_q[lane]   <= (i_feb_datak[lane] == 4'b0001) &&
                                          (i_feb_data[lane][7:0] == 8'h9C);
            end
        end
    end

    // ----------------- Stage 2: OPQ -----------------------------------------
    // Note: in the full integration, this maps to the existing
    // opq_upstream_4lane Qsys instance. For pure-SV cosim we model OPQ as a
    // 1-cycle latency pass-through that picks among the 4 lanes (the real OPQ
    // already sequences them; here we only validate the packer).
    //
    // The hardware integration replaces this with the actual OPQ instance
    // and feeds opq_egress_* directly into the packer.

    // For the cosim TB we just round-robin through the lanes. Real RTL
    // would instantiate the OPQ here.
    logic [35:0] opq_egress_data_q;
    logic        opq_egress_valid_q;
    logic        opq_egress_sop_q;
    logic        opq_egress_eop_q;
    logic [1:0]  rr_lane;

    always_ff @(posedge i_clk or negedge i_reset_n) begin
        if (!i_reset_n) begin
            rr_lane            <= '0;
            opq_egress_data_q  <= '0;
            opq_egress_valid_q <= 1'b0;
            opq_egress_sop_q   <= 1'b0;
            opq_egress_eop_q   <= 1'b0;
        end else begin
            // pick first valid lane in round-robin
            opq_egress_valid_q <= 1'b0;
            opq_egress_sop_q   <= 1'b0;
            opq_egress_eop_q   <= 1'b0;
            for (int unsigned k = 0; k < N_LANES; k++) begin
                automatic int unsigned lane = (rr_lane + k) % N_LANES;
                if (ingress_valid_q[lane]) begin
                    opq_egress_data_q  <= ingress_data_q[lane];
                    opq_egress_valid_q <= 1'b1;
                    opq_egress_sop_q   <= ingress_sop_q[lane];
                    opq_egress_eop_q   <= ingress_eop_q[lane];
                    rr_lane            <= lane[1:0] + 1;
                    break;
                end
            end
        end
    end

    assign o_opq_egress_data  = opq_egress_data_q;
    assign o_opq_egress_valid = opq_egress_valid_q;
    assign o_opq_egress_sop   = opq_egress_sop_q;
    assign o_opq_egress_eop   = opq_egress_eop_q;

    // ----------------- Stage 3: DMA packer ----------------------------------
    swb_opq_dma_packer u_packer (
        .i_clk           (i_clk),
        .i_reset_n       (i_reset_n & i_dma_enable),
        .i_opq_data      (opq_egress_data_q[31:0]),
        .i_opq_datak     (opq_egress_data_q[35:32]),
        .i_opq_valid     (opq_egress_valid_q & i_dma_enable),
        .i_opq_sop       (opq_egress_sop_q),
        .i_opq_eop       (opq_egress_eop_q),
        .i_dma_halffull  (i_dma_halffull),
        .o_dma_data      (o_dma_data),
        .o_dma_wen       (o_dma_wen),
        .o_end_of_event  (o_end_of_event),
        .o_input_word_cnt(o_input_word_cnt),
        .o_output_word_cnt(o_output_word_cnt),
        .o_event_cnt     (o_event_cnt),
        .o_halt_cnt      (o_halt_cnt)
    );

endmodule
