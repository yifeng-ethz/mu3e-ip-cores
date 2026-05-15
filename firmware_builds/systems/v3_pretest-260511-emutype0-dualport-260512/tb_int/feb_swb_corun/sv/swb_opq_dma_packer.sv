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
// Version   : 26.3.11
// Date      : 20260514
// Change    : Expose OPQ ready so RDMA backpressure reaches the upstream
//             packet merger before the elastic FIFO overflows.
//
// Outputs: 256b DMA word stream — wen, end_of_event, halffull accounting.
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
    parameter int unsigned SLOTS_PER_DMA = 8,   // = DMA_WORD_W / OPQ_DATA_W
    parameter int unsigned BACKPRESSURE_FIFO_DEPTH = 4096
) (
    input  wire                          i_clk,
    input  wire                          i_reset_n,

    // OPQ egress
    input  wire [OPQ_DATA_W-1:0]         i_opq_data,
    input  wire [OPQ_DATA_W/8-1:0]       i_opq_datak,
    input  wire                          i_opq_valid,
    input  wire                          i_opq_sop,
    input  wire                          i_opq_eop,
    output wire                          o_opq_ready,

    // Backpressure (from PCIe RDMA writeback)
    input  wire                          i_dma_halffull,

    // DMA writeback
    output reg  [DMA_WORD_W-1:0]         o_dma_data,
    output reg  [SLOTS_PER_DMA*(OPQ_DATA_W/8)-1:0] o_dma_datak,
    output reg                           o_dma_wen,
    output reg                           o_end_of_event,

    // Counters (CSR-readable from outside)
    output reg  [31:0]                   o_input_word_cnt,
    output reg  [31:0]                   o_output_word_cnt,
    output reg  [31:0]                   o_event_cnt,
    output reg  [31:0]                   o_halt_cnt
);

    localparam int unsigned OPQ_DATK_W          = OPQ_DATA_W / 8;
    localparam int unsigned FIFO_PTR_W          =
        (BACKPRESSURE_FIFO_DEPTH <= 2) ? 1 : $clog2(BACKPRESSURE_FIFO_DEPTH);
    localparam int unsigned FIFO_COUNT_W        =
        $clog2(BACKPRESSURE_FIFO_DEPTH + 1);
    localparam logic [FIFO_PTR_W-1:0] FIFO_LAST_PTR =
        BACKPRESSURE_FIFO_DEPTH[FIFO_PTR_W-1:0] - 1'b1;
    localparam logic [FIFO_COUNT_W-1:0] FIFO_DEPTH_COUNT =
        BACKPRESSURE_FIFO_DEPTH[FIFO_COUNT_W-1:0];

    // Slot accumulator: slot 0 occupies bits [31:0], matching host 32b
    // little-endian unpacking of the 256b DMA line.
    reg [DMA_WORD_W-1:0]  accum;
    reg [SLOTS_PER_DMA*OPQ_DATK_W-1:0] accum_datak;
    reg [3:0]             slot_idx;        // counts 0..SLOTS_PER_DMA-1

    reg [DMA_WORD_W-1:0]  emit_data;
    reg [SLOTS_PER_DMA*OPQ_DATK_W-1:0] emit_datak;

    (* ramstyle = "M20K" *) reg [OPQ_DATA_W-1:0] fifo_data
        [0:BACKPRESSURE_FIFO_DEPTH-1];
    (* ramstyle = "MLAB" *) reg [OPQ_DATK_W-1:0] fifo_datak
        [0:BACKPRESSURE_FIFO_DEPTH-1];
    (* ramstyle = "MLAB" *) reg fifo_eop
        [0:BACKPRESSURE_FIFO_DEPTH-1];

    reg [FIFO_PTR_W-1:0]   fifo_wr_ptr;
    reg [FIFO_PTR_W-1:0]   fifo_rd_ptr;
    reg [FIFO_COUNT_W-1:0] fifo_count;
    reg [OPQ_DATA_W-1:0]   fifo_pop_data;
    reg [OPQ_DATK_W-1:0]   fifo_pop_datak;
    reg                    fifo_pop_eop;
    reg                    fifo_pop_valid;

    wire                   fifo_empty;
    wire                   fifo_full;
    wire                   fifo_read_req;
    wire                   fifo_write;
    wire                   opq_stall;
    wire                   fifo_pop_accept;

    assign fifo_empty    = (fifo_count == '0);
    assign fifo_full     = (fifo_count == FIFO_DEPTH_COUNT);
    assign o_opq_ready   = i_reset_n && !fifo_full;
    assign fifo_pop_accept = fifo_pop_valid && !i_dma_halffull;
    assign fifo_read_req = !fifo_empty && !i_dma_halffull &&
                           (!fifo_pop_valid || fifo_pop_accept);
    assign fifo_write    = i_opq_valid && o_opq_ready;
    assign opq_stall     = i_opq_valid && !o_opq_ready;

    function automatic logic [FIFO_PTR_W-1:0] fifo_ptr_next(
        input logic [FIFO_PTR_W-1:0] ptr
    );
        if (ptr == FIFO_LAST_PTR) begin
            return '0;
        end
        return ptr + 1'b1;
    endfunction

    always_ff @(posedge i_clk or negedge i_reset_n) begin
        if (!i_reset_n) begin
            accum                <= '0;
            slot_idx             <= '0;
            o_dma_data           <= '0;
            o_dma_datak          <= '0;
            o_dma_wen            <= 1'b0;
            o_end_of_event       <= 1'b0;
            o_input_word_cnt     <= '0;
            o_output_word_cnt    <= '0;
            o_event_cnt          <= '0;
            o_halt_cnt           <= '0;
            fifo_wr_ptr          <= '0;
            fifo_rd_ptr          <= '0;
            fifo_count           <= '0;
            fifo_pop_data        <= '0;
            fifo_pop_datak       <= '0;
            fifo_pop_eop         <= 1'b0;
            fifo_pop_valid       <= 1'b0;
        end else begin
            // default
            o_dma_wen         <= 1'b0;
            o_end_of_event    <= 1'b0;

            if ((i_dma_halffull && (i_opq_valid || !fifo_empty ||
                                    fifo_pop_valid)) ||
                opq_stall) begin
                o_halt_cnt <= o_halt_cnt + 1;
            end

            if (fifo_write) begin
                fifo_data[fifo_wr_ptr]     <= i_opq_data;
                fifo_datak[fifo_wr_ptr]    <= i_opq_datak;
                fifo_eop[fifo_wr_ptr]      <= i_opq_eop;
                fifo_wr_ptr                <= fifo_ptr_next(fifo_wr_ptr);
                o_input_word_cnt           <= o_input_word_cnt + 1;
            end

            if (fifo_read_req) begin
                fifo_pop_data     <= fifo_data[fifo_rd_ptr];
                fifo_pop_datak    <= fifo_datak[fifo_rd_ptr];
                fifo_pop_eop      <= fifo_eop[fifo_rd_ptr];
                fifo_pop_valid    <= 1'b1;
                fifo_rd_ptr       <= fifo_ptr_next(fifo_rd_ptr);
            end else if (fifo_pop_accept) begin
                fifo_pop_valid   <= 1'b0;
            end

            unique case ({fifo_write, fifo_read_req})
                2'b10: begin
                    fifo_count    <= fifo_count + 1'b1;
                end
                2'b01: begin
                    fifo_count    <= fifo_count - 1'b1;
                end
                default: begin
                    fifo_count    <= fifo_count;
                end
            endcase

            if (fifo_pop_accept) begin
                emit_data = accum;
                emit_datak = accum_datak;
                emit_data[slot_idx*OPQ_DATA_W +: OPQ_DATA_W] = fifo_pop_data;
                emit_datak[slot_idx*OPQ_DATK_W +: OPQ_DATK_W] = fifo_pop_datak;

                // Emit either on a full 256b line or immediately on OPQ EOP.
                // The EOP case pads the remaining slots with zero, so the next
                // Mu3e frame always starts on a fresh DMA line.
                if ((slot_idx == SLOTS_PER_DMA - 1) || fifo_pop_eop) begin
                    o_dma_data           <= emit_data;
                    o_dma_datak          <= emit_datak;
                    o_dma_wen            <= 1'b1;
                    o_output_word_cnt    <= o_output_word_cnt + 1;
                    o_end_of_event       <= fifo_pop_eop;
                    if (fifo_pop_eop) begin
                        o_event_cnt    <= o_event_cnt + 1;
                    end
                    slot_idx       <= '0;
                    accum          <= '0;
                    accum_datak    <= '0;
                end else begin
                    accum          <= emit_data;
                    accum_datak    <= emit_datak;
                    slot_idx       <= slot_idx + 1;
                end
            end
        end
    end

endmodule
