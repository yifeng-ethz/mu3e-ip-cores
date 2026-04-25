module phase4_latency_tlm;
  localparam int N_LANE = 8;
  localparam int RATE_POINTS = 8;
  localparam int LATENCY_BINS = 4096;
  localparam int FRAME_INTERVAL_CYCLES = 1550;
  localparam int RUN_CYCLES = 200000;
  localparam int CLK_HZ = 156250000;
  localparam int HIST_ACCEPT_NUM = 7;
  localparam int HIST_ACCEPT_DEN = 8;
  localparam int HIST_BACKLOG_LIMIT = 1 << 28;

  string artifact_dir;
  int unsigned latency_hist [0:LATENCY_BINS-1];
  int unsigned rate_words [0:RATE_POINTS-1];

  function automatic int unsigned xorshift32(input int unsigned state);
    int unsigned x;
    begin
      x = (state == 0) ? 32'h1ACE_B00C : state;
      x = x ^ (x << 13);
      x = x ^ (x >> 17);
      x = x ^ (x << 5);
      return x;
    end
  endfunction

  function automatic int scaled_threshold(input int rate_word);
    int threshold;
    begin
      threshold = rate_word * 5;
      if (threshold > 65535) begin
        threshold = 65535;
      end
      return threshold;
    end
  endfunction

  function automatic int dispatch_latency_cycles(input int cycle, input int lane, input int unsigned rnd);
    int phase;
    int wait_to_frame;
    int pipe_delay;
    begin
      phase = cycle % FRAME_INTERVAL_CYCLES;
      wait_to_frame = (phase == 0) ? 0 : (FRAME_INTERVAL_CYCLES - phase);
      pipe_delay = 8 + (lane % 4) + (rnd & 7);
      return wait_to_frame + pipe_delay;
    end
  endfunction

  task automatic clear_latency_hist;
    int i;
    begin
      for (i = 0; i < LATENCY_BINS; i++) begin
        latency_hist[i] = 0;
      end
    end
  endtask

  task automatic run_latency_case(input int rate_word, output int unsigned total_hits);
    int cycle;
    int lane;
    int threshold;
    int lat;
    int unsigned rng [0:N_LANE-1];
    begin
      total_hits = 0;
      threshold = scaled_threshold(rate_word);
      for (lane = 0; lane < N_LANE; lane++) begin
        rng[lane] = 32'h1234_0001 ^ (lane * 32'h0010_0101);
      end
      clear_latency_hist();
      for (cycle = 0; cycle < RUN_CYCLES; cycle++) begin
        for (lane = 0; lane < N_LANE; lane++) begin
          rng[lane] = xorshift32(rng[lane]);
          if ((rng[lane] & 16'hffff) < threshold) begin
            lat = dispatch_latency_cycles(cycle, lane, rng[lane] >> 16);
            if (lat < 0) begin
              lat = 0;
            end
            if (lat >= LATENCY_BINS) begin
              lat = LATENCY_BINS - 1;
            end
            latency_hist[lat]++;
            total_hits++;
          end
        end
      end
    end
  endtask

  task automatic run_rate_case(
      input int rate_word,
      output int unsigned generated,
      output int unsigned accepted,
      output int unsigned dropped,
      output int unsigned backlog_end
  );
    int cycle;
    int lane;
    int threshold;
    int unsigned rng [0:N_LANE-1];
    int generated_this_cycle;
    int accept_accum;
    int accept_slots;
    int unsigned backlog;
    begin
      generated = 0;
      accepted = 0;
      dropped = 0;
      backlog = 0;
      accept_accum = 0;
      threshold = scaled_threshold(rate_word);
      for (lane = 0; lane < N_LANE; lane++) begin
        rng[lane] = 32'hC0DE_1001 ^ (lane * 32'h0101_0101) ^ rate_word;
      end
      for (cycle = 0; cycle < RUN_CYCLES; cycle++) begin
        generated_this_cycle = 0;
        for (lane = 0; lane < N_LANE; lane++) begin
          rng[lane] = xorshift32(rng[lane]);
          if ((rng[lane] & 16'hffff) < threshold) begin
            generated_this_cycle++;
          end
        end

        generated += generated_this_cycle;
        if (backlog + generated_this_cycle > HIST_BACKLOG_LIMIT) begin
          dropped += (backlog + generated_this_cycle - HIST_BACKLOG_LIMIT);
          backlog = HIST_BACKLOG_LIMIT;
        end else begin
          backlog += generated_this_cycle;
        end

        accept_accum += HIST_ACCEPT_NUM;
        accept_slots = accept_accum / HIST_ACCEPT_DEN;
        accept_accum = accept_accum % HIST_ACCEPT_DEN;
        if (accept_slots > backlog) begin
          accept_slots = backlog;
        end
        backlog -= accept_slots;
        accepted += accept_slots;
      end
      backlog_end = backlog;
    end
  endtask

  task automatic write_latency_csv(input string path);
    int fd;
    int i;
    begin
      fd = $fopen(path, "w");
      if (fd == 0) begin
        $fatal(1, "could not open latency CSV: %s", path);
      end
      $fdisplay(fd, "latency_cycles,count");
      for (i = 0; i < LATENCY_BINS; i++) begin
        $fdisplay(fd, "%0d,%0d", i, latency_hist[i]);
      end
      $fclose(fd);
    end
  endtask

  task automatic write_rate_csv(input string path);
    int fd;
    int idx;
    int unsigned generated;
    int unsigned accepted;
    int unsigned dropped;
    int unsigned backlog_end;
    real duration_s;
    real accepted_per_s;
    begin
      duration_s = real'(RUN_CYCLES) / real'(CLK_HZ);
      fd = $fopen(path, "w");
      if (fd == 0) begin
        $fatal(1, "could not open rate CSV: %s", path);
      end
      $fdisplay(fd, "rate_word,generated,accepted,dropped,backlog_end,duration_s,accepted_per_s");
      for (idx = 0; idx < RATE_POINTS; idx++) begin
        run_rate_case(rate_words[idx], generated, accepted, dropped, backlog_end);
        accepted_per_s = real'(accepted) / duration_s;
        $fdisplay(fd, "0x%04x,%0d,%0d,%0d,%0d,%.9f,%.3f",
                  rate_words[idx], generated, accepted, dropped, backlog_end,
                  duration_s, accepted_per_s);
      end
      $fclose(fd);
    end
  endtask

  task automatic write_summary(input string path, input int unsigned latency_total);
    int fd;
    begin
      fd = $fopen(path, "w");
      if (fd == 0) begin
        $fatal(1, "could not open summary file: %s", path);
      end
      $fdisplay(fd, "phase4_latency_tlm");
      $fdisplay(fd, "n_lane=%0d", N_LANE);
      $fdisplay(fd, "run_cycles=%0d", RUN_CYCLES);
      $fdisplay(fd, "clk_hz=%0d", CLK_HZ);
      $fdisplay(fd, "frame_interval_cycles=%0d", FRAME_INTERVAL_CYCLES);
      $fdisplay(fd, "latency_case_rate_word=0x0800");
      $fdisplay(fd, "latency_total_hits=%0d", latency_total);
      $fdisplay(fd, "hist_accept_ratio=%0d/%0d", HIST_ACCEPT_NUM, HIST_ACCEPT_DEN);
      $fclose(fd);
    end
  endtask

  initial begin
    int unsigned latency_total;

    rate_words[0] = 16'h0100;
    rate_words[1] = 16'h0200;
    rate_words[2] = 16'h0400;
    rate_words[3] = 16'h0800;
    rate_words[4] = 16'h1000;
    rate_words[5] = 16'h2000;
    rate_words[6] = 16'h4000;
    rate_words[7] = 16'h8000;

    if (!$value$plusargs("ARTIFACT_DIR=%s", artifact_dir)) begin
      artifact_dir = ".";
    end

    run_latency_case(16'h0800, latency_total);
    write_latency_csv({artifact_dir, "/phase4_tlm_latency_hist.csv"});
    write_rate_csv({artifact_dir, "/phase4_tlm_rate_sweep.csv"});
    write_summary({artifact_dir, "/phase4_tlm_summary.txt"}, latency_total);
    $display("PHASE4_TLM_DONE artifact_dir=%s latency_total=%0d", artifact_dir, latency_total);
    $finish;
  end
endmodule
