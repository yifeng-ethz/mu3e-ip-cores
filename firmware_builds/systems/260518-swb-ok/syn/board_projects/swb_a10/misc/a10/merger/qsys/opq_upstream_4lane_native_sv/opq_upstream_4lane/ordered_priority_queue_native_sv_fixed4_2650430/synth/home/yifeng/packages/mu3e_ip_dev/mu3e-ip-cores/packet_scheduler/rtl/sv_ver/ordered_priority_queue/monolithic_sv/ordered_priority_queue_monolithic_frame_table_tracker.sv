//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_frame_table_tracker
// Version : 26.1.0
// Date    : 20260413
// Change  : Add standalone SV translation of the frame-table tracker block
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_frame_table_tracker #(
  parameter int unsigned N_TILE = 5,
  parameter int unsigned TILE_FIFO_DEPTH = 512,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned TILE_PKT_CNT_WIDTH = 10
) (
  input  logic                                                 d_clk,
  input  logic                                                 d_reset,
  input  logic [1:0]                                           i_update_ftable_valid,
  input  logic [1:0][$clog2(N_TILE)-1:0]                       i_update_ftable_tindex,
  input  logic [1:0]                                           i_update_ftable_meta_valid,
  input  logic [1:0][2*$clog2(PAGE_RAM_DEPTH)-1:0]             i_update_ftable_meta,
  input  logic [1:0]                                           i_update_ftable_trltl_valid,
  input  logic [1:0][$clog2(N_TILE)-1:0]                       i_update_ftable_trltl,
  input  logic [1:0]                                           i_update_ftable_bdytl_valid,
  input  logic [1:0][$clog2(N_TILE)-1:0]                       i_update_ftable_bdytl,
  input  logic [1:0]                                           i_update_ftable_hcmpl,
  input  logic [1:0]                                           i_flush_ftable_valid,
  input  logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       i_tile_rptr,
  input  logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]            i_tile_pkt_rcnt,
  input  logic [$clog2(N_TILE)-1:0]                            i_rseg_tile_index,
  input  logic                                                 i_void_trail_tid,
  input  logic                                                 i_void_body_tid,
  output logic [N_TILE-1:0]                                    o_tile_fifo_we,
  output logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       o_tile_fifo_wr_addr,
  output logic [N_TILE-1:0][2*$clog2(PAGE_RAM_DEPTH)-1:0]      o_tile_fifo_wr_data,
  output logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       o_tile_wptr,
  output logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]            o_tile_pkt_wcnt,
  output logic [N_TILE-1:0][$clog2(N_TILE):0]                  o_trail_tid,
  output logic [N_TILE-1:0][$clog2(N_TILE):0]                  o_body_tid
);
  localparam int unsigned TILE_ID_WIDTH = $clog2(N_TILE);
  localparam int unsigned TILE_FIFO_ADDR_WIDTH = $clog2(TILE_FIFO_DEPTH);
  localparam int unsigned TILE_FIFO_DATA_WIDTH = 2 * $clog2(PAGE_RAM_DEPTH);

  typedef enum logic [1:0] {
    TRACKER_IDLING,
    TRACKER_RECORDING_TILE,
    TRACKER_RESETTING
  } tracker_state_t;

  tracker_state_t tracker_state;
  logic [N_TILE-1:0][TILE_FIFO_ADDR_WIDTH-1:0] tile_wptr;
  logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0] tile_pkt_wcnt;
  logic [N_TILE-1:0][TILE_ID_WIDTH:0] trail_tid;
  logic [N_TILE-1:0][TILE_ID_WIDTH:0] body_tid;
  logic [1:0] upd_valid;
  logic [1:0][TILE_ID_WIDTH-1:0] upd_tindex;
  logic [1:0] upd_meta_valid;
  logic [1:0][TILE_FIFO_DATA_WIDTH-1:0] upd_meta;
  logic [1:0] upd_trltl_valid;
  logic [1:0][TILE_ID_WIDTH-1:0] upd_trltl;
  logic [1:0] upd_bdytl_valid;
  logic [1:0][TILE_ID_WIDTH-1:0] upd_bdytl;
  logic [1:0] upd_hcmpl;

  assign o_tile_wptr = tile_wptr;
  assign o_tile_pkt_wcnt = tile_pkt_wcnt;
  assign o_trail_tid = trail_tid;
  assign o_body_tid = body_tid;

  always_comb begin : proc_tile_fifo_wr_comb
    o_tile_fifo_we = '0;
    o_tile_fifo_wr_addr = '0;
    o_tile_fifo_wr_data = '0;

    if (tracker_state == TRACKER_RECORDING_TILE) begin
      for (int a = 0; a < 2; a++) begin
        int unsigned tile_idx_v;

        tile_idx_v = upd_tindex[a];
        if (upd_meta_valid[a]) begin
          o_tile_fifo_we[tile_idx_v] = 1'b1;
          o_tile_fifo_wr_addr[tile_idx_v] = tile_wptr[tile_idx_v];
          o_tile_fifo_wr_data[tile_idx_v] = upd_meta[a];
        end
      end
    end
  end

  always_ff @(posedge d_clk) begin : proc_tracker
    if (|i_flush_ftable_valid) begin
      for (int a = 0; a < 2; a++) begin
        int unsigned tile_idx_v;

        if (i_flush_ftable_valid[a]) begin
          tile_idx_v = i_update_ftable_tindex[a];
          trail_tid[tile_idx_v] <= '0;
          body_tid[tile_idx_v] <= '0;
          tile_wptr[tile_idx_v] <= i_tile_rptr[tile_idx_v];
          tile_pkt_wcnt[tile_idx_v] <= i_tile_pkt_rcnt[tile_idx_v];
        end
      end
    end

    unique case (tracker_state)
      TRACKER_IDLING: begin
        if (|i_update_ftable_valid) begin
          upd_valid <= i_update_ftable_valid;
          upd_tindex <= i_update_ftable_tindex;
          upd_meta_valid <= i_update_ftable_meta_valid;
          upd_meta <= i_update_ftable_meta;
          upd_trltl_valid <= i_update_ftable_trltl_valid;
          upd_trltl <= i_update_ftable_trltl;
          upd_bdytl_valid <= i_update_ftable_bdytl_valid;
          upd_bdytl <= i_update_ftable_bdytl;
          upd_hcmpl <= i_update_ftable_hcmpl;
          tracker_state <= TRACKER_RECORDING_TILE;
        end else if (|upd_valid) begin
          tracker_state <= TRACKER_RECORDING_TILE;
        end
      end

      TRACKER_RECORDING_TILE: begin
        for (int a = 0; a < 2; a++) begin
          int unsigned tile_idx_v;

          tile_idx_v = upd_tindex[a];

          if (upd_meta_valid[a]) begin
            tile_wptr[tile_idx_v] <= tile_wptr[tile_idx_v] + TILE_FIFO_ADDR_WIDTH'(1);
          end

          if (upd_trltl_valid[a]) begin
            trail_tid[tile_idx_v] <= {1'b1, upd_trltl[a]};
          end

          if (upd_bdytl_valid[a]) begin
            body_tid[tile_idx_v][TILE_ID_WIDTH-1:0] <= upd_bdytl[a];
          end

          if (upd_hcmpl[a]) begin
            tile_pkt_wcnt[tile_idx_v] <= tile_pkt_wcnt[tile_idx_v] + TILE_PKT_CNT_WIDTH'(1);
          end
        end

        upd_valid <= '0;
        upd_meta_valid <= '0;
        upd_trltl_valid <= '0;
        upd_bdytl_valid <= '0;
        upd_hcmpl <= '0;
        tracker_state <= TRACKER_IDLING;
      end

      TRACKER_RESETTING: begin
        tile_wptr <= '0;
        tile_pkt_wcnt <= '0;
        trail_tid <= '0;
        body_tid <= '0;
        upd_valid <= '0;
        upd_meta_valid <= '0;
        upd_trltl_valid <= '0;
        upd_bdytl_valid <= '0;
        upd_hcmpl <= '0;
        tracker_state <= TRACKER_IDLING;
      end

      default: begin
      end
    endcase

    if (i_void_body_tid) begin
      body_tid[i_rseg_tile_index][TILE_ID_WIDTH] <= 1'b0;
    end

    if (i_void_trail_tid) begin
      trail_tid[i_rseg_tile_index][TILE_ID_WIDTH] <= 1'b0;
    end

    if (d_reset) begin
      tracker_state <= TRACKER_RESETTING;
    end
  end

  property p_reset_enters_tracker_resetting;
    @(posedge d_clk) d_reset |=> (tracker_state == TRACKER_RESETTING);
  endproperty
  ap_reset_enters_tracker_resetting: assert property (p_reset_enters_tracker_resetting);

`ifdef OPQ_ENABLE_NATIVE_FORMAL_FTABLE
  opq_native_frame_table_tracker_formal_sva #(
    .N_TILE(N_TILE),
    .TILE_FIFO_DEPTH(TILE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .TILE_PKT_CNT_WIDTH(TILE_PKT_CNT_WIDTH)
  ) native_formal_sva_i (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .i_update_ftable_valid(i_update_ftable_valid),
    .i_update_ftable_tindex(i_update_ftable_tindex),
    .i_flush_ftable_valid(i_flush_ftable_valid),
    .i_tile_rptr(i_tile_rptr),
    .i_tile_pkt_rcnt(i_tile_pkt_rcnt),
    .o_tile_fifo_we(o_tile_fifo_we),
    .o_tile_wptr(o_tile_wptr),
    .o_tile_pkt_wcnt(o_tile_pkt_wcnt),
    .o_trail_tid(o_trail_tid),
    .o_body_tid(o_body_tid)
  );
`endif
endmodule
