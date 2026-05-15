// -----------------------------------------------------------------------------
// File      : swb_opq_dma_pipeline.sv
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Version   : 26.3.10
// Date      : 20260514
// Change    : Hardware SWB wrapper from raw OPQ egress to the lossless
//             swb_opq_dma_packer RDMA-FIFO interface with upstream ready.
// -----------------------------------------------------------------------------
//
// LEGACY_DMA_DEAD:
//   This wrapper replaces the old post-OPQ DMA choices in swb_block.vhd:
//   musip_mux_4_1, musip_event_builder, and the interim rdma_subsystem bridge.
//   It does not parse event format. It packs every accepted OPQ 32-bit wire
//   word into the existing 256-bit PCIe DMA0 write interface and asserts
//   o_end_of_event on OPQ EOP.
// -----------------------------------------------------------------------------

`default_nettype none

module swb_opq_dma_pipeline (
    input  wire         i_clk,
    input  wire         i_reset_n,
    input  wire         i_dma_enable,
    input  wire         i_dma_halffull,

    input  wire [31:0]  i_opq_data,
    input  wire [3:0]   i_opq_datak,
    input  wire         i_opq_valid,
    input  wire         i_opq_sop,
    input  wire         i_opq_eop,
    output wire         o_opq_ready,

    output logic [35:0] o_opq_egress_data,
    output logic        o_opq_egress_valid,
    output logic        o_opq_egress_sop,
    output logic        o_opq_egress_eop,

    output wire [255:0] o_dma_data,
    output wire         o_dma_wen,
    output wire         o_end_of_event,

    output wire [31:0]  o_input_word_cnt,
    output wire [31:0]  o_output_word_cnt,
    output wire [31:0]  o_event_cnt,
    output wire [31:0]  o_halt_cnt
);

    localparam logic [7:0] K285_CONST = 8'hBC;
    localparam logic [7:0] K284_CONST = 8'h9C;
    localparam logic [5:0] IDLE_HEADER_ID_CONST = 6'b000000;

    wire opq_accept_valid;
    wire opq_packer_ready;
    wire opq_is_sop;
    wire opq_is_eop;
    wire opq_is_idle_sop;
    wire opq_is_dirty_trailer;
    wire [31:0] opq_dma_data;
    wire opq_dma_sop;
    wire opq_dma_eop;

    assign opq_accept_valid    = i_dma_enable & i_opq_valid & opq_packer_ready;
    assign opq_is_sop        = (i_opq_datak == 4'h1) && (i_opq_data[7:0] == K285_CONST);
    assign opq_is_eop        = (i_opq_datak == 4'h1) && (i_opq_data[7:0] == K284_CONST);
    assign opq_is_idle_sop   = opq_is_sop && (i_opq_data[31:26] == IDLE_HEADER_ID_CONST);
    assign opq_is_dirty_trailer = opq_is_eop && (i_opq_data[31:8] != 24'h0);
    assign opq_dma_data      = opq_is_eop ? {24'h0, K284_CONST} : i_opq_data;
    assign opq_dma_sop       = opq_accept_valid & (i_opq_sop | opq_is_sop);
    assign opq_dma_eop       = opq_accept_valid & (i_opq_eop | opq_is_eop);

    // Gate visible ready with RDMA enable to prevent dropping accepted frames.
    assign o_opq_ready = i_dma_enable && opq_packer_ready;

    // synthesis translate_off
    always_ff @(posedge i_clk) begin
        if (i_reset_n && opq_accept_valid) begin
            if (opq_is_idle_sop) begin
                $fatal(1, "SWB OPQ DMA pipeline accepted an Idle frame SOP: data=0x%08h datak=0x%01h",
                       i_opq_data, i_opq_datak);
            end
            if (opq_is_dirty_trailer) begin
                $fatal(1, "SWB OPQ DMA pipeline accepted a dirty K28.4 trailer: data=0x%08h datak=0x%01h",
                       i_opq_data, i_opq_datak);
            end
        end
    end
    // synthesis translate_on

    always_ff @(posedge i_clk or negedge i_reset_n) begin
        if (!i_reset_n) begin
            o_opq_egress_data     <= '0;
            o_opq_egress_valid    <= 1'b0;
            o_opq_egress_sop      <= 1'b0;
            o_opq_egress_eop      <= 1'b0;
        end else begin
            o_opq_egress_data     <= {i_opq_datak, opq_dma_data};
            o_opq_egress_valid    <= opq_accept_valid;
            o_opq_egress_sop      <= opq_dma_sop;
            o_opq_egress_eop      <= opq_dma_eop;
        end
    end

    swb_opq_dma_packer u_packer (
        .i_clk            (i_clk),
        .i_reset_n        (i_reset_n),
        .i_opq_data       (opq_dma_data),
        .i_opq_datak      (i_opq_datak),
        .i_opq_valid      (opq_accept_valid),
        .i_opq_sop        (opq_dma_sop),
        .i_opq_eop        (opq_dma_eop),
        .o_opq_ready      (opq_packer_ready),
        .i_dma_halffull   (i_dma_halffull),
        .o_dma_data       (o_dma_data),
        .o_dma_wen        (o_dma_wen),
        .o_end_of_event   (o_end_of_event),
        .o_input_word_cnt (o_input_word_cnt),
        .o_output_word_cnt(o_output_word_cnt),
        .o_event_cnt      (o_event_cnt),
        .o_halt_cnt       (o_halt_cnt)
    );

endmodule

`default_nettype wire
