//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_ingress_parser
// Version : 26.5.1
// Date    : 20260517
// Change  : Include same-cycle returned lane/ticket credit in ingress drop
//           decisions for consecutive valid Mu3e frame beats.
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_ingress_parser #(
  parameter int unsigned INGRESS_DATA_WIDTH = 32,
  parameter int unsigned INGRESS_DATAK_WIDTH = 4,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned LANE_FIFO_WIDTH = 40,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HIT_SIZE = 1,
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
  parameter int unsigned LANE_FIFO_MAX_CREDIT = LANE_FIFO_DEPTH - 2
) (
  input  logic [INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0] asi_ingress_data,
  input  logic                                              asi_ingress_valid,
  input  logic                                              asi_ingress_startofpacket,
  input  logic                                              asi_ingress_endofpacket,
  input  logic [2:0]                                        asi_ingress_error,
  input  logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_credit_update,
  input  logic                                              lane_credit_update_valid,
  input  logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_credit_update,
  input  logic                                              ticket_credit_update_valid,
  output logic [TICKET_FIFO_DATA_WIDTH-1:0]                 ticket_wdata,
  output logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_waddr,
  output logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_wptr,
  output logic                                              ticket_we,
  output logic [LANE_FIFO_WIDTH-1:0]                        lane_wdata,
  output logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_waddr,
  output logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_wptr,
  output logic                                              lane_we,
  output logic [47:0]                                       running_ts_dbg,
  output logic [47:0]                                       frame_ts_base_dbg,
  output logic [FRAME_SERIAL_SIZE-1:0]                      pkg_cnt_dbg,
  output logic [5:0]                                        dt_type_dbg,
  output logic [15:0]                                       feb_id_dbg,
  output logic                                              parser_busy_o,
  output logic                                              parser_idle_dbg_o,
  output logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_credit_dbg_o,
  output logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_credit_dbg_o,
`ifdef OPQ_OSS_FORMAL
  output logic [LANE_FIFO_ADDR_WIDTH-1:0]                   lane_credit_dbg_oss,
  output logic [TICKET_FIFO_ADDR_WIDTH-1:0]                 ticket_credit_dbg_oss,
  output logic [MAX_PKT_LENGTH_BITS-1:0]                    shd_len_dbg_oss,
  output logic [2:0]                                        ingress_state_dbg_oss,
  output logic                                              lane_issue_dbg_oss,
  output logic                                              ticket_issue_dbg_oss,
  output logic                                              credit_drop_lane_decision_dbg_oss,
  output logic                                              credit_drop_ticket_decision_dbg_oss,
`endif
  output logic                                              credit_drop_valid_o,
  output logic                                              credit_drop_lane_o,
  output logic                                              credit_drop_ticket_o,
  output logic [FRAME_SERIAL_SIZE-1:0]                      credit_drop_pkg_cnt_o,
  output logic [47:0]                                       credit_drop_ts_o,
  output logic [15:0]                                       credit_drop_shd_cnt_o,
  output logic [15:0]                                       credit_drop_hit_cnt_o,
  output logic                                              tail_bypass_valid_o,
  output logic                                              tail_bypass_drop_o,
  output logic [FRAME_SERIAL_SIZE-1:0]                      tail_bypass_serial_o,
  output logic [47:0]                                       tail_bypass_ts_o,
  output logic                                              alert_eop_state_o,
  input  logic                                              eop_flush_ack_i,
  input  logic                                              d_clk,
  input  logic                                              d_reset
);
  localparam logic [7:0] K285 = 8'hBC;
  localparam logic [7:0] K284 = 8'h9C;
  localparam logic [7:0] K237 = 8'hF7;
  localparam int unsigned SUBHEADER_HIT_LO = 8;
  localparam int unsigned SUBHEADER_HIT_HI = 23;

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

  typedef logic [LANE_FIFO_ADDR_WIDTH-1:0] lane_fifo_addr_t;
  typedef logic [TICKET_FIFO_ADDR_WIDTH-1:0] ticket_fifo_addr_t;
  typedef logic [MAX_PKT_LENGTH_BITS-1:0] pkt_length_t;
  localparam lane_fifo_addr_t LANE_FIFO_ADDR_ONE_CONST = {{(LANE_FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam ticket_fifo_addr_t TICKET_FIFO_ADDR_ONE_CONST = {{(TICKET_FIFO_ADDR_WIDTH-1){1'b0}}, 1'b1};
  localparam lane_fifo_addr_t LANE_FIFO_MAX_CREDIT_CONST = LANE_FIFO_MAX_CREDIT;
  localparam ticket_fifo_addr_t TICKET_FIFO_MAX_CREDIT_CONST = TICKET_FIFO_MAX_CREDIT;

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

  typedef enum logic [2:0] {
    INGRESS_PARSER_IDLE,
    INGRESS_PARSER_UPDATE_HEADER_TS,
    INGRESS_PARSER_MASK_PKT_EXTENDED,
    INGRESS_PARSER_MASK_PKT,
    INGRESS_PARSER_DROP_OVERLIMIT,
    INGRESS_PARSER_WR_HITS,
    INGRESS_PARSER_RESET
  } ingress_parser_state_t;

  typedef logic [1:0] update_header_ts_flow_t;

  typedef struct packed {
    logic                  lane_we;
    lane_fifo_addr_t       lane_wptr;
    lane_fifo_addr_t       lane_waddr;
    logic [LANE_FIFO_WIDTH-1:0] lane_wdata;
    lane_fifo_addr_t       lane_credit;
    logic                  ticket_we;
    ticket_fifo_addr_t     ticket_wptr;
    ticket_fifo_addr_t     ticket_waddr;
    logic [TICKET_FIFO_DATA_WIDTH-1:0] ticket_wdata;
    ticket_fifo_addr_t     ticket_credit;
    logic [47:0]           running_ts;
    logic [47:0]           frame_ts_base;
    pkt_length_t           shd_len;
    pkt_length_t           shd_decl_len;
    pkt_length_t           shd_seen_cnt;
    logic [15:0]           shd_pre_drop_remaining;
    logic [5:0]            dt_type;
    logic [15:0]           feb_id;
    lane_fifo_addr_t       lane_start_addr;
    logic [15:0]           pkg_cnt;
    logic [15:0]           running_shd_cnt;
    logic [15:0]           hit_cnt;
    logic [30:0]           send_ts;
    logic                  alert_sop;
    logic                  alert_eop;
    logic                  error_lane_wr_early_term;
  } ingress_parser_reg_t;

  ingress_parser_state_t ingress_parser_state;
  update_header_ts_flow_t update_header_ts_flow;
  ingress_parser_reg_t ingress_parser;

  logic ingress_parser_is_subheader;
  logic ingress_parser_is_preamble;
  logic ingress_parser_is_trailer;
  logic ingress_parser_hit_err;
  logic ingress_parser_shd_err;
  logic ingress_parser_hdr_err;
  logic [47:0] ingress_parser_if_current_subheader_ts;
  logic [15:0] ingress_parser_if_subheader_hit_cnt_raw;
  logic [MAX_PKT_LENGTH_BITS-1:0] ingress_parser_if_subheader_hit_cnt;
  logic [15:0] ingress_parser_if_subheader_overlimit_drop_cnt;
  logic ingress_parser_if_subheader_overlimit;
  logic [7:0] ingress_parser_if_subheader_shd_ts;
  logic [5:0] ingress_parser_if_preamble_dt_type;
  logic [15:0] ingress_parser_if_preamble_feb_id;
  logic [TICKET_FIFO_DATA_WIDTH-1:0] ingress_parser_if_write_ticket_data;
  logic [LANE_FIFO_WIDTH-1:0] ingress_parser_if_write_lane_data;

  function automatic logic [47:0] ingress_parser_extend_subheader_ts(
    input logic [47:0] last_running_ts,
    input logic [15:0] last_subheader_count,
    input logic [7:0]  curr_subheader_byte
  );
    logic [47:0] ts_v;
    begin
      ts_v = {last_running_ts[47:12], curr_subheader_byte, 4'b0000};
      if ((last_subheader_count != '0) && (curr_subheader_byte < last_running_ts[11:4])) begin
        ts_v[47:12] = last_running_ts[47:12] + 36'd1;
      end
      ingress_parser_extend_subheader_ts = ts_v;
    end
  endfunction

  always_comb begin : proc_ingress_parser_comb
    pkt_length_t wr_hits_block_len_v;

    ingress_parser_is_subheader = (asi_ingress_data[7:0] == K237) && (asi_ingress_data[35:32] == 4'b0001);
    ingress_parser_is_preamble = (asi_ingress_data[7:0] == K285) && (asi_ingress_data[35:32] == 4'b0001);
    ingress_parser_is_trailer = (asi_ingress_data[7:0] == K284) && (asi_ingress_data[35:32] == 4'b0001);

    ingress_parser_hit_err = asi_ingress_error[0];
    ingress_parser_shd_err = asi_ingress_error[1];
    ingress_parser_hdr_err = asi_ingress_error[2];

    ingress_parser_if_current_subheader_ts = ingress_parser_extend_subheader_ts(
      ingress_parser.running_ts,
      ingress_parser.running_shd_cnt,
      asi_ingress_data[31:24]
    );
    ingress_parser_if_subheader_hit_cnt_raw = asi_ingress_data[SUBHEADER_HIT_HI:SUBHEADER_HIT_LO];
    ingress_parser_if_subheader_overlimit =
      int'(ingress_parser_if_subheader_hit_cnt_raw) > int'(MAX_PKT_LENGTH);
    if (ingress_parser_if_subheader_overlimit) begin
      ingress_parser_if_subheader_hit_cnt = pkt_length_t'(MAX_PKT_LENGTH);
      ingress_parser_if_subheader_overlimit_drop_cnt =
        ingress_parser_if_subheader_hit_cnt_raw - 16'(MAX_PKT_LENGTH);
    end else begin
      ingress_parser_if_subheader_hit_cnt = pkt_length_t'(ingress_parser_if_subheader_hit_cnt_raw);
      ingress_parser_if_subheader_overlimit_drop_cnt = '0;
    end
    ingress_parser_if_subheader_shd_ts = asi_ingress_data[31:24];
    ingress_parser_if_preamble_dt_type = asi_ingress_data[31:26];
    ingress_parser_if_preamble_feb_id = asi_ingress_data[23:8];

    ingress_parser_if_write_ticket_data = '0;
    wr_hits_block_len_v = ingress_parser.shd_len;
    if ((ingress_parser_state == INGRESS_PARSER_WR_HITS) &&
        asi_ingress_valid &&
        !ingress_parser_hit_err) begin
      wr_hits_block_len_v = ingress_parser.shd_len + pkt_length_t'(1);
    end
    if (ingress_parser_is_subheader) begin
      ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO] = ingress_parser_if_current_subheader_ts;
      ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO] =
        ingress_parser.lane_start_addr;
      ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO] =
        ingress_parser_if_subheader_hit_cnt;
    end else begin
      ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO] = ingress_parser.running_ts;
      ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO] =
        ingress_parser.lane_start_addr;
      ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO] = wr_hits_block_len_v;
    end

    if (!ingress_parser.alert_sop) begin
      ingress_parser_if_write_ticket_data[TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] =
        ingress_parser.pkg_cnt;
    end

    if ((ingress_parser_state == INGRESS_PARSER_UPDATE_HEADER_TS) && (update_header_ts_flow == 2'd3)) begin
      ingress_parser_if_write_ticket_data[TICKET_SERIAL_HI:TICKET_SERIAL_LO] = ingress_parser.pkg_cnt;
      ingress_parser_if_write_ticket_data[TICKET_N_SUBH_HI:TICKET_N_SUBH_LO] = ingress_parser.running_shd_cnt;
      ingress_parser_if_write_ticket_data[TICKET_N_HIT_HI:TICKET_N_HIT_LO] = ingress_parser.hit_cnt;
      ingress_parser_if_write_ticket_data[TICKET_DT_TYPE_HI:TICKET_DT_TYPE_LO] = ingress_parser.dt_type;
      ingress_parser_if_write_ticket_data[TICKET_FEB_ID_HI:TICKET_FEB_ID_LO] = ingress_parser.feb_id;
      ingress_parser_if_write_ticket_data[TICKET_FRAME_TS_HI:TICKET_FRAME_TS_LO] = ingress_parser.frame_ts_base;
    end
    ingress_parser_if_write_ticket_data[TICKET_ALT_EOP_LOC] = ingress_parser.alert_eop;
    ingress_parser_if_write_ticket_data[TICKET_ALT_SOP_LOC] = ingress_parser.alert_sop;

    ingress_parser_if_write_lane_data = '0;
    ingress_parser_if_write_lane_data[35:0] = asi_ingress_data;
    ingress_parser_if_write_lane_data[36] = ingress_parser.ticket_we;
    ingress_parser_if_write_lane_data[38] = asi_ingress_error[0];

    ticket_wdata = ingress_parser.ticket_wdata;
    ticket_waddr = ingress_parser.ticket_waddr;
    ticket_wptr = ingress_parser.ticket_wptr;
    ticket_we = ingress_parser.ticket_we;
    lane_wdata = ingress_parser.lane_wdata;
    lane_waddr = ingress_parser.lane_waddr;
    lane_wptr = ingress_parser.lane_wptr;
    lane_we = ingress_parser.lane_we;
  running_ts_dbg = ingress_parser.running_ts;
  frame_ts_base_dbg = ingress_parser.frame_ts_base;
  pkg_cnt_dbg = ingress_parser.pkg_cnt;
  dt_type_dbg = ingress_parser.dt_type;
    feb_id_dbg = ingress_parser.feb_id;
`ifdef SYNTHESIS
    // Quartus 18.1 can mis-resolve the enum-based state compare through the
    // parent monolithic wrapper. Use the same observable in-flight markers for
    // synthesis-only harnesses and keep the state-based definition in sim/formal.
    parser_busy_o = ingress_parser.alert_sop ||
      ingress_parser.alert_eop ||
      (ingress_parser.running_shd_cnt != '0) ||
      (ingress_parser.hit_cnt != '0) ||
      (ingress_parser.shd_pre_drop_remaining != '0) ||
      lane_we ||
      ticket_we;
`else
    parser_busy_o = (ingress_parser_state != INGRESS_PARSER_IDLE);
`endif
`ifdef SYNTHESIS
    parser_idle_dbg_o = !parser_busy_o;
`else
    parser_idle_dbg_o = (ingress_parser_state == INGRESS_PARSER_IDLE);
`endif
    lane_credit_dbg_o = ingress_parser.lane_credit;
    ticket_credit_dbg_o = ingress_parser.ticket_credit;
`ifdef OPQ_OSS_FORMAL
    lane_credit_dbg_oss = lane_credit_dbg_o;
    ticket_credit_dbg_oss = ticket_credit_dbg_o;
    shd_len_dbg_oss = ingress_parser.shd_len;
    ingress_state_dbg_oss = ingress_parser_state;
`endif
    alert_eop_state_o = ingress_parser.alert_eop;
  end

  always_ff @(posedge d_clk) begin : proc_ingress_parser
    bit hit_consume_v;
    bit hit_accept_v;
    bit hit_last_v;
    bit ticket_credit_available_v;
    int unsigned lane_credit_effective_v;
    pkt_length_t shd_seen_next_v;
    pkt_length_t shd_accept_next_v;

    ingress_parser.lane_we <= 1'b0;
    ingress_parser.ticket_we <= 1'b0;
`ifdef OPQ_OSS_FORMAL
    lane_issue_dbg_oss <= 1'b0;
    ticket_issue_dbg_oss <= 1'b0;
    credit_drop_lane_decision_dbg_oss <= 1'b0;
    credit_drop_ticket_decision_dbg_oss <= 1'b0;
`endif
    credit_drop_valid_o <= 1'b0;
    credit_drop_lane_o <= 1'b0;
    credit_drop_ticket_o <= 1'b0;
    credit_drop_pkg_cnt_o <= '0;
    credit_drop_ts_o <= '0;
    credit_drop_shd_cnt_o <= '0;
    credit_drop_hit_cnt_o <= '0;
    tail_bypass_valid_o <= 1'b0;
    tail_bypass_drop_o <= 1'b0;
    tail_bypass_serial_o <= '0;
    tail_bypass_ts_o <= '0;
    hit_consume_v = asi_ingress_valid;
    hit_accept_v = asi_ingress_valid && !ingress_parser_hit_err;
    shd_seen_next_v = ingress_parser.shd_seen_cnt;
    if (hit_consume_v) begin
      shd_seen_next_v = ingress_parser.shd_seen_cnt + pkt_length_t'(1);
    end
    shd_accept_next_v = ingress_parser.shd_len;
    if (hit_accept_v) begin
      shd_accept_next_v = ingress_parser.shd_len + pkt_length_t'(1);
    end
    hit_last_v =
      hit_consume_v &&
      (shd_seen_next_v == ingress_parser.shd_decl_len);
    ticket_credit_available_v =
      (ingress_parser.ticket_credit != '0) ||
      (ticket_credit_update_valid && (ticket_credit_update != '0));
    lane_credit_effective_v = int'(ingress_parser.lane_credit);
    if (lane_credit_update_valid) begin
      lane_credit_effective_v += int'(lane_credit_update);
    end

    if (lane_credit_update_valid) begin
      ingress_parser.lane_credit <= ingress_parser.lane_credit + lane_credit_update;
    end
    if (ticket_credit_update_valid) begin
      ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update;
    end
    if (eop_flush_ack_i) begin
      ingress_parser.alert_eop <= 1'b0;
    end

    unique case (ingress_parser_state)
      INGRESS_PARSER_IDLE: begin
        if (asi_ingress_valid) begin
          if (ingress_parser_is_subheader && !ingress_parser_shd_err) begin
            ingress_parser.running_ts <= ingress_parser_if_current_subheader_ts;
            ingress_parser.shd_len <= '0;
            ingress_parser.shd_decl_len <= ingress_parser_if_subheader_hit_cnt;
            ingress_parser.shd_seen_cnt <= '0;
            ingress_parser.shd_pre_drop_remaining <= '0;
            if ((ingress_parser_if_subheader_hit_cnt_raw != '0) &&
                (int'(ingress_parser_if_subheader_hit_cnt_raw) >= lane_credit_effective_v)) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_lane_o <= 1'b1;
              credit_drop_pkg_cnt_o <= ingress_parser.pkg_cnt;
              credit_drop_ts_o <= ingress_parser_if_current_subheader_ts;
`ifdef OPQ_OSS_FORMAL
              credit_drop_lane_decision_dbg_oss <= 1'b1;
`endif
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= ingress_parser_if_subheader_hit_cnt_raw;
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (!ticket_credit_available_v) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_ticket_o <= 1'b1;
              credit_drop_pkg_cnt_o <= ingress_parser.pkg_cnt;
              credit_drop_ts_o <= ingress_parser_if_current_subheader_ts;
`ifdef OPQ_OSS_FORMAL
              credit_drop_ticket_decision_dbg_oss <= 1'b1;
`endif
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= ingress_parser_if_subheader_hit_cnt_raw;
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (ingress_parser_if_subheader_hit_cnt_raw != '0) begin
              if (ingress_parser_if_subheader_overlimit) begin
                credit_drop_valid_o <= 1'b1;
                credit_drop_pkg_cnt_o <= ingress_parser.pkg_cnt;
                credit_drop_ts_o <= ingress_parser_if_current_subheader_ts;
                credit_drop_shd_cnt_o <= 16'd0;
                credit_drop_hit_cnt_o <= ingress_parser_if_subheader_overlimit_drop_cnt;
                ingress_parser.shd_pre_drop_remaining <= ingress_parser_if_subheader_overlimit_drop_cnt;
                ingress_parser_state <= INGRESS_PARSER_DROP_OVERLIMIT;
              end else begin
                ingress_parser_state <= INGRESS_PARSER_WR_HITS;
              end
            end else begin
              ingress_parser.ticket_we <= 1'b1;
`ifdef OPQ_OSS_FORMAL
              ticket_issue_dbg_oss <= 1'b1;
`endif
              ingress_parser.ticket_waddr <= ingress_parser.ticket_wptr;
              ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
              ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
              if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
                $display("[opq_boundary] t=%0t parser_ticket_we ts=0x%0h lane_start=0x%0h len=%0d sop=%0b eop=%0b next_ticket_wptr=0x%0h",
                  $time,
                  ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO],
                  ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO],
                  ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO],
                  ingress_parser_if_write_ticket_data[TICKET_ALT_SOP_LOC],
                  ingress_parser_if_write_ticket_data[TICKET_ALT_EOP_LOC],
                  ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST);
              end
`endif
`endif
              if (ticket_credit_update_valid) begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                  TICKET_FIFO_ADDR_ONE_CONST;
              end else begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
              end
            end
          end else if (asi_ingress_startofpacket && ingress_parser_is_preamble && !ingress_parser_hdr_err) begin
            ingress_parser.alert_sop <= 1'b1;
            ingress_parser.dt_type <= ingress_parser_if_preamble_dt_type;
            ingress_parser.feb_id <= ingress_parser_if_preamble_feb_id;
            update_header_ts_flow <= '0;
            ingress_parser_state <= INGRESS_PARSER_UPDATE_HEADER_TS;
          end else if (ingress_parser_is_trailer) begin
            ingress_parser.alert_eop <= 1'b1;
          end

          if (ingress_parser_shd_err) begin
            ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
          end
          if (ingress_parser_hdr_err) begin
            ingress_parser_state <= INGRESS_PARSER_MASK_PKT_EXTENDED;
          end
          if (ingress_parser.error_lane_wr_early_term) begin
            ingress_parser.error_lane_wr_early_term <= 1'b0;
            ingress_parser.lane_wptr <= ingress_parser.lane_start_addr + ingress_parser.shd_len;
          end
        end
      end

      INGRESS_PARSER_UPDATE_HEADER_TS: begin
        if (asi_ingress_valid) begin
          unique case (update_header_ts_flow)
            2'd0: begin
              ingress_parser.running_ts[47:16] <= asi_ingress_data[31:0];
              update_header_ts_flow <= update_header_ts_flow + 2'd1;
            end
            2'd1: begin
              ingress_parser.running_ts[15:0] <= asi_ingress_data[31:16];
              ingress_parser.frame_ts_base <= {ingress_parser.running_ts[47:16], asi_ingress_data[31:16]};
              ingress_parser.pkg_cnt <= asi_ingress_data[15:0];
              update_header_ts_flow <= update_header_ts_flow + 2'd1;
            end
            2'd2: begin
              ingress_parser.running_shd_cnt <= asi_ingress_data[31:16];
              ingress_parser.hit_cnt <= asi_ingress_data[15:0];
              update_header_ts_flow <= update_header_ts_flow + 2'd1;
            end
            2'd3: begin
              ingress_parser.send_ts <= asi_ingress_data[30:0];
              update_header_ts_flow <= '0;
              if (ticket_credit_available_v) begin
                ingress_parser.alert_sop <= 1'b0;
                ingress_parser.ticket_we <= 1'b1;
`ifdef OPQ_OSS_FORMAL
                ticket_issue_dbg_oss <= 1'b1;
`endif
                if (ticket_credit_update_valid) begin
                  ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                    TICKET_FIFO_ADDR_ONE_CONST;
                end else begin
                  ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
                end
                ingress_parser.ticket_waddr <= ingress_parser.ticket_wptr;
                ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
                ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
                if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
                  $display("[opq_boundary] t=%0t parser_ticket_we ts=0x%0h lane_start=0x%0h len=%0d sop=%0b eop=%0b next_ticket_wptr=0x%0h",
                    $time,
                    ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO],
                    ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO],
                    ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO],
                    ingress_parser_if_write_ticket_data[TICKET_ALT_SOP_LOC],
                    ingress_parser_if_write_ticket_data[TICKET_ALT_EOP_LOC],
                    ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST);
                end
`endif
`endif
                ingress_parser_state <= INGRESS_PARSER_IDLE;
              end else begin
                ingress_parser_state <= INGRESS_PARSER_MASK_PKT_EXTENDED;
              end
            end
            default: begin
            end
          endcase

          if (ingress_parser_hdr_err) begin
            ingress_parser_state <= INGRESS_PARSER_MASK_PKT_EXTENDED;
          end
        end
      end

      INGRESS_PARSER_MASK_PKT_EXTENDED: begin
        if (asi_ingress_valid) begin
          if (ingress_parser_is_trailer) begin
            ingress_parser_state <= INGRESS_PARSER_IDLE;
          end else if (ingress_parser_is_preamble && !ingress_parser_hdr_err) begin
            ingress_parser.alert_sop <= 1'b1;
            ingress_parser.dt_type <= ingress_parser_if_preamble_dt_type;
            ingress_parser.feb_id <= ingress_parser_if_preamble_feb_id;
            update_header_ts_flow <= '0;
            ingress_parser_state <= INGRESS_PARSER_UPDATE_HEADER_TS;
          end
        end
      end

      INGRESS_PARSER_MASK_PKT: begin
        if (asi_ingress_valid && asi_ingress_endofpacket) begin
          ingress_parser_state <= INGRESS_PARSER_IDLE;
        end

        if (asi_ingress_valid) begin
          if (ingress_parser_is_subheader && !ingress_parser_shd_err) begin
            ingress_parser.running_ts <= ingress_parser_if_current_subheader_ts;
            ingress_parser.shd_len <= '0;
            ingress_parser.shd_decl_len <= ingress_parser_if_subheader_hit_cnt;
            ingress_parser.shd_seen_cnt <= '0;
            ingress_parser.shd_pre_drop_remaining <= '0;
            if ((ingress_parser_if_subheader_hit_cnt_raw != '0) &&
                (int'(ingress_parser_if_subheader_hit_cnt_raw) >= lane_credit_effective_v)) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_lane_o <= 1'b1;
              credit_drop_pkg_cnt_o <= ingress_parser.pkg_cnt;
              credit_drop_ts_o <= ingress_parser_if_current_subheader_ts;
`ifdef OPQ_OSS_FORMAL
              credit_drop_lane_decision_dbg_oss <= 1'b1;
`endif
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= ingress_parser_if_subheader_hit_cnt_raw;
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (!ticket_credit_available_v) begin
              credit_drop_valid_o <= 1'b1;
              credit_drop_ticket_o <= 1'b1;
              credit_drop_pkg_cnt_o <= ingress_parser.pkg_cnt;
              credit_drop_ts_o <= ingress_parser_if_current_subheader_ts;
`ifdef OPQ_OSS_FORMAL
              credit_drop_ticket_decision_dbg_oss <= 1'b1;
`endif
              credit_drop_shd_cnt_o <= 16'd1;
              credit_drop_hit_cnt_o <= ingress_parser_if_subheader_hit_cnt_raw;
              ingress_parser_state <= INGRESS_PARSER_MASK_PKT;
            end else if (ingress_parser_if_subheader_hit_cnt_raw != '0) begin
              if (ingress_parser_if_subheader_overlimit) begin
                credit_drop_valid_o <= 1'b1;
                credit_drop_pkg_cnt_o <= ingress_parser.pkg_cnt;
                credit_drop_ts_o <= ingress_parser_if_current_subheader_ts;
                credit_drop_shd_cnt_o <= 16'd0;
                credit_drop_hit_cnt_o <= ingress_parser_if_subheader_overlimit_drop_cnt;
                ingress_parser.shd_pre_drop_remaining <= ingress_parser_if_subheader_overlimit_drop_cnt;
                ingress_parser_state <= INGRESS_PARSER_DROP_OVERLIMIT;
              end else begin
                ingress_parser_state <= INGRESS_PARSER_WR_HITS;
              end
            end else begin
              ingress_parser.ticket_we <= 1'b1;
`ifdef OPQ_OSS_FORMAL
              ticket_issue_dbg_oss <= 1'b1;
`endif
              ingress_parser.ticket_waddr <= ingress_parser.ticket_wptr;
              ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
              ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
              if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
                $display("[opq_boundary] t=%0t parser_ticket_we ts=0x%0h lane_start=0x%0h len=%0d sop=%0b eop=%0b next_ticket_wptr=0x%0h",
                  $time,
                  ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO],
                  ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO],
                  ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO],
                  ingress_parser_if_write_ticket_data[TICKET_ALT_SOP_LOC],
                  ingress_parser_if_write_ticket_data[TICKET_ALT_EOP_LOC],
                  ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST);
              end
`endif
`endif
              ingress_parser.alert_eop <= 1'b0;
              ingress_parser_state <= INGRESS_PARSER_IDLE;
              if (ticket_credit_update_valid) begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                  TICKET_FIFO_ADDR_ONE_CONST;
              end else begin
                ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
              end
            end
          end else if (asi_ingress_startofpacket && ingress_parser_is_preamble && !ingress_parser_hdr_err) begin
            ingress_parser.alert_sop <= 1'b1;
            ingress_parser.dt_type <= ingress_parser_if_preamble_dt_type;
            ingress_parser.feb_id <= ingress_parser_if_preamble_feb_id;
            update_header_ts_flow <= '0;
            ingress_parser_state <= INGRESS_PARSER_UPDATE_HEADER_TS;
          end else if (ingress_parser_is_trailer) begin
            ingress_parser.alert_eop <= 1'b1;
          end
        end
      end

      INGRESS_PARSER_DROP_OVERLIMIT: begin
        if (hit_consume_v) begin
          if (ingress_parser.shd_pre_drop_remaining > 16'd1) begin
            ingress_parser.shd_pre_drop_remaining <= ingress_parser.shd_pre_drop_remaining - 16'd1;
          end else begin
            ingress_parser.shd_pre_drop_remaining <= '0;
            ingress_parser_state <= INGRESS_PARSER_WR_HITS;
          end
        end
      end

      INGRESS_PARSER_WR_HITS: begin
        if (hit_accept_v) begin
          ingress_parser.lane_wdata <= ingress_parser_if_write_lane_data;
          ingress_parser.lane_waddr <= ingress_parser.lane_wptr;
          ingress_parser.lane_wptr <= ingress_parser.lane_wptr + LANE_FIFO_ADDR_ONE_CONST;
          ingress_parser.lane_we <= 1'b1;
`ifdef OPQ_OSS_FORMAL
          lane_issue_dbg_oss <= 1'b1;
`endif
          ingress_parser.shd_len <= shd_accept_next_v;
        end else if (ingress_parser_shd_err) begin
          ingress_parser.error_lane_wr_early_term <= 1'b1;
        end

        if (hit_consume_v) begin
          ingress_parser.shd_seen_cnt <= shd_seen_next_v;
          if (hit_last_v) begin
            ingress_parser.ticket_we <= 1'b1;
`ifdef OPQ_OSS_FORMAL
            ticket_issue_dbg_oss <= 1'b1;
`endif
            ingress_parser.ticket_waddr <= ingress_parser.ticket_wptr;
            ingress_parser.ticket_wptr <= ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST;
            ingress_parser.ticket_wdata <= ingress_parser_if_write_ticket_data;
`ifndef SYNTHESIS
`ifndef OPQ_OSS_FORMAL
            if (opq_trace_boundary_en && ($time >= opq_trace_after_ps)) begin
              $display("[opq_boundary] t=%0t parser_ticket_we ts=0x%0h lane_start=0x%0h len=%0d sop=%0b eop=%0b next_ticket_wptr=0x%0h",
                $time,
                ingress_parser_if_write_ticket_data[TICKET_TS_HI:TICKET_TS_LO],
                ingress_parser_if_write_ticket_data[TICKET_LANE_RD_OFST_HI:TICKET_LANE_RD_OFST_LO],
                ingress_parser_if_write_ticket_data[TICKET_BLOCK_LEN_HI:TICKET_BLOCK_LEN_LO],
                ingress_parser_if_write_ticket_data[TICKET_ALT_SOP_LOC],
                ingress_parser_if_write_ticket_data[TICKET_ALT_EOP_LOC],
                ingress_parser.ticket_wptr + TICKET_FIFO_ADDR_ONE_CONST);
            end
`endif
`endif
            if (ticket_credit_update_valid) begin
              ingress_parser.ticket_credit <= ingress_parser.ticket_credit + ticket_credit_update -
                TICKET_FIFO_ADDR_ONE_CONST;
            end else begin
              ingress_parser.ticket_credit <= ingress_parser.ticket_credit - TICKET_FIFO_ADDR_ONE_CONST;
            end
            if (lane_credit_update_valid) begin
              ingress_parser.lane_credit <= ingress_parser.lane_credit - shd_accept_next_v +
                lane_credit_update;
            end else begin
              ingress_parser.lane_credit <= ingress_parser.lane_credit - shd_accept_next_v;
            end
            if (hit_accept_v) begin
              ingress_parser.lane_start_addr <= ingress_parser.lane_wptr + LANE_FIFO_ADDR_ONE_CONST;
            end else begin
              ingress_parser.lane_start_addr <= ingress_parser.lane_wptr;
            end
            ingress_parser_state <= INGRESS_PARSER_IDLE;
          end
        end
      end

      INGRESS_PARSER_RESET: begin
        ingress_parser <= '0;
        ingress_parser.lane_credit <= LANE_FIFO_MAX_CREDIT_CONST;
        ingress_parser.ticket_credit <= TICKET_FIFO_MAX_CREDIT_CONST;
        if ((ingress_parser.lane_credit == LANE_FIFO_MAX_CREDIT_CONST) &&
            (ingress_parser.ticket_credit == TICKET_FIFO_MAX_CREDIT_CONST)) begin
          ingress_parser_state <= INGRESS_PARSER_IDLE;
        end
      end

      default: begin
      end
    endcase

    if (ingress_parser.ticket_we && ingress_parser.alert_eop) begin
      ingress_parser.alert_eop <= 1'b0;
    end

    if (asi_ingress_valid && ingress_parser_is_trailer) begin
      tail_bypass_valid_o <= 1'b1;
      tail_bypass_drop_o <=
        (ingress_parser_state == INGRESS_PARSER_MASK_PKT) ||
        (ingress_parser_state == INGRESS_PARSER_MASK_PKT_EXTENDED);
      tail_bypass_serial_o <= ingress_parser.pkg_cnt;
      tail_bypass_ts_o <= ingress_parser.running_ts;
    end

    if (d_reset) begin
      ingress_parser <= '0;
      ingress_parser.lane_credit <= LANE_FIFO_MAX_CREDIT_CONST;
      ingress_parser.ticket_credit <= TICKET_FIFO_MAX_CREDIT_CONST;
      ingress_parser_state <= INGRESS_PARSER_RESET;
      update_header_ts_flow <= '0;
      credit_drop_valid_o <= 1'b0;
      credit_drop_lane_o <= 1'b0;
      credit_drop_ticket_o <= 1'b0;
      credit_drop_pkg_cnt_o <= '0;
      credit_drop_ts_o <= '0;
      credit_drop_shd_cnt_o <= '0;
      credit_drop_hit_cnt_o <= '0;
      tail_bypass_valid_o <= 1'b0;
      tail_bypass_drop_o <= 1'b0;
      tail_bypass_serial_o <= '0;
      tail_bypass_ts_o <= '0;
`ifdef OPQ_OSS_FORMAL
      lane_issue_dbg_oss <= 1'b0;
      ticket_issue_dbg_oss <= 1'b0;
      credit_drop_lane_decision_dbg_oss <= 1'b0;
      credit_drop_ticket_decision_dbg_oss <= 1'b0;
`endif
    end
  end

`ifndef OPQ_OSS_FORMAL
  property p_reset_drives_ingress_parser_reset;
    @(posedge d_clk) d_reset |=> (ingress_parser_state == INGRESS_PARSER_RESET);
  endproperty
  ap_reset_drives_ingress_parser_reset: assert property (p_reset_drives_ingress_parser_reset);

  // TODO: pointer-advance assertions need a dedicated pre-update shadow register.
  // The exported write pulse and pointer are both driven from the same clocked process,
  // so a direct SVA on the public outputs samples the wrong phase and false-fires.

  property p_alert_eop_clears_after_ticket_write;
    @(posedge d_clk) disable iff (d_reset)
      (ticket_we && ingress_parser.alert_eop) |=> !ingress_parser.alert_eop;
  endproperty
  ap_alert_eop_clears_after_ticket_write: assert property (p_alert_eop_clears_after_ticket_write);

  property p_subheader_ticket_carries_pkg_serial;
    @(posedge d_clk) disable iff (d_reset)
      (ticket_we && !ticket_wdata[TICKET_ALT_SOP_LOC])
      |-> (ticket_wdata[TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] == $past(ingress_parser.pkg_cnt));
  endproperty
  ap_subheader_ticket_carries_pkg_serial: assert property (p_subheader_ticket_carries_pkg_serial);

  property p_credit_drop_carries_pkg_cnt;
    @(posedge d_clk) disable iff (d_reset)
      credit_drop_valid_o |-> (credit_drop_pkg_cnt_o == ingress_parser.pkg_cnt);
  endproperty
  ap_credit_drop_carries_pkg_cnt: assert property (p_credit_drop_carries_pkg_cnt);

`ifndef SYNTHESIS
  cp_subheader_ticket_carries_pkg_serial: cover property (@(posedge d_clk) disable iff (d_reset)
    ticket_we && !ticket_wdata[TICKET_ALT_SOP_LOC] &&
    (ticket_wdata[TICKET_BODY_SERIAL_HI:TICKET_BODY_SERIAL_LO] == $past(ingress_parser.pkg_cnt)));

  cp_credit_drop_carries_pkg_cnt: cover property (@(posedge d_clk) disable iff (d_reset)
    credit_drop_valid_o && (credit_drop_pkg_cnt_o == ingress_parser.pkg_cnt));
`endif
`endif

`ifdef OPQ_ENABLE_NATIVE_FORMAL_INGRESS
  opq_native_ingress_formal_sva #(
    .N_SHD(N_SHD),
    .N_HIT(N_HIT),
    .FRAME_HDR_AUX_WORDS(4),
    .FRAME_SUBH_CNT_SIZE(FRAME_SUBH_CNT_SIZE),
    .FRAME_HIT_CNT_SIZE(FRAME_HIT_CNT_SIZE),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
    .LANE_FIFO_ADDR_WIDTH(LANE_FIFO_ADDR_WIDTH),
    .TICKET_FIFO_ADDR_WIDTH(TICKET_FIFO_ADDR_WIDTH),
    .TICKET_FIFO_DATA_WIDTH(TICKET_FIFO_DATA_WIDTH),
    .MAX_PKT_LENGTH_BITS(MAX_PKT_LENGTH_BITS),
    .TICKET_ALT_EOP_LOC(TICKET_ALT_EOP_LOC),
    .TICKET_ALT_SOP_LOC(TICKET_ALT_SOP_LOC)
  ) native_formal_sva_i (
    .d_clk(d_clk),
    .d_reset(d_reset),
    .asi_ingress_valid(asi_ingress_valid),
    .asi_ingress_startofpacket(asi_ingress_startofpacket),
    .asi_ingress_endofpacket(asi_ingress_endofpacket),
    .asi_ingress_data(asi_ingress_data),
    .asi_ingress_error(asi_ingress_error),
    .lane_credit_update(lane_credit_update),
    .lane_credit_update_valid(lane_credit_update_valid),
    .ticket_credit_update(ticket_credit_update),
    .ticket_credit_update_valid(ticket_credit_update_valid),
    .ticket_wdata(ticket_wdata),
    .ticket_wptr(ticket_wptr),
    .ticket_we(ticket_we),
    .lane_wptr(lane_wptr),
    .lane_we(lane_we),
    .lane_credit_dbg(ingress_parser.lane_credit),
    .ticket_credit_dbg(ingress_parser.ticket_credit),
    .tail_bypass_valid_dbg(tail_bypass_valid_o),
    .tail_bypass_drop_dbg(tail_bypass_drop_o),
    .alert_eop_dbg(ingress_parser.alert_eop),
    .eop_flush_ack_i(eop_flush_ack_i)
  );
`endif

endmodule
