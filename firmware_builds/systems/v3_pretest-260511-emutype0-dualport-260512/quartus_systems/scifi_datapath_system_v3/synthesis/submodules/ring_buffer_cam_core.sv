// File name: ring_buffer_cam_core.sv
// Author  : Yifeng Wang (yifenwan@phys.ethz.ch), Codex migration
// Version : 26.2.12
// Date    : 20260513
// Change  : add N_SHD-controlled subframe key/epoch mapping

module ring_buffer_cam_core #(
  parameter int SEARCH_KEY_WIDTH    = 8,
  parameter int N_SHD               = 128,
  parameter int RING_BUFFER_N_ENTRY = 512,
  parameter int SIDE_DATA_BITS      = 31,
  parameter int INTERLEAVING_FACTOR = 4,
  parameter int INTERLEAVING_INDEX  = 0,
  parameter int N_PARTITIONS        = 4,
  parameter int ENCODER_LEAF_WIDTH  = 16,
  parameter int ENCODER_PIPE_STAGES = 4,
  parameter int IP_UID              = 32'h5242_434d,
  parameter int VERSION_MAJOR       = 26,
  parameter int VERSION_MINOR       = 2,
  parameter int VERSION_PATCH       = 12,
  parameter int BUILD               = 513,
  parameter int VERSION_DATE        = 20260513,
  parameter int VERSION_GIT         = 0,
  parameter int INSTANCE_ID         = 0,
  parameter int DEBUG               = 0
) (
  output logic [31:0] avs_csr_readdata,
  input  logic        avs_csr_read,
  input  logic [4:0]  avs_csr_address,
  output logic        avs_csr_waitrequest,
  input  logic        avs_csr_write,
  input  logic [31:0] avs_csr_writedata,

  input  logic [8:0]  asi_ctrl_data,
  input  logic        asi_ctrl_valid,
  output logic        asi_ctrl_ready,

  input  logic [3:0]  asi_hit_type1_channel,
  input  logic        asi_hit_type1_startofpacket,
  input  logic        asi_hit_type1_endofpacket,
  input  logic        asi_hit_type1_empty,
  input  logic [38:0] asi_hit_type1_data,
  input  logic        asi_hit_type1_valid,
  output logic        asi_hit_type1_ready,
  input  logic [0:0]  asi_hit_type1_error,
  input  logic [63:0] asi_hit_type1_metadata,
  input  logic        asi_hit_type1_metadata_valid,

  output logic [3:0]  aso_hit_type2_channel,
  output logic        aso_hit_type2_startofpacket,
  output logic        aso_hit_type2_endofpacket,
  output logic [35:0] aso_hit_type2_data,
  output logic        aso_hit_type2_valid,
  input  logic        aso_hit_type2_ready,
  output logic [0:0]  aso_hit_type2_error,
  output logic [63:0] aso_hit_type2_metadata,
  output logic        aso_hit_type2_metadata_valid,

  output logic        aso_filllevel_valid,
  output logic [15:0] aso_filllevel_data,
  output logic [31:0] coe_debug_fill_level,
  output logic [31:0] coe_debug_fifo_level,
  output logic [31:0] coe_debug_queue_state,

  input  logic        i_rst,
  input  logic        i_clk
);
  import ring_buffer_cam_sv_pkg::*;

  localparam int ADDR_W_CONST          = (RING_BUFFER_N_ENTRY <= 2) ? 1 : $clog2(RING_BUFFER_N_ENTRY);
  localparam int DEASM_DEPTH_CONST     = 64;
  localparam int POP_CMD_DEPTH_CONST   = 16;
  localparam int LOCK_SECTOR_COUNT_CONST = 8;
  localparam int LOCK_SECTOR_BITS_CONST = 3;
  localparam int ADDR_SECTOR_LSB_CONST =
    (ADDR_W_CONST > LOCK_SECTOR_BITS_CONST) ?
    (ADDR_W_CONST - LOCK_SECTOR_BITS_CONST) : 0;
  localparam int CAM_KEY_WIDTH_CONST    = 8;
  localparam int CAM_KEY_COUNT_CONST    = 1 << CAM_KEY_WIDTH_CONST;
  localparam int CAM_FLUSH_CYCLES_CONST = RING_BUFFER_N_ENTRY * CAM_KEY_COUNT_CONST;
  localparam int FLUSH_COUNT_W_CONST    =
    (CAM_FLUSH_CYCLES_CONST <= 2) ? 1 : $clog2(CAM_FLUSH_CYCLES_CONST + 1);
  localparam int SIDE_META_WIDTH_CONST  = 65;
  localparam int POP_COUNT_CHUNK_WIDTH_CONST = 16;
  localparam int POP_COUNT_CHUNKS_CONST =
    (RING_BUFFER_N_ENTRY + POP_COUNT_CHUNK_WIDTH_CONST - 1) /
    POP_COUNT_CHUNK_WIDTH_CONST;
  localparam int POP_COUNT_CHUNK_W_CONST =
    (POP_COUNT_CHUNKS_CONST <= 2) ? 1 : $clog2(POP_COUNT_CHUNKS_CONST);
  localparam logic [8:0] CTRL_IDLE_CONST        = 9'b0_0000_0001;
  localparam logic [8:0] CTRL_RUN_PREPARE_CONST = 9'b0_0000_0010;
  localparam logic [8:0] CTRL_SYNC_CONST        = 9'b0_0000_0100;
  localparam logic [8:0] CTRL_RUNNING_CONST     = 9'b0_0000_1000;
  localparam logic [8:0] CTRL_TERMINATING_CONST = 9'b0_0001_0000;
  localparam logic [8:0] CTRL_LINK_TEST_CONST   = 9'b0_0010_0000;

  typedef struct packed {
    logic [39:0] hit_word;
    logic [63:0] metadata;
    logic        metadata_valid;
  } deasm_word_t;
  localparam int DEASM_WORD_BITS_CONST = $bits(deasm_word_t);

  function automatic logic [7:0] tcc8n_search_key_local(input logic [12:0] tcc8n);
    return tcc8n[SK_LO_CONST +: CAM_KEY_WIDTH_CONST];
  endfunction

  function automatic logic [8:0] tcc8n_search_epoch_local(input logic [12:0] tcc8n);
    return {tcc8n[SK_LO_CONST + CAM_KEY_WIDTH_CONST], tcc8n_search_key_local(tcc8n)};
  endfunction

  function automatic logic [7:0] pop_cmd_search_key_local(input logic [8:0] pop_cmd);
    return pop_cmd[7:0];
  endfunction

  function automatic logic pop_cmd_epoch_bit_local(input logic [8:0] pop_cmd);
    return pop_cmd[8];
  endfunction

  function automatic logic [8:0] read_time_pop_cmd_local(input logic [47:0] read_time);
    return read_time[SK_LO_CONST + CAM_KEY_WIDTH_CONST:SK_LO_CONST];
  endfunction

  typedef enum logic [1:0] {
    PUSH_WRITING = 2'd0,
    PUSH_ERASING = 2'd1
  } push_state_e;

  run_state_e run_state_cmd;
  pop_state_e pop_engine_state;
  push_state_e push_state;
  debug_msg_t debug_msg2;
  debug_msg_t debug_msg2_snap;

  logic csr_go;
  logic csr_soft_reset_pulse;
  logic csr_filter_inerr;
  logic csr_counter_freeze;
  logic [31:0] csr_expected_latency;
  logic [1:0] csr_meta_sel;
  logic [47:0] expected_latency_48b;
  logic [47:0] read_time_ptr;
  logic [47:0] read_time_ptr_comb;
  logic read_time_valid;
  logic [47:0] gts_8n;
  logic [47:0] gts_end_of_run;
  logic gts_counter_rst;

  deasm_word_t deassembly_fifo_din;
  deasm_word_t deassembly_fifo_dout;
  logic deassembly_fifo_wrreq;
  logic deassembly_fifo_rdack;
  logic deassembly_fifo_empty;
  logic deassembly_fifo_full;
  logic deassembly_fifo_sclr;
  logic [$clog2(DEASM_DEPTH_CONST+1)-1:0] deassembly_fifo_usedw_int;
  logic [7:0] deassembly_fifo_usedw;
  logic ingress_active_window;
  logic ingress_lane_match;
  logic ingress_payload_countable;
  logic deasm_full_drop_event;

  logic [8:0] pop_cmd_fifo_din;
  logic [8:0] pop_cmd_fifo_dout;
  logic pop_cmd_fifo_wrreq;
  logic pop_cmd_fifo_rdack;
  logic pop_cmd_fifo_empty;
  logic pop_cmd_fifo_full;
  logic pop_cmd_fifo_sclr;
  logic [$clog2(POP_CMD_DEPTH_CONST+1)-1:0] pop_cmd_fifo_usedw_int;
  logic [3:0] pop_cmd_fifo_usedw;
  logic pop_cmd_tick_due;
  logic pop_cmd_full_drop_event;

  logic [RING_BUFFER_N_ENTRY-1:0] slot_valid;
  logic [ADDR_W_CONST-1:0] write_pointer;

  logic in_payload_valid;
  logic [38:0] in_hit_side;
  logic [12:0] in_hit_ts8n;
  logic [7:0] in_hit_sk;

  logic push_write_req;
  logic push_write_allowed;
  logic push_write_sector_locked;
  logic push_erase_sector_locked;
  logic [LOCK_SECTOR_COUNT_CONST-1:0] pop_sector_lock_mask;
  logic push_write_grant;
  logic push_erase_req;
  logic push_erase_grant;
  logic [7:0] push_write_sk_reg;
  logic [7:0] push_erase_sk;
  logic push_check_valid;
  logic push_check_occupied;
  logic [ADDR_W_CONST-1:0] push_erase_addr_reg;
  logic [39:0] overwritten_side_word;

  logic [2:0] decision;
  logic [2:0] decision_reg;
  logic cam_wr_en;
  logic cam_erase_en;
  logic [15:0] cam_wr_addr;
  logic [7:0] cam_wr_data;
  logic [RING_BUFFER_N_ENTRY-1:0] cam_match_addr_oh;
  logic [15:0] side_ram_waddr;
  logic [39:0] side_ram_din;
  logic side_ram_we;
  logic [15:0] side_ram_raddr;
  logic [39:0] side_ram_raw_dout;
  logic [39:0] side_ram_dout;
  logic [SIDE_META_WIDTH_CONST-1:0] side_meta_ram_din;
  logic [SIDE_META_WIDTH_CONST-1:0] side_meta_ram_dout;

  logic [RING_BUFFER_N_ENTRY-1:0] pop_snapshot;
  logic [LOCK_SECTOR_COUNT_CONST-1:0] pop_snapshot_sector_mask;
  logic [RING_BUFFER_N_ENTRY-1:0] pop_scan_mask;
  logic [ADDR_W_CONST-1:0] pop_scan_addr;
  logic [RING_BUFFER_N_ENTRY-1:0] pop_count_mask;
  logic [POP_COUNT_CHUNK_W_CONST-1:0] pop_count_chunk_idx;
  logic [15:0] pop_count_acc;
  logic [15:0] pop_count_next;
  logic [POP_COUNT_CHUNK_WIDTH_CONST-1:0] pop_count_chunk_vec;
  logic [4:0] pop_count_chunk_hits;
  logic [8:0] pop_current_sk;
  logic [7:0] pop_current_cam_key;
  logic [7:0] pop_current_subheader_key;
  logic pop_current_epoch_bit;
  logic [15:0] pop_total_hits;
  logic [15:0] pop_hits_count;
  logic [15:0] pop_issue_addr;
  logic [15:0] pop_issue_addr_pending;
  logic [38:0] pop_hit_pending;
  logic [63:0] pop_metadata_pending;
  logic pop_metadata_valid_pending;
  logic pop_occupied_pending;
  logic pop_output_pending;
  logic pop_issue_inflight;
  logic pop_ram_read_pending;
  logic pop_emit_pending;
  logic pop_erase_req;
  logic pop_erase_grant;
  logic pop_flush_req;
  logic pop_flush_grant;
  logic pop_pipeline_start;
  logic pop_hit_valid;
  logic [8:0] pop_hit_pending_epoch;
  logic pop_cache_miss_pulse;
  logic pop_last_hit_pending;
  logic subheader_gen_done;
  logic [2:0] pop_search_wait_cnt;
  logic [1:0] dbg_pop_rr_idx;
  logic [1:0] dbg_pop_issue_partition_idx;
  logic [1:0] dbg_pop_count_partition_idx;
  logic [3:0] dbg_pop_partition_pending;
  logic [3:0] dbg_pop_partition_load;
  logic [3:0] dbg_pop_partition_advance;
  logic [3:0] dbg_pop_partition_result_valid;
  logic [3:0] dbg_pop_partition_flag;
  logic [3:0] dbg_pop_partition_has_more;
  logic [3:0] dbg_pop_partition_eval_stage0_valid;
  logic egress_not_ready_drop_event;
  logic [31:0] fill_level_word;

  logic endofrun_seen;
  logic terminating_drain_done;
  logic run_mgmt_flush_memory_start;
  logic run_mgmt_flush_memory_done;
  logic run_mgmt_flushed;
  logic pop_flush_ram_done;
  logic pop_flush_cam_done;
  logic [15:0] flush_ram_wraddr;
  logic [15:0] flush_cam_wraddr;
  logic [15:0] flush_cam_wrdata;
  logic [FLUSH_COUNT_W_CONST-1:0] flush_cycle_count;
  logic prep_ready_latched;

  wire dbg_side_ram_patch_we;
  wire [ADDR_W_CONST-1:0] dbg_side_ram_patch_addr;
  wire [39:0] dbg_side_ram_patch_data;

  assign avs_csr_waitrequest = 1'b0;
  assign dbg_side_ram_patch_we = 1'b0;
  assign dbg_side_ram_patch_addr = '0;
  assign dbg_side_ram_patch_data = '0;
  assign expected_latency_48b = {16'd0, csr_expected_latency};
  assign deassembly_fifo_usedw = 8'(deassembly_fifo_usedw_int);
  assign pop_cmd_fifo_usedw = pop_cmd_fifo_usedw_int[3:0];
  assign deassembly_fifo_sclr = csr_soft_reset_pulse || (run_state_cmd == RUN_PREPARING && flush_cycle_count == '0);
  assign pop_cmd_fifo_sclr = deassembly_fifo_sclr;
  assign gts_counter_rst = (run_state_cmd != RUN_RUNNING && run_state_cmd != RUN_TERMINATING);
  assign egress_not_ready_drop_event = aso_hit_type2_valid && !aso_hit_type2_ready;

  assign fill_level_word = avs_fill_level_word();
  assign coe_debug_fill_level = fill_level_word;
  assign coe_debug_fifo_level = {
    4'd0,
    pop_cmd_fifo_usedw,
    4'd0,
    deassembly_fifo_usedw,
    4'd0,
    pop_cmd_fifo_full,
    pop_cmd_fifo_empty,
    deassembly_fifo_full,
    deassembly_fifo_empty,
    4'd0
  };
  assign coe_debug_queue_state = {
    12'd0,
    decision_reg,
    pop_engine_state,
    run_state_cmd,
    push_state,
    6'd0
  };
  assign aso_filllevel_valid = 1'b1;
  assign aso_filllevel_data = fill_level_word[15:0];
  assign pop_current_cam_key = pop_cmd_search_key_local(pop_current_sk);
  assign pop_current_subheader_key = pop_current_sk[7:0];
  assign pop_current_epoch_bit = pop_cmd_epoch_bit_local(pop_current_sk);
  assign pop_hit_pending_epoch = tcc8n_search_epoch_local(hit_tcc8n(pop_hit_pending));
  assign pop_count_chunk_vec = low_count_chunk(pop_count_mask);
  assign pop_count_chunk_hits = count_ones_16(pop_count_chunk_vec);
  assign pop_count_next = pop_count_acc + {11'd0, pop_count_chunk_hits};
  assign side_ram_dout =
    (pop_output_pending || pop_emit_pending || pop_hit_valid) ?
    {pop_occupied_pending, pop_hit_pending} :
    side_ram_raw_dout;

  function automatic logic [31:0] avs_fill_level_word();
    logic [63:0] level;
    level = debug_msg2.push_cnt - debug_msg2.pop_cnt - debug_msg2.overwrite_cnt;
    return level[31:0];
  endfunction

  function automatic logic [31:0] counter_word(
    input logic [63:0] live_value,
    input logic [63:0] snap_value,
    input logic        high_word
  );
    logic [63:0] selected;
    selected = csr_counter_freeze ? snap_value : live_value;
    if (high_word) begin
      return selected[63:32];
    end
    return selected[31:0];
  endfunction

  function automatic logic [ADDR_W_CONST-1:0] ptr_inc(
    input logic [ADDR_W_CONST-1:0] ptr
  );
    if (ptr == RING_BUFFER_N_ENTRY - 1) begin
      return '0;
    end
    return ptr + {{(ADDR_W_CONST-1){1'b0}}, 1'b1};
  endfunction

  function automatic logic [POP_COUNT_CHUNK_WIDTH_CONST-1:0] low_count_chunk(
    input logic [RING_BUFFER_N_ENTRY-1:0] snap
  );
    logic [POP_COUNT_CHUNK_WIDTH_CONST-1:0] chunk;

    chunk = '0;
    for (int i = 0; i < POP_COUNT_CHUNK_WIDTH_CONST; i++) begin
      if (i < RING_BUFFER_N_ENTRY) begin
        chunk[i] = snap[i];
      end
    end
    return chunk;
  endfunction

  function automatic logic [4:0] count_ones_16(
    input logic [POP_COUNT_CHUNK_WIDTH_CONST-1:0] bits
  );
    logic [4:0] count;

    count = '0;
    for (int i = 0; i < POP_COUNT_CHUNK_WIDTH_CONST; i++) begin
      count = count + {4'd0, bits[i]};
    end
    return count;
  endfunction

  function automatic logic [LOCK_SECTOR_BITS_CONST-1:0] addr_sector(
    input logic [ADDR_W_CONST-1:0] addr
  );
    return LOCK_SECTOR_BITS_CONST'(addr >> ADDR_SECTOR_LSB_CONST);
  endfunction

  function automatic logic [LOCK_SECTOR_COUNT_CONST-1:0] snapshot_sector_mask(
    input logic [RING_BUFFER_N_ENTRY-1:0] snap
  );
    logic [LOCK_SECTOR_COUNT_CONST-1:0] mask;
    logic [ADDR_W_CONST-1:0] addr;

    mask = '0;
    for (int i = 0; i < RING_BUFFER_N_ENTRY; i++) begin
      if (snap[i]) begin
        addr = ADDR_W_CONST'(i);
        mask[addr_sector(addr)] = 1'b1;
      end
    end
    return mask;
  endfunction

  function automatic logic [31:0] csr_read_data(input logic [4:0] addr);
    logic [31:0] data;
    data = '0;
    unique case (addr)
      5'd0: data = IP_UID[31:0];
      5'd1: begin
        unique case (csr_meta_sel)
          2'd0: data = {
            VERSION_MAJOR[7:0],
            VERSION_MINOR[7:0],
            VERSION_PATCH[3:0],
            BUILD[11:0]
          };
          2'd1: data = VERSION_DATE[31:0];
          2'd2: data = VERSION_GIT[31:0];
          default: data = INSTANCE_ID[31:0];
        endcase
      end
      5'd2: data = {26'd0, csr_counter_freeze, csr_filter_inerr, 2'd0, 1'b0, csr_go};
      5'd3: data = csr_expected_latency;
      5'd4: data = avs_fill_level_word();
      5'd5: data = counter_word(debug_msg2.inerr_cnt, debug_msg2_snap.inerr_cnt, 1'b0);
      5'd6: data = counter_word(debug_msg2.push_cnt, debug_msg2_snap.push_cnt, 1'b0);
      5'd7: data = counter_word(debug_msg2.pop_cnt, debug_msg2_snap.pop_cnt, 1'b0);
      5'd8: data = counter_word(debug_msg2.overwrite_cnt, debug_msg2_snap.overwrite_cnt, 1'b0);
      5'd9: data = counter_word(debug_msg2.cache_miss_cnt, debug_msg2_snap.cache_miss_cnt, 1'b0);
      5'd10: data = counter_word(debug_msg2.inerr_cnt, debug_msg2_snap.inerr_cnt, 1'b1);
      5'd11: data = counter_word(debug_msg2.push_cnt, debug_msg2_snap.push_cnt, 1'b1);
      5'd12: data = counter_word(debug_msg2.pop_cnt, debug_msg2_snap.pop_cnt, 1'b1);
      5'd13: data = counter_word(debug_msg2.overwrite_cnt, debug_msg2_snap.overwrite_cnt, 1'b1);
      5'd14: data = counter_word(debug_msg2.cache_miss_cnt, debug_msg2_snap.cache_miss_cnt, 1'b1);
      5'd15: data = counter_word(debug_msg2.deasm_full_drop_cnt, debug_msg2_snap.deasm_full_drop_cnt, 1'b0);
      5'd16: data = counter_word(debug_msg2.deasm_full_drop_cnt, debug_msg2_snap.deasm_full_drop_cnt, 1'b1);
      5'd17: data = counter_word(debug_msg2.pop_cmd_full_drop_cnt, debug_msg2_snap.pop_cmd_full_drop_cnt, 1'b0);
      5'd18: data = counter_word(debug_msg2.pop_cmd_full_drop_cnt, debug_msg2_snap.pop_cmd_full_drop_cnt, 1'b1);
      5'd19: data = counter_word(debug_msg2.egress_not_ready_drop_cnt, debug_msg2_snap.egress_not_ready_drop_cnt, 1'b0);
      5'd20: data = counter_word(debug_msg2.egress_not_ready_drop_cnt, debug_msg2_snap.egress_not_ready_drop_cnt, 1'b1);
      default: data = '0;
    endcase
    return data;
  endfunction

  ring_buffer_cam_fifo #(
    .WIDTH(DEASM_WORD_BITS_CONST),
    .DEPTH(DEASM_DEPTH_CONST)
  ) deassembly_fifo (
    .clk(i_clk),
    .rst(i_rst),
    .sclr(deassembly_fifo_sclr),
    .wrreq(deassembly_fifo_wrreq),
    .rdack(deassembly_fifo_rdack),
    .din(deassembly_fifo_din),
    .dout(deassembly_fifo_dout),
    .empty(deassembly_fifo_empty),
    .full(deassembly_fifo_full),
    .usedw(deassembly_fifo_usedw_int)
  );

  ring_buffer_cam_fifo #(
    .WIDTH(9),
    .DEPTH(POP_CMD_DEPTH_CONST)
  ) pop_cmd_fifo (
    .clk(i_clk),
    .rst(i_rst),
    .sclr(pop_cmd_fifo_sclr),
    .wrreq(pop_cmd_fifo_wrreq),
    .rdack(pop_cmd_fifo_rdack),
    .din(pop_cmd_fifo_din),
    .dout(pop_cmd_fifo_dout),
    .empty(pop_cmd_fifo_empty),
    .full(pop_cmd_fifo_full),
    .usedw(pop_cmd_fifo_usedw_int)
  );

  cam_lookup_m10k_sv #(
    .KEY_WIDTH(CAM_KEY_WIDTH_CONST),
    .N_ENTRY(RING_BUFFER_N_ENTRY),
    .ADDR_WIDTH(ADDR_W_CONST)
  ) main_cam (
    .clock(i_clk),
    .write_addr(cam_wr_addr[ADDR_W_CONST-1:0]),
    .write_key(cam_wr_data[CAM_KEY_WIDTH_CONST-1:0]),
    .write_bit(cam_wr_en && !cam_erase_en),
    .write_enable(cam_wr_en || cam_erase_en),
    .read_key(pop_current_cam_key),
    .match_addr(cam_match_addr_oh)
  );

  cam_primitive_m10k_sv #(
    .DATA_WIDTH(40),
    .ADDR_WIDTH(ADDR_W_CONST),
    .DEPTH(RING_BUFFER_N_ENTRY)
  ) side_hit_ram (
    .clock(i_clk),
    .write_addr(side_ram_waddr[ADDR_W_CONST-1:0]),
    .write_data(side_ram_din),
    .write_enable(side_ram_we),
    .read_addr(side_ram_raddr[ADDR_W_CONST-1:0]),
    .read_data(side_ram_raw_dout)
  );

  cam_primitive_m10k_sv #(
    .DATA_WIDTH(SIDE_META_WIDTH_CONST),
    .ADDR_WIDTH(ADDR_W_CONST),
    .DEPTH(RING_BUFFER_N_ENTRY)
  ) side_metadata_ram (
    .clock(i_clk),
    .write_addr(side_ram_waddr[ADDR_W_CONST-1:0]),
    .write_data(side_meta_ram_din),
    .write_enable(side_ram_we),
    .read_addr(side_ram_raddr[ADDR_W_CONST-1:0]),
    .read_data(side_meta_ram_dout)
  );

  always_comb begin
    ingress_lane_match = lane_matches(
      asi_hit_type1_data,
      asi_hit_type1_channel,
      asi_hit_type1_empty,
      INTERLEAVING_INDEX
    );
    ingress_active_window =
      (run_state_cmd == RUN_RUNNING ||
       (run_state_cmd == RUN_TERMINATING && !endofrun_seen)) &&
      csr_go &&
      asi_hit_type1_valid &&
      !asi_hit_type1_empty &&
      ingress_lane_match;
    ingress_payload_countable =
      ingress_active_window &&
      (!csr_filter_inerr || !asi_hit_type1_error[0]);
    deasm_full_drop_event = ingress_payload_countable && deassembly_fifo_full;

    deassembly_fifo_din = '0;
    deassembly_fifo_din.hit_word = {1'b0, asi_hit_type1_data};
    deassembly_fifo_din.metadata = asi_hit_type1_metadata;
    deassembly_fifo_din.metadata_valid = asi_hit_type1_metadata_valid;
    deassembly_fifo_wrreq = 1'b0;
    if (ingress_payload_countable && !deassembly_fifo_full) begin
      deassembly_fifo_wrreq = 1'b1;
    end

    asi_hit_type1_ready =
      !csr_soft_reset_pulse &&
      csr_go &&
      (run_state_cmd == RUN_RUNNING ||
       (run_state_cmd == RUN_TERMINATING && !endofrun_seen)) &&
      !deassembly_fifo_full;

    in_payload_valid = !deassembly_fifo_empty;
    in_hit_side = deassembly_fifo_dout.hit_word[38:0];
    in_hit_ts8n = hit_tcc8n(deassembly_fifo_dout.hit_word[38:0]);
    in_hit_sk = tcc8n_search_key_local(hit_tcc8n(deassembly_fifo_dout.hit_word[38:0]));
    push_write_req = in_payload_valid &&
      (run_state_cmd == RUN_RUNNING || run_state_cmd == RUN_TERMINATING) &&
      !csr_soft_reset_pulse;
    push_check_occupied = push_check_valid && side_ram_raw_dout[39];
    push_erase_sk = tcc8n_search_key_local(hit_tcc8n(side_ram_raw_dout[38:0]));
    push_erase_req = push_check_occupied;
    deassembly_fifo_rdack = push_write_grant;
  end

  always_comb begin
    read_time_valid = (gts_8n >= expected_latency_48b);
    if (read_time_valid) begin
      read_time_ptr_comb = gts_8n - expected_latency_48b;
    end else begin
      read_time_ptr_comb = 48'd1;
    end
  end

  always_comb begin
    pop_cmd_fifo_wrreq = 1'b0;
    pop_cmd_fifo_din = '0;
    pop_cmd_tick_due =
      (run_state_cmd == RUN_RUNNING ||
       (run_state_cmd == RUN_TERMINATING && !terminating_drain_done)) &&
      read_time_valid &&
      read_time_ptr[3:0] == 4'h0 &&
      read_time_ptr[5:4] == INTERLEAVING_INDEX[1:0];
    pop_cmd_full_drop_event = pop_cmd_tick_due && pop_cmd_fifo_full;
    if (pop_cmd_tick_due && !pop_cmd_fifo_full) begin
      pop_cmd_fifo_wrreq = 1'b1;
      pop_cmd_fifo_din = read_time_pop_cmd_local(read_time_ptr);
    end
  end

  always_comb begin
    push_write_grant = 1'b0;
    push_erase_grant = 1'b0;
    pop_erase_grant = 1'b0;
    pop_flush_grant = 1'b0;
    push_write_allowed = 1'b0;
    push_write_sector_locked = 1'b0;
    push_erase_sector_locked = 1'b0;
    pop_sector_lock_mask = pop_snapshot_sector_mask;

    if (pop_issue_inflight || pop_output_pending || pop_emit_pending) begin
      pop_sector_lock_mask[
        addr_sector(pop_issue_addr_pending[ADDR_W_CONST-1:0])
      ] = 1'b1;
    end
    if (pop_erase_req) begin
      pop_sector_lock_mask[
        addr_sector(pop_issue_addr[ADDR_W_CONST-1:0])
      ] = 1'b1;
    end
    if ((pop_engine_state == POP_LOADING) ||
        (pop_engine_state == POP_COUNTING) ||
        (pop_engine_state == POP_DRAINING)) begin
      push_write_sector_locked =
        pop_sector_lock_mask[addr_sector(write_pointer)];
      push_erase_sector_locked =
        pop_sector_lock_mask[addr_sector(push_erase_addr_reg)];
    end

    push_write_allowed =
      push_write_req &&
      !push_erase_req &&
      !pop_erase_req &&
      !pop_flush_req &&
      (pop_engine_state != POP_SEARCHING) &&
      !push_write_sector_locked;

    if (csr_soft_reset_pulse) begin
      push_write_grant = 1'b0;
      push_erase_grant = 1'b0;
      pop_erase_grant = 1'b0;
      pop_flush_grant = 1'b0;
    end else if (pop_flush_req) begin
      pop_flush_grant = 1'b1;
    end else begin
      push_erase_grant =
        push_erase_req &&
        !pop_erase_req &&
        (pop_engine_state != POP_SEARCHING) &&
        !push_erase_sector_locked;
      pop_erase_grant = pop_erase_req;
      push_write_grant = push_write_allowed;
    end

    decision = 3'd4;
    if (pop_flush_grant) begin
      decision = 3'd3;
    end else if (pop_erase_grant && push_write_grant) begin
      decision = 3'd5;
    end else if (pop_erase_grant) begin
      decision = 3'd2;
    end else if (push_erase_grant) begin
      decision = 3'd1;
    end else if (push_write_grant) begin
      decision = 3'd0;
    end

    cam_wr_en = 1'b0;
    cam_erase_en = 1'b0;
    cam_wr_addr = {{(16-ADDR_W_CONST){1'b0}}, write_pointer};
    cam_wr_data = in_hit_sk;
    side_ram_we = 1'b0;
    side_ram_waddr = {{(16-ADDR_W_CONST){1'b0}}, write_pointer};
    side_ram_din = {1'b1, in_hit_side};
    side_ram_raddr = {{(16-ADDR_W_CONST){1'b0}}, write_pointer};
    side_meta_ram_din = '0;

    if (push_write_grant) begin
      cam_wr_en = 1'b1;
      side_ram_we = 1'b1;
      side_ram_waddr = {{(16-ADDR_W_CONST){1'b0}}, write_pointer};
      side_ram_din = {1'b1, in_hit_side};
      side_meta_ram_din = {
        deassembly_fifo_dout.metadata_valid,
        deassembly_fifo_dout.metadata
      };
    end

    if (push_erase_grant && !pop_erase_grant && !push_write_grant) begin
      cam_erase_en = (push_erase_sk != push_write_sk_reg);
      cam_wr_addr = {{(16-ADDR_W_CONST){1'b0}}, push_erase_addr_reg};
      cam_wr_data = push_erase_sk;
      side_ram_waddr = {{(16-ADDR_W_CONST){1'b0}}, push_erase_addr_reg};
    end

    if (pop_erase_grant) begin
      cam_erase_en = 1'b1;
      cam_wr_addr = pop_issue_addr;
      cam_wr_data = pop_current_cam_key;
      side_ram_raddr = pop_issue_addr;
      if (!push_write_grant) begin
        side_ram_we = 1'b1;
        side_ram_waddr = pop_issue_addr;
        side_ram_din = '0;
      end
    end

    if (pop_flush_grant) begin
      cam_erase_en = !pop_flush_cam_done;
      cam_wr_addr = flush_cam_wraddr;
      side_ram_we = !pop_flush_ram_done;
      side_ram_waddr = flush_ram_wraddr;
      side_ram_din = '0;
      side_meta_ram_din = '0;
    end

    if (dbg_side_ram_patch_we) begin
      side_ram_we = 1'b1;
      side_ram_waddr = {{(16-ADDR_W_CONST){1'b0}}, dbg_side_ram_patch_addr};
      side_ram_din = dbg_side_ram_patch_data;
    end
  end

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      avs_csr_readdata <= '0;
      csr_go <= 1'b1;
      csr_soft_reset_pulse <= 1'b0;
      csr_filter_inerr <= 1'b1;
      csr_counter_freeze <= 1'b0;
      csr_expected_latency <= DEFAULT_EXPECTED_LATENCY_CONST;
      csr_meta_sel <= 2'd0;
      debug_msg2_snap <= '0;
      debug_msg2_snap.cam_clean <= 1'b1;
    end else begin
      csr_soft_reset_pulse <= 1'b0;
      if (avs_csr_read) begin
        avs_csr_readdata <= csr_read_data(avs_csr_address);
      end else begin
        avs_csr_readdata <= csr_read_data(avs_csr_address);
      end
      if (csr_soft_reset_pulse) begin
        csr_counter_freeze <= 1'b0;
        debug_msg2_snap <= '0;
        debug_msg2_snap.cam_clean <= 1'b1;
      end else if (avs_csr_write) begin
        unique case (avs_csr_address)
          5'd1: csr_meta_sel <= avs_csr_writedata[1:0];
          5'd2: begin
            csr_go <= avs_csr_writedata[0];
            csr_filter_inerr <= avs_csr_writedata[4];
            csr_counter_freeze <= avs_csr_writedata[5] && !avs_csr_writedata[1];
            if (avs_csr_writedata[5] && !avs_csr_writedata[1]) begin
              debug_msg2_snap <= debug_msg2;
            end
            if (avs_csr_writedata[1]) begin
              csr_soft_reset_pulse <= 1'b1;
              csr_counter_freeze <= 1'b0;
              debug_msg2_snap <= '0;
              debug_msg2_snap.cam_clean <= 1'b1;
            end
          end
          5'd3: csr_expected_latency <= avs_csr_writedata;
          default: begin
          end
        endcase
      end
    end
  end

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      run_state_cmd <= RUN_IDLING;
      asi_ctrl_ready <= 1'b0;
      endofrun_seen <= 1'b0;
      gts_8n <= '0;
      gts_end_of_run <= '0;
      read_time_ptr <= '0;
      run_mgmt_flush_memory_start <= 1'b0;
      run_mgmt_flush_memory_done <= 1'b0;
      run_mgmt_flushed <= 1'b0;
      pop_flush_ram_done <= 1'b0;
      pop_flush_cam_done <= 1'b0;
      flush_ram_wraddr <= '0;
      flush_cam_wraddr <= '0;
      flush_cam_wrdata <= '0;
      flush_cycle_count <= '0;
      prep_ready_latched <= 1'b0;
    end else begin
      if (csr_soft_reset_pulse) begin
        run_state_cmd <= RUN_IDLING;
        asi_ctrl_ready <= 1'b0;
        endofrun_seen <= 1'b0;
        gts_8n <= '0;
        gts_end_of_run <= '0;
        read_time_ptr <= '0;
        run_mgmt_flush_memory_start <= 1'b0;
        run_mgmt_flush_memory_done <= 1'b0;
        run_mgmt_flushed <= 1'b0;
        pop_flush_ram_done <= 1'b0;
        pop_flush_cam_done <= 1'b0;
        flush_ram_wraddr <= '0;
        flush_cam_wraddr <= '0;
        flush_cam_wrdata <= '0;
        flush_cycle_count <= '0;
        prep_ready_latched <= 1'b0;
      end else begin
        if (run_state_cmd == RUN_RUNNING || run_state_cmd == RUN_TERMINATING) begin
          gts_8n <= gts_8n + 48'd1;
          read_time_ptr <= read_time_ptr_comb;
        end else begin
          read_time_ptr <= '0;
        end

        if (asi_hit_type1_valid && asi_hit_type1_empty &&
            lane_matches(asi_hit_type1_data, asi_hit_type1_channel, 1'b1, INTERLEAVING_INDEX) &&
            run_state_cmd == RUN_TERMINATING) begin
          endofrun_seen <= 1'b1;
          gts_end_of_run <= gts_8n;
        end

        if (run_state_cmd == RUN_PREPARING) begin
          run_mgmt_flush_memory_start <= 1'b1;
          if (!pop_flush_ram_done || !pop_flush_cam_done) begin
            flush_cycle_count <= flush_cycle_count + {{(FLUSH_COUNT_W_CONST-1){1'b0}}, 1'b1};
            run_mgmt_flushed <= 1'b0;
            run_mgmt_flush_memory_done <= 1'b0;
            prep_ready_latched <= 1'b0;

            if (!pop_flush_ram_done) begin
              if (flush_ram_wraddr == 16'(RING_BUFFER_N_ENTRY - 1)) begin
                pop_flush_ram_done <= 1'b1;
              end else begin
                flush_ram_wraddr <= flush_ram_wraddr + 16'd1;
              end
            end

            if (!pop_flush_cam_done) begin
              if (flush_cam_wrdata[CAM_KEY_WIDTH_CONST-1:0] ==
                  CAM_KEY_WIDTH_CONST'(CAM_KEY_COUNT_CONST - 1)) begin
                flush_cam_wrdata <= '0;
                if (flush_cam_wraddr == 16'(RING_BUFFER_N_ENTRY - 1)) begin
                  pop_flush_cam_done <= 1'b1;
                end else begin
                  flush_cam_wraddr <= flush_cam_wraddr + 16'd1;
                end
              end else begin
                flush_cam_wrdata <= flush_cam_wrdata + 16'd1;
              end
            end
          end else if (!run_mgmt_flushed) begin
            run_mgmt_flush_memory_done <= 1'b1;
            run_mgmt_flushed <= 1'b1;
            prep_ready_latched <= 1'b0;
          end else begin
            prep_ready_latched <= 1'b1;
          end
        end

        asi_ctrl_ready <= 1'b0;
        if (asi_ctrl_valid) begin
          unique case (asi_ctrl_data)
            CTRL_IDLE_CONST: begin
              run_state_cmd <= RUN_IDLING;
              asi_ctrl_ready <= 1'b1;
              endofrun_seen <= 1'b0;
            end
            CTRL_RUN_PREPARE_CONST: begin
              run_state_cmd <= RUN_PREPARING;
              asi_ctrl_ready <= prep_ready_latched;
              if (run_state_cmd != RUN_PREPARING) begin
                flush_cycle_count <= '0;
                flush_ram_wraddr <= '0;
                flush_cam_wraddr <= '0;
                flush_cam_wrdata <= '0;
                pop_flush_ram_done <= 1'b0;
                pop_flush_cam_done <= 1'b0;
                run_mgmt_flush_memory_start <= 1'b1;
                run_mgmt_flush_memory_done <= 1'b0;
                run_mgmt_flushed <= 1'b0;
                prep_ready_latched <= 1'b0;
                endofrun_seen <= 1'b0;
                gts_8n <= '0;
                read_time_ptr <= '0;
              end
            end
            CTRL_SYNC_CONST: begin
              run_state_cmd <= RUN_SYNCING;
              asi_ctrl_ready <= 1'b1;
              endofrun_seen <= 1'b0;
            end
            CTRL_RUNNING_CONST: begin
              run_state_cmd <= RUN_RUNNING;
              asi_ctrl_ready <= 1'b1;
              endofrun_seen <= 1'b0;
            end
            CTRL_TERMINATING_CONST: begin
              run_state_cmd <= RUN_TERMINATING;
              asi_ctrl_ready <= terminating_drain_done;
            end
            CTRL_LINK_TEST_CONST: begin
              run_state_cmd <= RUN_LINK_TESTING;
              asi_ctrl_ready <= 1'b0;
            end
            default: begin
              run_state_cmd <= RUN_ERRORING;
              asi_ctrl_ready <= 1'b0;
            end
          endcase
        end
      end
    end
  end

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      for (int i = 0; i < RING_BUFFER_N_ENTRY; i++) begin
        slot_valid[i] <= 1'b0;
      end
      write_pointer <= '0;
      push_state <= PUSH_WRITING;
      push_write_sk_reg <= '0;
      push_check_valid <= 1'b0;
      push_erase_addr_reg <= '0;
      overwritten_side_word <= '0;
      pop_issue_addr_pending <= '0;
      pop_hit_pending <= '0;
      pop_metadata_pending <= '0;
      pop_metadata_valid_pending <= 1'b0;
      pop_occupied_pending <= 1'b0;
      pop_output_pending <= 1'b0;
      pop_ram_read_pending <= 1'b0;
      debug_msg2 <= '0;
      debug_msg2.cam_clean <= 1'b1;
    end else begin
      debug_msg2.cam_clean <=
        (debug_msg2.push_cnt == (debug_msg2.pop_cnt + debug_msg2.overwrite_cnt));

      if (csr_soft_reset_pulse ||
          (run_state_cmd == RUN_PREPARING && flush_cycle_count == '0)) begin
        for (int i = 0; i < RING_BUFFER_N_ENTRY; i++) begin
          slot_valid[i] <= 1'b0;
        end
        write_pointer <= '0;
        push_state <= PUSH_WRITING;
        push_write_sk_reg <= '0;
        push_check_valid <= 1'b0;
        push_erase_addr_reg <= '0;
        overwritten_side_word <= '0;
        pop_issue_addr_pending <= '0;
        pop_hit_pending <= '0;
        pop_metadata_pending <= '0;
        pop_metadata_valid_pending <= 1'b0;
        pop_occupied_pending <= 1'b0;
        pop_output_pending <= 1'b0;
        pop_ram_read_pending <= 1'b0;
        debug_msg2 <= '0;
        debug_msg2.cam_clean <= 1'b1;
      end else begin
        if (asi_hit_type1_valid && asi_hit_type1_error[0] && asi_hit_type1_ready &&
            !asi_hit_type1_empty && csr_filter_inerr) begin
          debug_msg2.inerr_cnt <= debug_msg2.inerr_cnt + 64'd1;
        end

        if (deasm_full_drop_event) begin
          debug_msg2.deasm_full_drop_cnt <= debug_msg2.deasm_full_drop_cnt + 64'd1;
        end

        if (pop_cmd_full_drop_event) begin
          debug_msg2.pop_cmd_full_drop_cnt <= debug_msg2.pop_cmd_full_drop_cnt + 64'd1;
        end

        if (egress_not_ready_drop_event) begin
          debug_msg2.egress_not_ready_drop_cnt <= debug_msg2.egress_not_ready_drop_cnt + 64'd1;
        end

        if (dbg_side_ram_patch_we) begin
          slot_valid[dbg_side_ram_patch_addr] <= dbg_side_ram_patch_data[39];
        end

        if (push_check_valid) begin
          overwritten_side_word <= side_ram_raw_dout;
          if (!push_check_occupied || push_erase_grant) begin
            push_check_valid <= 1'b0;
            push_state <= PUSH_WRITING;
          end else begin
            push_state <= PUSH_ERASING;
          end
        end

        if (push_write_grant) begin
          push_write_sk_reg <= in_hit_sk;
          push_erase_addr_reg <= write_pointer;
          push_check_valid <= 1'b1;
          slot_valid[write_pointer] <= 1'b1;
          write_pointer <= ptr_inc(write_pointer);
          debug_msg2.push_cnt <= debug_msg2.push_cnt + 64'd1;
        end else if (push_erase_grant) begin
          debug_msg2.overwrite_cnt <= debug_msg2.overwrite_cnt + 64'd1;
          push_state <= PUSH_WRITING;
        end

        if (pop_erase_grant) begin
          pop_issue_addr_pending <= pop_issue_addr;
          slot_valid[pop_issue_addr[ADDR_W_CONST-1:0]] <= 1'b0;
          debug_msg2.pop_cnt <= debug_msg2.pop_cnt + 64'd1;
          pop_ram_read_pending <= 1'b1;
        end

        if (pop_ram_read_pending) begin
          pop_hit_pending <= side_ram_raw_dout[38:0];
          pop_metadata_pending <= side_meta_ram_dout[63:0];
          pop_metadata_valid_pending <= side_meta_ram_dout[64];
          pop_occupied_pending <= side_ram_raw_dout[39];
          pop_ram_read_pending <= 1'b0;
          pop_output_pending <= 1'b1;
        end else if (pop_hit_valid) begin
          pop_output_pending <= 1'b0;
        end

        if (pop_cache_miss_pulse) begin
          debug_msg2.cache_miss_cnt <= debug_msg2.cache_miss_cnt + 64'd1;
        end
      end
    end
  end

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      pop_engine_state <= POP_IDLING;
      pop_snapshot <= '0;
      pop_snapshot_sector_mask <= '0;
      pop_scan_mask <= '0;
      pop_scan_addr <= '0;
      pop_count_mask <= '0;
      pop_count_chunk_idx <= '0;
      pop_count_acc <= '0;
      pop_current_sk <= '0;
      pop_total_hits <= '0;
      pop_hits_count <= '0;
      pop_issue_addr <= '0;
      pop_cmd_fifo_rdack <= 1'b0;
      pop_erase_req <= 1'b0;
      pop_flush_req <= 1'b0;
      pop_pipeline_start <= 1'b0;
      pop_hit_valid <= 1'b0;
      pop_cache_miss_pulse <= 1'b0;
      pop_last_hit_pending <= 1'b0;
      subheader_gen_done <= 1'b0;
      pop_search_wait_cnt <= '0;
      dbg_pop_rr_idx <= '0;
      dbg_pop_issue_partition_idx <= '0;
      dbg_pop_count_partition_idx <= '0;
      dbg_pop_partition_pending <= '0;
      dbg_pop_partition_load <= '0;
      dbg_pop_partition_advance <= '0;
      dbg_pop_partition_result_valid <= '0;
      dbg_pop_partition_flag <= '0;
      dbg_pop_partition_has_more <= '0;
      dbg_pop_partition_eval_stage0_valid <= '0;
      aso_hit_type2_valid <= 1'b0;
      aso_hit_type2_channel <= '0;
      aso_hit_type2_startofpacket <= 1'b0;
      aso_hit_type2_endofpacket <= 1'b0;
      aso_hit_type2_data <= '0;
      aso_hit_type2_error <= '0;
      aso_hit_type2_metadata <= '0;
      aso_hit_type2_metadata_valid <= 1'b0;
      pop_issue_inflight <= 1'b0;
      pop_emit_pending <= 1'b0;
    end else begin
      pop_cmd_fifo_rdack <= 1'b0;
      pop_erase_req <= 1'b0;
      pop_flush_req <= 1'b0;
      pop_hit_valid <= 1'b0;
      pop_cache_miss_pulse <= 1'b0;
      pop_last_hit_pending <= 1'b0;
      aso_hit_type2_valid <= 1'b0;
      aso_hit_type2_startofpacket <= 1'b0;
      aso_hit_type2_endofpacket <= 1'b0;
      aso_hit_type2_data <= '0;
      aso_hit_type2_error <= '0;
      aso_hit_type2_metadata <= '0;
      aso_hit_type2_metadata_valid <= 1'b0;
      dbg_pop_partition_load <= '0;
      dbg_pop_partition_advance <= '0;
      dbg_pop_partition_eval_stage0_valid <= '0;

      if (csr_soft_reset_pulse) begin
        pop_engine_state <= POP_IDLING;
        pop_snapshot <= '0;
        pop_snapshot_sector_mask <= '0;
        pop_scan_mask <= '0;
        pop_scan_addr <= '0;
        pop_count_mask <= '0;
        pop_count_chunk_idx <= '0;
        pop_count_acc <= '0;
        pop_current_sk <= '0;
        pop_total_hits <= '0;
        pop_hits_count <= '0;
        pop_issue_addr <= '0;
        pop_pipeline_start <= 1'b0;
        subheader_gen_done <= 1'b0;
        pop_search_wait_cnt <= '0;
        pop_issue_inflight <= 1'b0;
        pop_emit_pending <= 1'b0;
      end else if (run_state_cmd == RUN_PREPARING) begin
        pop_engine_state <= POP_FLUSHING;
        pop_flush_req <= 1'b1;
        pop_pipeline_start <= 1'b0;
        subheader_gen_done <= 1'b0;
        pop_snapshot <= '0;
        pop_snapshot_sector_mask <= '0;
        pop_scan_mask <= '0;
        pop_scan_addr <= '0;
        pop_count_mask <= '0;
        pop_count_chunk_idx <= '0;
        pop_count_acc <= '0;
        if (prep_ready_latched) begin
          pop_engine_state <= POP_IDLING;
        end
      end else begin
        unique case (pop_engine_state)
          POP_IDLING: begin
            pop_pipeline_start <= 1'b0;
            subheader_gen_done <= 1'b0;
            if ((run_state_cmd == RUN_RUNNING || run_state_cmd == RUN_TERMINATING) &&
                !pop_cmd_fifo_empty) begin
              pop_current_sk <= pop_cmd_fifo_dout;
              pop_cmd_fifo_rdack <= 1'b1;
              pop_search_wait_cnt <= '0;
              pop_snapshot <= '0;
              pop_snapshot_sector_mask <= '0;
              pop_scan_mask <= '0;
              pop_scan_addr <= '0;
              pop_count_mask <= '0;
              pop_count_chunk_idx <= '0;
              pop_count_acc <= '0;
              pop_engine_state <= POP_SEARCHING;
            end
          end
          POP_SEARCHING: begin
            if (pop_search_wait_cnt < 3'd5) begin
              pop_search_wait_cnt <= pop_search_wait_cnt + 3'd1;
            end else begin
              logic [RING_BUFFER_N_ENTRY-1:0] snapshot_tmp;
              snapshot_tmp = cam_match_addr_oh & slot_valid;
              pop_snapshot <= snapshot_tmp;
              pop_snapshot_sector_mask <= snapshot_sector_mask(snapshot_tmp);
              pop_scan_mask <= snapshot_tmp;
              pop_scan_addr <= '0;
              pop_count_mask <= snapshot_tmp;
              pop_count_chunk_idx <= '0;
              pop_count_acc <= '0;
              pop_total_hits <= '0;
              pop_hits_count <= '0;
              dbg_pop_partition_pending <= |snapshot_tmp ? 4'hf : 4'h0;
              pop_engine_state <= POP_LOADING;
            end
          end
          POP_LOADING: begin
            dbg_pop_partition_load <= 4'hf;
            dbg_pop_partition_result_valid <= '0;
            dbg_pop_partition_flag <= '0;
            dbg_pop_partition_has_more <= '0;
            pop_engine_state <= POP_COUNTING;
          end
          POP_COUNTING: begin
            pop_count_acc <= pop_count_next;
            pop_count_mask <= pop_count_mask >> POP_COUNT_CHUNK_WIDTH_CONST;
            dbg_pop_count_partition_idx <= dbg_pop_count_partition_idx + 2'd1;
            if (pop_count_chunk_idx ==
                POP_COUNT_CHUNK_W_CONST'(POP_COUNT_CHUNKS_CONST - 1)) begin
              pop_total_hits <= pop_count_next;
              pop_hits_count <= pop_count_next;
              dbg_pop_partition_result_valid <= 4'hf;
              dbg_pop_partition_flag <= (pop_count_next != 16'd0) ? 4'hf : 4'h0;
              dbg_pop_partition_has_more <= (pop_count_next > 16'd1) ? 4'hf : 4'h0;
              if (pop_count_next == 16'd0) begin
                aso_hit_type2_valid <= 1'b1;
                aso_hit_type2_startofpacket <= 1'b1;
                aso_hit_type2_endofpacket <= 1'b1;
                aso_hit_type2_channel <= INTERLEAVING_INDEX[3:0];
                aso_hit_type2_data <= make_subheader(pop_current_subheader_key, 8'd0);
                pop_engine_state <= POP_RESETTING;
              end else begin
                pop_pipeline_start <= 1'b1;
                subheader_gen_done <= 1'b0;
                pop_scan_addr <= '0;
                pop_engine_state <= POP_DRAINING;
              end
            end else begin
              pop_count_chunk_idx <= pop_count_chunk_idx + POP_COUNT_CHUNK_W_CONST'(1);
            end
          end
          POP_DRAINING: begin
            pop_pipeline_start <= 1'b1;
            if (!subheader_gen_done) begin
              aso_hit_type2_valid <= 1'b1;
              aso_hit_type2_startofpacket <= 1'b1;
              aso_hit_type2_channel <= INTERLEAVING_INDEX[3:0];
              aso_hit_type2_data <= make_subheader(pop_current_subheader_key, pop_total_hits[7:0]);
              subheader_gen_done <= 1'b1;
            end else if (pop_emit_pending) begin
              aso_hit_type2_valid <= 1'b1;
              aso_hit_type2_channel <= INTERLEAVING_INDEX[3:0];
              aso_hit_type2_data <= make_hit_type2(pop_hit_pending);
              aso_hit_type2_error[0] <= (pop_hit_pending_epoch[8] != pop_current_epoch_bit);
              aso_hit_type2_metadata <= pop_metadata_pending;
              aso_hit_type2_metadata_valid <= pop_metadata_valid_pending;
              if (!pop_occupied_pending) begin
                pop_cache_miss_pulse <= 1'b1;
              end
              if (pop_hits_count == 16'd0) begin
                aso_hit_type2_endofpacket <= 1'b1;
                pop_last_hit_pending <= 1'b1;
                pop_engine_state <= POP_RESETTING;
              end
              pop_emit_pending <= 1'b0;
            end else if (pop_output_pending) begin
              pop_hit_valid <= 1'b1;
              pop_issue_inflight <= 1'b0;
              pop_emit_pending <= 1'b1;
            end else if (pop_issue_inflight) begin
              pop_engine_state <= POP_DRAINING;
            end else begin
              if (pop_hits_count != 16'd0 && pop_scan_mask[0]) begin
                pop_issue_addr <= {{(16-ADDR_W_CONST){1'b0}}, pop_scan_addr};
                if (pop_hits_count != 0) begin
                  pop_hits_count <= pop_hits_count - 16'd1;
                end
                pop_erase_req <= 1'b1;
                pop_issue_inflight <= 1'b1;
                dbg_pop_rr_idx <= dbg_pop_rr_idx + 2'd1;
                dbg_pop_issue_partition_idx <= pop_scan_addr[ADDR_W_CONST-1 -: 2];
              end else if (pop_hits_count != 16'd0 &&
                           pop_scan_addr == ADDR_W_CONST'(RING_BUFFER_N_ENTRY - 1)) begin
                pop_engine_state <= POP_RESETTING;
              end
              if (pop_hits_count != 16'd0) begin
                pop_scan_mask <= {1'b0, pop_scan_mask[RING_BUFFER_N_ENTRY-1:1]};
                pop_scan_addr <= ptr_inc(pop_scan_addr);
              end
            end
          end
          POP_RESETTING: begin
            pop_pipeline_start <= 1'b0;
            subheader_gen_done <= 1'b0;
            pop_snapshot <= '0;
            pop_snapshot_sector_mask <= '0;
            pop_scan_mask <= '0;
            pop_scan_addr <= '0;
            pop_count_mask <= '0;
            pop_count_chunk_idx <= '0;
            pop_count_acc <= '0;
            pop_issue_inflight <= 1'b0;
            pop_emit_pending <= 1'b0;
            pop_hits_count <= '0;
            pop_total_hits <= '0;
            dbg_pop_partition_pending <= '0;
            dbg_pop_partition_result_valid <= '0;
            dbg_pop_partition_flag <= '0;
            dbg_pop_partition_has_more <= '0;
            pop_engine_state <= POP_IDLING;
          end
          default: begin
            pop_engine_state <= POP_IDLING;
          end
        endcase
      end
    end
  end

  assign decision_reg = (i_rst || csr_soft_reset_pulse) ? 3'd4 : decision;

  always_comb begin
    terminating_drain_done =
      run_state_cmd == RUN_TERMINATING &&
      deassembly_fifo_empty &&
      pop_cmd_fifo_empty &&
      pop_engine_state == POP_IDLING &&
      debug_msg2.push_cnt == (debug_msg2.pop_cnt + debug_msg2.overwrite_cnt);
  end

  logic [3:0] dbg_run_state_code;
  logic [2:0] dbg_pop_engine_state_code;
  logic dbg_push_state_code;
  assign dbg_run_state_code = run_state_cmd;
  assign dbg_pop_engine_state_code = pop_engine_state;
  assign dbg_push_state_code = (push_state == PUSH_ERASING);

endmodule
