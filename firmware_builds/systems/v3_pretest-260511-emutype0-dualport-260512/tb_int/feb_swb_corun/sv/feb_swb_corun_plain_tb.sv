`timescale 1ns/1ps

module feb_swb_corun_plain_tb;
  import feb_swb_corun_pkg::*;

  localparam int ACTIVE_LANES = 4;
  localparam int CHANNELS_PER_ASIC = 32;
  localparam int DEFAULT_ASIC_COUNT = 8;
  localparam int MAX_ASIC_COUNT = 8;
  localparam int N_SHD = 128;
  localparam int DEFAULT_RUN_WINDOW_8NS = 125000; // 1 ms on the MuTRiG 8 ns timebase.
  localparam int DEFAULT_HIT_PERIOD_8NS = 1250;   // 100 kHz/channel.
  localparam int DEFAULT_POISSON_SEED = 20260508;
  localparam int DEFAULT_HEADER_SYNC_PHASE_8NS = 100;
  localparam int DEFAULT_HEADER_SYNC_BURST_COUNT = 1;
  localparam int DEFAULT_HEADER_SYNC_BURST_SPACING_8NS = 10;
  localparam int DEFAULT_HEADER_SYNC_ASIC_STAGGER_8NS = 16;
  localparam int SOURCE_MODE_PERIODIC = 0;
  localparam int SOURCE_MODE_POISSON = 1;
  localparam int SOURCE_MODE_HEADER_SYNC = 2;
  localparam int FRAME_STRIDE_8NS = N_SHD << 4;
  localparam int VIRTUAL_MUTRIG_SHORT_FRAME_8NS = 910;
  localparam int FRAME_PERIOD_FEB_CYCLES = FRAME_STRIDE_8NS;
  localparam int FEB_FRAME_EGRESS_DELAY_FRAMES = 2;
  localparam int SYNTHETIC_PRE_RBCAM_DELAY_CYCLES = 0;
  localparam int SYNTHETIC_POST_RBCAM_DELAY_CYCLES = 0;
  localparam int DEFAULT_DRAIN_SWB_CYCLES = 500000;
  localparam int DEFAULT_FLUSH_FRAMES = 4;
  localparam int unsigned NO_HIT_ID = 32'hffff_ffff;

  localparam logic [5:0] SWB_SCIFI_HEADER_ID = 6'b111000;
  localparam logic [7:0] SWB_K285 = 8'hBC;
  localparam logic [7:0] SWB_K284 = 8'h9C;
  localparam logic [7:0] SWB_K237 = 8'hF7;
  localparam logic [255:0] DMA_PADDING_WORD = {256{1'b1}};

  typedef struct {
    int unsigned abs_ts_8ns;
    int unsigned lane;
    int unsigned asic;
    int unsigned channel;
    int unsigned hit_id;
    int unsigned bucket_idx;
  } source_hit_event_t;

  logic feb_clk = 1'b0;
  logic swb_clk = 1'b0;
  logic reset = 1'b1;
  logic reset_n;

  logic [ACTIVE_LANES-1:0]    feb_valid;
  logic [ACTIVE_LANES-1:0]    feb_ready;
  logic [ACTIVE_LANES*36-1:0] feb_data;
  logic [ACTIVE_LANES-1:0]    feb_startofpacket;
  logic [ACTIVE_LANES-1:0]    feb_endofpacket;
  logic [ACTIVE_LANES-1:0]    feb_debug_valid;
  logic [ACTIVE_LANES*64-1:0] feb_debug_meta;

  logic [127:0] swb_data;
  logic [15:0]  swb_datak;
  logic [3:0]   swb_valid;
  logic [3:0]   swb_startofpacket;
  logic [3:0]   swb_endofpacket;
  logic [3:0]   swb_debug_valid;
  logic [255:0] swb_debug_meta;
  logic [3:0]   swb_enable_mask;
  logic [ACTIVE_LANES-1:0] fifo_overflow;
  logic [ACTIVE_LANES-1:0] fifo_underflow;

  logic [11:0]  swb_err_desc;
  logic         use_merge;
  logic         enable_dma;
  logic [31:0]  get_n_words;
  logic [31:0]  lookup_ctrl;
  logic         dma_half_full;
  logic [31:0]  opq_data;
  logic [3:0]   opq_datak;
  logic         opq_valid;
  logic [255:0] dma_data;
  logic         dma_wren;
  logic         end_of_event;
  logic         dma_done;

  longint unsigned expected_hits[$];
  longint unsigned actual_hits[$];
  bit actual_hit_matched[];

  int unsigned feb_hit_count;
  int unsigned opq_beat_count;
  int unsigned dma_payload_word_count;
  int unsigned dma_padding_word_count;
  int unsigned actual_hit_count;
  int unsigned end_of_event_count;
  int unsigned dma_done_count;
  int unsigned missing_count;
  int unsigned ghost_count;
  int unsigned allow_drops;
  int unsigned scan_only;
  int unsigned drain_swb_cycles;
  int unsigned flush_frames;
  int unsigned run_window_8ns;
  int unsigned hit_period_8ns;
  int unsigned active_asic_count;
  int unsigned source_mode;
  int unsigned poisson_seed;
  longint unsigned rn_basic_lane_mask;
  longint unsigned rn_basic_channel_mask;
  int unsigned header_sync_phase_8ns;
  int unsigned header_sync_burst_count;
  int unsigned header_sync_burst_spacing_8ns;
  int unsigned header_sync_asic_stagger_8ns;
  int unsigned n_frames_runtime;
  int unsigned total_source_buckets;
  int unsigned expected_time_samples_runtime;
  int unsigned expected_hits_runtime;
  int unsigned expected_dma_words_runtime;

  source_hit_event_t source_hits_unsorted[$];
  source_hit_event_t source_hits[];
  int unsigned bucket_hit_count[ACTIVE_LANES][];
  int unsigned bucket_first_idx[ACTIVE_LANES][];

  int source_trace_fd;
  int pre_rbcam_trace_fd;
  int post_rbcam_trace_fd;
  int feb_egress_trace_fd;
  int ingress_trace_fd;
  int feb_egress_waveform_fd;
  int ingress_waveform_fd;
  int opq_trace_fd;
  int dma_trace_fd;
  int summary_fd;
  string trace_dir;

  assign reset_n = !reset;
  assign swb_err_desc = '0;
  assign use_merge = 1'b1;
  assign enable_dma = !reset;
  assign get_n_words = expected_dma_words_runtime[31:0];
  assign dma_half_full = 1'b0;

  always #4.0 feb_clk = ~feb_clk;
  always #2.0 swb_clk = ~swb_clk;

  feb_swb_parallel_cdc_adapter #(
    .ACTIVE_LANES(ACTIVE_LANES),
    .FIFO_DEPTH_LOG2(8)
  ) u_adapter (
    .feb_clk(feb_clk),
    .feb_reset(reset),
    .feb_valid(feb_valid),
    .feb_ready(feb_ready),
    .feb_data(feb_data),
    .feb_startofpacket(feb_startofpacket),
    .feb_endofpacket(feb_endofpacket),
    .feb_debug_valid(feb_debug_valid),
    .feb_debug_meta(feb_debug_meta),
    .swb_clk(swb_clk),
    .swb_reset(reset),
    .swb_data(swb_data),
    .swb_datak(swb_datak),
    .swb_valid(swb_valid),
    .swb_startofpacket(swb_startofpacket),
    .swb_endofpacket(swb_endofpacket),
    .swb_debug_valid(swb_debug_valid),
    .swb_debug_meta(swb_debug_meta),
    .swb_enable_mask(swb_enable_mask),
    .fifo_overflow(fifo_overflow),
    .fifo_underflow(fifo_underflow)
  );

  swb_block_uvm_wrapper u_swb (
    .clk(swb_clk),
    .reset_n(reset_n),
    .feb_data(swb_data),
    .feb_datak(swb_datak),
    .feb_valid(swb_valid),
    .feb_err_desc(swb_err_desc),
    .feb_enable_mask(swb_enable_mask),
    .use_merge(use_merge),
    .enable_dma(enable_dma),
    .get_n_words(get_n_words),
    .lookup_ctrl(lookup_ctrl),
    .dma_half_full(dma_half_full),
    .opq_data(opq_data),
    .opq_datak(opq_datak),
    .opq_valid(opq_valid),
    .dma_data(dma_data),
    .dma_wren(dma_wren),
    .end_of_event(end_of_event),
    .dma_done(dma_done)
  );

  function automatic logic [31:0] make_sop(input int unsigned lane);
    logic [15:0] lane_id;
    begin
      lane_id = lane[15:0];
      return {SWB_SCIFI_HEADER_ID, 2'b00, lane_id, SWB_K285};
    end
  endfunction

  function automatic logic [31:0] make_subheader(
      input int unsigned shd_ts,
      input int unsigned hit_count);
    logic [31:0] word;
    begin
      word = '0;
      word[31:24] = shd_ts[7:0];
      word[15:8] = hit_count[7:0];
      word[7:0] = SWB_K237;
      return word;
    end
  endfunction

  function automatic logic [31:0] make_mutrig_hit(
      input int unsigned abs_ts_8ns,
      input int unsigned asic,
      input int unsigned channel,
      input int unsigned hit_id);
    logic [31:0] word;
    begin
      word = '0;
      word[31:28] = abs_ts_8ns[3:0];
      word[25:22] = asic[3:0];
      word[21:17] = channel[4:0];
      word[16:14] = abs_ts_8ns[2:0];
      word[13:9] = 5'd0;       // Fine time kept at zero for this contract case.
      word[8:0] = hit_id[8:0]; // Per-hit identity survives in the MuTRiG payload.
      return word;
    end
  endfunction

  function automatic longint unsigned expected_mutrig_dma_hit(
      input logic [31:0] ts_high_word,
      input logic [15:0] ts_low_word,
      input logic [7:0]  shd_ts,
      input logic [31:0] hit_word,
      input int unsigned asic);
    longint unsigned data_word;
    begin
      data_word = 64'h0;
      data_word[63] = 1'b1;
      data_word[62:61] = asic[1:0];
      data_word[60:56] = hit_word[21:17];
      data_word[55:47] = hit_word[8:0];
      data_word[46:44] = hit_word[16:14];
      data_word[43:39] = hit_word[13:9];
      data_word[38:0] = {
        ts_high_word[22:0],
        ts_low_word[15:11],
        shd_ts[6:0],
        hit_word[31:28]
      };
      return data_word;
    end
  endfunction

  function automatic logic [63:0] make_debug_meta(
      input int unsigned lane,
      input int unsigned abs_ts_8ns,
      input int unsigned hit_id);
    feb_swb_debug_meta_t meta;
    begin
      meta.debug_level = 2'd2;
      meta.swb_lane = lane[1:0];
      meta.source_id = FEB_SWB_SOURCE_MUTRIG_EMU;
      meta.ps_tag = abs_ts_8ns[7:0];
      meta.ts_tag = abs_ts_8ns[15:0];
      meta.hit_id = hit_id[31:0];
      return feb_swb_pack_debug_meta(meta);
    end
  endfunction

  function automatic int unsigned asic_phase_8ns(input int unsigned asic);
    begin
      return (asic * hit_period_8ns) / active_asic_count;
    end
  endfunction

  function automatic int unsigned source_lane_for_asic(input int unsigned asic);
    begin
      if (ACTIVE_LANES <= 1) begin
        return 0;
      end
      return (asic / 2) % ACTIVE_LANES;
    end
  endfunction

  function automatic string source_mode_name(input int unsigned mode);
    begin
      if (mode == SOURCE_MODE_HEADER_SYNC) begin
        return "header_sync";
      end
      if (mode == SOURCE_MODE_POISSON) begin
        return "poisson_iid";
      end
      return "periodic_phase_staggered";
    end
  endfunction

  function automatic bit rn_basic_source_selected(
      input int unsigned asic,
      input int unsigned channel);
    begin
      return rn_basic_lane_mask[asic] && rn_basic_channel_mask[channel];
    end
  endfunction

  function automatic logic [31:0] make_lookup_ctrl_word(
      input int unsigned addr,
      input int unsigned value);
    logic [31:0] word;
    begin
      word = 32'h0;
      word[6:0] = addr[6:0];
      word[8:7] = 2'b01;
      word[22:9] = value[13:0];
      return word;
    end
  endfunction

  task automatic drive_feb_word(
      input int lane,
      input logic [3:0] datak,
      input logic [31:0] data,
      input logic sop,
      input logic eop,
      input logic debug_valid,
      input logic [63:0] debug_meta);
    begin
      @(posedge feb_clk);
      while (!feb_ready[lane]) begin
        @(posedge feb_clk);
      end
      feb_data[lane*36 +: 36] <= {datak, data};
      feb_startofpacket[lane] <= sop;
      feb_endofpacket[lane] <= eop;
      feb_debug_valid[lane] <= debug_valid;
      feb_debug_meta[lane*64 +: 64] <= debug_meta;
      feb_valid[lane] <= 1'b1;
      @(posedge feb_clk);
      feb_valid[lane] <= 1'b0;
      feb_startofpacket[lane] <= 1'b0;
      feb_endofpacket[lane] <= 1'b0;
      feb_debug_valid[lane] <= 1'b0;
      feb_data[lane*36 +: 36] <= '0;
      feb_debug_meta[lane*64 +: 64] <= '0;
    end
  endtask

  task automatic wait_until_hit_timebase(input longint unsigned abs_ts_8ns);
    begin
      while ($time < (abs_ts_8ns * 8ns)) begin
        @(posedge feb_clk);
      end
    end
  endtask

  function automatic int unsigned subheader_hit_count(
      input int unsigned lane,
      input int unsigned frame_id,
      input int unsigned shd_idx);
    int unsigned bucket_idx;
    begin
      if (lane >= ACTIVE_LANES) begin
        return 0;
      end
      bucket_idx = (frame_id * N_SHD) + shd_idx;
      if (bucket_idx >= total_source_buckets) begin
        return 0;
      end
      return bucket_hit_count[lane][bucket_idx];
    end
  endfunction

  task automatic push_source_hit(
      input int unsigned abs_ts_8ns,
      input int unsigned asic,
      input int unsigned channel,
      input int unsigned hit_id);
    source_hit_event_t hit;
    int unsigned bucket_idx;
    int unsigned lane;
    begin
      if (abs_ts_8ns >= run_window_8ns) begin
        return;
      end
      if (!rn_basic_source_selected(asic, channel)) begin
        return;
      end
      lane = source_lane_for_asic(asic);
      bucket_idx = abs_ts_8ns >> 4;
      if (bucket_idx >= total_source_buckets) begin
        $fatal(1, "source hit bucket outside runtime abs_ts=%0d bucket=%0d total=%0d",
               abs_ts_8ns, bucket_idx, total_source_buckets);
      end
      if (bucket_hit_count[lane][bucket_idx] >= 255) begin
        $fatal(1, "source lane %0d bucket %0d exceeds FEB subheader hit-count field",
               lane, bucket_idx);
      end
      hit.abs_ts_8ns = abs_ts_8ns;
      hit.lane = lane;
      hit.asic = asic;
      hit.channel = channel;
      hit.hit_id = hit_id;
      hit.bucket_idx = bucket_idx;
      source_hits_unsorted.push_back(hit);
      bucket_hit_count[lane][bucket_idx]++;
    end
  endtask

  task automatic generate_periodic_source_model();
    int unsigned hit_id;
    int unsigned sample_idx;
    int unsigned abs_ts_8ns;
    begin
      for (int unsigned asic = 0; asic < active_asic_count; asic++) begin
        sample_idx = 0;
        abs_ts_8ns = asic_phase_8ns(asic);
        while (abs_ts_8ns < run_window_8ns) begin
          for (int unsigned channel = 0; channel < CHANNELS_PER_ASIC; channel++) begin
            hit_id = (((sample_idx * active_asic_count) + asic) *
                      CHANNELS_PER_ASIC) + channel;
            push_source_hit(abs_ts_8ns, asic, channel, hit_id);
          end
          sample_idx++;
          abs_ts_8ns = asic_phase_8ns(asic) + (sample_idx * hit_period_8ns);
        end
      end
      expected_time_samples_runtime = source_hits_unsorted.size() / CHANNELS_PER_ASIC;
    end
  endtask

  function automatic int unsigned poisson_gap_8ns(ref int seed);
    int gap;
    begin
      gap = $dist_exponential(seed, hit_period_8ns);
      if (gap < 1) begin
        gap = 1;
      end
      return gap;
    end
  endfunction

  task automatic generate_poisson_source_model();
    int unsigned hit_id;
    int unsigned abs_ts_8ns;
    int seed;
    begin
      hit_id = 0;
      for (int unsigned asic = 0; asic < active_asic_count; asic++) begin
        for (int unsigned channel = 0; channel < CHANNELS_PER_ASIC; channel++) begin
          seed = int'((poisson_seed + (asic * 32'h0001_0001) +
                       (channel * 32'h0000_1009)) & 32'h7fff_ffff);
          if (seed == 0) begin
            seed = 1;
          end
          abs_ts_8ns = poisson_gap_8ns(seed);
          while (abs_ts_8ns < run_window_8ns) begin
            push_source_hit(abs_ts_8ns, asic, channel, hit_id);
            hit_id++;
            abs_ts_8ns += poisson_gap_8ns(seed);
          end
        end
      end
      expected_time_samples_runtime = 0;
    end
  endtask

  task automatic generate_header_sync_source_model();
    int unsigned hit_id;
    int unsigned abs_ts_8ns;
    int unsigned header_base_8ns;
    int unsigned phase_8ns;
    int unsigned burst_count;
    begin
      hit_id = 0;
      burst_count = (header_sync_burst_count == 0) ? 1 : header_sync_burst_count;
      header_base_8ns = 0;
      while ((header_base_8ns + header_sync_phase_8ns) < run_window_8ns) begin
        for (int unsigned burst_idx = 0; burst_idx < burst_count; burst_idx++) begin
          for (int unsigned asic = 0; asic < active_asic_count; asic++) begin
            phase_8ns = header_sync_phase_8ns +
                        (burst_idx * header_sync_burst_spacing_8ns) +
                        (asic * header_sync_asic_stagger_8ns);
            abs_ts_8ns = header_base_8ns + phase_8ns;
            if (abs_ts_8ns >= run_window_8ns) begin
              continue;
            end
            for (int unsigned channel = 0; channel < CHANNELS_PER_ASIC; channel++) begin
              push_source_hit(abs_ts_8ns, asic, channel, hit_id);
              hit_id++;
            end
          end
        end
        header_base_8ns += VIRTUAL_MUTRIG_SHORT_FRAME_8NS;
      end
      expected_time_samples_runtime = source_hits_unsorted.size() / CHANNELS_PER_ASIC;
    end
  endtask

  task automatic build_source_model();
    int unsigned bucket_next[ACTIVE_LANES][];
    int unsigned running;
    int unsigned dst;
    begin
      source_hits_unsorted.delete();
      for (int lane = 0; lane < ACTIVE_LANES; lane++) begin
        bucket_hit_count[lane] = new[total_source_buckets];
        bucket_first_idx[lane] = new[total_source_buckets];
        bucket_next[lane] = new[total_source_buckets];
      end

      if (source_mode == SOURCE_MODE_HEADER_SYNC) begin
        generate_header_sync_source_model();
      end else if (source_mode == SOURCE_MODE_POISSON) begin
        generate_poisson_source_model();
      end else begin
        generate_periodic_source_model();
      end

      source_hits = new[source_hits_unsorted.size()];
      running = 0;
      for (int lane = 0; lane < ACTIVE_LANES; lane++) begin
        for (int unsigned bucket = 0; bucket < total_source_buckets; bucket++) begin
          bucket_first_idx[lane][bucket] = running;
          bucket_next[lane][bucket] = running;
          running += bucket_hit_count[lane][bucket];
        end
      end

      foreach (source_hits_unsorted[idx]) begin
        dst = bucket_next[source_hits_unsorted[idx].lane][source_hits_unsorted[idx].bucket_idx];
        source_hits[dst] = source_hits_unsorted[idx];
        bucket_next[source_hits_unsorted[idx].lane][source_hits_unsorted[idx].bucket_idx]++;
      end
    end
  endtask

  function automatic int unsigned compute_expected_dma_words();
    int unsigned total_words;
    int unsigned frame_hits;
    int unsigned bucket_idx;
    begin
      total_words = 0;
      for (int unsigned frame = 0; frame < n_frames_runtime; frame++) begin
        frame_hits = 0;
        for (int unsigned shd = 0; shd < N_SHD; shd++) begin
          bucket_idx = (frame * N_SHD) + shd;
          for (int lane = 0; lane < ACTIVE_LANES; lane++) begin
            frame_hits += bucket_hit_count[lane][bucket_idx];
          end
        end
        total_words += (frame_hits + 3) / 4;
      end
      return total_words;
    end
  endfunction

  task automatic program_lookup_table();
    int unsigned addr;
    begin
      lookup_ctrl <= 32'h0;
      repeat (4) @(posedge swb_clk);
      for (int unsigned lane = 0; lane < ACTIVE_LANES; lane++) begin
        for (int unsigned asic = 0; asic < active_asic_count; asic++) begin
          addr = ((lane & 3'h7) << 4) | (asic & 4'hf);
          lookup_ctrl <= make_lookup_ctrl_word(addr, asic);
          @(posedge swb_clk);
        end
      end
      lookup_ctrl <= 32'h0;
      repeat (4) @(posedge swb_clk);
    end
  endtask

  task automatic write_hit_checkpoint(
      input int fd,
      input longint unsigned time_ps,
      input int lane,
      input int unsigned hit_id,
      input int unsigned channel,
      input int unsigned abs_ts_8ns,
      input logic [31:0] hit_word,
      input longint unsigned dma_hit,
      input logic [63:0] debug_meta);
    begin
      if (fd != 0) begin
        $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,0x%08h,0x%016h,0x%016h",
                  time_ps,
                  lane,
                  hit_id,
                  channel,
                  abs_ts_8ns,
                  hit_word,
                  dma_hit,
                  debug_meta);
      end
    end
  endtask

  task automatic drive_frame(input int lane, input int unsigned frame_id);
    longint unsigned frame_base;
    int unsigned shd_idx;
    int unsigned bucket_idx;
    int unsigned event_idx;
    int unsigned asic;
    int unsigned hit_count;
    int unsigned channel;
    int unsigned hit_id;
    int unsigned abs_ts_8ns;
    int unsigned total_hits;
    source_hit_event_t hit_event;
    logic [31:0] hit_word;
    logic [31:0] ts_high_word;
    logic [15:0] ts_low_word;
    logic [31:0] debug1_word;
    longint unsigned dispatch_time_8ns;
    longint unsigned source_time_ps;
    longint unsigned expected_dma_hit;
    logic [63:0] debug_meta;
    begin
      frame_base = frame_id * FRAME_STRIDE_8NS;
      ts_high_word = frame_base[47:16];
      ts_low_word = frame_base[15:0];
      debug1_word = (frame_base + FRAME_STRIDE_8NS) & 32'h7fff_ffff;
      dispatch_time_8ns =
          frame_base + (FEB_FRAME_EGRESS_DELAY_FRAMES * FRAME_STRIDE_8NS);
      total_hits = 0;

      for (int idx = 0; idx < N_SHD; idx++) begin
        total_hits += subheader_hit_count(lane, frame_id, idx);
      end

      wait_until_hit_timebase(dispatch_time_8ns);
      drive_feb_word(lane, 4'h1, make_sop(lane), 1'b1, 1'b0, 1'b0, 64'h0);
      drive_feb_word(lane, 4'h0, ts_high_word, 1'b0, 1'b0, 1'b0, 64'h0);
      drive_feb_word(lane, 4'h0, {ts_low_word, frame_id[15:0]}, 1'b0, 1'b0, 1'b0, 64'h0);
      drive_feb_word(lane, 4'h0, {1'b0, 15'(N_SHD), total_hits[15:0]}, 1'b0, 1'b0, 1'b0, 64'h0);
      drive_feb_word(lane, 4'h0, debug1_word, 1'b0, 1'b0, 1'b0, 64'h0);

      for (shd_idx = 0; shd_idx < N_SHD; shd_idx++) begin
        hit_count = subheader_hit_count(lane, frame_id, shd_idx);
        drive_feb_word(lane, 4'h1, make_subheader(shd_idx, hit_count),
                       1'b0, 1'b0, 1'b0, 64'h0);

        if (hit_count != 0) begin
          bucket_idx = (frame_id * N_SHD) + shd_idx;
          for (event_idx = bucket_first_idx[lane][bucket_idx];
               event_idx < (bucket_first_idx[lane][bucket_idx] + hit_count);
               event_idx++) begin
            hit_event = source_hits[event_idx];
            asic = hit_event.asic;
            channel = hit_event.channel;
            hit_id = hit_event.hit_id;
            abs_ts_8ns = hit_event.abs_ts_8ns;
            source_time_ps = longint'(abs_ts_8ns) * 8000;
            hit_word = make_mutrig_hit(abs_ts_8ns, asic, channel, hit_id);
            expected_dma_hit =
                expected_mutrig_dma_hit(ts_high_word, ts_low_word, shd_idx[7:0],
                                        hit_word, asic);
            debug_meta = make_debug_meta(lane, abs_ts_8ns, hit_id);
            expected_hits.push_back(expected_dma_hit);
            write_hit_checkpoint(source_trace_fd,
                                 source_time_ps,
                                 lane, hit_id, channel, abs_ts_8ns,
                                 hit_word, expected_dma_hit, debug_meta);
            write_hit_checkpoint(pre_rbcam_trace_fd,
                                 source_time_ps +
                                     (SYNTHETIC_PRE_RBCAM_DELAY_CYCLES * 8000),
                                 lane, hit_id, channel, abs_ts_8ns,
                                 hit_word, expected_dma_hit, debug_meta);
            write_hit_checkpoint(post_rbcam_trace_fd,
                                 source_time_ps +
                                     (SYNTHETIC_POST_RBCAM_DELAY_CYCLES * 8000),
                                 lane, hit_id, channel, abs_ts_8ns,
                                 hit_word, expected_dma_hit, debug_meta);
            drive_feb_word(lane, 4'h0, hit_word, 1'b0, 1'b0, 1'b1,
                           debug_meta);
            feb_hit_count++;
          end
        end
      end

      drive_feb_word(lane, 4'h1, {24'h0, SWB_K284}, 1'b0, 1'b1, 1'b0, 64'h0);
    end
  endtask

  task automatic drive_lane(input int lane);
    int unsigned frame_start_cycle;
    int unsigned next_frame_cycle;
    int unsigned driven_frames;
    begin
      wait (!reset);
      frame_start_cycle = 0;
      driven_frames = n_frames_runtime + flush_frames;
      for (int frame_id = 0; frame_id < driven_frames; frame_id++) begin
        drive_frame(lane, frame_id);
        next_frame_cycle = frame_start_cycle + FRAME_PERIOD_FEB_CYCLES;
        while ($time < (next_frame_cycle * 8ns)) begin
          @(posedge feb_clk);
        end
        frame_start_cycle = next_frame_cycle;
      end
    end
  endtask

  task automatic open_traces();
    begin
      if (!$value$plusargs("FEB_SWB_TRACE_DIR=%s", trace_dir)) begin
        trace_dir = "report";
      end
      source_trace_fd = 0;
      pre_rbcam_trace_fd = 0;
      post_rbcam_trace_fd = 0;
      feb_egress_trace_fd = 0;
      ingress_trace_fd = 0;
      feb_egress_waveform_fd = 0;
      ingress_waveform_fd = 0;
      opq_trace_fd = 0;
      dma_trace_fd = 0;
      if (!scan_only) begin
        source_trace_fd = $fopen({trace_dir, "/feb_swb_source_trace.csv"}, "w");
        pre_rbcam_trace_fd = $fopen({trace_dir, "/feb_swb_pre_rbcam_trace.csv"}, "w");
        post_rbcam_trace_fd = $fopen({trace_dir, "/feb_swb_post_rbcam_trace.csv"}, "w");
        feb_egress_trace_fd = $fopen({trace_dir, "/feb_swb_feb_egress_trace.csv"}, "w");
        ingress_trace_fd = $fopen({trace_dir, "/feb_swb_ingress_trace.csv"}, "w");
        feb_egress_waveform_fd = $fopen({trace_dir, "/feb_swb_feb_egress_waveform.csv"}, "w");
        ingress_waveform_fd = $fopen({trace_dir, "/feb_swb_swb_ingress_waveform.csv"}, "w");
        opq_trace_fd = $fopen({trace_dir, "/feb_swb_opq_trace.csv"}, "w");
        dma_trace_fd = $fopen({trace_dir, "/feb_swb_dma_trace.csv"}, "w");
      end
      summary_fd = $fopen({trace_dir, "/feb_swb_corun_summary.txt"}, "w");
      if ((!scan_only && (source_trace_fd == 0 || pre_rbcam_trace_fd == 0 ||
                          post_rbcam_trace_fd == 0 || feb_egress_trace_fd == 0 ||
                          ingress_trace_fd == 0 || feb_egress_waveform_fd == 0 ||
                          ingress_waveform_fd == 0 || opq_trace_fd == 0 ||
                          dma_trace_fd == 0)) ||
          summary_fd == 0) begin
        $fatal(1, "failed to open one or more trace files under %s", trace_dir);
      end
      if (!scan_only) begin
        $fdisplay(source_trace_fd,
                  "time_ps,lane,hit_id,channel,abs_ts_8ns,hit_word,expected_dma_hit,debug_meta");
        $fdisplay(pre_rbcam_trace_fd,
                  "time_ps,lane,hit_id,channel,abs_ts_8ns,hit_word,expected_dma_hit,debug_meta");
        $fdisplay(post_rbcam_trace_fd,
                  "time_ps,lane,hit_id,channel,abs_ts_8ns,hit_word,expected_dma_hit,debug_meta");
        $fdisplay(feb_egress_trace_fd,
                  "time_ps,lane,valid,datak,data,sop,eop,debug_valid,debug_meta");
        $fdisplay(ingress_trace_fd,
                  "time_ps,lane,valid,datak,data,sop,eop,debug_valid,debug_meta");
        $fdisplay(feb_egress_waveform_fd,
                  "time_ps,lane,channel,valid,ready,sop,eop,error,datak,data,debug_valid,debug_meta");
        $fdisplay(ingress_waveform_fd,
                  "time_ps,lane,channel,valid,ready,sop,eop,error,datak,data,debug_valid,debug_meta");
        $fdisplay(opq_trace_fd, "time_ps,valid,datak,data");
        $fdisplay(dma_trace_fd, "time_ps,wren,end_of_event,dma_done,data");
      end
    end
  endtask

  always @(posedge feb_clk) begin : feb_egress_trace_monitor
    if (!reset && !scan_only) begin
      for (int lane = 0; lane < ACTIVE_LANES; lane++) begin
        $fdisplay(feb_egress_waveform_fd,
                  "%0t,%0d,%0d,%0d,%0d,%0d,%0d,0,0x%1h,0x%08h,%0d,0x%016h",
                  $time,
                  lane,
                  lane,
                  feb_valid[lane],
                  feb_ready[lane],
                  feb_startofpacket[lane],
                  feb_endofpacket[lane],
                  feb_data[lane*36 + 32 +: 4],
                  feb_data[lane*36 +: 32],
                  feb_debug_valid[lane],
                  feb_debug_meta[lane*64 +: 64]);
        if (feb_valid[lane] && feb_ready[lane]) begin
          $fdisplay(feb_egress_trace_fd,
                    "%0t,%0d,1,0x%1h,0x%08h,%0d,%0d,%0d,0x%016h",
                    $time,
                    lane,
                    feb_data[lane*36 + 32 +: 4],
                    feb_data[lane*36 +: 32],
                    feb_startofpacket[lane],
                    feb_endofpacket[lane],
                    feb_debug_valid[lane],
                    feb_debug_meta[lane*64 +: 64]);
        end
      end
    end
  end

  always @(posedge swb_clk) begin : ingress_trace_monitor
    if (!reset && !scan_only) begin
      for (int lane = 0; lane < 4; lane++) begin
        $fdisplay(ingress_waveform_fd,
                  "%0t,%0d,%0d,%0d,1,%0d,%0d,0,0x%1h,0x%08h,%0d,0x%016h",
                  $time,
                  lane,
                  lane,
                  swb_valid[lane],
                  swb_startofpacket[lane],
                  swb_endofpacket[lane],
                  swb_datak[lane*4 +: 4],
                  swb_data[lane*32 +: 32],
                  swb_debug_valid[lane],
                  swb_debug_meta[lane*64 +: 64]);
        if (swb_valid[lane]) begin
          $fdisplay(ingress_trace_fd,
                    "%0t,%0d,1,0x%1h,0x%08h,%0d,%0d,%0d,0x%016h",
                    $time,
                    lane,
                    swb_datak[lane*4 +: 4],
                    swb_data[lane*32 +: 32],
                    swb_startofpacket[lane],
                    swb_endofpacket[lane],
                    swb_debug_valid[lane],
                    swb_debug_meta[lane*64 +: 64]);
        end
      end
    end
  end

  always @(posedge swb_clk) begin : opq_trace_monitor
    if (!reset && opq_valid) begin
      opq_beat_count++;
      if (!scan_only) begin
        $fdisplay(opq_trace_fd,
                  "%0t,1,0x%1h,0x%08h",
                  $time,
                  opq_datak,
                  opq_data);
      end
    end
  end

  always @(posedge swb_clk) begin : dma_trace_monitor
    longint unsigned hit_word;
    if (!reset) begin
      if (dma_wren) begin
        if (!scan_only) begin
          $fdisplay(dma_trace_fd,
                    "%0t,1,%0d,%0d,0x%064h",
                    $time,
                    end_of_event,
                    dma_done,
                    dma_data);
        end
        if (dma_data == DMA_PADDING_WORD) begin
          dma_padding_word_count++;
        end else begin
          dma_payload_word_count++;
          for (int slot = 0; slot < 4; slot++) begin
            hit_word = dma_data[slot*64 +: 64];
            if (hit_word != 64'h0) begin
              actual_hit_count++;
              if (!allow_drops) begin
                actual_hits.push_back(hit_word);
              end
            end
          end
        end
        if (end_of_event) begin
          end_of_event_count++;
        end
      end
      if (dma_done) begin
        dma_done_count++;
      end
    end
  end

  task automatic check_results();
    bit found;
    begin
      missing_count = 0;
      ghost_count = 0;

      if (allow_drops) begin
        if (expected_hits.size() >= actual_hit_count) begin
          missing_count = expected_hits.size() - actual_hit_count;
        end else begin
          ghost_count = actual_hit_count - expected_hits.size();
        end
      end else begin
        actual_hit_matched = new[actual_hits.size()];
        foreach (expected_hits[exp_idx]) begin
          found = 1'b0;
          foreach (actual_hits[act_idx]) begin
            if (!actual_hit_matched[act_idx] &&
                (actual_hits[act_idx] == expected_hits[exp_idx])) begin
              actual_hit_matched[act_idx] = 1'b1;
              found = 1'b1;
              break;
            end
          end
          if (!found) begin
            missing_count++;
            $error("missing DMA hit exp_idx=%0d hit=0x%016h",
                   exp_idx, expected_hits[exp_idx]);
          end
        end

        foreach (actual_hits[act_idx]) begin
          if (!actual_hit_matched[act_idx]) begin
            ghost_count++;
            $error("ghost DMA hit act_idx=%0d hit=0x%016h",
                   act_idx, actual_hits[act_idx]);
          end
        end
      end

      $fdisplay(summary_fd, "frames=%0d", n_frames_runtime);
      $fdisplay(summary_fd, "run_window_8ns=%0d", run_window_8ns);
      $fdisplay(summary_fd, "active_mask=0x%0h", swb_enable_mask);
      $fdisplay(summary_fd, "active_asics=%0d", active_asic_count);
      $fdisplay(summary_fd, "channels_per_asic=%0d", CHANNELS_PER_ASIC);
      $fdisplay(summary_fd, "rn_basic_lane_mask=0x%0h", rn_basic_lane_mask);
      $fdisplay(summary_fd, "rn_basic_channel_mask=0x%0h", rn_basic_channel_mask);
      $fdisplay(summary_fd, "allow_drops=%0d", allow_drops);
      $fdisplay(summary_fd, "scan_only=%0d", scan_only);
      $fdisplay(summary_fd, "drain_swb_cycles=%0d", drain_swb_cycles);
      $fdisplay(summary_fd, "flush_frames=%0d", flush_frames);
      $fdisplay(summary_fd, "source_mode=%s", source_mode_name(source_mode));
      $fdisplay(summary_fd, "poisson_seed=%0d", poisson_seed);
      $fdisplay(summary_fd, "header_sync_phase_8ns=%0d", header_sync_phase_8ns);
      $fdisplay(summary_fd, "header_sync_burst_count=%0d", header_sync_burst_count);
      $fdisplay(summary_fd, "header_sync_burst_spacing_8ns=%0d",
                header_sync_burst_spacing_8ns);
      $fdisplay(summary_fd, "header_sync_asic_stagger_8ns=%0d",
                header_sync_asic_stagger_8ns);
      $fdisplay(summary_fd, "hit_period_8ns=%0d", hit_period_8ns);
      $fdisplay(summary_fd, "hit_rate_hz_per_channel=%0d",
                (hit_period_8ns == 0) ? 0 : (125000000 / hit_period_8ns));
      $fdisplay(summary_fd, "feb_frame_egress_delay_frames=%0d",
                FEB_FRAME_EGRESS_DELAY_FRAMES);
      $fdisplay(summary_fd, "synthetic_pre_rbcam_delay_cycles=%0d",
                SYNTHETIC_PRE_RBCAM_DELAY_CYCLES);
      $fdisplay(summary_fd, "synthetic_post_rbcam_delay_cycles=%0d",
                SYNTHETIC_POST_RBCAM_DELAY_CYCLES);
      $fdisplay(summary_fd, "expected_time_samples=%0d", expected_time_samples_runtime);
      $fdisplay(summary_fd, "expected_hits=%0d", expected_hits.size());
      $fdisplay(summary_fd, "expected_dma_words=%0d", expected_dma_words_runtime);
      $fdisplay(summary_fd, "feb_hit_count=%0d", feb_hit_count);
      $fdisplay(summary_fd, "opq_beats=%0d", opq_beat_count);
      $fdisplay(summary_fd, "dma_payload_words=%0d", dma_payload_word_count);
      $fdisplay(summary_fd, "dma_padding_words=%0d", dma_padding_word_count);
      $fdisplay(summary_fd, "actual_hits=%0d", actual_hit_count);
      $fdisplay(summary_fd, "end_of_event_count=%0d", end_of_event_count);
      $fdisplay(summary_fd, "dma_done_count=%0d", dma_done_count);
      $fdisplay(summary_fd, "missing_hits=%0d", missing_count);
      $fdisplay(summary_fd, "ghost_hits=%0d", ghost_count);
      $fdisplay(summary_fd, "fifo_overflow=0x%0h", fifo_overflow);
      $fdisplay(summary_fd, "fifo_underflow=0x%0h", fifo_underflow);

      assert(swb_enable_mask == ((4'h1 << ACTIVE_LANES) - 4'h1))
        else $fatal(1, "SWB lane mask mismatch");
      assert(fifo_overflow == '0) else $fatal(1, "adapter FIFO overflow");
      assert(fifo_underflow == '0) else $fatal(1, "adapter FIFO underflow");
      assert(expected_hits.size() == expected_hits_runtime)
        else $fatal(1, "expected hit model mismatch: got %0d expected %0d",
                    expected_hits.size(), expected_hits_runtime);
      assert(feb_hit_count == expected_hits.size())
        else $fatal(1, "FEB hit count and expected ledger differ");
      assert(opq_beat_count != 0) else $fatal(1, "OPQ produced no egress beats");
      if (allow_drops) begin
        assert(actual_hit_count != 0) else $fatal(1, "scan delivered no DMA hits");
        $display("FEB_SWB_CORUN_SCAN_PASS expected_hits=%0d actual_hits=%0d missing_hits=%0d ghost_hits=%0d dma_payload_words=%0d opq_beats=%0d",
                 expected_hits.size(),
                 actual_hit_count,
                 missing_count,
                 ghost_count,
                 dma_payload_word_count,
                 opq_beat_count);
      end else begin
        assert(dma_payload_word_count == expected_dma_words_runtime)
          else $fatal(1, "DMA payload words got %0d expected %0d",
                      dma_payload_word_count, expected_dma_words_runtime);
        assert(end_of_event_count != 0) else $fatal(1, "no DMA end_of_event observed");
        assert(missing_count == 0) else $fatal(1, "missing DMA hits: %0d", missing_count);
        assert(ghost_count == 0) else $fatal(1, "ghost DMA hits: %0d", ghost_count);
        $display("FEB_SWB_CORUN_PLAIN_PASS expected_hits=%0d dma_payload_words=%0d opq_beats=%0d",
                 expected_hits.size(), dma_payload_word_count, opq_beat_count);
      end
    end
  endtask

  initial begin : tb_main
    feb_valid = '0;
    feb_data = '0;
    feb_startofpacket = '0;
    feb_endofpacket = '0;
    feb_debug_valid = '0;
    feb_debug_meta = '0;
    lookup_ctrl = 32'h0;
    feb_hit_count = 0;
    opq_beat_count = 0;
    dma_payload_word_count = 0;
    dma_padding_word_count = 0;
    actual_hit_count = 0;
    end_of_event_count = 0;
    dma_done_count = 0;
    allow_drops = 0;
    scan_only = 0;
    drain_swb_cycles = DEFAULT_DRAIN_SWB_CYCLES;
    flush_frames = DEFAULT_FLUSH_FRAMES;
    run_window_8ns = DEFAULT_RUN_WINDOW_8NS;
    hit_period_8ns = DEFAULT_HIT_PERIOD_8NS;
    active_asic_count = DEFAULT_ASIC_COUNT;
    source_mode = SOURCE_MODE_PERIODIC;
    poisson_seed = DEFAULT_POISSON_SEED;
    rn_basic_lane_mask = 64'h0000_0000_0000_00ff;
    rn_basic_channel_mask = 64'h0000_0000_ffff_ffff;
    header_sync_phase_8ns = DEFAULT_HEADER_SYNC_PHASE_8NS;
    header_sync_burst_count = DEFAULT_HEADER_SYNC_BURST_COUNT;
    header_sync_burst_spacing_8ns = DEFAULT_HEADER_SYNC_BURST_SPACING_8NS;
    header_sync_asic_stagger_8ns = DEFAULT_HEADER_SYNC_ASIC_STAGGER_8NS;
    if (!$value$plusargs("FEB_SWB_RUN_WINDOW_8NS=%d", run_window_8ns)) begin
      run_window_8ns = DEFAULT_RUN_WINDOW_8NS;
    end
    if (!$value$plusargs("FEB_SWB_HIT_PERIOD_8NS=%d", hit_period_8ns)) begin
      hit_period_8ns = DEFAULT_HIT_PERIOD_8NS;
    end
    if (!$value$plusargs("FEB_SWB_ASIC_COUNT=%d", active_asic_count)) begin
      active_asic_count = DEFAULT_ASIC_COUNT;
    end
    if (!$value$plusargs("FEB_SWB_ALLOW_DROPS=%d", allow_drops)) begin
      allow_drops = 0;
    end
    if (!$value$plusargs("FEB_SWB_SCAN_ONLY=%d", scan_only)) begin
      scan_only = 0;
    end
    if (!$value$plusargs("FEB_SWB_DRAIN_SWB_CYCLES=%d", drain_swb_cycles)) begin
      drain_swb_cycles = DEFAULT_DRAIN_SWB_CYCLES;
    end
    if (!$value$plusargs("FEB_SWB_FLUSH_FRAMES=%d", flush_frames)) begin
      flush_frames = DEFAULT_FLUSH_FRAMES;
    end
    if (scan_only) begin
      allow_drops = 1;
    end
    begin
      string source_mode_arg;
      if ($value$plusargs("FEB_SWB_SOURCE_MODE=%s", source_mode_arg)) begin
        if (source_mode_arg == "poisson" || source_mode_arg == "poisson_iid") begin
          source_mode = SOURCE_MODE_POISSON;
        end else if (source_mode_arg == "header_sync" ||
                     source_mode_arg == "header_sync_phase_staggered") begin
          source_mode = SOURCE_MODE_HEADER_SYNC;
        end else if (source_mode_arg == "periodic" ||
                     source_mode_arg == "periodic_phase_staggered") begin
          source_mode = SOURCE_MODE_PERIODIC;
        end else begin
          $fatal(1, "unknown FEB_SWB_SOURCE_MODE=%s", source_mode_arg);
        end
      end
    end
    if (!$value$plusargs("FEB_SWB_POISSON_SEED=%d", poisson_seed)) begin
      poisson_seed = DEFAULT_POISSON_SEED;
    end
    if (!$value$plusargs("RN_BASIC_LANE_MASK=%d", rn_basic_lane_mask)) begin
      rn_basic_lane_mask = 64'h0000_0000_0000_00ff;
    end
    if (!$value$plusargs("RN_BASIC_CHANNEL_MASK=%d", rn_basic_channel_mask)) begin
      rn_basic_channel_mask = 64'h0000_0000_ffff_ffff;
    end
    if (!$value$plusargs("FEB_SWB_HEADER_SYNC_PHASE_8NS=%d", header_sync_phase_8ns)) begin
      header_sync_phase_8ns = DEFAULT_HEADER_SYNC_PHASE_8NS;
    end
    if (!$value$plusargs("FEB_SWB_HEADER_SYNC_BURST_COUNT=%d", header_sync_burst_count)) begin
      header_sync_burst_count = DEFAULT_HEADER_SYNC_BURST_COUNT;
    end
    if (!$value$plusargs("FEB_SWB_HEADER_SYNC_BURST_SPACING_8NS=%d",
                         header_sync_burst_spacing_8ns)) begin
      header_sync_burst_spacing_8ns = DEFAULT_HEADER_SYNC_BURST_SPACING_8NS;
    end
    if (!$value$plusargs("FEB_SWB_HEADER_SYNC_ASIC_STAGGER_8NS=%d",
                         header_sync_asic_stagger_8ns)) begin
      header_sync_asic_stagger_8ns = DEFAULT_HEADER_SYNC_ASIC_STAGGER_8NS;
    end
    if (hit_period_8ns == 0 || run_window_8ns == 0 ||
        active_asic_count == 0 || active_asic_count > MAX_ASIC_COUNT) begin
      $fatal(1,
             "invalid FEB_SWB runtime config run_window_8ns=%0d hit_period_8ns=%0d asic_count=%0d",
             run_window_8ns, hit_period_8ns, active_asic_count);
    end
    if (source_mode == SOURCE_MODE_HEADER_SYNC &&
        (header_sync_phase_8ns >= VIRTUAL_MUTRIG_SHORT_FRAME_8NS ||
         header_sync_burst_spacing_8ns == 0 ||
         header_sync_asic_stagger_8ns == 0)) begin
      $fatal(1,
             "invalid header-sync config phase=%0d burst_spacing=%0d asic_stagger=%0d",
             header_sync_phase_8ns,
             header_sync_burst_spacing_8ns,
             header_sync_asic_stagger_8ns);
    end
    n_frames_runtime = (run_window_8ns + FRAME_STRIDE_8NS - 1) / FRAME_STRIDE_8NS;
    total_source_buckets = n_frames_runtime * N_SHD;
    expected_time_samples_runtime = 0;
    build_source_model();
    expected_hits_runtime = source_hits.size();
    expected_dma_words_runtime = compute_expected_dma_words();

    open_traces();

    repeat (16) @(posedge swb_clk);
    reset = 1'b0;
    program_lookup_table();

    fork
      drive_lane(0);
      drive_lane(1);
      drive_lane(2);
      drive_lane(3);
    join

    for (int cyc = 0; cyc < drain_swb_cycles; cyc++) begin
      @(posedge swb_clk);
      if (end_of_event_count != 0 && actual_hit_count >= expected_hits_runtime) begin
        break;
      end
    end

    repeat (64) @(posedge swb_clk);
    check_results();

    if (ingress_trace_fd != 0) $fclose(ingress_trace_fd);
    if (feb_egress_trace_fd != 0) $fclose(feb_egress_trace_fd);
    if (ingress_waveform_fd != 0) $fclose(ingress_waveform_fd);
    if (feb_egress_waveform_fd != 0) $fclose(feb_egress_waveform_fd);
    if (source_trace_fd != 0) $fclose(source_trace_fd);
    if (pre_rbcam_trace_fd != 0) $fclose(pre_rbcam_trace_fd);
    if (post_rbcam_trace_fd != 0) $fclose(post_rbcam_trace_fd);
    if (opq_trace_fd != 0) $fclose(opq_trace_fd);
    if (dma_trace_fd != 0) $fclose(dma_trace_fd);
    $fclose(summary_fd);
    $finish;
  end
endmodule
