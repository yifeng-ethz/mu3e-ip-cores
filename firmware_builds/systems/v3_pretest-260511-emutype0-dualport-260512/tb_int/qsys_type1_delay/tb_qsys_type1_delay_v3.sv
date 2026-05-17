// Generated-Qsys FEB V3 Type1 delay/rate smoke.
//
// This bench instantiates the regenerated scifi_datapath_system_v3 top and
// drives only public Qsys boundary ports: top AVMM, run-control, clocks, and
// resets. Internal references are monitor-only checkpoints at the Type1
// histogram ingress tap.

`timescale 1ns/1ps

module tb_qsys_type1_delay_v3;
  localparam int unsigned CLK_HZ              = 125_000_000;
  localparam int unsigned N_BINS              = 256;
  localparam int unsigned RUN_10MS_CYCLES     = 1_250_000;
  localparam int unsigned PINGPONG_1MS_CYCLES = 125_000;
  localparam int unsigned DELAY_BIN_WIDTH     = 32;
  localparam int unsigned RBCAM_LOW_CYCLES    = 0;
  localparam int unsigned RBCAM_HIGH_CYCLES   = 2000;
  localparam int unsigned AVMM_TIMEOUT        = 200_000;
  localparam int unsigned RC_TIMEOUT          = 20_000;

  localparam int unsigned AVMM_EMU_BASE       = 14'h0800;
  localparam int unsigned AVMM_RUNCTL_BASE    = 14'h0880;
  localparam int unsigned AVMM_ARB_BASE       = 14'h08a0;
  localparam int unsigned AVMM_ARB_STRIDE     = 14'h0020;
  localparam int unsigned AVMM_HIST_BIN_BASE  = 14'h2800;
  localparam int unsigned AVMM_HIST_CSR_BASE  = 14'h2900;
  localparam int unsigned AVMM_INJ_BASE       = 14'h2c80;

  localparam int unsigned CSR_CONTROL         = 2;
  localparam int unsigned CSR_LEFT_BOUND      = 3;
  localparam int unsigned CSR_RIGHT_BOUND     = 4;
  localparam int unsigned CSR_BIN_WIDTH       = 5;
  localparam int unsigned CSR_KEY_FILTER      = 6;
  localparam int unsigned CSR_KEY_FILTER_V    = 7;
  localparam int unsigned CSR_INTERVAL        = 10;
  localparam int unsigned CSR_TOTAL_HITS      = 13;
  localparam int unsigned CSR_DROPPED_HITS    = 14;
  localparam int unsigned CSR_LAST_TOTAL      = 17;
  localparam int unsigned CSR_LAST_DROPPED    = 18;

  localparam int unsigned SRC_TYPE1_UP        = 1;
  localparam int unsigned SRC_TYPE1_DOWN      = 2;

  localparam logic [8:0] RC_IDLE              = 9'b000000001;
  localparam logic [8:0] RC_RUN_PREPARE       = 9'b000000010;
  localparam logic [8:0] RC_SYNC              = 9'b000000100;
  localparam logic [8:0] RC_RUNNING           = 9'b000001000;
  localparam logic [8:0] RC_TERMINATING       = 9'b000010000;

  logic avmm_clk_clk = 1'b0;
  logic lvds_pll_inclock_clk = 1'b0;
  logic monitor_clock_125_in_clk = 1'b0;
  logic osc_clock_50_in_clk = 1'b0;
  logic xcvr_clock_clk = 1'b0;

  always #4  avmm_clk_clk = ~avmm_clk_clk;
  always #4  lvds_pll_inclock_clk = ~lvds_pll_inclock_clk;
  always #4  monitor_clock_125_in_clk = ~monitor_clock_125_in_clk;
  always #10 osc_clock_50_in_clk = ~osc_clock_50_in_clk;
  always #4  xcvr_clock_clk = ~xcvr_clock_clk;

  logic        avmm_port_waitrequest;
  logic [31:0] avmm_port_readdata;
  logic        avmm_port_readdatavalid;
  logic [8:0]  avmm_port_burstcount = 9'd1;
  logic [31:0] avmm_port_writedata = 32'd0;
  logic [13:0] avmm_port_address = 14'd0;
  logic        avmm_port_write = 1'b0;
  logic        avmm_port_read = 1'b0;
  logic [3:0]  avmm_port_byteenable = 4'hf;
  logic        avmm_port_debugaccess = 1'b0;
  logic        avmm_rst_reset = 1'b1;
  logic        counter_sclr_reset = 1'b1;

  logic [35:0] hit_type3_lower_data;
  logic        hit_type3_lower_valid;
  logic        hit_type3_lower_ready = 1'b1;
  logic        hit_type3_lower_startofpacket;
  logic        hit_type3_lower_endofpacket;
  logic        hit_type3_upper_valid;
  logic        hit_type3_upper_startofpacket;
  logic        hit_type3_upper_endofpacket;
  logic [0:0]  hit_type3_upper_empty;
  logic [35:0] hit_type3_upper_data;
  logic        inject_pulse;
  logic        inject_masked_pulse;
  logic        inject_aux_pulse = 1'b0;
  logic        lvds_outclock_clk;
  logic        monitor_reset_in_reset_reset_n = 1'b0;
  logic [1:0]  mutrig_reset_reset;
  logic [8:0]  redriver_losn = 9'h1ff;
  logic [8:0]  rstlink_data;
  logic [3:0]  rstlink_channel;
  logic [2:0]  rstlink_error;
  logic [8:0]  runctl_mgmt_host_data = 9'd0;
  logic        runctl_mgmt_host_valid = 1'b0;
  logic        runctl_mgmt_host_ready;
  logic [8:0]  serial_data = 9'd0;
  logic        xcvr_reset_reset_n = 1'b0;

  string report_prefix;
  string source_name;
  string case_mode;
  string case_name;
  string pattern_name;
  string delay_model;
  int unsigned rate_hz;
  int unsigned run_cycles;
  int unsigned interval_cycles;
  int unsigned trigger_interval_cycles;
  int unsigned source_select;
  int unsigned active_asics;
  int unsigned delay_target_cycles;
  int unsigned fail_count;
  int unsigned interval_seen;
  bit debug_tail;

  int summary_fd;
  int delay_fd;
  int meta_fd;

  longint unsigned data_cycle;
  longint unsigned run_start_cycle;
  longint unsigned run_end_cycle;
  longint unsigned interval_pulse_count;
  longint unsigned interval_pulse_consumed;
  longint unsigned pulse_count;
  longint unsigned pulse_expected;
  longint unsigned meta_total;
  longint unsigned expected_hits;
  longint unsigned last_total_sum;
  longint unsigned last_dropped_sum;
  longint unsigned bin_sum;
  longint unsigned csr_total;
  longint unsigned csr_dropped;
  longint unsigned csr_bins[N_BINS];
  longint unsigned meta_bins[N_BINS];
  int unsigned asic_seen[8];
  int unsigned meta_first_bin;
  int unsigned meta_last_bin;
  int unsigned csr_first_bin;
  int unsigned csr_last_bin;
  int unsigned csr_nonzero_bins;
  int unsigned meta_nonzero_bins;

  logic inject_pulse_q;

  scifi_datapath_system_v3 dut (
    .avmm_clk_clk(avmm_clk_clk),
    .avmm_port_waitrequest(avmm_port_waitrequest),
    .avmm_port_readdata(avmm_port_readdata),
    .avmm_port_readdatavalid(avmm_port_readdatavalid),
    .avmm_port_burstcount(avmm_port_burstcount),
    .avmm_port_writedata(avmm_port_writedata),
    .avmm_port_address(avmm_port_address),
    .avmm_port_write(avmm_port_write),
    .avmm_port_read(avmm_port_read),
    .avmm_port_byteenable(avmm_port_byteenable),
    .avmm_port_debugaccess(avmm_port_debugaccess),
    .avmm_rst_reset(avmm_rst_reset),
    .counter_sclr_reset(counter_sclr_reset),
    .hit_type3_lower_data(hit_type3_lower_data),
    .hit_type3_lower_valid(hit_type3_lower_valid),
    .hit_type3_lower_ready(hit_type3_lower_ready),
    .hit_type3_lower_startofpacket(hit_type3_lower_startofpacket),
    .hit_type3_lower_endofpacket(hit_type3_lower_endofpacket),
    .hit_type3_upper_valid(hit_type3_upper_valid),
    .hit_type3_upper_startofpacket(hit_type3_upper_startofpacket),
    .hit_type3_upper_endofpacket(hit_type3_upper_endofpacket),
    .hit_type3_upper_empty(hit_type3_upper_empty),
    .hit_type3_upper_data(hit_type3_upper_data),
    .inject_pulse(inject_pulse),
    .inject_masked_pulse(inject_masked_pulse),
    .inject_aux_pulse(inject_aux_pulse),
    .lvds_outclock_clk(lvds_outclock_clk),
    .lvds_pll_inclock_clk(lvds_pll_inclock_clk),
    .monitor_clock_125_in_clk(monitor_clock_125_in_clk),
    .monitor_reset_in_reset_reset_n(monitor_reset_in_reset_reset_n),
    .mutrig_reset_reset(mutrig_reset_reset),
    .osc_clock_50_in_clk(osc_clock_50_in_clk),
    .redriver_losn(redriver_losn),
    .rstlink_data(rstlink_data),
    .rstlink_channel(rstlink_channel),
    .rstlink_error(rstlink_error),
    .runctl_mgmt_host_data(runctl_mgmt_host_data),
    .runctl_mgmt_host_valid(runctl_mgmt_host_valid),
    .runctl_mgmt_host_ready(runctl_mgmt_host_ready),
    .serial_data(serial_data),
    .xcvr_clock_clk(xcvr_clock_clk),
    .xcvr_reset_reset_n(xcvr_reset_reset_n)
  );

  function automatic string rate_label(input int unsigned hz);
    if (hz == 1_000_000) begin
      return "1000k";
    end
    return $sformatf("%0dk", hz / 1000);
  endfunction

  function automatic int unsigned source_default_filter_key(input int unsigned src);
    return (src == SRC_TYPE1_DOWN) ? 4 : 0;
  endfunction

  function automatic int is_in_expected_bank(input int unsigned asic);
    if (source_select == SRC_TYPE1_UP) begin
      return (asic < 4);
    end
    return ((asic >= 4) && (asic < 8));
  endfunction

  task automatic note_fail(input string msg);
    begin
      fail_count++;
      $display("QSYS_TYPE1_DELAY_FAIL %s", msg);
    end
  endtask

  task automatic avmm_tick;
    begin
      @(posedge avmm_clk_clk);
      #1ps;
    end
  endtask

  task automatic avmm_write(input int unsigned addr, input logic [31:0] data);
    int unsigned guard;
    begin
      avmm_tick();
      avmm_port_address <= addr[13:0];
      avmm_port_writedata <= data;
      avmm_port_byteenable <= 4'hf;
      avmm_port_burstcount <= 9'd1;
      avmm_port_write <= 1'b1;
      avmm_port_read <= 1'b0;
      guard = 0;
      do begin
        avmm_tick();
        guard++;
        if (guard > AVMM_TIMEOUT) begin
          $fatal(1, "AVMM write timeout addr=0x%0h data=0x%08h", addr, data);
        end
      end while (avmm_port_waitrequest !== 1'b0);
      avmm_port_write <= 1'b0;
      avmm_port_address <= 14'd0;
      avmm_port_writedata <= 32'd0;
      avmm_tick();
    end
  endtask

  task automatic dump_avmm_debug(input string tag, input int unsigned addr);
    begin
      $display("AVMM_DEBUG %s addr=0x%0h top rd=%b wr=%b wait=%b rdv=%b rdata=0x%08h",
               tag,
               addr,
               avmm_port_read,
               avmm_port_write,
               avmm_port_waitrequest,
               avmm_port_readdatavalid,
               avmm_port_readdata);
      $display("AVMM_DEBUG reset monitor=%b datapath=%b top_m0=%b avmm_rst=%b",
               dut.monitor_reset_sync_reset_out_reset,
               dut.rst_controller_reset_out_reset,
               dut.rst_controller_reset_out_reset,
               avmm_rst_reset);
      $display("AVMM_DEBUG xbridge m0 addr=0x%0h rd=%b wr=%b wait=%b rdv=%b rdata=0x%08h",
               dut.mm_clock_crossing_bridge_m0_address,
               dut.mm_clock_crossing_bridge_m0_read,
               dut.mm_clock_crossing_bridge_m0_write,
               dut.mm_clock_crossing_bridge_m0_waitrequest,
               dut.mm_clock_crossing_bridge_m0_readdatavalid,
               dut.mm_clock_crossing_bridge_m0_readdata);
      $display("AVMM_DEBUG xbridge internals s0_reset=%b m0_reset=%b cmd_valid=%b cmd_ready=%b internal_read=%b stop=%b stop_r=%b space=%0d pending=%0d rsp_ready=%b rsp_space=%0d",
               dut.mm_clock_crossing_bridge.s0_reset,
               dut.mm_clock_crossing_bridge.m0_reset,
               dut.mm_clock_crossing_bridge.m0_cmd_valid,
               dut.mm_clock_crossing_bridge.m0_cmd_ready,
               dut.mm_clock_crossing_bridge.m0_internal_read,
               dut.mm_clock_crossing_bridge.stop_cmd,
               dut.mm_clock_crossing_bridge.stop_cmd_r,
               dut.mm_clock_crossing_bridge.space_avail,
               dut.mm_clock_crossing_bridge.pending_read_count,
               dut.mm_clock_crossing_bridge.m0_rsp_ready,
               dut.mm_clock_crossing_bridge.rsp_fifo.in_space_avail);
      $display("AVMM_DEBUG rsp_valids mux=%b sinks=%b low=%b emu=%b hist=%b hitring=%b mts1=%b m3=%b m4=%b m5=%b m6=%b m7=%b",
               dut.mm_interconnect_2.rsp_mux_src_valid,
               dut.mm_interconnect_2.rsp_mux.valid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_low_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_emu_dbg_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_hist_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_hitstack_ring_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_mts1_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_mutrig3_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_mutrig4_mts0_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_mutrig5_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_mutrig6_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_mutrig7_s0_readdatavalid);
      $display("AVMM_DEBUG emu_pipe_s0 addr=0x%0h rd=%b wr=%b wait=%b rdv=%b rdata=0x%08h",
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_emu_dbg_s0_address,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_emu_dbg_s0_read,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_emu_dbg_s0_write,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_emu_dbg_s0_waitrequest,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_emu_dbg_s0_readdatavalid,
               dut.mm_interconnect_2_mm_pipeline_lvds_csr_emu_dbg_s0_readdata);
      $display("AVMM_DEBUG emu_pipe_m0 addr=0x%0h rd=%b wr=%b wait=%b rdv=%b rdata=0x%08h",
               dut.mm_pipeline_lvds_csr_emu_dbg_m0_address,
               dut.mm_pipeline_lvds_csr_emu_dbg_m0_read,
               dut.mm_pipeline_lvds_csr_emu_dbg_m0_write,
               dut.mm_pipeline_lvds_csr_emu_dbg_m0_waitrequest,
               dut.mm_pipeline_lvds_csr_emu_dbg_m0_readdatavalid,
               dut.mm_pipeline_lvds_csr_emu_dbg_m0_readdata);
      $display("AVMM_DEBUG emu_csr addr=0x%0h rd=%b wr=%b wait=%b rdata=0x%08h",
               dut.mm_interconnect_0_emulator_mutrig_qsys_inst_csr_address,
               dut.mm_interconnect_0_emulator_mutrig_qsys_inst_csr_read,
               dut.mm_interconnect_0_emulator_mutrig_qsys_inst_csr_write,
               dut.mm_interconnect_0_emulator_mutrig_qsys_inst_csr_waitrequest,
               dut.mm_interconnect_0_emulator_mutrig_qsys_inst_csr_readdata);
    end
  endtask

  task automatic avmm_read(input int unsigned addr, output logic [31:0] data);
    int unsigned guard;
    begin
      avmm_tick();
      avmm_port_address <= addr[13:0];
      avmm_port_byteenable <= 4'hf;
      avmm_port_burstcount <= 9'd1;
      avmm_port_read <= 1'b1;
      avmm_port_write <= 1'b0;
      guard = 0;
      do begin
        avmm_tick();
        guard++;
        if (guard > AVMM_TIMEOUT) begin
          dump_avmm_debug("read_accept_timeout", addr);
          $fatal(1, "AVMM read accept timeout addr=0x%0h", addr);
        end
      end while (avmm_port_waitrequest !== 1'b0);
      avmm_port_read <= 1'b0;
      guard = 0;
      while (avmm_port_readdatavalid !== 1'b1) begin
        avmm_tick();
        guard++;
        if (guard > AVMM_TIMEOUT) begin
          dump_avmm_debug("read_data_timeout", addr);
          $fatal(1, "AVMM read data timeout addr=0x%0h", addr);
        end
      end
      data = avmm_port_readdata;
      avmm_port_address <= 14'd0;
      avmm_tick();
    end
  endtask

  task automatic runctl_send(input logic [8:0] state_word);
    int unsigned guard;
    begin
      @(posedge lvds_outclock_clk);
      runctl_mgmt_host_data <= state_word;
      runctl_mgmt_host_valid <= 1'b1;
      guard = 0;
      while (runctl_mgmt_host_ready !== 1'b1) begin
        @(posedge lvds_outclock_clk);
        guard++;
        if (guard > RC_TIMEOUT) begin
          $fatal(1, "run-control host timeout state=0x%0h", state_word);
        end
      end
      @(posedge lvds_outclock_clk);
      runctl_mgmt_host_valid <= 1'b0;
      runctl_mgmt_host_data <= 9'd0;
      repeat (8) @(posedge lvds_outclock_clk);
    end
  endtask

  task automatic wait_for_data_clock;
    int unsigned guard;
    logic old_clk;
    begin
      old_clk = lvds_outclock_clk;
      guard = 0;
      while (lvds_outclock_clk === old_clk) begin
        #1;
        guard++;
        if (guard > 20_000) begin
          $fatal(1, "lvds_outclock_clk did not toggle");
        end
      end
      repeat (16) @(posedge lvds_outclock_clk);
    end
  endtask

  task automatic pulse_monitor_reset_after_data_clock;
    begin
      monitor_reset_in_reset_reset_n <= 1'b0;
      xcvr_reset_reset_n <= 1'b0;
      repeat (16) @(posedge monitor_clock_125_in_clk);
      repeat (16) @(posedge lvds_outclock_clk);
      monitor_reset_in_reset_reset_n <= 1'b1;
      xcvr_reset_reset_n <= 1'b1;
      repeat (256) @(posedge monitor_clock_125_in_clk);
      repeat (256) @(posedge lvds_outclock_clk);
    end
  endtask

  task automatic configure_dut;
    int lane;
    logic [31:0] rd;
    logic [31:0] hist_control;
    logic [31:0] cluster_one_ch;
    begin
      for (lane = 0; lane < 8; lane++) begin
        avmm_write(AVMM_ARB_BASE + lane * AVMM_ARB_STRIDE + 2, 32'h0000_0001);
      end

      cluster_one_ch = (32'd1 << 14) | 32'd0;
      avmm_write(AVMM_EMU_BASE + 7, 32'h0000_0001);
      avmm_write(AVMM_EMU_BASE + 8, 32'h0000_0001);
      avmm_write(AVMM_EMU_BASE + 9, 32'h0000_0000);
      avmm_write(AVMM_EMU_BASE + 10, 32'h0000_0023);
      avmm_write(AVMM_EMU_BASE + 11, 32'h0000_0001);
      avmm_write(AVMM_EMU_BASE + 12, cluster_one_ch);
      avmm_write(AVMM_EMU_BASE + 'h12, 32'h0000_00ff);
      avmm_read(AVMM_EMU_BASE + 10, rd);
      if (rd[5] !== 1'b1) begin
        $fatal(1, "emulator Type0 stream is not enabled after CSR programming: 0x%08h", rd);
      end

      avmm_write(AVMM_INJ_BASE + 5, 32'h0000_0001);
      avmm_write(AVMM_INJ_BASE + 7, trigger_interval_cycles);
      avmm_write(AVMM_INJ_BASE + 8, 32'h0000_0005);
      avmm_write(AVMM_INJ_BASE + 2, 32'h0000_0002);

      hist_control = 32'h0000_0001 | (32'd1 << 4) | (32'd1 << 8) | (source_select << 16);
      avmm_write(AVMM_HIST_CSR_BASE + CSR_CONTROL, 32'h0000_0000);
      avmm_write(AVMM_HIST_CSR_BASE + CSR_LEFT_BOUND, 32'h0000_0000);
      avmm_write(AVMM_HIST_CSR_BASE + CSR_RIGHT_BOUND, 32'd8192);
      avmm_write(AVMM_HIST_CSR_BASE + CSR_BIN_WIDTH, DELAY_BIN_WIDTH);
      avmm_write(AVMM_HIST_CSR_BASE + CSR_KEY_FILTER, source_default_filter_key(source_select));
      avmm_write(AVMM_HIST_CSR_BASE + CSR_KEY_FILTER_V, 32'h0000_0001);
      avmm_write(AVMM_HIST_CSR_BASE + CSR_INTERVAL, interval_cycles);
      avmm_write(AVMM_HIST_CSR_BASE + CSR_CONTROL, hist_control);
      avmm_read(AVMM_HIST_CSR_BASE + CSR_CONTROL, rd);
      if (rd[17:16] != source_select[1:0]) begin
        $fatal(1, "histogram source-select readback mismatch: got 0x%08h source=%0d", rd, source_select);
      end
    end
  endtask

  task automatic read_interval_snapshot(input int unsigned interval_idx);
    logic [31:0] rd;
    logic [31:0] burst_bins[N_BINS];
    longint unsigned interval_total;
    longint unsigned interval_dropped;
    longint unsigned interval_bin_sum;
    int bin;
    begin
      repeat (64) @(posedge lvds_outclock_clk);
      avmm_read(AVMM_HIST_CSR_BASE + CSR_LAST_TOTAL, rd);
      interval_total = rd;
      avmm_read(AVMM_HIST_CSR_BASE + CSR_LAST_DROPPED, rd);
      interval_dropped = rd;
      interval_bin_sum = 0;

      avmm_tick();
      avmm_port_address <= AVMM_HIST_BIN_BASE[13:0];
      avmm_port_byteenable <= 4'hf;
      avmm_port_burstcount <= N_BINS[8:0];
      avmm_port_read <= 1'b1;
      avmm_port_write <= 1'b0;
      for (bin = 0; avmm_port_waitrequest !== 1'b0; bin++) begin
        avmm_tick();
        if (bin > AVMM_TIMEOUT) begin
          dump_avmm_debug("hist_burst_accept_timeout", AVMM_HIST_BIN_BASE);
          $fatal(1, "AVMM histogram burst accept timeout");
        end
      end
      avmm_tick();
      avmm_port_read <= 1'b0;
      avmm_port_address <= 14'd0;
      avmm_port_burstcount <= 9'd1;
      for (bin = 0; bin < N_BINS; bin++) begin
        int guard;
        guard = 0;
        while (avmm_port_readdatavalid !== 1'b1) begin
          avmm_tick();
          guard++;
          if (guard > AVMM_TIMEOUT) begin
            dump_avmm_debug("hist_burst_data_timeout", AVMM_HIST_BIN_BASE + bin);
            $fatal(1, "AVMM histogram burst data timeout bin=%0d", bin);
          end
        end
        rd = avmm_port_readdata;
        burst_bins[bin] = rd;
        csr_bins[bin] += rd;
        interval_bin_sum += rd;
        if (rd != 0) begin
          $fdisplay(delay_fd, "%s,%0d,%s,delay,%0d,%s,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0d",
                    case_name,
                    interval_idx,
                    source_name,
                    rate_hz,
                    pattern_name,
                    delay_model,
                    delay_target_cycles,
                    active_asics,
                    bin,
                    bin * DELAY_BIN_WIDTH,
                    rd,
                    interval_total,
                    (interval_total == 0) ? 0.0 : (100.0 * real'(rd) / real'(interval_total)),
                    (((bin * DELAY_BIN_WIDTH) >= RBCAM_LOW_CYCLES) &&
                     ((bin * DELAY_BIN_WIDTH) <= RBCAM_HIGH_CYCLES)));
        end
        avmm_tick();
      end
      last_total_sum += interval_total;
      last_dropped_sum += interval_dropped;
      bin_sum += interval_bin_sum;
      interval_seen++;
      $display("QSYS_INTERVAL case=%s idx=%0d last_total=%0d dropped=%0d bin_sum=%0d",
               case_name, interval_idx, interval_total, interval_dropped, interval_bin_sum);
    end
  endtask

  task automatic wait_histogram_interval_pulse;
    begin
      while (interval_pulse_count == interval_pulse_consumed) begin
        @(posedge lvds_outclock_clk);
      end
      interval_pulse_consumed++;
      @(posedge lvds_outclock_clk);
    end
  endtask

  task automatic read_final_counters;
    logic [31:0] rd;
    begin
      avmm_read(AVMM_HIST_CSR_BASE + CSR_TOTAL_HITS, rd);
      csr_total = rd;
      avmm_read(AVMM_HIST_CSR_BASE + CSR_DROPPED_HITS, rd);
      csr_dropped = rd;
    end
  endtask

  task automatic summarize_bins;
    int bin;
    begin
      csr_first_bin = N_BINS;
      csr_last_bin = 0;
      meta_first_bin = N_BINS;
      meta_last_bin = 0;
      csr_nonzero_bins = 0;
      meta_nonzero_bins = 0;
      for (bin = 0; bin < N_BINS; bin++) begin
        if (csr_bins[bin] != 0) begin
          csr_nonzero_bins++;
          if (csr_first_bin == N_BINS) csr_first_bin = bin;
          csr_last_bin = bin;
        end
        if (meta_bins[bin] != 0) begin
          meta_nonzero_bins++;
          if (meta_first_bin == N_BINS) meta_first_bin = bin;
          meta_last_bin = bin;
        end
      end
      if (csr_first_bin == N_BINS) csr_first_bin = 0;
      if (meta_first_bin == N_BINS) meta_first_bin = 0;
    end
  endtask

  task automatic check_results;
    int asic;
    int bin;
    longint unsigned bank_seen;
    begin
      summarize_bins();
      expected_hits = pulse_count * active_asics;
      bank_seen = 0;
      for (asic = 0; asic < 8; asic++) begin
        if (is_in_expected_bank(asic) && asic_seen[asic] != 0) begin
          bank_seen++;
        end
        if (!is_in_expected_bank(asic) && asic_seen[asic] != 0) begin
          note_fail($sformatf("unexpected Type1 ASIC %0d in %s bank", asic, source_name));
        end
      end

      if (pulse_count == 0) note_fail("no injector pulses during RUNNING");
      if (meta_total == 0) note_fail("no Type1 metadata accepted at histogram ingress");
      if (bank_seen != active_asics) note_fail($sformatf("expected %0d ASICs in bank, saw %0d", active_asics, bank_seen));
      if (meta_total != expected_hits) note_fail($sformatf("meta_total=%0d expected=%0d pulses=%0d", meta_total, expected_hits, pulse_count));
      if (bin_sum != expected_hits) note_fail($sformatf("CSR bin_sum=%0d expected=%0d", bin_sum, expected_hits));
      if (last_total_sum != bin_sum) note_fail($sformatf("LAST_TOTAL sum=%0d bin_sum=%0d", last_total_sum, bin_sum));
      if (last_dropped_sum != 0) note_fail($sformatf("LAST_DROPPED sum=%0d", last_dropped_sum));
      if (csr_dropped != 0) note_fail($sformatf("CSR dropped=%0d", csr_dropped));
      if ((csr_last_bin * DELAY_BIN_WIDTH) > RBCAM_HIGH_CYCLES) begin
        note_fail($sformatf("CSR delay max %0d cycles exceeds %0d", csr_last_bin * DELAY_BIN_WIDTH, RBCAM_HIGH_CYCLES));
      end
      if ((meta_last_bin * DELAY_BIN_WIDTH) > RBCAM_HIGH_CYCLES) begin
        note_fail($sformatf("meta delay max %0d cycles exceeds %0d", meta_last_bin * DELAY_BIN_WIDTH, RBCAM_HIGH_CYCLES));
      end
      for (bin = 0; bin < N_BINS; bin++) begin
        if (meta_bins[bin] != csr_bins[bin]) begin
          note_fail($sformatf("CSR/meta bin mismatch bin=%0d csr=%0d meta=%0d", bin, csr_bins[bin], meta_bins[bin]));
        end
      end
      if (case_mode == "header_sync") begin
        if (csr_nonzero_bins != 1) note_fail($sformatf("header-sync mimic CSR bins not delta: %0d bins", csr_nonzero_bins));
        if (meta_nonzero_bins != 1) note_fail($sformatf("header-sync mimic meta bins not delta: %0d bins", meta_nonzero_bins));
      end
      if (case_mode != "header_sync") begin
        pulse_expected = run_cycles / trigger_interval_cycles;
        if (pulse_count != pulse_expected) begin
          note_fail($sformatf("periodic pulse_count=%0d expected=%0d interval=%0d",
                              pulse_count, pulse_expected, trigger_interval_cycles));
        end
      end
    end
  endtask

  always @(posedge lvds_outclock_clk or posedge counter_sclr_reset) begin
    if (counter_sclr_reset) begin
      data_cycle <= 0;
      inject_pulse_q <= 1'b0;
      interval_pulse_count <= 0;
    end else begin
      data_cycle <= data_cycle + 1;
      inject_pulse_q <= inject_pulse;
      if (dut.histogram_statistics_0.interval_pulse === 1'b1) begin
        interval_pulse_count <= interval_pulse_count + 1;
      end
      if ((data_cycle >= run_start_cycle) && (data_cycle < run_end_cycle) &&
          (inject_pulse === 1'b1) && (inject_pulse_q === 1'b0)) begin
        pulse_count <= pulse_count + 1;
      end
    end
  end

  always @(posedge lvds_outclock_clk) begin
    if (debug_tail &&
        (run_end_cycle != 64'hffff_ffff_ffff_ffff) &&
        (data_cycle + 512 >= run_end_cycle) &&
        (data_cycle < run_end_cycle + 2048)) begin
      if ((inject_pulse === 1'b1) ||
          (dut.hist_type1_up_tap_out1_valid === 1'b1) ||
          (dut.hist_type1_down_tap_out1_valid === 1'b1) ||
          (dut.histogram_statistics_0.interval_pulse === 1'b1) ||
          (dut.histogram_statistics_0.force_interval_pulse === 1'b1) ||
          (dut.histogram_statistics_0.hist_pipeline_busy === 1'b1) ||
          (dut.histogram_statistics_0.hist_update_busy === 1'b1) ||
          (dut.histogram_statistics_0.queue_drain_valid === 1'b1)) begin
        $display("QSYS_TYPE1_TAIL cycle=%0d run_end=%0d inj=%0b up_vr=%0b%0b dn_vr=%0b%0b int=%0b force=%0b pipe=%0b upd=%0b qdv=%0b qdr=%0b total=%0d last=%0d",
                 data_cycle,
                 run_end_cycle,
                 inject_pulse,
                 dut.hist_type1_up_tap_out1_valid,
                 dut.hist_type1_up_tap_out1_ready,
                 dut.hist_type1_down_tap_out1_valid,
                 dut.hist_type1_down_tap_out1_ready,
                 dut.histogram_statistics_0.interval_pulse,
                 dut.histogram_statistics_0.force_interval_pulse,
                 dut.histogram_statistics_0.hist_pipeline_busy,
                 dut.histogram_statistics_0.hist_update_busy,
                 dut.histogram_statistics_0.queue_drain_valid,
                 dut.histogram_statistics_0.queue_drain_ready,
                 dut.histogram_statistics_0.csr_total_hits,
                 dut.histogram_statistics_0.csr_last_interval_total_hits);
      end
    end
  end

  task automatic record_meta(input logic [38:0] data_word,
                             input logic [47:0] hit_ts,
                             input logic [47:0] gts_sample,
                             input string source);
    int unsigned asic;
    int unsigned channel;
    longint unsigned latency;
    longint unsigned hit_ts_v;
    longint unsigned gts_v;
    int unsigned bin;
    begin
      asic = data_word[38:35];
      channel = data_word[34:30];
      hit_ts_v = hit_ts;
      gts_v = gts_sample;
      if (gts_v >= hit_ts_v) begin
        latency = gts_v - hit_ts_v;
      end else begin
        latency = 0;
      end
      bin = latency / DELAY_BIN_WIDTH;
      if (bin >= N_BINS) begin
        bin = N_BINS - 1;
      end
      meta_bins[bin]++;
      meta_total++;
      if (asic < 8) begin
        asic_seen[asic]++;
      end
      $fdisplay(meta_fd, "%s,%s,%0d,%s,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0h,%0d,%0d",
                case_name,
                source,
                rate_hz,
                pattern_name,
                delay_model,
                data_cycle,
                asic,
                channel,
                meta_total,
                meta_total,
                latency,
                bin,
                hit_ts,
                data_word,
                gts_sample,
                1);
    end
  endtask

  always @(negedge lvds_outclock_clk) begin
    if (!counter_sclr_reset) begin
      if ((source_select == SRC_TYPE1_UP) &&
          (dut.hist_type1_up_tap_out1_valid === 1'b1) &&
          (dut.hist_type1_up_tap_out1_ready === 1'b1)) begin
        record_meta(dut.hist_type1_up_tap_out1_data,
                    dut.mts_preprocessor_0_hit_type1_ts_export,
                    dut.histogram_statistics_0.gts_8n,
                    "type1_up");
      end
      if ((source_select == SRC_TYPE1_DOWN) &&
          (dut.hist_type1_down_tap_out1_valid === 1'b1) &&
          (dut.hist_type1_down_tap_out1_ready === 1'b1)) begin
        record_meta(dut.hist_type1_down_tap_out1_data,
                    dut.mts_preprocessor_1_hit_type1_ts_export,
                    dut.histogram_statistics_0.gts_8n,
                    "type1_down");
      end
    end
  end

  initial begin : main
    int i;

    report_prefix = "qsys_type1_delay";
    source_name = "type1_up";
    case_mode = "periodic";
    rate_hz = 100_000;
    run_cycles = RUN_10MS_CYCLES;
    interval_cycles = PINGPONG_1MS_CYCLES;
    fail_count = 0;
    active_asics = 4;
    debug_tail = 0;

    void'($value$plusargs("REPORT_PREFIX=%s", report_prefix));
    void'($value$plusargs("SOURCE=%s", source_name));
    void'($value$plusargs("CASE_MODE=%s", case_mode));
    void'($value$plusargs("RATE_HZ=%d", rate_hz));
    void'($value$plusargs("RUN_CYCLES=%d", run_cycles));
    void'($value$plusargs("INTERVAL_CYCLES=%d", interval_cycles));
    debug_tail = $test$plusargs("DEBUG_TAIL");

    source_select = (source_name == "type1_down") ? SRC_TYPE1_DOWN : SRC_TYPE1_UP;
    if (case_mode == "header_sync") begin
      trigger_interval_cycles = 910;
      delay_target_cycles = 910;
      pattern_name = "qsys_header_sync_910_one_ch_per_asic";
      delay_model = "qsys_internal_trigger_910cyc_header_sync_mimic";
      case_name = $sformatf("%s_latency_hsync910_qsys", source_name);
      rate_hz = CLK_HZ / trigger_interval_cycles;
    end else begin
      trigger_interval_cycles = CLK_HZ / rate_hz;
      delay_target_cycles = 0;
      pattern_name = "qsys_periodic_one_ch_per_asic";
      delay_model = "qsys_periodic_mode2";
      case_name = $sformatf("%s_latency_%s_qsys_periodic", source_name, rate_label(rate_hz));
    end

    summary_fd = $fopen({report_prefix, "_summary.csv"}, "w");
    delay_fd = $fopen({report_prefix, "_delay_bins.csv"}, "w");
    meta_fd = $fopen({report_prefix, "_type1_meta.csv"}, "w");
    if ((summary_fd == 0) || (delay_fd == 0) || (meta_fd == 0)) begin
      $fatal(1, "could not open report CSV prefix %s", report_prefix);
    end
    $fdisplay(summary_fd, "case,source,mode,rate_hz,pattern,run_cycles,interval_cycles,expected,offered,accepted,ready_miss,intervals,total,dropped,bin_sum,coal_overflow_max,delay_min_bin,delay_max_bin,active_asics,per_asic_rate_hz,result,delay_model,delay_target_cycles,rbcam_window_low_cycles,rbcam_window_high_cycles");
    $fdisplay(delay_fd, "case,interval_idx,source,mode,rate_hz,pattern,delay_model,delay_target_cycles,active_asics,bin_idx,bin_center_cycles,count,interval_total,percent,in_rbcam_window");
    $fdisplay(meta_fd, "case,source,rate_hz,pattern,delay_mode,cycle,asic,channel,hit_index,hit_seq,latency_cycles,bin,hit_ts,data_word,gts_sample,ready");

    for (i = 0; i < N_BINS; i++) begin
      csr_bins[i] = 0;
      meta_bins[i] = 0;
    end
    for (i = 0; i < 8; i++) begin
      asic_seen[i] = 0;
    end
    pulse_count = 0;
    interval_pulse_count = 0;
    interval_pulse_consumed = 0;
    meta_total = 0;
    last_total_sum = 0;
    last_dropped_sum = 0;
    bin_sum = 0;
    csr_total = 0;
    csr_dropped = 0;
    interval_seen = 0;
    run_start_cycle = 64'hffff_ffff_ffff_ffff;
    run_end_cycle = 64'hffff_ffff_ffff_ffff;

	    repeat (80) @(posedge avmm_clk_clk);
	    monitor_reset_in_reset_reset_n = 1'b1;
	    xcvr_reset_reset_n = 1'b1;
	    counter_sclr_reset = 1'b0;
	    wait_for_data_clock();
	    pulse_monitor_reset_after_data_clock();
	    repeat (128) @(posedge lvds_outclock_clk);
	    repeat (128) @(posedge avmm_clk_clk);
	    avmm_rst_reset = 1'b0;
	    repeat (128) @(posedge avmm_clk_clk);

	    configure_dut();

    runctl_send(RC_IDLE);
    runctl_send(RC_RUN_PREPARE);
    runctl_send(RC_SYNC);
    repeat (128) @(posedge lvds_outclock_clk);
    run_start_cycle = data_cycle + 16;
    run_end_cycle = run_start_cycle + run_cycles;
    runctl_send(RC_RUNNING);

    fork
      begin : run_timer
        while (data_cycle < run_end_cycle) begin
          @(posedge lvds_outclock_clk);
        end
        runctl_send(RC_TERMINATING);
        repeat (4096) @(posedge lvds_outclock_clk);
        runctl_send(RC_IDLE);
      end
      begin : interval_reader
        for (int interval_idx = 0; interval_idx < ((run_cycles / interval_cycles) + 1); interval_idx++) begin
          wait_histogram_interval_pulse();
          read_interval_snapshot(interval_idx);
        end
      end
    join

    read_final_counters();
    check_results();
    $fdisplay(summary_fd, "%s,%s,delay,%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%s,%s,%0d,%0d,%0d",
              case_name,
              source_name,
              rate_hz,
              pattern_name,
              run_cycles,
              interval_cycles,
              expected_hits,
              pulse_count * active_asics,
              meta_total,
              0,
              interval_seen,
              last_total_sum,
              last_dropped_sum,
              bin_sum,
              0,
              csr_first_bin,
              csr_last_bin,
              active_asics,
              rate_hz,
              (fail_count == 0) ? "PASS" : "FAIL",
              delay_model,
              delay_target_cycles,
              RBCAM_LOW_CYCLES,
              RBCAM_HIGH_CYCLES);
    $fclose(summary_fd);
    $fclose(delay_fd);
    $fclose(meta_fd);

    $display("QSYS_TYPE1_DELAY_RESULT case=%s source=%s pulses=%0d expected_hits=%0d meta=%0d bin_sum=%0d last_total_sum=%0d dropped=%0d csr_total=%0d fail_count=%0d",
             case_name, source_name, pulse_count, expected_hits, meta_total, bin_sum, last_total_sum,
             last_dropped_sum + csr_dropped, csr_total, fail_count);
    if (fail_count != 0) begin
      $fatal(1, "Qsys Type1 delay/rate gate failed");
    end
    $display("*** TEST PASSED ***");
    $finish;
  end
endmodule
