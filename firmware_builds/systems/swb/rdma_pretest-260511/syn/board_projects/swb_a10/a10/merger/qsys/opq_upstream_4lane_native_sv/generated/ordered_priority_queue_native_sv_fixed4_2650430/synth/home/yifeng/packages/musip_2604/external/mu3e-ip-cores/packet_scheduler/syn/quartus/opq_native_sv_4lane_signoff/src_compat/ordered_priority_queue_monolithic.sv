//------------------------------------------------------------------------------
// ordered_priority_queue_monolithic_sv
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.4.6-syn
// Date    : 20260427
// Change  : Export native debug ports and preserve standalone synth-observe taps
//------------------------------------------------------------------------------

module ordered_priority_queue_monolithic_sv #(
  parameter int unsigned N_LANE = 2,
  parameter string MODE = "MERGING",
  parameter bit TRACK_HEADER = 1'b1,
  parameter int unsigned INGRESS_DATA_WIDTH = 32,
  parameter int unsigned INGRESS_DATAK_WIDTH = 4,
  parameter int unsigned CHANNEL_WIDTH = 2,
  parameter int unsigned LANE_FIFO_DEPTH = 1024,
  parameter int unsigned LANE_FIFO_WIDTH = 40,
  parameter int unsigned TICKET_FIFO_DEPTH = 256,
  parameter int unsigned HANDLE_FIFO_DEPTH = 64,
  parameter int unsigned PAGE_RAM_DEPTH = 65536,
  parameter int unsigned PAGE_RAM_RD_WIDTH = 36,
  parameter int unsigned N_SHD = 256,
  parameter int unsigned N_HIT = 255,
  parameter int unsigned HDR_SIZE = 5,
  parameter int unsigned SHD_SIZE = 1,
  parameter int unsigned HIT_SIZE = 1,
  parameter int unsigned TRL_SIZE = 1,
  parameter int unsigned FRAME_SERIAL_SIZE = 16,
  parameter int unsigned FRAME_SUBH_CNT_SIZE = 16,
  parameter int unsigned FRAME_HIT_CNT_SIZE = 16,
  parameter int unsigned DEBUG_LV = 1,
  parameter int unsigned MAX_PKT_LENGTH = HIT_SIZE * N_HIT,
  parameter int unsigned MAX_PKT_LENGTH_BITS = (MAX_PKT_LENGTH <= 1) ? 1 : $clog2(MAX_PKT_LENGTH),
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_A =
    48 + $clog2(LANE_FIFO_DEPTH) + MAX_PKT_LENGTH_BITS + FRAME_SERIAL_SIZE + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH_B =
    FRAME_SERIAL_SIZE + FRAME_SUBH_CNT_SIZE + FRAME_HIT_CNT_SIZE + 6 + 16 + 48 + 2,
  parameter int unsigned TICKET_FIFO_DATA_WIDTH =
    (TICKET_FIFO_DATA_WIDTH_A > TICKET_FIFO_DATA_WIDTH_B) ? TICKET_FIFO_DATA_WIDTH_A : TICKET_FIFO_DATA_WIDTH_B,
  parameter int unsigned TICKET_FIFO_ADDR_WIDTH = $clog2(TICKET_FIFO_DEPTH),
  parameter int unsigned LANE_FIFO_ADDR_WIDTH = $clog2(LANE_FIFO_DEPTH),
  parameter int unsigned HANDLE_FIFO_ADDR_WIDTH = $clog2(HANDLE_FIFO_DEPTH),
  parameter int unsigned PAGE_RAM_DATA_WIDTH = 40,
  parameter int unsigned PAGE_RAM_ADDR_WIDTH = $clog2(PAGE_RAM_DEPTH),
  parameter int unsigned HANDLE_LENGTH = LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH + MAX_PKT_LENGTH_BITS
) (
  input  logic [N_LANE-1:0][INGRESS_DATA_WIDTH+INGRESS_DATAK_WIDTH-1:0] asi_ingress_data,
  input  logic [N_LANE-1:0]                                              asi_ingress_valid,
  input  logic [N_LANE-1:0][CHANNEL_WIDTH-1:0]                           asi_ingress_channel,
  input  logic [N_LANE-1:0]                                              asi_ingress_startofpacket,
  input  logic [N_LANE-1:0]                                              asi_ingress_endofpacket,
  input  logic [N_LANE-1:0][2:0]                                         asi_ingress_error,
  output logic [PAGE_RAM_RD_WIDTH-1:0]                                   aso_egress_data,
  output logic                                                           aso_egress_valid,
  input  logic                                                           aso_egress_ready,
  output logic                                                           aso_egress_startofpacket,
  output logic                                                           aso_egress_endofpacket,
  output logic [2:0]                                                     aso_egress_error,
  output logic [31:0]                                                    synth_observe_global0_o,
  output logic [31:0]                                                    synth_observe_global1_o,
  output logic [31:0]                                                    synth_observe_global2_o,
  output logic [31:0]                                                    synth_observe_global3_o,
  output logic [31:0]                                                    synth_observe_global4_o,
  output logic [31:0]                                                    synth_observe_global5_o,
  output logic [31:0]                                                    synth_observe_global6_o,
  output logic [31:0]                                                    synth_observe_global7_o,
  output logic [31:0]                                                    synth_observe_global8_o,
  output logic [31:0]                                                    synth_observe_global9_o,
  output logic [N_LANE-1:0][31:0]                                        synth_observe_lane_o,
  output logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0]                    ingress_lane_credit_dbg_o,
  output logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0]                  ingress_ticket_credit_dbg_o,
  output logic [N_LANE-1:0]                                              ingress_parser_idle_dbg_o,
  output logic [N_LANE-1:0]                                              ingress_ticket_we_dbg_o,
  output logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0]                  ingress_ticket_wdata_dbg_o,
  output logic [N_LANE-1:0]                                              ingress_lane_we_dbg_o,
  output logic [N_LANE-1:0]                                              ingress_credit_drop_valid_dbg_o,
  output logic [N_LANE-1:0]                                              ingress_credit_drop_lane_dbg_o,
  output logic [N_LANE-1:0]                                              ingress_credit_drop_ticket_dbg_o,
  output logic [N_LANE-1:0][15:0]                                        ingress_credit_drop_shd_cnt_dbg_o,
  output logic [N_LANE-1:0][15:0]                                        ingress_credit_drop_hit_cnt_dbg_o,
  output logic [N_LANE-1:0]                                              handle_we_dbg_o,
  output logic [N_LANE-1:0]                                              handle_flag_dbg_o,
  output logic [N_LANE-1:0][MAX_PKT_LENGTH_BITS-1:0]                     handle_block_len_dbg_o,
  output logic [N_LANE-1:0][9:0]                                         drr_quantum_dbg_o,
  output logic [N_LANE-1:0]                                              drr_req_dbg_o,
  output logic [N_LANE-1:0]                                              drr_gnt_dbg_o,
  output logic [N_LANE-1:0]                                              drr_lock_event_dbg_o,
  output logic [N_LANE-1:0]                                              drr_defer_event_dbg_o,
  output logic                                                           new_frame_dbg_o,
  output logic                                                           ft_wr_page_dbg_o,
  output logic [15:0]                                                    ft_wr_hit_len_dbg_o,
  output logic                                                           ft_drop_valid_dbg_o,
  output logic [31:0]                                                    ft_drop_hdr_dbg_o,
  output logic [31:0]                                                    ft_drop_shd_dbg_o,
  output logic [31:0]                                                    ft_drop_hit_dbg_o,
  output logic                                                           page_allocator_active_dbg_o,
  output logic                                                           arbiter_active_dbg_o,
  input  logic [N_LANE-1:0][9:0]                                         cfg_drr_allowance_i,
  input  logic [N_LANE-1:0]                                              cfg_drr_allowance_reload_i,
  input  logic                                                           d_clk,
  input  logic                                                           d_reset
);
  // ----------------------------------------------------------------------------
  // Source-level SystemVerilog rewrite in progress.
  // The default/basic data path is now native SV for:
  // - per-lane ingress parser
  // - shared page allocator
  // - handle reader / block mover / B2P arbiter
  // - single-page basic presenter
  //
  // Standalone frame-table tracker/presenter SV translations now exist in this
  // directory, but the top-level shell still uses the basic presenter until the
  // mapper and tiled page-ram hookup are swapped over and regression-backed.
  // ----------------------------------------------------------------------------

  logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0] ingress_ticket_wdata;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] ingress_ticket_waddr;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] ingress_ticket_wptr;
  logic [N_LANE-1:0] ingress_ticket_we;
  logic [N_LANE-1:0][LANE_FIFO_WIDTH-1:0] ingress_lane_wdata;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] ingress_lane_waddr;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] ingress_lane_wptr;
  logic [N_LANE-1:0] ingress_lane_we;
  logic [N_LANE-1:0][47:0] ingress_running_ts_dbg;
  logic [N_LANE-1:0][47:0] ingress_frame_ts_base_dbg;
  logic [N_LANE-1:0][5:0] ingress_dt_type_dbg;
  logic [N_LANE-1:0][15:0] ingress_feb_id_dbg;
  logic [N_LANE-1:0] ingress_parser_busy_dbg;
  logic [N_LANE-1:0] ingress_credit_drop_valid_dbg;
  logic [N_LANE-1:0] ingress_credit_drop_lane_dbg;
  logic [N_LANE-1:0] ingress_credit_drop_ticket_dbg;
  logic [N_LANE-1:0][47:0] ingress_credit_drop_ts_dbg;
  logic [N_LANE-1:0][15:0] ingress_credit_drop_shd_cnt_dbg;
  logic [N_LANE-1:0][15:0] ingress_credit_drop_hit_cnt_dbg;
  logic [N_LANE-1:0] ingress_tail_bypass_valid_dbg;
  logic [N_LANE-1:0] ingress_tail_bypass_drop_dbg;
  logic [N_LANE-1:0][FRAME_SERIAL_SIZE-1:0] ingress_tail_bypass_serial_dbg;
  logic [N_LANE-1:0][47:0] ingress_tail_bypass_ts_dbg;
  logic [N_LANE-1:0] ingress_alert_eop_dbg;
  logic [N_LANE-1:0] ingress_eop_flush_ack_dbg;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] lane_credit_update;
  logic [N_LANE-1:0] lane_credit_update_valid;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] block_path_lane_credit_update;
  logic [N_LANE-1:0] block_path_lane_credit_update_valid;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] late_drop_lane_credit_update;
  logic [N_LANE-1:0] late_drop_lane_credit_update_valid;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] ticket_credit_update;
  logic [N_LANE-1:0] ticket_credit_update_valid;
  logic [N_LANE-1:0][TICKET_FIFO_DATA_WIDTH-1:0] ticket_fifos_rd_data;
  logic [N_LANE-1:0][TICKET_FIFO_ADDR_WIDTH-1:0] ticket_fifos_rd_addr;
  logic [N_LANE-1:0][LANE_FIFO_WIDTH-1:0] lane_fifos_rd_data;
  logic [N_LANE-1:0][LANE_FIFO_ADDR_WIDTH-1:0] lane_fifos_rd_addr;
  logic [N_LANE-1:0][HANDLE_LENGTH:0] handle_fifos_rd_data;
  logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_fifos_rd_addr;
  logic [N_LANE-1:0][HANDLE_LENGTH:0] handle_wdata_dbg;
  logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_waddr_dbg;
  logic [N_LANE-1:0][HANDLE_FIFO_ADDR_WIDTH-1:0] handle_wptr_dbg;
  logic [N_LANE-1:0] handle_we_dbg;
  logic [N_LANE-1:0] late_frame_drop_valid_dbg;
  logic [N_LANE-1:0][15:0] late_frame_drop_hdr_cnt_dbg;
  logic [N_LANE-1:0][15:0] late_frame_drop_shd_cnt_dbg;
  logic [N_LANE-1:0][15:0] late_frame_drop_hit_cnt_dbg;
  logic [N_LANE-1:0][47:0] late_frame_drop_ts_dbg;
  logic [N_LANE-1:0] tk_future_dbg;
  logic fetch_ticket_active_dbg;
  logic alloc_page_active_dbg;
  logic write_head_active_dbg;
  logic write_tail_active_dbg;
  logic write_page_active_dbg;
  logic [2:0] write_meta_flow_dbg;
  logic [2:0] write_meta_flow_d1_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] frame_start_addr_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] packet_complete_frame_start_addr_dbg;
  logic [$clog2(N_SHD * N_LANE):0] packet_complete_shr_cnt_dbg;
  logic [15:0] packet_complete_hit_cnt_dbg;
  logic [N_LANE-1:0][$clog2(N_SHD * N_LANE):0] packet_complete_lane_shd_cnt_dbg;
  logic [N_LANE-1:0][15:0] packet_complete_lane_hit_cnt_dbg;
  logic [$clog2(N_SHD * N_LANE):0] frame_shr_cnt_this_dbg;
  logic [15:0] frame_hit_cnt_this_dbg;
  logic [N_LANE-1:0][$clog2(N_SHD * N_LANE):0] frame_lane_shd_cnt_this_dbg;
  logic [N_LANE-1:0][15:0] frame_lane_hit_cnt_this_dbg;
  logic page_we_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] page_waddr_dbg;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_wdata_dbg;
  logic page_ram_we_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_wr_addr_dbg;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_wr_data_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] page_ram_rd_addr_dbg;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_rd_data_dbg;
  logic [PAGE_RAM_DATA_WIDTH-1:0] page_ram_rd_data_presenter_dbg;
  logic presenter_resident_hold_dbg;
  logic presenter_resident_head_valid_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] presenter_resident_head_addr_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] presenter_resident_head_len_dbg;
  logic presenter_resident_head_full_ring_dbg;
  logic presenter_resident_head_has_successor_dbg;
  logic payload_commit_idle_dbg;
  logic packet_complete_pulse_dbg;
  logic [1:0] packet_complete_presenter_delay_dbg;
  logic packet_complete_presenter_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] packet_complete_addr_presenter_delay_dbg [1:0];
  logic [PAGE_RAM_ADDR_WIDTH-1:0] packet_complete_addr_presenter_dbg;
  logic [$clog2(N_SHD * N_LANE):0] packet_complete_shr_cnt_presenter_delay_dbg [1:0];
  logic [15:0] packet_complete_hit_cnt_presenter_delay_dbg [1:0];
  logic [N_LANE-1:0][$clog2(N_SHD * N_LANE):0] packet_complete_lane_shd_cnt_presenter_delay_dbg [1:0];
  logic [N_LANE-1:0][15:0] packet_complete_lane_hit_cnt_presenter_delay_dbg [1:0];
  logic [$clog2(N_SHD * N_LANE):0] packet_complete_shr_cnt_presenter_new_frame_dbg;
  logic [15:0] packet_complete_hit_cnt_presenter_new_frame_dbg;
  logic [N_LANE-1:0][$clog2(N_SHD * N_LANE):0] packet_complete_lane_shd_cnt_presenter_dbg;
  logic [N_LANE-1:0][15:0] packet_complete_lane_hit_cnt_presenter_dbg;
  logic [$clog2(N_SHD * N_LANE):0] packet_complete_shr_cnt_presenter_dbg;
  logic [15:0] packet_complete_hit_cnt_presenter_dbg;
  logic ft_drop_valid_dbg;
  logic [31:0] ft_drop_hdr_cnt_dbg;
  logic [31:0] ft_drop_shd_cnt_dbg;
  logic [31:0] ft_drop_hit_cnt_dbg;
  logic [N_LANE-1:0][$clog2(N_SHD * N_LANE):0] ft_drop_lane_shd_cnt_dbg;
  logic [N_LANE-1:0][15:0] ft_drop_lane_hit_cnt_dbg;
  logic allocator_resident_protect_valid_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] allocator_resident_protect_addr_dbg;
  logic [PAGE_RAM_ADDR_WIDTH-1:0] allocator_resident_protect_len_dbg;
  logic allocator_resident_protect_full_ring_dbg;
  logic allocator_resident_protect_has_successor_dbg;
  logic [N_LANE-1:0] drr_sel_mask_dbg;

  assign ingress_ticket_we_dbg_o = ingress_ticket_we;
  assign ingress_ticket_wdata_dbg_o = ingress_ticket_wdata;
  assign ingress_lane_we_dbg_o = ingress_lane_we;
  assign ingress_credit_drop_valid_dbg_o = ingress_credit_drop_valid_dbg;
  assign ingress_credit_drop_lane_dbg_o = ingress_credit_drop_lane_dbg;
  assign ingress_credit_drop_ticket_dbg_o = ingress_credit_drop_ticket_dbg;
  assign ingress_credit_drop_shd_cnt_dbg_o = ingress_credit_drop_shd_cnt_dbg;
  assign ingress_credit_drop_hit_cnt_dbg_o = ingress_credit_drop_hit_cnt_dbg;
  assign handle_we_dbg_o = handle_we_dbg;
  assign new_frame_dbg_o = write_head_active_dbg && (write_meta_flow_dbg == 3'd0);
  assign ft_wr_page_dbg_o = write_page_active_dbg && page_we_dbg;
  assign ft_wr_hit_len_dbg_o = page_wdata_dbg[23:8];
  assign ft_drop_valid_dbg_o = ft_drop_valid_dbg;
  assign ft_drop_hdr_dbg_o = ft_drop_hdr_cnt_dbg;
  assign ft_drop_shd_dbg_o = ft_drop_shd_cnt_dbg;
  assign ft_drop_hit_dbg_o = ft_drop_hit_cnt_dbg;
  assign page_allocator_active_dbg_o =
    fetch_ticket_active_dbg || write_head_active_dbg || write_tail_active_dbg || write_page_active_dbg;
  assign arbiter_active_dbg_o = |drr_req_dbg_o || |drr_sel_mask_dbg;

  genvar dbg_export_g;
  generate
    for (dbg_export_g = 0; dbg_export_g < N_LANE; dbg_export_g = dbg_export_g + 1) begin : g_dbg_export
      assign handle_flag_dbg_o[dbg_export_g] = handle_wdata_dbg[dbg_export_g][HANDLE_LENGTH];
      assign handle_block_len_dbg_o[dbg_export_g] =
        handle_wdata_dbg[dbg_export_g][HANDLE_LENGTH-1:LANE_FIFO_ADDR_WIDTH + PAGE_RAM_ADDR_WIDTH];
    end
  endgenerate

  always_comb begin : proc_lane_credit_update_mux
    for (int i = 0; i < N_LANE; i++) begin
      lane_credit_update[i] = '0;
      lane_credit_update_valid[i] = 1'b0;
      if (block_path_lane_credit_update_valid[i]) begin
        lane_credit_update[i] = lane_credit_update[i] + block_path_lane_credit_update[i];
        lane_credit_update_valid[i] = 1'b1;
      end
      if (late_drop_lane_credit_update_valid[i]) begin
        lane_credit_update[i] = lane_credit_update[i] + late_drop_lane_credit_update[i];
        lane_credit_update_valid[i] = 1'b1;
      end
    end
  end

  genvar m;
  generate
    for (m = 0; m < N_LANE; m = m + 1) begin : g_storage
    ticket_fifo #(
      .DATA_WIDTH(TICKET_FIFO_DATA_WIDTH),
      .ADDR_WIDTH(TICKET_FIFO_ADDR_WIDTH)
    ) ticket_fifo_i (
      .data(ingress_ticket_wdata[m]),
      .read_addr(ticket_fifos_rd_addr[m]),
      .write_addr(ingress_ticket_waddr[m]),
      .we(ingress_ticket_we[m]),
      .clk(d_clk),
      .q(ticket_fifos_rd_data[m])
    );

    lane_fifo #(
      .DATA_WIDTH(LANE_FIFO_WIDTH),
      .ADDR_WIDTH(LANE_FIFO_ADDR_WIDTH)
    ) lane_fifo_i (
      .data(ingress_lane_wdata[m]),
      .read_addr(lane_fifos_rd_addr[m]),
      .write_addr(ingress_lane_waddr[m]),
      .we(ingress_lane_we[m]),
      .clk(d_clk),
      .q(lane_fifos_rd_data[m])
    );

    handle_fifo #(
      .DATA_WIDTH(HANDLE_LENGTH + 1),
      .ADDR_WIDTH(HANDLE_FIFO_ADDR_WIDTH)
    ) handle_fifo_i (
      .data(handle_wdata_dbg[m]),
      .read_addr(handle_fifos_rd_addr[m]),
      .write_addr(handle_waddr_dbg[m]),
      .we(handle_we_dbg[m]),
      .clk(d_clk),
      .q(handle_fifos_rd_data[m])
    );
    end
  endgenerate

  genvar g;
  generate
    for (g = 0; g < N_LANE; g = g + 1) begin : g_ingress_parser
    ordered_priority_queue_monolithic_ingress_parser #(
      .INGRESS_DATA_WIDTH(INGRESS_DATA_WIDTH),
      .INGRESS_DATAK_WIDTH(INGRESS_DATAK_WIDTH),
      .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
      .LANE_FIFO_WIDTH(LANE_FIFO_WIDTH),
      .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
      .N_HIT(N_HIT),
      .HIT_SIZE(HIT_SIZE),
      .FRAME_SERIAL_SIZE(FRAME_SERIAL_SIZE),
      .FRAME_SUBH_CNT_SIZE(FRAME_SUBH_CNT_SIZE),
      .FRAME_HIT_CNT_SIZE(FRAME_HIT_CNT_SIZE)
    ) ingress_parser_i (
      .asi_ingress_data(asi_ingress_data[g]),
      .asi_ingress_valid(asi_ingress_valid[g]),
      .asi_ingress_startofpacket(asi_ingress_startofpacket[g]),
      .asi_ingress_endofpacket(asi_ingress_endofpacket[g]),
      .asi_ingress_error(asi_ingress_error[g]),
      .lane_credit_update(lane_credit_update[g]),
      .lane_credit_update_valid(lane_credit_update_valid[g]),
      .ticket_credit_update(ticket_credit_update[g]),
      .ticket_credit_update_valid(ticket_credit_update_valid[g]),
      .ticket_wdata(ingress_ticket_wdata[g]),
      .ticket_waddr(ingress_ticket_waddr[g]),
      .ticket_wptr(ingress_ticket_wptr[g]),
      .ticket_we(ingress_ticket_we[g]),
      .lane_wdata(ingress_lane_wdata[g]),
      .lane_waddr(ingress_lane_waddr[g]),
      .lane_wptr(ingress_lane_wptr[g]),
      .lane_we(ingress_lane_we[g]),
      .running_ts_dbg(ingress_running_ts_dbg[g]),
        .frame_ts_base_dbg(ingress_frame_ts_base_dbg[g]),
        .dt_type_dbg(ingress_dt_type_dbg[g]),
        .feb_id_dbg(ingress_feb_id_dbg[g]),
        .parser_busy_o(ingress_parser_busy_dbg[g]),
        .parser_idle_dbg_o(ingress_parser_idle_dbg_o[g]),
        .lane_credit_dbg_o(ingress_lane_credit_dbg_o[g]),
        .ticket_credit_dbg_o(ingress_ticket_credit_dbg_o[g]),
      .credit_drop_valid_o(ingress_credit_drop_valid_dbg[g]),
      .credit_drop_lane_o(ingress_credit_drop_lane_dbg[g]),
      .credit_drop_ticket_o(ingress_credit_drop_ticket_dbg[g]),
      .credit_drop_ts_o(ingress_credit_drop_ts_dbg[g]),
      .credit_drop_shd_cnt_o(ingress_credit_drop_shd_cnt_dbg[g]),
      .credit_drop_hit_cnt_o(ingress_credit_drop_hit_cnt_dbg[g]),
      .tail_bypass_valid_o(ingress_tail_bypass_valid_dbg[g]),
      .tail_bypass_drop_o(ingress_tail_bypass_drop_dbg[g]),
      .tail_bypass_serial_o(ingress_tail_bypass_serial_dbg[g]),
      .tail_bypass_ts_o(ingress_tail_bypass_ts_dbg[g]),
      .alert_eop_state_o(ingress_alert_eop_dbg[g]),
      .eop_flush_ack_i(ingress_eop_flush_ack_dbg[g]),
      .d_clk(d_clk),
      .d_reset(d_reset)
    );
    end
  endgenerate

  ordered_priority_queue_monolithic_page_allocator #(
    .N_LANE(N_LANE),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH),
    .HANDLE_FIFO_DEPTH(HANDLE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .N_SHD(N_SHD),
    .N_HIT(N_HIT),
    .HDR_SIZE(HDR_SIZE),
    .SHD_SIZE(SHD_SIZE),
    .HIT_SIZE(HIT_SIZE),
    .TRL_SIZE(TRL_SIZE),
    .FRAME_SERIAL_SIZE(FRAME_SERIAL_SIZE),
    .FRAME_SUBH_CNT_SIZE(FRAME_SUBH_CNT_SIZE),
    .FRAME_HIT_CNT_SIZE(FRAME_HIT_CNT_SIZE)
  ) page_allocator_i (
    .ingress_ticket_wptr(ingress_ticket_wptr),
    .ticket_fifos_rd_data_i(ticket_fifos_rd_data),
    .ingress_dt_type_i(ingress_dt_type_dbg),
    .ingress_feb_id_i(ingress_feb_id_dbg),
    .ingress_frame_ts_i(ingress_frame_ts_base_dbg),
    .ingress_running_ts_i(ingress_running_ts_dbg),
    .ingress_parser_busy_i(ingress_parser_busy_dbg),
    .ingress_tail_bypass_valid_i(ingress_tail_bypass_valid_dbg),
    .ingress_tail_bypass_drop_i(ingress_tail_bypass_drop_dbg),
    .ingress_tail_bypass_serial_i(ingress_tail_bypass_serial_dbg),
    .ingress_tail_bypass_ts_i(ingress_tail_bypass_ts_dbg),
    .ticket_credit_update_o(ticket_credit_update),
    .ticket_credit_update_valid_o(ticket_credit_update_valid),
    .handle_wdata_o(handle_wdata_dbg),
    .handle_waddr_o(handle_waddr_dbg),
    .handle_we_o(handle_we_dbg),
    .handle_wptr_o(handle_wptr_dbg),
    .eop_flush_ack_o(ingress_eop_flush_ack_dbg),
    .late_frame_drop_valid_o(late_frame_drop_valid_dbg),
    .late_frame_drop_hdr_cnt_o(late_frame_drop_hdr_cnt_dbg),
    .late_frame_drop_shd_cnt_o(late_frame_drop_shd_cnt_dbg),
    .late_frame_drop_hit_cnt_o(late_frame_drop_hit_cnt_dbg),
    .late_frame_drop_ts_o(late_frame_drop_ts_dbg),
    .late_frame_lane_credit_update_o(late_drop_lane_credit_update),
    .late_frame_lane_credit_update_valid_o(late_drop_lane_credit_update_valid),
    .page_we_o(page_we_dbg),
    .page_waddr_o(page_waddr_dbg),
    .page_wdata_o(page_wdata_dbg),
    .ticket_fifos_rd_addr_o(ticket_fifos_rd_addr),
    .tk_future_o(tk_future_dbg),
    .fetch_ticket_active_o(fetch_ticket_active_dbg),
    .alloc_page_active_o(alloc_page_active_dbg),
    .write_head_active_o(write_head_active_dbg),
    .write_tail_active_o(write_tail_active_dbg),
    .write_page_active_o(write_page_active_dbg),
    .write_meta_flow_o(write_meta_flow_dbg),
    .write_meta_flow_d1_o(write_meta_flow_d1_dbg),
    .frame_start_addr_o(frame_start_addr_dbg),
    .frame_shr_cnt_this_o(frame_shr_cnt_this_dbg),
    .frame_hit_cnt_this_o(frame_hit_cnt_this_dbg),
    .frame_lane_shd_cnt_this_o(frame_lane_shd_cnt_this_dbg),
    .frame_lane_hit_cnt_this_o(frame_lane_hit_cnt_this_dbg),
    .packet_complete_frame_start_addr_o(packet_complete_frame_start_addr_dbg),
    .packet_complete_shr_cnt_o(packet_complete_shr_cnt_dbg),
    .packet_complete_hit_cnt_o(packet_complete_hit_cnt_dbg),
    .packet_complete_lane_shd_cnt_o(packet_complete_lane_shd_cnt_dbg),
    .packet_complete_lane_hit_cnt_o(packet_complete_lane_hit_cnt_dbg),
    .packet_complete_pulse_o(packet_complete_pulse_dbg),
    .resident_backpressure_hold_i(presenter_resident_hold_dbg),
    .resident_protect_valid_i(allocator_resident_protect_valid_dbg),
    .resident_protect_addr_i(allocator_resident_protect_addr_dbg),
    .resident_protect_len_i(allocator_resident_protect_len_dbg),
    .resident_protect_full_ring_i(allocator_resident_protect_full_ring_dbg),
    .resident_protect_has_successor_i(allocator_resident_protect_has_successor_dbg),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

  ordered_priority_queue_monolithic_block_path #(
    .N_LANE(N_LANE),
    .CHANNEL_WIDTH(CHANNEL_WIDTH),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH),
    .LANE_FIFO_WIDTH(LANE_FIFO_WIDTH),
    .HANDLE_FIFO_DEPTH(HANDLE_FIFO_DEPTH),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .N_HIT(N_HIT),
    .HIT_SIZE(HIT_SIZE)
  ) block_path_i (
    .handle_wptr_i(handle_wptr_dbg),
    .handle_we_i(handle_we_dbg),
    .handle_fifos_rd_data_i(handle_fifos_rd_data),
    .lane_fifos_rd_data_i(lane_fifos_rd_data),
    .fetch_ticket_active_i(fetch_ticket_active_dbg),
    .page_allocator_alloc_page_i(alloc_page_active_dbg),
    .tk_future_i(tk_future_dbg),
    .page_allocator_write_head_i(write_head_active_dbg),
    .page_allocator_write_tail_i(write_tail_active_dbg),
    .page_allocator_write_page_i(write_page_active_dbg),
    .page_allocator_page_we_i(page_we_dbg),
    .page_allocator_page_waddr_i(page_waddr_dbg),
    .page_allocator_page_wdata_i(page_wdata_dbg),
    .drr_allowance_i(cfg_drr_allowance_i),
    .drr_allowance_reload_i(cfg_drr_allowance_reload_i),
    .handle_fifos_rd_addr_o(handle_fifos_rd_addr),
    .lane_fifos_rd_addr_o(lane_fifos_rd_addr),
    .lane_credit_update_o(block_path_lane_credit_update),
      .lane_credit_update_valid_o(block_path_lane_credit_update_valid),
      .payload_commit_idle_o(payload_commit_idle_dbg),
      .page_ram_we_o(page_ram_we_dbg),
      .page_ram_wr_addr_o(page_ram_wr_addr_dbg),
      .page_ram_wr_data_o(page_ram_wr_data_dbg),
      .drr_quantum_dbg_o(drr_quantum_dbg_o),
      .drr_req_dbg_o(drr_req_dbg_o),
      .drr_gnt_dbg_o(drr_gnt_dbg_o),
      .drr_lock_event_dbg_o(drr_lock_event_dbg_o),
      .drr_defer_event_dbg_o(drr_defer_event_dbg_o),
      .drr_sel_mask_dbg_o(drr_sel_mask_dbg),
      .d_clk(d_clk),
      .d_reset(d_reset)
  );

  page_ram #(
    .DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH)
  ) page_ram_i (
    .data(page_ram_wr_data_dbg),
    .read_addr(page_ram_rd_addr_dbg),
    .write_addr(page_ram_wr_addr_dbg),
    .we(page_ram_we_dbg),
    .clk(d_clk),
    .q(page_ram_rd_data_dbg)
  );

  always_ff @(posedge d_clk) begin : proc_presenter_page_ram_read_pipe
    if (d_reset) begin
      page_ram_rd_data_presenter_dbg <= '0;
    end else begin
      page_ram_rd_data_presenter_dbg <= page_ram_rd_data_dbg;
    end
  end

  always_ff @(posedge d_clk) begin : proc_presenter_packet_complete_delay
    if (d_reset) begin
      packet_complete_presenter_delay_dbg <= '0;
      packet_complete_addr_presenter_delay_dbg[0] <= '0;
      packet_complete_addr_presenter_delay_dbg[1] <= '0;
      packet_complete_shr_cnt_presenter_delay_dbg[0] <= '0;
      packet_complete_shr_cnt_presenter_delay_dbg[1] <= '0;
      packet_complete_hit_cnt_presenter_delay_dbg[0] <= '0;
      packet_complete_hit_cnt_presenter_delay_dbg[1] <= '0;
      packet_complete_lane_shd_cnt_presenter_delay_dbg[0] <= '{default:'0};
      packet_complete_lane_shd_cnt_presenter_delay_dbg[1] <= '{default:'0};
      packet_complete_lane_hit_cnt_presenter_delay_dbg[0] <= '{default:'0};
      packet_complete_lane_hit_cnt_presenter_delay_dbg[1] <= '{default:'0};
    end else begin
      packet_complete_presenter_delay_dbg[0] <= packet_complete_pulse_dbg;
      packet_complete_presenter_delay_dbg[1] <= packet_complete_presenter_delay_dbg[0];
      if (packet_complete_pulse_dbg) begin
        packet_complete_addr_presenter_delay_dbg[0] <= packet_complete_frame_start_addr_dbg;
        packet_complete_shr_cnt_presenter_delay_dbg[0] <= packet_complete_shr_cnt_dbg;
        packet_complete_hit_cnt_presenter_delay_dbg[0] <= packet_complete_hit_cnt_dbg;
        packet_complete_lane_shd_cnt_presenter_delay_dbg[0] <= packet_complete_lane_shd_cnt_dbg;
        packet_complete_lane_hit_cnt_presenter_delay_dbg[0] <= packet_complete_lane_hit_cnt_dbg;
      end
      if (packet_complete_presenter_delay_dbg[0]) begin
        packet_complete_addr_presenter_delay_dbg[1] <= packet_complete_addr_presenter_delay_dbg[0];
        packet_complete_shr_cnt_presenter_delay_dbg[1] <= packet_complete_shr_cnt_presenter_delay_dbg[0];
        packet_complete_hit_cnt_presenter_delay_dbg[1] <= packet_complete_hit_cnt_presenter_delay_dbg[0];
        packet_complete_lane_shd_cnt_presenter_delay_dbg[1] <=
          packet_complete_lane_shd_cnt_presenter_delay_dbg[0];
        packet_complete_lane_hit_cnt_presenter_delay_dbg[1] <=
          packet_complete_lane_hit_cnt_presenter_delay_dbg[0];
      end
    end
  end

  assign packet_complete_presenter_dbg = packet_complete_presenter_delay_dbg[1];
  assign packet_complete_addr_presenter_dbg = packet_complete_addr_presenter_delay_dbg[1];
  assign packet_complete_shr_cnt_presenter_new_frame_dbg = packet_complete_shr_cnt_presenter_delay_dbg[1];
  assign packet_complete_hit_cnt_presenter_new_frame_dbg = packet_complete_hit_cnt_presenter_delay_dbg[1];
  assign packet_complete_lane_shd_cnt_presenter_dbg = packet_complete_lane_shd_cnt_presenter_delay_dbg[1];
  assign packet_complete_lane_hit_cnt_presenter_dbg = packet_complete_lane_hit_cnt_presenter_delay_dbg[1];
  assign packet_complete_shr_cnt_presenter_dbg = packet_complete_shr_cnt_presenter_delay_dbg[1];
  assign packet_complete_hit_cnt_presenter_dbg = packet_complete_hit_cnt_presenter_delay_dbg[1];

  always_comb begin : proc_allocator_resident_protect
    allocator_resident_protect_valid_dbg = presenter_resident_head_valid_dbg;
    allocator_resident_protect_addr_dbg = presenter_resident_head_addr_dbg;
    allocator_resident_protect_len_dbg = presenter_resident_head_len_dbg;
    allocator_resident_protect_full_ring_dbg = presenter_resident_head_full_ring_dbg;
    allocator_resident_protect_has_successor_dbg = presenter_resident_head_has_successor_dbg;
  end

  ordered_priority_queue_monolithic_basic_presenter #(
    .N_LANE(N_LANE),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH),
    .PAGE_RAM_RD_WIDTH(PAGE_RAM_RD_WIDTH),
    .PAGE_RAM_DATA_WIDTH(PAGE_RAM_DATA_WIDTH),
    .PAGE_RAM_ADDR_WIDTH(PAGE_RAM_ADDR_WIDTH),
    .N_SHD(N_SHD),
    .N_HIT(N_HIT)
  ) presenter_i (
    .new_frame_valid_i(packet_complete_presenter_dbg),
    .new_frame_raw_addr_i(packet_complete_addr_presenter_dbg),
    .frame_shr_cnt_this_i(packet_complete_shr_cnt_presenter_new_frame_dbg),
    .frame_hit_cnt_this_i(packet_complete_hit_cnt_presenter_new_frame_dbg),
    .frame_lane_shd_cnt_this_i(packet_complete_lane_shd_cnt_presenter_dbg),
    .frame_lane_hit_cnt_this_i(packet_complete_lane_hit_cnt_presenter_dbg),
    .packet_complete_i(packet_complete_presenter_dbg),
    .packet_complete_shr_cnt_i(packet_complete_shr_cnt_presenter_dbg),
    .packet_complete_hit_cnt_i(packet_complete_hit_cnt_presenter_dbg),
    .payload_commit_idle_i(payload_commit_idle_dbg),
    .page_ram_rd_addr_o(page_ram_rd_addr_dbg),
    .page_ram_rd_data_i(page_ram_rd_data_presenter_dbg),
    .resident_backpressure_hold_o(presenter_resident_hold_dbg),
    .resident_head_valid_o(presenter_resident_head_valid_dbg),
    .resident_head_addr_o(presenter_resident_head_addr_dbg),
    .resident_head_len_o(presenter_resident_head_len_dbg),
    .resident_head_full_ring_o(presenter_resident_head_full_ring_dbg),
    .resident_head_has_successor_o(presenter_resident_head_has_successor_dbg),
    .ft_drop_valid_o(ft_drop_valid_dbg),
    .ft_drop_hdr_cnt_o(ft_drop_hdr_cnt_dbg),
    .ft_drop_shd_cnt_o(ft_drop_shd_cnt_dbg),
    .ft_drop_hit_cnt_o(ft_drop_hit_cnt_dbg),
    .ft_drop_lane_shd_cnt_o(ft_drop_lane_shd_cnt_dbg),
    .ft_drop_lane_hit_cnt_o(ft_drop_lane_hit_cnt_dbg),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

  initial begin
    assert (PAGE_RAM_ADDR_WIDTH == 16)
      else $warning("PAGE RAM ADDR NON-DEFAULT (16 bits expected)");
    assert ($clog2(N_SHD * N_HIT) + 1 <= 16)
      else $warning("N hits counter will likely overflow the 16-bit frame hit counter");
  end

  // Keep the signoff activity signature tied to top-level I/O so Quartus can
  // prune the large internal debug cone from the standalone build.
  assign synth_observe_global0_o = {aso_egress_valid, aso_egress_ready,
    aso_egress_startofpacket, aso_egress_endofpacket, aso_egress_error,
    aso_egress_data[24:0]};
  assign synth_observe_global1_o = {24'd0, ^asi_ingress_valid, ^asi_ingress_startofpacket,
    ^asi_ingress_endofpacket, ^asi_ingress_error, ^asi_ingress_channel,
    ^cfg_drr_allowance_reload_i, ^cfg_drr_allowance_i, d_reset};
  assign synth_observe_global2_o = 32'd0;
  assign synth_observe_global3_o = 32'd0;
  assign synth_observe_global4_o = 32'd0;
  assign synth_observe_global5_o = 32'd0;
  assign synth_observe_global6_o = 32'd0;
  assign synth_observe_global7_o = 32'd0;
  assign synth_observe_global8_o = 32'd0;
  assign synth_observe_global9_o = 32'd0;

  genvar synth_lane;
  generate
    for (synth_lane = 0; synth_lane < N_LANE; synth_lane = synth_lane + 1) begin : g_synth_observe
      assign synth_observe_lane_o[synth_lane] = {26'd0,
        asi_ingress_valid[synth_lane],
        asi_ingress_startofpacket[synth_lane],
        asi_ingress_endofpacket[synth_lane],
        ^asi_ingress_error[synth_lane],
        ^asi_ingress_channel[synth_lane],
        ^asi_ingress_data[synth_lane]
      };
    end
  endgenerate

endmodule
