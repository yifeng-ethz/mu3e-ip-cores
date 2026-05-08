`timescale 1ns/1ps

module feb_swb_corun_plain_tb;
  import feb_swb_corun_pkg::*;

  localparam int ACTIVE_LANES = 2;
  localparam int N_SHD = 128;
  localparam int N_FRAMES = 7;
  localparam int HIT_PERIOD_8NS = 1250; // 100 kHz on the MuTRiG 8 ns timebase.
  localparam int FRAME_STRIDE_8NS = N_SHD << 4;
  localparam int FRAME_PERIOD_FEB_CYCLES = FRAME_STRIDE_8NS;
  localparam int EXPECTED_HITS =
      ((N_FRAMES * FRAME_STRIDE_8NS) + HIT_PERIOD_8NS - 1) / HIT_PERIOD_8NS;
  localparam int EXPECTED_DMA_WORDS = (EXPECTED_HITS + 3) / 4;
  localparam int TIMEOUT_SWB_CYCLES = 200000;
  localparam int unsigned NO_HIT_ID = 32'hffff_ffff;

  localparam logic [5:0] SWB_SCIFI_HEADER_ID = 6'b111000;
  localparam logic [7:0] SWB_K285 = 8'hBC;
  localparam logic [7:0] SWB_K284 = 8'h9C;
  localparam logic [7:0] SWB_K237 = 8'hF7;
  localparam logic [255:0] DMA_PADDING_WORD = {256{1'b1}};

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
  int unsigned end_of_event_count;
  int unsigned dma_done_count;
  int unsigned missing_count;
  int unsigned ghost_count;

  int ingress_trace_fd;
  int opq_trace_fd;
  int dma_trace_fd;
  int summary_fd;
  string trace_dir;

  assign reset_n = !reset;
  assign swb_err_desc = '0;
  assign use_merge = 1'b1;
  assign enable_dma = !reset;
  assign get_n_words = EXPECTED_DMA_WORDS[31:0];
  assign lookup_ctrl = 32'h0000_0000;
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
      input int unsigned hit_id);
    logic [31:0] word;
    begin
      word = '0;
      word[31:28] = abs_ts_8ns[3:0];
      word[25:22] = 4'd0;      // ASIC 0.
      word[21:17] = 5'd0;      // Channel 0.
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
      input logic [31:0] hit_word);
    longint unsigned data_word;
    begin
      data_word = 64'h0;
      data_word[63] = 1'b1;
      data_word[62:61] = 2'b00;
      data_word[60:56] = hit_word[21:17];
      data_word[55:47] = hit_word[8:0];
      data_word[46:44] = hit_word[16:14];
      data_word[43:39] = hit_word[13:9];
      data_word[38:0] = {
        ts_high_word[22:0],
        ts_low_word[15:12],
        shd_ts[7:0],
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

  function automatic int unsigned subheader_hit_id(
      input int unsigned lane,
      input int unsigned frame_id,
      input int unsigned shd_idx);
    longint unsigned frame_base;
    longint unsigned shd_base;
    longint unsigned shd_end;
    int unsigned hit_idx;
    begin
      if (lane != 0) begin
        return NO_HIT_ID;
      end
      frame_base = longint'(frame_id) * FRAME_STRIDE_8NS;
      shd_base = frame_base + (longint'(shd_idx) << 4);
      shd_end = shd_base + 16;
      hit_idx = shd_base / HIT_PERIOD_8NS;
      if ((longint'(hit_idx) * HIT_PERIOD_8NS) < shd_base) begin
        hit_idx++;
      end
      if ((longint'(hit_idx) * HIT_PERIOD_8NS) < shd_end) begin
        return hit_idx;
      end
      return NO_HIT_ID;
    end
  endfunction

  function automatic int unsigned subheader_hit_count(
      input int unsigned lane,
      input int unsigned frame_id,
      input int unsigned shd_idx);
    int unsigned hit_id_v;
    begin
      hit_id_v = subheader_hit_id(lane, frame_id, shd_idx);
      return (hit_id_v == NO_HIT_ID) ? 0 : 1;
    end
  endfunction

  task automatic drive_frame(input int lane, input int unsigned frame_id);
    longint unsigned frame_base;
    int unsigned shd_idx;
    int unsigned hit_count;
    int unsigned hit_id;
    int unsigned abs_ts_8ns;
    int unsigned total_hits;
    logic [31:0] hit_word;
    logic [31:0] ts_high_word;
    logic [15:0] ts_low_word;
    logic [31:0] debug1_word;
    begin
      frame_base = frame_id * FRAME_STRIDE_8NS;
      ts_high_word = frame_base[47:16];
      ts_low_word = frame_base[15:0];
      debug1_word = (frame_base + FRAME_STRIDE_8NS) & 32'h7fff_ffff;
      total_hits = 0;

      for (int idx = 0; idx < N_SHD; idx++) begin
        total_hits += subheader_hit_count(lane, frame_id, idx);
      end

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
          hit_id = subheader_hit_id(lane, frame_id, shd_idx);
          abs_ts_8ns = hit_id * HIT_PERIOD_8NS;
          hit_word = make_mutrig_hit(abs_ts_8ns, hit_id);
          expected_hits.push_back(expected_mutrig_dma_hit(
              ts_high_word, ts_low_word, shd_idx[7:0], hit_word));
          drive_feb_word(lane, 4'h0, hit_word, 1'b0, 1'b0, 1'b1,
                         make_debug_meta(lane, abs_ts_8ns, hit_id));
          feb_hit_count++;
        end
      end

      drive_feb_word(lane, 4'h1, {24'h0, SWB_K284}, 1'b0, 1'b1, 1'b0, 64'h0);
    end
  endtask

  task automatic drive_lane(input int lane);
    int unsigned frame_start_cycle;
    int unsigned next_frame_cycle;
    begin
      wait (!reset);
      frame_start_cycle = 0;
      for (int frame_id = 0; frame_id < N_FRAMES; frame_id++) begin
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
      ingress_trace_fd = $fopen({trace_dir, "/feb_swb_ingress_trace.csv"}, "w");
      opq_trace_fd = $fopen({trace_dir, "/feb_swb_opq_trace.csv"}, "w");
      dma_trace_fd = $fopen({trace_dir, "/feb_swb_dma_trace.csv"}, "w");
      summary_fd = $fopen({trace_dir, "/feb_swb_corun_summary.txt"}, "w");
      if (ingress_trace_fd == 0 || opq_trace_fd == 0 ||
          dma_trace_fd == 0 || summary_fd == 0) begin
        $fatal(1, "failed to open one or more trace files under %s", trace_dir);
      end
      $fdisplay(ingress_trace_fd,
                "time_ps,lane,valid,datak,data,sop,eop,debug_valid,debug_meta");
      $fdisplay(opq_trace_fd, "time_ps,valid,datak,data");
      $fdisplay(dma_trace_fd, "time_ps,wren,end_of_event,dma_done,data");
    end
  endtask

  always @(posedge swb_clk) begin : ingress_trace_monitor
    if (!reset) begin
      for (int lane = 0; lane < 4; lane++) begin
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
      $fdisplay(opq_trace_fd,
                "%0t,1,0x%1h,0x%08h",
                $time,
                opq_datak,
                opq_data);
    end
  end

  always @(posedge swb_clk) begin : dma_trace_monitor
    longint unsigned hit_word;
    if (!reset) begin
      if (dma_wren) begin
        $fdisplay(dma_trace_fd,
                  "%0t,1,%0d,%0d,0x%064h",
                  $time,
                  end_of_event,
                  dma_done,
                  dma_data);
        if (dma_data == DMA_PADDING_WORD) begin
          dma_padding_word_count++;
        end else begin
          dma_payload_word_count++;
          for (int slot = 0; slot < 4; slot++) begin
            hit_word = dma_data[slot*64 +: 64];
            if (hit_word != 64'h0) begin
              actual_hits.push_back(hit_word);
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
      actual_hit_matched = new[actual_hits.size()];
      missing_count = 0;
      ghost_count = 0;

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

      $fdisplay(summary_fd, "frames=%0d", N_FRAMES);
      $fdisplay(summary_fd, "active_mask=0x%0h", swb_enable_mask);
      $fdisplay(summary_fd, "hit_rate_hz=100000");
      $fdisplay(summary_fd, "expected_hits=%0d", expected_hits.size());
      $fdisplay(summary_fd, "feb_hit_count=%0d", feb_hit_count);
      $fdisplay(summary_fd, "opq_beats=%0d", opq_beat_count);
      $fdisplay(summary_fd, "dma_payload_words=%0d", dma_payload_word_count);
      $fdisplay(summary_fd, "dma_padding_words=%0d", dma_padding_word_count);
      $fdisplay(summary_fd, "actual_hits=%0d", actual_hits.size());
      $fdisplay(summary_fd, "end_of_event_count=%0d", end_of_event_count);
      $fdisplay(summary_fd, "dma_done_count=%0d", dma_done_count);
      $fdisplay(summary_fd, "missing_hits=%0d", missing_count);
      $fdisplay(summary_fd, "ghost_hits=%0d", ghost_count);
      $fdisplay(summary_fd, "fifo_overflow=0x%0h", fifo_overflow);
      $fdisplay(summary_fd, "fifo_underflow=0x%0h", fifo_underflow);

      assert(swb_enable_mask == 4'h3) else $fatal(1, "SWB lane mask mismatch");
      assert(fifo_overflow == '0) else $fatal(1, "adapter FIFO overflow");
      assert(fifo_underflow == '0) else $fatal(1, "adapter FIFO underflow");
      assert(expected_hits.size() == EXPECTED_HITS)
        else $fatal(1, "expected hit model mismatch: got %0d expected %0d",
                    expected_hits.size(), EXPECTED_HITS);
      assert(feb_hit_count == expected_hits.size())
        else $fatal(1, "FEB hit count and expected ledger differ");
      assert(opq_beat_count != 0) else $fatal(1, "OPQ produced no egress beats");
      assert(dma_payload_word_count == EXPECTED_DMA_WORDS)
        else $fatal(1, "DMA payload words got %0d expected %0d",
                    dma_payload_word_count, EXPECTED_DMA_WORDS);
      assert(end_of_event_count != 0) else $fatal(1, "no DMA end_of_event observed");
      assert(missing_count == 0) else $fatal(1, "missing DMA hits: %0d", missing_count);
      assert(ghost_count == 0) else $fatal(1, "ghost DMA hits: %0d", ghost_count);
      $display("FEB_SWB_CORUN_PLAIN_PASS expected_hits=%0d dma_payload_words=%0d opq_beats=%0d",
               expected_hits.size(), dma_payload_word_count, opq_beat_count);
    end
  endtask

  initial begin : tb_main
    feb_valid = '0;
    feb_data = '0;
    feb_startofpacket = '0;
    feb_endofpacket = '0;
    feb_debug_valid = '0;
    feb_debug_meta = '0;
    feb_hit_count = 0;
    opq_beat_count = 0;
    dma_payload_word_count = 0;
    dma_padding_word_count = 0;
    end_of_event_count = 0;
    dma_done_count = 0;

    open_traces();

    repeat (16) @(posedge swb_clk);
    reset = 1'b0;

    fork
      drive_lane(0);
      drive_lane(1);
    join

    for (int cyc = 0; cyc < TIMEOUT_SWB_CYCLES; cyc++) begin
      @(posedge swb_clk);
      if (end_of_event_count != 0 && actual_hits.size() >= EXPECTED_HITS) begin
        break;
      end
    end

    repeat (64) @(posedge swb_clk);
    check_results();

    $fclose(ingress_trace_fd);
    $fclose(opq_trace_fd);
    $fclose(dma_trace_fd);
    $fclose(summary_fd);
    $finish;
  end
endmodule
