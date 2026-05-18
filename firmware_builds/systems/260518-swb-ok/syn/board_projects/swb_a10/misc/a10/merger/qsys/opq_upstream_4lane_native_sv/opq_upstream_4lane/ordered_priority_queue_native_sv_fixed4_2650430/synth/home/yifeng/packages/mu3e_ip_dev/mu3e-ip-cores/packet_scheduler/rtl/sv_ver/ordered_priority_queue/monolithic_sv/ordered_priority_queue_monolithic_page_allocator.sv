//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_page_allocator
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.5.3
// Date    : 20260517
// Change  : Add a staged same-timestamp body-ticket fast path that can commit
//           all active lanes without depleting ticket FIFO credit.
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_page_allocator #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned CHANNEL_WIDTH = 2,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned HANDLE_FIFO_DEPTH = 64,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HDR_SIZE = 5,
  parameter int unsigned SHD_SIZE = 1,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned TRL_SIZE = 1,
  parameter int unsigned FRAME_SERIAL_SIZE = 16,
  parameter int unsigned FRAME_SUBH_CNT_SIZE = 16,
  parameter int unsigned FRAME_HIT_CNT_SIZE = 16,
  parameter int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT,
  parameter int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH),
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_A =
    48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + FRAME_SERIAL_SIZE + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 6 + 16 + 48 + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH =
    (TICKET_FIFO_DATA_WIDTH_A > TICKET_FIFO_DATA_WIDTH_B) ? TICKET_FIFO_DATA_WIDTH_A : TICKET_FIFO_DATA_WIDTH_B,
  parameter int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH),
  parameter int unsigned TICKET_FIFO_MAX_CREDIT = TICKET_FIFO_DEPTH - 1,
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned HANDLE_FIFO_ADDR_WIDTH = $clog2(HANDLE_FIFO_DEPTH),
  parameter int unsigned HANDLE_LENGTH = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS,
  parameter int unsigned FIFO_RAW_DELAY = 2,
  parameter int unsigned FRAME_DURATION_CYCLES = N_SHD * 16,
  parameter int unsigned FRAME_JOIN_WAIT_CYCLES = FRAME_DURATION_CYCLES,
  parameter int unsigned MAX_SHR_CNT_BITS = $clog2(N_SHD * N_LANE) + 1,
  parameter int unsigned MAX_HIT_CNT_BITS = (($clog2(N_SHD * N_HIT) + 1) < 16) ? ($clog2(N_SHD * N_HIT) + 1) : 16,
  parameter int unsigned FRAME_HIT_ROOM_LIMIT = N_SHD * N_HIT,
  parameter int unsigned ALLOC_PAGE_FLOW_WIDTH = (N_LANE <= 1) ? 1 : $clog2(N_LANE),
  parameter int unsigned WRITE_META_FLOW_WIDTH = 3,
  parameter int unsigned PAGE_LENGTH_WIDTH = MAX_PKT_LENGTH_BITS + CHANNEL_WIDTH
) (
  input  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ingress_ticket_wptr,
  input  logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0]     ticket_fifos_rd_data_i,
  input  logic [N_LANE-1:0][5:0]                            ingress_dt_type_i,
  input  logic [N_LANE-1:0][15:0]                           ingress_feb_id_i,
  input  logic [N_LANE-1:0][47:0]                           ingress_frame_ts_i,
  input  logic [N_LANE-1:0][47:0]                           ingress_running_ts_i,
  input  logic [N_LANE-1:0]                                 ingress_parser_busy_i,
  input  logic [N_LANE-1:0]                                 ingress_tail_bypass_valid_i,
  input  logic [N_LANE-1:0]                                 ingress_tail_bypass_drop_i,
  input  logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0]          ingress_tail_bypass_serial_i,
  input  logic [N_LANE-1:0][47:0]                           ingress_tail_bypass_ts_i,
  output logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ticket_credit_update_o,
  output logic [N_LANE-1:0]                                 ticket_credit_update_valid_o,
  output logic [N_LANE-1:0][HANDLE_LENGTH:0]                handle_wdata_o,
  output logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]     handle_waddr_o,
  output logic [N_LANE-1:0]                                 handle_we_o,
  output logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0]     handle_wptr_o,
  input  logic [N_LANE-1:0]                                 handle_credit_update_valid_i,
  output logic [N_LANE-1:0]                                 eop_flush_ack_o,
  output logic [N_LANE-1:0]                                 late_frame_drop_valid_o,
  output logic [N_LANE-1:0][15:0]                           late_frame_drop_hdr_cnt_o,
  output logic [N_LANE-1:0][15:0]                           late_frame_drop_shd_cnt_o,
  output logic [N_LANE-1:0][15:0]                           late_frame_drop_hit_cnt_o,
  output logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0]          late_frame_drop_serial_o,
  output logic [N_LANE-1:0][47:0]                           late_frame_drop_ts_o,
  output logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0]       late_frame_lane_credit_update_o,
  output logic [N_LANE-1:0]                                 late_frame_lane_credit_update_valid_o,
  output logic                                              page_we_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    page_waddr_o,
  output logic [PAGE_RAM_DATA_WIDTH-1:0]                    page_wdata_o,
  output logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]     ticket_fifos_rd_addr_o,
  output logic [N_LANE-1:0]                                 tk_future_o,
  output logic                                              fetch_ticket_active_o,
  output logic                                              alloc_page_active_o,
  output logic                                              write_head_active_o,
  output logic                                              write_tail_active_o,
  output logic                                              write_page_active_o,
  output logic [WRITE_META_FLOW_WIDTH-1:0]                  write_meta_flow_o,
  output logic [WRITE_META_FLOW_WIDTH-1:0]                  write_meta_flow_d1_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    frame_start_addr_o,
  output logic [MAX_SHR_CNT_BITS-1:0]                       frame_shr_cnt_this_o,
  output logic [MAX_HIT_CNT_BITS-1:0]                       frame_hit_cnt_this_o,
  output logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]           frame_lane_shd_cnt_this_o,
  output logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]           frame_lane_hit_cnt_this_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                    packet_complete_frame_start_addr_o,
  output logic [MAX_SHR_CNT_BITS-1:0]                       packet_complete_shr_cnt_o,
  output logic [MAX_HIT_CNT_BITS-1:0]                       packet_complete_hit_cnt_o,
  output logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]           packet_complete_lane_shd_cnt_o,
  output logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]           packet_complete_lane_hit_cnt_o,
  output logic                                              packet_complete_pulse_o,
  input  logic                                              resident_backpressure_hold_i,
  input  logic                                              resident_protect_valid_i,
  input  logic [PAGE_RAM_ADDR_WIDTH-1:0]                    resident_protect_addr_i,
  input  logic [PAGE_RAM_ADDR_WIDTH-1:0]                    resident_protect_len_i,
  input  logic                                              resident_protect_full_ring_i,
  input  logic                                              resident_protect_has_successor_i,
  input  logic                                              d_clk,
  input  logic                                              d_reset
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;
  localparam int unsigned HANDLE_FIFO_MAX_CREDIT = HANDLE_FIFO_DEPTH - 2;
  localparam int unsigned HANDLE_CREDIT_WIDTH = $clog2(HANDLE_FIFO_DEPTH + 1);

  localparam int unsigned HANDLE_SRC_LO = 0;
  localparam int unsigned HANDLE_SRC_HI = LANE_FIFO_ADDR_WIDTH - 1;
  localparam int unsigned HANDLE_DST_LO = LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned HANDLE_DST_HI = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH - 1;
  localparam int unsigned HANDLE_LEN_LO = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH;
  localparam int unsigned HANDLE_LEN_HI = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS - 1;
  localparam int unsigned TICKET_TS_LO = 0;
  localparam int unsigned TICKET_TS_HI = 47;
  localparam int unsigned TICKET_LANE_RD_OFST_LO = 48;
  localparam int unsigned TICKET_LANE_RD_OFST_HI = 48 + LANE_FIFO_ADDR_WIDTH - 1;
  localparam int unsigned TICKET_BLOCK_LEN_LO = 48 + LANE_FIFO_ADDR_WIDTH;
  localparam int unsigned TICKET_BLOCK_LEN_HI = 48 + LANE_FIFO_ADDR_WIDTH + MAX_PKT_LENGTH_BITS - 1;
  localparam int unsigned TICKET_BODY_SERIAL_LO = TICKET_BLOCK_LEN_HI + 1;
  localparam int unsigned TICKET_BODY_SERIAL_HI = TICKET_BODY_SERIAL_LO + FRAME_SERIAL_SIZE - 1;
  localparam int unsigned TICKET_SERIAL_LO = 0;
  localparam int unsigned TICKET_SERIAL_HI = FRAME_SERIAL_SIZE - 1;
  localparam int unsigned TICKET_N_SUBH_LO = FRAME_SERIAL_SIZE;
  localparam int unsigned TICKET_N_SUBH_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE - 1;
  localparam int unsigned TICKET_N_HIT_LO = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE;
  localparam int unsigned TICKET_N_HIT_HI = FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE - 1;
  localparam int unsigned TICKET_DT_TYPE_LO = TICKET_N_HIT_HI + 1;
  localparam int unsigned TICKET_DT_TYPE_HI = TICKET_DT_TYPE_LO + 6 - 1;
  localparam int unsigned TICKET_FEB_ID_LO = TICKET_DT_TYPE_HI + 1;
  localparam int unsigned TICKET_FEB_ID_HI = TICKET_FEB_ID_LO + 16 - 1;
  localparam int unsigned TICKET_FRAME_TS_LO = TICKET_FEB_ID_HI + 1;
  localparam int unsigned TICKET_FRAME_TS_HI = TICKET_FRAME_TS_LO + 48 - 1;
  localparam int unsigned TICKET_ALT_EOP_LOC = TICKET_FIFO_DATA_WIDTH - 2;
  localparam int unsigned TICKET_ALT_SOP_LOC = TICKET_FIFO_DATA_WIDTH - 1;
  localparam logic [N_LANE-1:0] ALLOC_PAGE_FLOW_FIRST_ONEHOT = N_LANE'(1);

  typedef logic [LANE_FIFO_ADDR_WIDTH-1:0] lane_fifo_addr_t;
  typedef logic [TICKET_FIFO_ADDR_WIDTH-1:0] ticket_fifo_addr_t;
  typedef logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_addr_t;
  typedef logic [HANDLE_FIFO_ADDR_WIDTH-1:0] handle_fifo_addr_t;
  typedef logic [HANDLE_CREDIT_WIDTH-1:0] handle_credit_t;
  typedef logic [MAX_PKT_LENGTH_BITS-1:0] pkt_length_t;
  typedef logic [MAX_SHR_CNT_BITS-1:0] frame_shr_cnt_t;
  typedef logic [MAX_HIT_CNT_BITS-1:0] frame_hit_cnt_t;
`ifdef OPQ_DEBUG_BYPASS_SUBFRAME_HIT_LIMIT
  localparam frame_hit_cnt_t FRAME_HIT_ROOM_RESET = {MAX_HIT_CNT_BITS{1'b1}};
`else
  localparam frame_hit_cnt_t FRAME_HIT_ROOM_RESET = frame_hit_cnt_t'(FRAME_HIT_ROOM_LIMIT);
`endif
  typedef logic [PAGE_LENGTH_WIDTH-1:0] page_length_t;

  typedef struct packed {
    logic [47:0]           ticket_ts;
    lane_fifo_addr_t       lane_fifo_rd_offset;
    pkt_length_t           block_length;
    logic [FRAME_SERIAL_SIZE-1:0] frame_serial;
    logic                  alert_eop;
    logic                  alert_sop;
  } ticket_t;

  localparam ticket_t TICKET_DEFAULT = '{
    ticket_ts: '0,
    lane_fifo_rd_offset: '0,
    block_length: '0,
    frame_serial: '0,
    alert_eop: 1'b0,
    alert_sop: 1'b0
  };

`ifndef SYNTHESIS
  bit opq_trace_boundary_en;
  time opq_trace_after_ps;
  logic formal_past_valid;

  initial begin
    opq_trace_boundary_en = $test$plusargs("OPQ_NATIVE_TRACE_BOUNDARY");
    opq_trace_after_ps = 0;
    void'($value$plusargs("OPQ_TRACE_AFTER_PS=%d", opq_trace_after_ps));
  end

  always_ff @(posedge d_clk) begin
    if (d_reset) begin
      formal_past_valid <= 1'b0;
    end else begin
      formal_past_valid <= 1'b1;
    end
  end
`endif

  typedef enum logic [4:0] {
    PAGE_ALLOCATOR_IDLE,
    PAGE_ALLOCATOR_PREPARE_WRITE_TAIL,
    PAGE_ALLOCATOR_FETCH_TICKET,
    PAGE_ALLOCATOR_DECODE_TICKET,
    PAGE_ALLOCATOR_SAMPLE_TAIL,
    PAGE_ALLOCATOR_RESOLVE_TAIL,
    PAGE_ALLOCATOR_CLASSIFY_TICKET,
    PAGE_ALLOCATOR_SELECT_HEADER,
    PAGE_ALLOCATOR_ACCUM_TICKET,
    PAGE_ALLOCATOR_REDUCE_TICKET,
    PAGE_ALLOCATOR_SUMMARIZE_TICKET,
    PAGE_ALLOCATOR_REDUCE_FUTURE,
    PAGE_ALLOCATOR_REDUCE_FUTURE_FINAL,
    PAGE_ALLOCATOR_FINALIZE_SUMMARY,
    PAGE_ALLOCATOR_PREDICT_RESIDENT,
    PAGE_ALLOCATOR_PREDICT_TICKET,
    PAGE_ALLOCATOR_DECIDE_TICKET,
    PAGE_ALLOCATOR_APPLY_TICKET,
    PAGE_ALLOCATOR_FAST_ZERO_ISSUE,
    PAGE_ALLOCATOR_FAST_ZERO_COMMIT,
    PAGE_ALLOCATOR_WRITE_HEAD,
    PAGE_ALLOCATOR_WRITE_TAIL,
    PAGE_ALLOCATOR_ALLOC_PAGE,
    PAGE_ALLOCATOR_COMMIT_PAGE,
    PAGE_ALLOCATOR_FINALIZE_PAGE,
    PAGE_ALLOCATOR_WRITE_PAGE,
    PAGE_ALLOCATOR_RESET
  } page_allocator_state_t;

  typedef ticket_fifo_addr_t ticket_credit_update_t [N_LANE];
  typedef logic [N_LANE-1:0] handle_wflag_t;
  typedef logic [HANDLE_LENGTH:0] handle_wdata_t [N_LANE];
  typedef handle_fifo_addr_t handle_waddr_t [N_LANE];
  typedef handle_fifo_addr_t handle_wptr_t [N_LANE];
  typedef ticket_t tickets_t [N_LANE];
  typedef ticket_fifo_addr_t ticket_rptr_t [N_LANE];
  typedef logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0] ticket_raws_t;
  localparam int unsigned FRAME_JOIN_WAIT_WIDTH =
    (FRAME_JOIN_WAIT_CYCLES > 0) ? $clog2(FRAME_JOIN_WAIT_CYCLES + 1) : 1;
  typedef logic [FRAME_JOIN_WAIT_WIDTH-1:0] frame_join_wait_t;
  typedef enum logic [1:0] {
    FETCH_LANE_HOLD,
    FETCH_LANE_ADVANCE_ONLY,
    FETCH_LANE_LOAD,
    FETCH_LANE_LATE_DROP
  } fetch_lane_action_t;
  typedef fetch_lane_action_t fetch_lane_actions_t [N_LANE];
  localparam int unsigned FUTURE_FRAME_PAIR_COUNT = (N_LANE + 1) / 2;
  localparam int unsigned FUTURE_FRAME_REDUCE_COUNT = (FUTURE_FRAME_PAIR_COUNT + 1) / 2;
  localparam int unsigned FUTURE_FRAME_FINAL_COUNT = (FUTURE_FRAME_REDUCE_COUNT + 1) / 2;
  localparam int unsigned FETCH_READY_PAIR_COUNT = (N_LANE + 1) / 2;
  localparam int unsigned FETCH_READY_REDUCE_COUNT = (FETCH_READY_PAIR_COUNT + 1) / 2;
  localparam int unsigned FAST_ZERO_PAIR_COUNT = (N_LANE + 1) / 2;
  localparam int unsigned FUTURE_FRAME_LANE_WIDTH = (N_LANE <= 1) ? 1 : $clog2(N_LANE);
  localparam int unsigned TAIL_STATUS_WRAP_WIDTH =
    (FRAME_SERIAL_SIZE > TICKET_FIFO_ADDR_WIDTH) ? (FRAME_SERIAL_SIZE - TICKET_FIFO_ADDR_WIDTH) : 1;
  localparam bit PAGE_RAM_DEPTH_POWER_OF_TWO =
    ((PAGE_RAM_DEPTH & (PAGE_RAM_DEPTH - 1)) == 0);

  typedef struct packed {
    logic                        valid;
    logic [FRAME_SERIAL_SIZE-1:0] serial;
    logic [FUTURE_FRAME_LANE_WIDTH-1:0] lane;
  } future_frame_candidate_t;

  function automatic future_frame_candidate_t choose_earlier_future_frame(
    input future_frame_candidate_t lhs,
    input future_frame_candidate_t rhs
  );
    future_frame_candidate_t result;

    if (!lhs.valid) begin
      result = rhs;
    end else if (!rhs.valid) begin
      result = lhs;
    end else if (rhs.serial < lhs.serial) begin
      result = rhs;
    end else begin
      result = lhs;
    end

    return result;
  endfunction

  function automatic logic serial_reached_or_passed(
    input logic [FRAME_SERIAL_SIZE-1:0] observed_serial,
    input logic [FRAME_SERIAL_SIZE-1:0] target_serial
  );
    logic [FRAME_SERIAL_SIZE-1:0] serial_delta;
    begin
      serial_delta = observed_serial - target_serial;
      serial_reached_or_passed = !serial_delta[FRAME_SERIAL_SIZE-1];
    end
  endfunction

  function automatic page_ram_addr_t frame_length_from_counts(
    input frame_shr_cnt_t shd_cnt,
    input frame_hit_cnt_t hit_cnt
  );
    logic [PAGE_RAM_ADDR_WIDTH:0] shd_ext;
    logic [PAGE_RAM_ADDR_WIDTH:0] hit_ext;
    logic [PAGE_RAM_ADDR_WIDTH:0] frame_len_ext;
    begin
      shd_ext = shd_cnt;
      hit_ext = hit_cnt;
      frame_len_ext = (shd_ext * SHD_SIZE) + (hit_ext * HIT_SIZE) + HDR_SIZE + TRL_SIZE;
      frame_length_from_counts = frame_len_ext[PAGE_RAM_ADDR_WIDTH-1:0];
    end
  endfunction

  function automatic logic frame_length_spans_full_ring(
    input frame_shr_cnt_t shd_cnt,
    input frame_hit_cnt_t hit_cnt
  );
    int unsigned shd_words_v;
    int unsigned hit_words_v;
    int unsigned frame_len_words_v;
    begin
      shd_words_v = int'(shd_cnt) * SHD_SIZE;
      hit_words_v = int'(hit_cnt) * HIT_SIZE;
      frame_len_words_v = shd_words_v + hit_words_v + HDR_SIZE + TRL_SIZE;
      frame_length_spans_full_ring = (frame_len_words_v >= PAGE_RAM_DEPTH);
    end
  endfunction

  function automatic logic frame_lengths_exceed_ring_capacity(
    input page_ram_addr_t lhs_len,
    input page_ram_addr_t rhs_len
  );
    logic [PAGE_RAM_ADDR_WIDTH:0] lhs_ext;
    logic [PAGE_RAM_ADDR_WIDTH:0] rhs_ext;
    logic [PAGE_RAM_ADDR_WIDTH+1:0] sum_ext;
    begin
      lhs_ext = lhs_len;
      rhs_ext = rhs_len;
      sum_ext = lhs_ext + rhs_ext;
      frame_lengths_exceed_ring_capacity = (sum_ext > PAGE_RAM_DEPTH);
    end
  endfunction

  function automatic logic [PAGE_RAM_ADDR_WIDTH+1:0] circular_distance(
    input page_ram_addr_t from_addr,
    input page_ram_addr_t to_addr
  );
    logic [PAGE_RAM_ADDR_WIDTH+1:0] from_ext;
    logic [PAGE_RAM_ADDR_WIDTH+1:0] to_ext;
    logic [PAGE_RAM_ADDR_WIDTH-1:0] distance_mod_v;
    begin
      from_ext = from_addr;
      to_ext = to_addr;
      if (PAGE_RAM_DEPTH_POWER_OF_TWO) begin
        distance_mod_v = to_addr - from_addr;
        circular_distance = {{2{1'b0}}, distance_mod_v};
      end else begin
        if (to_ext >= from_ext) begin
          circular_distance = to_ext - from_ext;
        end else begin
          circular_distance = (PAGE_RAM_DEPTH - from_ext) + to_ext;
        end
      end
    end
  endfunction

  function automatic bit circular_range_overlaps(
    input page_ram_addr_t lhs_addr,
    input page_ram_addr_t lhs_len,
    input page_ram_addr_t rhs_addr,
    input page_ram_addr_t rhs_len
  );
    logic [PAGE_RAM_ADDR_WIDTH+1:0] lhs_len_ext;
    logic [PAGE_RAM_ADDR_WIDTH+1:0] rhs_len_ext;
    begin
      circular_range_overlaps = 1'b0;
      if ((lhs_len == '0) || (rhs_len == '0)) begin
        circular_range_overlaps = 1'b0;
      end else begin
        lhs_len_ext = lhs_len;
        rhs_len_ext = rhs_len;
        circular_range_overlaps =
          (circular_distance(lhs_addr, rhs_addr) < lhs_len_ext) ||
          (circular_distance(rhs_addr, lhs_addr) < rhs_len_ext);
      end
    end
  endfunction

  function automatic logic [FRAME_SERIAL_SIZE-1:0] tail_target_serial_from_raw(
    input logic [TICKET_FIFO_DATA_WIDTH-1:0] ticket_raw_v
  );
    begin
      if (ticket_raw_v[TICKET_ALT_SOP_LOC]) begin
        tail_target_serial_from_raw = ticket_raw_v[TICKET_SERIAL_HI:TICKET_SERIAL_LO];
      end else begin
        tail_target_serial_from_raw = ticket_raw_v[TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO];
      end
    end
  endfunction

  function automatic ticket_fifo_addr_t tail_status_slot(
    input logic [FRAME_SERIAL_SIZE-1:0] serial_v
  );
    begin
      tail_status_slot = ticket_fifo_addr_t'(serial_v);
    end
  endfunction

  function automatic logic [TAIL_STATUS_WRAP_WIDTH-1:0] tail_status_wrap(
    input logic [FRAME_SERIAL_SIZE-1:0] serial_v
  );
    logic [TAIL_STATUS_WRAP_WIDTH-1:0] wrap_v;
    begin
      wrap_v = '0;
      if (FRAME_SERIAL_SIZE > TICKET_FIFO_ADDR_WIDTH) begin
        wrap_v = serial_v[FRAME_SERIAL_SIZE-1:TICKET_FIFO_ADDR_WIDTH];
      end
      tail_status_wrap = wrap_v;
    end
  endfunction

`ifndef SYNTHESIS
`endif

  typedef struct {
    ticket_rptr_t          ticket_rptr;
    ticket_credit_update_t ticket_credit_update;
    logic [N_LANE-1:0]     ticket_credit_update_valid;
    logic [N_LANE-1:0]     handle_we;
    handle_wflag_t         handle_wflag;
    handle_wdata_t         handle_wdata;
    handle_waddr_t         handle_waddr;
    handle_wptr_t          handle_wptr;
    logic                  page_we;
    logic [PAGE_RAM_DATA_WIDTH-1:0] page_wdata;
    page_ram_addr_t        page_waddr;
    page_ram_addr_t        frame_start_addr;
    page_ram_addr_t        frame_start_addr_last;
    logic [35:0]           frame_cnt;
    logic [FRAME_SERIAL_SIZE-1:0] frame_serial;
    logic [FRAME_SERIAL_SIZE-1:0] frame_serial_this;
    frame_shr_cnt_t        frame_shr_cnt;
    frame_shr_cnt_t        frame_shr_cnt_this;
    frame_shr_cnt_t        frame_lane_shd_cnt [N_LANE];
    frame_shr_cnt_t        frame_lane_shd_cnt_this [N_LANE];
    frame_hit_cnt_t        frame_hit_cnt;
    frame_hit_cnt_t        frame_hit_room;
    frame_hit_cnt_t        frame_hit_cnt_this;
    frame_hit_cnt_t        frame_lane_hit_cnt [N_LANE];
    frame_hit_cnt_t        frame_lane_hit_cnt_this [N_LANE];
    logic [47:0]           frame_ts;
    logic [47:0]           running_ts;
    logic [N_LANE-1:0]     frame_lane_active;
    logic [N_LANE-1:0]     frame_lane_tail_seen;
    logic [N_LANE-1:0]     ingress_tail_seen_valid;
    logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0] ingress_tail_serial_seen;
    logic [N_LANE-1:0]     ingress_tail_drop_seen;
    logic [N_LANE-1:0][47:0] ingress_tail_ts_seen;
    frame_join_wait_t      frame_join_wait;
    logic [N_LANE-1:0]     lane_masked;
    logic [N_LANE-1:0]     lane_skipped;
    logic                  subheader_has_accepted_lane;
    tickets_t              ticket;
    page_ram_addr_t        page_start_addr;
    page_length_t          page_length;
    logic [ALLOC_PAGE_FLOW_WIDTH-1:0] alloc_page_flow;
    logic [N_LANE-1:0]     alloc_page_flow_onehot;
    logic [WRITE_META_FLOW_WIDTH-1:0] write_meta_flow;
    logic [WRITE_META_FLOW_WIDTH-1:0] write_meta_flow_d1;
    logic                  write_trailer;
    logic                  tail_only_flush;
    logic                  reset_done;
  } page_allocator_reg_t;

  localparam page_allocator_reg_t PAGE_ALLOCATOR_REG_RESET = '{
    ticket_rptr: '{default:'0},
    ticket_credit_update: '{default:'0},
    ticket_credit_update_valid: '0,
    handle_we: '0,
    handle_wflag: '0,
    handle_wdata: '{default:'0},
    handle_waddr: '{default:'0},
    handle_wptr: '{default:'0},
    page_we: 1'b0,
    page_wdata: '0,
    page_waddr: '0,
    frame_start_addr: '0,
    frame_start_addr_last: '0,
    frame_cnt: '0,
    frame_serial: '0,
    frame_serial_this: '0,
    frame_shr_cnt: '0,
    frame_shr_cnt_this: '0,
    frame_lane_shd_cnt: '{default:'0},
    frame_lane_shd_cnt_this: '{default:'0},
    frame_hit_cnt: '0,
    frame_hit_room: FRAME_HIT_ROOM_RESET,
    frame_hit_cnt_this: '0,
    frame_lane_hit_cnt: '{default:'0},
    frame_lane_hit_cnt_this: '{default:'0},
    frame_ts: '0,
    running_ts: '0,
    frame_lane_active: '0,
    frame_lane_tail_seen: '0,
    ingress_tail_seen_valid: '0,
    ingress_tail_serial_seen: '0,
    ingress_tail_drop_seen: '0,
    ingress_tail_ts_seen: '0,
    frame_join_wait: '0,
    lane_masked: '0,
    lane_skipped: '0,
    subheader_has_accepted_lane: 1'b0,
    ticket: '{default:TICKET_DEFAULT},
    page_start_addr: '0,
    page_length: '0,
    alloc_page_flow: '0,
    alloc_page_flow_onehot: '0,
    write_meta_flow: '0,
    write_meta_flow_d1: '0,
    write_trailer: 1'b0,
    tail_only_flush: 1'b0,
    reset_done: 1'b0
  };

  typedef ticket_t page_allocator_if_read_ticket_ticket_t [N_LANE];

  typedef struct packed {
    logic [FRAME_SERIAL_SIZE-1:0] serial;
    frame_shr_cnt_t               n_subh;
    frame_hit_cnt_t               n_hit;
  } page_allocator_if_read_ticket_ticket_sop_t;

  page_allocator_state_t page_allocator_state;
  page_allocator_reg_t page_allocator;
  logic [N_LANE-1:0][FIFO_RAW_DELAY:1] page_allocator_is_pending_ticket_d;
  logic [N_LANE-1:0][FIFO_RAW_DELAY:1][TICKET_FIFO_ADDR_WIDTH-1:0] page_allocator_ticket_rptr_d;
  ticket_raws_t ticket_fifos_rd_data_stage_q;
  page_length_t fast_zero_block_length;
  page_length_t fast_zero_lane_offset [N_LANE];
  page_length_t fast_zero_lane_length [N_LANE];
  page_length_t fast_zero_pair_length [FAST_ZERO_PAIR_COUNT];
  logic fast_zero_commit_valid;
  logic [N_LANE-1:0] fast_zero_commit_lane_onehot_q;
  tickets_t fast_zero_commit_ticket_q;
  page_length_t fast_zero_commit_block_length_q;
  page_length_t fast_zero_commit_lane_offset_q [N_LANE];
  page_ram_addr_t fast_zero_commit_page_addr_q;
  logic [PAGE_RAM_DATA_WIDTH-1:0] fast_zero_commit_page_data_q;
  (* preserve *) logic [N_LANE-1:0] fetch_pending_q;
  (* preserve *) tickets_t fetch_ticket_q;
  (* preserve *) ticket_raws_t fetch_ticket_raw_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_sop_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_curr_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_future_q;
  (* preserve *) logic [N_LANE-1:0] fetch_tk_past_q;
  (* preserve *) logic [N_LANE-1:0] idle_tk_sop_q;
  (* preserve *) logic [N_LANE-1:0] idle_tk_curr_q;
  (* preserve *) logic [N_LANE-1:0] idle_tk_future_q;
  (* preserve *) logic [N_LANE-1:0] idle_tk_past_q;
  (* preserve *) logic [N_LANE-1:0] idle_tk_active_frame_q;
  logic [N_LANE-1:0] fetch_lane_masked_q;
  logic [N_LANE-1:0] fetch_lane_credit_valid_q;
  logic [N_LANE-1:0] fetch_lane_reactivate_q;
  fetch_lane_actions_t fetch_lane_action_q;
  logic fetch_all_present_tk_sop_q;
  logic fetch_any_pending_sop_q;
  logic fetch_any_pending_curr_sop_q;
  logic fetch_future_frame_seen_q;
  logic fetch_start_new_frame_q;
  logic fetch_rebase_future_frame_q;
  logic [N_LANE-1:0] fetch_rebase_future_frame_lane_q;
  logic fetch_join_absorb_only_q;
  logic fetch_predrop_current_frame_q;
  logic [N_LANE-1:0] fetch_predrop_current_frame_lane_q;
  logic fetch_resident_predict_matches_q;
  page_ram_addr_t fetch_predicted_frame_len_q;
  logic fetch_predicted_frame_spans_full_ring_q;
  logic fetch_predicted_capacity_exceeded_q;
  logic [N_LANE-1:0] fetch_lanes_with_curr_sop_q;
  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0] fetch_curr_sop_n_subh_q;
  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0] fetch_curr_sop_n_hit_q;
  frame_shr_cnt_t fetch_sop_pair_subh_q [FUTURE_FRAME_PAIR_COUNT];
  frame_hit_cnt_t fetch_sop_pair_hit_q [FUTURE_FRAME_PAIR_COUNT];
  frame_shr_cnt_t fetch_sop_reduce_subh_q [FUTURE_FRAME_REDUCE_COUNT];
  frame_hit_cnt_t fetch_sop_reduce_hit_q [FUTURE_FRAME_REDUCE_COUNT];
  logic fetch_header_lane_valid_q;
  logic [FUTURE_FRAME_LANE_WIDTH-1:0] fetch_header_lane_q;
  logic [5:0] fetch_default_header_dt_type_q;
  logic [15:0] fetch_default_header_feb_id_q;
  logic [47:0] fetch_default_header_frame_ts_q;
  logic [47:0] fetch_default_header_running_ts_q;
  logic [FRAME_SERIAL_SIZE-1:0] fetch_ticket_serial_ref_q;
  logic resident_protect_valid_stage_q;
  page_ram_addr_t resident_protect_addr_stage_q;
  page_ram_addr_t resident_protect_len_stage_q;
  logic resident_protect_full_ring_stage_q;
  logic resident_protect_has_successor_stage_q;
  logic [5:0] fetch_header_dt_type_q;
  logic [15:0] fetch_header_feb_id_q;
  logic [47:0] fetch_header_frame_ts_q;
  logic [47:0] fetch_header_running_ts_q;
  logic [FRAME_SERIAL_SIZE-1:0] fetch_sop_serial_q;
  frame_shr_cnt_t fetch_sop_n_subh_q;
  frame_hit_cnt_t fetch_sop_n_hit_q;
  logic [FRAME_SERIAL_SIZE-1:0] fetch_future_frame_serial_q;
  logic [FUTURE_FRAME_LANE_WIDTH-1:0] fetch_future_frame_lane_q;
  logic [47:0] fetch_future_frame_ts_q;
  logic fetch_resident_protect_valid_q;
  page_ram_addr_t fetch_resident_protect_addr_q;
  page_ram_addr_t fetch_resident_protect_len_q;
  logic fetch_resident_protect_full_ring_q;
  logic fetch_resident_protect_has_successor_q;
  future_frame_candidate_t fetch_future_pairs_q [FUTURE_FRAME_PAIR_COUNT];
  future_frame_candidate_t fetch_future_reduce_q [FUTURE_FRAME_REDUCE_COUNT];
  future_frame_candidate_t fetch_future_final_q [FUTURE_FRAME_FINAL_COUNT];
  logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0] fetch_tail_target_serial_q;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] fetch_tail_status_slot_q;
  logic [N_LANE-1:0][TAIL_STATUS_WRAP_WIDTH-1:0] fetch_tail_target_wrap_q;
  logic [N_LANE-1:0] fetch_tail_ready_q;
  logic [N_LANE-1:0] fetch_tail_shadow_valid_q;
  logic [N_LANE-1:0] fetch_tail_shadow_drop_q;
  logic [N_LANE-1:0] fetch_tail_dropped_q;
  logic [N_LANE-1:0] alloc_lane_active_q;
  logic alloc_lane_accept_q;
  logic alloc_lane_skip_q;
  logic alloc_lane_skipped_q;
  logic alloc_lane_masked_q;
  logic alloc_lane_last_q;
  pkt_length_t alloc_selected_block_length_q;
  ticket_t alloc_lane_ticket_q;
  page_ram_addr_t alloc_lane_dst_addr_q;
  logic [HANDLE_LENGTH-1:0] alloc_lane_handle_data_q;
  logic [N_LANE-1:0] alloc_page_flow_onehot_next_q;
  handle_credit_t handle_credit [N_LANE];
  logic [N_LANE-1:0] handle_credit_available;
  logic [N_LANE-1:0] handle_credit_reserve;
  logic [N_LANE-1:0] fetch_handle_slot_needed;
  logic fetch_handle_slots_ready;
  logic [N_LANE-1:0][TAIL_STATUS_WRAP_WIDTH-1:0] ingress_tail_status_wrap_rd_q;
  logic [N_LANE-1:0][1:0] ingress_tail_status_rd_q;
`ifndef SYNTHESIS
  logic [N_LANE-1:0][TICKET_FIFO_DEPTH-1:0] ingress_tail_status_valid_q;
  logic [N_LANE-1:0][TICKET_FIFO_DEPTH-1:0] ingress_tail_status_drop_q;
`endif
  logic [N_LANE-1:0] page_allocator_is_pending_ticket;
  logic [N_LANE-1:0] page_allocator_is_pending_ticket_lane;
  logic [N_LANE-1:0] page_allocator_ticket_q_valid;
  logic [N_LANE-1:0] page_allocator_is_tk_sop;
  logic [N_LANE-1:0] page_allocator_is_tk_curr;
  logic [N_LANE-1:0] page_allocator_is_tk_future;
  logic [N_LANE-1:0] page_allocator_is_tk_past;
  logic [FRAME_SERIAL_SIZE-1:0] page_allocator_ticket_serial_ref;
  page_allocator_if_read_ticket_ticket_t page_allocator_if_read_ticket_ticket;
  page_allocator_if_read_ticket_ticket_sop_t page_allocator_if_read_ticket_ticket_sop;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_shr_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_fast_page_shr_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_hdr_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_allocator_if_write_page_trl_data;
  logic all_lanes_fetch_ready;
  logic all_lanes_fetch_ready_live;
  logic fast_zero_valid;
  logic [N_LANE-1:0] fast_zero_lane_onehot;
  logic [N_LANE-1:0] fast_zero_stage_lane_onehot;
  logic [N_LANE-1:0] idle_fetch_ready_lane;
  logic [N_LANE-1:0] idle_fetch_ready_lane_q;
  logic [FETCH_READY_PAIR_COUNT-1:0] idle_fetch_ready_pair;
  logic [FETCH_READY_REDUCE_COUNT-1:0] idle_fetch_ready_reduce;
  logic all_lanes_fetch_ready_q;
  logic idle_tail_flush_ready;
  logic idle_tail_flush_base;
  logic idle_tail_flush_ready_decision;
  logic idle_fetch_ready;
  logic idle_fetch_ready_q;
  logic all_present_tk_sop;
  logic any_pending_ticket;
  logic any_pending_ticket_q;
  logic any_pending_curr_sop_ticket;
  logic any_pending_ticket_lane;
  logic any_pending_sop_ticket;
  logic frame_start_waiting_busy_lane;
  logic frame_start_waiting_busy_lane_q;
  logic [N_LANE-1:0] frame_start_waiting_busy_lane_v;
  logic [N_LANE-1:0] frame_start_waiting_busy_lane_v_q;
  logic active_frame_waiting_busy_lane;
  logic active_frame_waiting_busy_lane_q;
  logic [N_LANE-1:0] active_frame_waiting_busy_lane_v;
  logic [N_LANE-1:0] active_frame_waiting_busy_lane_v_q;
  logic [N_LANE-1:0] active_frame_pending_nonfuture_lane;
  logic [N_LANE-1:0] active_frame_pending_nonfuture_lane_q;
  logic [N_LANE-1:0] inactive_frame_join_pending_lane;
  logic inactive_frame_join_sop_pending;
  logic active_frame_pending_nonfuture_ticket;
  logic frame_join_hold;
  logic frame_join_hold_q;
  logic all_present_tk_sop_q;
  logic any_pending_curr_sop_ticket_q;
  logic all_active_lanes_tail_ready;
  logic [N_LANE-1:0] idle_active_tail_ready_lane;
  logic [N_LANE-1:0] idle_active_tail_ready_lane_q;
  (* preserve *) logic [N_LANE-1:0] idle_tk_pending_d1_q;
  (* preserve *) logic [N_LANE-1:0] idle_tk_sop_d1_q;
  (* preserve *) logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0] idle_tk_serial_d1_q;
  (* preserve *) logic [N_LANE-1:0][47:0] idle_tk_ts_d1_q;
  logic [FRAME_SERIAL_SIZE-1:0] idle_tk_serial_ref_d1_q;
  logic [FRAME_SERIAL_SIZE-1:0] idle_tk_frame_serial_this_d1_q;
  logic [47:0] idle_tk_running_ts_d1_q;
  logic [N_LANE-1:0] lanes_with_sop_ticket;
  logic [N_LANE-1:0] lanes_with_curr_sop_ticket;
  logic [N_LANE-1:0] fetch_pending_snapshot_q;
  logic [5:0] header_dt_type;
  logic [15:0] header_feb_id;
  logic [47:0] header_frame_ts;
  logic [47:0] header_running_ts;
  logic packet_complete_pulse;
  logic [N_LANE-1:0] eop_flush_ack;
  logic [N_LANE-1:0] late_frame_drop_valid;
  logic [N_LANE-1:0][15:0] late_frame_drop_hdr_cnt;
  logic [N_LANE-1:0][15:0] late_frame_drop_shd_cnt;
  logic [N_LANE-1:0][15:0] late_frame_drop_hit_cnt;
  logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0] late_frame_drop_serial;
  logic [N_LANE-1:0][47:0] late_frame_drop_ts;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] late_frame_lane_credit_update;
  logic [N_LANE-1:0] late_frame_lane_credit_update_valid;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] packet_complete_frame_start_addr;
  page_ram_addr_t packet_complete_frame_len;
  logic packet_complete_frame_full_ring;
  frame_shr_cnt_t packet_complete_shr_cnt;
  frame_hit_cnt_t packet_complete_hit_cnt;
  frame_shr_cnt_t packet_complete_lane_shd_cnt [N_LANE];
  frame_hit_cnt_t packet_complete_lane_hit_cnt [N_LANE];
  genvar tail_status_lane_idx;

  assign idle_tail_flush_ready_decision =
    idle_tail_flush_base &&
    (active_frame_pending_nonfuture_lane_q == '0) &&
    !frame_join_hold;
  assign idle_fetch_ready =
    all_lanes_fetch_ready_q &&
    any_pending_ticket_q &&
    !active_frame_waiting_busy_lane_q &&
    !frame_join_hold_q &&
    !(all_present_tk_sop_q &&
      any_pending_curr_sop_ticket_q &&
      frame_start_waiting_busy_lane_q);

  generate
    for (tail_status_lane_idx = 0; tail_status_lane_idx < N_LANE; tail_status_lane_idx++) begin : gen_tail_status_wrap_ram
      tile_fifo #(
        .DATA_WIDTH(TAIL_STATUS_WRAP_WIDTH),
        .ADDR_WIDTH(TICKET_FIFO_ADDR_WIDTH)
      ) tail_status_wrap_ram_i (
        .data(tail_status_wrap(ingress_tail_bypass_serial_i[tail_status_lane_idx])),
        .read_addr(fetch_tail_status_slot_q[tail_status_lane_idx]),
        .write_addr(tail_status_slot(ingress_tail_bypass_serial_i[tail_status_lane_idx])),
        .we(ingress_tail_bypass_valid_i[tail_status_lane_idx]),
        .clk(d_clk),
        .q(ingress_tail_status_wrap_rd_q[tail_status_lane_idx])
      );

      tile_fifo #(
        .DATA_WIDTH(2),
        .ADDR_WIDTH(TICKET_FIFO_ADDR_WIDTH)
      ) tail_status_state_ram_i (
        .data({1'b1, ingress_tail_bypass_drop_i[tail_status_lane_idx]}),
        .read_addr(fetch_tail_status_slot_q[tail_status_lane_idx]),
        .write_addr(tail_status_slot(ingress_tail_bypass_serial_i[tail_status_lane_idx])),
        .we(ingress_tail_bypass_valid_i[tail_status_lane_idx]),
        .clk(d_clk),
        .q(ingress_tail_status_rd_q[tail_status_lane_idx])
      );
    end
  endgenerate

  always_comb begin : proc_page_allocator_comb
    int unsigned total_subh_v;
    int unsigned total_hit_v;
    bit header_lane_selected_v;
    bit lane_tail_ready_v;
    total_subh_v = 0;
    total_hit_v = 0;
    all_lanes_fetch_ready = 1'b1;
    all_lanes_fetch_ready_live = 1'b1;
    fast_zero_valid = 1'b0;
    fast_zero_block_length = '0;
    fast_zero_lane_offset = '{default:'0};
    fast_zero_lane_length = '{default:'0};
    fast_zero_pair_length = '{default:'0};
    fast_zero_lane_onehot = '0;
    fast_zero_stage_lane_onehot = '0;
    all_present_tk_sop = 1'b1;
    any_pending_ticket = 1'b0;
    any_pending_curr_sop_ticket = 1'b0;
    any_pending_ticket_lane = 1'b0;
    any_pending_sop_ticket = 1'b0;
    frame_start_waiting_busy_lane = |frame_start_waiting_busy_lane_v_q;
    active_frame_waiting_busy_lane = |active_frame_waiting_busy_lane_v_q;
    frame_start_waiting_busy_lane_v = '0;
    active_frame_waiting_busy_lane_v = '0;
    active_frame_pending_nonfuture_lane = '0;
    inactive_frame_join_pending_lane = '0;
    inactive_frame_join_sop_pending = 1'b0;
    active_frame_pending_nonfuture_ticket = 1'b0;
    frame_join_hold = 1'b0;
    page_allocator_ticket_serial_ref = page_allocator.frame_serial;
    all_active_lanes_tail_ready = 1'b1;
    idle_active_tail_ready_lane = '1;
    idle_tail_flush_ready = 1'b0;
    idle_tail_flush_base = 1'b0;
    lanes_with_sop_ticket = '0;
    lanes_with_curr_sop_ticket = '0;
    header_dt_type = fetch_header_dt_type_q;
    header_feb_id = fetch_header_feb_id_q;
    header_frame_ts = fetch_header_frame_ts_q;
    header_running_ts = fetch_header_running_ts_q;
    header_lane_selected_v = 1'b0;
    page_allocator_if_read_ticket_ticket_sop = '0;
    page_allocator_if_write_page_shr_data = '0;
    page_allocator_if_write_fast_page_shr_data = '0;
    page_allocator_if_write_page_hdr_data = '0;
    page_allocator_if_write_page_trl_data = '0;
    page_allocator_is_tk_sop = '0;
    page_allocator_is_tk_curr = '0;
    page_allocator_is_tk_future = '0;
    page_allocator_is_tk_past = '0;
    page_allocator_is_pending_ticket_lane = '0;
    idle_fetch_ready_lane = '1;
    idle_fetch_ready_pair = '1;
    idle_fetch_ready_reduce = '1;
    ticket_fifos_rd_addr_o = '0;
    handle_we_o = '0;
    handle_wdata_o = '0;
    handle_waddr_o = '0;
    handle_credit_available = '0;
    handle_credit_reserve = '0;
    fetch_handle_slot_needed = '0;
    fetch_handle_slots_ready = 1'b1;
    fast_zero_commit_valid =
      (page_allocator_state == PAGE_ALLOCATOR_FAST_ZERO_COMMIT) &&
      (fast_zero_commit_lane_onehot_q != '0) &&
      (frame_hit_cnt_t'(fast_zero_commit_block_length_q) <= page_allocator.frame_hit_room);

    page_allocator_if_write_page_shr_data[35:32] = 4'b0001;
    page_allocator_if_write_page_shr_data[31:24] = page_allocator.running_ts[11:4];
    page_allocator_if_write_page_shr_data[23:8] = 16'(page_allocator.page_length);
    page_allocator_if_write_page_shr_data[7:0] = K237;
    page_allocator_if_write_fast_page_shr_data = page_allocator_if_write_page_shr_data;

    if (page_allocator.frame_lane_active != '0) begin
      page_allocator_ticket_serial_ref = page_allocator.frame_serial_this;
    end

    page_allocator_if_write_page_trl_data[35:32] = 4'b0001;
    page_allocator_if_write_page_trl_data[7:0] = K284;

    unique case (page_allocator.write_meta_flow)
      3'd0: begin
        page_allocator_if_write_page_hdr_data[35:32] = 4'b0001;
        page_allocator_if_write_page_hdr_data[31:26] = header_dt_type;
        page_allocator_if_write_page_hdr_data[23:8] = header_feb_id;
        page_allocator_if_write_page_hdr_data[7:0] = K285;
      end
      3'd1: begin
        page_allocator_if_write_page_hdr_data[31:0] = page_allocator.frame_ts[47:16];
      end
      3'd2: begin
        page_allocator_if_write_page_hdr_data[31:16] = page_allocator.frame_ts[15:0];
        page_allocator_if_write_page_hdr_data[15:0] = page_allocator.frame_serial_this;
      end
      3'd3: begin
        page_allocator_if_write_page_hdr_data[16+MAX_SHR_CNT_BITS-1:16] = page_allocator.frame_shr_cnt;
        page_allocator_if_write_page_hdr_data[MAX_HIT_CNT_BITS-1:0] = page_allocator.frame_hit_cnt;
      end
      3'd4: begin
        page_allocator_if_write_page_hdr_data[30:0] = page_allocator.running_ts[30:0];
      end
      3'd5: begin
        page_allocator_if_write_page_hdr_data = page_allocator_if_write_page_trl_data;
      end
      default: begin
      end
    endcase

    for (int i = 0; i < N_LANE; i++) begin
      ticket_credit_update_o[i] = page_allocator.ticket_credit_update[i];
      ticket_credit_update_valid_o[i] = page_allocator.ticket_credit_update_valid[i];
      handle_wptr_o[i] = page_allocator.handle_wptr[i];
      eop_flush_ack_o[i] = eop_flush_ack[i];
      late_frame_drop_valid_o[i] = late_frame_drop_valid[i];
      late_frame_drop_hdr_cnt_o[i] = late_frame_drop_hdr_cnt[i];
      late_frame_drop_shd_cnt_o[i] = late_frame_drop_shd_cnt[i];
      late_frame_drop_hit_cnt_o[i] = late_frame_drop_hit_cnt[i];
      late_frame_drop_serial_o[i] = late_frame_drop_serial[i];
      late_frame_drop_ts_o[i] = late_frame_drop_ts[i];
      late_frame_lane_credit_update_o[i] = late_frame_lane_credit_update[i];
      late_frame_lane_credit_update_valid_o[i] = late_frame_lane_credit_update_valid[i];

      page_allocator_is_pending_ticket[i] = (ingress_ticket_wptr[i] != page_allocator.ticket_rptr[i]);
      any_pending_ticket |= page_allocator_is_pending_ticket[i];

      page_allocator_if_read_ticket_ticket[i].ticket_ts = ticket_fifos_rd_data_stage_q[i][TICKET_TS_HI:TICKET_TS_LO];
      page_allocator_if_read_ticket_ticket[i].lane_fifo_rd_offset =
        ticket_fifos_rd_data_stage_q[i][TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO];
      page_allocator_if_read_ticket_ticket[i].block_length =
        ticket_fifos_rd_data_stage_q[i][TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO];
      if (ticket_fifos_rd_data_stage_q[i][TICKET_ALT_SOP_LOC]) begin
        page_allocator_if_read_ticket_ticket[i].frame_serial =
          ticket_fifos_rd_data_stage_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
      end else begin
        page_allocator_if_read_ticket_ticket[i].frame_serial =
          ticket_fifos_rd_data_stage_q[i][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO];
      end
      page_allocator_if_read_ticket_ticket[i].alert_eop = ticket_fifos_rd_data_stage_q[i][TICKET_ALT_EOP_LOC];
      page_allocator_if_read_ticket_ticket[i].alert_sop = ticket_fifos_rd_data_stage_q[i][TICKET_ALT_SOP_LOC];

      if (page_allocator_is_pending_ticket[i] && ticket_fifos_rd_data_stage_q[i][TICKET_ALT_SOP_LOC]) begin
        page_allocator_is_tk_sop[i] = 1'b1;
        lanes_with_sop_ticket[i] = 1'b1;
        if (ticket_fifos_rd_data_stage_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] ==
            page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_curr[i] = 1'b1;
          lanes_with_curr_sop_ticket[i] = 1'b1;
          total_subh_v += int'(ticket_fifos_rd_data_stage_q[i][TICKET_N_SUBH_HI:TICKET_N_SUBH_LO]);
          total_hit_v += int'(ticket_fifos_rd_data_stage_q[i][TICKET_N_HIT_HI:TICKET_N_HIT_LO]);
          if (!header_lane_selected_v) begin
            header_dt_type = ticket_fifos_rd_data_stage_q[i][TICKET_DT_TYPE_HI:TICKET_DT_TYPE_LO];
            header_feb_id = ticket_fifos_rd_data_stage_q[i][TICKET_FEB_ID_HI:TICKET_FEB_ID_LO];
            header_frame_ts = ticket_fifos_rd_data_stage_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
            header_running_ts = ticket_fifos_rd_data_stage_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
            page_allocator_if_read_ticket_ticket_sop.serial =
              ticket_fifos_rd_data_stage_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
            header_lane_selected_v = 1'b1;
          end
        end
      end

      if (!page_allocator_is_pending_ticket[i]) begin
        page_allocator_is_tk_future[i] = 1'b0;
        page_allocator_is_tk_past[i] = 1'b0;
      end else if (page_allocator_is_tk_sop[i]) begin
        if (ticket_fifos_rd_data_stage_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] > page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_future[i] = 1'b1;
        end
        if (ticket_fifos_rd_data_stage_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] < page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_past[i] = 1'b1;
        end
      end else begin
        if (page_allocator_if_read_ticket_ticket[i].frame_serial > page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_future[i] = 1'b1;
        end else if (page_allocator_if_read_ticket_ticket[i].frame_serial < page_allocator_ticket_serial_ref) begin
          page_allocator_is_tk_past[i] = 1'b1;
        end else begin
          if (ticket_fifos_rd_data_stage_q[i][47:0] > page_allocator.running_ts) begin
            page_allocator_is_tk_future[i] = 1'b1;
          end
          if (ticket_fifos_rd_data_stage_q[i][47:0] < page_allocator.running_ts) begin
            page_allocator_is_tk_past[i] = 1'b1;
          end
        end
      end

      page_allocator_is_pending_ticket_lane[i] = &page_allocator_is_pending_ticket_d[i];
      page_allocator_ticket_q_valid[i] =
        (page_allocator_ticket_rptr_d[i][FIFO_RAW_DELAY] == page_allocator.ticket_rptr[i]);
      any_pending_ticket_lane |= page_allocator_is_pending_ticket_lane[i];
      idle_fetch_ready_lane[i] =
        !page_allocator_is_pending_ticket[i] ||
        (page_allocator_is_pending_ticket_lane[i] &&
         page_allocator_ticket_q_valid[i]);
      lane_tail_ready_v = page_allocator.frame_lane_tail_seen[i];
      if (!page_allocator_is_pending_ticket[i] && ingress_parser_busy_i[i]) begin
        frame_start_waiting_busy_lane_v[i] = 1'b1;
      end
      if (page_allocator.frame_lane_active[i] &&
          !lane_tail_ready_v &&
          !page_allocator_is_pending_ticket[i] &&
          ingress_parser_busy_i[i]) begin
        active_frame_waiting_busy_lane_v[i] = 1'b1;
      end
      if ((page_allocator.frame_lane_active != '0) &&
          !page_allocator.frame_lane_active[i] &&
          !page_allocator_is_pending_ticket[i] &&
          ingress_parser_busy_i[i] &&
          (ingress_frame_ts_i[i] == page_allocator.frame_ts)) begin
        // A lane can still be parsing the current frame after another lane has
        // already opened it. Keep the frame alive until that parser either
        // surfaces its ticket or drains to idle; otherwise the late body
        // ticket can be reclassified against the next frame and dropped.
        active_frame_pending_nonfuture_lane[i] = 1'b1;
        inactive_frame_join_pending_lane[i] = 1'b1;
        active_frame_pending_nonfuture_ticket = 1'b1;
      end
      if (page_allocator_is_pending_ticket[i] && idle_tk_sop_q[i]) begin
        any_pending_sop_ticket = 1'b1;
        if (idle_tk_curr_q[i]) begin
          any_pending_curr_sop_ticket = 1'b1;
        end
      end
      if (page_allocator_is_pending_ticket[i] && !idle_tk_sop_q[i]) begin
        all_present_tk_sop = 1'b0;
      end
      if (page_allocator.frame_lane_active[i] &&
          page_allocator_is_pending_ticket[i] &&
          (!page_allocator_is_pending_ticket_lane[i] ||
           !page_allocator_ticket_q_valid[i] ||
           idle_tk_active_frame_q[i] ||
           !idle_tk_future_q[i])) begin
        // The tail-retire path now consumes the registered IDLE decode
        // snapshot. Any newly arrived or not-yet-future ticket therefore
        // blocks retirement until the snapshot has a confirmed class.
        // A same-serial body ticket is still part of the current frame even
        // when its timestamp is ahead of the current subheader cursor.
        active_frame_pending_nonfuture_lane[i] = 1'b1;
        active_frame_pending_nonfuture_ticket = 1'b1;
      end
      if ((page_allocator.frame_lane_active != '0) &&
          !page_allocator.frame_lane_active[i] &&
          page_allocator_is_pending_ticket[i]) begin
        if (!page_allocator_is_pending_ticket_lane[i] ||
            !page_allocator_ticket_q_valid[i]) begin
          active_frame_pending_nonfuture_lane[i] = 1'b1;
          inactive_frame_join_pending_lane[i] = 1'b1;
          active_frame_pending_nonfuture_ticket = 1'b1;
        end else if (!idle_tk_sop_q[i] &&
                     idle_tk_active_frame_q[i]) begin
          // A skewed whole-frame lane can surface its first body ticket after
          // another lane has already opened the frame. Keep that current-frame
          // ownership alive instead of retiring the frame and late-dropping the
          // straggling body ticket one cycle later.
          active_frame_pending_nonfuture_lane[i] = 1'b1;
          inactive_frame_join_pending_lane[i] = 1'b1;
          active_frame_pending_nonfuture_ticket = 1'b1;
        end else if (idle_tk_sop_q[i] &&
                     idle_tk_curr_q[i]) begin
          // An inactive lane can still surface the current-frame SOP after the
          // frame has already been opened by another lane. Keep the frame live
          // until that SOP is absorbed and the lane is reactivated, otherwise
          // the following body ticket ages into the late-drop path.
          active_frame_pending_nonfuture_lane[i] = 1'b1;
          inactive_frame_join_pending_lane[i] = 1'b1;
          inactive_frame_join_sop_pending = 1'b1;
          active_frame_pending_nonfuture_ticket = 1'b1;
        end
      end
      if (page_allocator.frame_lane_active[i] &&
          !(lane_tail_ready_v &&
            (!page_allocator_is_pending_ticket[i] ||
             (page_allocator_is_pending_ticket_lane[i] &&
              page_allocator_ticket_q_valid[i] &&
              idle_tk_future_q[i] &&
              !idle_tk_active_frame_q[i])))) begin
        idle_active_tail_ready_lane[i] = 1'b0;
        all_active_lanes_tail_ready = 1'b0;
      end

      handle_we_o[i] = page_allocator.handle_we[i];
      handle_wdata_o[i] = page_allocator.handle_wdata[i];
      handle_waddr_o[i] = page_allocator.handle_waddr[i];
      ticket_fifos_rd_addr_o[i] = page_allocator.ticket_rptr[i];
      tk_future_o[i] = page_allocator_is_tk_future[i];
      handle_credit_available[i] =
        (handle_credit[i] != '0) || handle_credit_update_valid_i[i];
      fetch_handle_slot_needed[i] =
        (fetch_lane_action_q[i] == FETCH_LANE_LOAD) &&
        (fetch_ticket_q[i].block_length != '0);
      if (fetch_handle_slot_needed[i] && !handle_credit_available[i]) begin
        fetch_handle_slots_ready = 1'b0;
      end
    end

    for (int i = 0; i < N_LANE; i++) begin
      fast_zero_stage_lane_onehot[i] =
        page_allocator.frame_lane_active[i] &&
        page_allocator_is_pending_ticket[i] &&
        page_allocator_is_pending_ticket_lane[i] &&
        page_allocator_ticket_q_valid[i] &&
        !ticket_fifos_rd_data_stage_q[i][TICKET_ALT_SOP_LOC] &&
        !ticket_fifos_rd_data_stage_q[i][TICKET_ALT_EOP_LOC] &&
        (page_allocator_if_read_ticket_ticket[i].frame_serial == page_allocator.frame_serial_this) &&
        (page_allocator_if_read_ticket_ticket[i].ticket_ts == page_allocator.running_ts) &&
        ((page_allocator_if_read_ticket_ticket[i].block_length == '0) ||
         handle_credit_available[i]);
    end
    fast_zero_lane_onehot = fast_zero_stage_lane_onehot;
    if (fast_zero_lane_onehot != '0) begin
      for (int i = 0; i < N_LANE; i++) begin
        if (fast_zero_lane_onehot[i]) begin
          fast_zero_lane_length[i] =
            page_length_t'(page_allocator_if_read_ticket_ticket[i].block_length);
        end
      end
      for (int i = 0; i < FAST_ZERO_PAIR_COUNT; i++) begin
        fast_zero_pair_length[i] = fast_zero_lane_length[2*i];
        if ((2*i + 1) < N_LANE) begin
          fast_zero_pair_length[i] =
            fast_zero_pair_length[i] + fast_zero_lane_length[2*i + 1];
        end
      end
      for (int i = 0; i < N_LANE; i++) begin
        for (int pair_idx = 0; pair_idx < (i / 2); pair_idx++) begin
          fast_zero_lane_offset[i] =
            fast_zero_lane_offset[i] + fast_zero_pair_length[pair_idx];
        end
        if ((i % 2) != 0) begin
          fast_zero_lane_offset[i] =
            fast_zero_lane_offset[i] + fast_zero_lane_length[i - 1];
        end
      end
      for (int i = 0; i < FAST_ZERO_PAIR_COUNT; i++) begin
        fast_zero_block_length = fast_zero_block_length + fast_zero_pair_length[i];
      end
    end
    fast_zero_valid =
      (page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
      (page_allocator.frame_lane_active != '0) &&
      (fast_zero_lane_onehot == page_allocator.frame_lane_active) &&
      (inactive_frame_join_pending_lane == '0) &&
      !inactive_frame_join_sop_pending &&
      !idle_tail_flush_ready_decision;

    if (fast_zero_commit_valid) begin
      for (int i = 0; i < N_LANE; i++) begin
        if (fast_zero_commit_lane_onehot_q[i] &&
            (fast_zero_commit_ticket_q[i].block_length != '0)) begin
          handle_credit_reserve[i] = 1'b1;
        end
      end
    end

    if (page_allocator_state == PAGE_ALLOCATOR_COMMIT_PAGE) begin
      logic alloc_handle_skip_comb_v;
      alloc_handle_skip_comb_v = alloc_lane_skipped_q || alloc_lane_skip_q;
      for (int i = 0; i < N_LANE; i++) begin
        if (alloc_lane_active_q[i] &&
            (alloc_selected_block_length_q != '0) &&
            (alloc_handle_skip_comb_v ||
             (!alloc_lane_masked_q && alloc_lane_accept_q))) begin
          handle_credit_reserve[i] = 1'b1;
        end
      end
    end

    all_lanes_fetch_ready_live = &idle_fetch_ready_lane;

    for (int i = 0; i < FETCH_READY_PAIR_COUNT; i++) begin
      idle_fetch_ready_pair[i] = idle_fetch_ready_lane_q[2*i];
      if ((2*i + 1) < N_LANE) begin
        idle_fetch_ready_pair[i] &= idle_fetch_ready_lane_q[2*i + 1];
      end
    end

    for (int i = 0; i < FETCH_READY_REDUCE_COUNT; i++) begin
      idle_fetch_ready_reduce[i] = idle_fetch_ready_pair[2*i];
      if ((2*i + 1) < FETCH_READY_PAIR_COUNT) begin
        idle_fetch_ready_reduce[i] &= idle_fetch_ready_pair[2*i + 1];
      end
    end
    all_lanes_fetch_ready = &idle_fetch_ready_reduce;

    if ((page_allocator.frame_join_wait != '0) &&
        (page_allocator.frame_lane_active != '0) &&
        (page_allocator.frame_lane_active != '1) &&
        !all_active_lanes_tail_ready &&
        !inactive_frame_join_sop_pending) begin
      frame_join_hold = 1'b1;
    end
    idle_tail_flush_base =
      (page_allocator.frame_lane_active != '0) &&
      (&idle_active_tail_ready_lane_q) &&
      (page_allocator.frame_cnt != '0);
    idle_tail_flush_ready =
      idle_tail_flush_base &&
      !active_frame_pending_nonfuture_ticket &&
      !frame_join_hold;
    page_allocator_if_read_ticket_ticket_sop.n_subh = frame_shr_cnt_t'(total_subh_v);
    page_allocator_if_read_ticket_ticket_sop.n_hit = frame_hit_cnt_t'(total_hit_v);
    page_allocator_if_write_fast_page_shr_data = page_allocator_if_write_page_shr_data;
    page_allocator_if_write_fast_page_shr_data[23:8] = 16'(fast_zero_block_length);

    page_we_o =
      page_allocator.page_we ||
      fast_zero_commit_valid;
    page_waddr_o =
      (page_allocator_state == PAGE_ALLOCATOR_FAST_ZERO_COMMIT) ?
        fast_zero_commit_page_addr_q :
        page_allocator.page_waddr;
    fetch_ticket_active_o =
      (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_SAMPLE_TAIL) ||
      (page_allocator_state == PAGE_ALLOCATOR_RESOLVE_TAIL) ||
      (page_allocator_state == PAGE_ALLOCATOR_CLASSIFY_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_SELECT_HEADER) ||
      (page_allocator_state == PAGE_ALLOCATOR_ACCUM_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_REDUCE_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_SUMMARIZE_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_REDUCE_FUTURE) ||
      (page_allocator_state == PAGE_ALLOCATOR_REDUCE_FUTURE_FINAL) ||
      (page_allocator_state == PAGE_ALLOCATOR_FINALIZE_SUMMARY) ||
      (page_allocator_state == PAGE_ALLOCATOR_PREDICT_RESIDENT) ||
      (page_allocator_state == PAGE_ALLOCATOR_PREDICT_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_DECIDE_TICKET) ||
      (page_allocator_state == PAGE_ALLOCATOR_APPLY_TICKET);
    alloc_page_active_o =
      (page_allocator_state == PAGE_ALLOCATOR_ALLOC_PAGE) ||
      (page_allocator_state == PAGE_ALLOCATOR_COMMIT_PAGE);
    write_head_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_HEAD);
    write_tail_active_o = (page_allocator_state == PAGE_ALLOCATOR_WRITE_TAIL);
    write_page_active_o =
      (page_allocator_state == PAGE_ALLOCATOR_WRITE_PAGE) ||
      fast_zero_commit_valid;
    write_meta_flow_o = page_allocator.write_meta_flow;
    write_meta_flow_d1_o = page_allocator.write_meta_flow_d1;
    frame_start_addr_o = page_allocator.frame_start_addr;
    frame_shr_cnt_this_o = page_allocator.frame_shr_cnt_this;
    frame_hit_cnt_this_o = page_allocator.frame_hit_cnt_this;
    for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
      frame_lane_shd_cnt_this_o[lane_idx] = page_allocator.frame_lane_shd_cnt_this[lane_idx];
      frame_lane_hit_cnt_this_o[lane_idx] = page_allocator.frame_lane_hit_cnt_this[lane_idx];
      packet_complete_lane_shd_cnt_o[lane_idx] = packet_complete_lane_shd_cnt[lane_idx];
      packet_complete_lane_hit_cnt_o[lane_idx] = packet_complete_lane_hit_cnt[lane_idx];
    end
    packet_complete_frame_start_addr_o = packet_complete_frame_start_addr;
    packet_complete_shr_cnt_o = packet_complete_shr_cnt;
    packet_complete_hit_cnt_o = packet_complete_hit_cnt;
    packet_complete_pulse_o = packet_complete_pulse;
    if (fast_zero_commit_valid) begin
      page_wdata_o = fast_zero_commit_page_data_q;
    end else begin
      unique case (page_allocator_state)
        PAGE_ALLOCATOR_WRITE_PAGE: page_wdata_o = page_allocator_if_write_page_shr_data;
        PAGE_ALLOCATOR_WRITE_HEAD,
        PAGE_ALLOCATOR_WRITE_TAIL: page_wdata_o = page_allocator_if_write_page_hdr_data;
        default: page_wdata_o = '0;
      endcase
    end
  end

  always_ff @(posedge d_clk) begin : proc_handle_credit
    for (int i = 0; i < N_LANE; i++) begin
      logic [HANDLE_CREDIT_WIDTH:0] credit_next_v;

      if (d_reset) begin
        handle_credit[i] <= handle_credit_t'(HANDLE_FIFO_MAX_CREDIT);
      end else begin
        credit_next_v = {1'b0, handle_credit[i]};
        if (handle_credit_update_valid_i[i] &&
            (credit_next_v < (HANDLE_CREDIT_WIDTH+1)'(HANDLE_FIFO_MAX_CREDIT))) begin
          credit_next_v = credit_next_v + {{HANDLE_CREDIT_WIDTH{1'b0}}, 1'b1};
        end
        if (handle_credit_reserve[i] && (credit_next_v != '0)) begin
          credit_next_v = credit_next_v - {{HANDLE_CREDIT_WIDTH{1'b0}}, 1'b1};
        end
        handle_credit[i] <= handle_credit_t'(credit_next_v[HANDLE_CREDIT_WIDTH-1:0]);
      end
    end
  end

  always_ff @(posedge d_clk) begin : proc_page_allocator
    for (int i = 0; i < N_LANE; i++) begin
      page_allocator.ticket_credit_update_valid[i] <= 1'b0;
      page_allocator.handle_we[i] <= 1'b0;
      page_allocator.handle_wflag[i] <= 1'b0;
    end
    page_allocator.page_we <= 1'b0;
    packet_complete_pulse <= 1'b0;
    packet_complete_frame_start_addr <= packet_complete_frame_start_addr;
    packet_complete_shr_cnt <= packet_complete_shr_cnt;
    packet_complete_hit_cnt <= packet_complete_hit_cnt;
    packet_complete_lane_shd_cnt <= packet_complete_lane_shd_cnt;
    packet_complete_lane_hit_cnt <= packet_complete_lane_hit_cnt;
    eop_flush_ack <= '0;
    late_frame_drop_valid <= '0;
    late_frame_drop_hdr_cnt <= '{default:'0};
    late_frame_drop_shd_cnt <= '{default:'0};
    late_frame_drop_hit_cnt <= '{default:'0};
    late_frame_drop_serial <= '{default:'0};
    late_frame_drop_ts <= '{default:'0};
    late_frame_lane_credit_update <= '{default:'0};
    late_frame_lane_credit_update_valid <= '0;
    ticket_fifos_rd_data_stage_q <= ticket_fifos_rd_data_i;
    resident_protect_valid_stage_q <= resident_protect_valid_i;
    resident_protect_addr_stage_q <= resident_protect_addr_i;
    resident_protect_len_stage_q <= resident_protect_len_i;
    resident_protect_full_ring_stage_q <= resident_protect_full_ring_i;
    resident_protect_has_successor_stage_q <= resident_protect_has_successor_i;

    for (int i = 0; i < N_LANE; i++) begin
      if (ingress_tail_bypass_valid_i[i]) begin
        ticket_fifo_addr_t tail_status_slot_v;

        tail_status_slot_v = ticket_fifo_addr_t'(ingress_tail_bypass_serial_i[i]);
        page_allocator.ingress_tail_seen_valid[i] <= 1'b1;
        page_allocator.ingress_tail_serial_seen[i] <= ingress_tail_bypass_serial_i[i];
        page_allocator.ingress_tail_drop_seen[i] <= ingress_tail_bypass_drop_i[i];
        page_allocator.ingress_tail_ts_seen[i] <= ingress_tail_bypass_ts_i[i];
`ifndef SYNTHESIS
        ingress_tail_status_valid_q[i][tail_status_slot_v] <= 1'b1;
        ingress_tail_status_drop_q[i][tail_status_slot_v] <= ingress_tail_bypass_drop_i[i];
`endif
      end
      if (page_allocator.frame_lane_active[i] &&
          ((ingress_tail_bypass_valid_i[i] &&
            serial_reached_or_passed(
              ingress_tail_bypass_serial_i[i],
              page_allocator.frame_serial_this
            )) ||
           (page_allocator.ingress_tail_seen_valid[i] &&
            serial_reached_or_passed(
              page_allocator.ingress_tail_serial_seen[i],
              page_allocator.frame_serial_this
            )))) begin
        page_allocator.frame_lane_tail_seen[i] <= 1'b1;
      end
    end

    unique case (page_allocator_state)
      PAGE_ALLOCATOR_IDLE: begin
        if (idle_tail_flush_ready_decision) begin
`ifndef SYNTHESIS
            if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
              $display(
                "[opq_pa_decision] t=%0t idle_to_write_tail running_ts=0x%0h frame_lane_active=0x%0h page_len=%0d frame_shd=%0d frame_hit=%0d pending=0x%0h pending_lane=0x%0h q_valid=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h ingress_busy=0x%0h",
                $time,
                page_allocator.running_ts,
                page_allocator.frame_lane_active,
                page_allocator.page_length,
                page_allocator.frame_shr_cnt,
                page_allocator.frame_hit_cnt,
                page_allocator_is_pending_ticket,
                page_allocator_is_pending_ticket_lane,
                page_allocator_ticket_q_valid,
                page_allocator_is_tk_sop,
                page_allocator_is_tk_curr,
                page_allocator_is_tk_future,
                page_allocator_is_tk_past,
                ingress_parser_busy_i
              );
            end
`endif
          page_allocator_state <= PAGE_ALLOCATOR_PREPARE_WRITE_TAIL;
        end else if (fast_zero_valid) begin
          page_allocator_state <= PAGE_ALLOCATOR_FAST_ZERO_ISSUE;
        end else if (idle_fetch_ready_q && !frame_join_hold) begin
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display(
              "[opq_pa_decision] t=%0t idle_to_fetch running_ts=0x%0h frame_lane_active=0x%0h pending=0x%0h pending_lane=0x%0h q_valid=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h ingress_busy=0x%0h",
              $time,
              page_allocator.running_ts,
              page_allocator.frame_lane_active,
              page_allocator_is_pending_ticket,
              page_allocator_is_pending_ticket_lane,
              page_allocator_ticket_q_valid,
              page_allocator_is_tk_sop,
              page_allocator_is_tk_curr,
              page_allocator_is_tk_future,
              page_allocator_is_tk_past,
              ingress_parser_busy_i
            );
            for (int dbg_lane = 0; dbg_lane < N_LANE; dbg_lane++) begin
              if (page_allocator_is_pending_ticket[dbg_lane]) begin
                $display(
                  "[opq_pa_ticket] t=%0t lane=%0d running_ts=0x%0h raw=0x%0h ts=0x%0h body_serial=0x%0h sop_serial=0x%0h sop=%0b eop=%0b rptr=0x%0h wptr=0x%0h q_valid=%0b future=%0b past=%0b",
                  $time,
                  dbg_lane,
                  page_allocator.running_ts,
                  ticket_fifos_rd_data_stage_q[dbg_lane],
                  ticket_fifos_rd_data_stage_q[dbg_lane][TICKET_TS_HI:TICKET_TS_LO],
                  ticket_fifos_rd_data_stage_q[dbg_lane][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO],
                  ticket_fifos_rd_data_stage_q[dbg_lane][TICKET_SERIAL_HI:TICKET_SERIAL_LO],
                  ticket_fifos_rd_data_stage_q[dbg_lane][TICKET_ALT_SOP_LOC],
                  ticket_fifos_rd_data_stage_q[dbg_lane][TICKET_ALT_EOP_LOC],
                  page_allocator.ticket_rptr[dbg_lane],
                  ingress_ticket_wptr[dbg_lane],
                  page_allocator_ticket_q_valid[dbg_lane],
                  page_allocator_is_tk_future[dbg_lane],
                  page_allocator_is_tk_past[dbg_lane]
                );
              end
            end
          end
`endif
          page_allocator_state <= PAGE_ALLOCATOR_FETCH_TICKET;
        end
        end

      PAGE_ALLOCATOR_FAST_ZERO_ISSUE: begin
          fast_zero_commit_lane_onehot_q <= fast_zero_lane_onehot;
          fast_zero_commit_ticket_q <= '{default:TICKET_DEFAULT};
          fast_zero_commit_block_length_q <= fast_zero_block_length;
          fast_zero_commit_lane_offset_q <= fast_zero_lane_offset;
          fast_zero_commit_page_addr_q <= page_allocator.page_start_addr;
          fast_zero_commit_page_data_q <= page_allocator_if_write_fast_page_shr_data;
          for (int i = 0; i < N_LANE; i++) begin
            if (fast_zero_lane_onehot[i]) begin
              fast_zero_commit_ticket_q[i] <= page_allocator_if_read_ticket_ticket[i];
`ifndef SYNTHESIS
              if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
                $display(
                  "[opq_pa_fast_issue] t=%0t lane=%0d ts=0x%0h serial=0x%0h len=%0d lane_offset=%0d total_len=%0d running_ts=0x%0h page_addr=0x%0h join_wait=%0d",
                  $time,
                  i,
                  page_allocator_if_read_ticket_ticket[i].ticket_ts,
                  page_allocator_if_read_ticket_ticket[i].frame_serial,
                  page_allocator_if_read_ticket_ticket[i].block_length,
                  fast_zero_lane_offset[i],
                  fast_zero_block_length,
                  page_allocator.running_ts,
                  page_allocator.page_start_addr,
                  page_allocator.frame_join_wait
                );
              end
`endif
            end
          end
          page_allocator_state <= PAGE_ALLOCATOR_FAST_ZERO_COMMIT;
        end

      PAGE_ALLOCATOR_PREPARE_WRITE_TAIL: begin
        eop_flush_ack <= '1;
        page_allocator.page_we <= 1'b1;
        page_allocator.page_waddr <= page_allocator.frame_start_addr + page_ram_addr_t'(3);
        page_allocator.frame_start_addr_last <= page_allocator.frame_start_addr;
        page_allocator.frame_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
        page_allocator.write_meta_flow <= WRITE_META_FLOW_WIDTH'(3);
        page_allocator.write_trailer <= 1'b1;
        page_allocator.tail_only_flush <= 1'b1;
        page_allocator.frame_lane_active <= '0;
        page_allocator.frame_lane_tail_seen <= '0;
        page_allocator_state <= PAGE_ALLOCATOR_WRITE_TAIL;
        end

      PAGE_ALLOCATOR_FETCH_TICKET: begin
        // Use the live FIFO-read validity interlock so an rptr update from the
        // previous apply step cannot be followed by a stale ticket snapshot.
        if (!all_lanes_fetch_ready_live || !any_pending_ticket) begin
          page_allocator_state <= PAGE_ALLOCATOR_FETCH_TICKET;
        end else begin
          for (int i = 0; i < N_LANE; i++) begin
            fetch_pending_q[i] <=
              page_allocator_is_pending_ticket[i] &&
              page_allocator_is_pending_ticket_lane[i] &&
              page_allocator_ticket_q_valid[i];
            fetch_ticket_q[i] <= page_allocator_if_read_ticket_ticket[i];
            fetch_ticket_raw_q[i] <= ticket_fifos_rd_data_stage_q[i];
          end
          // Fallback header fields are only used when no current-frame SOP lane
          // is selected. Seed them from stable parser inputs here and let the
          // registered winning header lane override them in SUMMARIZE_TICKET.
          fetch_default_header_dt_type_q <= ingress_dt_type_i[0];
          fetch_default_header_feb_id_q <= ingress_feb_id_i[0];
          fetch_default_header_frame_ts_q <= ingress_frame_ts_i[0];
          fetch_default_header_running_ts_q <= ingress_frame_ts_i[0];
          fetch_ticket_serial_ref_q <= page_allocator.frame_serial;
          if (page_allocator.frame_lane_active != '0) begin
            fetch_ticket_serial_ref_q <= page_allocator.frame_serial_this;
          end
          page_allocator_state <= PAGE_ALLOCATOR_DECODE_TICKET;
        end
        end

      PAGE_ALLOCATOR_DECODE_TICKET: begin
        for (int i = 0; i < N_LANE; i++) begin
          logic [FRAME_SERIAL_SIZE-1:0] tail_target_serial_v;

          if (fetch_ticket_raw_q[i][TICKET_ALT_SOP_LOC]) begin
            tail_target_serial_v = fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
          end else begin
            tail_target_serial_v = fetch_ticket_q[i].frame_serial;
          end
          fetch_tail_target_serial_q[i] <= tail_target_serial_v;
          fetch_tail_status_slot_q[i] <= tail_status_slot(tail_target_serial_v);
          fetch_tail_target_wrap_q[i] <= tail_status_wrap(tail_target_serial_v);
        end
        page_allocator_state <= PAGE_ALLOCATOR_SAMPLE_TAIL;
        end

      PAGE_ALLOCATOR_SAMPLE_TAIL: begin
        for (int i = 0; i < N_LANE; i++) begin
          logic tail_ready_now_v;
          logic seen_tail_matches_v;

          seen_tail_matches_v =
            page_allocator.ingress_tail_seen_valid[i] &&
            serial_reached_or_passed(
              page_allocator.ingress_tail_serial_seen[i],
              fetch_tail_target_serial_q[i]
            );
          tail_ready_now_v = seen_tail_matches_v;
          fetch_tail_ready_q[i] <= tail_ready_now_v;
        end
        page_allocator_state <= PAGE_ALLOCATOR_RESOLVE_TAIL;
        end

      PAGE_ALLOCATOR_RESOLVE_TAIL: begin
        for (int i = 0; i < N_LANE; i++) begin
          fetch_tail_shadow_valid_q[i] <= ingress_tail_status_rd_q[i][1];
          fetch_tail_shadow_drop_q[i] <= ingress_tail_status_rd_q[i][0];
          fetch_tail_dropped_q[i] <=
            ingress_tail_status_rd_q[i][1] &&
            (ingress_tail_status_wrap_rd_q[i] == fetch_tail_target_wrap_q[i]) &&
            ingress_tail_status_rd_q[i][0];
        end
        page_allocator_state <= PAGE_ALLOCATOR_CLASSIFY_TICKET;
        end

      PAGE_ALLOCATOR_CLASSIFY_TICKET: begin
        logic [N_LANE-1:0] tk_sop_v;
        logic [N_LANE-1:0] tk_curr_v;
        logic [N_LANE-1:0] tk_curr_sop_usable_v;
        logic [N_LANE-1:0] tk_future_v;
        logic [N_LANE-1:0] tk_past_v;
        logic [N_LANE-1:0] lanes_with_curr_sop_v;
        logic all_present_tk_sop_v;
        logic any_pending_sop_v;
        logic any_pending_curr_sop_v;
        logic [FRAME_SERIAL_SIZE-1:0] ticket_serial_ref_v;

        tk_sop_v = '0;
        tk_curr_v = '0;
        tk_curr_sop_usable_v = '0;
        tk_future_v = '0;
        tk_past_v = '0;
        lanes_with_curr_sop_v = '0;
        all_present_tk_sop_v = 1'b1;
        any_pending_sop_v = 1'b0;
        any_pending_curr_sop_v = 1'b0;
        ticket_serial_ref_v = fetch_ticket_serial_ref_q;

        for (int i = 0; i < N_LANE; i++) begin
          if (fetch_pending_q[i] && fetch_ticket_raw_q[i][TICKET_ALT_SOP_LOC]) begin
            tk_sop_v[i] = 1'b1;
            any_pending_sop_v = 1'b1;
            if (fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] ==
                ticket_serial_ref_v) begin
              tk_curr_v[i] = 1'b1;
              if (!fetch_tail_dropped_q[i]) begin
                tk_curr_sop_usable_v[i] = 1'b1;
                lanes_with_curr_sop_v[i] = 1'b1;
                any_pending_curr_sop_v = 1'b1;
              end
            end
          end

          if (!fetch_pending_q[i]) begin
            tk_future_v[i] = 1'b0;
            tk_past_v[i] = 1'b0;
          end else if (tk_sop_v[i]) begin
            if (fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] > ticket_serial_ref_v) begin
              tk_future_v[i] = 1'b1;
            end
            if (fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO] < ticket_serial_ref_v) begin
              tk_past_v[i] = 1'b1;
            end
          end else begin
            if (fetch_ticket_q[i].frame_serial > ticket_serial_ref_v) begin
              tk_future_v[i] = 1'b1;
            end else if (fetch_ticket_q[i].frame_serial < ticket_serial_ref_v) begin
              tk_past_v[i] = 1'b1;
            end else begin
              if (fetch_ticket_q[i].ticket_ts > page_allocator.running_ts) begin
                tk_future_v[i] = 1'b1;
              end
              if (fetch_ticket_q[i].ticket_ts < page_allocator.running_ts) begin
                tk_past_v[i] = 1'b1;
              end
            end
          end

          if (fetch_pending_q[i] && !tk_sop_v[i]) begin
            all_present_tk_sop_v = 1'b0;
          end

          if (tk_curr_sop_usable_v[i]) begin
            fetch_curr_sop_n_subh_q[i] <=
              frame_shr_cnt_t'(fetch_ticket_raw_q[i][TICKET_N_SUBH_HI:TICKET_N_SUBH_LO]);
            fetch_curr_sop_n_hit_q[i] <=
              frame_hit_cnt_t'(fetch_ticket_raw_q[i][TICKET_N_HIT_HI:TICKET_N_HIT_LO]);
          end else begin
            fetch_curr_sop_n_subh_q[i] <= '0;
            fetch_curr_sop_n_hit_q[i] <= '0;
          end
        end

        fetch_tk_sop_q <= tk_sop_v;
        fetch_tk_curr_q <= tk_curr_v;
        fetch_tk_future_q <= tk_future_v;
        fetch_tk_past_q <= tk_past_v;
        fetch_all_present_tk_sop_q <= all_present_tk_sop_v;
        fetch_any_pending_sop_q <= any_pending_sop_v;
        fetch_any_pending_curr_sop_q <= any_pending_curr_sop_v;
        fetch_lanes_with_curr_sop_q <= lanes_with_curr_sop_v;
        fetch_sop_serial_q <= fetch_ticket_serial_ref_q;
        page_allocator_state <= PAGE_ALLOCATOR_SELECT_HEADER;
        end

      PAGE_ALLOCATOR_SELECT_HEADER: begin
        logic header_lane_selected_v;
        logic [FUTURE_FRAME_LANE_WIDTH-1:0] header_lane_v;

        header_lane_selected_v = 1'b0;
        header_lane_v = '0;

        for (int i = 0; i < N_LANE; i++) begin
          if (fetch_lanes_with_curr_sop_q[i] && !header_lane_selected_v) begin
            header_lane_v = FUTURE_FRAME_LANE_WIDTH'(i);
            header_lane_selected_v = 1'b1;
          end
        end

        fetch_header_lane_valid_q <= header_lane_selected_v;
        fetch_header_lane_q <= header_lane_v;
        page_allocator_state <= PAGE_ALLOCATOR_ACCUM_TICKET;
        end

      PAGE_ALLOCATOR_ACCUM_TICKET: begin
        frame_shr_cnt_t pair_subh_v [FUTURE_FRAME_PAIR_COUNT];
        frame_hit_cnt_t pair_hit_v [FUTURE_FRAME_PAIR_COUNT];

        for (int i = 0; i < FUTURE_FRAME_PAIR_COUNT; i++) begin
          pair_subh_v[i] = '0;
          pair_hit_v[i] = '0;
          if ((2 * i) < N_LANE) begin
            pair_subh_v[i] += frame_shr_cnt_t'(fetch_curr_sop_n_subh_q[2 * i]);
            pair_hit_v[i] += frame_hit_cnt_t'(fetch_curr_sop_n_hit_q[2 * i]);
          end
          if ((2 * i + 1) < N_LANE) begin
            pair_subh_v[i] += frame_shr_cnt_t'(fetch_curr_sop_n_subh_q[2 * i + 1]);
            pair_hit_v[i] += frame_hit_cnt_t'(fetch_curr_sop_n_hit_q[2 * i + 1]);
          end
          fetch_sop_pair_subh_q[i] <= pair_subh_v[i];
          fetch_sop_pair_hit_q[i] <= pair_hit_v[i];
        end

        page_allocator_state <= PAGE_ALLOCATOR_REDUCE_TICKET;
        end

      PAGE_ALLOCATOR_REDUCE_TICKET: begin
        frame_shr_cnt_t reduce_subh_v [FUTURE_FRAME_REDUCE_COUNT];
        frame_hit_cnt_t reduce_hit_v [FUTURE_FRAME_REDUCE_COUNT];

        for (int i = 0; i < FUTURE_FRAME_REDUCE_COUNT; i++) begin
          reduce_subh_v[i] = '0;
          reduce_hit_v[i] = '0;
          if ((2 * i) < FUTURE_FRAME_PAIR_COUNT) begin
            reduce_subh_v[i] += fetch_sop_pair_subh_q[2 * i];
            reduce_hit_v[i] += fetch_sop_pair_hit_q[2 * i];
          end
          if ((2 * i + 1) < FUTURE_FRAME_PAIR_COUNT) begin
            reduce_subh_v[i] += fetch_sop_pair_subh_q[2 * i + 1];
            reduce_hit_v[i] += fetch_sop_pair_hit_q[2 * i + 1];
          end
          fetch_sop_reduce_subh_q[i] <= reduce_subh_v[i];
          fetch_sop_reduce_hit_q[i] <= reduce_hit_v[i];
        end

        page_allocator_state <= PAGE_ALLOCATOR_SUMMARIZE_TICKET;
        end

      PAGE_ALLOCATOR_SUMMARIZE_TICKET: begin
        frame_shr_cnt_t total_subh_v;
        frame_hit_cnt_t total_hit_v;
        logic [5:0] header_dt_type_v;
        logic [15:0] header_feb_id_v;
        logic [47:0] header_frame_ts_v;
        logic [47:0] header_running_ts_v;
        future_frame_candidate_t future_candidates_v [N_LANE];

        total_subh_v = '0;
        total_hit_v = '0;
        for (int i = 0; i < FUTURE_FRAME_REDUCE_COUNT; i++) begin
          total_subh_v += fetch_sop_reduce_subh_q[i];
          total_hit_v += fetch_sop_reduce_hit_q[i];
        end
        fetch_sop_n_subh_q <= frame_shr_cnt_t'(total_subh_v);
        fetch_sop_n_hit_q <= frame_hit_cnt_t'(total_hit_v);

        header_dt_type_v = fetch_default_header_dt_type_q;
        header_feb_id_v = fetch_default_header_feb_id_q;
        header_frame_ts_v = fetch_default_header_frame_ts_q;
        header_running_ts_v = fetch_default_header_running_ts_q;

        if (fetch_header_lane_valid_q) begin
          header_dt_type_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_DT_TYPE_HI:TICKET_DT_TYPE_LO];
          header_feb_id_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_FEB_ID_HI:TICKET_FEB_ID_LO];
          header_frame_ts_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
          header_running_ts_v =
            fetch_ticket_raw_q[fetch_header_lane_q][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
        end

        for (int i = 0; i < N_LANE; i++) begin
          future_candidates_v[i] = '{
            valid: fetch_pending_q[i] && fetch_tk_sop_q[i] && !fetch_tk_past_q[i],
            serial: fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO],
            lane: FUTURE_FRAME_LANE_WIDTH'(i)
          };
        end

        for (int i = 0; i < FUTURE_FRAME_PAIR_COUNT; i++) begin
          if ((2 * i + 1) < N_LANE) begin
            fetch_future_pairs_q[i] <= choose_earlier_future_frame(
              future_candidates_v[2 * i],
              future_candidates_v[2 * i + 1]
            );
          end else begin
            fetch_future_pairs_q[i] <= future_candidates_v[2 * i];
          end
        end

        fetch_header_dt_type_q <= header_dt_type_v;
        fetch_header_feb_id_q <= header_feb_id_v;
        fetch_header_frame_ts_q <= header_frame_ts_v;
        fetch_header_running_ts_q <= header_running_ts_v;
        page_allocator_state <= PAGE_ALLOCATOR_REDUCE_FUTURE;
        end

      PAGE_ALLOCATOR_REDUCE_FUTURE: begin
        for (int i = 0; i < FUTURE_FRAME_REDUCE_COUNT; i++) begin
          if ((2 * i + 1) < FUTURE_FRAME_PAIR_COUNT) begin
            fetch_future_reduce_q[i] <= choose_earlier_future_frame(
              fetch_future_pairs_q[2 * i],
              fetch_future_pairs_q[2 * i + 1]
            );
          end else begin
            fetch_future_reduce_q[i] <= fetch_future_pairs_q[2 * i];
          end
        end
        page_allocator_state <= PAGE_ALLOCATOR_REDUCE_FUTURE_FINAL;
        end

      PAGE_ALLOCATOR_REDUCE_FUTURE_FINAL: begin
        for (int i = 0; i < FUTURE_FRAME_FINAL_COUNT; i++) begin
          if ((2 * i + 1) < FUTURE_FRAME_REDUCE_COUNT) begin
            fetch_future_final_q[i] <= choose_earlier_future_frame(
              fetch_future_reduce_q[2 * i],
              fetch_future_reduce_q[2 * i + 1]
            );
          end else begin
            fetch_future_final_q[i] <= fetch_future_reduce_q[2 * i];
          end
        end
        page_allocator_state <= PAGE_ALLOCATOR_FINALIZE_SUMMARY;
        end

      PAGE_ALLOCATOR_FINALIZE_SUMMARY: begin
        future_frame_candidate_t future_best_v;

        future_best_v = '{
          valid: 1'b0,
          serial: page_allocator.frame_serial,
          lane: '0
        };

        for (int i = 0; i < FUTURE_FRAME_FINAL_COUNT; i++) begin
          future_best_v = choose_earlier_future_frame(future_best_v, fetch_future_final_q[i]);
        end

        fetch_future_frame_seen_q <= future_best_v.valid;
        fetch_future_frame_serial_q <= future_best_v.serial;
        fetch_future_frame_lane_q <= future_best_v.lane;
        fetch_resident_protect_valid_q <= resident_protect_valid_stage_q;
        fetch_resident_protect_addr_q <= resident_protect_addr_stage_q;
        fetch_resident_protect_len_q <= resident_protect_len_stage_q;
        fetch_resident_protect_full_ring_q <= resident_protect_full_ring_stage_q;
        fetch_resident_protect_has_successor_q <= resident_protect_has_successor_stage_q;
        fetch_join_absorb_only_q <=
          (page_allocator.frame_join_wait != '0) &&
          (page_allocator.frame_lane_active != '0) &&
          (page_allocator.frame_lane_active != '1) &&
          fetch_any_pending_sop_q;
        fetch_start_new_frame_q <=
          (page_allocator.frame_lane_active == '0) &&
          fetch_all_present_tk_sop_q &&
          fetch_any_pending_curr_sop_q;
        page_allocator_state <= PAGE_ALLOCATOR_PREDICT_RESIDENT;
        end

      PAGE_ALLOCATOR_PREDICT_RESIDENT: begin
        logic [47:0] future_frame_ts_v;
        page_ram_addr_t predicted_frame_len_v;
        logic predicted_frame_spans_full_ring_v;
        logic resident_predict_matches_v;

        future_frame_ts_v = page_allocator.frame_ts;
        predicted_frame_len_v = fetch_resident_protect_len_q;
        predicted_frame_spans_full_ring_v = fetch_resident_protect_full_ring_q;
        resident_predict_matches_v =
          fetch_resident_protect_valid_q &&
          (packet_complete_frame_start_addr == fetch_resident_protect_addr_q);
        if (resident_predict_matches_v) begin
          predicted_frame_len_v = packet_complete_frame_len;
          predicted_frame_spans_full_ring_v = packet_complete_frame_full_ring;
        end
        if (fetch_future_frame_seen_q) begin
          future_frame_ts_v =
            fetch_ticket_raw_q[fetch_future_frame_lane_q][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
        end
        fetch_future_frame_ts_q <= future_frame_ts_v;
        fetch_resident_predict_matches_q <= resident_predict_matches_v;
        fetch_predicted_frame_len_q <= predicted_frame_len_v;
        fetch_predicted_frame_spans_full_ring_q <= predicted_frame_spans_full_ring_v;
        fetch_predicted_capacity_exceeded_q <=
          frame_lengths_exceed_ring_capacity(fetch_resident_protect_len_q, predicted_frame_len_v);
        page_allocator_state <= PAGE_ALLOCATOR_PREDICT_TICKET;
        end

      PAGE_ALLOCATOR_PREDICT_TICKET: begin
        logic predrop_current_frame_v;
        logic rebase_future_frame_v;

        predrop_current_frame_v =
          (page_allocator.frame_lane_active == '0) &&
          fetch_all_present_tk_sop_q &&
          fetch_any_pending_curr_sop_q &&
          fetch_resident_protect_valid_q &&
          !fetch_resident_protect_has_successor_q &&
          (fetch_resident_protect_full_ring_q ||
           fetch_predicted_frame_spans_full_ring_q ||
           fetch_predicted_capacity_exceeded_q);
        rebase_future_frame_v =
          (page_allocator.frame_lane_active == '0) &&
          fetch_all_present_tk_sop_q &&
          fetch_any_pending_sop_q &&
          !fetch_any_pending_curr_sop_q &&
          fetch_future_frame_seen_q &&
          serial_reached_or_passed(fetch_future_frame_serial_q, page_allocator.frame_serial) &&
          (fetch_future_frame_serial_q != page_allocator.frame_serial) &&
          (fetch_future_frame_ts_q >= page_allocator.frame_ts);
        fetch_rebase_future_frame_q <= rebase_future_frame_v;
        fetch_rebase_future_frame_lane_q <= {N_LANE{rebase_future_frame_v}};
        fetch_predrop_current_frame_q <= predrop_current_frame_v;
        fetch_predrop_current_frame_lane_q <= {N_LANE{predrop_current_frame_v}};
`ifndef SYNTHESIS
        if (opq_trace_boundary_en &&
            ($time >= opq_trace_after_ps) &&
            fetch_start_new_frame_q) begin
          $display(
            "[opq_pa_decision] t=%0t start_frame_guard predrop=%0b resident_valid=%0b resident_len=%0d resident_full=%0b resident_has_successor=%0b predictor_match=%0b predicted_len=%0d predicted_full=%0b lanes_curr_sop=0x%0h tail_ready=0x%0h",
            $time,
            predrop_current_frame_v,
            fetch_resident_protect_valid_q,
            fetch_resident_protect_len_q,
            fetch_resident_protect_full_ring_q,
            fetch_resident_protect_has_successor_q,
            fetch_resident_predict_matches_q,
            fetch_predicted_frame_len_q,
            fetch_predicted_frame_spans_full_ring_q,
            fetch_lanes_with_curr_sop_q,
            fetch_tail_ready_q
          );
        end
`endif
        page_allocator_state <= PAGE_ALLOCATOR_DECIDE_TICKET;
        end

      PAGE_ALLOCATOR_DECIDE_TICKET: begin
        logic [N_LANE-1:0] lane_masked_v;
        logic [N_LANE-1:0] lane_credit_valid_v;
        logic [N_LANE-1:0] lane_reactivate_v;
        fetch_lane_actions_t lane_action_v;

        lane_masked_v = '0;
        lane_credit_valid_v = '0;
        lane_reactivate_v = '0;

        for (int i = 0; i < N_LANE; i++) begin
          lane_action_v[i] = FETCH_LANE_HOLD;
          if (!fetch_pending_q[i]) begin
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
          end else if (fetch_tk_curr_q[i] &&
                       fetch_tk_sop_q[i] &&
                       fetch_tail_dropped_q[i]) begin
            lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b1;
          end else if (fetch_join_absorb_only_q) begin
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
            if ((page_allocator.frame_lane_active != '0) &&
                !page_allocator.frame_lane_active[i] &&
                fetch_tk_sop_q[i] &&
                fetch_tk_curr_q[i]) begin
              // During the join window, absorb a late current-frame SOP from
              // an inactive lane and mark that lane active before its body
              // ticket appears on the next fetch.
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_credit_valid_v[i] = 1'b1;
              lane_reactivate_v[i] = !fetch_tail_dropped_q[i];
            end else if (fetch_tk_sop_q[i] &&
                         fetch_tk_past_q[i] &&
                         (fetch_ticket_raw_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO] +
                           48'(FRAME_DURATION_CYCLES) == page_allocator.frame_ts)) begin
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_credit_valid_v[i] = 1'b1;
              lane_reactivate_v[i] = 1'b1;
            end
          end else if (fetch_predrop_current_frame_lane_q[i]) begin
            if (fetch_tk_curr_q[i] && fetch_tk_sop_q[i]) begin
              lane_action_v[i] = FETCH_LANE_LATE_DROP;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
            end else if (fetch_tk_future_q[i]) begin
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b0;
            end else if (fetch_tk_past_q[i]) begin
              lane_action_v[i] = FETCH_LANE_LATE_DROP;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
            end else begin
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b0;
            end
          end else if (fetch_rebase_future_frame_lane_q[i]) begin
            lane_masked_v[i] = 1'b0;
            lane_credit_valid_v[i] = 1'b0;
          end else if (fetch_start_new_frame_q) begin
            if (fetch_tk_curr_q[i]) begin
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_masked_v[i] = 1'b0;
              lane_credit_valid_v[i] = 1'b1;
            end else if (fetch_tk_future_q[i]) begin
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b0;
            end else if (fetch_tk_past_q[i]) begin
              lane_action_v[i] = FETCH_LANE_LATE_DROP;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
            end else begin
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b0;
            end
          end else if ((page_allocator.frame_lane_active != '0) &&
                       !page_allocator.frame_lane_active[i] &&
                       fetch_tk_curr_q[i] &&
                       fetch_tk_sop_q[i] &&
                       !fetch_tail_dropped_q[i]) begin
            // Outside the explicit join window, a late current-frame SOP still
            // belongs to the active frame. Consume it and reactivate the lane
            // so its body ticket stays on the live-frame path.
            lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b1;
            lane_reactivate_v[i] = 1'b1;
          end else if (fetch_tk_future_q[i]) begin
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
          end else if (fetch_tk_past_q[i]) begin
            if ((page_allocator.frame_lane_active != '0) &&
                fetch_tk_sop_q[i] &&
                (fetch_ticket_raw_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO] +
                  48'(FRAME_DURATION_CYCLES) == page_allocator.frame_ts)) begin
              lane_action_v[i] = FETCH_LANE_ADVANCE_ONLY;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
              lane_reactivate_v[i] = 1'b1;
            end else begin
              lane_action_v[i] = FETCH_LANE_LATE_DROP;
              lane_masked_v[i] = 1'b1;
              lane_credit_valid_v[i] = 1'b1;
            end
          end else if ((page_allocator.frame_lane_active == '0) && !fetch_tk_sop_q[i]) begin
            // A frame cannot start from body traffic alone. Keep current non-SOP
            // tickets parked until a matching SOP claims the frame, or let them
            // age into the late-drop path once they fall behind running_ts.
            lane_masked_v[i] = 1'b1;
            lane_credit_valid_v[i] = 1'b0;
          end else begin
            lane_action_v[i] = FETCH_LANE_LOAD;
            lane_masked_v[i] = 1'b0;
            lane_credit_valid_v[i] = 1'b1;
          end
        end

        for (int i = 0; i < N_LANE; i++) begin
          fetch_lane_masked_q[i] <= lane_masked_v[i];
          fetch_lane_credit_valid_q[i] <= lane_credit_valid_v[i];
          fetch_lane_reactivate_q[i] <= lane_reactivate_v[i];
          fetch_lane_action_q[i] <= lane_action_v[i];
        end
`ifndef SYNTHESIS
        if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
          $display(
            "[opq_pa_decide] t=%0t running_ts=0x%0h frame_lane_active=0x%0h start_new=%0b join_absorb=%0b rebase_future=%0b predrop=%0b pending=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h lane_mask=0x%0h lane_credit=0x%0h lane_reactivate=0x%0h",
            $time,
            page_allocator.running_ts,
            page_allocator.frame_lane_active,
            fetch_start_new_frame_q,
            fetch_join_absorb_only_q,
            fetch_rebase_future_frame_q,
            fetch_predrop_current_frame_q,
            fetch_pending_q,
            fetch_tk_sop_q,
            fetch_tk_curr_q,
            fetch_tk_future_q,
            fetch_tk_past_q,
            lane_masked_v,
            lane_credit_valid_v,
            lane_reactivate_v
          );
          for (int dbg_lane = 0; dbg_lane < N_LANE; dbg_lane++) begin
            if (fetch_pending_q[dbg_lane]) begin
              $display(
                "[opq_pa_lane_action] t=%0t lane=%0d action=%0d masked=%0b credit=%0b reactivate=%0b fetch_ts=0x%0h block_len=%0d body_serial=0x%0h sop=%0b eop=%0b tail_ready=%0b tail_dropped=%0b",
                $time,
                dbg_lane,
                lane_action_v[dbg_lane],
                lane_masked_v[dbg_lane],
                lane_credit_valid_v[dbg_lane],
                lane_reactivate_v[dbg_lane],
                fetch_ticket_q[dbg_lane].ticket_ts,
                fetch_ticket_q[dbg_lane].block_length,
                fetch_ticket_q[dbg_lane].frame_serial,
                fetch_tk_sop_q[dbg_lane],
                fetch_ticket_q[dbg_lane].alert_eop,
                fetch_tail_ready_q[dbg_lane],
                fetch_tail_dropped_q[dbg_lane]
              );
            end
          end
        end
`endif
        page_allocator_state <= PAGE_ALLOCATOR_APPLY_TICKET;
        end

      PAGE_ALLOCATOR_APPLY_TICKET: begin
        page_allocator.lane_masked <= '0;
        page_allocator.lane_skipped <= '0;
        page_allocator.subheader_has_accepted_lane <= 1'b0;
        page_allocator.page_length <= '0;

        if (!fetch_handle_slots_ready) begin
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display(
              "[opq_pa_decision] t=%0t wait_handle_credit need=0x%0h credit_avail=0x%0h",
              $time,
              fetch_handle_slot_needed,
              handle_credit_available
            );
          end
`endif
          page_allocator_state <= PAGE_ALLOCATOR_APPLY_TICKET;
        end else if (fetch_predrop_current_frame_q) begin
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display(
              "[opq_pa_decision] t=%0t predrop_current_frame frame_serial=0x%0h pending=0x%0h tk_sop=0x%0h tk_curr=0x%0h tk_future=0x%0h tk_past=0x%0h",
              $time,
              page_allocator.frame_serial,
              fetch_pending_q,
              fetch_tk_sop_q,
              fetch_tk_curr_q,
              fetch_tk_future_q,
              fetch_tk_past_q
            );
          end
`endif
          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(1);
            page_allocator.ticket_credit_update_valid[i] <= fetch_lane_credit_valid_q[i];
            page_allocator.lane_masked[i] <= 1'b1;

            unique case (fetch_lane_action_q[i])
              FETCH_LANE_HOLD: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
              end
              FETCH_LANE_ADVANCE_ONLY: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
              end
              FETCH_LANE_LATE_DROP: begin
                late_frame_drop_valid[i] <= 1'b1;
                if (fetch_ticket_raw_q[i][TICKET_ALT_SOP_LOC]) begin
                  late_frame_drop_hdr_cnt[i] <= 16'd1;
                  late_frame_drop_shd_cnt[i] <= '0;
                  late_frame_drop_hit_cnt[i] <= '0;
                  late_frame_drop_serial[i] <= fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
                  late_frame_drop_ts[i] <= fetch_ticket_raw_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
                end else begin
                  late_frame_drop_hdr_cnt[i] <= '0;
                  late_frame_drop_shd_cnt[i] <= 16'd1;
                  late_frame_drop_hit_cnt[i] <=
                    {{(16-MAX_PKT_LENGTH_BITS){1'b0}}, fetch_ticket_q[i].block_length};
                  late_frame_drop_serial[i] <= fetch_ticket_q[i].frame_serial;
                  late_frame_drop_ts[i] <= fetch_ticket_q[i].ticket_ts;
                end
                late_frame_lane_credit_update[i] <= fetch_ticket_q[i].block_length;
                late_frame_lane_credit_update_valid[i] <= 1'b1;
                page_allocator.ticket[i] <= TICKET_DEFAULT;
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
              end
              default: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
              end
            endcase
          end

          page_allocator.frame_serial <= page_allocator.frame_serial + 1'b1;
          page_allocator.alloc_page_flow <= '0;
          page_allocator.alloc_page_flow_onehot <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else if (fetch_join_absorb_only_q) begin
          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(1);
            page_allocator.ticket_credit_update_valid[i] <= fetch_lane_credit_valid_q[i];
            page_allocator.lane_masked[i] <= 1'b1;
            if (fetch_lane_action_q[i] == FETCH_LANE_ADVANCE_ONLY) begin
              page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
              if (fetch_lane_reactivate_q[i]) begin
                page_allocator.frame_lane_active[i] <= 1'b1;
              end
            end else begin
              page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
            end
          end

          page_allocator.alloc_page_flow <= '0;
          page_allocator.alloc_page_flow_onehot <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else if (fetch_rebase_future_frame_q) begin
`ifndef SYNTHESIS
          if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
            $display(
              "[opq_pa_decision] t=%0t fetch_rebase_future_frame old_serial=0x%0h new_serial=0x%0h old_frame_ts=0x%0h new_frame_ts=0x%0h pending=0x%0h",
              $time,
              page_allocator.frame_serial,
              fetch_future_frame_serial_q,
              page_allocator.frame_ts,
              fetch_future_frame_ts_q,
              fetch_pending_q
            );
          end
`endif
          page_allocator.frame_serial <= fetch_future_frame_serial_q;
          page_allocator.frame_ts <= fetch_future_frame_ts_q;
          page_allocator.running_ts <= fetch_future_frame_ts_q;
          page_allocator.alloc_page_flow <= '0;
          page_allocator.alloc_page_flow_onehot <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else begin
          if (fetch_start_new_frame_q) begin
            page_allocator.frame_shr_cnt_this <= fetch_sop_n_subh_q;
            page_allocator.frame_hit_cnt_this <= fetch_sop_n_hit_q;
            page_allocator.frame_serial_this <= fetch_sop_serial_q;
            page_allocator.frame_serial <= page_allocator.frame_serial + 1'b1;
          end

          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(1);
            page_allocator.ticket_credit_update_valid[i] <= fetch_lane_credit_valid_q[i];
            page_allocator.lane_masked[i] <= fetch_lane_masked_q[i];

            unique case (fetch_lane_action_q[i])
              FETCH_LANE_HOLD: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
              end
              FETCH_LANE_ADVANCE_ONLY: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
                if (fetch_lane_reactivate_q[i]) begin
                  page_allocator.frame_lane_active[i] <= 1'b1;
                  page_allocator.frame_lane_tail_seen[i] <= fetch_tail_ready_q[i];
                end
              end
              FETCH_LANE_LOAD: begin
                page_allocator.ticket[i] <= fetch_ticket_q[i];
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
                if (page_allocator.frame_lane_active[i]) begin
                  page_allocator.frame_lane_tail_seen[i] <= fetch_tail_ready_q[i];
                end
              end
              FETCH_LANE_LATE_DROP: begin
                late_frame_drop_valid[i] <= 1'b1;
                if (fetch_ticket_raw_q[i][TICKET_ALT_SOP_LOC]) begin
                  late_frame_drop_hdr_cnt[i] <= 16'd1;
                  late_frame_drop_shd_cnt[i] <= '0;
                  late_frame_drop_hit_cnt[i] <= '0;
                  late_frame_drop_serial[i] <= fetch_ticket_raw_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
                  late_frame_drop_ts[i] <= fetch_ticket_raw_q[i][TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO];
                end else begin
                  late_frame_drop_hdr_cnt[i] <= '0;
                  late_frame_drop_shd_cnt[i] <= 16'd1;
                  late_frame_drop_hit_cnt[i] <=
                    {{(16-MAX_PKT_LENGTH_BITS){1'b0}}, fetch_ticket_q[i].block_length};
                  late_frame_drop_serial[i] <= fetch_ticket_q[i].frame_serial;
                  late_frame_drop_ts[i] <= fetch_ticket_q[i].ticket_ts;
                end
                late_frame_lane_credit_update[i] <= fetch_ticket_q[i].block_length;
                late_frame_lane_credit_update_valid[i] <= 1'b1;
                page_allocator.ticket[i] <= TICKET_DEFAULT;
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
              end
              default: begin
                page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i];
              end
            endcase
          end

          page_allocator_state <= PAGE_ALLOCATOR_ALLOC_PAGE;
          page_allocator.alloc_page_flow <= '0;
          page_allocator.alloc_page_flow_onehot <= ALLOC_PAGE_FLOW_FIRST_ONEHOT;

          if (fetch_start_new_frame_q) begin
`ifndef SYNTHESIS
            if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
              $display(
                "[opq_pa_decision] t=%0t fetch_to_write_head header_ts=0x%0h frame_serial_this=0x%0h n_subh=%0d n_hit=%0d lanes_curr_sop=0x%0h tail_ready=0x%0h tail_dropped=0x%0h ingress_busy=0x%0h",
                $time,
                fetch_header_frame_ts_q,
                fetch_sop_serial_q,
                fetch_sop_n_subh_q,
                fetch_sop_n_hit_q,
                fetch_lanes_with_curr_sop_q,
                fetch_tail_ready_q,
                fetch_tail_dropped_q,
                ingress_parser_busy_i
              );
            end
`endif
            page_allocator.frame_shr_cnt <= '0;
            page_allocator.frame_hit_cnt <= '0;
            page_allocator.frame_hit_room <= FRAME_HIT_ROOM_RESET;
            page_allocator.page_we <= 1'b1;
            if (&(fetch_lanes_with_curr_sop_q & fetch_tail_ready_q)) begin
              page_allocator.page_waddr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
              page_allocator.frame_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
              page_allocator.frame_start_addr_last <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
            end else begin
              page_allocator.page_waddr <= page_allocator.page_start_addr;
              page_allocator.frame_start_addr <= page_allocator.page_start_addr;
              page_allocator.frame_start_addr_last <= page_allocator.page_start_addr;
            end
            page_allocator.frame_ts <= fetch_header_frame_ts_q;
            // Seed each frame from its first subheader slot, not from a live
            // parser-running timestamp that may already have advanced past
            // unread tickets by the time the allocator opens the frame.
            page_allocator.running_ts <= fetch_header_running_ts_q;
            // Only fast-close frames that are already completely empty. Frames
            // with zero hits can still carry real empty subheaders that must
            // be emitted through the normal page path.
            page_allocator.write_trailer <=
              &(fetch_lanes_with_curr_sop_q & fetch_tail_ready_q) &&
              (fetch_sop_n_subh_q == '0) &&
              (fetch_sop_n_hit_q == '0);
            page_allocator.tail_only_flush <= 1'b0;
            page_allocator.frame_lane_active <= fetch_lanes_with_curr_sop_q;
            page_allocator.frame_lane_tail_seen <= fetch_lanes_with_curr_sop_q & fetch_tail_ready_q;
            page_allocator_state <= PAGE_ALLOCATOR_WRITE_HEAD;
            page_allocator.write_meta_flow <= '0;
          end
        end
        end

      PAGE_ALLOCATOR_FAST_ZERO_COMMIT: begin
        if (fast_zero_commit_valid) begin
          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(1);
            page_allocator.ticket_credit_update_valid[i] <= fast_zero_commit_lane_onehot_q[i];
            if (fast_zero_commit_lane_onehot_q[i]) begin
              ticket_t fast_ticket_v;
              logic [HANDLE_LENGTH-1:0] fast_handle_data_v;

              fast_ticket_v = fast_zero_commit_ticket_q[i];
              fast_handle_data_v = '0;
              fast_handle_data_v[HANDLE_SRC_HI:HANDLE_SRC_LO] =
                fast_ticket_v.lane_fifo_rd_offset;
              fast_handle_data_v[HANDLE_DST_HI:HANDLE_DST_LO] =
                fast_zero_commit_page_addr_q +
                page_ram_addr_t'(SHD_SIZE) +
                page_ram_addr_t'(fast_zero_commit_lane_offset_q[i]);
              fast_handle_data_v[HANDLE_LEN_HI:HANDLE_LEN_LO] =
                fast_ticket_v.block_length;

              page_allocator.ticket_rptr[i] <= page_allocator.ticket_rptr[i] + ticket_fifo_addr_t'(1);
              page_allocator.frame_lane_shd_cnt[i] <=
                page_allocator.frame_lane_shd_cnt[i] + frame_shr_cnt_t'(1);
              page_allocator.frame_lane_hit_cnt[i] <=
                page_allocator.frame_lane_hit_cnt[i] + frame_hit_cnt_t'(fast_ticket_v.block_length);
              if (fast_ticket_v.block_length != '0) begin
                page_allocator.handle_wdata[i] <= {1'b0, fast_handle_data_v};
                page_allocator.handle_waddr[i] <= page_allocator.handle_wptr[i];
                page_allocator.handle_wptr[i] <=
                  page_allocator.handle_wptr[i] + handle_fifo_addr_t'(1);
                page_allocator.handle_we[i] <= 1'b1;
              end
            end
          end

          page_allocator.frame_shr_cnt <= page_allocator.frame_shr_cnt + frame_shr_cnt_t'(1);
          page_allocator.frame_hit_cnt <=
            page_allocator.frame_hit_cnt + frame_hit_cnt_t'(fast_zero_commit_block_length_q);
          page_allocator.frame_hit_room <=
            page_allocator.frame_hit_room - frame_hit_cnt_t'(fast_zero_commit_block_length_q);
          page_allocator.page_length <= fast_zero_commit_block_length_q;
          page_allocator.subheader_has_accepted_lane <= 1'b0;
          page_allocator.running_ts[47:4] <= page_allocator.running_ts[47:4] + 1'b1;
          page_allocator.page_start_addr <=
            fast_zero_commit_page_addr_q +
            page_ram_addr_t'(fast_zero_commit_block_length_q) +
            page_ram_addr_t'(SHD_SIZE);
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else begin
          page_allocator_state <= PAGE_ALLOCATOR_FETCH_TICKET;
        end
        end

      PAGE_ALLOCATOR_WRITE_HEAD: begin
        if (int'(page_allocator.write_meta_flow) < 2) begin
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.frame_start_addr + page_ram_addr_t'(page_allocator.write_meta_flow) +
            page_ram_addr_t'(1);
        end else begin
          if (page_allocator.write_trailer) begin
            page_allocator.page_we <= 1'b1;
            page_allocator.page_waddr <= page_allocator.frame_start_addr_last +
              page_ram_addr_t'(page_allocator.write_meta_flow) + page_ram_addr_t'(1);
            page_allocator_state <= PAGE_ALLOCATOR_WRITE_TAIL;
          end else begin
            page_allocator.page_we <= 1'b0;
            page_allocator.page_start_addr <= page_allocator.frame_start_addr + page_ram_addr_t'(HDR_SIZE);
            page_allocator.frame_cnt <= page_allocator.frame_cnt + 1'b1;
            page_allocator.frame_ts <= page_allocator.frame_ts + 48'(FRAME_DURATION_CYCLES);
            if ((page_allocator.frame_lane_active != '0) &&
                (page_allocator.frame_lane_active != '1)) begin
              page_allocator.frame_join_wait <= frame_join_wait_t'(FRAME_JOIN_WAIT_CYCLES);
            end else begin
              page_allocator.frame_join_wait <= '0;
            end
            page_allocator_state <= PAGE_ALLOCATOR_IDLE;
          end
        end
        page_allocator.write_meta_flow <= page_allocator.write_meta_flow + 1'b1;
        end

      PAGE_ALLOCATOR_WRITE_TAIL: begin
        if (int'(page_allocator.write_meta_flow) < 4) begin
          page_allocator.write_meta_flow <= page_allocator.write_meta_flow + 1'b1;
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.frame_start_addr_last +
            page_ram_addr_t'(page_allocator.write_meta_flow) + page_ram_addr_t'(1);
        end else if (int'(page_allocator.write_meta_flow) < 5) begin
          page_allocator.write_meta_flow <= page_allocator.write_meta_flow + 1'b1;
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.frame_start_addr - page_ram_addr_t'(1);
        end else begin
          page_allocator.write_meta_flow <= '0;
          page_allocator.write_trailer <= 1'b0;
          page_allocator.frame_shr_cnt_this <= page_allocator.frame_shr_cnt;
          page_allocator.frame_hit_cnt_this <= page_allocator.frame_hit_cnt;
          page_allocator.frame_lane_shd_cnt_this <= page_allocator.frame_lane_shd_cnt;
          page_allocator.frame_lane_hit_cnt_this <= page_allocator.frame_lane_hit_cnt;
          packet_complete_frame_start_addr <= page_allocator.frame_start_addr_last;
          packet_complete_frame_len <=
            frame_length_from_counts(page_allocator.frame_shr_cnt, page_allocator.frame_hit_cnt);
          packet_complete_frame_full_ring <=
            frame_length_spans_full_ring(page_allocator.frame_shr_cnt, page_allocator.frame_hit_cnt);
          packet_complete_shr_cnt <= page_allocator.frame_shr_cnt;
          packet_complete_hit_cnt <= page_allocator.frame_hit_cnt;
          packet_complete_lane_shd_cnt <= page_allocator.frame_lane_shd_cnt;
          packet_complete_lane_hit_cnt <= page_allocator.frame_lane_hit_cnt;
          packet_complete_pulse <= 1'b1;
          if (page_allocator.tail_only_flush) begin
            page_allocator.page_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(TRL_SIZE);
            page_allocator.tail_only_flush <= 1'b0;
          end else begin
            // A zero-hit SOP+EOP frame reaches WRITE_TAIL directly from WRITE_HEAD.
            // Retire that frame here because it skipped the normal active-frame
            // completion path in IDLE.
            page_allocator.frame_cnt <= page_allocator.frame_cnt + 1'b1;
            page_allocator.frame_lane_active <= '0;
            page_allocator.frame_lane_tail_seen <= '0;
            page_allocator.page_start_addr <= page_allocator.page_start_addr + page_ram_addr_t'(HDR_SIZE + TRL_SIZE);
            page_allocator.frame_ts <= page_allocator.frame_ts + 48'(FRAME_DURATION_CYCLES);
          end
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
          page_allocator.frame_join_wait <= '0;
          page_allocator.frame_shr_cnt <= '0;
          page_allocator.frame_hit_cnt <= '0;
          page_allocator.frame_hit_room <= FRAME_HIT_ROOM_RESET;
          page_allocator.frame_lane_shd_cnt <= '{default:'0};
          page_allocator.frame_lane_hit_cnt <= '{default:'0};
        end
        end

      PAGE_ALLOCATOR_ALLOC_PAGE: begin
        logic selected_lane_skip_v;
        logic selected_lane_accept_v;
        logic lane_active_v;
        logic lane_accept_v;
        logic lane_skip_v;
        logic lane_masked_v;
        logic lane_skipped_v;
        ticket_t lane_ticket_v;
        page_ram_addr_t lane_dst_addr_v;
        logic [HANDLE_LENGTH-1:0] lane_handle_data_v;
        logic [N_LANE-1:0] lane_accept_vl;
        logic [N_LANE-1:0] lane_skip_vl;
        pkt_length_t selected_block_length_v;
        ticket_t selected_ticket_v;
        page_ram_addr_t selected_dst_addr_v;
        logic [HANDLE_LENGTH-1:0] selected_handle_data_v;

        selected_lane_skip_v = 1'b0;
        selected_lane_accept_v = 1'b0;
        lane_accept_vl = '0;
        lane_skip_vl = '0;
        selected_block_length_v = '0;
        selected_ticket_v = TICKET_DEFAULT;
        selected_dst_addr_v = '0;
        selected_handle_data_v = '0;

        alloc_lane_active_q <= page_allocator.alloc_page_flow_onehot;
        alloc_lane_accept_q <= 1'b0;
        alloc_lane_skip_q <= 1'b0;
        alloc_lane_skipped_q <= 1'b0;
        alloc_lane_masked_q <= 1'b0;
        alloc_lane_last_q <= page_allocator.alloc_page_flow_onehot[N_LANE-1];
        alloc_selected_block_length_q <= '0;
        alloc_lane_ticket_q <= TICKET_DEFAULT;
        alloc_lane_dst_addr_q <= '0;
        alloc_lane_handle_data_q <= '0;
        alloc_page_flow_onehot_next_q <= page_allocator.alloc_page_flow_onehot << 1;

        if (page_allocator.alloc_page_flow_onehot == '0) begin
          page_allocator.alloc_page_flow <= '0;
          page_allocator.alloc_page_flow_onehot <= ALLOC_PAGE_FLOW_FIRST_ONEHOT;
          page_allocator_state <= PAGE_ALLOCATOR_ALLOC_PAGE;
        end else begin
          for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
            lane_active_v = page_allocator.alloc_page_flow_onehot[lane_idx];
            lane_masked_v = page_allocator.lane_masked[lane_idx];
            lane_skipped_v = page_allocator.lane_skipped[lane_idx];
            lane_ticket_v = page_allocator.ticket[lane_idx];
            lane_dst_addr_v =
              page_allocator.page_start_addr + page_ram_addr_t'(SHD_SIZE) +
              page_ram_addr_t'(page_allocator.page_length);
            lane_handle_data_v = '0;
            lane_handle_data_v[HANDLE_SRC_HI:HANDLE_SRC_LO] =
              lane_ticket_v.lane_fifo_rd_offset;
            lane_handle_data_v[HANDLE_DST_HI:HANDLE_DST_LO] =
              lane_dst_addr_v;
            lane_handle_data_v[HANDLE_LEN_HI:HANDLE_LEN_LO] =
              lane_ticket_v.block_length;
            lane_accept_v =
              lane_active_v &&
              !lane_skipped_v &&
              !lane_masked_v &&
              (frame_hit_cnt_t'(lane_ticket_v.block_length) <= page_allocator.frame_hit_room);
            lane_skip_v =
              lane_active_v &&
              !lane_accept_v &&
              !lane_skipped_v &&
              !lane_masked_v &&
              (lane_ticket_v.block_length != '0);
            lane_accept_vl[lane_idx] = lane_accept_v;
            lane_skip_vl[lane_idx] = lane_skip_v;

            if (lane_active_v) begin
              selected_block_length_v = lane_ticket_v.block_length;
              selected_ticket_v = lane_ticket_v;
              selected_dst_addr_v = lane_dst_addr_v;
              selected_handle_data_v = lane_handle_data_v;
              alloc_lane_skipped_q <= lane_skipped_v;
              alloc_lane_masked_q <= lane_masked_v;
            end
          end

          selected_lane_accept_v = |lane_accept_vl;
          selected_lane_skip_v = |lane_skip_vl;
          alloc_lane_accept_q <= selected_lane_accept_v;
          alloc_lane_skip_q <= selected_lane_skip_v;
          alloc_selected_block_length_q <= selected_block_length_v;
          alloc_lane_ticket_q <= selected_ticket_v;
          alloc_lane_dst_addr_q <= selected_dst_addr_v;
          alloc_lane_handle_data_q <= selected_handle_data_v;
          page_allocator_state <= PAGE_ALLOCATOR_COMMIT_PAGE;
        end
        end

      PAGE_ALLOCATOR_COMMIT_PAGE: begin
        logic alloc_handle_skip_v;

        alloc_handle_skip_v = alloc_lane_skipped_q || alloc_lane_skip_q;

        if (alloc_lane_accept_q) begin
          if (!page_allocator.subheader_has_accepted_lane) begin
            page_allocator.subheader_has_accepted_lane <= 1'b1;
            page_allocator.frame_shr_cnt <=
              page_allocator.frame_shr_cnt + frame_shr_cnt_t'(1);
          end
          page_allocator.frame_hit_cnt <=
            page_allocator.frame_hit_cnt + frame_hit_cnt_t'(alloc_selected_block_length_q);
          page_allocator.frame_hit_room <=
            page_allocator.frame_hit_room - frame_hit_cnt_t'(alloc_selected_block_length_q);
          page_allocator.page_length <=
            page_allocator.page_length + page_length_t'(alloc_selected_block_length_q);
        end

        for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
          if (alloc_lane_active_q[lane_idx]) begin
            page_allocator.handle_wdata[lane_idx] <=
              {alloc_handle_skip_v, alloc_lane_handle_data_q};
            page_allocator.handle_waddr[lane_idx] <=
              page_allocator.handle_wptr[lane_idx];

            if (alloc_lane_accept_q) begin
              page_allocator.frame_lane_shd_cnt[lane_idx] <=
                page_allocator.frame_lane_shd_cnt[lane_idx] + frame_shr_cnt_t'(1);
              page_allocator.frame_lane_hit_cnt[lane_idx] <=
                page_allocator.frame_lane_hit_cnt[lane_idx] +
                frame_hit_cnt_t'(alloc_selected_block_length_q);
            end else if (alloc_lane_skip_q) begin
              page_allocator.lane_skipped[lane_idx] <= 1'b1;
            end

            if (alloc_selected_block_length_q == '0) begin
              page_allocator.handle_we[lane_idx] <= 1'b0;
            end else if (alloc_handle_skip_v) begin
              page_allocator.handle_we[lane_idx] <= 1'b1;
              page_allocator.handle_wflag[lane_idx] <= 1'b1;
              page_allocator.handle_wptr[lane_idx] <=
                page_allocator.handle_wptr[lane_idx] + handle_fifo_addr_t'(1);
`ifndef SYNTHESIS
              if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
                $display("[opq_boundary] t=%0t lane%0d handle_skip ts=0x%0h src=0x%0h dst=0x%0h len=%0d handle_wptr=0x%0h ticket_rptr=0x%0h",
                  $time,
                  lane_idx,
                  alloc_lane_ticket_q.ticket_ts,
                  alloc_lane_ticket_q.lane_fifo_rd_offset,
                  alloc_lane_dst_addr_q,
                  alloc_lane_ticket_q.block_length,
                  page_allocator.handle_wptr[lane_idx] + handle_fifo_addr_t'(1),
                  page_allocator.ticket_rptr[lane_idx]);
              end
`endif
            end else if (alloc_lane_masked_q) begin
              page_allocator.handle_we[lane_idx] <= 1'b0;
            end else if (alloc_lane_accept_q) begin
              page_allocator.handle_we[lane_idx] <= 1'b1;
              page_allocator.handle_wptr[lane_idx] <=
                page_allocator.handle_wptr[lane_idx] + handle_fifo_addr_t'(1);
`ifndef SYNTHESIS
              if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
                $display("[opq_boundary] t=%0t lane%0d handle_accept ts=0x%0h src=0x%0h dst=0x%0h len=%0d handle_wptr=0x%0h ticket_rptr=0x%0h page_len_next=%0d",
                  $time,
                  lane_idx,
                  alloc_lane_ticket_q.ticket_ts,
                  alloc_lane_ticket_q.lane_fifo_rd_offset,
                  alloc_lane_dst_addr_q,
                  alloc_lane_ticket_q.block_length,
                  page_allocator.handle_wptr[lane_idx] + handle_fifo_addr_t'(1),
                  page_allocator.ticket_rptr[lane_idx],
                  page_allocator.page_length);
              end
`endif
            end else begin
              page_allocator.handle_we[lane_idx] <= 1'b0;
            end
          end
        end

        if (alloc_lane_active_q == '0) begin
          page_allocator.alloc_page_flow <= '0;
          page_allocator.alloc_page_flow_onehot <= ALLOC_PAGE_FLOW_FIRST_ONEHOT;
          page_allocator_state <= PAGE_ALLOCATOR_ALLOC_PAGE;
        end else if (alloc_lane_last_q) begin
          page_allocator.alloc_page_flow <= '0;
          page_allocator.alloc_page_flow_onehot <= '0;
          page_allocator_state <= PAGE_ALLOCATOR_FINALIZE_PAGE;
        end else begin
          page_allocator.alloc_page_flow <= page_allocator.alloc_page_flow + 1'b1;
          page_allocator.alloc_page_flow_onehot <= alloc_page_flow_onehot_next_q;
          page_allocator_state <= PAGE_ALLOCATOR_ALLOC_PAGE;
        end
        end

      PAGE_ALLOCATOR_FINALIZE_PAGE: begin
        page_allocator.alloc_page_flow <= '0;
        page_allocator.alloc_page_flow_onehot <= '0;
        if (&page_allocator.lane_masked || !page_allocator.subheader_has_accepted_lane) begin
          page_allocator.running_ts[47:4] <= page_allocator.running_ts[47:4] + 1'b1;
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end else begin
          page_allocator.page_we <= 1'b1;
          page_allocator.page_waddr <= page_allocator.page_start_addr;
          page_allocator_state <= PAGE_ALLOCATOR_WRITE_PAGE;
        end
        end

      PAGE_ALLOCATOR_WRITE_PAGE: begin
        page_allocator.running_ts[47:4] <= page_allocator.running_ts[47:4] + 1'b1;
        page_allocator.page_start_addr <= page_allocator.page_waddr +
          page_ram_addr_t'(page_allocator.page_length) + page_ram_addr_t'(SHD_SIZE);
        page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end

      PAGE_ALLOCATOR_RESET: begin
        if (!page_allocator.reset_done) begin
          for (int i = 0; i < N_LANE; i++) begin
            page_allocator.ticket_credit_update[i] <= ticket_fifo_addr_t'(TICKET_FIFO_MAX_CREDIT);
            page_allocator.ticket_credit_update_valid[i] <= 1'b1;
          end
          page_allocator.reset_done <= 1'b1;
        end else if (!d_reset) begin
          page_allocator_state <= PAGE_ALLOCATOR_IDLE;
        end
        end

      default: begin
      end
    endcase

    page_allocator.write_meta_flow_d1 <= page_allocator.write_meta_flow;
    idle_fetch_ready_lane_q <= idle_fetch_ready_lane;
    all_lanes_fetch_ready_q <= all_lanes_fetch_ready;
    any_pending_ticket_q <= any_pending_ticket;
    fetch_pending_snapshot_q <= page_allocator_is_pending_ticket;
    active_frame_pending_nonfuture_lane_q <= active_frame_pending_nonfuture_lane;
    idle_active_tail_ready_lane_q <= idle_active_tail_ready_lane;
    frame_start_waiting_busy_lane_v_q <= frame_start_waiting_busy_lane_v;
    active_frame_waiting_busy_lane_v_q <= active_frame_waiting_busy_lane_v;
    frame_start_waiting_busy_lane_q <= frame_start_waiting_busy_lane;
    active_frame_waiting_busy_lane_q <= active_frame_waiting_busy_lane;
    frame_join_hold_q <= frame_join_hold;
    all_present_tk_sop_q <= all_present_tk_sop;
    any_pending_curr_sop_ticket_q <= any_pending_curr_sop_ticket;
    idle_fetch_ready_q <= idle_fetch_ready;

    if ((page_allocator.frame_join_wait != '0) &&
        (page_allocator.frame_lane_active == '1)) begin
      page_allocator.frame_join_wait <= '0;
    end else if ((page_allocator.frame_join_wait != '0) &&
                 (page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
                 (page_allocator.frame_lane_active != '0) &&
                 (page_allocator.frame_lane_active != '1)) begin
      page_allocator.frame_join_wait <= page_allocator.frame_join_wait - frame_join_wait_t'(1);
    end

    for (int i = 0; i < N_LANE; i++) begin
      if (d_reset) begin
        page_allocator_is_pending_ticket_d[i] <= '0;
        page_allocator_ticket_rptr_d[i] <= '0;
      end else begin
        for (int j = 1; j <= FIFO_RAW_DELAY; j++) begin
          if (j == 1) begin
            page_allocator_is_pending_ticket_d[i][j] <= page_allocator_is_pending_ticket[i];
            page_allocator_ticket_rptr_d[i][j] <= page_allocator.ticket_rptr[i];
          end else begin
            page_allocator_is_pending_ticket_d[i][j] <= page_allocator_is_pending_ticket_d[i][j-1];
            page_allocator_ticket_rptr_d[i][j] <= page_allocator_ticket_rptr_d[i][j-1];
          end
        end
      end
    end

    idle_tk_serial_ref_d1_q <= page_allocator.frame_serial;
    if (page_allocator.frame_lane_active != '0) begin
      idle_tk_serial_ref_d1_q <= page_allocator.frame_serial_this;
    end
    idle_tk_frame_serial_this_d1_q <= page_allocator.frame_serial_this;
    idle_tk_running_ts_d1_q <= page_allocator.running_ts;

    for (int i = 0; i < N_LANE; i++) begin
      logic pending_now_v;
      logic tk_sop_now_v;
      logic tk_curr_now_v;
      logic tk_future_now_v;
      logic tk_past_now_v;
      logic tk_active_frame_now_v;

      pending_now_v = (ingress_ticket_wptr[i] != page_allocator.ticket_rptr[i]);
      idle_tk_pending_d1_q[i] <= pending_now_v;
      idle_tk_sop_d1_q[i] <= pending_now_v && ticket_fifos_rd_data_stage_q[i][TICKET_ALT_SOP_LOC];
      idle_tk_ts_d1_q[i] <= ticket_fifos_rd_data_stage_q[i][TICKET_TS_HI:TICKET_TS_LO];
      if (ticket_fifos_rd_data_stage_q[i][TICKET_ALT_SOP_LOC]) begin
        idle_tk_serial_d1_q[i] <= ticket_fifos_rd_data_stage_q[i][TICKET_SERIAL_HI:TICKET_SERIAL_LO];
      end else begin
        idle_tk_serial_d1_q[i] <= ticket_fifos_rd_data_stage_q[i][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO];
      end

      tk_sop_now_v = idle_tk_pending_d1_q[i] && idle_tk_sop_d1_q[i];
      tk_curr_now_v = 1'b0;
      tk_future_now_v = 1'b0;
      tk_past_now_v = 1'b0;
      tk_active_frame_now_v = 1'b0;

      if (tk_sop_now_v) begin
        tk_curr_now_v = (idle_tk_serial_d1_q[i] == idle_tk_serial_ref_d1_q);
      end else begin
        tk_active_frame_now_v = idle_tk_pending_d1_q[i] &&
                                (idle_tk_serial_d1_q[i] == idle_tk_frame_serial_this_d1_q);
      end

      if (idle_tk_pending_d1_q[i]) begin
        if (idle_tk_serial_d1_q[i] > idle_tk_serial_ref_d1_q) begin
          tk_future_now_v = 1'b1;
        end else if (idle_tk_serial_d1_q[i] < idle_tk_serial_ref_d1_q) begin
          tk_past_now_v = 1'b1;
        end else if (!idle_tk_sop_d1_q[i]) begin
          if (idle_tk_ts_d1_q[i] > idle_tk_running_ts_d1_q) begin
            tk_future_now_v = 1'b1;
          end
          if (idle_tk_ts_d1_q[i] < idle_tk_running_ts_d1_q) begin
            tk_past_now_v = 1'b1;
          end
        end
      end

      idle_tk_sop_q[i] <= tk_sop_now_v;
      idle_tk_curr_q[i] <= tk_curr_now_v;
      idle_tk_future_q[i] <= tk_future_now_v;
      idle_tk_past_q[i] <= tk_past_now_v;
      idle_tk_active_frame_q[i] <= tk_active_frame_now_v;
    end

    if (d_reset) begin
      page_allocator <= PAGE_ALLOCATOR_REG_RESET;
      page_allocator.reset_done <= 1'b0;
      page_allocator_state <= PAGE_ALLOCATOR_RESET;
      fetch_pending_q <= '0;
      fetch_pending_snapshot_q <= '0;
      fetch_ticket_q <= '{default:TICKET_DEFAULT};
      fetch_ticket_raw_q <= '0;
      ticket_fifos_rd_data_stage_q <= '0;
      fast_zero_commit_lane_onehot_q <= '0;
      fast_zero_commit_ticket_q <= '{default:TICKET_DEFAULT};
      fast_zero_commit_block_length_q <= '0;
      fast_zero_commit_lane_offset_q <= '{default:'0};
      fast_zero_commit_page_addr_q <= '0;
      fast_zero_commit_page_data_q <= '0;
      idle_fetch_ready_lane_q <= '0;
      all_lanes_fetch_ready_q <= 1'b0;
      any_pending_ticket_q <= 1'b0;
      idle_fetch_ready_q <= 1'b0;
      idle_active_tail_ready_lane_q <= '0;
      active_frame_pending_nonfuture_lane_q <= '0;
      frame_start_waiting_busy_lane_v_q <= '0;
      active_frame_waiting_busy_lane_v_q <= '0;
      frame_start_waiting_busy_lane_q <= 1'b0;
      active_frame_waiting_busy_lane_q <= 1'b0;
      frame_join_hold_q <= 1'b0;
      all_present_tk_sop_q <= 1'b0;
      any_pending_curr_sop_ticket_q <= 1'b0;
      idle_tk_sop_q <= '0;
      idle_tk_curr_q <= '0;
      idle_tk_future_q <= '0;
      idle_tk_past_q <= '0;
      idle_tk_active_frame_q <= '0;
      fetch_lane_masked_q <= '0;
      fetch_lane_credit_valid_q <= '0;
      fetch_lane_reactivate_q <= '0;
      fetch_all_present_tk_sop_q <= 1'b0;
      fetch_any_pending_sop_q <= 1'b0;
      fetch_any_pending_curr_sop_q <= 1'b0;
      fetch_future_frame_seen_q <= 1'b0;
      fetch_start_new_frame_q <= 1'b0;
      fetch_rebase_future_frame_q <= 1'b0;
      fetch_rebase_future_frame_lane_q <= '0;
      fetch_join_absorb_only_q <= 1'b0;
      fetch_predrop_current_frame_q <= 1'b0;
      fetch_predrop_current_frame_lane_q <= '0;
      fetch_resident_predict_matches_q <= 1'b0;
      fetch_predicted_frame_len_q <= '0;
      fetch_predicted_frame_spans_full_ring_q <= 1'b0;
      fetch_predicted_capacity_exceeded_q <= 1'b0;
      fetch_lanes_with_curr_sop_q <= '0;
      fetch_curr_sop_n_subh_q <= '0;
      fetch_curr_sop_n_hit_q <= '0;
      fetch_sop_pair_subh_q <= '{default:'0};
      fetch_sop_pair_hit_q <= '{default:'0};
      fetch_sop_reduce_subh_q <= '{default:'0};
      fetch_sop_reduce_hit_q <= '{default:'0};
      fetch_header_lane_valid_q <= 1'b0;
      fetch_header_lane_q <= '0;
      fetch_default_header_dt_type_q <= '0;
      fetch_default_header_feb_id_q <= '0;
      fetch_default_header_frame_ts_q <= '0;
      fetch_default_header_running_ts_q <= '0;
      fetch_ticket_serial_ref_q <= '0;
      resident_protect_valid_stage_q <= 1'b0;
      resident_protect_addr_stage_q <= '0;
      resident_protect_len_stage_q <= '0;
      resident_protect_full_ring_stage_q <= 1'b0;
      resident_protect_has_successor_stage_q <= 1'b0;
      fetch_header_dt_type_q <= '0;
      fetch_header_feb_id_q <= '0;
      fetch_header_frame_ts_q <= '0;
      fetch_header_running_ts_q <= '0;
      fetch_sop_serial_q <= '0;
      fetch_sop_n_subh_q <= '0;
      fetch_sop_n_hit_q <= '0;
      fetch_future_frame_serial_q <= '0;
      fetch_future_frame_lane_q <= '0;
      fetch_future_frame_ts_q <= '0;
      fetch_resident_protect_valid_q <= 1'b0;
      fetch_resident_protect_addr_q <= '0;
      fetch_resident_protect_len_q <= '0;
      fetch_resident_protect_full_ring_q <= 1'b0;
      fetch_resident_protect_has_successor_q <= 1'b0;
      fetch_future_pairs_q <= '{default:'0};
      fetch_future_reduce_q <= '{default:'0};
      fetch_future_final_q <= '{default:'0};
      fetch_tail_target_serial_q <= '0;
      fetch_tail_status_slot_q <= '0;
      fetch_tail_target_wrap_q <= '0;
      fetch_tail_ready_q <= '0;
      fetch_tail_shadow_valid_q <= '0;
      fetch_tail_shadow_drop_q <= '0;
      fetch_tail_dropped_q <= '0;
      alloc_lane_active_q <= '0;
      alloc_lane_accept_q <= 1'b0;
      alloc_lane_skip_q <= 1'b0;
      alloc_lane_skipped_q <= 1'b0;
      alloc_lane_masked_q <= 1'b0;
      alloc_lane_last_q <= 1'b0;
      alloc_selected_block_length_q <= '0;
      alloc_lane_ticket_q <= TICKET_DEFAULT;
      alloc_lane_dst_addr_q <= '0;
      alloc_lane_handle_data_q <= '0;
      alloc_page_flow_onehot_next_q <= '0;
`ifndef SYNTHESIS
      ingress_tail_status_valid_q <= '0;
      ingress_tail_status_drop_q <= '0;
`endif
      idle_tk_pending_d1_q <= '0;
      idle_tk_sop_d1_q <= '0;
      idle_tk_serial_d1_q <= '0;
      idle_tk_ts_d1_q <= '0;
      idle_tk_serial_ref_d1_q <= '0;
      idle_tk_frame_serial_this_d1_q <= '0;
      idle_tk_running_ts_d1_q <= '0;
      for (int i = 0; i < N_LANE; i++) begin
        fetch_lane_action_q[i] <= FETCH_LANE_HOLD;
      end
      packet_complete_frame_start_addr <= '0;
      packet_complete_frame_len <= '0;
      packet_complete_frame_full_ring <= 1'b0;
      packet_complete_shr_cnt <= '0;
      packet_complete_hit_cnt <= '0;
      packet_complete_lane_shd_cnt <= '{default:'0};
      packet_complete_lane_hit_cnt <= '{default:'0};
    end
  end

  property p_page_allocator_reset_enters_reset;
    @(posedge d_clk) d_reset |=> (page_allocator_state == PAGE_ALLOCATOR_RESET);
  endproperty
  ap_page_allocator_reset_enters_reset: assert property (p_page_allocator_reset_enters_reset);

  property p_page_allocator_idle_fetch_requires_all_lanes;
    @(posedge d_clk) disable iff (d_reset)
      ((page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
       !idle_tail_flush_ready_decision &&
       idle_fetch_ready_q &&
       !frame_join_hold &&
       !fast_zero_valid)
      |=> (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET);
  endproperty
  ap_page_allocator_idle_fetch_requires_all_lanes: assert property (p_page_allocator_idle_fetch_requires_all_lanes);

  property p_page_allocator_idle_tail_flush_is_staged;
    @(posedge d_clk) disable iff (d_reset)
      ((page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
       idle_tail_flush_ready_decision)
      |=> (page_allocator_state == PAGE_ALLOCATOR_PREPARE_WRITE_TAIL)
          ##1 ((page_allocator_state == PAGE_ALLOCATOR_WRITE_TAIL) &&
               (eop_flush_ack != '0) &&
               page_allocator.tail_only_flush &&
               page_allocator.write_trailer &&
               (page_allocator.frame_lane_active == '0));
  endproperty
  ap_page_allocator_idle_tail_flush_is_staged: assert property (p_page_allocator_idle_tail_flush_is_staged);

  property p_page_allocator_write_page_returns_idle;
    @(posedge d_clk) disable iff (d_reset)
      (page_allocator_state == PAGE_ALLOCATOR_WRITE_PAGE)
      |=> (page_allocator_state == PAGE_ALLOCATOR_IDLE);
  endproperty
  ap_page_allocator_write_page_returns_idle: assert property (p_page_allocator_write_page_returns_idle);

`ifndef SYNTHESIS
  property p_join_absorb_only_requires_partial_frame;
    @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
      ((page_allocator_state == PAGE_ALLOCATOR_DECIDE_TICKET) &&
       fetch_join_absorb_only_q)
      |->
      ((page_allocator.frame_lane_active != '0) &&
       (page_allocator.frame_lane_active != '1));
  endproperty
  ap_join_absorb_only_requires_partial_frame: assert property (p_join_absorb_only_requires_partial_frame)
    else $error("OPQ_PAGE_ALLOCATOR join-only absorb was active after the frame had no missing lanes");

  property p_full_active_frame_clears_join_wait;
    @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
      ((page_allocator.frame_join_wait != '0) &&
       (page_allocator.frame_lane_active == '1))
      |=>
      (page_allocator.frame_join_wait == '0);
  endproperty
  ap_full_active_frame_clears_join_wait: assert property (p_full_active_frame_clears_join_wait)
    else $error("OPQ_PAGE_ALLOCATOR kept a join window after all lanes had joined the frame");

  for (genvar g = 0; g < N_LANE; g++) begin : gen_tail_bypass_formal
    property p_tail_bypass_captures_shadow;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past(ingress_tail_bypass_valid_i[g])
        |->
        page_allocator.ingress_tail_seen_valid[g] &&
        (page_allocator.ingress_tail_serial_seen[g] == $past(ingress_tail_bypass_serial_i[g])) &&
        (page_allocator.ingress_tail_drop_seen[g] == $past(ingress_tail_bypass_drop_i[g])) &&
        (page_allocator.ingress_tail_ts_seen[g] == $past(ingress_tail_bypass_ts_i[g])) &&
        ingress_tail_status_valid_q[g][tail_status_slot($past(ingress_tail_bypass_serial_i[g]))] &&
        (ingress_tail_status_drop_q[g][tail_status_slot($past(ingress_tail_bypass_serial_i[g]))] ==
          $past(ingress_tail_bypass_drop_i[g]));
    endproperty
    ap_tail_bypass_captures_shadow: assert property (p_tail_bypass_captures_shadow)
      else $error("OPQ_PAGE_ALLOCATOR tail bypass did not persist into the per-serial shadow state");

    property p_fetch_tail_ready_accepts_live_bypass;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_SAMPLE_TAIL) &&
              page_allocator.ingress_tail_seen_valid[g] &&
              serial_reached_or_passed(
                page_allocator.ingress_tail_serial_seen[g],
                fetch_tail_target_serial_q[g]
              ))
        |-> fetch_tail_ready_q[g];
    endproperty
    ap_fetch_tail_ready_accepts_live_bypass: assert property (p_fetch_tail_ready_accepts_live_bypass)
      else $error("OPQ_PAGE_ALLOCATOR live ingress tail bypass did not mark the target packet tail-ready");

    property p_fetch_tail_drop_uses_shadow_exact_bypass;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_RESOLVE_TAIL) &&
              ingress_tail_status_rd_q[g][1] &&
              (ingress_tail_status_wrap_rd_q[g] == fetch_tail_target_wrap_q[g]))
        |-> (fetch_tail_dropped_q[g] == $past(ingress_tail_status_rd_q[g][0]));
    endproperty
    ap_fetch_tail_drop_uses_shadow_exact_bypass: assert property (p_fetch_tail_drop_uses_shadow_exact_bypass)
      else $error("OPQ_PAGE_ALLOCATOR shadowed bypass state did not drive fetch_tail_dropped_q for an earlier packet");

    property p_late_drop_serial_matches_ticket;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_APPLY_TICKET) &&
              (fetch_lane_action_q[g] == FETCH_LANE_LATE_DROP))
        |-> late_frame_drop_valid[g] &&
            (late_frame_drop_serial[g] ==
              ($past(fetch_ticket_raw_q[g][TICKET_ALT_SOP_LOC]) ?
                $past(fetch_ticket_raw_q[g][TICKET_SERIAL_HI:TICKET_SERIAL_LO]) :
                $past(fetch_ticket_q[g].frame_serial)));
    endproperty
    ap_late_drop_serial_matches_ticket: assert property (p_late_drop_serial_matches_ticket)
      else $error("OPQ_PAGE_ALLOCATOR late-drop serial did not match the dropped ticket identity");

`ifdef OPQ_NATIVE_FORMAL_STRICT
    property p_busy_parser_same_frame_keeps_frame_live;
      @(posedge d_clk) disable iff (d_reset)
        (page_allocator.frame_lane_active != '0) &&
        !page_allocator.frame_lane_active[g] &&
        !page_allocator_is_pending_ticket[g] &&
        ingress_parser_busy_i[g] &&
        (ingress_frame_ts_i[g] == page_allocator.frame_ts)
        |->
        active_frame_pending_nonfuture_ticket;
    endproperty
    ap_busy_parser_same_frame_keeps_frame_live: assert property (p_busy_parser_same_frame_keeps_frame_live)
      else $error("OPQ_PAGE_ALLOCATOR retired a live frame while an inactive lane parser was still busy on that same frame timestamp");

    property p_active_frame_body_serial_is_not_past;
      @(posedge d_clk) disable iff (d_reset)
        (page_allocator.frame_lane_active != '0) &&
        page_allocator_is_pending_ticket[g] &&
        !ticket_fifos_rd_data_i[g][TICKET_ALT_SOP_LOC] &&
        (ticket_fifos_rd_data_i[g][TICKET_TS_HI:TICKET_TS_LO] == page_allocator.running_ts) &&
        (ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] ==
          page_allocator.frame_serial_this)
        |->
        !page_allocator_is_tk_past[g];
    endproperty
    ap_active_frame_body_serial_is_not_past: assert property (p_active_frame_body_serial_is_not_past)
      else $error("OPQ_PAGE_ALLOCATOR active-frame body ticket fell into the past path despite matching the live frame serial");

    property p_fetch_active_frame_body_serial_is_not_past;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_CLASSIFY_TICKET) &&
              (page_allocator.frame_lane_active != '0) &&
              fetch_pending_q[g] &&
              !fetch_ticket_raw_q[g][TICKET_ALT_SOP_LOC] &&
              (fetch_ticket_q[g].ticket_ts == page_allocator.running_ts) &&
              (fetch_ticket_q[g].frame_serial == page_allocator.frame_serial_this))
        |->
        fetch_pending_q[g] &&
        ($past(fetch_ticket_q[g].frame_serial) == $past(page_allocator.frame_serial_this)) &&
        ($past(fetch_ticket_q[g].ticket_ts) == $past(page_allocator.running_ts)) &&
        !fetch_tk_past_q[g];
    endproperty
    ap_fetch_active_frame_body_serial_is_not_past: assert property (p_fetch_active_frame_body_serial_is_not_past)
      else $error("OPQ_PAGE_ALLOCATOR registered fetch path marked an active-frame body ticket as past");

    property p_fetch_current_join_sop_reactivates_inactive_lane;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_DECIDE_TICKET) &&
              (page_allocator.frame_lane_active != '0) &&
              !page_allocator.frame_lane_active[g] &&
              fetch_pending_q[g] &&
              fetch_tk_curr_q[g] &&
              fetch_tk_sop_q[g] &&
              !fetch_tail_dropped_q[g])
        |->
        (fetch_lane_action_q[g] == FETCH_LANE_ADVANCE_ONLY) &&
        fetch_lane_credit_valid_q[g] &&
        fetch_lane_reactivate_q[g];
    endproperty
    ap_fetch_current_join_sop_reactivates_inactive_lane: assert property (p_fetch_current_join_sop_reactivates_inactive_lane)
      else $error("OPQ_PAGE_ALLOCATOR failed to absorb a late current-frame SOP and reactivate its inactive lane");

    property p_apply_reactivate_marks_lane_active;
      @(posedge d_clk) disable iff (d_reset || !formal_past_valid)
        $past((page_allocator_state == PAGE_ALLOCATOR_APPLY_TICKET) &&
              (fetch_lane_action_q[g] == FETCH_LANE_ADVANCE_ONLY) &&
              fetch_lane_reactivate_q[g])
        |->
        page_allocator.frame_lane_active[g];
    endproperty
    ap_apply_reactivate_marks_lane_active: assert property (p_apply_reactivate_marks_lane_active)
      else $error("OPQ_PAGE_ALLOCATOR consumed a join SOP but failed to mark the lane active");

    cp_tail_bypass_shadow_drop_window: cover property (@(posedge d_clk) disable iff (d_reset)
      ingress_tail_bypass_valid_i[g] && ingress_tail_bypass_drop_i[g]
      ##1 page_allocator.ingress_tail_seen_valid[g]
      ##[1:16] ((page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) && all_lanes_fetch_ready)
      ##1 (page_allocator_state == PAGE_ALLOCATOR_SAMPLE_TAIL)
      ##1 (page_allocator_state == PAGE_ALLOCATOR_RESOLVE_TAIL)
      ##1 fetch_tail_dropped_q[g]);

    cp_active_frame_body_serial_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator.frame_lane_active != '0) &&
      page_allocator_is_pending_ticket[g] &&
      (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
      all_lanes_fetch_ready &&
      !ticket_fifos_rd_data_i[g][TICKET_ALT_SOP_LOC] &&
      (ticket_fifos_rd_data_i[g][TICKET_TS_HI:TICKET_TS_LO] == page_allocator.running_ts) &&
      (ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] ==
        page_allocator.frame_serial_this)
      ##1 (page_allocator_state == PAGE_ALLOCATOR_SAMPLE_TAIL) && fetch_pending_q[g]
      ##1 (page_allocator_state == PAGE_ALLOCATOR_RESOLVE_TAIL)
      ##1 (page_allocator_state == PAGE_ALLOCATOR_CLASSIFY_TICKET)
      ##1 fetch_pending_q[g] && !fetch_tk_past_q[g]);

    cp_current_join_sop_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator.frame_lane_active != '0) &&
      !page_allocator.frame_lane_active[g] &&
      page_allocator_is_pending_ticket[g] &&
      page_allocator_is_tk_sop[g] &&
      page_allocator_is_tk_curr[g]
      ##[1:4] ((page_allocator_state == PAGE_ALLOCATOR_DECIDE_TICKET) &&
               fetch_pending_q[g] &&
               fetch_tk_sop_q[g] &&
               fetch_tk_curr_q[g] &&
               !fetch_tail_dropped_q[g])
      ##1 fetch_lane_reactivate_q[g]);

    cp_busy_parser_same_frame_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator.frame_lane_active != '0) &&
      !page_allocator.frame_lane_active[g] &&
      !page_allocator_is_pending_ticket[g] &&
      ingress_parser_busy_i[g] &&
      (ingress_frame_ts_i[g] == page_allocator.frame_ts)
      ##1 active_frame_pending_nonfuture_ticket);
`endif

`ifndef SYNTHESIS
    cp_fetch_pending_serial_mismatch_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator_state == PAGE_ALLOCATOR_FETCH_TICKET) &&
      all_lanes_fetch_ready &&
      !ticket_fifos_rd_data_i[g][TICKET_ALT_SOP_LOC] &&
      (ticket_fifos_rd_data_i[g][TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] !=
        page_allocator_ticket_serial_ref)
      ##1 fetch_pending_q[g]);

    cp_idle_tail_flush_stage_window: cover property (@(posedge d_clk) disable iff (d_reset)
      (page_allocator_state == PAGE_ALLOCATOR_IDLE) &&
      (page_allocator.frame_lane_active != '0) &&
      all_active_lanes_tail_ready &&
      !active_frame_pending_nonfuture_ticket &&
      (page_allocator.frame_cnt != '0)
      ##1 (page_allocator_state == PAGE_ALLOCATOR_PREPARE_WRITE_TAIL)
      ##1 ((page_allocator_state == PAGE_ALLOCATOR_WRITE_TAIL) &&
           page_allocator.tail_only_flush));
`endif
  end
`endif

endmodule
