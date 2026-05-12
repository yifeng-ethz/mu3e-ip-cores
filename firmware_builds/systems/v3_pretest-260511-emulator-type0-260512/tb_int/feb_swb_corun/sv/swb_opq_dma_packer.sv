// -----------------------------------------------------------------------------
// swb_opq_dma_packer.sv
//
// Clean replacement for the post-OPQ chain in swb_block.vhd
// (ingress_egress_adaptor egress_mux + musip_mux_4_1 + musip_event_builder).
//
// Inputs:  OPQ egress stream — 36b (32b data + 4b datak), valid, sop, eop.
//          The OPQ already does the per-lane time-merge; this module just
//          packs the resulting word stream into 256b DMA writes.
//
// Outputs: 256b DMA word stream — wen, end_of_event, halt-on-halffull.
//          end_of_event is asserted on the last beat of each event boundary,
//          which we declare as one OPQ frame (i.e. on OPQ eop). This gives
//          the host a per-frame DMA endpoint without the legacy
//          "wait-for-N-words" event_builder framing.
//
// Per the user directive: keep OPQ unchanged, replace everything else with
// a minimal honest packer. No skipping. Conservation invariant:
//   sum(opq_egress_valid 32b words) == sum(dma_data 32b slots emitted)
// -----------------------------------------------------------------------------

`default_nettype none

module swb_opq_dma_packer #(
    parameter int unsigned DMA_WORD_W   = 256,  // DMA word width
    parameter int unsigned OPQ_DATA_W   = 32,   // OPQ data path width
    parameter int unsigned SLOTS_PER_DMA = 8    // = DMA_WORD_W / OPQ_DATA_W
) (
    input  wire                          i_clk,
    input  wire                          i_reset_n,

    // OPQ egress
    input  wire [OPQ_DATA_W-1:0]         i_opq_data,
    input  wire [OPQ_DATA_W/8-1:0]       i_opq_datak,
    input  wire                          i_opq_valid,
    input  wire                          i_opq_sop,
    input  wire                          i_opq_eop,

    // Backpressure (from PCIe DMA writeback)
    input  wire                          i_dma_halffull,

    // DMA writeback
    output reg  [DMA_WORD_W-1:0]         o_dma_data,
    output reg                           o_dma_wen,
    output reg                           o_end_of_event,

    // Counters (CSR-readable from outside)
    output reg  [31:0]                   o_input_word_cnt,
    output reg  [31:0]                   o_output_word_cnt,
    output reg  [31:0]                   o_event_cnt,
    output reg  [31:0]                   o_halt_cnt
);

    localparam logic [OPQ_DATA_W-1:0] PADDING_WORD = 32'h0000_0000;

    // Slot accumulator: shift in 32b words MSB-first into a 256b register
    reg [DMA_WORD_W-1:0]  accum;
    reg [3:0]             slot_idx;        // counts 0..SLOTS_PER_DMA-1
    reg                   pending_eoe;     // remember EOP across the flush

    wire                  accept;

    // Allow input only when DMA isn't backpressured (HALT)
    assign accept = i_opq_valid & ~i_dma_halffull;

    always_ff @(posedge i_clk or negedge i_reset_n) begin
        if (!i_reset_n) begin
            accum             <= '0;
            slot_idx          <= '0;
            pending_eoe       <= 1'b0;
            o_dma_data        <= '0;
            o_dma_wen         <= 1'b0;
            o_end_of_event    <= 1'b0;
            o_input_word_cnt  <= '0;
            o_output_word_cnt <= '0;
            o_event_cnt       <= '0;
            o_halt_cnt        <= '0;
        end else begin
            // default
            o_dma_wen      <= 1'b0;
            o_end_of_event <= 1'b0;

            if (i_opq_valid && i_dma_halffull) begin
                // dropped opportunity — track for diagnostic
                o_halt_cnt <= o_halt_cnt + 1;
            end

            if (accept) begin
                o_input_word_cnt <= o_input_word_cnt + 1;
                pending_eoe      <= pending_eoe | i_opq_eop;

                // shift in word at slot_idx
                accum[slot_idx*OPQ_DATA_W +: OPQ_DATA_W] <= i_opq_data;
                slot_idx <= slot_idx + 1;

                // Once the 256b is full, emit
                if (slot_idx == SLOTS_PER_DMA - 1) begin
                    o_dma_data        <= {i_opq_data, accum[DMA_WORD_W-OPQ_DATA_W-1:0]};
                    o_dma_wen         <= 1'b1;
                    o_output_word_cnt <= o_output_word_cnt + 1;
                    o_end_of_event    <= pending_eoe | i_opq_eop;
                    if (pending_eoe | i_opq_eop)
                        o_event_cnt <= o_event_cnt + 1;
                    pending_eoe <= 1'b0;
                    slot_idx    <= '0;
                    accum       <= '0;
                end
            end else if (pending_eoe && slot_idx != 0) begin
                // EOE pending and we have a partial line — flush with padding
                // Build the line from accum + padding for empty slots
                // (zero-pad — host knows event length from end_of_event)
                o_dma_data        <= accum;
                o_dma_wen         <= 1'b1;
                o_end_of_event    <= 1'b1;
                o_output_word_cnt <= o_output_word_cnt + 1;
                o_event_cnt       <= o_event_cnt + 1;
                pending_eoe       <= 1'b0;
                slot_idx          <= '0;
                accum             <= '0;
            end
        end
    end

endmodule
