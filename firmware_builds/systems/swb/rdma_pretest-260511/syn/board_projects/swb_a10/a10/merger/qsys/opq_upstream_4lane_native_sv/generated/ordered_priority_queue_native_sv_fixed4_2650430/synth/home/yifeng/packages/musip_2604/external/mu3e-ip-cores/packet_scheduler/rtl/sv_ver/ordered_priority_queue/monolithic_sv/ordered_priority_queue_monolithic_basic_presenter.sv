//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_basic_presenter
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.4.13
// Date    : 20260428
// Change  : Preserve the native-presenter metadata staging registers so
//           frame-length arithmetic terminates before page-RAM pointer launch
//           control in MuSiP integration builds without changing queue order.
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_basic_presenter #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_RD_WIDTH = 36,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HDR_SIZE = 5,
  parameter int unsigned SHD_SIZE = 1,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned TRL_SIZE = 1,
  parameter int unsigned MAX_SHR_CNT_BITS = $clog2(N_SHD * N_LANE) + 1,
  parameter int unsigned MAX_HIT_CNT_BITS = (($clog2(N_SHD * N_HIT) + 1) < 16) ? ($clog2(N_SHD * N_HIT) + 1) : 16,
  parameter int unsigned META_ADDR_WIDTH = 9,
  parameter int unsigned EGRESS_DELAY = 3
) (
  input  logic                                            new_frame_valid_i,
  input  logic [PAGE_RAM_ADDR_WIDTH-1:0]                  new_frame_raw_addr_i,
  input  logic [MAX_SHR_CNT_BITS-1:0]                     frame_shr_cnt_this_i,
  input  logic [MAX_HIT_CNT_BITS-1:0]                     frame_hit_cnt_this_i,
  input  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]         frame_lane_shd_cnt_this_i,
  input  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]         frame_lane_hit_cnt_this_i,
  input  logic                                            packet_complete_i,
  input  logic [MAX_SHR_CNT_BITS-1:0]                     packet_complete_shr_cnt_i,
  input  logic [MAX_HIT_CNT_BITS-1:0]                     packet_complete_hit_cnt_i,
  input  logic                                            payload_commit_idle_i,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                  page_ram_rd_addr_o,
  input  logic [PAGE_RAM_DATA_WIDTH-1:0]                  page_ram_rd_data_i,
  output logic                                            resident_backpressure_hold_o,
  output logic                                            resident_head_valid_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                  resident_head_addr_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                  resident_head_len_o,
  output logic                                            resident_head_full_ring_o,
  output logic                                            resident_head_has_successor_o,
  output logic                                            ft_drop_valid_o,
  output logic [31:0]                                     ft_drop_hdr_cnt_o,
  output logic [31:0]                                     ft_drop_shd_cnt_o,
  output logic [31:0]                                     ft_drop_hit_cnt_o,
  output logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]         ft_drop_lane_shd_cnt_o,
  output logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]         ft_drop_lane_hit_cnt_o,
  output logic [PAGE_RAM_RD_WIDTH-1:0]                    aso_egress_data,
  output logic                                            aso_egress_valid,
  input  logic                                            aso_egress_ready,
  output logic                                            aso_egress_startofpacket,
  output logic                                            aso_egress_endofpacket,
  output logic [2:0]                                      aso_egress_error,
  input  logic                                            d_clk,
  input  logic                                            d_reset
);
`ifndef OPQ_OSS_FORMAL
  ordered_priority_queue_monolithic_basic_presenter_native #(
    .N_LANE(N_LANE),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_RD_WIDTH(PAGE_RAM_RD_WIDTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH),
    .N_SHD(N_SHD),
    .N_HIT(N_HIT),
    .HDR_SIZE(HDR_SIZE),
    .SHD_SIZE(SHD_SIZE),
    .HIT_SIZE(HIT_SIZE),
    .TRL_SIZE(TRL_SIZE),
    .MAX_SHR_CNT_BITS(MAX_SHR_CNT_BITS),
    .MAX_HIT_CNT_BITS(MAX_HIT_CNT_BITS),
    .META_ADDR_WIDTH(META_ADDR_WIDTH),
    .EGRESS_DELAY(EGRESS_DELAY)
  ) native_i (
    .new_frame_valid_i(new_frame_valid_i),
    .new_frame_raw_addr_i(new_frame_raw_addr_i),
    .frame_shr_cnt_this_i(frame_shr_cnt_this_i),
    .frame_hit_cnt_this_i(frame_hit_cnt_this_i),
    .frame_lane_shd_cnt_this_i(frame_lane_shd_cnt_this_i),
    .frame_lane_hit_cnt_this_i(frame_lane_hit_cnt_this_i),
    .packet_complete_i(packet_complete_i),
    .packet_complete_shr_cnt_i(packet_complete_shr_cnt_i),
    .packet_complete_hit_cnt_i(packet_complete_hit_cnt_i),
    .payload_commit_idle_i(payload_commit_idle_i),
    .page_ram_rd_addr_o(page_ram_rd_addr_o),
    .page_ram_rd_data_i(page_ram_rd_data_i),
    .resident_backpressure_hold_o(resident_backpressure_hold_o),
    .resident_head_valid_o(resident_head_valid_o),
    .resident_head_addr_o(resident_head_addr_o),
    .resident_head_len_o(resident_head_len_o),
    .resident_head_full_ring_o(resident_head_full_ring_o),
    .resident_head_has_successor_o(resident_head_has_successor_o),
    .ft_drop_valid_o(ft_drop_valid_o),
    .ft_drop_hdr_cnt_o(ft_drop_hdr_cnt_o),
    .ft_drop_shd_cnt_o(ft_drop_shd_cnt_o),
    .ft_drop_hit_cnt_o(ft_drop_hit_cnt_o),
    .ft_drop_lane_shd_cnt_o(ft_drop_lane_shd_cnt_o),
    .ft_drop_lane_hit_cnt_o(ft_drop_lane_hit_cnt_o),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );
`else
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam int unsigned META_DEPTH = 1 << META_ADDR_WIDTH;
  localparam int unsigned FRAME_LEN_WIDTH = PAGE_RAM_ADDR_WIDTH + 1;
  localparam int unsigned OVERLAP_MATH_WIDTH = PAGE_RAM_ADDR_WIDTH + 2;
  localparam int unsigned WORD_ACC_WIDTH = PAGE_RAM_ADDR_WIDTH + META_ADDR_WIDTH + 1;
  localparam int unsigned SHD_ACC_WIDTH = MAX_SHR_CNT_BITS + META_ADDR_WIDTH + 1;
  localparam int unsigned HIT_ACC_WIDTH = MAX_HIT_CNT_BITS + META_ADDR_WIDTH + 1;

  typedef logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_addr_t;
  typedef logic [META_ADDR_WIDTH-1:0] meta_ptr_t;
  typedef logic [WORD_ACC_WIDTH-1:0] meta_word_acc_t;
  typedef logic [SHD_ACC_WIDTH-1:0] meta_shd_acc_t;
  typedef logic [HIT_ACC_WIDTH-1:0] meta_hit_acc_t;
  localparam page_ram_addr_t PAGE_RAM_ADDR_ONE_CONST = {{(PAGE_RAM_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam meta_ptr_t META_PTR_ONE_CONST = {{(META_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam logic [OVERLAP_MATH_WIDTH-1:0] PAGE_RAM_DEPTH_EXT_CONST = PAGE_RAM_DEPTH;
  localparam bit PAGE_RAM_DEPTH_POWER_OF_TWO =
    ((PAGE_RAM_DEPTH & (PAGE_RAM_DEPTH - 1)) == 0);

  typedef enum logic [2:0] {
    FTABLE_PRESENTER_IDLE,
    FTABLE_PRESENTER_WAIT_FOR_COMPLETE,
    FTABLE_PRESENTER_PRESENTING,
    FTABLE_PRESENTER_RESET
  } presenter_state_t;

  presenter_state_t presenter_state;
  page_ram_addr_t meta_addr [META_DEPTH];
  page_ram_addr_t meta_len  [META_DEPTH];
  logic [MAX_SHR_CNT_BITS-1:0] meta_shd_cnt [META_DEPTH];
  logic [MAX_HIT_CNT_BITS-1:0] meta_hit_cnt [META_DEPTH];
  meta_word_acc_t meta_word_start [META_DEPTH];
  meta_shd_acc_t meta_shd_end [META_DEPTH];
  meta_hit_acc_t meta_hit_end [META_DEPTH];
  meta_ptr_t meta_wptr;
  meta_ptr_t meta_rptr;
  meta_ptr_t meta_pkt_wcnt;
  meta_ptr_t meta_pkt_rcnt;
  page_ram_addr_t page_ram_rptr;
  logic [EGRESS_DELAY:0] output_data_valid;
  logic [PAGE_RAM_DATA_WIDTH-1:0] output_data_pipe [EGRESS_DELAY-1:0];
  logic [PAGE_RAM_DATA_WIDTH-1:0] output_data;
  page_ram_addr_t pkt_rd_word_cnt;
  page_ram_addr_t packet_length;
  page_ram_addr_t launch_word_cnt;
  logic is_new_pkt_head;
  logic is_new_pkt_complete;
  logic output_is_trailer;
  logic launch_is_trailer;
  logic advance_output_pipe;
  logic startup_prefetch_ok;
  logic retire_pending;
  logic pkt_accept_started;
  logic suppress_next_packet_complete;
  logic [PAGE_RAM_DATA_WIDTH-1:0] launch_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] pipe_input_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_rd_data_skid;
  logic page_ram_skid_valid;
  logic [FRAME_LEN_WIDTH-1:0] new_frame_length_full;
  page_ram_addr_t new_frame_length;
  logic new_frame_oversize;
  logic overwrite_head_accepted_or_accepting;
  logic overwrite_drop_valid_next;
  logic overwrite_drop_flush_head;
  meta_ptr_t overwrite_drop_rptr_next;
  meta_ptr_t overwrite_drop_pkt_rcnt_next;
  logic [31:0] overwrite_drop_hdr_cnt_next;
  logic [31:0] overwrite_drop_shd_cnt_next;
  logic [31:0] overwrite_drop_hit_cnt_next;
  meta_word_acc_t meta_word_total_next_slot;
  meta_shd_acc_t meta_shd_total_next_slot;
  meta_hit_acc_t meta_hit_total_next_slot;

  function automatic logic [FRAME_LEN_WIDTH-1:0] frame_length_from_counts(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    logic [FRAME_LEN_WIDTH-1:0] shd_ext;
    logic [FRAME_LEN_WIDTH-1:0] hit_ext;
    begin
      shd_ext = shd_cnt;
      hit_ext = hit_cnt;
      frame_length_from_counts = (shd_ext * SHD_SIZE) + (hit_ext * HIT_SIZE) + HDR_SIZE + TRL_SIZE;
    end
  endfunction

  function automatic logic frame_length_spans_full_ring(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
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

  function automatic logic [31:0] extend32_shd(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt
  );
    extend32_shd = shd_cnt;
  endfunction

  function automatic logic [31:0] extend32_hit(
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    extend32_hit = hit_cnt;
  endfunction

  function automatic logic [31:0] extend32_shd_acc(
    input meta_shd_acc_t shd_cnt
  );
    extend32_shd_acc = shd_cnt;
  endfunction

  function automatic logic [31:0] extend32_hit_acc(
    input meta_hit_acc_t hit_cnt
  );
    extend32_hit_acc = hit_cnt;
  endfunction

  function automatic logic [OVERLAP_MATH_WIDTH-1:0] circular_distance(
    input page_ram_addr_t from_addr,
    input page_ram_addr_t to_addr
  );
    logic [OVERLAP_MATH_WIDTH-1:0] from_ext;
    logic [OVERLAP_MATH_WIDTH-1:0] to_ext;
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
          circular_distance = (PAGE_RAM_DEPTH_EXT_CONST - from_ext) + to_ext;
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
    logic [OVERLAP_MATH_WIDTH-1:0] lhs_len_ext;
    logic [OVERLAP_MATH_WIDTH-1:0] rhs_len_ext;
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

  always_comb begin
    is_new_pkt_head = (meta_wptr != meta_rptr);
    is_new_pkt_complete = (meta_pkt_wcnt != meta_pkt_rcnt);
    packet_length = meta_len[meta_rptr];
    new_frame_length_full = frame_length_from_counts(frame_shr_cnt_this_i, frame_hit_cnt_this_i);
    new_frame_length = new_frame_length_full[PAGE_RAM_ADDR_WIDTH-1:0];
    new_frame_oversize = (new_frame_length_full >= PAGE_RAM_DEPTH);
    output_data = output_data_pipe[EGRESS_DELAY-1];
    output_is_trailer =
      (output_data[35:32] == 4'b0001) &&
      (output_data[7:0] == K284);

    startup_prefetch_ok = pkt_accept_started || aso_egress_ready;
    advance_output_pipe =
      !page_ram_prime_pending &&
      (aso_egress_ready ||
       (!output_data_valid[EGRESS_DELAY] && startup_prefetch_ok));
    launch_word_cnt = pkt_rd_word_cnt;
    if (output_data_valid[EGRESS_DELAY] && aso_egress_ready) begin
      launch_word_cnt = pkt_rd_word_cnt + PAGE_RAM_ADDR_ONE_CONST;
    end

    pipe_input_data = page_ram_rd_data_skid;

    launch_data = output_data;
    if (advance_output_pipe) begin
      if (EGRESS_DELAY > 1) begin
        launch_data = output_data_pipe[EGRESS_DELAY-2];
      end else begin
        launch_data = pipe_input_data;
      end
    end

    launch_is_trailer =
      (launch_data[35:32] == 4'b0001) &&
      (launch_data[7:0] == K284);

    page_ram_rd_addr_o = page_ram_rptr;
    aso_egress_valid = 1'b0;
    if (presenter_state == FTABLE_PRESENTER_PRESENTING) begin
      aso_egress_valid = output_data_valid[EGRESS_DELAY];
    end
    aso_egress_data = output_data[PAGE_RAM_RD_WIDTH-1:0];
    aso_egress_startofpacket = aso_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K285);
    aso_egress_endofpacket = aso_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K284);
    aso_egress_error = '0;
    resident_backpressure_hold_o =
      !aso_egress_ready &&
      (((presenter_state != FTABLE_PRESENTER_IDLE) && (presenter_state != FTABLE_PRESENTER_RESET)) ||
       is_new_pkt_head ||
       is_new_pkt_complete ||
       (|output_data_valid) ||
       page_ram_skid_valid);
    resident_head_valid_o = is_new_pkt_head;
    resident_head_addr_o = '0;
    resident_head_len_o = '0;
    resident_head_full_ring_o = 1'b0;
    resident_head_has_successor_o = 1'b0;
    if (is_new_pkt_head) begin
      resident_head_addr_o = meta_addr[meta_rptr];
      resident_head_len_o = packet_length;
      resident_head_full_ring_o = frame_length_spans_full_ring(
        meta_shd_cnt[meta_rptr],
        meta_hit_cnt[meta_rptr]
      );
      resident_head_has_successor_o = (meta_wptr != (meta_rptr + META_PTR_ONE_CONST));
    end
  end

`ifdef OPQ_OSS_FORMAL
  always_comb begin : proc_overwrite_drop_plan
    // Once a word is visible at the egress interface, the current head is
    // live even if ready is low. Overwrite-drop must not flush that head
    // until the visible beat is accepted, or the Avalon-ST hold contract
    // and packet framing can break on the first stalled beat.
    overwrite_head_accepted_or_accepting =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      (pkt_accept_started || (|output_data_valid) || page_ram_skid_valid);
    overwrite_drop_valid_next = 1'b0;
    overwrite_drop_flush_head = 1'b0;
    overwrite_drop_rptr_next = meta_rptr;
    overwrite_drop_pkt_rcnt_next = meta_pkt_rcnt;
    overwrite_drop_hdr_cnt_next = '0;
    overwrite_drop_shd_cnt_next = '0;
    overwrite_drop_hit_cnt_next = '0;

    // Keep the OSS proof subset feed-forward. The unread-overwrite scan remains
    // on the native-SV signoff path; this subset still proves the live egress
    // hold contract plus oversize-frame drop accounting.
    if (new_frame_valid_i && new_frame_oversize) begin
      overwrite_drop_valid_next = 1'b1;
      overwrite_drop_hdr_cnt_next = 32'd1;
      overwrite_drop_shd_cnt_next = extend32_shd(frame_shr_cnt_this_i);
      overwrite_drop_hit_cnt_next = extend32_hit(frame_hit_cnt_this_i);
    end
  end
`else
  always_comb begin : proc_overwrite_drop_plan
    meta_ptr_t mid_ptr;
    meta_ptr_t last_drop_ptr;
    int unsigned unread_pkt_count;
    int unsigned left_idx;
    int unsigned right_idx;
    int unsigned mid_idx;
    int unsigned search_idx;
    int unsigned drop_pkt_count;
    meta_word_acc_t head_word_base;
    meta_word_acc_t overlap_word_limit;
    meta_word_acc_t gap_to_head_words;
    meta_shd_acc_t head_shd_end_base;
    meta_hit_acc_t head_hit_end_base;

    // Once a word is visible at the egress interface, the current head is
    // live even if ready is low. Overwrite-drop must not flush that head
    // until the visible beat is accepted, or the Avalon-ST hold contract
    // and packet framing can break on the first stalled beat.
    overwrite_head_accepted_or_accepting =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      (pkt_accept_started || output_data_valid[EGRESS_DELAY]);
    overwrite_drop_valid_next = 1'b0;
    overwrite_drop_flush_head = 1'b0;
    overwrite_drop_rptr_next = meta_rptr;
    overwrite_drop_pkt_rcnt_next = meta_pkt_rcnt;
    overwrite_drop_hdr_cnt_next = '0;
    overwrite_drop_shd_cnt_next = '0;
    overwrite_drop_hit_cnt_next = '0;
    mid_ptr = meta_rptr;
    last_drop_ptr = meta_rptr;
    unread_pkt_count = 0;
    left_idx = 0;
    right_idx = 0;
    mid_idx = 0;
    search_idx = 0;
    drop_pkt_count = 0;
    head_word_base = '0;
    overlap_word_limit = '0;
    gap_to_head_words = '0;
    head_shd_end_base = '0;
    head_hit_end_base = '0;

    if (new_frame_valid_i) begin
      if (new_frame_oversize) begin
        overwrite_drop_hdr_cnt_next = 32'd1;
        overwrite_drop_shd_cnt_next = extend32_shd(frame_shr_cnt_this_i);
        overwrite_drop_hit_cnt_next = extend32_hit(frame_hit_cnt_this_i);
      end else if (meta_pkt_rcnt != meta_pkt_wcnt) begin
        gap_to_head_words = circular_distance(new_frame_raw_addr_i, meta_addr[meta_rptr]);
        if ((meta_word_acc_t'(new_frame_length) > gap_to_head_words) &&
            !overwrite_head_accepted_or_accepting) begin
          unread_pkt_count = meta_pkt_wcnt - meta_pkt_rcnt;
          head_word_base = meta_word_start[meta_rptr];
          overlap_word_limit = head_word_base + meta_word_acc_t'(new_frame_length) - gap_to_head_words;
          left_idx = 0;
          right_idx = unread_pkt_count;

          for (search_idx = 0; search_idx < META_ADDR_WIDTH; search_idx = search_idx + 1) begin
            mid_idx = left_idx + ((right_idx - left_idx) >> 1);
            mid_ptr = meta_rptr + meta_ptr_t'(mid_idx);
            if ((mid_idx < unread_pkt_count) && (meta_word_start[mid_ptr] < overlap_word_limit)) begin
              left_idx = mid_idx + 1;
            end else begin
              right_idx = mid_idx;
            end
          end

          drop_pkt_count = left_idx;
          if (drop_pkt_count != 0) begin
            overwrite_drop_rptr_next = meta_rptr + meta_ptr_t'(drop_pkt_count);
            overwrite_drop_pkt_rcnt_next = meta_pkt_rcnt + meta_ptr_t'(drop_pkt_count);
            overwrite_drop_hdr_cnt_next = drop_pkt_count;
            last_drop_ptr = meta_rptr + meta_ptr_t'(drop_pkt_count - 1);
            head_shd_end_base = meta_shd_end[meta_rptr] - meta_shd_acc_t'(meta_shd_cnt[meta_rptr]);
            head_hit_end_base = meta_hit_end[meta_rptr] - meta_hit_acc_t'(meta_hit_cnt[meta_rptr]);
            overwrite_drop_shd_cnt_next = extend32_shd_acc(meta_shd_end[last_drop_ptr] - head_shd_end_base);
            overwrite_drop_hit_cnt_next = extend32_hit_acc(meta_hit_end[last_drop_ptr] - head_hit_end_base);
          end
        end
      end
    end

    overwrite_drop_valid_next =
      (overwrite_drop_hdr_cnt_next != 0) ||
      (overwrite_drop_shd_cnt_next != 0) ||
      (overwrite_drop_hit_cnt_next != 0);
    overwrite_drop_flush_head = overwrite_drop_valid_next && !new_frame_oversize;
  end
`endif

  always_ff @(posedge d_clk) begin
    integer pipe_valid_idx;
    integer pipe_data_idx;
    integer reset_pipe_idx;

    ft_drop_valid_o <= 1'b0;
    ft_drop_hdr_cnt_o <= '0;
    ft_drop_shd_cnt_o <= '0;
    ft_drop_hit_cnt_o <= '0;
    for (int lane_clear_idx = 0; lane_clear_idx < N_LANE; lane_clear_idx = lane_clear_idx + 1) begin
      ft_drop_lane_shd_cnt_o[lane_clear_idx] <= '0;
      ft_drop_lane_hit_cnt_o[lane_clear_idx] <= '0;
    end

    if (new_frame_valid_i) begin
      if (new_frame_oversize) begin
        suppress_next_packet_complete <= 1'b1;
      end else begin
        meta_addr[meta_wptr] <= new_frame_raw_addr_i;
        meta_len[meta_wptr] <= new_frame_length;
        meta_shd_cnt[meta_wptr] <= frame_shr_cnt_this_i;
        meta_hit_cnt[meta_wptr] <= frame_hit_cnt_this_i;
        meta_wptr <= meta_wptr + META_PTR_ONE_CONST;

        if (overwrite_drop_flush_head) begin
          meta_rptr <= overwrite_drop_rptr_next;
          meta_pkt_rcnt <= overwrite_drop_pkt_rcnt_next;
        end
      end

      if (overwrite_drop_valid_next) begin
        ft_drop_valid_o <= 1'b1;
        ft_drop_hdr_cnt_o <= overwrite_drop_hdr_cnt_next;
        ft_drop_shd_cnt_o <= overwrite_drop_shd_cnt_next;
        ft_drop_hit_cnt_o <= overwrite_drop_hit_cnt_next;
      end
    end

    if (packet_complete_i) begin
      if (suppress_next_packet_complete) begin
        suppress_next_packet_complete <= 1'b0;
      end else begin
        meta_word_start[meta_pkt_wcnt] <= meta_word_total_next_slot;
        meta_len[meta_pkt_wcnt] <= frame_length_from_counts(packet_complete_shr_cnt_i, packet_complete_hit_cnt_i);
        meta_shd_cnt[meta_pkt_wcnt] <= packet_complete_shr_cnt_i;
        meta_hit_cnt[meta_pkt_wcnt] <= packet_complete_hit_cnt_i;
        meta_shd_end[meta_pkt_wcnt] <= meta_shd_total_next_slot + meta_shd_acc_t'(packet_complete_shr_cnt_i);
        meta_hit_end[meta_pkt_wcnt] <= meta_hit_total_next_slot + meta_hit_acc_t'(packet_complete_hit_cnt_i);
        meta_word_total_next_slot <= meta_word_total_next_slot +
          meta_word_acc_t'(frame_length_from_counts(packet_complete_shr_cnt_i, packet_complete_hit_cnt_i));
        meta_shd_total_next_slot <= meta_shd_total_next_slot + meta_shd_acc_t'(packet_complete_shr_cnt_i);
        meta_hit_total_next_slot <= meta_hit_total_next_slot + meta_hit_acc_t'(packet_complete_hit_cnt_i);
        meta_pkt_wcnt <= meta_pkt_wcnt + META_PTR_ONE_CONST;
      end
    end

    if (overwrite_drop_flush_head) begin
      presenter_state <= FTABLE_PRESENTER_IDLE;
      output_data_valid <= '0;
      pkt_rd_word_cnt <= '0;
      retire_pending <= 1'b0;
      pkt_accept_started <= 1'b0;
      page_ram_skid_valid <= 1'b0;
      for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
        output_data_pipe[pipe_data_idx] <= '0;
      end
    end else begin
      unique case (presenter_state)
        FTABLE_PRESENTER_IDLE: begin
          if (is_new_pkt_head) begin
            presenter_state <= FTABLE_PRESENTER_WAIT_FOR_COMPLETE;
            pkt_accept_started <= 1'b0;
            page_ram_skid_valid <= 1'b0;
          end
        end

        FTABLE_PRESENTER_WAIT_FOR_COMPLETE: begin
          if (is_new_pkt_complete && payload_commit_idle_i && aso_egress_ready) begin
            presenter_state <= FTABLE_PRESENTER_PRESENTING;
            page_ram_rptr <= meta_addr[meta_rptr];
            pkt_rd_word_cnt <= '0;
            output_data_valid <= '0;
            retire_pending <= 1'b0;
            pkt_accept_started <= 1'b0;
            page_ram_skid_valid <= 1'b0;
            for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
              output_data_pipe[pipe_data_idx] <= '0;
            end
          end
        end

        FTABLE_PRESENTER_PRESENTING: begin
          if (retire_pending) begin
            if (output_data_valid[EGRESS_DELAY] && aso_egress_ready) begin
              presenter_state <= FTABLE_PRESENTER_IDLE;
              output_data_valid <= '0;
              meta_pkt_rcnt <= meta_pkt_rcnt + META_PTR_ONE_CONST;
              meta_rptr <= meta_rptr + META_PTR_ONE_CONST;
              retire_pending <= 1'b0;
              pkt_accept_started <= 1'b0;
              page_ram_skid_valid <= 1'b0;
              for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
                output_data_pipe[pipe_data_idx] <= '0;
              end
            end
          end else begin
            if (output_data_valid[EGRESS_DELAY] && !aso_egress_ready) begin
              if (!page_ram_skid_valid) begin
                page_ram_rd_data_skid <= page_ram_rd_data_i;
                page_ram_skid_valid <= 1'b1;
              end
            end
            if (output_data_valid[EGRESS_DELAY] && aso_egress_ready) begin
              pkt_rd_word_cnt <= pkt_rd_word_cnt + PAGE_RAM_ADDR_ONE_CONST;
              pkt_accept_started <= 1'b1;
            end
            if (advance_output_pipe) begin
              output_data_valid[0] <= 1'b1;
              for (pipe_valid_idx = 0; pipe_valid_idx < EGRESS_DELAY; pipe_valid_idx = pipe_valid_idx + 1) begin
                output_data_valid[pipe_valid_idx+1] <= output_data_valid[pipe_valid_idx];
              end
              output_data_pipe[0] <= pipe_input_data;
              for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY-1; pipe_data_idx = pipe_data_idx + 1) begin
                output_data_pipe[pipe_data_idx+1] <= output_data_pipe[pipe_data_idx];
              end
              page_ram_rptr <= page_ram_rptr + PAGE_RAM_ADDR_ONE_CONST;
              if (page_ram_skid_valid) begin
                page_ram_skid_valid <= 1'b0;
              end
            end

            if (advance_output_pipe && launch_is_trailer) begin
              output_data_valid <= '0;
              output_data_valid[EGRESS_DELAY] <= 1'b1;
              retire_pending <= 1'b1;
            end
          end
        end

        FTABLE_PRESENTER_RESET: begin
          presenter_state <= FTABLE_PRESENTER_IDLE;
          pkt_accept_started <= 1'b0;
        end

        default: begin
        end
      endcase
    end

    if (d_reset) begin
      presenter_state <= FTABLE_PRESENTER_RESET;
      meta_wptr <= '0;
      meta_rptr <= '0;
      meta_pkt_wcnt <= '0;
      meta_pkt_rcnt <= '0;
      page_ram_rptr <= '0;
      output_data_valid <= '0;
      for (reset_pipe_idx = 0; reset_pipe_idx < EGRESS_DELAY; reset_pipe_idx = reset_pipe_idx + 1) begin
        output_data_pipe[reset_pipe_idx] <= '0;
      end
      pkt_rd_word_cnt <= '0;
      retire_pending <= 1'b0;
      pkt_accept_started <= 1'b0;
      page_ram_rd_data_skid <= '0;
      page_ram_skid_valid <= 1'b0;
      suppress_next_packet_complete <= 1'b0;
      ft_drop_valid_o <= 1'b0;
      ft_drop_hdr_cnt_o <= '0;
      ft_drop_shd_cnt_o <= '0;
      ft_drop_hit_cnt_o <= '0;
      meta_word_total_next_slot <= '0;
      meta_shd_total_next_slot <= '0;
      meta_hit_total_next_slot <= '0;
    end
  end

// synthesis translate_off
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
  always_ff @(posedge d_clk) begin : proc_presenter_trace
    longint unsigned trace_after_ps_v;
    bit trace_after_ps_valid_v;
    bit trace_enable_v;

    trace_after_ps_v = 0;
`ifdef SYNTHESIS
    trace_after_ps_valid_v = 1'b0;
`else
    trace_after_ps_valid_v = $value$plusargs("OPQ_TRACE_AFTER_PS=%d", trace_after_ps_v);
`endif
    trace_enable_v = $test$plusargs("OPQ_NATIVE_TRACE_PRESENTER") &&
      (!trace_after_ps_valid_v || ($time >= trace_after_ps_v));

    if (trace_enable_v && (presenter_state == FTABLE_PRESENTER_WAIT_FOR_COMPLETE) && is_new_pkt_complete) begin
      $display(
        "[opq_presenter] t=%0t start meta_rptr=%0d addr=0x%0h len=%0d shd=%0d hit=%0d meta_pkt_rcnt=%0d meta_pkt_wcnt=%0d",
        $time,
        meta_rptr,
        meta_addr[meta_rptr],
        meta_len[meta_rptr],
        meta_shd_cnt[meta_rptr],
        meta_hit_cnt[meta_rptr],
        meta_pkt_rcnt,
        meta_pkt_wcnt
      );
    end

    if (trace_enable_v &&
        (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
        output_data_valid[EGRESS_DELAY] &&
        aso_egress_ready) begin
      $display(
        "[opq_presenter] t=%0t accept word_idx=%0d page_rptr=0x%0h meta_rptr=%0d data=0x%010h sop=%0b eop=%0b retire=%0b",
        $time,
        pkt_rd_word_cnt,
        page_ram_rptr,
        meta_rptr,
        output_data,
        ((output_data[35:32] == 4'b0001) && (output_data[7:0] == K285)),
        ((output_data[35:32] == 4'b0001) && (output_data[7:0] == K284)),
        retire_pending
      );
    end

    if (trace_enable_v && overwrite_drop_valid_next) begin
      $display(
        "[opq_presenter] t=%0t overwrite_drop hdr=%0d shd=%0d hit=%0d flush_head=%0b meta_rptr=%0d meta_pkt_rcnt=%0d",
        $time,
        overwrite_drop_hdr_cnt_next,
        overwrite_drop_shd_cnt_next,
        overwrite_drop_hit_cnt_next,
        overwrite_drop_flush_head,
        meta_rptr,
        meta_pkt_rcnt
      );
    end
  end
`endif
`endif
// synthesis translate_on

`ifndef OPQ_OSS_FORMAL
  property p_reset_enters_presenter_reset;
    @(posedge d_clk) d_reset |=> (presenter_state == FTABLE_PRESENTER_RESET);
  endproperty
  ap_reset_enters_presenter_reset: assert property (p_reset_enters_presenter_reset);

  property p_complete_without_head_never_advances;
    @(posedge d_clk) disable iff (d_reset)
      (!is_new_pkt_head && packet_complete_i) |=> (meta_rptr == $past(meta_rptr));
  endproperty
  ap_complete_without_head_never_advances: assert property (p_complete_without_head_never_advances);
`endif

`ifdef OPQ_ENABLE_NATIVE_FORMAL_EGRESS
  opq_native_basic_presenter_formal_sva #(
    .N_LANE(N_LANE),
    .N_SHD(N_SHD),
    .N_HIT(N_HIT),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_RD_WIDTH(PAGE_RAM_RD_WIDTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH),
    .META_ADDR_WIDTH(META_ADDR_WIDTH),
    .EGRESS_DELAY(EGRESS_DELAY)
  ) native_formal_sva_i (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .packet_complete_i(packet_complete_i),
    .new_frame_valid_i(new_frame_valid_i),
    .page_ram_rd_addr_o(page_ram_rd_addr_o),
    .page_ram_rd_data_i(page_ram_rd_data_i),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .presenter_state(presenter_state),
    .meta_wptr(meta_wptr),
    .meta_rptr(meta_rptr),
    .meta_pkt_wcnt(meta_pkt_wcnt),
    .meta_pkt_rcnt(meta_pkt_rcnt),
    .page_ram_rptr(page_ram_rptr),
    .output_data_valid(output_data_valid),
    .output_data(output_data),
    .pkt_rd_word_cnt(pkt_rd_word_cnt),
    .retire_pending(retire_pending)
  );
`endif

`endif
endmodule

module ordered_priority_queue_monolithic_basic_presenter_native #(
  parameter int unsigned N_LANE = 2,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_RD_WIDTH = 36,
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HDR_SIZE = 5,
  parameter int unsigned SHD_SIZE = 1,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned TRL_SIZE = 1,
  parameter int unsigned MAX_SHR_CNT_BITS = $clog2(N_SHD * N_LANE) + 1,
  parameter int unsigned MAX_HIT_CNT_BITS = (($clog2(N_SHD * N_HIT) + 1) < 16) ? ($clog2(N_SHD * N_HIT) + 1) : 16,
  parameter int unsigned META_ADDR_WIDTH = 9,
  parameter int unsigned EGRESS_DELAY = 3
) (
  input  logic                                            new_frame_valid_i,
  input  logic [PAGE_RAM_ADDR_WIDTH-1:0]                  new_frame_raw_addr_i,
  input  logic [MAX_SHR_CNT_BITS-1:0]                     frame_shr_cnt_this_i,
  input  logic [MAX_HIT_CNT_BITS-1:0]                     frame_hit_cnt_this_i,
  input  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]         frame_lane_shd_cnt_this_i,
  input  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]         frame_lane_hit_cnt_this_i,
  input  logic                                            packet_complete_i,
  input  logic [MAX_SHR_CNT_BITS-1:0]                     packet_complete_shr_cnt_i,
  input  logic [MAX_HIT_CNT_BITS-1:0]                     packet_complete_hit_cnt_i,
  input  logic                                            payload_commit_idle_i,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                  page_ram_rd_addr_o,
  input  logic [PAGE_RAM_DATA_WIDTH-1:0]                  page_ram_rd_data_i,
  output logic                                            resident_backpressure_hold_o,
  output logic                                            resident_head_valid_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                  resident_head_addr_o,
  output logic [PAGE_RAM_ADDR_WIDTH-1:0]                  resident_head_len_o,
  output logic                                            resident_head_full_ring_o,
  output logic                                            resident_head_has_successor_o,
  output logic                                            ft_drop_valid_o,
  output logic [31:0]                                     ft_drop_hdr_cnt_o,
  output logic [31:0]                                     ft_drop_shd_cnt_o,
  output logic [31:0]                                     ft_drop_hit_cnt_o,
  output logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0]         ft_drop_lane_shd_cnt_o,
  output logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0]         ft_drop_lane_hit_cnt_o,
  output logic [PAGE_RAM_RD_WIDTH-1:0]                    aso_egress_data,
  output logic                                            aso_egress_valid,
  input  logic                                            aso_egress_ready,
  output logic                                            aso_egress_startofpacket,
  output logic                                            aso_egress_endofpacket,
  output logic [2:0]                                      aso_egress_error,
  input  logic                                            d_clk,
  input  logic                                            d_reset
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam int unsigned META_DATA_WIDTH =
    PAGE_RAM_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_SHR_CNT_BITS + MAX_HIT_CNT_BITS;
  localparam int unsigned FRAME_LEN_WIDTH = PAGE_RAM_ADDR_WIDTH + 1;
  localparam int unsigned OVERLAP_MATH_WIDTH = PAGE_RAM_ADDR_WIDTH + 2;
  localparam int unsigned OVERLAP_REQ_DEPTH = 4;
  localparam int unsigned OVERLAP_REQ_PTR_WIDTH = (OVERLAP_REQ_DEPTH <= 1) ? 1 : $clog2(OVERLAP_REQ_DEPTH);
  localparam int unsigned OVERLAP_REQ_COUNT_WIDTH = $clog2(OVERLAP_REQ_DEPTH + 1);
  localparam int unsigned OUTPUT_VISIBLE_STAGE = EGRESS_DELAY - 1;
  localparam int unsigned PAGE_RAM_SKID_DEPTH = 3;
  localparam int unsigned PAGE_RAM_SKID_COUNT_WIDTH = $clog2(PAGE_RAM_SKID_DEPTH + 1);
  localparam int unsigned PAGE_RAM_RSP_LATENCY = 2;

  typedef logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_addr_t;
  typedef logic [META_ADDR_WIDTH-1:0] meta_ptr_t;
  typedef logic [META_DATA_WIDTH-1:0] meta_data_t;

  typedef enum logic [2:0] {
    FTABLE_PRESENTER_IDLE,
    FTABLE_PRESENTER_WAIT_FOR_COMPLETE,
    FTABLE_PRESENTER_PRESENTING,
    FTABLE_PRESENTER_RESET
  } presenter_state_t;

  typedef enum logic [1:0] {
    META_READ_IDLE,
    META_READ_HEAD,
    META_READ_SCAN
  } meta_read_owner_t;

  localparam page_ram_addr_t PAGE_RAM_ADDR_ONE_CONST = {{(PAGE_RAM_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam meta_ptr_t META_PTR_ONE_CONST = {{(META_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam logic [OVERLAP_MATH_WIDTH-1:0] PAGE_RAM_DEPTH_EXT_CONST = PAGE_RAM_DEPTH;
  localparam bit PAGE_RAM_DEPTH_POWER_OF_TWO =
    ((PAGE_RAM_DEPTH & (PAGE_RAM_DEPTH - 1)) == 0);

  presenter_state_t presenter_state;
  meta_ptr_t meta_wptr;
  meta_ptr_t meta_rptr;
  meta_ptr_t meta_rd_addr;
  logic [MAX_SHR_CNT_BITS-1:0] meta_lane_shd_cnt [1<<META_ADDR_WIDTH][N_LANE];
  logic [MAX_HIT_CNT_BITS-1:0] meta_lane_hit_cnt [1<<META_ADDR_WIDTH][N_LANE];
  meta_read_owner_t meta_read_owner;
  logic meta_read_pending;
  logic meta_read_armed;
  meta_data_t meta_rd_data;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic head_meta_valid;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  page_ram_addr_t head_addr_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  page_ram_addr_t head_len_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [MAX_SHR_CNT_BITS-1:0] head_shd_cnt_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [MAX_HIT_CNT_BITS-1:0] head_hit_cnt_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0] head_lane_shd_cnt_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0] head_lane_hit_cnt_q;
  logic pending_overlap_check_valid;
  page_ram_addr_t pending_overlap_addr_q;
  page_ram_addr_t pending_overlap_len_q;
  meta_ptr_t pending_overlap_stop_ptr_q;
  logic pending_overlap_launch_valid;
  page_ram_addr_t pending_overlap_launch_addr_q;
  page_ram_addr_t pending_overlap_launch_len_q;
  meta_ptr_t pending_overlap_launch_stop_ptr_q;
  logic [FRAME_LEN_WIDTH-1:0] pending_overlap_launch_remaining_words_q;
  logic pending_overlap_head_eval_valid_q;
  logic pending_overlap_head_eval_overlaps_q;
  page_ram_addr_t pending_overlap_head_eval_addr_q;
  page_ram_addr_t pending_overlap_head_eval_len_q;
  meta_ptr_t pending_overlap_head_eval_stop_ptr_q;
  logic [FRAME_LEN_WIDTH-1:0] pending_overlap_head_eval_remaining_words_q;
  logic [OVERLAP_REQ_PTR_WIDTH-1:0] overlap_req_wptr;
  logic [OVERLAP_REQ_PTR_WIDTH-1:0] overlap_req_rptr;
  logic [OVERLAP_REQ_COUNT_WIDTH-1:0] overlap_req_count;
  page_ram_addr_t overlap_req_addr_q [OVERLAP_REQ_DEPTH];
  page_ram_addr_t overlap_req_len_q [OVERLAP_REQ_DEPTH];
  meta_ptr_t overlap_req_stop_ptr_q [OVERLAP_REQ_DEPTH];
  logic overwrite_scan_active;
  logic overwrite_scan_process_head;
  meta_ptr_t overwrite_scan_next_ptr;
  meta_ptr_t overwrite_scan_stop_ptr;
  logic [FRAME_LEN_WIDTH-1:0] overwrite_scan_remaining_words;
  logic [31:0] overwrite_scan_hdr_cnt;
  logic [31:0] overwrite_scan_shd_cnt;
  logic [31:0] overwrite_scan_hit_cnt;
  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0] overwrite_scan_lane_shd_cnt;
  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0] overwrite_scan_lane_hit_cnt;
  logic scan_eval_valid_q;
  meta_ptr_t scan_eval_next_ptr_q;
  page_ram_addr_t scan_eval_addr_q;
  page_ram_addr_t scan_eval_len_q;
  logic [MAX_SHR_CNT_BITS-1:0] scan_eval_shd_q;
  logic [MAX_HIT_CNT_BITS-1:0] scan_eval_hit_q;
  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0] scan_eval_lane_shd_q;
  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0] scan_eval_lane_hit_q;
  logic scan_eval_overlaps_q;
  logic overwrite_head_eval_valid_q;
  meta_ptr_t overwrite_head_eval_next_ptr_q;
  page_ram_addr_t overwrite_head_eval_len_q;
  logic [MAX_SHR_CNT_BITS-1:0] overwrite_head_eval_shd_q;
  logic [MAX_HIT_CNT_BITS-1:0] overwrite_head_eval_hit_q;
  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0] overwrite_head_eval_lane_shd_q;
  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0] overwrite_head_eval_lane_hit_q;
  logic overwrite_head_eval_overlaps_q;
  logic overwrite_head_eval_last_q;
  page_ram_addr_t page_ram_rptr;
  logic [EGRESS_DELAY-1:0] output_data_valid;
  logic [PAGE_RAM_DATA_WIDTH-1:0] output_data_pipe [EGRESS_DELAY-1:0];
  logic [PAGE_RAM_DATA_WIDTH-1:0] output_data;
  page_ram_addr_t pkt_fetch_word_cnt;
  page_ram_addr_t pkt_rd_word_cnt;
  page_ram_addr_t packet_length;
  logic is_new_pkt_head;
  logic is_new_pkt_complete;
  logic advance_output_pipe;
  logic startup_prefetch_ok;
  logic output_is_trailer;
  logic [PAGE_RAM_DATA_WIDTH-1:0] launch_data;
  page_ram_addr_t launch_word_cnt;
  logic launch_is_trailer;
  logic retire_pending;
  logic pkt_accept_started;
  logic page_ram_prime_pending;
  logic page_ram_prime_drain_q;
  logic [PAGE_RAM_DATA_WIDTH-1:0] pipe_input_data;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_rd_data_skid [PAGE_RAM_SKID_DEPTH];
  logic [PAGE_RAM_SKID_COUNT_WIDTH-1:0] page_ram_skid_count;
  logic page_ram_skid_valid;
  logic [PAGE_RAM_RSP_LATENCY-1:0] page_ram_rsp_valid_pipe;
  page_ram_addr_t page_ram_rsp_addr_pipe [PAGE_RAM_RSP_LATENCY];
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_lookahead_data;
  page_ram_addr_t page_ram_lookahead_addr;
  logic page_ram_lookahead_valid;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_lookahead_pending_data;
  page_ram_addr_t page_ram_lookahead_pending_addr;
  logic page_ram_lookahead_pending_valid;
  logic [FRAME_LEN_WIDTH-1:0] new_frame_length_full_d;
  page_ram_addr_t new_frame_length_d;
  logic new_frame_oversize_d;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic new_frame_valid_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  page_ram_addr_t new_frame_raw_addr_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [MAX_SHR_CNT_BITS-1:0] frame_shr_cnt_this_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [MAX_HIT_CNT_BITS-1:0] frame_hit_cnt_this_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [N_LANE-1:0][MAX_SHR_CNT_BITS-1:0] frame_lane_shd_cnt_this_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic [N_LANE-1:0][MAX_HIT_CNT_BITS-1:0] frame_lane_hit_cnt_this_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  page_ram_addr_t new_frame_length_q;
  (* preserve, altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name PRESERVE_REGISTER ON" *)
  logic new_frame_oversize_q;
  logic overwrite_head_accepted_or_accepting;
  logic overlap_request_pending;

  assign page_ram_skid_valid = (page_ram_skid_count != '0);

`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
  bit opq_native_trace_egress_en;
  time opq_native_trace_egress_after_ps;

  initial begin
    opq_native_trace_egress_en = $test$plusargs("OPQ_NATIVE_TRACE_EGRESS_WORDS");
    opq_native_trace_egress_after_ps = 0;
    void'($value$plusargs("OPQ_NATIVE_TRACE_EGRESS_AFTER_PS=%d", opq_native_trace_egress_after_ps));
  end
`endif
`endif

  function automatic meta_data_t pack_meta(
    input page_ram_addr_t addr,
    input page_ram_addr_t len,
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    pack_meta = {hit_cnt, shd_cnt, len, addr};
  endfunction

  function automatic page_ram_addr_t meta_addr_from_data(
    input meta_data_t meta_data
  );
    meta_addr_from_data = meta_data[PAGE_RAM_ADDR_WIDTH-1:0];
  endfunction

  function automatic page_ram_addr_t meta_len_from_data(
    input meta_data_t meta_data
  );
    meta_len_from_data = meta_data[2*PAGE_RAM_ADDR_WIDTH-1:PAGE_RAM_ADDR_WIDTH];
  endfunction

  function automatic logic [MAX_SHR_CNT_BITS-1:0] meta_shd_from_data(
    input meta_data_t meta_data
  );
    meta_shd_from_data =
      meta_data[2*PAGE_RAM_ADDR_WIDTH+MAX_SHR_CNT_BITS-1:2*PAGE_RAM_ADDR_WIDTH];
  endfunction

  function automatic logic [MAX_HIT_CNT_BITS-1:0] meta_hit_from_data(
    input meta_data_t meta_data
  );
    meta_hit_from_data =
      meta_data[META_DATA_WIDTH-1:2*PAGE_RAM_ADDR_WIDTH+MAX_SHR_CNT_BITS];
  endfunction

  function automatic logic [FRAME_LEN_WIDTH-1:0] frame_length_from_counts(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    logic [FRAME_LEN_WIDTH-1:0] shd_ext;
    logic [FRAME_LEN_WIDTH-1:0] hit_ext;
    begin
      shd_ext = shd_cnt;
      hit_ext = hit_cnt;
      frame_length_from_counts = (shd_ext * SHD_SIZE) + (hit_ext * HIT_SIZE) + HDR_SIZE + TRL_SIZE;
    end
  endfunction

  function automatic logic frame_length_spans_full_ring(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt,
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
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

  function automatic logic [31:0] extend32_shd(
    input logic [MAX_SHR_CNT_BITS-1:0] shd_cnt
  );
    extend32_shd = shd_cnt;
  endfunction

  function automatic logic [31:0] extend32_hit(
    input logic [MAX_HIT_CNT_BITS-1:0] hit_cnt
  );
    extend32_hit = hit_cnt;
  endfunction

  function automatic logic [OVERLAP_MATH_WIDTH-1:0] circular_distance(
    input page_ram_addr_t from_addr,
    input page_ram_addr_t to_addr
  );
    logic [OVERLAP_MATH_WIDTH-1:0] from_ext;
    logic [OVERLAP_MATH_WIDTH-1:0] to_ext;
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
          circular_distance = (PAGE_RAM_DEPTH_EXT_CONST - from_ext) + to_ext;
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
    logic [OVERLAP_MATH_WIDTH-1:0] lhs_len_ext;
    logic [OVERLAP_MATH_WIDTH-1:0] rhs_len_ext;
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

  tile_fifo #(
    .DATA_WIDTH(META_DATA_WIDTH),
    .ADDR_WIDTH(META_ADDR_WIDTH)
  ) meta_ram_i (
    .data(pack_meta(new_frame_raw_addr_q, new_frame_length_q, frame_shr_cnt_this_q, frame_hit_cnt_this_q)),
    .read_addr(meta_rd_addr),
    .write_addr(meta_wptr),
    .we(new_frame_valid_q && !new_frame_oversize_q),
    .clk(d_clk),
    .q(meta_rd_data)
  );

  always_comb begin
    is_new_pkt_head = (meta_wptr != meta_rptr);
    is_new_pkt_complete = is_new_pkt_head;
    packet_length = head_len_q;
    new_frame_length_full_d = frame_length_from_counts(frame_shr_cnt_this_i, frame_hit_cnt_this_i);
    new_frame_length_d = new_frame_length_full_d[PAGE_RAM_ADDR_WIDTH-1:0];
    new_frame_oversize_d = (new_frame_length_full_d >= PAGE_RAM_DEPTH);
    output_data = output_data_pipe[EGRESS_DELAY-1];
    output_is_trailer = 1'b0;
    if ((output_data[35:32] == 4'b0001) && (output_data[7:0] == K284)) begin
      output_is_trailer = 1'b1;
    end else if (packet_length == pkt_rd_word_cnt) begin
      output_is_trailer = 1'b1;
    end

    startup_prefetch_ok = pkt_accept_started || aso_egress_ready;
    advance_output_pipe =
      !page_ram_prime_pending &&
      (aso_egress_ready ||
       (!output_data_valid[OUTPUT_VISIBLE_STAGE] && startup_prefetch_ok));
    launch_word_cnt = pkt_rd_word_cnt;
    if (output_data_valid[OUTPUT_VISIBLE_STAGE] && aso_egress_ready) begin
      launch_word_cnt = pkt_rd_word_cnt + PAGE_RAM_ADDR_ONE_CONST;
    end

    pipe_input_data = page_ram_rd_data_i;
    if (page_ram_skid_valid) begin
      pipe_input_data = page_ram_rd_data_skid[0];
    end

    launch_data = output_data;
    if (advance_output_pipe) begin
      if (EGRESS_DELAY > 1) begin
        launch_data = output_data_pipe[EGRESS_DELAY-2];
      end else begin
        launch_data = pipe_input_data;
      end
    end

    launch_is_trailer = 1'b0;
    if ((launch_data[35:32] == 4'b0001) && (launch_data[7:0] == K284)) begin
      launch_is_trailer = 1'b1;
    end else if (packet_length == launch_word_cnt) begin
      launch_is_trailer = 1'b1;
    end

    page_ram_rd_addr_o = page_ram_rptr;
    aso_egress_valid = 1'b0;
    if (presenter_state == FTABLE_PRESENTER_PRESENTING) begin
      aso_egress_valid = output_data_valid[OUTPUT_VISIBLE_STAGE];
    end
    aso_egress_data = output_data[PAGE_RAM_RD_WIDTH-1:0];
    aso_egress_startofpacket =
      aso_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K285);
    aso_egress_endofpacket =
      aso_egress_valid && (output_data[35:32] == 4'b0001) && (output_data[7:0] == K284);
    aso_egress_error = '0;

    overwrite_head_accepted_or_accepting =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      (pkt_accept_started || (|output_data_valid) || page_ram_skid_valid);
    overlap_request_pending =
      (overlap_req_count != '0) ||
      pending_overlap_check_valid ||
      pending_overlap_head_eval_valid_q ||
      pending_overlap_launch_valid ||
      overwrite_head_eval_valid_q ||
      overwrite_scan_active ||
      overwrite_scan_process_head ||
      scan_eval_valid_q;
    resident_backpressure_hold_o =
      ((!aso_egress_ready &&
        (((presenter_state != FTABLE_PRESENTER_IDLE) && (presenter_state != FTABLE_PRESENTER_RESET)) ||
         head_meta_valid ||
         meta_read_pending ||
         (meta_wptr != meta_rptr) ||
         (|output_data_valid) ||
         page_ram_skid_valid)) ||
       overlap_request_pending);
    resident_head_valid_o = head_meta_valid && !overwrite_head_accepted_or_accepting;
    resident_head_addr_o = '0;
    resident_head_len_o = '0;
    resident_head_full_ring_o = 1'b0;
    resident_head_has_successor_o = 1'b0;
    if (resident_head_valid_o) begin
      resident_head_addr_o = head_addr_q;
      resident_head_len_o = head_len_q;
      resident_head_full_ring_o = frame_length_spans_full_ring(head_shd_cnt_q, head_hit_cnt_q);
      resident_head_has_successor_o = (meta_wptr != (meta_rptr + META_PTR_ONE_CONST));
    end
  end

  always_ff @(posedge d_clk) begin : proc_new_frame_stage
    if (d_reset) begin
      new_frame_valid_q <= 1'b0;
      new_frame_raw_addr_q <= '0;
      frame_shr_cnt_this_q <= '0;
      frame_hit_cnt_this_q <= '0;
      for (int lane_clear_idx = 0; lane_clear_idx < N_LANE; lane_clear_idx = lane_clear_idx + 1) begin
        frame_lane_shd_cnt_this_q[lane_clear_idx] <= '0;
        frame_lane_hit_cnt_this_q[lane_clear_idx] <= '0;
      end
      new_frame_length_q <= '0;
      new_frame_oversize_q <= 1'b0;
    end else begin
      new_frame_valid_q <= new_frame_valid_i;
      if (new_frame_valid_i) begin
        new_frame_raw_addr_q <= new_frame_raw_addr_i;
        frame_shr_cnt_this_q <= frame_shr_cnt_this_i;
        frame_hit_cnt_this_q <= frame_hit_cnt_this_i;
        frame_lane_shd_cnt_this_q <= frame_lane_shd_cnt_this_i;
        frame_lane_hit_cnt_this_q <= frame_lane_hit_cnt_this_i;
        new_frame_length_q <= new_frame_length_d;
        new_frame_oversize_q <= new_frame_oversize_d;
      end
    end
  end

  always_ff @(posedge d_clk) begin
    integer pipe_valid_idx;
    integer pipe_data_idx;
    integer reset_pipe_idx;
    bit block_meta_head_fetch_v;
    bit block_present_start_v;
    logic [FRAME_LEN_WIDTH-1:0] remaining_words_v;
    meta_ptr_t next_scan_ptr_v;
    page_ram_addr_t scan_len_v;
    page_ram_addr_t scan_addr_v;
    logic [MAX_SHR_CNT_BITS-1:0] scan_shd_v;
    logic [MAX_HIT_CNT_BITS-1:0] scan_hit_v;
    bit scan_overlaps_v;
    bit head_overlaps_v;
    bit launch_head_overlaps_v;
    bit stage0_load_valid_v;
    bit output_accept_v;
    bit final_output_accept_v;
    integer skid_idx;
    integer rsp_idx;
    bit page_ram_issue_valid_v;
    bit page_ram_direct_consume_v;
    bit page_ram_skid_pop_v;
    bit page_ram_skid_push_v;

    ft_drop_valid_o <= 1'b0;
    ft_drop_hdr_cnt_o <= '0;
    ft_drop_shd_cnt_o <= '0;
    ft_drop_hit_cnt_o <= '0;
    block_meta_head_fetch_v =
      overwrite_head_eval_valid_q ||
      overwrite_scan_active ||
      overwrite_scan_process_head ||
      scan_eval_valid_q;
    block_present_start_v =
      overwrite_head_eval_valid_q ||
      overwrite_scan_active ||
      overwrite_scan_process_head ||
      pending_overlap_head_eval_valid_q ||
      pending_overlap_launch_valid ||
      pending_overlap_check_valid ||
      scan_eval_valid_q;
    stage0_load_valid_v =
      page_ram_skid_valid ||
      (!page_ram_prime_pending && (pkt_fetch_word_cnt != packet_length));
    output_accept_v = output_data_valid[OUTPUT_VISIBLE_STAGE] && aso_egress_ready;
    final_output_accept_v =
      retire_pending &&
      output_accept_v &&
      aso_egress_endofpacket;
    page_ram_issue_valid_v =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      (page_ram_prime_pending ||
       (advance_output_pipe && stage0_load_valid_v));
    page_ram_direct_consume_v =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      advance_output_pipe &&
      stage0_load_valid_v &&
      !page_ram_skid_valid &&
      !page_ram_prime_pending;
    page_ram_skid_pop_v =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      advance_output_pipe &&
      stage0_load_valid_v &&
      page_ram_skid_valid;
    page_ram_skid_push_v =
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      !page_ram_prime_pending &&
      page_ram_rsp_valid_pipe[PAGE_RAM_RSP_LATENCY-1] &&
      !page_ram_direct_consume_v &&
      (pkt_fetch_word_cnt != packet_length) &&
      ((page_ram_skid_count < PAGE_RAM_SKID_COUNT_WIDTH'(PAGE_RAM_SKID_DEPTH)) ||
       page_ram_skid_pop_v);

    if (d_reset) begin
      presenter_state <= FTABLE_PRESENTER_RESET;
      meta_wptr <= '0;
      meta_rptr <= '0;
      meta_rd_addr <= '0;
      meta_read_owner <= META_READ_IDLE;
      meta_read_pending <= 1'b0;
      meta_read_armed <= 1'b0;
      head_meta_valid <= 1'b0;
      head_addr_q <= '0;
      head_len_q <= '0;
      head_shd_cnt_q <= '0;
      head_hit_cnt_q <= '0;
      for (int lane_clear_idx = 0; lane_clear_idx < N_LANE; lane_clear_idx = lane_clear_idx + 1) begin
        head_lane_shd_cnt_q[lane_clear_idx] <= '0;
        head_lane_hit_cnt_q[lane_clear_idx] <= '0;
      end
      pending_overlap_check_valid <= 1'b0;
      pending_overlap_addr_q <= '0;
      pending_overlap_len_q <= '0;
      pending_overlap_stop_ptr_q <= '0;
      pending_overlap_launch_valid <= 1'b0;
      pending_overlap_launch_addr_q <= '0;
      pending_overlap_launch_len_q <= '0;
      pending_overlap_launch_stop_ptr_q <= '0;
      pending_overlap_launch_remaining_words_q <= '0;
      pending_overlap_head_eval_valid_q <= 1'b0;
      pending_overlap_head_eval_overlaps_q <= 1'b0;
      pending_overlap_head_eval_addr_q <= '0;
      pending_overlap_head_eval_len_q <= '0;
      pending_overlap_head_eval_stop_ptr_q <= '0;
      pending_overlap_head_eval_remaining_words_q <= '0;
      overlap_req_wptr <= '0;
      overlap_req_rptr <= '0;
      overlap_req_count <= '0;
      overwrite_scan_active <= 1'b0;
      overwrite_scan_process_head <= 1'b0;
      overwrite_scan_next_ptr <= '0;
      overwrite_scan_stop_ptr <= '0;
      overwrite_scan_remaining_words <= '0;
      overwrite_scan_hdr_cnt <= '0;
      overwrite_scan_shd_cnt <= '0;
      overwrite_scan_hit_cnt <= '0;
      for (int lane_clear_idx = 0; lane_clear_idx < N_LANE; lane_clear_idx = lane_clear_idx + 1) begin
        overwrite_scan_lane_shd_cnt[lane_clear_idx] <= '0;
        overwrite_scan_lane_hit_cnt[lane_clear_idx] <= '0;
      end
      scan_eval_valid_q <= 1'b0;
      scan_eval_next_ptr_q <= '0;
      scan_eval_addr_q <= '0;
      scan_eval_len_q <= '0;
      scan_eval_shd_q <= '0;
      scan_eval_hit_q <= '0;
      for (int lane_clear_idx = 0; lane_clear_idx < N_LANE; lane_clear_idx = lane_clear_idx + 1) begin
        scan_eval_lane_shd_q[lane_clear_idx] <= '0;
        scan_eval_lane_hit_q[lane_clear_idx] <= '0;
      end
      scan_eval_overlaps_q <= 1'b0;
      overwrite_head_eval_valid_q <= 1'b0;
      overwrite_head_eval_next_ptr_q <= '0;
      overwrite_head_eval_len_q <= '0;
      overwrite_head_eval_shd_q <= '0;
      overwrite_head_eval_hit_q <= '0;
      for (int lane_clear_idx = 0; lane_clear_idx < N_LANE; lane_clear_idx = lane_clear_idx + 1) begin
        overwrite_head_eval_lane_shd_q[lane_clear_idx] <= '0;
        overwrite_head_eval_lane_hit_q[lane_clear_idx] <= '0;
      end
      overwrite_head_eval_overlaps_q <= 1'b0;
      overwrite_head_eval_last_q <= 1'b0;
      page_ram_rptr <= '0;
      output_data_valid <= '0;
      for (reset_pipe_idx = 0; reset_pipe_idx < EGRESS_DELAY; reset_pipe_idx = reset_pipe_idx + 1) begin
        output_data_pipe[reset_pipe_idx] <= '0;
      end
      pkt_fetch_word_cnt <= '0;
      pkt_rd_word_cnt <= '0;
      retire_pending <= 1'b0;
      pkt_accept_started <= 1'b0;
      page_ram_prime_pending <= 1'b0;
      page_ram_prime_drain_q <= 1'b0;
      for (skid_idx = 0; skid_idx < PAGE_RAM_SKID_DEPTH; skid_idx = skid_idx + 1) begin
        page_ram_rd_data_skid[skid_idx] <= '0;
      end
      page_ram_skid_count <= '0;
      page_ram_rsp_valid_pipe <= '0;
      for (rsp_idx = 0; rsp_idx < PAGE_RAM_RSP_LATENCY; rsp_idx = rsp_idx + 1) begin
        page_ram_rsp_addr_pipe[rsp_idx] <= '0;
      end
      page_ram_lookahead_data <= '0;
      page_ram_lookahead_addr <= '0;
      page_ram_lookahead_valid <= 1'b0;
      page_ram_lookahead_pending_data <= '0;
      page_ram_lookahead_pending_addr <= '0;
      page_ram_lookahead_pending_valid <= 1'b0;
    end else begin
      page_ram_rsp_valid_pipe[0] <= page_ram_issue_valid_v;
      page_ram_rsp_addr_pipe[0] <= page_ram_rptr;
      for (rsp_idx = 1; rsp_idx < PAGE_RAM_RSP_LATENCY; rsp_idx = rsp_idx + 1) begin
        page_ram_rsp_valid_pipe[rsp_idx] <= page_ram_rsp_valid_pipe[rsp_idx-1];
        page_ram_rsp_addr_pipe[rsp_idx] <= page_ram_rsp_addr_pipe[rsp_idx-1];
      end

      if (page_ram_lookahead_pending_valid) begin
        page_ram_lookahead_pending_valid <= 1'b0;
        if (!page_ram_lookahead_valid &&
            (page_ram_lookahead_pending_data[35:32] == 4'b0001) &&
            (page_ram_lookahead_pending_data[7:0] == K285)) begin
          page_ram_lookahead_data <= page_ram_lookahead_pending_data;
          page_ram_lookahead_addr <= page_ram_lookahead_pending_addr;
          page_ram_lookahead_valid <= 1'b1;
        end
      end

      if (meta_read_pending) begin
        if (!meta_read_armed) begin
          meta_read_armed <= 1'b1;
        end else begin
          meta_read_pending <= 1'b0;
          meta_read_armed <= 1'b0;
          meta_read_owner <= META_READ_IDLE;

          unique case (meta_read_owner)
            META_READ_HEAD: begin
              head_meta_valid <= 1'b1;
              head_addr_q <= meta_addr_from_data(meta_rd_data);
              head_len_q <= meta_len_from_data(meta_rd_data);
              head_shd_cnt_q <= meta_shd_from_data(meta_rd_data);
              head_hit_cnt_q <= meta_hit_from_data(meta_rd_data);
              for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
                head_lane_shd_cnt_q[lane_idx] <= meta_lane_shd_cnt[meta_rd_addr][lane_idx];
                head_lane_hit_cnt_q[lane_idx] <= meta_lane_hit_cnt[meta_rd_addr][lane_idx];
              end
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
              if ($test$plusargs("OPQ_NATIVE_TRACE_OWNERSHIP")) begin
                $display(
                  "[opq_native_meta] t=%0t evt=read_head slot=0x%0h data=0x%0h addr=0x%0h len=0x%0h shd=%0d hit=%0d",
                  $time,
                  meta_rd_addr,
                  meta_rd_data,
                  meta_addr_from_data(meta_rd_data),
                  meta_len_from_data(meta_rd_data),
                  meta_shd_from_data(meta_rd_data),
                  meta_hit_from_data(meta_rd_data)
                );
              end
`endif
`endif
            end

            META_READ_SCAN: begin
              scan_addr_v = meta_addr_from_data(meta_rd_data);
              scan_len_v = meta_len_from_data(meta_rd_data);
              scan_shd_v = meta_shd_from_data(meta_rd_data);
              scan_hit_v = meta_hit_from_data(meta_rd_data);
              next_scan_ptr_v = overwrite_scan_next_ptr + META_PTR_ONE_CONST;
              scan_overlaps_v = circular_range_overlaps(
                pending_overlap_launch_addr_q,
                pending_overlap_launch_len_q,
                scan_addr_v,
                scan_len_v
              );
              scan_eval_valid_q <= 1'b1;
              scan_eval_next_ptr_q <= next_scan_ptr_v;
              scan_eval_addr_q <= scan_addr_v;
              scan_eval_len_q <= scan_len_v;
              scan_eval_shd_q <= scan_shd_v;
              scan_eval_hit_q <= scan_hit_v;
              for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
                scan_eval_lane_shd_q[lane_idx] <= meta_lane_shd_cnt[meta_rd_addr][lane_idx];
                scan_eval_lane_hit_q[lane_idx] <= meta_lane_hit_cnt[meta_rd_addr][lane_idx];
              end
              scan_eval_overlaps_q <= scan_overlaps_v;
            end

            default: begin
            end
          endcase
        end
      end

      if (scan_eval_valid_q) begin
        scan_eval_valid_q <= 1'b0;
        if (!scan_eval_overlaps_q) begin
          if ((overwrite_scan_hdr_cnt != 0) ||
              (overwrite_scan_shd_cnt != 0) ||
              (overwrite_scan_hit_cnt != 0)) begin
            ft_drop_valid_o <= 1'b1;
            ft_drop_hdr_cnt_o <= overwrite_scan_hdr_cnt;
            ft_drop_shd_cnt_o <= overwrite_scan_shd_cnt;
            ft_drop_hit_cnt_o <= overwrite_scan_hit_cnt;
            ft_drop_lane_shd_cnt_o <= overwrite_scan_lane_shd_cnt;
            ft_drop_lane_hit_cnt_o <= overwrite_scan_lane_hit_cnt;
          end
          meta_rptr <= overwrite_scan_next_ptr;
          head_meta_valid <= 1'b1;
          head_addr_q <= scan_eval_addr_q;
          head_len_q <= scan_eval_len_q;
          head_shd_cnt_q <= scan_eval_shd_q;
          head_hit_cnt_q <= scan_eval_hit_q;
          head_lane_shd_cnt_q <= scan_eval_lane_shd_q;
          head_lane_hit_cnt_q <= scan_eval_lane_hit_q;
          overwrite_scan_active <= 1'b0;
          overwrite_scan_process_head <= 1'b0;
          presenter_state <= FTABLE_PRESENTER_IDLE;
          output_data_valid <= '0;
          pkt_rd_word_cnt <= '0;
          retire_pending <= 1'b0;
          pkt_accept_started <= 1'b0;
          page_ram_prime_pending <= 1'b0;
          page_ram_prime_drain_q <= 1'b0;
          page_ram_skid_count <= '0;
          page_ram_lookahead_valid <= 1'b0;
          page_ram_lookahead_pending_valid <= 1'b0;
          for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
            output_data_pipe[pipe_data_idx] <= '0;
          end
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
          if ($test$plusargs("OPQ_NATIVE_TRACE_OWNERSHIP")) begin
            $display(
              "[opq_native_scan] t=%0t evt=scan_stop_keep head_ptr=0x%0h head_addr=0x%0h head_len=0x%0h drop_hdr=%0d drop_shd=%0d drop_hit=%0d",
              $time,
              overwrite_scan_next_ptr,
              scan_eval_addr_q,
              scan_eval_len_q,
              overwrite_scan_hdr_cnt,
              overwrite_scan_shd_cnt,
              overwrite_scan_hit_cnt
            );
          end
`endif
`endif
        end else if (scan_eval_next_ptr_q == overwrite_scan_stop_ptr) begin
          ft_drop_valid_o <= 1'b1;
          ft_drop_hdr_cnt_o <= overwrite_scan_hdr_cnt + 32'd1;
          ft_drop_shd_cnt_o <= overwrite_scan_shd_cnt + extend32_shd(scan_eval_shd_q);
          ft_drop_hit_cnt_o <= overwrite_scan_hit_cnt + extend32_hit(scan_eval_hit_q);
          ft_drop_lane_shd_cnt_o <= overwrite_scan_lane_shd_cnt;
          ft_drop_lane_hit_cnt_o <= overwrite_scan_lane_hit_cnt;
          for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
            ft_drop_lane_shd_cnt_o[lane_idx] <=
              overwrite_scan_lane_shd_cnt[lane_idx] + scan_eval_lane_shd_q[lane_idx];
            ft_drop_lane_hit_cnt_o[lane_idx] <=
              overwrite_scan_lane_hit_cnt[lane_idx] + scan_eval_lane_hit_q[lane_idx];
          end
          meta_rptr <= scan_eval_next_ptr_q;
          head_meta_valid <= 1'b0;
          overwrite_scan_active <= 1'b0;
          overwrite_scan_process_head <= 1'b0;
          presenter_state <= FTABLE_PRESENTER_IDLE;
          output_data_valid <= '0;
          pkt_rd_word_cnt <= '0;
          retire_pending <= 1'b0;
          pkt_accept_started <= 1'b0;
          page_ram_prime_pending <= 1'b0;
          page_ram_prime_drain_q <= 1'b0;
          page_ram_skid_count <= '0;
          page_ram_lookahead_valid <= 1'b0;
          page_ram_lookahead_pending_valid <= 1'b0;
          for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
            output_data_pipe[pipe_data_idx] <= '0;
          end
        end else begin
          overwrite_scan_hdr_cnt <= overwrite_scan_hdr_cnt + 32'd1;
          overwrite_scan_shd_cnt <= overwrite_scan_shd_cnt + extend32_shd(scan_eval_shd_q);
          overwrite_scan_hit_cnt <= overwrite_scan_hit_cnt + extend32_hit(scan_eval_hit_q);
          for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
            overwrite_scan_lane_shd_cnt[lane_idx] <=
              overwrite_scan_lane_shd_cnt[lane_idx] + scan_eval_lane_shd_q[lane_idx];
            overwrite_scan_lane_hit_cnt[lane_idx] <=
              overwrite_scan_lane_hit_cnt[lane_idx] + scan_eval_lane_hit_q[lane_idx];
          end
          overwrite_scan_remaining_words <= overwrite_scan_remaining_words - scan_eval_len_q;
          overwrite_scan_next_ptr <= scan_eval_next_ptr_q;
          meta_rd_addr <= scan_eval_next_ptr_q;
          meta_read_pending <= 1'b1;
          meta_read_armed <= 1'b0;
          meta_read_owner <= META_READ_SCAN;
        end
      end

      if (new_frame_valid_q) begin
        if (new_frame_oversize_q) begin
          ft_drop_valid_o <= 1'b1;
          ft_drop_hdr_cnt_o <= 32'd1;
          ft_drop_shd_cnt_o <= extend32_shd(frame_shr_cnt_this_q);
          ft_drop_hit_cnt_o <= extend32_hit(frame_hit_cnt_this_q);
          ft_drop_lane_shd_cnt_o <= frame_lane_shd_cnt_this_q;
          ft_drop_lane_hit_cnt_o <= frame_lane_hit_cnt_this_q;
        end else begin
          if ((meta_wptr == meta_rptr) && !head_meta_valid) begin
            head_meta_valid <= 1'b1;
            head_addr_q <= new_frame_raw_addr_q;
            head_len_q <= new_frame_length_q;
            head_shd_cnt_q <= frame_shr_cnt_this_q;
            head_hit_cnt_q <= frame_hit_cnt_this_q;
            head_lane_shd_cnt_q <= frame_lane_shd_cnt_this_q;
            head_lane_hit_cnt_q <= frame_lane_hit_cnt_this_q;
          end

          if (meta_wptr != meta_rptr) begin
            if (!pending_overlap_check_valid &&
                !pending_overlap_launch_valid &&
                !overwrite_scan_active &&
                !overwrite_scan_process_head &&
                (overlap_req_count == '0)) begin
              pending_overlap_check_valid <= 1'b1;
              pending_overlap_addr_q <= new_frame_raw_addr_q;
              pending_overlap_len_q <= new_frame_length_q;
              pending_overlap_stop_ptr_q <= meta_wptr;
            end else if (overlap_req_count < OVERLAP_REQ_DEPTH) begin
              overlap_req_addr_q[overlap_req_wptr] <= new_frame_raw_addr_q;
              overlap_req_len_q[overlap_req_wptr] <= new_frame_length_q;
              overlap_req_stop_ptr_q[overlap_req_wptr] <= meta_wptr;
              overlap_req_wptr <= overlap_req_wptr + OVERLAP_REQ_PTR_WIDTH'(1);
              overlap_req_count <= overlap_req_count + OVERLAP_REQ_COUNT_WIDTH'(1);
            end
            block_present_start_v = 1'b1;
          end

          meta_wptr <= meta_wptr + META_PTR_ONE_CONST;
          for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
            meta_lane_shd_cnt[meta_wptr][lane_idx] <= frame_lane_shd_cnt_this_q[lane_idx];
            meta_lane_hit_cnt[meta_wptr][lane_idx] <= frame_lane_hit_cnt_this_q[lane_idx];
          end
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
          if ($test$plusargs("OPQ_NATIVE_TRACE_OWNERSHIP")) begin
            $display(
              "[opq_native_meta] t=%0t evt=write slot=0x%0h addr=0x%0h len=0x%0h shd=%0d hit=%0d",
              $time,
              meta_wptr,
              new_frame_raw_addr_q,
              new_frame_length_q,
              frame_shr_cnt_this_q,
              frame_hit_cnt_this_q
            );
          end
`endif
`endif
        end
      end

      if (overwrite_scan_process_head) begin
        next_scan_ptr_v = meta_rptr + META_PTR_ONE_CONST;
        head_overlaps_v = circular_range_overlaps(
          pending_overlap_launch_addr_q,
          pending_overlap_launch_len_q,
          head_addr_q,
          head_len_q
        );
        overwrite_scan_process_head <= 1'b0;
        overwrite_head_eval_valid_q <= 1'b1;
        overwrite_head_eval_next_ptr_q <= next_scan_ptr_v;
        overwrite_head_eval_len_q <= head_len_q;
        overwrite_head_eval_shd_q <= head_shd_cnt_q;
        overwrite_head_eval_hit_q <= head_hit_cnt_q;
        overwrite_head_eval_lane_shd_q <= head_lane_shd_cnt_q;
        overwrite_head_eval_lane_hit_q <= head_lane_hit_cnt_q;
        overwrite_head_eval_overlaps_q <= head_overlaps_v;
        overwrite_head_eval_last_q <= (next_scan_ptr_v == overwrite_scan_stop_ptr);
      end

      if (overwrite_head_eval_valid_q) begin
        overwrite_head_eval_valid_q <= 1'b0;
        if (!overwrite_head_eval_overlaps_q) begin
          overwrite_scan_active <= 1'b0;
        end else if (overwrite_head_eval_last_q) begin
          ft_drop_valid_o <= 1'b1;
          ft_drop_hdr_cnt_o <= overwrite_scan_hdr_cnt + 32'd1;
          ft_drop_shd_cnt_o <= overwrite_scan_shd_cnt + extend32_shd(overwrite_head_eval_shd_q);
          ft_drop_hit_cnt_o <= overwrite_scan_hit_cnt + extend32_hit(overwrite_head_eval_hit_q);
          ft_drop_lane_shd_cnt_o <= overwrite_scan_lane_shd_cnt;
          ft_drop_lane_hit_cnt_o <= overwrite_scan_lane_hit_cnt;
          for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
            ft_drop_lane_shd_cnt_o[lane_idx] <=
              overwrite_scan_lane_shd_cnt[lane_idx] + overwrite_head_eval_lane_shd_q[lane_idx];
            ft_drop_lane_hit_cnt_o[lane_idx] <=
              overwrite_scan_lane_hit_cnt[lane_idx] + overwrite_head_eval_lane_hit_q[lane_idx];
          end
          meta_rptr <= overwrite_head_eval_next_ptr_q;
          head_meta_valid <= 1'b0;
          overwrite_scan_active <= 1'b0;
          presenter_state <= FTABLE_PRESENTER_IDLE;
          output_data_valid <= '0;
          pkt_rd_word_cnt <= '0;
          retire_pending <= 1'b0;
          pkt_accept_started <= 1'b0;
          page_ram_prime_pending <= 1'b0;
          page_ram_prime_drain_q <= 1'b0;
          page_ram_skid_count <= '0;
          page_ram_lookahead_valid <= 1'b0;
          page_ram_lookahead_pending_valid <= 1'b0;
          for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
            output_data_pipe[pipe_data_idx] <= '0;
          end
        end else begin
          overwrite_scan_hdr_cnt <= overwrite_scan_hdr_cnt + 32'd1;
          overwrite_scan_shd_cnt <= overwrite_scan_shd_cnt + extend32_shd(overwrite_head_eval_shd_q);
          overwrite_scan_hit_cnt <= overwrite_scan_hit_cnt + extend32_hit(overwrite_head_eval_hit_q);
          for (int lane_idx = 0; lane_idx < N_LANE; lane_idx++) begin
            overwrite_scan_lane_shd_cnt[lane_idx] <=
              overwrite_scan_lane_shd_cnt[lane_idx] + overwrite_head_eval_lane_shd_q[lane_idx];
            overwrite_scan_lane_hit_cnt[lane_idx] <=
              overwrite_scan_lane_hit_cnt[lane_idx] + overwrite_head_eval_lane_hit_q[lane_idx];
          end
          overwrite_scan_remaining_words <=
            overwrite_scan_remaining_words - overwrite_head_eval_len_q;
          overwrite_scan_next_ptr <= overwrite_head_eval_next_ptr_q;
          meta_rd_addr <= overwrite_head_eval_next_ptr_q;
          meta_read_pending <= 1'b1;
          meta_read_armed <= 1'b0;
          meta_read_owner <= META_READ_SCAN;
        end
      end

      if (pending_overlap_launch_valid) begin
        pending_overlap_launch_valid <= 1'b0;
        overwrite_scan_active <= 1'b1;
        overwrite_scan_process_head <= 1'b1;
        overwrite_scan_stop_ptr <= pending_overlap_launch_stop_ptr_q;
        overwrite_scan_next_ptr <= meta_rptr;
        overwrite_scan_remaining_words <= pending_overlap_launch_remaining_words_q;
        overwrite_scan_hdr_cnt <= '0;
        overwrite_scan_shd_cnt <= '0;
        overwrite_scan_hit_cnt <= '0;
        for (int lane_clear_idx = 0; lane_clear_idx < N_LANE; lane_clear_idx = lane_clear_idx + 1) begin
          overwrite_scan_lane_shd_cnt[lane_clear_idx] <= '0;
          overwrite_scan_lane_hit_cnt[lane_clear_idx] <= '0;
        end
        block_present_start_v = 1'b1;
      end

      if (pending_overlap_head_eval_valid_q) begin
        pending_overlap_head_eval_valid_q <= 1'b0;
        if (pending_overlap_head_eval_overlaps_q) begin
          pending_overlap_launch_valid <= 1'b1;
          pending_overlap_launch_addr_q <= pending_overlap_head_eval_addr_q;
          pending_overlap_launch_len_q <= pending_overlap_head_eval_len_q;
          pending_overlap_launch_stop_ptr_q <= pending_overlap_head_eval_stop_ptr_q;
          pending_overlap_launch_remaining_words_q <= pending_overlap_head_eval_remaining_words_q;
          block_present_start_v = 1'b1;
        end
      end

      if (!pending_overlap_check_valid &&
          !pending_overlap_launch_valid &&
          !pending_overlap_head_eval_valid_q &&
          !overwrite_scan_active &&
          !overwrite_scan_process_head &&
          (overlap_req_count != '0)) begin
        pending_overlap_check_valid <= 1'b1;
        pending_overlap_addr_q <= overlap_req_addr_q[overlap_req_rptr];
        pending_overlap_len_q <= overlap_req_len_q[overlap_req_rptr];
        pending_overlap_stop_ptr_q <= overlap_req_stop_ptr_q[overlap_req_rptr];
        overlap_req_rptr <= overlap_req_rptr + OVERLAP_REQ_PTR_WIDTH'(1);
        overlap_req_count <= overlap_req_count - OVERLAP_REQ_COUNT_WIDTH'(1);
        block_present_start_v = 1'b1;
      end

      if (!overwrite_scan_active &&
          !pending_overlap_head_eval_valid_q &&
          !pending_overlap_launch_valid &&
          pending_overlap_check_valid &&
          head_meta_valid &&
          !overwrite_head_accepted_or_accepting) begin
        pending_overlap_check_valid <= 1'b0;
        // A queued overlap request only needs to scan metadata older than the
        // frame that created it. Once that request's stop pointer has become
        // the current head, the request has caught up to itself and must be
        // discarded instead of launching a self-overlap scan that walks one
        // slot past the valid queue.
        if (pending_overlap_stop_ptr_q != meta_rptr) begin
          launch_head_overlaps_v = circular_range_overlaps(
            pending_overlap_addr_q,
            pending_overlap_len_q,
            head_addr_q,
            head_len_q
          );
          remaining_words_v = pending_overlap_len_q;
          pending_overlap_head_eval_valid_q <= 1'b1;
          pending_overlap_head_eval_overlaps_q <= launch_head_overlaps_v;
          pending_overlap_head_eval_addr_q <= pending_overlap_addr_q;
          pending_overlap_head_eval_len_q <= pending_overlap_len_q;
          pending_overlap_head_eval_stop_ptr_q <= pending_overlap_stop_ptr_q;
          pending_overlap_head_eval_remaining_words_q <= remaining_words_v;
          block_present_start_v = 1'b1;
        end
      end

      unique case (presenter_state)
        FTABLE_PRESENTER_IDLE: begin
          // Always enter WAIT when metadata is queued. Overlap/drop
          // bookkeeping may still be busy, but WAIT is the state that fetches
          // the next head and drains those blockers; keeping the same blocker
          // on the IDLE->WAIT hop deadlocks the queue once overlap checks are
          // pending.
          if (is_new_pkt_head) begin
            presenter_state <= FTABLE_PRESENTER_WAIT_FOR_COMPLETE;
            pkt_accept_started <= 1'b0;
            page_ram_skid_count <= '0;
            page_ram_rsp_valid_pipe <= '0;
          end
        end

        FTABLE_PRESENTER_WAIT_FOR_COMPLETE: begin
          if (!is_new_pkt_head) begin
            presenter_state <= FTABLE_PRESENTER_IDLE;
          end else if (!head_meta_valid && !meta_read_pending && !block_meta_head_fetch_v) begin
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
            if ($test$plusargs("OPQ_NATIVE_TRACE_OWNERSHIP")) begin
              $display(
                "[opq_native_meta] t=%0t evt=req_head slot=0x%0h",
                $time,
                meta_rptr
              );
            end
`endif
`endif
            meta_rd_addr <= meta_rptr;
            meta_read_pending <= 1'b1;
            meta_read_armed <= 1'b0;
            meta_read_owner <= META_READ_HEAD;
          end else if (head_meta_valid &&
                       payload_commit_idle_i &&
                       aso_egress_ready &&
                       !block_present_start_v) begin
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
            if ($test$plusargs("OPQ_NATIVE_TRACE_OWNERSHIP")) begin
              $display(
                "[opq_native_scan] t=%0t evt=present_start meta_rptr=0x%0h head_addr=0x%0h head_len=0x%0h head_shd=%0d head_hit=%0d",
                $time,
                meta_rptr,
                head_addr_q,
                head_len_q,
                head_shd_cnt_q,
                head_hit_cnt_q
              );
            end
`endif
`endif
            presenter_state <= FTABLE_PRESENTER_PRESENTING;
            pkt_fetch_word_cnt <= '0;
            pkt_rd_word_cnt <= '0;
            output_data_valid <= '0;
            retire_pending <= 1'b0;
            pkt_accept_started <= 1'b0;
            // The page RAM read data is registered. In the common case we repoint
            // q to the new packet head and burn one quiet prime cycle. If the
            // previous packet exposed the next packet preamble on q while its own
            // tail was draining, preserve that lookahead word and seed startup
            // from a local hold register instead of letting q roll past it.
            if ((page_ram_lookahead_valid && (page_ram_lookahead_addr == head_addr_q)) ||
                (page_ram_lookahead_pending_valid &&
                 (page_ram_lookahead_pending_addr == head_addr_q) &&
                 (page_ram_lookahead_pending_data[35:32] == 4'b0001) &&
                 (page_ram_lookahead_pending_data[7:0] == K285))) begin
              page_ram_rptr <= head_addr_q + PAGE_RAM_ADDR_ONE_CONST;
              page_ram_prime_pending <= 1'b0;
              page_ram_prime_drain_q <= 1'b0;
              if (page_ram_lookahead_valid && (page_ram_lookahead_addr == head_addr_q)) begin
                page_ram_rd_data_skid[0] <= page_ram_lookahead_data;
              end else begin
                page_ram_rd_data_skid[0] <= page_ram_lookahead_pending_data;
              end
              page_ram_skid_count <= PAGE_RAM_SKID_COUNT_WIDTH'(1);
              page_ram_rsp_valid_pipe <= '0;
              page_ram_lookahead_valid <= 1'b0;
              page_ram_lookahead_pending_valid <= 1'b0;
            end else begin
              page_ram_rptr <= head_addr_q;
              page_ram_prime_pending <= 1'b1;
              page_ram_prime_drain_q <= 1'b1;
              page_ram_skid_count <= '0;
              page_ram_rsp_valid_pipe <= '0;
              page_ram_lookahead_valid <= 1'b0;
              page_ram_lookahead_pending_valid <= 1'b0;
            end
            for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
              output_data_pipe[pipe_data_idx] <= '0;
            end
          end
        end

        FTABLE_PRESENTER_PRESENTING: begin
          if (page_ram_prime_pending) begin
            // The page RAM read is synchronous and then registered once at the
            // native presenter boundary. Burn two quiet cycles: the first
            // requests the next resident word, the second lets the boundary
            // register expose the head word to this presenter. Advance the RAM
            // pointer in both quiet cycles so the registered data stream is
            // already one word ahead when the output pipe starts.
            page_ram_rptr <= page_ram_rptr + PAGE_RAM_ADDR_ONE_CONST;
            if (page_ram_prime_drain_q) begin
              page_ram_prime_drain_q <= 1'b0;
            end else begin
              page_ram_prime_pending <= 1'b0;
            end
          end

          if (!page_ram_lookahead_valid &&
              !page_ram_lookahead_pending_valid &&
              (pkt_fetch_word_cnt == packet_length) &&
              (meta_wptr != (meta_rptr + META_PTR_ONE_CONST))) begin
            page_ram_lookahead_pending_data <= page_ram_rd_data_i;
            page_ram_lookahead_pending_addr <= page_ram_rptr;
            page_ram_lookahead_pending_valid <= 1'b1;
          end

          if (output_data_valid[OUTPUT_VISIBLE_STAGE] && !aso_egress_ready) begin
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
            if (opq_native_trace_egress_en && ($time >= opq_native_trace_egress_after_ps)) begin
              $display(
                "[opq_native_egress] t=%0t evt=stall meta_rptr=0x%0h page_rptr=0x%0h rd=%0d fetch=%0d valid_pipe=0x%0h q=0x%010h skid_valid=%0b skid=0x%010h retire=%0b",
                $time,
                meta_rptr,
                page_ram_rptr,
                pkt_rd_word_cnt,
                pkt_fetch_word_cnt,
                output_data_valid,
                page_ram_rd_data_i,
                page_ram_skid_valid,
                page_ram_rd_data_skid[0],
                retire_pending
              );
            end
`endif
`endif
          end

          if (final_output_accept_v) begin
            presenter_state <= FTABLE_PRESENTER_IDLE;
            output_data_valid <= '0;
            meta_rptr <= meta_rptr + META_PTR_ONE_CONST;
            head_meta_valid <= 1'b0;
            pkt_fetch_word_cnt <= '0;
            pkt_rd_word_cnt <= '0;
            retire_pending <= 1'b0;
            pkt_accept_started <= 1'b0;
            page_ram_prime_pending <= 1'b0;
            page_ram_prime_drain_q <= 1'b0;
            page_ram_skid_count <= '0;
            page_ram_rsp_valid_pipe <= '0;
            for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY; pipe_data_idx = pipe_data_idx + 1) begin
              output_data_pipe[pipe_data_idx] <= '0;
            end
          end else begin
            if (output_accept_v) begin
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
              if (opq_native_trace_egress_en && ($time >= opq_native_trace_egress_after_ps)) begin
                $display(
                  "[opq_native_egress] t=%0t evt=accept meta_rptr=0x%0h page_rptr=0x%0h rd=%0d fetch=%0d data=0x%010h sop=%0b eop=%0b retire=%0b skid_valid=%0b",
                  $time,
                  meta_rptr,
                  page_ram_rptr,
                  pkt_rd_word_cnt,
                  pkt_fetch_word_cnt,
                  output_data,
                  aso_egress_startofpacket,
                  aso_egress_endofpacket,
                  retire_pending,
                  page_ram_skid_valid
                );
              end
`endif
`endif
              pkt_rd_word_cnt <= pkt_rd_word_cnt + PAGE_RAM_ADDR_ONE_CONST;
              pkt_accept_started <= 1'b1;
            end

            if (advance_output_pipe) begin
              output_data_valid[0] <= stage0_load_valid_v;
              for (pipe_valid_idx = 0; pipe_valid_idx < (EGRESS_DELAY-1); pipe_valid_idx = pipe_valid_idx + 1) begin
                output_data_valid[pipe_valid_idx+1] <= output_data_valid[pipe_valid_idx];
              end
              output_data_pipe[0] <= pipe_input_data;
              for (pipe_data_idx = 0; pipe_data_idx < EGRESS_DELAY-1; pipe_data_idx = pipe_data_idx + 1) begin
                output_data_pipe[pipe_data_idx+1] <= output_data_pipe[pipe_data_idx];
              end
              if (stage0_load_valid_v) begin
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
                if (opq_native_trace_egress_en && ($time >= opq_native_trace_egress_after_ps)) begin
                  $display(
                    "[opq_native_egress] t=%0t evt=load meta_rptr=0x%0h page_rptr=0x%0h rd=%0d fetch=%0d load=0x%010h skid_valid=%0b retire=%0b",
                    $time,
                    meta_rptr,
                    page_ram_rptr,
                    pkt_rd_word_cnt,
                    pkt_fetch_word_cnt,
                    pipe_input_data,
                    page_ram_skid_valid,
                    retire_pending
                  );
                end
`endif
`endif
                page_ram_rptr <= page_ram_rptr + PAGE_RAM_ADDR_ONE_CONST;
                pkt_fetch_word_cnt <= pkt_fetch_word_cnt + PAGE_RAM_ADDR_ONE_CONST;
              end

              if (launch_is_trailer) begin
                output_data_valid <= '0;
                output_data_valid[OUTPUT_VISIBLE_STAGE] <= 1'b1;
                retire_pending <= 1'b1;
              end
            end

            if (page_ram_skid_pop_v || page_ram_skid_push_v) begin
              if (page_ram_skid_pop_v) begin
                for (skid_idx = 0; skid_idx < (PAGE_RAM_SKID_DEPTH-1); skid_idx = skid_idx + 1) begin
                  page_ram_rd_data_skid[skid_idx] <= page_ram_rd_data_skid[skid_idx+1];
                end
                page_ram_rd_data_skid[PAGE_RAM_SKID_DEPTH-1] <= '0;
              end

              if (page_ram_skid_push_v) begin
                if (page_ram_skid_pop_v) begin
                  page_ram_rd_data_skid[page_ram_skid_count - PAGE_RAM_SKID_COUNT_WIDTH'(1)] <= page_ram_rd_data_i;
                end else begin
                  page_ram_rd_data_skid[page_ram_skid_count] <= page_ram_rd_data_i;
                end
              end

              if (page_ram_skid_push_v && !page_ram_skid_pop_v) begin
                page_ram_skid_count <= page_ram_skid_count + PAGE_RAM_SKID_COUNT_WIDTH'(1);
              end else if (page_ram_skid_pop_v && !page_ram_skid_push_v) begin
                page_ram_skid_count <= page_ram_skid_count - PAGE_RAM_SKID_COUNT_WIDTH'(1);
              end
            end
          end
        end

        FTABLE_PRESENTER_RESET: begin
          presenter_state <= FTABLE_PRESENTER_IDLE;
          pkt_accept_started <= 1'b0;
          page_ram_prime_pending <= 1'b0;
          page_ram_prime_drain_q <= 1'b0;
          page_ram_lookahead_valid <= 1'b0;
          page_ram_lookahead_pending_valid <= 1'b0;
        end

        default: begin
        end
      endcase
    end
  end

`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
  property p_retire_waits_for_consumed_trailer;
    @(posedge d_clk) disable iff (d_reset)
      retire_pending &&
      aso_egress_valid &&
      aso_egress_ready &&
      !aso_egress_endofpacket |=> (presenter_state == FTABLE_PRESENTER_PRESENTING);
  endproperty
  ap_retire_waits_for_consumed_trailer: assert property (p_retire_waits_for_consumed_trailer)
    else $error("OPQ_NATIVE_BASIC_PRESENTER consumed a non-trailer beat after retire_pending and still retired early");

  property p_retire_only_exposes_trailer;
    @(posedge d_clk) disable iff (d_reset)
      retire_pending && aso_egress_valid |-> output_is_trailer && aso_egress_endofpacket;
  endproperty
  ap_retire_only_exposes_trailer: assert property (p_retire_only_exposes_trailer)
    else $error("OPQ_NATIVE_BASIC_PRESENTER exposed a non-trailer beat while retire_pending was asserted");

  property p_prime_cycle_stays_quiet;
    @(posedge d_clk) disable iff (d_reset)
      page_ram_prime_pending |=> !aso_egress_valid &&
                                (output_data_valid == $past(output_data_valid)) &&
                                (pkt_fetch_word_cnt == $past(pkt_fetch_word_cnt)) &&
                                (pkt_rd_word_cnt == $past(pkt_rd_word_cnt));
  endproperty
  ap_prime_cycle_stays_quiet: assert property (p_prime_cycle_stays_quiet)
    else $error("OPQ_NATIVE_BASIC_PRESENTER exposed or consumed data while the new head was still priming");

  property p_startup_backpressure_captures_head;
    @(posedge d_clk) disable iff (d_reset)
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      !page_ram_prime_pending &&
      !pkt_accept_started &&
      !aso_egress_ready &&
      !page_ram_skid_valid &&
      page_ram_rsp_valid_pipe[PAGE_RAM_RSP_LATENCY-1] &&
      (pkt_fetch_word_cnt != packet_length) |=> page_ram_skid_valid;
  endproperty
  ap_startup_backpressure_captures_head: assert property (p_startup_backpressure_captures_head)
    else $error("OPQ_NATIVE_BASIC_PRESENTER lost the primed head word before the first launch under startup backpressure");

  property p_tail_lookahead_preamble_is_buffered;
    @(posedge d_clk) disable iff (d_reset)
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      !page_ram_lookahead_valid &&
      !page_ram_lookahead_pending_valid &&
      (pkt_fetch_word_cnt == packet_length) &&
      (meta_wptr != (meta_rptr + META_PTR_ONE_CONST)) &&
      (page_ram_rd_data_i[35:32] == 4'b0001) &&
      (page_ram_rd_data_i[7:0] == K285)
      |=> (page_ram_lookahead_valid || page_ram_lookahead_pending_valid);
  endproperty
  ap_tail_lookahead_preamble_is_buffered: assert property (p_tail_lookahead_preamble_is_buffered)
    else $error("OPQ_NATIVE_BASIC_PRESENTER let a queued next-packet preamble roll off page_ram.q without buffering it for restart");

  property p_stalled_resident_word_is_preserved;
    @(posedge d_clk) disable iff (d_reset)
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      !advance_output_pipe &&
      !retire_pending &&
      !page_ram_prime_pending &&
      !page_ram_skid_valid &&
      page_ram_rsp_valid_pipe[PAGE_RAM_RSP_LATENCY-1] &&
      (pkt_fetch_word_cnt != packet_length) |=> page_ram_skid_valid;
  endproperty
  ap_stalled_resident_word_is_preserved: assert property (p_stalled_resident_word_is_preserved)
    else $error("OPQ_NATIVE_BASIC_PRESENTER let page_ram.q roll past an unread resident word while the pipe was stalled");

  property p_first_visible_word_is_sop;
    @(posedge d_clk) disable iff (d_reset)
      (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
      !pkt_accept_started &&
      aso_egress_valid |-> aso_egress_startofpacket;
  endproperty
  ap_first_visible_word_is_sop: assert property (p_first_visible_word_is_sop)
    else $error("OPQ_NATIVE_BASIC_PRESENTER exposed a non-SOP beat before the first packet acceptance");

  property p_idle_with_queued_head_enters_wait;
    @(posedge d_clk) disable iff (d_reset)
      (presenter_state == FTABLE_PRESENTER_IDLE) && is_new_pkt_head |=> (presenter_state == FTABLE_PRESENTER_WAIT_FOR_COMPLETE);
  endproperty
  ap_idle_with_queued_head_enters_wait: assert property (p_idle_with_queued_head_enters_wait)
    else $error("OPQ_NATIVE_BASIC_PRESENTER stranded queued metadata in IDLE instead of entering WAIT_FOR_COMPLETE");

  property p_scan_eval_launches_followup_read;
    @(posedge d_clk) disable iff (d_reset)
      scan_eval_valid_q &&
      scan_eval_overlaps_q &&
      (scan_eval_next_ptr_q != overwrite_scan_stop_ptr)
      |=> meta_read_pending &&
          (meta_read_owner == META_READ_SCAN) &&
          (meta_rd_addr == scan_eval_next_ptr_q);
  endproperty
  ap_scan_eval_launches_followup_read: assert property (p_scan_eval_launches_followup_read)
    else $error("OPQ_NATIVE_BASIC_PRESENTER scan-eval stage did not launch the next overlap read from the registered pointer");

  property p_scan_eval_stop_keeps_head_registered;
    @(posedge d_clk) disable iff (d_reset)
      scan_eval_valid_q && !scan_eval_overlaps_q
      |=> head_meta_valid &&
          (head_addr_q == $past(scan_eval_addr_q)) &&
          (head_len_q == $past(scan_eval_len_q));
  endproperty
  ap_scan_eval_stop_keeps_head_registered: assert property (p_scan_eval_stop_keeps_head_registered)
    else $error("OPQ_NATIVE_BASIC_PRESENTER scan-eval stop path did not keep the registered head metadata");

  property p_self_overlap_request_is_discarded;
    @(posedge d_clk) disable iff (d_reset)
      pending_overlap_check_valid &&
      head_meta_valid &&
      !overwrite_head_accepted_or_accepting &&
      (pending_overlap_stop_ptr_q == meta_rptr)
      |=> !pending_overlap_launch_valid &&
          !overwrite_scan_active &&
          !overwrite_scan_process_head &&
          head_meta_valid &&
          (head_addr_q == $past(head_addr_q)) &&
          (head_len_q == $past(head_len_q));
  endproperty
  ap_self_overlap_request_is_discarded: assert property (p_self_overlap_request_is_discarded)
    else $error("OPQ_NATIVE_BASIC_PRESENTER launched or mutated head state for an overlap request that had already caught up to its own head slot");

`ifndef SYNTHESIS
  cover property (@(posedge d_clk) disable iff (d_reset)
    presenter_state == FTABLE_PRESENTER_PRESENTING
    ##[1:64] retire_pending
    ##[1:32] aso_egress_valid && !aso_egress_ready
    ##[1:32] aso_egress_valid && aso_egress_ready && aso_egress_endofpacket
  );

  cover property (@(posedge d_clk) disable iff (d_reset)
    page_ram_prime_pending
    ##1 !page_ram_prime_pending
    ##[1:EGRESS_DELAY+2] aso_egress_valid && aso_egress_startofpacket && aso_egress_ready
  );

  cover property (@(posedge d_clk) disable iff (d_reset)
    (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
    !page_ram_prime_pending &&
    !pkt_accept_started &&
    !aso_egress_ready &&
    !page_ram_skid_valid &&
    page_ram_rsp_valid_pipe[PAGE_RAM_RSP_LATENCY-1] &&
    (pkt_fetch_word_cnt != packet_length)
    ##1 page_ram_skid_valid
    ##[1:EGRESS_DELAY+4] aso_egress_valid && aso_egress_startofpacket && aso_egress_ready
  );

  cover property (@(posedge d_clk) disable iff (d_reset)
    (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
    !page_ram_lookahead_valid &&
    !page_ram_lookahead_pending_valid &&
    (pkt_fetch_word_cnt == packet_length) &&
    (meta_wptr != (meta_rptr + META_PTR_ONE_CONST)) &&
    (page_ram_rd_data_i[35:32] == 4'b0001) &&
    (page_ram_rd_data_i[7:0] == K285)
    ##1 (page_ram_lookahead_valid || page_ram_lookahead_pending_valid)
    ##[1:64] presenter_state == FTABLE_PRESENTER_WAIT_FOR_COMPLETE
    ##[1:8] presenter_state == FTABLE_PRESENTER_PRESENTING && page_ram_skid_valid
    ##[1:EGRESS_DELAY+4] aso_egress_valid && aso_egress_startofpacket && aso_egress_ready
  );

  cover property (@(posedge d_clk) disable iff (d_reset)
    (presenter_state == FTABLE_PRESENTER_PRESENTING) &&
    !advance_output_pipe &&
    !retire_pending &&
    !page_ram_prime_pending &&
    !page_ram_skid_valid &&
    page_ram_rsp_valid_pipe[PAGE_RAM_RSP_LATENCY-1] &&
    (pkt_fetch_word_cnt != packet_length)
    ##1 page_ram_skid_valid
    ##[1:EGRESS_DELAY+4] aso_egress_valid && aso_egress_ready
  );

  cover property (@(posedge d_clk) disable iff (d_reset)
    pending_overlap_check_valid &&
    head_meta_valid &&
    !overwrite_head_accepted_or_accepting &&
    (pending_overlap_stop_ptr_q == meta_rptr)
    ##1 !pending_overlap_launch_valid &&
        !overwrite_scan_active &&
        !overwrite_scan_process_head
  );

  cover property (@(posedge d_clk) disable iff (d_reset)
    (presenter_state == FTABLE_PRESENTER_IDLE) &&
    is_new_pkt_head &&
    (pending_overlap_check_valid || pending_overlap_launch_valid || overwrite_scan_active || overwrite_scan_process_head)
    ##1 (presenter_state == FTABLE_PRESENTER_WAIT_FOR_COMPLETE)
  );

  cover property (@(posedge d_clk) disable iff (d_reset)
    scan_eval_valid_q &&
    scan_eval_overlaps_q &&
    (scan_eval_next_ptr_q != overwrite_scan_stop_ptr)
    ##1 meta_read_pending &&
        (meta_read_owner == META_READ_SCAN)
  );

`endif
`endif
`endif

endmodule
