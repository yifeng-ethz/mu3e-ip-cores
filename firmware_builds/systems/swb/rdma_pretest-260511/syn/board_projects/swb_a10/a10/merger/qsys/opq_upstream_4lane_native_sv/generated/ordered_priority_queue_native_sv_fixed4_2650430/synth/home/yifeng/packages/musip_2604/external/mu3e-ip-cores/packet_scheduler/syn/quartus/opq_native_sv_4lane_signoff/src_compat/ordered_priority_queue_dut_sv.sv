//------------------------------------------------------------------------------
// ordered_priority_queue_dut_sv
// Author  : Yifeng Wang (original OPQ) / native SV staging by Codex
// Version : 26.5.0-syn
// Date    : 20260430
// Change  : Narrow fixed4 drop-delta adders before the CSR delta register to
//           close the SWB 250 MHz integration path without changing the CSR map.
//------------------------------------------------------------------------------

`ifndef OPQ_N_SHD
`define OPQ_N_SHD 128
`endif

`ifndef OPQ_PAGE_RAM_DEPTH
`define OPQ_PAGE_RAM_DEPTH 65536
`endif

`ifndef OPQ_TICKET_FIFO_DEPTH
`define OPQ_TICKET_FIFO_DEPTH 256
`endif

`ifndef OPQ_HANDLE_FIFO_DEPTH
`define OPQ_HANDLE_FIFO_DEPTH 64
`endif

`ifndef OPQ_LANE_FIFO_DEPTH
`define OPQ_LANE_FIFO_DEPTH 1024
`endif

`ifndef OPQ_N_LANE
`define OPQ_N_LANE 2
`endif

`ifndef OPQ_N_HIT
`define OPQ_N_HIT 255
`endif

`ifndef OPQ_DEBUG_LEVEL
`define OPQ_DEBUG_LEVEL 1
`endif

module ordered_priority_queue_dut_sv #(
  parameter int unsigned N_HIT = `OPQ_N_HIT,
  parameter int unsigned IP_UID = 32'h4F50_514D,
  parameter int unsigned VERSION_MAJOR = 26,
  parameter int unsigned VERSION_MINOR = 5,
  parameter int unsigned VERSION_PATCH = 0,
  parameter int unsigned BUILD = 430,
  parameter int unsigned VERSION_DATE = 20260430,
  parameter int unsigned VERSION_GIT = 32'h4F66_7FB1,
  parameter int unsigned INSTANCE_ID = 0
) (
  input  logic [35:0] asi_ingress_0_data,
  input  logic [0:0]  asi_ingress_0_valid,
  input  logic [1:0]  asi_ingress_0_channel,
  input  logic [0:0]  asi_ingress_0_startofpacket,
  input  logic [0:0]  asi_ingress_0_endofpacket,
  input  logic [2:0]  asi_ingress_0_error,
  input  logic [35:0] asi_ingress_1_data,
  input  logic [0:0]  asi_ingress_1_valid,
  input  logic [1:0]  asi_ingress_1_channel,
  input  logic [0:0]  asi_ingress_1_startofpacket,
  input  logic [0:0]  asi_ingress_1_endofpacket,
  input  logic [2:0]  asi_ingress_1_error,
  input  logic [35:0] asi_ingress_2_data,
  input  logic [0:0]  asi_ingress_2_valid,
  input  logic [1:0]  asi_ingress_2_channel,
  input  logic [0:0]  asi_ingress_2_startofpacket,
  input  logic [0:0]  asi_ingress_2_endofpacket,
  input  logic [2:0]  asi_ingress_2_error,
  input  logic [35:0] asi_ingress_3_data,
  input  logic [0:0]  asi_ingress_3_valid,
  input  logic [1:0]  asi_ingress_3_channel,
  input  logic [0:0]  asi_ingress_3_startofpacket,
  input  logic [0:0]  asi_ingress_3_endofpacket,
  input  logic [2:0]  asi_ingress_3_error,
  output logic [35:0] aso_egress_data,
  output logic        aso_egress_valid,
  input  logic        aso_egress_ready,
  output logic        aso_egress_startofpacket,
  output logic        aso_egress_endofpacket,
  output logic [2:0]  aso_egress_error,
  input  logic [8:0]  avs_csr_address,
  input  logic        avs_csr_read,
  input  logic        avs_csr_write,
  input  logic [31:0] avs_csr_writedata,
  output logic [31:0] avs_csr_readdata,
  output logic        avs_csr_readdatavalid,
  output logic        avs_csr_waitrequest,
  input  logic        avs_csr_burstcount,
  input  logic        d_clk,
  input  logic        d_reset
);
`ifdef OPQ_USE_NATIVE_SV
  localparam int unsigned OPQ_N_LANE_LOCAL = `OPQ_N_LANE;
  localparam int unsigned OPQ_N_SHD_LOCAL = `OPQ_N_SHD;
  localparam int unsigned OPQ_DEBUG_LEVEL_CONST = `OPQ_DEBUG_LEVEL;
  localparam int unsigned CHANNEL_WIDTH_CONST = 2;
  localparam int unsigned LANE_FIFO_DEPTH_CONST = `OPQ_LANE_FIFO_DEPTH;
  localparam int unsigned LANE_FIFO_ADDR_WIDTH_CONST = $clog2(LANE_FIFO_DEPTH_CONST);
  localparam int unsigned LANE_FIFO_MAX_CREDIT_CONST = LANE_FIFO_DEPTH_CONST - 2;
  localparam int unsigned TICKET_FIFO_DEPTH_CONST = `OPQ_TICKET_FIFO_DEPTH;
  localparam int unsigned TICKET_FIFO_ADDR_WIDTH_CONST = $clog2(TICKET_FIFO_DEPTH_CONST);
  localparam int unsigned TICKET_FIFO_MAX_CREDIT_CONST = TICKET_FIFO_DEPTH_CONST - 1;
  localparam int unsigned HANDLE_FIFO_DEPTH_CONST = `OPQ_HANDLE_FIFO_DEPTH;
  localparam int unsigned HANDLE_FIFO_ADDR_WIDTH_CONST = $clog2(HANDLE_FIFO_DEPTH_CONST);
  localparam int unsigned PAGE_RAM_DEPTH_CONST = `OPQ_PAGE_RAM_DEPTH;
  localparam int unsigned PAGE_RAM_ADDR_WIDTH_CONST = $clog2(PAGE_RAM_DEPTH_CONST);
  localparam int unsigned FRAME_SERIAL_SIZE_CONST = 16;
  localparam int unsigned FRAME_SUBH_CNT_SIZE_CONST = 16;
  localparam int unsigned FRAME_HIT_CNT_SIZE_CONST = 16;
  localparam int unsigned MAX_PKT_LENGTH_CONST = N_HIT;
  localparam int unsigned MAX_PKT_LENGTH_BITS_CONST = (MAX_PKT_LENGTH_CONST <= 1) ? 1 : $clog2(MAX_PKT_LENGTH_CONST);
  localparam int unsigned DROP_SHD_DELTA_BITS_CONST = 17;
  localparam int unsigned DROP_HIT_DELTA_BITS_CONST = 18;
  localparam int unsigned TICKET_FIFO_DATA_WIDTH_A_CONST =
    48 + LANE_FIFO_ADDR_WIDTH_CONST + MAX_PKT_LENGTH_BITS_CONST + FRAME_SERIAL_SIZE_CONST + 2;
  localparam int unsigned TICKET_FIFO_DATA_WIDTH_B_CONST =
    FRAME_SERIAL_SIZE_CONST + FRAME_SUBH_CNT_SIZE_CONST + FRAME_HIT_CNT_SIZE_CONST + 6 + 16 + 48 + 2;
  localparam int unsigned TICKET_FIFO_DATA_WIDTH_CONST =
    (TICKET_FIFO_DATA_WIDTH_A_CONST > TICKET_FIFO_DATA_WIDTH_B_CONST) ?
      TICKET_FIFO_DATA_WIDTH_A_CONST : TICKET_FIFO_DATA_WIDTH_B_CONST;
  localparam int unsigned HANDLE_LENGTH_CONST =
    LANE_FIFO_ADDR_WIDTH_CONST + PAGE_RAM_ADDR_WIDTH_CONST + MAX_PKT_LENGTH_BITS_CONST;
  localparam int unsigned HANDLE_LEN_LO_CONST = LANE_FIFO_ADDR_WIDTH_CONST + PAGE_RAM_ADDR_WIDTH_CONST;
  localparam int unsigned HANDLE_LEN_HI_CONST =
    LANE_FIFO_ADDR_WIDTH_CONST + PAGE_RAM_ADDR_WIDTH_CONST + MAX_PKT_LENGTH_BITS_CONST - 1;
  localparam int unsigned TICKET_ALT_EOP_LOC_CONST = TICKET_FIFO_DATA_WIDTH_CONST - 2;
  localparam int unsigned TICKET_ALT_SOP_LOC_CONST = TICKET_FIFO_DATA_WIDTH_CONST - 1;
  localparam int unsigned HDR_SIZE_CONST = 5;
  localparam logic [7:0] K285_CONST = 8'hBC;
  localparam logic [7:0] K284_CONST = 8'h9C;
  localparam logic [7:0] K237_CONST = 8'hF7;
  localparam logic [8:0] CSR_WORD_UID_CONST = 9'h000;
  localparam logic [8:0] CSR_WORD_META_CONST = 9'h001;
  localparam logic [8:0] CSR_WORD_LANE_MASK_CONST = 9'h002;
  localparam logic [8:0] CSR_WORD_CTRL_CONST = 9'h003;
  localparam logic [8:0] CSR_WORD_STATUS_CONST = 9'h004;
  localparam logic [8:0] CSR_WORD_CAP_CONST = 9'h005;
  localparam logic [8:0] CSR_WORD_FT_WR_HDR_CONST = 9'h008;
  localparam logic [8:0] CSR_WORD_FT_WR_SHD_CONST = 9'h009;
  localparam logic [8:0] CSR_WORD_FT_WR_HIT_CONST = 9'h00A;
  localparam logic [8:0] CSR_WORD_FT_RD_HDR_CONST = 9'h00B;
  localparam logic [8:0] CSR_WORD_FT_RD_SHD_CONST = 9'h00C;
  localparam logic [8:0] CSR_WORD_FT_RD_HIT_CONST = 9'h00D;
  localparam logic [8:0] CSR_WORD_FT_DROP_HDR_CONST = 9'h00E;
  localparam logic [8:0] CSR_WORD_FT_DROP_SHD_CONST = 9'h00F;
  localparam logic [8:0] CSR_WORD_FT_DROP_HIT_CONST = 9'h010;
  localparam logic [8:0] CSR_LANE_REGION_BASE_CONST = 9'h040;
  localparam logic [8:0] CSR_LANE_REGION_STRIDE_CONST = 9'h010;
  localparam logic [3:0] CSR_LANE_WORD_DRR_ALLOWANCE_CONST = 4'hB;
  localparam logic [3:0] CSR_LANE_WORD_DRR_QUANTUM_CONST = 4'hC;
  localparam logic [3:0] CSR_LANE_WORD_DRR_GRANT_CNT_CONST = 4'hD;
  localparam logic [3:0] CSR_LANE_WORD_DRR_BEAT_CNT_CONST = 4'hE;
  localparam logic [3:0] CSR_LANE_WORD_DRR_DEFER_CNT_CONST = 4'hF;
  localparam logic [31:0] UID_CONST = IP_UID;
  localparam int unsigned VERSION_MAJOR_CONST = VERSION_MAJOR;
  localparam int unsigned VERSION_MINOR_CONST = VERSION_MINOR;
  localparam int unsigned VERSION_PATCH_CONST = VERSION_PATCH;
  localparam int unsigned VERSION_BUILD_CONST = BUILD;
  localparam logic [31:0] VERSION_DATE_CONST = VERSION_DATE;
  localparam logic [31:0] VERSION_GIT_CONST = VERSION_GIT;
  localparam logic [31:0] INSTANCE_ID_CONST = INSTANCE_ID;
  localparam logic [9:0] DRR_DEFAULT_ALLOWANCE_CONST = 10'd256;

  logic [3:0][35:0] asi_ingress_data_bus;
  logic [3:0]       asi_ingress_valid_bus;
  logic [3:0][1:0]  asi_ingress_channel_bus;
  logic [3:0]       asi_ingress_startofpacket_bus;
  logic [3:0]       asi_ingress_endofpacket_bus;
  logic [3:0][2:0]  asi_ingress_error_bus;

  logic [OPQ_N_LANE_LOCAL-1:0][9:0] csr_drr_allowance;
  logic [OPQ_N_LANE_LOCAL-1:0]      csr_drr_allowance_reload;
  logic [OPQ_N_LANE_LOCAL-1:0]      csr_lane_mask;
  logic [1:0]                       csr_meta_page_sel;

  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_wr_hdr_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_wr_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_wr_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_rd_hdr_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_rd_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_rd_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drop_hdr_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drop_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drop_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_mask_drop_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_mask_drop_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_credit_lane_drop_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_credit_lane_drop_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_credit_ticket_drop_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_credit_ticket_drop_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_credit_other_drop_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_credit_other_drop_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_handle_drop_shd_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_handle_drop_hit_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drop_hdr_delta_q;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drop_shd_delta_q;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drop_hit_delta_q;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drr_grant_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drr_beat_cnt;
  logic [OPQ_N_LANE_LOCAL-1:0][31:0] csr_drr_defer_cnt;
  logic [31:0] csr_ft_wr_hdr_cnt;
  logic [31:0] csr_ft_wr_shd_cnt;
  logic [31:0] csr_ft_wr_hit_cnt;
  logic [31:0] csr_ft_rd_hdr_cnt;
  logic [31:0] csr_ft_rd_shd_cnt;
  logic [31:0] csr_ft_rd_hit_cnt;
  logic [31:0] csr_ft_drop_hdr_cnt;
  logic [31:0] csr_ft_drop_shd_cnt;
  logic [31:0] csr_ft_drop_hit_cnt;
  logic        csr_ft_rd_in_packet;
  logic [2:0]  csr_ft_rd_header_idx;
  logic [15:0] csr_ft_rd_hits_pending;

  logic        csr_read_d;
  logic [8:0]  csr_read_addr_d;
  logic [OPQ_N_LANE_LOCAL-1:0] csr_lane_mask_effective;
  logic [3:0]  asi_ingress_valid_eff_bus;

  logic [OPQ_N_LANE_LOCAL-1:0][LANE_FIFO_ADDR_WIDTH_CONST-1:0] native_lane_credit_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][TICKET_FIFO_ADDR_WIDTH_CONST-1:0] native_ticket_credit_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_ingress_parser_idle_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_ingress_ticket_we_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][TICKET_FIFO_DATA_WIDTH_CONST-1:0] native_ingress_ticket_wdata_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_ingress_lane_we_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_ingress_credit_drop_valid_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_ingress_credit_drop_lane_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_ingress_credit_drop_ticket_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][15:0] native_ingress_credit_drop_shd_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][15:0] native_ingress_credit_drop_hit_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_handle_we_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_handle_flag_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][MAX_PKT_LENGTH_BITS_CONST-1:0] native_handle_block_len_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_drop_valid_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][15:0] native_drop_shd_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][15:0] native_drop_hit_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0][9:0] native_drr_quantum_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_drr_req_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_drr_gnt_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_drr_lock_event_dbg;
  logic [OPQ_N_LANE_LOCAL-1:0] native_drr_defer_event_dbg;
  logic native_new_frame_dbg;
  logic native_ft_wr_page_dbg;
  logic [15:0] native_ft_wr_hit_len_dbg;
  logic native_ft_drop_valid_dbg;
  logic [31:0] native_ft_drop_hdr_dbg;
  logic [31:0] native_ft_drop_shd_dbg;
  logic [31:0] native_ft_drop_hit_dbg;
  logic native_page_allocator_active_dbg;
  logic native_arbiter_active_dbg;

  function automatic logic [31:0] pack_version_word(
    input int unsigned major_v,
    input int unsigned minor_v,
    input int unsigned patch_v,
    input int unsigned build_v
  );
    logic [31:0] word_v;
    begin
      word_v = '0;
      word_v[31:24] = major_v[7:0];
      word_v[23:16] = minor_v[7:0];
      word_v[15:12] = patch_v[3:0];
      word_v[11:0] = build_v[11:0];
      return word_v;
    end
  endfunction

  function automatic logic [31:0] sat_add32(
    input logic [31:0] count_v,
    input logic [31:0] add_v
  );
    logic [32:0] sum_v;
    begin
      sum_v = {1'b0, count_v} + {1'b0, add_v};
      if (sum_v[32]) begin
        return 32'hFFFF_FFFF;
      end
      return sum_v[31:0];
    end
  endfunction

  function automatic logic [31:0] lane_credit_visible_word(input int lane_v);
    int unsigned visible_v;
    begin
      visible_v = native_lane_credit_dbg[lane_v] + 2;
      if (visible_v > LANE_FIFO_MAX_CREDIT_CONST) begin
        visible_v = LANE_FIFO_MAX_CREDIT_CONST;
      end
      return visible_v[31:0];
    end
  endfunction

  function automatic logic [31:0] ticket_credit_visible_word(input int lane_v);
    int unsigned visible_v;
    begin
      visible_v = native_ticket_credit_dbg[lane_v] + 1;
      if (visible_v > TICKET_FIFO_MAX_CREDIT_CONST) begin
        visible_v = TICKET_FIFO_MAX_CREDIT_CONST;
      end
      return visible_v[31:0];
    end
  endfunction

  function automatic logic is_preamble_word(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K285_CONST);
  endfunction

  function automatic logic is_subheader_word(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K237_CONST);
  endfunction

  function automatic logic is_trailer_word(input logic [35:0] word_v);
    return (word_v[35:32] == 4'b0001) && (word_v[7:0] == K284_CONST);
  endfunction

  function automatic logic [31:0] csr_decode_word(input logic [8:0] addr_v);
    int lane_v;
    int lane_word_v;
    logic [31:0] csr_word_v;
    logic [31:0] status_v;
    begin
      csr_word_v = '0;
      if (addr_v >= CSR_LANE_REGION_BASE_CONST) begin
        lane_v = (int'(addr_v) - int'(CSR_LANE_REGION_BASE_CONST)) / int'(CSR_LANE_REGION_STRIDE_CONST);
        lane_word_v = (int'(addr_v) - int'(CSR_LANE_REGION_BASE_CONST)) % int'(CSR_LANE_REGION_STRIDE_CONST);
        if ((lane_v >= 0) && (lane_v < OPQ_N_LANE_LOCAL)) begin
          unique case (lane_word_v[3:0])
            4'h0: csr_word_v = csr_wr_hdr_cnt[lane_v];
            4'h1: csr_word_v = csr_wr_shd_cnt[lane_v];
            4'h2: csr_word_v = csr_wr_hit_cnt[lane_v];
            4'h3: csr_word_v = csr_rd_hdr_cnt[lane_v];
            4'h4: csr_word_v = csr_rd_shd_cnt[lane_v];
            4'h5: csr_word_v = csr_rd_hit_cnt[lane_v];
            4'h6: csr_word_v = csr_drop_hdr_cnt[lane_v];
            4'h7: csr_word_v = csr_drop_shd_cnt[lane_v];
            4'h8: csr_word_v = csr_drop_hit_cnt[lane_v];
            4'h9: csr_word_v = lane_credit_visible_word(lane_v);
            4'hA: csr_word_v = ticket_credit_visible_word(lane_v);
            4'hB: csr_word_v = {{22{1'b0}}, csr_drr_allowance[lane_v]};
            4'hC: csr_word_v = {{22{1'b0}}, native_drr_quantum_dbg[lane_v]};
            4'hD: csr_word_v = csr_drr_grant_cnt[lane_v];
            4'hE: csr_word_v = csr_drr_beat_cnt[lane_v];
            4'hF: csr_word_v = csr_drr_defer_cnt[lane_v];
            default: csr_word_v = '0;
          endcase
        end
      end else begin
        unique case (addr_v)
          CSR_WORD_UID_CONST: csr_word_v = UID_CONST;
          CSR_WORD_META_CONST: begin
            unique case (csr_meta_page_sel)
              2'b00: csr_word_v = pack_version_word(
                VERSION_MAJOR_CONST,
                VERSION_MINOR_CONST,
                VERSION_PATCH_CONST,
                VERSION_BUILD_CONST
              );
              2'b01: csr_word_v = VERSION_DATE_CONST;
              2'b10: csr_word_v = VERSION_GIT_CONST;
              default: csr_word_v = INSTANCE_ID_CONST;
            endcase
          end
          CSR_WORD_LANE_MASK_CONST: begin
            csr_word_v[OPQ_N_LANE_LOCAL-1:0] = csr_lane_mask;
          end
          CSR_WORD_CTRL_CONST: csr_word_v = '0;
          CSR_WORD_STATUS_CONST: begin
            status_v = '0;
            status_v[OPQ_N_LANE_LOCAL-1:0] = csr_lane_mask;
            status_v[16] = native_page_allocator_active_dbg;
            status_v[17] = native_arbiter_active_dbg;
            status_v[18] = aso_egress_valid;
            status_v[19] = |csr_lane_mask_effective;
            status_v[23:20] = OPQ_N_LANE_LOCAL[3:0];
            csr_word_v = status_v;
          end
          CSR_WORD_CAP_CONST: begin
            csr_word_v[4:0] = 5'h1F;
            csr_word_v[15:8] = CSR_LANE_REGION_STRIDE_CONST[7:0];
            csr_word_v[23:16] = CSR_LANE_REGION_BASE_CONST[7:0];
            csr_word_v[31:24] = OPQ_N_LANE_LOCAL[7:0];
          end
          CSR_WORD_FT_WR_HDR_CONST: csr_word_v = csr_ft_wr_hdr_cnt;
          CSR_WORD_FT_WR_SHD_CONST: csr_word_v = csr_ft_wr_shd_cnt;
          CSR_WORD_FT_WR_HIT_CONST: csr_word_v = csr_ft_wr_hit_cnt;
          CSR_WORD_FT_RD_HDR_CONST: csr_word_v = csr_ft_rd_hdr_cnt;
          CSR_WORD_FT_RD_SHD_CONST: csr_word_v = csr_ft_rd_shd_cnt;
          CSR_WORD_FT_RD_HIT_CONST: csr_word_v = csr_ft_rd_hit_cnt;
          CSR_WORD_FT_DROP_HDR_CONST: csr_word_v = csr_ft_drop_hdr_cnt;
          CSR_WORD_FT_DROP_SHD_CONST: csr_word_v = csr_ft_drop_shd_cnt;
          CSR_WORD_FT_DROP_HIT_CONST: csr_word_v = csr_ft_drop_hit_cnt;
          default: csr_word_v = '0;
        endcase
      end
      return csr_word_v;
    end
  endfunction

  assign asi_ingress_data_bus[0] = asi_ingress_0_data;
  assign asi_ingress_data_bus[1] = asi_ingress_1_data;
  assign asi_ingress_valid_bus[0] = asi_ingress_0_valid[0];
  assign asi_ingress_valid_bus[1] = asi_ingress_1_valid[0];
  assign asi_ingress_channel_bus[0] = asi_ingress_0_channel;
  assign asi_ingress_channel_bus[1] = asi_ingress_1_channel;
  assign asi_ingress_startofpacket_bus[0] = asi_ingress_0_startofpacket[0];
  assign asi_ingress_startofpacket_bus[1] = asi_ingress_1_startofpacket[0];
  assign asi_ingress_endofpacket_bus[0] = asi_ingress_0_endofpacket[0];
  assign asi_ingress_endofpacket_bus[1] = asi_ingress_1_endofpacket[0];
  assign asi_ingress_error_bus[0] = asi_ingress_0_error;
  assign asi_ingress_error_bus[1] = asi_ingress_1_error;
  assign asi_ingress_data_bus[2] = asi_ingress_2_data;
  assign asi_ingress_data_bus[3] = asi_ingress_3_data;
  assign asi_ingress_valid_bus[2] = asi_ingress_2_valid[0];
  assign asi_ingress_valid_bus[3] = asi_ingress_3_valid[0];
  assign asi_ingress_channel_bus[2] = asi_ingress_2_channel;
  assign asi_ingress_channel_bus[3] = asi_ingress_3_channel;
  assign asi_ingress_startofpacket_bus[2] = asi_ingress_2_startofpacket[0];
  assign asi_ingress_startofpacket_bus[3] = asi_ingress_3_startofpacket[0];
  assign asi_ingress_endofpacket_bus[2] = asi_ingress_2_endofpacket[0];
  assign asi_ingress_endofpacket_bus[3] = asi_ingress_3_endofpacket[0];
  assign asi_ingress_error_bus[2] = asi_ingress_2_error;
  assign asi_ingress_error_bus[3] = asi_ingress_3_error;

  ordered_priority_queue_monolithic_sv #(
    .N_LANE(OPQ_N_LANE_LOCAL),
    .LANE_FIFO_DEPTH(LANE_FIFO_DEPTH_CONST),
    .TICKET_FIFO_DEPTH(TICKET_FIFO_DEPTH_CONST),
    .HANDLE_FIFO_DEPTH(HANDLE_FIFO_DEPTH_CONST),
    .PAGE_RAM_DEPTH(PAGE_RAM_DEPTH_CONST),
    .N_SHD(OPQ_N_SHD_LOCAL),
    .N_HIT(MAX_PKT_LENGTH_CONST),
    .DEBUG_LV(OPQ_DEBUG_LEVEL_CONST)
  ) u_native (
    .asi_ingress_data(asi_ingress_data_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_valid(asi_ingress_valid_eff_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_channel(asi_ingress_channel_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_startofpacket(asi_ingress_startofpacket_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_endofpacket(asi_ingress_endofpacket_bus[`OPQ_N_LANE-1:0]),
    .asi_ingress_error(asi_ingress_error_bus[`OPQ_N_LANE-1:0]),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
      .aso_egress_endofpacket(aso_egress_endofpacket),
      .aso_egress_error(aso_egress_error),
      .ingress_lane_credit_dbg_o(native_lane_credit_dbg),
      .ingress_ticket_credit_dbg_o(native_ticket_credit_dbg),
      .ingress_parser_idle_dbg_o(native_ingress_parser_idle_dbg),
      .ingress_ticket_we_dbg_o(native_ingress_ticket_we_dbg),
      .ingress_ticket_wdata_dbg_o(native_ingress_ticket_wdata_dbg),
      .ingress_lane_we_dbg_o(native_ingress_lane_we_dbg),
      .ingress_credit_drop_valid_dbg_o(native_ingress_credit_drop_valid_dbg),
      .ingress_credit_drop_lane_dbg_o(native_ingress_credit_drop_lane_dbg),
      .ingress_credit_drop_ticket_dbg_o(native_ingress_credit_drop_ticket_dbg),
      .ingress_credit_drop_shd_cnt_dbg_o(native_ingress_credit_drop_shd_dbg),
      .ingress_credit_drop_hit_cnt_dbg_o(native_ingress_credit_drop_hit_dbg),
      .handle_we_dbg_o(native_handle_we_dbg),
      .handle_flag_dbg_o(native_handle_flag_dbg),
      .handle_block_len_dbg_o(native_handle_block_len_dbg),
      .drr_quantum_dbg_o(native_drr_quantum_dbg),
      .drr_req_dbg_o(native_drr_req_dbg),
      .drr_gnt_dbg_o(native_drr_gnt_dbg),
      .drr_lock_event_dbg_o(native_drr_lock_event_dbg),
      .drr_defer_event_dbg_o(native_drr_defer_event_dbg),
      .new_frame_dbg_o(native_new_frame_dbg),
      .ft_wr_page_dbg_o(native_ft_wr_page_dbg),
      .ft_wr_hit_len_dbg_o(native_ft_wr_hit_len_dbg),
      .ft_drop_valid_dbg_o(native_ft_drop_valid_dbg),
      .ft_drop_hdr_dbg_o(native_ft_drop_hdr_dbg),
      .ft_drop_shd_dbg_o(native_ft_drop_shd_dbg),
      .ft_drop_hit_dbg_o(native_ft_drop_hit_dbg),
      .page_allocator_active_dbg_o(native_page_allocator_active_dbg),
      .arbiter_active_dbg_o(native_arbiter_active_dbg),
      .cfg_drr_allowance_i(csr_drr_allowance),
      .cfg_drr_allowance_reload_i(csr_drr_allowance_reload),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );

    genvar g;
    generate
      for (g = 0; g < OPQ_N_LANE_LOCAL; g = g + 1) begin : g_native_dbg
      assign csr_lane_mask_effective[g] = csr_lane_mask[g] &&
        native_ingress_parser_idle_dbg[g];
    assign asi_ingress_valid_eff_bus[g] = asi_ingress_valid_bus[g] && !csr_lane_mask_effective[g];
    assign native_drop_valid_dbg[g] = (csr_lane_mask_effective[g] && asi_ingress_valid_bus[g] &&
      is_subheader_word(asi_ingress_data_bus[g])) ||
      native_ingress_credit_drop_valid_dbg[g] ||
      (native_handle_we_dbg[g] && native_handle_flag_dbg[g]);
    assign native_drop_shd_dbg[g] =
      (csr_lane_mask_effective[g] && asi_ingress_valid_bus[g] &&
        is_subheader_word(asi_ingress_data_bus[g]) ? 16'd1 : 16'd0) +
      native_ingress_credit_drop_shd_dbg[g] +
      (native_handle_we_dbg[g] && native_handle_flag_dbg[g] ? 16'd1 : 16'd0);
    assign native_drop_hit_dbg[g] =
      (csr_lane_mask_effective[g] && asi_ingress_valid_bus[g] &&
        is_subheader_word(asi_ingress_data_bus[g]) ?
          asi_ingress_data_bus[g][23:8] : 16'd0) +
      native_ingress_credit_drop_hit_dbg[g] +
      (native_handle_we_dbg[g] && native_handle_flag_dbg[g] ?
        {{(16-MAX_PKT_LENGTH_BITS_CONST){1'b0}}, native_handle_block_len_dbg[g]} : 16'd0);
    end
  endgenerate

  assign avs_csr_waitrequest = 1'b0;

  always_ff @(posedge d_clk) begin : proc_native_csr
    logic clear_counters_v;
    logic csr_ft_rd_in_packet_v;
    logic [2:0] csr_ft_rd_header_idx_v;
    logic [15:0] csr_ft_rd_hits_pending_v;

    avs_csr_readdatavalid <= 1'b0;
    if (csr_read_d) begin
      avs_csr_readdata <= csr_decode_word(csr_read_addr_d);
      avs_csr_readdatavalid <= 1'b1;
    end
    csr_read_d <= avs_csr_read;
    if (avs_csr_read) begin
      csr_read_addr_d <= avs_csr_address;
    end
    csr_drr_allowance_reload <= '0;
    clear_counters_v = 1'b0;

    if (d_reset) begin
      avs_csr_readdata <= '0;
      avs_csr_readdatavalid <= 1'b0;
      csr_meta_page_sel <= '0;
      csr_lane_mask <= '0;
      csr_drr_allowance <= '{default:DRR_DEFAULT_ALLOWANCE_CONST};
      csr_drr_allowance_reload <= '0;
      csr_wr_hdr_cnt <= '0;
      csr_wr_shd_cnt <= '0;
      csr_wr_hit_cnt <= '0;
      csr_rd_hdr_cnt <= '0;
      csr_rd_shd_cnt <= '0;
      csr_rd_hit_cnt <= '0;
      csr_drop_hdr_cnt <= '0;
      csr_drop_shd_cnt <= '0;
      csr_drop_hit_cnt <= '0;
      csr_mask_drop_shd_cnt <= '0;
      csr_mask_drop_hit_cnt <= '0;
      csr_credit_lane_drop_shd_cnt <= '0;
      csr_credit_lane_drop_hit_cnt <= '0;
      csr_credit_ticket_drop_shd_cnt <= '0;
      csr_credit_ticket_drop_hit_cnt <= '0;
      csr_credit_other_drop_shd_cnt <= '0;
      csr_credit_other_drop_hit_cnt <= '0;
      csr_handle_drop_shd_cnt <= '0;
      csr_handle_drop_hit_cnt <= '0;
      csr_drop_hdr_delta_q <= '0;
      csr_drop_shd_delta_q <= '0;
      csr_drop_hit_delta_q <= '0;
      csr_drr_grant_cnt <= '0;
      csr_drr_beat_cnt <= '0;
      csr_drr_defer_cnt <= '0;
      csr_ft_wr_hdr_cnt <= '0;
      csr_ft_wr_shd_cnt <= '0;
      csr_ft_wr_hit_cnt <= '0;
      csr_ft_rd_hdr_cnt <= '0;
      csr_ft_rd_shd_cnt <= '0;
      csr_ft_rd_hit_cnt <= '0;
      csr_ft_drop_hdr_cnt <= '0;
      csr_ft_drop_shd_cnt <= '0;
      csr_ft_drop_hit_cnt <= '0;
      csr_ft_rd_in_packet <= 1'b0;
      csr_ft_rd_header_idx <= '0;
      csr_ft_rd_hits_pending <= '0;
      csr_read_d <= 1'b0;
      csr_read_addr_d <= '0;
    end else begin
      if (avs_csr_write) begin
        if (avs_csr_address >= CSR_LANE_REGION_BASE_CONST) begin
          int lane_v;
          int lane_word_v;
          lane_v = (int'(avs_csr_address) - int'(CSR_LANE_REGION_BASE_CONST)) /
            int'(CSR_LANE_REGION_STRIDE_CONST);
          lane_word_v = (int'(avs_csr_address) - int'(CSR_LANE_REGION_BASE_CONST)) %
            int'(CSR_LANE_REGION_STRIDE_CONST);
          if ((lane_v >= 0) && (lane_v < OPQ_N_LANE_LOCAL)) begin
            if (lane_word_v[3:0] == CSR_LANE_WORD_DRR_ALLOWANCE_CONST) begin
              csr_drr_allowance[lane_v] <= avs_csr_writedata[9:0];
              csr_drr_allowance_reload[lane_v] <= 1'b1;
            end
          end
        end else begin
          unique case (avs_csr_address)
            CSR_WORD_META_CONST: begin
              csr_meta_page_sel <= avs_csr_writedata[1:0];
            end
            CSR_WORD_LANE_MASK_CONST: begin
              csr_lane_mask <= avs_csr_writedata[OPQ_N_LANE_LOCAL-1:0];
            end
            CSR_WORD_CTRL_CONST: begin
              clear_counters_v = avs_csr_writedata[0];
            end
            default: begin
            end
          endcase
        end
      end

      if (clear_counters_v) begin
        csr_wr_hdr_cnt <= '0;
        csr_wr_shd_cnt <= '0;
        csr_wr_hit_cnt <= '0;
        csr_rd_hdr_cnt <= '0;
        csr_rd_shd_cnt <= '0;
        csr_rd_hit_cnt <= '0;
        csr_drop_hdr_cnt <= '0;
        csr_drop_shd_cnt <= '0;
        csr_drop_hit_cnt <= '0;
        csr_mask_drop_shd_cnt <= '0;
        csr_mask_drop_hit_cnt <= '0;
        csr_credit_lane_drop_shd_cnt <= '0;
        csr_credit_lane_drop_hit_cnt <= '0;
        csr_credit_ticket_drop_shd_cnt <= '0;
        csr_credit_ticket_drop_hit_cnt <= '0;
        csr_credit_other_drop_shd_cnt <= '0;
        csr_credit_other_drop_hit_cnt <= '0;
        csr_handle_drop_shd_cnt <= '0;
        csr_handle_drop_hit_cnt <= '0;
        csr_drop_hdr_delta_q <= '0;
        csr_drop_shd_delta_q <= '0;
        csr_drop_hit_delta_q <= '0;
        csr_drr_grant_cnt <= '0;
        csr_drr_beat_cnt <= '0;
        csr_drr_defer_cnt <= '0;
        csr_ft_wr_hdr_cnt <= '0;
        csr_ft_wr_shd_cnt <= '0;
        csr_ft_wr_hit_cnt <= '0;
        csr_ft_rd_hdr_cnt <= '0;
        csr_ft_rd_shd_cnt <= '0;
        csr_ft_rd_hit_cnt <= '0;
        csr_ft_drop_hdr_cnt <= '0;
        csr_ft_drop_shd_cnt <= '0;
        csr_ft_drop_hit_cnt <= '0;
        csr_ft_rd_in_packet <= 1'b0;
        csr_ft_rd_header_idx <= '0;
        csr_ft_rd_hits_pending <= '0;
      end else begin
        for (int lane = 0; lane < OPQ_N_LANE_LOCAL; lane++) begin
          logic [31:0] drop_hdr_delta_v;
          logic [DROP_SHD_DELTA_BITS_CONST-1:0] drop_shd_delta_v;
          logic [DROP_HIT_DELTA_BITS_CONST-1:0] drop_hit_delta_v;

          drop_hdr_delta_v = '0;
          drop_shd_delta_v = '0;
          drop_hit_delta_v = '0;

          if (csr_drop_hdr_delta_q[lane] != '0) begin
            csr_drop_hdr_cnt[lane] <= sat_add32(csr_drop_hdr_cnt[lane], csr_drop_hdr_delta_q[lane]);
          end
          if (csr_drop_shd_delta_q[lane] != '0) begin
            csr_drop_shd_cnt[lane] <= sat_add32(csr_drop_shd_cnt[lane], csr_drop_shd_delta_q[lane]);
          end
          if (csr_drop_hit_delta_q[lane] != '0) begin
            csr_drop_hit_cnt[lane] <= sat_add32(csr_drop_hit_cnt[lane], csr_drop_hit_delta_q[lane]);
          end

          if (asi_ingress_valid_bus[lane]) begin
            if (asi_ingress_startofpacket_bus[lane] &&
                is_preamble_word(asi_ingress_data_bus[lane]) &&
                !asi_ingress_error_bus[lane][2]) begin
              if (csr_lane_mask_effective[lane]) begin
                drop_hdr_delta_v = 32'd1;
              end else begin
                csr_wr_hdr_cnt[lane] <= sat_add32(csr_wr_hdr_cnt[lane], 32'd1);
                csr_rd_hdr_cnt[lane] <= sat_add32(csr_rd_hdr_cnt[lane], 32'd1);
              end
            end
          end

          if (native_ingress_ticket_we_dbg[lane] &&
              !native_ingress_ticket_wdata_dbg[lane][TICKET_ALT_SOP_LOC_CONST]) begin
            csr_wr_shd_cnt[lane] <= sat_add32(csr_wr_shd_cnt[lane], 32'd1);
            csr_rd_shd_cnt[lane] <= sat_add32(csr_rd_shd_cnt[lane], 32'd1);
          end

          if (native_ingress_lane_we_dbg[lane]) begin
            csr_wr_hit_cnt[lane] <= sat_add32(csr_wr_hit_cnt[lane], 32'd1);
            csr_rd_hit_cnt[lane] <= sat_add32(csr_rd_hit_cnt[lane], 32'd1);
          end

          if (csr_lane_mask_effective[lane] && asi_ingress_valid_bus[lane] &&
              is_subheader_word(asi_ingress_data_bus[lane])) begin
            drop_shd_delta_v = drop_shd_delta_v +
              {{(DROP_SHD_DELTA_BITS_CONST-1){1'b0}}, 1'b1};
            drop_hit_delta_v = drop_hit_delta_v +
              {{(DROP_HIT_DELTA_BITS_CONST-16){1'b0}}, asi_ingress_data_bus[lane][23:8]};
            csr_mask_drop_shd_cnt[lane] <= sat_add32(csr_mask_drop_shd_cnt[lane], 32'd1);
            csr_mask_drop_hit_cnt[lane] <=
              sat_add32(csr_mask_drop_hit_cnt[lane], {16'd0, asi_ingress_data_bus[lane][23:8]});
          end

          if (native_ingress_credit_drop_valid_dbg[lane]) begin
            drop_shd_delta_v = drop_shd_delta_v +
              {{(DROP_SHD_DELTA_BITS_CONST-16){1'b0}}, native_ingress_credit_drop_shd_dbg[lane]};
            drop_hit_delta_v = drop_hit_delta_v +
              {{(DROP_HIT_DELTA_BITS_CONST-16){1'b0}}, native_ingress_credit_drop_hit_dbg[lane]};
            if (native_ingress_credit_drop_lane_dbg[lane]) begin
              csr_credit_lane_drop_shd_cnt[lane] <=
                sat_add32(csr_credit_lane_drop_shd_cnt[lane],
                          {16'd0, native_ingress_credit_drop_shd_dbg[lane]});
              csr_credit_lane_drop_hit_cnt[lane] <=
                sat_add32(csr_credit_lane_drop_hit_cnt[lane],
                          {16'd0, native_ingress_credit_drop_hit_dbg[lane]});
            end else if (native_ingress_credit_drop_ticket_dbg[lane]) begin
              csr_credit_ticket_drop_shd_cnt[lane] <=
                sat_add32(csr_credit_ticket_drop_shd_cnt[lane],
                          {16'd0, native_ingress_credit_drop_shd_dbg[lane]});
              csr_credit_ticket_drop_hit_cnt[lane] <=
                sat_add32(csr_credit_ticket_drop_hit_cnt[lane],
                          {16'd0, native_ingress_credit_drop_hit_dbg[lane]});
            end else begin
              csr_credit_other_drop_shd_cnt[lane] <=
                sat_add32(csr_credit_other_drop_shd_cnt[lane],
                          {16'd0, native_ingress_credit_drop_shd_dbg[lane]});
              csr_credit_other_drop_hit_cnt[lane] <=
                sat_add32(csr_credit_other_drop_hit_cnt[lane],
                          {16'd0, native_ingress_credit_drop_hit_dbg[lane]});
            end
          end

          if (native_handle_we_dbg[lane] && native_handle_flag_dbg[lane]) begin
            drop_shd_delta_v = drop_shd_delta_v +
              {{(DROP_SHD_DELTA_BITS_CONST-1){1'b0}}, 1'b1};
            drop_hit_delta_v = drop_hit_delta_v +
              {{(DROP_HIT_DELTA_BITS_CONST-MAX_PKT_LENGTH_BITS_CONST){1'b0}}, native_handle_block_len_dbg[lane]};
            csr_handle_drop_shd_cnt[lane] <= sat_add32(csr_handle_drop_shd_cnt[lane], 32'd1);
            csr_handle_drop_hit_cnt[lane] <=
              sat_add32(csr_handle_drop_hit_cnt[lane],
                        {{(32-MAX_PKT_LENGTH_BITS_CONST){1'b0}}, native_handle_block_len_dbg[lane]});
          end

          csr_drop_hdr_delta_q[lane] <= drop_hdr_delta_v;
          csr_drop_shd_delta_q[lane] <= {{(32-DROP_SHD_DELTA_BITS_CONST){1'b0}}, drop_shd_delta_v};
          csr_drop_hit_delta_q[lane] <= {{(32-DROP_HIT_DELTA_BITS_CONST){1'b0}}, drop_hit_delta_v};

          if (native_drr_lock_event_dbg[lane]) begin
            csr_drr_grant_cnt[lane] <= sat_add32(csr_drr_grant_cnt[lane], 32'd1);
          end
          if (native_drr_gnt_dbg[lane] && native_drr_req_dbg[lane]) begin
            csr_drr_beat_cnt[lane] <= sat_add32(csr_drr_beat_cnt[lane], 32'd1);
          end
          if (native_drr_defer_event_dbg[lane]) begin
            csr_drr_defer_cnt[lane] <= sat_add32(csr_drr_defer_cnt[lane], 32'd1);
          end
        end

        if (native_new_frame_dbg) begin
          csr_ft_wr_hdr_cnt <= sat_add32(csr_ft_wr_hdr_cnt, 32'd1);
        end
        if (native_ft_wr_page_dbg) begin
          csr_ft_wr_shd_cnt <= sat_add32(csr_ft_wr_shd_cnt, 32'd1);
          csr_ft_wr_hit_cnt <= sat_add32(csr_ft_wr_hit_cnt, {16'd0, native_ft_wr_hit_len_dbg});
        end
        if (native_ft_drop_valid_dbg) begin
          csr_ft_drop_hdr_cnt <= sat_add32(csr_ft_drop_hdr_cnt, native_ft_drop_hdr_dbg);
          csr_ft_drop_shd_cnt <= sat_add32(csr_ft_drop_shd_cnt, native_ft_drop_shd_dbg);
          csr_ft_drop_hit_cnt <= sat_add32(csr_ft_drop_hit_cnt, native_ft_drop_hit_dbg);
        end

        csr_ft_rd_in_packet_v = csr_ft_rd_in_packet;
        csr_ft_rd_header_idx_v = csr_ft_rd_header_idx;
        csr_ft_rd_hits_pending_v = csr_ft_rd_hits_pending;
        if (aso_egress_valid && aso_egress_ready) begin
          if (!csr_ft_rd_in_packet_v || aso_egress_startofpacket) begin
            csr_ft_rd_in_packet_v = 1'b1;
            csr_ft_rd_header_idx_v = '0;
            csr_ft_rd_hits_pending_v = '0;
          end

          if (csr_ft_rd_in_packet_v) begin
            if (csr_ft_rd_header_idx_v < HDR_SIZE_CONST[2:0]) begin
              if ((csr_ft_rd_header_idx_v == 3'd0) && is_preamble_word(aso_egress_data)) begin
                csr_ft_rd_hdr_cnt <= sat_add32(csr_ft_rd_hdr_cnt, 32'd1);
              end
              csr_ft_rd_header_idx_v = csr_ft_rd_header_idx_v + 3'd1;
            end else if (csr_ft_rd_hits_pending_v != 16'd0) begin
              if (aso_egress_data[35:32] == 4'b0000) begin
                csr_ft_rd_hit_cnt <= sat_add32(csr_ft_rd_hit_cnt, 32'd1);
              end
              csr_ft_rd_hits_pending_v = csr_ft_rd_hits_pending_v - 16'd1;
            end else if (is_subheader_word(aso_egress_data)) begin
              csr_ft_rd_shd_cnt <= sat_add32(csr_ft_rd_shd_cnt, 32'd1);
              csr_ft_rd_hits_pending_v = aso_egress_data[23:8];
            end else if (is_trailer_word(aso_egress_data) || aso_egress_endofpacket) begin
              csr_ft_rd_in_packet_v = 1'b0;
              csr_ft_rd_header_idx_v = '0;
              csr_ft_rd_hits_pending_v = '0;
            end
          end
        end
        csr_ft_rd_in_packet <= csr_ft_rd_in_packet_v;
        csr_ft_rd_header_idx <= csr_ft_rd_header_idx_v;
        csr_ft_rd_hits_pending <= csr_ft_rd_hits_pending_v;
      end

    end
  end

// synthesis translate_off
`ifndef SYNTHESIS
  typedef struct packed {
    logic        in_frame;
    logic [2:0]  field_index;
    logic [31:0] ts_high;
    logic [15:0] ts_low;
    logic [15:0] frame_id;
    logic [7:0]  shd;
    logic [15:0] hits_pending;
  } opq_debug_trace_state_t;

  opq_debug_trace_state_t opq_debug_ingress_state[OPQ_N_LANE_LOCAL];
  opq_debug_trace_state_t opq_debug_egress_state;

  task automatic opq_debug_trace_word(
    input string stage_v,
    input int lane_v,
    input logic sop_v,
    input logic eop_v,
    input logic [35:0] word_v,
    inout opq_debug_trace_state_t state_v
  );
    logic [3:0]  datak_v;
    logic [31:0] data_v;
    logic [47:0] bucket_v;
    begin
      datak_v = word_v[35:32];
      data_v = word_v[31:0];
      if ((datak_v == 4'h1) && (data_v[7:0] == K285_CONST) && sop_v) begin
        state_v = '0;
        state_v.in_frame = 1'b1;
        state_v.field_index = 3'd1;
      end else if (state_v.in_frame) begin
        if ((datak_v == 4'h1) && (data_v[7:0] == K284_CONST) && eop_v) begin
          state_v = '0;
        end else if (state_v.field_index == 3'd1) begin
          state_v.ts_high = data_v;
          state_v.field_index = 3'd2;
        end else if (state_v.field_index == 3'd2) begin
          state_v.ts_low = data_v[31:16];
          state_v.frame_id = data_v[15:0];
          state_v.field_index = 3'd3;
        end else if (state_v.field_index < 3'd5) begin
          state_v.field_index = state_v.field_index + 3'd1;
        end else if ((datak_v == 4'h1) && (data_v[7:0] == K237_CONST)) begin
          state_v.shd = data_v[31:24];
          state_v.hits_pending = data_v[23:8];
        end else if ((datak_v == 4'h0) && (state_v.hits_pending != 16'd0)) begin
          bucket_v = {state_v.ts_high, state_v.ts_low} + {36'd0, state_v.shd, 4'd0};
          $display(
            "OPQ_DEBUG_HIT stage=%s level=%0d lane=%0d time_ps=%0t frame_id=%0d ts_high=0x%08h ts_low=0x%04h shd=%0d bucket_8ns=0x%012h asic=%0d channel=%0d hit_id9=%0d ts_nibble=%0d rem=%0d fine=%0d word=0x%08h",
            stage_v,
            OPQ_DEBUG_LEVEL_CONST,
            lane_v,
            $time,
            state_v.frame_id,
            state_v.ts_high,
            state_v.ts_low,
            state_v.shd,
            bucket_v,
            data_v[25:22],
            data_v[21:17],
            data_v[8:0],
            data_v[31:28],
            data_v[16:14],
            data_v[13:9],
            data_v
          );
          state_v.hits_pending = state_v.hits_pending - 16'd1;
        end
      end
    end
  endtask

  always_ff @(posedge d_clk) begin : proc_native_debug_trace
    if (d_reset) begin
      opq_debug_ingress_state <= '{default:'0};
      opq_debug_egress_state <= '0;
    end else if (OPQ_DEBUG_LEVEL_CONST >= 2) begin
      for (int lane = 0; lane < OPQ_N_LANE_LOCAL; lane++) begin
        if (asi_ingress_valid_eff_bus[lane]) begin
          opq_debug_trace_word(
            "ingress",
            lane,
            asi_ingress_startofpacket_bus[lane],
            asi_ingress_endofpacket_bus[lane],
            asi_ingress_data_bus[lane],
            opq_debug_ingress_state[lane]
          );
        end
      end
      if (aso_egress_valid && aso_egress_ready) begin
        opq_debug_trace_word(
          "egress",
          0,
          aso_egress_startofpacket,
          aso_egress_endofpacket,
          {aso_egress_data[35:32], aso_egress_data[31:0]},
          opq_debug_egress_state
        );
      end
    end
  end

  final begin : proc_native_summary
    if (OPQ_DEBUG_LEVEL_CONST >= 1) begin
      $display(
        "OPQ_NATIVE_SUMMARY debug_level=%0d n_lane=%0d n_shd=%0d n_hit=%0d lane_fifo_depth=%0d ticket_fifo_depth=%0d handle_fifo_depth=%0d page_ram_depth=%0d ft_wr_hdr=%0d ft_wr_shd=%0d ft_wr_hit=%0d ft_rd_hdr=%0d ft_rd_shd=%0d ft_rd_hit=%0d ft_drop_hdr=%0d ft_drop_shd=%0d ft_drop_hit=%0d",
        OPQ_DEBUG_LEVEL_CONST,
        OPQ_N_LANE_LOCAL,
        OPQ_N_SHD_LOCAL,
        MAX_PKT_LENGTH_CONST,
        LANE_FIFO_DEPTH_CONST,
        TICKET_FIFO_DEPTH_CONST,
        HANDLE_FIFO_DEPTH_CONST,
        PAGE_RAM_DEPTH_CONST,
        csr_ft_wr_hdr_cnt,
        csr_ft_wr_shd_cnt,
        csr_ft_wr_hit_cnt,
        csr_ft_rd_hdr_cnt,
        csr_ft_rd_shd_cnt,
        csr_ft_rd_hit_cnt,
        csr_ft_drop_hdr_cnt,
        csr_ft_drop_shd_cnt,
        csr_ft_drop_hit_cnt
      );
      for (int lane = 0; lane < OPQ_N_LANE_LOCAL; lane++) begin
        $display(
          "OPQ_NATIVE_LANE_SUMMARY lane=%0d wr_hdr=%0d wr_shd=%0d wr_hit=%0d rd_hdr=%0d rd_shd=%0d rd_hit=%0d drop_hdr=%0d drop_shd=%0d drop_hit=%0d mask_drop_shd=%0d mask_drop_hit=%0d credit_lane_drop_shd=%0d credit_lane_drop_hit=%0d credit_ticket_drop_shd=%0d credit_ticket_drop_hit=%0d credit_other_drop_shd=%0d credit_other_drop_hit=%0d handle_drop_shd=%0d handle_drop_hit=%0d drr_grant=%0d drr_beat=%0d drr_defer=%0d lane_credit_visible=%0d ticket_credit_visible=%0d",
          lane,
          csr_wr_hdr_cnt[lane],
          csr_wr_shd_cnt[lane],
          csr_wr_hit_cnt[lane],
          csr_rd_hdr_cnt[lane],
          csr_rd_shd_cnt[lane],
          csr_rd_hit_cnt[lane],
          csr_drop_hdr_cnt[lane],
          csr_drop_shd_cnt[lane],
          csr_drop_hit_cnt[lane],
          csr_mask_drop_shd_cnt[lane],
          csr_mask_drop_hit_cnt[lane],
          csr_credit_lane_drop_shd_cnt[lane],
          csr_credit_lane_drop_hit_cnt[lane],
          csr_credit_ticket_drop_shd_cnt[lane],
          csr_credit_ticket_drop_hit_cnt[lane],
          csr_credit_other_drop_shd_cnt[lane],
          csr_credit_other_drop_hit_cnt[lane],
          csr_handle_drop_shd_cnt[lane],
          csr_handle_drop_hit_cnt[lane],
          csr_drr_grant_cnt[lane],
          csr_drr_beat_cnt[lane],
          csr_drr_defer_cnt[lane],
          lane_credit_visible_word(lane),
          ticket_credit_visible_word(lane)
        );
      end
    end
  end
`endif
// synthesis translate_on
`else
  ordered_priority_queue_dut u_vhdl (
    .asi_ingress_0_data(asi_ingress_0_data),
    .asi_ingress_0_valid(asi_ingress_0_valid),
    .asi_ingress_0_channel(asi_ingress_0_channel),
    .asi_ingress_0_startofpacket(asi_ingress_0_startofpacket),
    .asi_ingress_0_endofpacket(asi_ingress_0_endofpacket),
    .asi_ingress_0_error(asi_ingress_0_error),
    .asi_ingress_1_data(asi_ingress_1_data),
    .asi_ingress_1_valid(asi_ingress_1_valid),
    .asi_ingress_1_channel(asi_ingress_1_channel),
    .asi_ingress_1_startofpacket(asi_ingress_1_startofpacket),
    .asi_ingress_1_endofpacket(asi_ingress_1_endofpacket),
    .asi_ingress_1_error(asi_ingress_1_error),
    .aso_egress_data(aso_egress_data),
    .aso_egress_valid(aso_egress_valid),
    .aso_egress_ready(aso_egress_ready),
    .aso_egress_startofpacket(aso_egress_startofpacket),
    .aso_egress_endofpacket(aso_egress_endofpacket),
    .aso_egress_error(aso_egress_error),
    .avs_csr_address(avs_csr_address),
    .avs_csr_read(avs_csr_read),
    .avs_csr_write(avs_csr_write),
    .avs_csr_writedata(avs_csr_writedata),
    .avs_csr_readdata(avs_csr_readdata),
    .avs_csr_readdatavalid(avs_csr_readdatavalid),
    .avs_csr_waitrequest(avs_csr_waitrequest),
    .avs_csr_burstcount(avs_csr_burstcount),
    .d_clk(d_clk),
    .d_reset(d_reset)
  );
`endif
endmodule
