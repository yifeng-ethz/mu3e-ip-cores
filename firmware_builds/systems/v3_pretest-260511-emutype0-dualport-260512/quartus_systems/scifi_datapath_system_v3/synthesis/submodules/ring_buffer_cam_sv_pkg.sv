// File name: ring_buffer_cam_sv_pkg.sv
// Author  : Yifeng Wang (yifenwan@phys.ethz.ch), Codex migration
// Version : 26.2.8
// Date    : 20260507
// Change  : widen debug counters and expose loss-accounting counter fields

package ring_buffer_cam_sv_pkg;
  localparam int TCC8N_LO_CONST  = 17;
  localparam int TCC8N_HI_CONST  = 29;
  localparam int ASIC_LO_CONST   = 35;
  localparam int ASIC_HI_CONST   = 38;
  localparam int CH_LO_CONST     = 30;
  localparam int CH_HI_CONST     = 34;
  localparam int TCC1N6_LO_CONST = 14;
  localparam int TCC1N6_HI_CONST = 16;
  localparam int TFINE_LO_CONST  = 9;
  localparam int TFINE_HI_CONST  = 13;
  localparam int ET_LO_CONST     = 0;
  localparam int ET_HI_CONST     = 8;
  localparam int SK_LO_CONST     = 4;
  localparam int SK_HI_CONST     = 11;
  localparam int DEFAULT_EXPECTED_LATENCY_CONST = 2000;

  localparam logic [7:0] K237_CONST = 8'hf7;

  typedef enum logic [3:0] {
    RUN_IDLING        = 4'd0,
    RUN_PREPARING    = 4'd1,
    RUN_SYNCING      = 4'd2,
    RUN_RUNNING      = 4'd3,
    RUN_TERMINATING  = 4'd4,
    RUN_LINK_TESTING = 4'd5,
    RUN_SYNC_TESTING = 4'd6,
    RUN_RESETTING    = 4'd7,
    RUN_OUT_OF_DAQ   = 4'd8,
    RUN_ERRORING     = 4'd9
  } run_state_e;

  typedef enum logic [2:0] {
    POP_IDLING       = 3'd0,
    POP_SEARCHING    = 3'd1,
    POP_LOADING      = 3'd2,
    POP_COUNTING     = 3'd3,
    POP_DRAINING     = 3'd4,
    POP_RESETTING    = 3'd5,
    POP_FLUSHING     = 3'd6,
    POP_FLUSHING_RST = 3'd7
  } pop_state_e;

  typedef struct packed {
    logic [63:0] inerr_cnt;
    logic [63:0] push_cnt;
    logic [63:0] pop_cnt;
    logic [63:0] overwrite_cnt;
    logic [63:0] cache_miss_cnt;
    logic [63:0] deasm_full_drop_cnt;
    logic [63:0] pop_cmd_full_drop_cnt;
    logic [63:0] egress_not_ready_drop_cnt;
    logic        cam_clean;
  } debug_msg_t;

  function automatic logic [12:0] hit_tcc8n(input logic [38:0] hit);
    return hit[TCC8N_HI_CONST:TCC8N_LO_CONST];
  endfunction

  function automatic logic [7:0] hit_search_key(input logic [38:0] hit);
    return hit[TCC8N_LO_CONST + SK_HI_CONST:TCC8N_LO_CONST + SK_LO_CONST];
  endfunction

  function automatic logic [8:0] hit_search_epoch(input logic [38:0] hit);
    return hit[TCC8N_LO_CONST + 12:TCC8N_LO_CONST + SK_LO_CONST];
  endfunction

  function automatic logic lane_matches(
    input logic [38:0] hit,
    input logic [3:0]  channel,
    input logic        empty,
    input int unsigned interleaving_index
  );
    if (empty) begin
      return channel[1:0] == interleaving_index[1:0];
    end
    return hit[TCC8N_LO_CONST + 5 -: 2] == interleaving_index[1:0];
  endfunction

  function automatic logic [35:0] make_subheader(
    input logic [7:0] search_key,
    input logic [7:0] hit_count
  );
    logic [35:0] word;
    word = '0;
    word[35:32] = 4'h1;
    word[31:24] = search_key;
    word[15:8]  = hit_count;
    word[7:0]   = K237_CONST;
    return word;
  endfunction

  function automatic logic [35:0] make_hit_type2(input logic [38:0] hit);
    logic [35:0] word;
    word = '0;
    word[31:28] = hit[TCC8N_LO_CONST + 3:TCC8N_LO_CONST];
    word[27:22] = {2'b00, hit[ASIC_HI_CONST:ASIC_LO_CONST]};
    word[21:17] = hit[CH_HI_CONST:CH_LO_CONST];
    word[16:9]  = hit[TCC1N6_HI_CONST:TFINE_LO_CONST];
    word[8:0]   = hit[ET_HI_CONST:ET_LO_CONST];
    return word;
  endfunction
endpackage
