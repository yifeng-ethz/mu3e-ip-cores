//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_block_path
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.4.15-syn
// Date    : 20260428
// Change  : Align fixed4 synthesis copy to the registered mover page-write
//           stage used by the maintained native-SV RTL.
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_block_path #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned CHANNEL_WIDTH = 2,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned LANE_FIFO_WIDTH = 40,
  parameter int unsigned HANDLE_FIFO_DEPTH = 64,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT,
  parameter int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH),
  parameter int unsigned FIFO_RAW_DELAY = 2,
  parameter int unsigned FIFO_RD_DELAY = 1,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned HANDLE_FIFO_ADDR_WIDTH = $clog2(HANDLE_FIFO_DEPTH),
  parameter int unsigned HANDLE_LENGTH = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS
) (
  input  logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]    handle_wptr_i,
  input  logic [N_LANE-1:0]                                handle_we_i,
  input  logic [N_LANE-1:0][HANDLE_LENGTH:0]               handle_fifos_rd_data_i,
  input  logic [N_LANE-1:0][LANE_FIFO_WIDTH-1:0]           lane_fifos_rd_data_i,
  input  logic                                             fetch_ticket_active_i,
  input  logic                                             page_allocator_alloc_page_i,
  input  logic [N_LANE-1:0]                                tk_future_i,
  input  logic                                             page_allocator_write_head_i,
  input  logic                                             page_allocator_write_tail_i,
  input  logic                                             page_allocator_write_page_i,
  input  logic                                             page_allocator_page_we_i,
  input  logic [PAGE_RAM_ADDR_WIDTH-1:0]                   page_allocator_page_waddr_i,
  input  logic [PAGE_RAM_DATA_WIDTH-1:0]                   page_allocator_page_wdata_i,
  input  logic [N_LANE-1:0][9:0]                           drr_allowance_i,
  input  logic [N_LANE-1:0]                                drr_allowance_reload_i,
  output logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]    handle_fifos_rd_addr_o,
  output logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0]      lane_fifos_rd_addr_o,
  output logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0]      lane_credit_update_o,
  output logic [N_LANE-1:0]                                lane_credit_update_valid_o,
  output logic                                             payload_commit_idle_o,
  output logic                                             page_ram_we_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                   page_ram_wr_addr_o,
  output logic [PAGE_RAM_DATA_WIDTH-1:0]                   page_ram_wr_data_o,
  output logic [N_LANE-1:0][9:0]                           drr_quantum_dbg_o,
  output logic [N_LANE-1:0]                                drr_req_dbg_o,
  output logic [N_LANE-1:0]                                drr_gnt_dbg_o,
  output logic [N_LANE-1:0]                                drr_lock_event_dbg_o,
  output logic [N_LANE-1:0]                                drr_defer_event_dbg_o,
  output logic [N_LANE-1:0]                                drr_sel_mask_dbg_o,
`ifdef OPQ_OSS_FORMAL
  output logic [N_LANE-1:0]                                req_raw_dbg_oss,
  output logic [N_LANE-1:0]                                req_eligible_dbg_oss,
  output logic [N_LANE-1:0]                                gnt_dbg_oss,
  output logic [N_LANE-1:0]                                sel_mask_dbg_oss,
  output logic [N_LANE-1:0]                                priority_mask_dbg_oss,
  output logic [N_LANE-1:0]                                lock_event_dbg_oss,
  output logic [N_LANE-1:0]                                defer_event_dbg_oss,
  output logic [N_LANE-1:0]                                lock_req_raw_dbg_oss,
  output logic [N_LANE-1:0]                                lock_req_eligible_dbg_oss,
  output logic [N_LANE-1:0]                                defer_req_raw_dbg_oss,
  output logic [N_LANE-1:0]                                defer_req_eligible_dbg_oss,
  output logic                                             locked_dbg_oss,
  output logic                                             page_ram_src_is_pa_dbg_oss,
  output logic [N_LANE-1:0]                                page_ram_src_lane_dbg_oss,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                   page_ram_src_addr_dbg_oss,
  output logic [PAGE_RAM_DATA_WIDTH-1:0]                   page_ram_src_data_dbg_oss,
  output logic                                             page_ram_src_valid_comb_dbg_oss,
  output logic                                             page_ram_src_is_pa_comb_dbg_oss,
  output logic [N_LANE-1:0]                                page_ram_src_lane_comb_dbg_oss,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                   page_ram_src_addr_comb_dbg_oss,
  output logic [PAGE_RAM_DATA_WIDTH-1:0]                   page_ram_src_data_comb_dbg_oss,
`endif
  input  logic                                             d_clk,
  input  logic                                             d_reset
);
  localparam int unsigned LANE_FIFO_MAX_CREDIT = LANE_FIFO_DEPTH - 2;
  localparam logic [9:0] QUANTUM_PER_SUBFRAME = 10'd256;
  localparam logic [9:0] QUANTUM_MAX = 10'h3ff;
  localparam int unsigned HANDLE_SRC_LO = 0;
  localparam int unsigned HANDLE_SRC_HI = LANE_FIFO_ADDR_WIDTH - 1;
  localparam int unsigned HANDLE_DST_LO = LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned HANDLE_DST_HI = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH - 1;
  localparam int unsigned HANDLE_LEN_LO = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH;
  localparam int unsigned HANDLE_LEN_HI = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS - 1;

`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
  bit opq_trace_boundary_en;
  time opq_trace_after_ps;

  initial begin
    opq_trace_boundary_en = $test$plusargs("OPQ_NATIVE_TRACE_BOUNDARY");
    opq_trace_after_ps = 0;
    void'($value$plusargs("OPQ_TRACE_AFTER_PS=%d", opq_trace_after_ps));
  end
`endif
`endif

  function automatic logic [N_LANE-1:0] rr_grant(
    input logic [N_LANE-1:0] req,
    input logic [N_LANE-1:0] priority_mask
  );
    logic [2*N_LANE-1:0] result0;
    logic [2*N_LANE-1:0] result0p5;
    logic [2*N_LANE-1:0] result1;
    logic [2*N_LANE-1:0] result2;
    begin
      result0 = {req, req};
      result0p5 = {~req, ~req};
      result1 = result0p5 + priority_mask;
      result2 = result0 & result1;
      if (|result2[N_LANE-1:0]) begin
        rr_grant = result2[N_LANE-1:0];
      end else begin
        rr_grant = result2[2*N_LANE-1:N_LANE];
      end
    end
  endfunction

  function automatic logic [9:0] sat_add_quantum(
    input logic [9:0] lhs,
    input logic [9:0] rhs
  );
    logic [10:0] sum_v;
    begin
      sum_v = {1'b0, lhs} + {1'b0, rhs};
      if (sum_v[10]) begin
        sat_add_quantum = QUANTUM_MAX;
      end else begin
        sat_add_quantum = sum_v[9:0];
      end
    end
  endfunction

  typedef logic [LANE_FIFO_ADDR_WIDTH-1:0] lane_fifo_addr_t;
  typedef logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_addr_t;
  typedef logic [HANDLE_FIFO_ADDR_WIDTH-1:0] handle_fifo_addr_t;
  typedef logic [MAX_PKT_LENGTH_BITS-1:0] pkt_length_t;

  typedef enum logic [2:0] {
    BLOCK_MOVER_IDLE,
    BLOCK_MOVER_PREP,
    BLOCK_MOVER_WRITE_BLK,
    BLOCK_MOVER_ABORT_WRITE_BLK,
    BLOCK_MOVER_RESET
  } block_mover_state_t;

  typedef logic [FIFO_RD_DELAY:1][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_rptr_d_t;

  typedef logic [N_LANE-1:0][9:0] quantum_t;

  typedef enum logic [1:0] {
    ARBITER_IDLE,
    ARBITER_LOCKING,
    ARBITER_LOCKED,
    ARBITER_RESET
  } arbiter_state_t;

  typedef struct packed {
    logic [N_LANE-1:0] sel_mask;
    logic [N_LANE-1:0] priority_mask;
    quantum_t          quantum;
  } b2p_arb_t;

  localparam b2p_arb_t B2P_ARB_REG_RESET = '0;

  block_mover_state_t block_mover_state [N_LANE];
  logic [N_LANE-1:0][FIFO_RAW_DELAY:1] handle_fifo_is_pending_handle_d;
  logic [N_LANE-1:0] handle_fifo_is_pending_handle;
  logic [N_LANE-1:0] handle_fifo_is_pending_handle_valid;
  logic [N_LANE-1:0] handle_fifo_is_q_valid;
  lane_fifo_addr_t   handle_fifo_if_rd_src [N_LANE];
  page_ram_addr_t    handle_fifo_if_rd_dst [N_LANE];
  pkt_length_t       handle_fifo_if_rd_blk_len [N_LANE];
  logic [N_LANE-1:0] handle_fifo_if_rd_flag;
  pkt_length_t       block_mover_word_wr_cnt [N_LANE];
  lane_fifo_addr_t   block_mover_lane_rd_addr [N_LANE];
  lane_fifo_addr_t   block_mover_handle_src [N_LANE];
  page_ram_addr_t    block_mover_handle_dst [N_LANE];
  pkt_length_t       block_mover_handle_blk_len [N_LANE];
  logic [N_LANE-1:0] block_mover_flag;
  logic [N_LANE-1:0] block_mover_final_word_q;
  handle_fifo_addr_t block_mover_handle_rptr [N_LANE];
  handle_rptr_d_t    block_mover_handle_rptr_d [N_LANE];
  page_ram_addr_t    block_mover_page_wptr [N_LANE];
  logic [N_LANE-1:0] block_mover_page_wreq;
  lane_fifo_addr_t   block_mover_lane_credit_update [N_LANE];
  logic [N_LANE-1:0] block_mover_lane_credit_update_valid;
  logic [N_LANE-1:0] block_mover_reset_done;
  logic [N_LANE-1:0] b2p_arb_req_raw;
  logic [N_LANE-1:0] b2p_arb_req_raw_q;
  logic [N_LANE-1:0] b2p_arb_req_eligible_comb;
  logic [N_LANE-1:0] b2p_arb_req_eligible_q;
  logic [N_LANE-1:0] b2p_arb_req_eligible;
  logic [N_LANE-1:0] b2p_arb_pick;
  logic [N_LANE-1:0] b2p_arb_pick_q;
  logic [N_LANE-1:0] b2p_arb_req_raw_qq;
  logic [N_LANE-1:0] b2p_arb_req_eligible_qq;
  logic [N_LANE-1:0] b2p_arb_gnt;
  logic [N_LANE-1:0] b2p_arb_gnt_q;
  logic [N_LANE-1:0] b2p_arb_commit;
  logic [N_LANE-1:0] b2p_arb_commit_q;
  logic [N_LANE-1:0] b2p_arb_commit_final;
  logic [N_LANE-1:0] drr_lock_event_dbg;
  logic [N_LANE-1:0] drr_defer_event_dbg;
  quantum_t          b2p_arb_quantum_update_if_updating;
  arbiter_state_t    arbiter_state;
  b2p_arb_t          b2p_arb;
  logic              page_allocator_direct_write;
  logic              page_allocator_capture_busy;
  logic              page_allocator_write_busy;
  logic              page_allocator_page_we_q;
  logic              page_allocator_page_write_pending_q;
  page_ram_addr_t    page_allocator_page_waddr_q;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_page_wdata_q;
  logic              mover_page_output_fire;
  logic              mover_page_stage_accepting;
  logic [N_LANE-1:0] mover_page_pending_q;
  page_ram_addr_t    mover_page_waddr_sel_q;
  logic [N_LANE-1:0][PAGE_RAM_DATA_WIDTH-1:0] mover_page_wdata_q;
  logic              page_ram_we_comb;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_wr_addr_comb;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_wr_data_comb;
  logic              payload_commit_idle_comb;

  assign drr_quantum_dbg_o = b2p_arb.quantum;
  assign drr_req_dbg_o = b2p_arb_req_raw;
  assign drr_gnt_dbg_o = b2p_arb_gnt;
  assign drr_lock_event_dbg_o = drr_lock_event_dbg;
  assign drr_defer_event_dbg_o = drr_defer_event_dbg;
  assign drr_sel_mask_dbg_o = b2p_arb.sel_mask;

  assign page_allocator_direct_write = page_allocator_write_page_i ||
    page_allocator_write_head_i ||
    page_allocator_write_tail_i;
  assign page_allocator_capture_busy = page_allocator_direct_write ||
    page_allocator_page_we_i ||
    page_allocator_page_write_pending_q;
  assign page_allocator_write_busy = page_allocator_page_write_pending_q;
  assign mover_page_output_fire =
    !page_allocator_page_write_pending_q && (mover_page_pending_q != '0);
  assign mover_page_stage_accepting =
    (mover_page_pending_q == '0) || mover_page_output_fire;

  always_comb begin : proc_block_mover_comb
    payload_commit_idle_comb =
      !(fetch_ticket_active_i ||
        page_allocator_alloc_page_i ||
        page_allocator_capture_busy ||
        (|b2p_arb_gnt_q) ||
        (|b2p_arb_commit_q) ||
        (|mover_page_pending_q));
    for (int i = 0; i < N_LANE; i++) begin
      b2p_arb_commit_final[i] =
        b2p_arb_commit_q[i] &&
        block_mover_final_word_q[i];
      b2p_arb_commit[i] =
        b2p_arb_gnt_q[i] &&
        !b2p_arb_commit_final[i] &&
        !page_allocator_capture_busy &&
        mover_page_stage_accepting;
      handle_fifo_is_pending_handle[i] = 1'b0;
      handle_fifo_is_pending_handle_valid[i] = 1'b0;
      handle_fifo_is_q_valid[i] = 1'b0;
      lane_fifos_rd_addr_o[i] = '0;
      handle_fifos_rd_addr_o[i] = block_mover_handle_rptr[i];
      handle_fifo_if_rd_src[i] = handle_fifos_rd_data_i[i][HANDLE_SRC_HI:HANDLE_SRC_LO];
      handle_fifo_if_rd_dst[i] = handle_fifos_rd_data_i[i][HANDLE_DST_HI:HANDLE_DST_LO];
      handle_fifo_if_rd_blk_len[i] = handle_fifos_rd_data_i[i][HANDLE_LEN_HI:HANDLE_LEN_LO];
      handle_fifo_if_rd_flag[i] = handle_fifos_rd_data_i[i][HANDLE_LENGTH];
      lane_credit_update_o[i] = block_mover_lane_credit_update[i];
      lane_credit_update_valid_o[i] = block_mover_lane_credit_update_valid[i];

      if (handle_wptr_i[i] != block_mover_handle_rptr[i]) begin
        handle_fifo_is_pending_handle[i] = 1'b1;
      end
      if (handle_we_i[i] && ((handle_wptr_i[i] - handle_fifo_addr_t'(1)) == block_mover_handle_rptr[i])) begin
        handle_fifo_is_pending_handle[i] = 1'b0;
      end
      if ((&handle_fifo_is_pending_handle_d[i]) && handle_fifo_is_pending_handle[i]) begin
        handle_fifo_is_pending_handle_valid[i] = 1'b1;
      end
      if (block_mover_handle_rptr_d[i][FIFO_RD_DELAY] == block_mover_handle_rptr[i]) begin
        handle_fifo_is_q_valid[i] = 1'b1;
      end

      lane_fifos_rd_addr_o[i] = block_mover_lane_rd_addr[i];
      if (b2p_arb_commit_q[i]) begin
        lane_fifos_rd_addr_o[i] = block_mover_lane_rd_addr[i] + lane_fifo_addr_t'(1);
      end

      b2p_arb_req_raw[i] =
        block_mover_page_wreq[i] &&
        !page_allocator_write_busy &&
        mover_page_stage_accepting;
      if (b2p_arb.quantum[i] >= 10'(block_mover_handle_blk_len[i])) begin
        b2p_arb_req_eligible_comb[i] = b2p_arb_req_raw[i];
      end else begin
        b2p_arb_req_eligible_comb[i] = 1'b0;
      end

      if ((QUANTUM_MAX - b2p_arb.quantum[i]) >= drr_allowance_i[i]) begin
        b2p_arb_quantum_update_if_updating[i] = drr_allowance_i[i];
      end else if (b2p_arb_commit_q[i]) begin
        b2p_arb_quantum_update_if_updating[i] = QUANTUM_MAX - b2p_arb.quantum[i] + 10'd1;
      end else begin
        b2p_arb_quantum_update_if_updating[i] = QUANTUM_MAX - b2p_arb.quantum[i];
      end

      if (handle_we_i[i] ||
          handle_fifo_is_pending_handle[i] ||
          block_mover_page_wreq[i] ||
          (block_mover_state[i] != BLOCK_MOVER_IDLE)) begin
        payload_commit_idle_comb = 1'b0;
      end
    end
  end

  always_comb begin : proc_b2p_arbiter_comb
    b2p_arb_req_eligible = b2p_arb_req_eligible_q & b2p_arb_req_raw_q;
    b2p_arb_pick = rr_grant(b2p_arb_req_eligible, b2p_arb.priority_mask);
    b2p_arb_gnt = '0;
    if (arbiter_state == ARBITER_LOCKED) begin
      b2p_arb_gnt = b2p_arb.sel_mask & b2p_arb_req_raw & ~b2p_arb_commit_final;
    end
    if (page_allocator_write_busy) begin
      b2p_arb_pick = '0;
      b2p_arb_gnt = '0;
    end

    page_ram_we_comb = 1'b0;
    page_ram_wr_addr_comb = mover_page_waddr_sel_q;
    page_ram_wr_data_comb = '0;

    if (page_allocator_page_write_pending_q) begin
      page_ram_we_comb = page_allocator_page_we_q;
      page_ram_wr_addr_comb = page_allocator_page_waddr_q;
      page_ram_wr_data_comb = page_allocator_page_wdata_q;
    end else if (mover_page_pending_q != '0) begin
      for (int i = 0; i < N_LANE; i++) begin
        if (mover_page_pending_q[i]) begin
          page_ram_we_comb = 1'b1;
          page_ram_wr_data_comb = mover_page_wdata_q[i];
        end
      end
    end

`ifdef OPQ_OSS_FORMAL
    req_raw_dbg_oss = b2p_arb_req_raw;
    req_eligible_dbg_oss = b2p_arb_req_eligible;
    gnt_dbg_oss = b2p_arb_gnt;
    sel_mask_dbg_oss = b2p_arb.sel_mask;
    priority_mask_dbg_oss = b2p_arb.priority_mask;
    lock_event_dbg_oss = drr_lock_event_dbg;
    defer_event_dbg_oss = drr_defer_event_dbg;
    locked_dbg_oss = (arbiter_state == ARBITER_LOCKED);
    page_ram_src_valid_comb_dbg_oss = page_ram_we_comb;
    page_ram_src_is_pa_comb_dbg_oss = 1'b0;
    page_ram_src_lane_comb_dbg_oss = '0;
    page_ram_src_addr_comb_dbg_oss = page_ram_wr_addr_comb;
    page_ram_src_data_comb_dbg_oss = page_ram_wr_data_comb;
    if (page_ram_we_comb) begin
      if (page_allocator_page_write_pending_q) begin
        page_ram_src_is_pa_comb_dbg_oss = 1'b1;
      end else begin
        page_ram_src_lane_comb_dbg_oss = mover_page_pending_q;
      end
    end
`endif
  end

  always_ff @(posedge d_clk) begin : proc_block_mover_and_arbiter
    drr_lock_event_dbg <= '0;
    drr_defer_event_dbg <= '0;
    b2p_arb_pick_q <= b2p_arb_pick;
    b2p_arb_req_raw_qq <= b2p_arb_req_raw_q;
    b2p_arb_req_eligible_qq <= b2p_arb_req_eligible;
    b2p_arb_gnt_q <= b2p_arb_gnt;
    b2p_arb_commit_q <= b2p_arb_commit;
    page_allocator_page_write_pending_q <= page_allocator_direct_write;
    page_allocator_page_we_q <= page_allocator_page_we_i;
    page_allocator_page_waddr_q <= page_allocator_page_waddr_i;
    page_allocator_page_wdata_q <= page_allocator_page_wdata_i;
    if (mover_page_output_fire && (b2p_arb_commit_q == '0)) begin
      mover_page_pending_q <= '0;
    end
    if (b2p_arb_commit_q != '0) begin
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
      if ((mover_page_pending_q != '0) && !mover_page_output_fire) begin
        $error("OPQ block mover page write stage overflow");
      end
`endif
`endif
      mover_page_pending_q <= b2p_arb_commit_q;
      for (int i = 0; i < N_LANE; i++) begin
        if (b2p_arb_commit_q[i]) begin
          mover_page_waddr_sel_q <=
            block_mover_page_wptr[i] + page_ram_addr_t'(block_mover_word_wr_cnt[i]);
          mover_page_wdata_q[i] <= lane_fifos_rd_data_i[i];
        end
      end
    end
`ifdef OPQ_OSS_FORMAL
    lock_req_raw_dbg_oss <= '0;
    lock_req_eligible_dbg_oss <= '0;
    defer_req_raw_dbg_oss <= '0;
    defer_req_eligible_dbg_oss <= '0;
`endif
    for (int i = 0; i < N_LANE; i++) begin
      block_mover_page_wreq[i] <= 1'b0;
      block_mover_lane_credit_update_valid[i] <= 1'b0;
      b2p_arb_req_eligible_q[i] <= b2p_arb_req_eligible_comb[i];

      unique case (block_mover_state[i])
        BLOCK_MOVER_IDLE: begin
          block_mover_word_wr_cnt[i] <= '0;
          if (handle_fifo_is_pending_handle_valid[i] && handle_fifo_is_q_valid[i]) begin
            block_mover_handle_src[i] <= handle_fifo_if_rd_src[i];
            block_mover_handle_dst[i] <= handle_fifo_if_rd_dst[i];
            block_mover_handle_blk_len[i] <= handle_fifo_if_rd_blk_len[i];
            block_mover_flag[i] <= handle_fifo_if_rd_flag[i];
            block_mover_final_word_q[i] <= (handle_fifo_if_rd_blk_len[i] == pkt_length_t'(1));
            block_mover_lane_rd_addr[i] <= handle_fifo_if_rd_src[i];
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
            if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
              $display("[opq_boundary] t=%0t lane%0d mover_load flag=%0b src=0x%0h dst=0x%0h len=%0d handle_rptr=0x%0h q=0x%0h",
                $time,
                i,
                handle_fifo_if_rd_flag[i],
                handle_fifo_if_rd_src[i],
                handle_fifo_if_rd_dst[i],
                handle_fifo_if_rd_blk_len[i],
                block_mover_handle_rptr[i],
                handle_fifos_rd_data_i[i]);
            end
`endif
`endif
            if (!handle_fifo_if_rd_flag[i]) begin
              block_mover_state[i] <= BLOCK_MOVER_PREP;
            end else begin
              block_mover_state[i] <= BLOCK_MOVER_ABORT_WRITE_BLK;
            end
          end
        end

        BLOCK_MOVER_PREP: begin
          // Prime the lane-FIFO read path first; the first page-RAM write starts
          // in WRITE_BLK on the following cycle once the source word is stable.
          block_mover_page_wptr[i] <= block_mover_handle_dst[i];
          block_mover_page_wreq[i] <= 1'b0;
          block_mover_state[i] <= BLOCK_MOVER_WRITE_BLK;
        end

        BLOCK_MOVER_WRITE_BLK: begin
          block_mover_page_wreq[i] <= 1'b1;
          if (b2p_arb_commit_q[i]) begin
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
            if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
              $display("[opq_boundary] t=%0t lane%0d mover_write word_idx=%0d src=0x%0h dst=0x%0h len=%0d lane_rd=0x%0h lane_q=0x%0h page_addr=0x%0h quantum=%0d",
                $time,
                i,
                block_mover_word_wr_cnt[i],
                block_mover_handle_src[i],
                block_mover_handle_dst[i],
                block_mover_handle_blk_len[i],
                lane_fifos_rd_addr_o[i],
                lane_fifos_rd_data_i[i],
                block_mover_page_wptr[i] + page_ram_addr_t'(block_mover_word_wr_cnt[i]),
                b2p_arb.quantum[i]);
            end
`endif
`endif
            block_mover_lane_rd_addr[i] <= block_mover_lane_rd_addr[i] + lane_fifo_addr_t'(1);
            block_mover_word_wr_cnt[i] <= block_mover_word_wr_cnt[i] + pkt_length_t'(1);
            if (block_mover_final_word_q[i]) begin
              block_mover_lane_credit_update[i] <= lane_fifo_addr_t'(block_mover_handle_blk_len[i]);
              block_mover_lane_credit_update_valid[i] <= 1'b1;
              block_mover_handle_rptr[i] <= block_mover_handle_rptr[i] + handle_fifo_addr_t'(1);
              block_mover_page_wreq[i] <= 1'b0;
              block_mover_final_word_q[i] <= 1'b0;
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
              if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
                $display("[opq_boundary] t=%0t lane%0d mover_done credit_return=%0d next_handle_rptr=0x%0h",
                  $time,
                  i,
                  block_mover_handle_blk_len[i],
                  block_mover_handle_rptr[i] + handle_fifo_addr_t'(1));
              end
`endif
`endif
              block_mover_state[i] <= BLOCK_MOVER_IDLE;
            end else begin
              block_mover_final_word_q[i] <=
                ((block_mover_word_wr_cnt[i] + pkt_length_t'(2)) == block_mover_handle_blk_len[i]);
            end
          end
        end

        BLOCK_MOVER_ABORT_WRITE_BLK: begin
          block_mover_handle_rptr[i] <= block_mover_handle_rptr[i] + handle_fifo_addr_t'(1);
          block_mover_lane_credit_update[i] <= lane_fifo_addr_t'(block_mover_handle_blk_len[i]);
          block_mover_lane_credit_update_valid[i] <= 1'b1;
          block_mover_final_word_q[i] <= 1'b0;
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display("[opq_boundary] t=%0t lane%0d mover_abort credit_return=%0d next_handle_rptr=0x%0h",
              $time,
              i,
              block_mover_handle_blk_len[i],
              block_mover_handle_rptr[i] + handle_fifo_addr_t'(1));
          end
`endif
`endif
          block_mover_state[i] <= BLOCK_MOVER_IDLE;
        end

        BLOCK_MOVER_RESET: begin
          if (!block_mover_reset_done[i]) begin
            block_mover_lane_credit_update[i] <= lane_fifo_addr_t'(LANE_FIFO_MAX_CREDIT);
            block_mover_lane_credit_update_valid[i] <= 1'b1;
            block_mover_reset_done[i] <= 1'b1;
          end else if (!d_reset) begin
            block_mover_state[i] <= BLOCK_MOVER_IDLE;
          end
        end

        default: begin
        end
      endcase

      if (d_reset) begin
        block_mover_word_wr_cnt[i] <= '0;
        block_mover_lane_rd_addr[i] <= '0;
        block_mover_handle_src[i] <= '0;
        block_mover_handle_dst[i] <= '0;
        block_mover_handle_blk_len[i] <= '0;
        block_mover_flag[i] <= 1'b0;
        block_mover_final_word_q[i] <= 1'b0;
        block_mover_handle_rptr[i] <= '0;
        block_mover_handle_rptr_d[i] <= '0;
        block_mover_page_wptr[i] <= '0;
        block_mover_page_wreq[i] <= 1'b0;
        block_mover_lane_credit_update[i] <= '0;
        block_mover_lane_credit_update_valid[i] <= 1'b0;
        block_mover_reset_done[i] <= 1'b0;
        block_mover_state[i] <= BLOCK_MOVER_RESET;
        handle_fifo_is_pending_handle_d[i] <= '0;
        b2p_arb_req_eligible_q[i] <= 1'b0;
        mover_page_wdata_q[i] <= '0;
      end else begin
        for (int j = 1; j <= FIFO_RAW_DELAY; j++) begin
          if (j == 1) begin
            handle_fifo_is_pending_handle_d[i][j] <= handle_fifo_is_pending_handle[i];
          end else begin
            handle_fifo_is_pending_handle_d[i][j] <= handle_fifo_is_pending_handle_d[i][j-1];
          end
        end
      end

      for (int j = 1; j <= FIFO_RD_DELAY; j++) begin
        if (j == 1) begin
          block_mover_handle_rptr_d[i][j] <= block_mover_handle_rptr[i];
        end else begin
          block_mover_handle_rptr_d[i][j] <= block_mover_handle_rptr_d[i][j-1];
        end
      end
    end

    for (int i = 0; i < N_LANE; i++) begin
      if (b2p_arb_commit_q[i]) begin
        if (b2p_arb.quantum[i] > 10'd0) begin
          b2p_arb.quantum[i] <= b2p_arb.quantum[i] - 10'd1;
        end else begin
          b2p_arb.quantum[i] <= '0;
        end
      end
      if (drr_allowance_reload_i[i]) begin
        b2p_arb.quantum[i] <= drr_allowance_i[i];
      end
    end

    unique case (arbiter_state)
      ARBITER_IDLE: begin
        if (|b2p_arb_req_raw_qq) begin
          if (|b2p_arb_pick_q) begin
            b2p_arb.sel_mask <= b2p_arb_pick_q;
            arbiter_state <= ARBITER_LOCKED;
            drr_lock_event_dbg <= b2p_arb_pick_q;
`ifdef OPQ_OSS_FORMAL
            lock_req_raw_dbg_oss <= b2p_arb_pick_q & b2p_arb_req_raw_qq;
            lock_req_eligible_dbg_oss <= b2p_arb_pick_q & b2p_arb_req_eligible_qq;
`endif
          end else begin
            for (int i = 0; i < N_LANE; i++) begin
              if (b2p_arb_req_raw_qq[i] && !drr_allowance_reload_i[i]) begin
                b2p_arb.quantum[i] <= sat_add_quantum(b2p_arb.quantum[i], drr_allowance_i[i]);
                drr_defer_event_dbg[i] <= 1'b1;
`ifdef OPQ_OSS_FORMAL
                defer_req_raw_dbg_oss[i] <= b2p_arb_req_raw_qq[i];
                defer_req_eligible_dbg_oss[i] <= b2p_arb_req_eligible_qq[i];
`endif
              end
            end
            arbiter_state <= ARBITER_LOCKING;
          end
        end
      end

      ARBITER_LOCKING: begin
        if (|b2p_arb_pick_q) begin
          b2p_arb.sel_mask <= b2p_arb_pick_q;
          arbiter_state <= ARBITER_LOCKED;
          drr_lock_event_dbg <= b2p_arb_pick_q;
`ifdef OPQ_OSS_FORMAL
          lock_req_raw_dbg_oss <= b2p_arb_pick_q & b2p_arb_req_raw_qq;
          lock_req_eligible_dbg_oss <= b2p_arb_pick_q & b2p_arb_req_eligible_qq;
`endif
        end else if (|b2p_arb_req_raw_qq) begin
          for (int i = 0; i < N_LANE; i++) begin
            if (b2p_arb_req_raw_qq[i] && !drr_allowance_reload_i[i]) begin
              b2p_arb.quantum[i] <= sat_add_quantum(b2p_arb.quantum[i], drr_allowance_i[i]);
              drr_defer_event_dbg[i] <= 1'b1;
`ifdef OPQ_OSS_FORMAL
              defer_req_raw_dbg_oss[i] <= b2p_arb_req_raw_qq[i];
              defer_req_eligible_dbg_oss[i] <= b2p_arb_req_eligible_qq[i];
`endif
            end
          end
        end
      end

      ARBITER_LOCKED: begin
        for (int i = 0; i < N_LANE; i++) begin
          if (b2p_arb.sel_mask[i] && !b2p_arb_req_raw[i]) begin
            arbiter_state <= ARBITER_IDLE;
            b2p_arb.priority_mask <= {b2p_arb.sel_mask[N_LANE-2:0], b2p_arb.sel_mask[N_LANE-1]};
          end
          if ((b2p_arb.quantum[i] == 10'd1) && b2p_arb_commit_q[i]) begin
            arbiter_state <= ARBITER_IDLE;
          end
        end
      end

      ARBITER_RESET: begin
        b2p_arb <= B2P_ARB_REG_RESET;
        b2p_arb.priority_mask <= {{(N_LANE-1){1'b0}}, 1'b1};
        for (int i = 0; i < N_LANE; i++) begin
          b2p_arb.quantum[i] <= QUANTUM_PER_SUBFRAME;
        end
        arbiter_state <= ARBITER_IDLE;
      end

      default: begin
      end
    endcase

    page_ram_we_o <= page_ram_we_comb;
    page_ram_wr_addr_o <= page_ram_wr_addr_comb;
    page_ram_wr_data_o <= page_ram_wr_data_comb;
    payload_commit_idle_o <= payload_commit_idle_comb;
`ifdef OPQ_OSS_FORMAL
    if (page_ram_we_comb) begin
      page_ram_src_addr_dbg_oss <= page_ram_wr_addr_comb;
      page_ram_src_data_dbg_oss <= page_ram_wr_data_comb;
      if (page_allocator_page_write_pending_q) begin
        page_ram_src_is_pa_dbg_oss <= 1'b1;
      end else begin
        page_ram_src_lane_dbg_oss <= mover_page_pending_q & {N_LANE{page_ram_we_comb}};
      end
    end
`endif

    if (d_reset) begin
      b2p_arb <= B2P_ARB_REG_RESET;
      b2p_arb.priority_mask <= {{(N_LANE-1){1'b0}}, 1'b1};
      for (int i = 0; i < N_LANE; i++) begin
        b2p_arb.quantum[i] <= QUANTUM_PER_SUBFRAME;
      end
      arbiter_state <= ARBITER_RESET;
      page_ram_we_o <= 1'b0;
      page_ram_wr_addr_o <= '0;
      page_ram_wr_data_o <= '0;
      payload_commit_idle_o <= 1'b0;
      b2p_arb_gnt_q <= '0;
      b2p_arb_commit_q <= '0;
      b2p_arb_req_raw_q <= '0;
      b2p_arb_pick_q <= '0;
      b2p_arb_req_raw_qq <= '0;
      b2p_arb_req_eligible_qq <= '0;
      page_allocator_page_write_pending_q <= 1'b0;
      page_allocator_page_we_q <= 1'b0;
      page_allocator_page_waddr_q <= '0;
      page_allocator_page_wdata_q <= '0;
      mover_page_pending_q <= '0;
      mover_page_waddr_sel_q <= '0;
`ifdef OPQ_OSS_FORMAL
      lock_req_raw_dbg_oss <= '0;
      lock_req_eligible_dbg_oss <= '0;
      defer_req_raw_dbg_oss <= '0;
      defer_req_eligible_dbg_oss <= '0;
      page_ram_src_is_pa_dbg_oss <= 1'b0;
      page_ram_src_lane_dbg_oss <= '0;
      page_ram_src_addr_dbg_oss <= '0;
      page_ram_src_data_dbg_oss <= '0;
`endif
    end

    if (!d_reset) begin
      b2p_arb_req_raw_q <= b2p_arb_req_raw;
    end
  end

`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
  genvar g_block_path_sva_idx;
  generate
    for (g_block_path_sva_idx = 0;
         g_block_path_sva_idx < N_LANE;
         g_block_path_sva_idx = g_block_path_sva_idx + 1) begin : g_block_path_sva
    property p_reset_enters_block_mover_reset;
      @(posedge d_clk) d_reset |=> (block_mover_state[g_block_path_sva_idx] == BLOCK_MOVER_RESET);
    endproperty
    ap_reset_enters_block_mover_reset: assert property (p_reset_enters_block_mover_reset);

    property p_abort_returns_credit;
      @(posedge d_clk) disable iff (d_reset)
        (block_mover_state[g_block_path_sva_idx] == BLOCK_MOVER_ABORT_WRITE_BLK)
        |=> lane_credit_update_valid_o[g_block_path_sva_idx];
    endproperty
    ap_abort_returns_credit: assert property (p_abort_returns_credit);
    end
  endgenerate
`endif
`endif

`ifdef OPQ_ENABLE_NATIVE_FORMAL_MOVER
  opq_native_block_path_formal_sva #(
    .N_LANE(N_LANE),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .LANE_FIFO_ADDR_WIDTH(LANE_FIFO_ADDR_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH)
  ) native_formal_sva_i (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .page_allocator_write_head_i(page_allocator_write_head_i),
    .page_allocator_write_tail_i(page_allocator_write_tail_i),
    .page_allocator_write_page_i(page_allocator_write_page_i),
    .page_allocator_page_we_i(page_allocator_page_we_i),
    .page_allocator_page_waddr_i(page_allocator_page_waddr_i),
    .page_allocator_page_wdata_i(page_allocator_page_wdata_i),
    .lane_fifos_rd_data_i(lane_fifos_rd_data_i),
    .page_ram_we_o(page_ram_we_o),
    .page_ram_wr_addr_o(page_ram_wr_addr_o),
    .page_ram_wr_data_o(page_ram_wr_data_o),
    .req_raw(b2p_arb_req_raw),
    .req_eligible(b2p_arb_req_eligible),
    .gnt(b2p_arb_gnt),
    .sel_mask(b2p_arb.sel_mask),
    .lock_event(drr_lock_event_dbg),
    .defer_event(drr_defer_event_dbg),
    .locked(arbiter_state == ARBITER_LOCKED)
  );
`endif

endmodule
