//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_frame_table_presenter
// Version : 26.1.0
// Date    : 20260413
// Change  : Add standalone SV translation of the frame-table presenter block
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_frame_table_presenter #(
  parameter int unsigned N_TILE = 5,
  parameter int unsigned N_WR_SEG = 4,
  parameter int unsigned TILE_FIFO_DEPTH = 512,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned TILE_PKT_CNT_WIDTH = 10,
  parameter int unsigned EGRESS_DELAY = 2,
  parameter int unsigned DEBUG_LV = 1
) (
  input  logic                                                 d_clk,
  input  logic                                                 d_reset,
  input  logic [N_WR_SEG-1:0][$clog2(N_TILE)-1:0]              i_wseg_tile_index,
  input  logic [$clog2(N_TILE)-1:0]                            i_leading_wr_tile_index_reg,
  input  logic                                                 i_mapper_busy,
  input  logic                                                 i_pa_write_head_start,
  input  logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       i_tile_wptr,
  input  logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]            i_tile_pkt_wcnt,
  input  logic [N_TILE-1:0][$clog2(N_TILE):0]                  i_trail_tid,
  input  logic [N_TILE-1:0][$clog2(N_TILE):0]                  i_body_tid,
  input  logic [N_TILE-1:0][2*$clog2(PAGE_RAM_DEPTH)-1:0]      i_tile_fifo_rd_data,
  input  logic [N_TILE-1:0][PAGE_RAM_DATA_WIDTH-1:0]           i_page_tile_rd_data,
  input  logic                                                 i_egress_ready,
  output logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       o_tile_fifo_rd_addr,
  output logic [N_TILE-1:0][$clog2(PAGE_RAM_DEPTH)-1:0]        o_page_tile_rd_addr,
  output logic [N_TILE-1:0][$clog2(TILE_FIFO_DEPTH)-1:0]       o_tile_rptr,
  output logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0]            o_tile_pkt_rcnt,
  output logic [$clog2(N_TILE)-1:0]                            o_rseg_tile_index,
  output logic                                                 o_void_trail_tid,
  output logic                                                 o_void_body_tid,
  output logic                                                 o_presenter_active,
  output logic                                                 o_presenter_warping,
  output logic                                                 o_is_rd_tile_in_range,
  output logic                                                 o_crossing_tile_valid,
  output logic [$clog2(N_TILE)-1:0]                            o_crossing_tile,
  output logic                                                 o_trailing_active0,
  output logic [$clog2(N_TILE)-1:0]                            o_trailing_tile_index,
  output logic [2:0]                                           o_state,
  output logic                                                 o_egress_valid,
  output logic [PAGE_RAM_DATA_WIDTH-1:0]                       o_egress_data,
  output logic                                                 o_egress_startofpacket,
  output logic                                                 o_egress_endofpacket
);
  localparam int unsigned TILE_ID_WIDTH = $clog2(N_TILE);
  localparam int unsigned TILE_FIFO_ADDR_WIDTH = $clog2(TILE_FIFO_DEPTH);
  localparam int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;

  typedef enum logic [2:0] {
    PRESENTER_IDLING,
    PRESENTER_WAITING_FOR_COMPLETE,
    PRESENTER_VERIFYING,
    PRESENTER_PRESENTING,
    PRESENTER_RESTARTING,
    PRESENTER_WARPING,
    PRESENTER_RESETTING
  } presenter_state_t;

  presenter_state_t presenter_state;
  logic [N_TILE-1:0][TILE_FIFO_ADDR_WIDTH-1:0] tile_rptr;
  logic [N_TILE-1:0][TILE_PKT_CNT_WIDTH-1:0] tile_pkt_rcnt;
  logic [TILE_ID_WIDTH-1:0] rseg_tile_index;
  logic [N_TILE-1:0][PAGE_RAM_ADDR_WIDTH-1:0] page_ram_rptr;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] leading_header_addr;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] packet_length;
  logic crossing_tile_valid;
  logic [TILE_ID_WIDTH-1:0] crossing_tile;
  logic [EGRESS_DELAY:0] trailing_active;
  logic [TILE_ID_WIDTH-1:0] trailing_tile_index;
  logic [EGRESS_DELAY:0] output_data_valid;
  logic [PAGE_RAM_DATA_WIDTH-1:0] output_data;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] pkt_rd_word_cnt;
  logic [N_TILE-1:0][PAGE_RAM_DATA_WIDTH-1:0] page_tile_rd_data_reg;
  logic [N_TILE-1:0][PAGE_RAM_DATA_WIDTH-1:0] page_tile_rd_data_skid;
  logic page_tile_skid_valid;
  logic is_new_pkt_head;
  logic is_new_pkt_complete;
  logic is_rd_tile_in_range;
  logic [TILE_ID_WIDTH-1:0] in_range_warp_rd_tile;
  logic is_pkt_spilling;
  logic output_is_trailer;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_rd_data;
  logic void_trail_tid;
  logic void_body_tid;

  assign o_tile_rptr = tile_rptr;
  assign o_tile_pkt_rcnt = tile_pkt_rcnt;
  assign o_rseg_tile_index = rseg_tile_index;
  assign o_void_trail_tid = void_trail_tid;
  assign o_void_body_tid = void_body_tid;
  assign o_crossing_tile_valid = crossing_tile_valid;
  assign o_crossing_tile = crossing_tile;
  assign o_trailing_active0 = trailing_active[0];
  assign o_trailing_tile_index = trailing_tile_index;
  assign o_presenter_warping = (presenter_state == PRESENTER_WARPING);
  assign o_presenter_active =
    (presenter_state == PRESENTER_PRESENTING) ||
    (presenter_state == PRESENTER_RESTARTING) ||
    ((presenter_state == PRESENTER_WAITING_FOR_COMPLETE) && is_new_pkt_complete);
  assign o_is_rd_tile_in_range = is_rd_tile_in_range;

  always_comb begin : proc_state_code
    unique case (presenter_state)
      PRESENTER_IDLING: o_state = 3'b000;
      PRESENTER_WAITING_FOR_COMPLETE: o_state = 3'b001;
      PRESENTER_VERIFYING: o_state = 3'b010;
      PRESENTER_PRESENTING: o_state = 3'b011;
      PRESENTER_RESTARTING: o_state = 3'b100;
      PRESENTER_WARPING: o_state = 3'b101;
      PRESENTER_RESETTING: o_state = 3'b110;
      default: o_state = 3'b111;
    endcase
  end

  assign o_egress_valid = output_data_valid[EGRESS_DELAY];
  assign o_egress_data = output_data;
  assign o_egress_startofpacket =
    o_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K285);
  assign o_egress_endofpacket =
    o_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K284);
  assign output_is_trailer = o_egress_endofpacket;

  genvar i;
  generate
    for (i = 0; i < N_TILE; i = i + 1) begin : g_tile_rd_addr
    assign o_tile_fifo_rd_addr[i] = tile_rptr[i];
    assign o_page_tile_rd_addr[i] = page_ram_rptr[i];
    end
  endgenerate

  always_comb begin : proc_page_ram_rd_data
    int unsigned sel_idx_v;

    if (trailing_active[EGRESS_DELAY]) begin
      sel_idx_v = trailing_tile_index;
    end else begin
      sel_idx_v = rseg_tile_index;
    end
    page_ram_rd_data = page_tile_rd_data_reg[sel_idx_v];
  end

  always_comb begin : proc_flags
    int unsigned rseg_idx_v;
    int unsigned warp_seg_v;
    int unsigned spill_sum_v;

    rseg_idx_v = rseg_tile_index;
    is_new_pkt_head = (i_tile_wptr[rseg_idx_v] != tile_rptr[rseg_idx_v]);
    is_new_pkt_complete = (i_tile_pkt_wcnt[rseg_idx_v] != tile_pkt_rcnt[rseg_idx_v]);

    is_rd_tile_in_range = 1'b0;
    for (int s = 0; s < N_WR_SEG; s++) begin
      if (i_wseg_tile_index[s] == rseg_tile_index) begin
        is_rd_tile_in_range = 1'b1;
      end
    end

    warp_seg_v = 0;
    for (int s = N_WR_SEG - 2; s >= 0; s--) begin
      if (rseg_tile_index == i_wseg_tile_index[s]) begin
        warp_seg_v = s + 1;
      end
    end
    in_range_warp_rd_tile = i_wseg_tile_index[warp_seg_v];

    spill_sum_v = leading_header_addr + packet_length;
    is_pkt_spilling = (spill_sum_v >= PAGE_RAM_DEPTH);
  end

  always_ff @(posedge d_clk) begin : proc_presenter
    bit any_tile_has_head_v;
    int unsigned rseg_idx_v;
    int unsigned cross_idx_v;

    void_trail_tid <= 1'b0;
    void_body_tid <= 1'b0;

    any_tile_has_head_v = 1'b0;
    for (int t = 0; t < N_TILE; t++) begin
      if (i_tile_wptr[t] != tile_rptr[t]) begin
        any_tile_has_head_v = 1'b1;
      end
    end
    rseg_idx_v = rseg_tile_index;

    unique case (presenter_state)
      PRESENTER_IDLING: begin
        output_data_valid <= '0;
        trailing_active[0] <= 1'b0;
        crossing_tile_valid <= 1'b0;

        if (is_new_pkt_head) begin
          presenter_state <= PRESENTER_WAITING_FOR_COMPLETE;
        end else if (rseg_tile_index == i_leading_wr_tile_index_reg) begin
        end else if (any_tile_has_head_v && !is_new_pkt_head) begin
          if (!i_mapper_busy && !i_pa_write_head_start) begin
            tile_rptr[rseg_idx_v] <= i_tile_wptr[rseg_idx_v];
            tile_pkt_rcnt[rseg_idx_v] <= '0;

            if (is_rd_tile_in_range) begin
              rseg_tile_index <= in_range_warp_rd_tile;
            end else begin
              rseg_tile_index <= i_wseg_tile_index[0];
            end
            presenter_state <= PRESENTER_WARPING;
          end
        end
      end

      PRESENTER_WARPING: begin
        presenter_state <= PRESENTER_IDLING;
      end

      PRESENTER_WAITING_FOR_COMPLETE: begin
        if (!is_new_pkt_head) begin
          presenter_state <= PRESENTER_IDLING;
        end else if (is_new_pkt_complete) begin
          leading_header_addr <= i_tile_fifo_rd_data[rseg_idx_v][PAGE_RAM_ADDR_WIDTH-1:0];
          packet_length <= i_tile_fifo_rd_data[rseg_idx_v][2*PAGE_RAM_ADDR_WIDTH-1:PAGE_RAM_ADDR_WIDTH];
          page_ram_rptr[rseg_idx_v] <= i_tile_fifo_rd_data[rseg_idx_v][PAGE_RAM_ADDR_WIDTH-1:0];
          pkt_rd_word_cnt <= '0;
          output_data_valid <= '0;
          trailing_active <= '0;
          crossing_tile_valid <= 1'b0;

          if ((i_tile_fifo_rd_data[rseg_idx_v][PAGE_RAM_ADDR_WIDTH-1:0] +
               i_tile_fifo_rd_data[rseg_idx_v][2*PAGE_RAM_ADDR_WIDTH-1:PAGE_RAM_ADDR_WIDTH]) >= PAGE_RAM_DEPTH) begin
            crossing_tile <= i_trail_tid[rseg_idx_v][TILE_ID_WIDTH-1:0];
            presenter_state <= PRESENTER_VERIFYING;
          end else begin
            presenter_state <= PRESENTER_PRESENTING;
          end
        end
      end

      PRESENTER_VERIFYING: begin
        cross_idx_v = crossing_tile;
        if (i_body_tid[cross_idx_v][TILE_ID_WIDTH-1:0] == rseg_tile_index) begin
          crossing_tile_valid <= 1'b1;
          presenter_state <= PRESENTER_PRESENTING;
        end else begin
          tile_pkt_rcnt[rseg_idx_v] <= tile_pkt_rcnt[rseg_idx_v] + TILE_PKT_CNT_WIDTH'(1);
          tile_rptr[rseg_idx_v] <= tile_rptr[rseg_idx_v] + TILE_FIFO_ADDR_WIDTH'(1);
          crossing_tile_valid <= 1'b0;
          presenter_state <= PRESENTER_IDLING;
        end
      end

      PRESENTER_PRESENTING: begin
        if (output_data_valid[EGRESS_DELAY] && !i_egress_ready) begin
          if (!page_tile_skid_valid) begin
            page_tile_rd_data_skid <= i_page_tile_rd_data;
            page_tile_skid_valid <= 1'b1;
          end
        end else begin
          output_data_valid[0] <= 1'b1;
          for (int d = 0; d < EGRESS_DELAY; d++) begin
            output_data_valid[d+1] <= output_data_valid[d];
          end
          output_data <= page_ram_rd_data;

          if (output_data_valid[EGRESS_DELAY] && i_egress_ready) begin
            pkt_rd_word_cnt <= pkt_rd_word_cnt + PAGE_RAM_ADDR_WIDTH'(1);
          end

          if (trailing_active[0]) begin
            page_ram_rptr[trailing_tile_index] <= page_ram_rptr[trailing_tile_index] + PAGE_RAM_ADDR_WIDTH'(1);
          end else if (is_pkt_spilling && (page_ram_rptr[rseg_idx_v] == PAGE_RAM_ADDR_WIDTH'(PAGE_RAM_DEPTH - 1))) begin
            trailing_active[0] <= 1'b1;
            trailing_tile_index <= crossing_tile;
            page_ram_rptr[rseg_idx_v] <= '0;
            page_ram_rptr[crossing_tile] <= '0;
          end else begin
            page_ram_rptr[rseg_idx_v] <= page_ram_rptr[rseg_idx_v] + PAGE_RAM_ADDR_WIDTH'(1);
          end
        end

        if (output_data_valid[EGRESS_DELAY] && i_egress_ready) begin
          if (output_is_trailer) begin
            presenter_state <= PRESENTER_IDLING;
            output_data_valid <= '0;

            if (trailing_active[0]) begin
              trailing_active[0] <= 1'b0;
              void_body_tid <= 1'b1;
              crossing_tile_valid <= 1'b0;
            end

            if (i_tile_wptr[rseg_idx_v] != tile_rptr[rseg_idx_v]) begin
              tile_pkt_rcnt[rseg_idx_v] <= tile_pkt_rcnt[rseg_idx_v] + TILE_PKT_CNT_WIDTH'(1);
              tile_rptr[rseg_idx_v] <= tile_rptr[rseg_idx_v] + TILE_FIFO_ADDR_WIDTH'(1);
            end
          end
        end
      end

      PRESENTER_RESTARTING: begin
        presenter_state <= PRESENTER_PRESENTING;
      end

      PRESENTER_RESETTING: begin
        presenter_state <= PRESENTER_IDLING;
        tile_rptr <= '0;
        tile_pkt_rcnt <= '0;
        rseg_tile_index <= '0;
        page_ram_rptr <= '0;
        leading_header_addr <= '0;
        packet_length <= '0;
        crossing_tile_valid <= 1'b0;
        crossing_tile <= '0;
        trailing_active <= '0;
        trailing_tile_index <= '0;
        output_data_valid <= '0;
        output_data <= '0;
        pkt_rd_word_cnt <= '0;
        page_tile_rd_data_reg <= '0;
        page_tile_rd_data_skid <= '0;
        page_tile_skid_valid <= 1'b0;
      end

      default: begin
      end
    endcase

    if (i_egress_ready || !output_data_valid[EGRESS_DELAY]) begin
      if (page_tile_skid_valid) begin
        page_tile_rd_data_reg <= page_tile_rd_data_skid;
        page_tile_skid_valid <= 1'b0;
      end else begin
        page_tile_rd_data_reg <= i_page_tile_rd_data;
      end
    end

    if (i_egress_ready || !output_data_valid[EGRESS_DELAY]) begin
      for (int d = 0; d < EGRESS_DELAY; d++) begin
        trailing_active[d+1] <= trailing_active[d];
      end
    end

    if (d_reset) begin
      presenter_state <= PRESENTER_RESETTING;
    end
  end

  property p_reset_enters_presenter_resetting;
    @(posedge d_clk) d_reset |=> (presenter_state == PRESENTER_RESETTING);
  endproperty
  ap_reset_enters_presenter_resetting: assert property (p_reset_enters_presenter_resetting);

  property p_hold_output_stable_on_backpressure;
    @(posedge d_clk) disable iff (d_reset)
      (o_egress_valid && !i_egress_ready) |=> $stable(o_egress_data);
  endproperty
  ap_hold_output_stable_on_backpressure: assert property (p_hold_output_stable_on_backpressure);

`ifdef OPQ_ENABLE_NATIVE_FORMAL_FTABLE
  opq_native_frame_table_presenter_formal_sva #(
    .N_TILE(N_TILE),
    .TILE_FIFO_DEPTH(TILE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .TILE_PKT_CNT_WIDTH(TILE_PKT_CNT_WIDTH),
    .EGRESS_DELAY(EGRESS_DELAY)
  ) native_formal_sva_i (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .i_egress_ready(i_egress_ready),
    .o_tile_rptr(o_tile_rptr),
    .o_tile_pkt_rcnt(o_tile_pkt_rcnt),
    .o_rseg_tile_index(o_rseg_tile_index),
    .o_egress_valid(o_egress_valid),
    .o_egress_data(o_egress_data),
    .o_egress_startofpacket(o_egress_startofpacket),
    .o_egress_endofpacket(o_egress_endofpacket),
    .o_state(o_state),
    .page_ram_rptr(page_ram_rptr),
    .pkt_rd_word_cnt(pkt_rd_word_cnt)
  );
`endif
endmodule
