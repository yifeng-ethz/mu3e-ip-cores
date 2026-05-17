// tb_hist_direct_v3.sv
// Direct FEB V3 histogram integration testbench.
//
// This tb_int harness intentionally does not instantiate histogram_ingress_bridge.
// It drives histogram_statistics_v2 through the explicit V3 Type0 lanes and
// Type1 up/down banks, including the 48-bit Type1 timestamp sideband.

`timescale 1ns/1ps

module tb_hist_direct_v3;
  localparam int unsigned CLK_HZ              = 125_000_000;
  localparam int unsigned CLK_PERIOD_NS       = 8;
  localparam int unsigned N_BINS              = 256;
  localparam int unsigned N_TYPE0_LANES       = 8;
  localparam int unsigned N_ASICS             = 16;
  localparam int unsigned CHANNELS_PER_ASIC   = 32;
  localparam int unsigned TYPE0_DATA_WIDTH    = 45;
  localparam int unsigned TYPE1_DATA_WIDTH    = 39;
  localparam int unsigned AVST_CHANNEL_WIDTH  = 4;
  localparam int unsigned HIST_ADDR_WIDTH     = 8;
  localparam int unsigned PINGPONG_1MS_CYCLES = 125_000;
  localparam int unsigned RUN_10MS_CYCLES     = 1_250_000;
  localparam int unsigned AVMM_TIMEOUT        = 4096;
  localparam int unsigned DELAY_TARGET_CYCLES = 4096;
  localparam int unsigned DELAY_BIN_WIDTH     = 32;

  localparam bit [1:0] SOURCE_TYPE0      = 2'd0;
  localparam bit [1:0] SOURCE_TYPE1_UP   = 2'd1;
  localparam bit [1:0] SOURCE_TYPE1_DOWN = 2'd2;

  localparam int unsigned CSR_CONTROL        = 2;
  localparam int unsigned CSR_LEFT_BOUND     = 3;
  localparam int unsigned CSR_RIGHT_BOUND    = 4;
  localparam int unsigned CSR_BIN_WIDTH      = 5;
  localparam int unsigned CSR_KEY_FILTER     = 6;
  localparam int unsigned CSR_KEY_FILTER_V   = 7;
  localparam int unsigned CSR_INTERVAL       = 10;
  localparam int unsigned CSR_BANK_STATUS    = 11;
  localparam int unsigned CSR_TOTAL_HITS     = 13;
  localparam int unsigned CSR_DROPPED_HITS   = 14;
  localparam int unsigned CSR_COAL_STATUS    = 15;
  localparam int unsigned CSR_LAST_TOTAL     = 17;
  localparam int unsigned CSR_LAST_DROPPED   = 18;

  string report_prefix;
  string case_select;
  int unsigned run_cycles;
  int unsigned interval_cycles;
  int unsigned prng_state;
  int unsigned fail_count;
  int unsigned pass_count;
  int summary_fd;
  int interval_fd;

  logic i_clk = 1'b0;
  logic i_rst = 1'b1;
  logic i_interval_reset = 1'b0;

  always #(CLK_PERIOD_NS/2) i_clk = ~i_clk;

  logic [31:0] csr_readdata;
  logic        csr_read = 1'b0;
  logic  [4:0] csr_address = '0;
  logic        csr_waitrequest;
  logic        csr_write = 1'b0;
  logic [31:0] csr_writedata = '0;

  logic [31:0] bin_readdata;
  logic        bin_read = 1'b0;
  logic [HIST_ADDR_WIDTH-1:0] bin_address = '0;
  logic        bin_waitrequest;
  logic        bin_write = 1'b0;
  logic [31:0] bin_writedata = '0;
  logic [HIST_ADDR_WIDTH:0] bin_burstcount = {{HIST_ADDR_WIDTH{1'b0}}, 1'b1};
  logic        bin_readdatavalid;
  logic        bin_writeresponsevalid;
  logic  [1:0] bin_response;

  logic [TYPE0_DATA_WIDTH-1:0]   type0_data  [N_TYPE0_LANES];
  logic                          type0_valid [N_TYPE0_LANES];
  logic                          type0_ready [N_TYPE0_LANES];
  logic [AVST_CHANNEL_WIDTH-1:0] type0_chan  [N_TYPE0_LANES];

  logic                          type1_up_ready;
  logic                          type1_up_valid = 1'b0;
  logic [TYPE1_DATA_WIDTH-1:0]   type1_up_data = '0;
  logic [47:0]                   type1_up_ts = '0;
  logic [AVST_CHANNEL_WIDTH-1:0] type1_up_chan = '0;
  logic                          type1_down_ready;
  logic                          type1_down_valid = 1'b0;
  logic [TYPE1_DATA_WIDTH-1:0]   type1_down_data = '0;
  logic [47:0]                   type1_down_ts = '0;
  logic [AVST_CHANNEL_WIDTH-1:0] type1_down_chan = '0;

  logic [8:0] ctrl_data = '0;
  logic       ctrl_valid = 1'b0;

  longint unsigned case_offered;
  longint unsigned case_accepted;
  longint unsigned case_ready_miss;
  longint unsigned case_interval_total;
  longint unsigned case_interval_dropped;
  longint unsigned case_interval_bin_sum;
  longint unsigned case_coal_overflow_max;
  int unsigned     case_delay_min_bin;
  int unsigned     case_delay_max_bin;
  int unsigned     case_interval_seen;
  string           mode_name;

  histogram_statistics_v2 #(
    .LOCK_KEY_RANGES          (1'b1),
    .POWER2_BIN_WIDTH_ONLY    (1'b1),
    .SAR_TICK_WIDTH           (21),
    .N_BINS                   (N_BINS),
    .MAX_COUNT_BITS           (20),
    .DEF_LEFT_BOUND           (0),
    .DEF_BIN_WIDTH            (32),
    .AVS_ADDR_WIDTH           (HIST_ADDR_WIDTH),
    .N_PORTS                  (N_TYPE0_LANES),
    .FIFO_ADDR_WIDTH          (2),
    .CHANNELS_PER_PORT        (CHANNELS_PER_ASIC),
    .COAL_QUEUE_DEPTH         (4),
    .ENABLE_PINGPONG          (1'b1),
    .DEF_INTERVAL_CLOCKS      (PINGPONG_1MS_CYCLES),
    .AVST_DATA_WIDTH          (TYPE0_DATA_WIDTH),
    .TYPE0_DATA_WIDTH         (TYPE0_DATA_WIDTH),
    .TYPE1_DATA_WIDTH         (TYPE1_DATA_WIDTH),
    .AVST_CHANNEL_WIDTH       (AVST_CHANNEL_WIDTH),
    .KICK_COUNT_WIDTH         (4),
    .N_DEBUG_INTERFACE        (0),
    .ENABLE_DEBUG_INPUTS      (1'b0),
    .VERSION_MAJOR            (26),
    .VERSION_MINOR            (3),
    .VERSION_PATCH            (0),
    .BUILD                    (517),
    .VERSION_DATE             (20260517),
    .SNOOP_EN                 (1'b0),
    .ENABLE_PACKET            (1'b0),
    .DEBUG                    (0)
  ) dut (
    .avs_hist_bin_readdata           (bin_readdata),
    .avs_hist_bin_read               (bin_read),
    .avs_hist_bin_address            (bin_address),
    .avs_hist_bin_waitrequest        (bin_waitrequest),
    .avs_hist_bin_write              (bin_write),
    .avs_hist_bin_writedata          (bin_writedata),
    .avs_hist_bin_burstcount         (bin_burstcount),
    .avs_hist_bin_readdatavalid      (bin_readdatavalid),
    .avs_hist_bin_writeresponsevalid (bin_writeresponsevalid),
    .avs_hist_bin_response           (bin_response),

    .avs_csr_readdata                (csr_readdata),
    .avs_csr_read                    (csr_read),
    .avs_csr_address                 (csr_address),
    .avs_csr_waitrequest             (csr_waitrequest),
    .avs_csr_write                   (csr_write),
    .avs_csr_writedata               (csr_writedata),

    .asi_type0_lane0_ready           (type0_ready[0]),
    .asi_type0_lane0_valid           (type0_valid[0]),
    .asi_type0_lane0_data            (type0_data[0]),
    .asi_type0_lane0_startofpacket   (1'b0),
    .asi_type0_lane0_endofpacket     (1'b0),
    .asi_type0_lane0_channel         (type0_chan[0]),
    .asi_type0_lane0_error           (3'b000),
    .asi_type0_lane0_endofrun        (1'b0),
    .asi_type0_lane1_ready           (type0_ready[1]),
    .asi_type0_lane1_valid           (type0_valid[1]),
    .asi_type0_lane1_data            (type0_data[1]),
    .asi_type0_lane1_startofpacket   (1'b0),
    .asi_type0_lane1_endofpacket     (1'b0),
    .asi_type0_lane1_channel         (type0_chan[1]),
    .asi_type0_lane1_error           (3'b000),
    .asi_type0_lane1_endofrun        (1'b0),
    .asi_type0_lane2_ready           (type0_ready[2]),
    .asi_type0_lane2_valid           (type0_valid[2]),
    .asi_type0_lane2_data            (type0_data[2]),
    .asi_type0_lane2_startofpacket   (1'b0),
    .asi_type0_lane2_endofpacket     (1'b0),
    .asi_type0_lane2_channel         (type0_chan[2]),
    .asi_type0_lane2_error           (3'b000),
    .asi_type0_lane2_endofrun        (1'b0),
    .asi_type0_lane3_ready           (type0_ready[3]),
    .asi_type0_lane3_valid           (type0_valid[3]),
    .asi_type0_lane3_data            (type0_data[3]),
    .asi_type0_lane3_startofpacket   (1'b0),
    .asi_type0_lane3_endofpacket     (1'b0),
    .asi_type0_lane3_channel         (type0_chan[3]),
    .asi_type0_lane3_error           (3'b000),
    .asi_type0_lane3_endofrun        (1'b0),
    .asi_type0_lane4_ready           (type0_ready[4]),
    .asi_type0_lane4_valid           (type0_valid[4]),
    .asi_type0_lane4_data            (type0_data[4]),
    .asi_type0_lane4_startofpacket   (1'b0),
    .asi_type0_lane4_endofpacket     (1'b0),
    .asi_type0_lane4_channel         (type0_chan[4]),
    .asi_type0_lane4_error           (3'b000),
    .asi_type0_lane4_endofrun        (1'b0),
    .asi_type0_lane5_ready           (type0_ready[5]),
    .asi_type0_lane5_valid           (type0_valid[5]),
    .asi_type0_lane5_data            (type0_data[5]),
    .asi_type0_lane5_startofpacket   (1'b0),
    .asi_type0_lane5_endofpacket     (1'b0),
    .asi_type0_lane5_channel         (type0_chan[5]),
    .asi_type0_lane5_error           (3'b000),
    .asi_type0_lane5_endofrun        (1'b0),
    .asi_type0_lane6_ready           (type0_ready[6]),
    .asi_type0_lane6_valid           (type0_valid[6]),
    .asi_type0_lane6_data            (type0_data[6]),
    .asi_type0_lane6_startofpacket   (1'b0),
    .asi_type0_lane6_endofpacket     (1'b0),
    .asi_type0_lane6_channel         (type0_chan[6]),
    .asi_type0_lane6_error           (3'b000),
    .asi_type0_lane6_endofrun        (1'b0),
    .asi_type0_lane7_ready           (type0_ready[7]),
    .asi_type0_lane7_valid           (type0_valid[7]),
    .asi_type0_lane7_data            (type0_data[7]),
    .asi_type0_lane7_startofpacket   (1'b0),
    .asi_type0_lane7_endofpacket     (1'b0),
    .asi_type0_lane7_channel         (type0_chan[7]),
    .asi_type0_lane7_error           (3'b000),
    .asi_type0_lane7_endofrun        (1'b0),

    .asi_type1_up_ready              (type1_up_ready),
    .asi_type1_up_valid              (type1_up_valid),
    .asi_type1_up_data               (type1_up_data),
    .asi_type1_up_ts                 (type1_up_ts),
    .asi_type1_up_startofpacket      (1'b0),
    .asi_type1_up_endofpacket        (1'b0),
    .asi_type1_up_channel            (type1_up_chan),
    .asi_type1_up_empty              (1'b0),
    .asi_type1_up_error              (1'b0),
    .asi_type1_down_ready            (type1_down_ready),
    .asi_type1_down_valid            (type1_down_valid),
    .asi_type1_down_data             (type1_down_data),
    .asi_type1_down_ts               (type1_down_ts),
    .asi_type1_down_startofpacket    (1'b0),
    .asi_type1_down_endofpacket      (1'b0),
    .asi_type1_down_channel          (type1_down_chan),
    .asi_type1_down_empty            (1'b0),
    .asi_type1_down_error            (1'b0),

    .aso_hist_fill_out_ready         (1'b1),
    .aso_hist_fill_out_valid         (),
    .aso_hist_fill_out_data          (),
    .aso_hist_fill_out_startofpacket (),
    .aso_hist_fill_out_endofpacket   (),
    .aso_hist_fill_out_channel       (),

    .asi_ctrl_data                   (ctrl_data),
    .asi_ctrl_valid                  (ctrl_valid),
    .asi_debug_1_valid               (1'b0),
    .asi_debug_1_data                (16'h0000),
    .asi_debug_2_valid               (1'b0),
    .asi_debug_2_data                (16'h0000),
    .asi_debug_3_valid               (1'b0),
    .asi_debug_3_data                (16'h0000),
    .asi_debug_4_valid               (1'b0),
    .asi_debug_4_data                (16'h0000),
    .asi_debug_5_valid               (1'b0),
    .asi_debug_5_data                (16'h0000),
    .asi_debug_6_valid               (1'b0),
    .asi_debug_6_data                (16'h0000),

    .i_interval_reset                (i_interval_reset),
    .i_rst                           (i_rst),
    .i_clk                           (i_clk)
  );

  function automatic int unsigned prng_next();
    prng_state = prng_state * 32'd1103515245 + 32'd12345;
    return prng_state;
  endfunction

  function automatic logic [TYPE0_DATA_WIDTH-1:0] make_type0_word(
    input int unsigned asic_id,
    input int unsigned channel_id,
    input int unsigned tcc
  );
    logic [TYPE0_DATA_WIDTH-1:0] word_v;
    int unsigned ecc_v;
    word_v = '0;
    ecc_v = tcc ^ (asic_id << 5) ^ channel_id;
    word_v[44:41] = asic_id[3:0];
    word_v[40:36] = channel_id[4:0];
    word_v[35:21] = tcc[14:0];
    word_v[20:16] = channel_id[4:0];
    word_v[15:1]  = ecc_v[14:0];
    word_v[0]     = 1'b0;
    return word_v;
  endfunction

  function automatic logic [TYPE1_DATA_WIDTH-1:0] make_type1_word(
    input int unsigned asic_id,
    input int unsigned channel_id,
    input int unsigned tcc_8n
  );
    logic [TYPE1_DATA_WIDTH-1:0] word_v;
    int unsigned tfine_v;
    int unsigned et_v;
    word_v = '0;
    tfine_v = channel_id ^ asic_id;
    et_v = tcc_8n ^ (asic_id << 4) ^ channel_id;
    word_v[38:35] = asic_id[3:0];
    word_v[34:30] = channel_id[4:0];
    word_v[29:17] = tcc_8n[12:0];
    word_v[16:14] = channel_id[2:0];
    word_v[13:9]  = tfine_v[4:0];
    word_v[8:0]   = et_v[8:0];
    return word_v;
  endfunction

  task automatic clear_streams();
    for (int lane = 0; lane < N_TYPE0_LANES; lane++) begin
      type0_valid[lane] = 1'b0;
      type0_data[lane]  = '0;
      type0_chan[lane]  = '0;
    end
    type1_up_valid   = 1'b0;
    type1_up_data    = '0;
    type1_up_ts      = '0;
    type1_up_chan    = '0;
    type1_down_valid = 1'b0;
    type1_down_data  = '0;
    type1_down_ts    = '0;
    type1_down_chan  = '0;
  endtask

  task automatic do_reset();
    i_rst = 1'b1;
    i_interval_reset = 1'b0;
    ctrl_valid = 1'b0;
    ctrl_data = '0;
    csr_read = 1'b0;
    csr_write = 1'b0;
    bin_read = 1'b0;
    bin_write = 1'b0;
    clear_streams();
    repeat (32) @(posedge i_clk);
    i_rst = 1'b0;
    wait_initial_clear();
    repeat (16) @(posedge i_clk);
  endtask

  task automatic wait_initial_clear();
    int unsigned timeout_cyc;
    timeout_cyc = 0;
    while (dut.flushing !== 1'b0) begin
      @(posedge i_clk);
      timeout_cyc++;
      if (timeout_cyc > 20000) begin
        $fatal(1, "timeout waiting for histogram clear");
      end
    end
    repeat (8) @(posedge i_clk);
  endtask

  task automatic wait_pipeline_drain(input int unsigned cycles = 2048);
    repeat (cycles) @(posedge i_clk);
  endtask

  task automatic pulse_interval_reset();
    @(posedge i_clk);
    i_interval_reset <= 1'b1;
    @(posedge i_clk);
    i_interval_reset <= 1'b0;
    repeat (2) @(posedge i_clk);
  endtask

  task automatic send_ctrl(input logic [8:0] data_word);
    @(posedge i_clk);
    ctrl_data  <= data_word;
    ctrl_valid <= 1'b1;
    @(posedge i_clk);
    ctrl_valid <= 1'b0;
    ctrl_data  <= '0;
    repeat (2) @(posedge i_clk);
  endtask

  task automatic csr_write32(input int unsigned addr, input logic [31:0] data);
    @(posedge i_clk);
    csr_address   <= addr[4:0];
    csr_writedata <= data;
    csr_write     <= 1'b1;
    csr_read      <= 1'b0;
    @(posedge i_clk);
    csr_write     <= 1'b0;
    csr_address   <= '0;
    csr_writedata <= '0;
  endtask

  task automatic csr_read32(input int unsigned addr, output logic [31:0] data);
    @(posedge i_clk);
    csr_address <= addr[4:0];
    csr_read    <= 1'b1;
    csr_write   <= 1'b0;
    @(posedge i_clk);
    csr_read    <= 1'b0;
    csr_address <= '0;
    @(posedge i_clk);
    data = csr_readdata;
  endtask

  task automatic bin_read32(input int unsigned addr, output logic [31:0] data);
    int unsigned cyc;
    @(posedge i_clk);
    bin_address    <= addr[HIST_ADDR_WIDTH-1:0];
    bin_read       <= 1'b1;
    bin_write      <= 1'b0;
    bin_burstcount <= {{HIST_ADDR_WIDTH{1'b0}}, 1'b1};
    @(posedge i_clk);
    bin_read    <= 1'b0;
    bin_address <= '0;
    cyc = 0;
    while (!bin_readdatavalid) begin
      @(posedge i_clk);
      cyc++;
      if (cyc > AVMM_TIMEOUT) begin
        $fatal(1, "bin_read32 timeout addr=%0d", addr);
      end
    end
    data = bin_readdata;
  endtask

  task automatic read_all_bins(
    output longint unsigned bin_sum,
    output int unsigned nonzero_min_bin,
    output int unsigned nonzero_max_bin
  );
    logic [31:0] data_v;
    bin_sum = 0;
    nonzero_min_bin = N_BINS;
    nonzero_max_bin = 0;
    for (int bin = 0; bin < N_BINS; bin++) begin
      bin_read32(bin, data_v);
      bin_sum += data_v;
      if (data_v != 0) begin
        if (bin < nonzero_min_bin) nonzero_min_bin = bin;
        if (bin > nonzero_max_bin) nonzero_max_bin = bin;
      end
    end
  endtask

  task automatic program_histogram(
    input bit [1:0] source_select,
    input bit       delay_mode,
    input bit       filter_enable,
    input int unsigned filter_key,
    input int unsigned interval_cfg
  );
    logic [31:0] control_word;
    int signed left_bound_v;
    int unsigned bin_width_v;
    logic [31:0] control_rb;
    logic [31:0] interval_rb;
    logic [31:0] right_rb;

    if (delay_mode) begin
      left_bound_v = 0;
      bin_width_v = DELAY_BIN_WIDTH;
    end else if (source_select == SOURCE_TYPE0) begin
      left_bound_v = 0;
      bin_width_v = 256;
    end else begin
      left_bound_v = 0;
      bin_width_v = 32;
    end

    csr_write32(CSR_KEY_FILTER, 32'h261d_2311);
    csr_write32(CSR_KEY_FILTER_V, {filter_key[15:0], 16'h0000});
    csr_write32(CSR_LEFT_BOUND, $unsigned(left_bound_v));
    csr_write32(CSR_BIN_WIDTH, bin_width_v[31:0]);
    csr_write32(CSR_INTERVAL, interval_cfg[31:0]);

    control_word = 32'h0000_0001;
    control_word[7:4]   = delay_mode ? 4'h1 : 4'h0;
    control_word[8]     = 1'b1;
    control_word[12]    = filter_enable;
    control_word[13]    = 1'b0;
    control_word[17:16] = source_select;
    csr_write32(CSR_CONTROL, control_word);
    repeat (16) @(posedge i_clk);

    csr_read32(CSR_CONTROL, control_rb);
    csr_read32(CSR_INTERVAL, interval_rb);
    csr_read32(CSR_RIGHT_BOUND, right_rb);
    if (control_rb[24]) begin
      $display("FAIL configure: CONTROL error word=0x%08h", control_rb);
      fail_count++;
    end
    if (control_rb[17:16] !== source_select) begin
      $display("FAIL configure: source_select readback=%0d expected=%0d", control_rb[17:16], source_select);
      fail_count++;
    end
    if (control_rb[7:4] !== (delay_mode ? 4'h1 : 4'h0)) begin
      $display("FAIL configure: mode readback=%0d expected=%0d", control_rb[7:4], delay_mode ? 1 : 0);
      fail_count++;
    end
    if (interval_rb != interval_cfg) begin
      $display("FAIL configure: interval readback=%0d expected=%0d", interval_rb, interval_cfg);
      fail_count++;
    end
    $display("CONFIG source=%0d mode=%0d interval=%0d right_bound=%0d control=0x%08h",
             source_select, delay_mode ? 1 : 0, interval_rb, right_rb, control_rb);
  endtask

  task automatic drive_type0_case(
    input int unsigned rate_hz,
    input bit          all_channels
  );
    int unsigned period;
    int unsigned next_due[N_ASICS];
    int unsigned fixed_ch[N_ASICS];
    int unsigned hit_index[N_ASICS];
    bit          lane_has_hit[N_TYPE0_LANES];
    int unsigned lane_asic[N_TYPE0_LANES];
    int unsigned lane_ch[N_TYPE0_LANES];
    int unsigned lane_tcc[N_TYPE0_LANES];

    period = CLK_HZ / rate_hz;
    for (int asic = 0; asic < N_ASICS; asic++) begin
      fixed_ch[asic]  = (prng_next() >> 8) % CHANNELS_PER_ASIC;
      hit_index[asic] = 0;
      next_due[asic]  = ((asic % 8) * (period / 8 + 1) + ((asic / 8) * (period / 2 + 3))) % period;
    end

    for (int cyc = 0; cyc < run_cycles; cyc++) begin
      @(negedge i_clk);
      for (int lane = 0; lane < N_TYPE0_LANES; lane++) begin
        lane_has_hit[lane] = 1'b0;
        type0_valid[lane] <= 1'b0;
        type0_data[lane]  <= '0;
        type0_chan[lane]  <= '0;
      end
      for (int asic = 0; asic < N_ASICS; asic++) begin
        if (cyc == next_due[asic]) begin
          int lane;
          lane = asic & 7;
          if (lane_has_hit[lane]) begin
            next_due[asic] = cyc + 1;
          end else begin
            lane_has_hit[lane] = 1'b1;
            lane_asic[lane] = asic;
            lane_ch[lane] = all_channels ? ((prng_next() >> 12) % CHANNELS_PER_ASIC) : fixed_ch[asic];
            lane_tcc[lane] = (cyc + asic * 17 + hit_index[asic]) & 15'h7fff;
            next_due[asic] = cyc + period;
            hit_index[asic]++;
          end
        end
      end
      for (int lane = 0; lane < N_TYPE0_LANES; lane++) begin
        if (lane_has_hit[lane]) begin
          type0_data[lane]  <= make_type0_word(lane_asic[lane], lane_ch[lane], lane_tcc[lane]);
          type0_chan[lane]  <= lane_asic[lane][AVST_CHANNEL_WIDTH-1:0];
          type0_valid[lane] <= 1'b1;
          case_offered++;
        end
      end
      @(posedge i_clk);
      for (int lane = 0; lane < N_TYPE0_LANES; lane++) begin
        if (type0_valid[lane]) begin
          if (type0_ready[lane]) case_accepted++;
          else case_ready_miss++;
        end
      end
    end
    @(negedge i_clk);
    clear_streams();
  endtask

	  task automatic drive_type1_case(
	    input bit [1:0]    source_select,
	    input int unsigned rate_hz,
	    input bit          all_channels,
	    input bit          delay_mode
  );
    int unsigned period;
    int unsigned next_due[N_ASICS];
    int unsigned fixed_ch[N_ASICS];
    int unsigned hit_index[N_ASICS];
    bit          has_hit;
    int unsigned hit_asic;
    int unsigned hit_ch;
    int unsigned hit_tcc;
    logic [47:0] gts_sample;
    logic [47:0] hit_ts;
    logic [47:0] delay_target_v;

    period = CLK_HZ / rate_hz;
    delay_target_v = DELAY_TARGET_CYCLES;
    for (int asic = 0; asic < N_ASICS; asic++) begin
      fixed_ch[asic]  = (prng_next() >> 8) % CHANNELS_PER_ASIC;
      hit_index[asic] = 0;
      next_due[asic]  = (asic * (period / N_ASICS + 1)) % period;
    end

    for (int cyc = 0; cyc < run_cycles; cyc++) begin
      @(negedge i_clk);
      has_hit = 1'b0;
      type1_up_valid   <= 1'b0;
      type1_up_data    <= '0;
      type1_up_ts      <= '0;
      type1_up_chan    <= '0;
      type1_down_valid <= 1'b0;
      type1_down_data  <= '0;
      type1_down_ts    <= '0;
      type1_down_chan  <= '0;

      for (int asic = 0; asic < N_ASICS; asic++) begin
        if (cyc == next_due[asic]) begin
          if (has_hit) begin
            next_due[asic] = cyc + 1;
          end else begin
            has_hit = 1'b1;
            hit_asic = asic;
            hit_ch = all_channels ? ((prng_next() >> 12) % CHANNELS_PER_ASIC) : fixed_ch[asic];
            hit_tcc = (cyc + asic * 17 + hit_index[asic]) & 13'h1fff;
            next_due[asic] = cyc + period;
            hit_index[asic]++;
          end
        end
      end

      if (has_hit) begin
        gts_sample = dut.gts_8n;
        hit_ts = delay_mode ? (gts_sample - delay_target_v) : 48'h0;
        if (source_select == SOURCE_TYPE1_UP) begin
          type1_up_data  <= make_type1_word(hit_asic, hit_ch, hit_tcc);
          type1_up_ts    <= hit_ts;
          type1_up_chan  <= hit_asic[AVST_CHANNEL_WIDTH-1:0];
          type1_up_valid <= 1'b1;
        end else begin
          type1_down_data  <= make_type1_word(hit_asic, hit_ch, hit_tcc);
          type1_down_ts    <= hit_ts;
          type1_down_chan  <= hit_asic[AVST_CHANNEL_WIDTH-1:0];
          type1_down_valid <= 1'b1;
        end
        case_offered++;
      end

      @(posedge i_clk);
      if (source_select == SOURCE_TYPE1_UP) begin
        if (type1_up_valid) begin
          if (type1_up_ready) case_accepted++;
          else case_ready_miss++;
        end
      end else begin
        if (type1_down_valid) begin
          if (type1_down_ready) case_accepted++;
          else case_ready_miss++;
        end
      end
    end
    @(negedge i_clk);
    clear_streams();
  endtask

  task automatic interval_readback_monitor(
    input string       case_name,
    input bit          delay_mode,
    input int unsigned rate_hz,
    input string       pattern
  );
    logic [31:0] last_total_v;
    logic [31:0] last_dropped_v;
    logic [31:0] coal_v;
    logic [31:0] bank_v;
    longint unsigned bin_sum_v;
    int unsigned min_bin_v;
    int unsigned max_bin_v;

    for (int interval_idx = 0; interval_idx < (run_cycles / interval_cycles); interval_idx++) begin
      while (dut.interval_pulse !== 1'b1) begin
        @(posedge i_clk);
      end
      @(posedge i_clk);
      while (dut.flushing === 1'b1) begin
        @(posedge i_clk);
      end
      repeat (4) @(posedge i_clk);
      csr_read32(CSR_LAST_TOTAL, last_total_v);
      csr_read32(CSR_LAST_DROPPED, last_dropped_v);
      csr_read32(CSR_COAL_STATUS, coal_v);
      csr_read32(CSR_BANK_STATUS, bank_v);
      read_all_bins(bin_sum_v, min_bin_v, max_bin_v);

      case_interval_seen++;
      case_interval_total += last_total_v;
      case_interval_dropped += last_dropped_v;
      case_interval_bin_sum += bin_sum_v;
      if (coal_v[31:16] > case_coal_overflow_max) begin
        case_coal_overflow_max = coal_v[31:16];
      end
      if (delay_mode && (bin_sum_v != 0)) begin
        if (min_bin_v < case_delay_min_bin) case_delay_min_bin = min_bin_v;
        if (max_bin_v > case_delay_max_bin) case_delay_max_bin = max_bin_v;
      end

      $fwrite(interval_fd,
              "%s,%0d,%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%08h,0x%08h\n",
              case_name, interval_idx, rate_hz, pattern, delay_mode,
              last_total_v, last_dropped_v, bin_sum_v, min_bin_v, max_bin_v,
              case_interval_total, case_interval_dropped, case_interval_bin_sum,
              coal_v, bank_v);
    end
  endtask

  task automatic reset_case_counters();
    case_offered          = 0;
    case_accepted         = 0;
    case_ready_miss       = 0;
    case_interval_total   = 0;
    case_interval_dropped = 0;
    case_interval_bin_sum = 0;
    case_coal_overflow_max = 0;
    case_delay_min_bin    = N_BINS;
    case_delay_max_bin    = 0;
    case_interval_seen    = 0;
  endtask

  function automatic longint unsigned expected_hits_for_case(
    input bit [1:0]    source_select,
    input int unsigned rate_hz
  );
    int unsigned period;

    if (rate_hz == 0) begin
      return 0;
    end
    period = CLK_HZ / rate_hz;
    if ((period == 0) || ((CLK_HZ % rate_hz) != 0) || ((run_cycles % period) != 0)) begin
      $fatal(1, "rate_hz=%0d does not declare an exact integer-cycle stimulus for run_cycles=%0d",
             rate_hz, run_cycles);
    end
    return longint'(N_ASICS) * longint'(run_cycles / period);
  endfunction

	  task automatic run_hist_case(
	    input string       source_name,
	    input bit [1:0]    source_select,
	    input bit          delay_mode,
	    input int unsigned rate_hz,
    input bit          all_channels
  );
    string case_name;
    string pattern;
    bit case_pass;
    real seconds_v;
    real per_asic_rate_v;
    int unsigned expected_intervals;
    int unsigned expected_delay_bin;
    longint unsigned expected_hits;

    pattern = all_channels ? "all_ch_all_asic" : "one_random_ch_per_asic";
    mode_name = delay_mode ? "latency" : "rate";
    case_name = $sformatf("%s_%s_%0dk_%s",
                          source_name,
                          mode_name,
                          rate_hz / 1000,
                          all_channels ? "allch" : "onech");
    expected_intervals = run_cycles / interval_cycles;
    expected_delay_bin = DELAY_TARGET_CYCLES / DELAY_BIN_WIDTH;
    expected_hits = expected_hits_for_case(source_select, rate_hz);

    $display("CASE_START %s source=%0d delay=%0d rate_hz=%0d pattern=%s expected_hits=%0d",
             case_name, source_select, delay_mode, rate_hz, pattern, expected_hits);

    do_reset();
    reset_case_counters();
    send_ctrl(9'h002); // RUN_PREPARE: configure before RUNNING.
    program_histogram(source_select, delay_mode, 1'b0, 0, interval_cycles);
    send_ctrl(9'h004); // SYNC: reset internal GTS.
    repeat (8) @(posedge i_clk);
    send_ctrl(9'h008); // RUNNING.
    if (delay_mode) begin
      repeat (DELAY_TARGET_CYCLES + 64) @(posedge i_clk);
    end else begin
      repeat (64) @(posedge i_clk);
    end
    pulse_interval_reset();

    fork
      begin
        if (source_select == SOURCE_TYPE0) begin
          drive_type0_case(rate_hz, all_channels);
        end else begin
          drive_type1_case(source_select, rate_hz, all_channels, delay_mode);
        end
      end
      interval_readback_monitor(case_name, delay_mode, rate_hz, pattern);
    join

    wait_pipeline_drain(2048);
    case_pass = 1'b1;
    if (case_interval_seen != expected_intervals) begin
      $display("FAIL %s interval_count=%0d expected=%0d", case_name, case_interval_seen, expected_intervals);
      case_pass = 1'b0;
    end
    if (expected_hits == 0) begin
      $display("FAIL %s declared zero expected_hits; rate stimulus must produce hits", case_name);
      case_pass = 1'b0;
    end
    if (case_offered != expected_hits) begin
      $display("FAIL %s offered=%0d expected_declared=%0d", case_name, case_offered, expected_hits);
      case_pass = 1'b0;
    end
    if (case_ready_miss != 0) begin
      $display("FAIL %s ready_miss=%0d", case_name, case_ready_miss);
      case_pass = 1'b0;
    end
    if (case_accepted != expected_hits) begin
      $display("FAIL %s accepted=%0d expected_declared=%0d", case_name, case_accepted, expected_hits);
      case_pass = 1'b0;
    end
    if (case_interval_total != expected_hits) begin
      $display("FAIL %s interval_total=%0d expected_declared=%0d", case_name, case_interval_total, expected_hits);
      case_pass = 1'b0;
    end
    if (case_interval_bin_sum != expected_hits) begin
      $display("FAIL %s bin_sum=%0d expected_declared=%0d", case_name, case_interval_bin_sum, expected_hits);
      case_pass = 1'b0;
    end
    if (case_interval_dropped != 0) begin
      $display("FAIL %s interval_dropped=%0d", case_name, case_interval_dropped);
      case_pass = 1'b0;
    end
    if (!((rate_hz == 1_000_000) && all_channels) && (case_coal_overflow_max != 0)) begin
      $display("FAIL %s coalescer_overflow_max=%0d", case_name, case_coal_overflow_max);
      case_pass = 1'b0;
    end
    if (delay_mode) begin
      if (case_delay_min_bin == N_BINS) begin
        $display("FAIL %s no delay bins observed", case_name);
        case_pass = 1'b0;
      end else if ((case_delay_min_bin + 1 < expected_delay_bin) ||
                   (case_delay_max_bin > expected_delay_bin + 1)) begin
        $display("FAIL %s delay bins [%0d,%0d] expected around %0d",
                 case_name, case_delay_min_bin, case_delay_max_bin, expected_delay_bin);
        case_pass = 1'b0;
      end
    end

    seconds_v = real'(run_cycles) / real'(CLK_HZ);
    per_asic_rate_v = (real'(case_interval_total) / seconds_v) / real'(N_ASICS);
    $fwrite(summary_fd,
            "%s,%s,%s,%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.3f,%s\n",
            case_name, source_name, mode_name,
            rate_hz, pattern, run_cycles, interval_cycles,
            expected_hits, case_offered, case_accepted, case_ready_miss,
            case_interval_seen, case_interval_total,
            case_interval_dropped, case_interval_bin_sum,
            case_coal_overflow_max, case_delay_min_bin, case_delay_max_bin,
            per_asic_rate_v, case_pass ? "PASS" : "FAIL");

    if (case_pass) begin
      pass_count++;
      $display("CASE_PASS %s expected=%0d offered=%0d total=%0d per_asic_rate_hz=%0.3f delay_bins=[%0d,%0d]",
               case_name, expected_hits, case_offered, case_interval_total, per_asic_rate_v,
               case_delay_min_bin, case_delay_max_bin);
    end else begin
      fail_count++;
      $display("CASE_FAIL %s expected=%0d offered=%0d total=%0d dropped=%0d ready_miss=%0d coal_overflow_max=%0d",
               case_name, expected_hits, case_offered, case_interval_total, case_interval_dropped,
               case_ready_miss, case_coal_overflow_max);
	    end
	  endtask

  task automatic run_matrix();
    int unsigned rates[3];
    rates[0] = 100_000;
    rates[1] = 500_000;
    rates[2] = 1_000_000;

    for (int r = 0; r < 3; r++) begin
      run_hist_case("type0", SOURCE_TYPE0, 1'b0, rates[r], 1'b0);
      run_hist_case("type0", SOURCE_TYPE0, 1'b0, rates[r], 1'b1);
    end

    for (int r = 0; r < 3; r++) begin
      for (int pat = 0; pat < 2; pat++) begin
        run_hist_case("type1_up", SOURCE_TYPE1_UP, 1'b0, rates[r], pat[0]);
        run_hist_case("type1_up", SOURCE_TYPE1_UP, 1'b1, rates[r], pat[0]);
        run_hist_case("type1_down", SOURCE_TYPE1_DOWN, 1'b0, rates[r], pat[0]);
        run_hist_case("type1_down", SOURCE_TYPE1_DOWN, 1'b1, rates[r], pat[0]);
      end
    end
  endtask

  task automatic run_smoke();
    run_hist_case("type0", SOURCE_TYPE0, 1'b0, 100_000, 1'b0);
    run_hist_case("type1_up", SOURCE_TYPE1_UP, 1'b0, 100_000, 1'b0);
    run_hist_case("type1_up", SOURCE_TYPE1_UP, 1'b1, 100_000, 1'b0);
    run_hist_case("type1_down", SOURCE_TYPE1_DOWN, 1'b0, 100_000, 1'b0);
    run_hist_case("type1_down", SOURCE_TYPE1_DOWN, 1'b1, 100_000, 1'b0);
  endtask

  task automatic run_type0_rate_max();
    run_hist_case("type0", SOURCE_TYPE0, 1'b0, 1_000_000, 1'b1);
  endtask

  initial begin
    report_prefix = "tb_int/REPORT/hist_direct_v3";
    case_select = "matrix";
    run_cycles = RUN_10MS_CYCLES;
    interval_cycles = PINGPONG_1MS_CYCLES;
    prng_state = 32'h20260517;
    fail_count = 0;
    pass_count = 0;
    clear_streams();

    void'($value$plusargs("REPORT_PREFIX=%s", report_prefix));
    void'($value$plusargs("CASE=%s", case_select));
    void'($value$plusargs("RUN_CYCLES=%d", run_cycles));
    void'($value$plusargs("INTERVAL_CYCLES=%d", interval_cycles));
    void'($value$plusargs("SEED=%d", prng_state));

    if ((run_cycles % interval_cycles) != 0) begin
      $fatal(1, "RUN_CYCLES=%0d must be an integer multiple of INTERVAL_CYCLES=%0d",
             run_cycles, interval_cycles);
    end

    summary_fd = $fopen({report_prefix, "_summary.csv"}, "w");
    interval_fd = $fopen({report_prefix, "_intervals.csv"}, "w");
    if (summary_fd == 0 || interval_fd == 0) begin
      $fatal(1, "failed to open report files for prefix %s", report_prefix);
    end
    $fwrite(summary_fd,
            "case,source,mode,rate_hz,pattern,run_cycles,interval_cycles,expected,offered,accepted,ready_miss,intervals,total,dropped,bin_sum,coal_overflow_max,delay_min_bin,delay_max_bin,per_asic_rate_hz,result\n");
    $fwrite(interval_fd,
            "case,interval_idx,rate_hz,pattern,delay_mode,last_total,last_dropped,bin_sum,min_bin,max_bin,total_accum,dropped_accum,bin_sum_accum,coal_status,bank_status\n");

    $display("TB_INT_DIRECT_V3_START case=%s run_cycles=%0d interval_cycles=%0d seed=%0d report_prefix=%s",
             case_select, run_cycles, interval_cycles, prng_state, report_prefix);
    if (case_select == "smoke") begin
      run_smoke();
    end else if (case_select == "type0_rate_max") begin
      run_type0_rate_max();
    end else begin
      run_matrix();
    end

    $fclose(summary_fd);
    $fclose(interval_fd);
    $display("TB_INT_DIRECT_V3_DONE pass_count=%0d fail_count=%0d", pass_count, fail_count);
    if (fail_count != 0) begin
      $fatal(1, "tb_hist_direct_v3 saw %0d failing cases", fail_count);
    end
    $finish;
  end
endmodule
