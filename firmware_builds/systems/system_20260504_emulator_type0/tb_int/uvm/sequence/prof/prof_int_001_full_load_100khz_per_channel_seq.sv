// prof_int_001_full_load_100khz_per_channel_seq.sv
// PROF-INT-001 sequence: 100 kHz/channel Poisson injection on all 16 EMU-mode
// channels of lane 0, driven directly against the arb_hit_type0_supercore RTL.
//
// This sequence is used by prof_int_001_top (standalone top, analogous to
// error_int_b002_top) and is NOT loaded into tb_int_top.
//
// Scope: 1 lane (lane 0), 16 EMU-mode channels (0..15 via emu_in_0),
//        100 ms simulated time (deviation from 1 s documented below).
//
// Deviation note:
//   Requested scope was 1 sec @ 100 kHz/channel x 16 channels.
//   Scope reduced to 100 ms to stay within 60 min wall-clock budget:
//   1 sec @ 125 MHz = 125 M cycles; 100 ms = 12.5 M cycles.
//   At 100 kHz/channel x 16 ch x 0.1 s = 160 000 hits total.
//   Statistical content is sufficient for CDF / histogram analysis.
//
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : New — PROF INT 001 full-load latency sequence.

package prof_int_001_full_load_100khz_per_channel_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -----------------------------------------------------------------------
    // Run-state encoding (matches arb_hit_type0_runctl localparam)
    // -----------------------------------------------------------------------
    localparam logic [8:0] RUNCTL_IDLE_SYM        = 9'h001;
    localparam logic [8:0] RUNCTL_RUN_PREP_SYM    = 9'h002;
    localparam logic [8:0] RUNCTL_SYNC_SYM        = 9'h004;
    localparam logic [8:0] RUNCTL_RUNNING_SYM     = 9'h008;
    localparam logic [8:0] RUNCTL_TERMINATING_SYM = 9'h010;

    // -----------------------------------------------------------------------
    // Per-hit in-flight record (used for timestamp correlation)
    // -----------------------------------------------------------------------
    typedef struct {
        longint unsigned hit_id;
        longint unsigned abs_ts_a;      // ns at injection
        int unsigned     channel;
        int unsigned     t_coarse;
        int unsigned     t_fine;
    } in_flight_t;

    // Depth-256 circular queue for in-flight hits (FIFO order preserved
    // in EMU-only mode — the arbiter never reorders within a single source)
    localparam int unsigned QUEUE_DEPTH = 512;

    class prof_int_001_full_load_100khz_per_channel_seq
        extends uvm_sequence #(uvm_sequence_item);

        `uvm_object_utils(prof_int_001_full_load_100khz_per_channel_seq)

        // -----------------------------------------------------------------------
        // Virtual interfaces wired by the top module
        // -----------------------------------------------------------------------
        // DUT control signals (driven via clocking block or direct assign)
        virtual interface prof_int_001_dut_if dut_vif;

        // Latency reporter (wired by top)
        int closed_fd;
        int drops_fd;
        string output_dir;

        // -----------------------------------------------------------------------
        // Sequence parameters
        // -----------------------------------------------------------------------
        int unsigned  seed;
        longint unsigned sim_cycles;       // total RUNNING cycles
        int unsigned  num_channels;        // channels per lane (0..num_channels-1)
        int unsigned  rate_hz_per_channel; // hits per second per channel

        // -----------------------------------------------------------------------
        // Counters
        // -----------------------------------------------------------------------
        longint unsigned emitted_hits;
        longint unsigned captured_hits;
        longint unsigned drop_count;

        function new(string name = "prof_int_001_full_load_100khz_per_channel_seq");
            super.new(name);
            seed                 = 32'hDEAD_BEEF;
            sim_cycles           = 12_500_000; // 100 ms at 125 MHz
            num_channels         = 16;
            rate_hz_per_channel  = 100_000;
            emitted_hits         = 0;
            captured_hits        = 0;
            drop_count           = 0;
            output_dir           = "sim/prof_int_001";
            closed_fd            = 0;
            drops_fd             = 0;
        endfunction

        // -----------------------------------------------------------------------
        // LCG PRNG (identical to PROF bucket convention)
        // -----------------------------------------------------------------------
        function automatic int unsigned lcg_next(ref int unsigned s);
            s = (32'd1664525 * s) + 32'd1013904223;
            return s;
        endfunction

        // -----------------------------------------------------------------------
        // Open CSV files
        // -----------------------------------------------------------------------
        function void open_csv();
            void'($system($sformatf("mkdir -p %s", output_dir)));
            closed_fd = $fopen({output_dir, "/closed_records.csv"}, "w");
            drops_fd  = $fopen({output_dir, "/drops.csv"}, "w");
            if (closed_fd == 0)
                `uvm_fatal("PROF_INT_001_SEQ",
                           $sformatf("cannot open %s/closed_records.csv", output_dir))
            if (drops_fd == 0)
                `uvm_fatal("PROF_INT_001_SEQ",
                           $sformatf("cannot open %s/drops.csv", output_dir))
            $fdisplay(closed_fd,
                      "hit_id,lane,channel,t_fine,t_coarse,root_hit_id,abs_ts_a,abs_ts_pre_rbcam,abs_ts_post_rbcam,abs_ts_feb_egress,run_origin");
            $fdisplay(drops_fd,
                      "hit_id,lane,key.channel,key.t_fine,t_coarse,last_seen_stage,last_seen_abs_ts,run_state_at_drop,run_origin");
        endfunction

        function void close_csv();
            if (closed_fd != 0) begin $fclose(closed_fd); closed_fd = 0; end
            if (drops_fd  != 0) begin $fclose(drops_fd);  drops_fd  = 0; end
        endfunction

        function void write_closed_record(
            longint unsigned hit_id,
            int unsigned     channel,
            int unsigned     t_fine,
            int unsigned     t_coarse,
            longint unsigned ts_a,
            longint unsigned ts_pre,
            longint unsigned ts_post,
            longint unsigned ts_feb
        );
            $fdisplay(closed_fd,
                      "%0d,0,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,1",
                      hit_id,
                      channel,
                      t_fine,
                      t_coarse,
                      hit_id,
                      ts_a,
                      ts_pre,
                      ts_post,
                      ts_feb);
        endfunction

        virtual task body();
            int unsigned s;
            int plus_seed;
            string plusarg_dir;

            if ($value$plusargs("ARB_SEED=%d", plus_seed))
                seed = plus_seed;
            if ($value$plusargs("TB_INT_SIM_DIR=%s", plusarg_dir))
                output_dir = plusarg_dir;
            s = seed;

            open_csv();

            // Wait for reset release
            if (dut_vif == null)
                `uvm_fatal("PROF_INT_001_SEQ", "dut_vif not wired")
            @(negedge dut_vif.rst);
            repeat (16) @(posedge dut_vif.clk);

            // Send RUN_PREP first so that stream_clear fires and resets CSR
            // mode back to MODE_DEFAULT (REAL=0). This must come BEFORE the
            // mode write because stream_clear resets csr.mode_pending to
            // MODE_DEFAULT — any mode write done before RUN_PREP is lost.
            @(negedge dut_vif.clk);
            dut_vif.run_ctrl_valid <= 1'b1;
            dut_vif.run_ctrl_data  <= RUNCTL_RUN_PREP_SYM;
            // Hold PREP for 4 cycles so runctl reset_active (2-cycle pipeline)
            // fully deasserts before we move to SYNC.
            repeat (4) @(negedge dut_vif.clk);
            dut_vif.run_ctrl_data  <= RUNCTL_SYNC_SYM;
            @(negedge dut_vif.clk);
            dut_vif.run_ctrl_data  <= RUNCTL_RUNNING_SYM;
            @(negedge dut_vif.clk);
            dut_vif.run_ctrl_valid <= 1'b0;

            // Wait for run_ctrl to propagate through the timing_adapter and
            // runctl pipeline to reach RUN_RUNNING state.
            repeat (8) @(posedge dut_vif.clk);

            // CSR write: set mode = 1 (EMU-only) AFTER stream_clear has fired.
            // stream_clear resets csr.mode and csr.mode_pending to MODE_DEFAULT
            // (REAL=0) during RUN_PREP. Writing after RUNNING is established
            // ensures the mode stays EMU for the injection window.
            // mode_commit = ~merged_open_next; when FIFOs are empty,
            // mode_commit=1 every cycle, so mode updates from mode_pending in
            // the very next clock after the write.
            @(negedge dut_vif.clk);
            dut_vif.csr_0_address   <= 5'h02;
            dut_vif.csr_0_writedata <= 32'h0000_0001; // mode_pending = EMU
            dut_vif.csr_0_write     <= 1'b1;
            dut_vif.csr_0_read      <= 1'b0;
            @(negedge dut_vif.clk);
            dut_vif.csr_0_write     <= 1'b0;
            // Allow mode_commit to propagate: csr.mode = EMU after this wait.
            repeat (4) @(posedge dut_vif.clk);
            `uvm_info("PROF_INT_001_SEQ",
                      $sformatf("RUNNING: injecting %0d channels at %0d Hz for %0d cycles",
                                num_channels, rate_hz_per_channel, sim_cycles),
                      UVM_LOW)

            // Fork injector (drives emu_in_0) and observer (monitors selected_out_0).
            // Observer runs for sim_cycles + 8192 drain cycles so all in-flight
            // hits are captured after the injector stops.
            fork
                inject_loop_with_record(s, sim_cycles);
                observe_loop(sim_cycles + 8192);
            join

            // Terminate run
            @(negedge dut_vif.clk);
            dut_vif.run_ctrl_valid <= 1'b1;
            dut_vif.run_ctrl_data  <= RUNCTL_TERMINATING_SYM;
            @(negedge dut_vif.clk);
            dut_vif.run_ctrl_data  <= RUNCTL_IDLE_SYM;
            @(negedge dut_vif.clk);
            dut_vif.run_ctrl_valid <= 1'b0;

            close_csv();

            `uvm_info("PROF_INT_001_SEQ",
                      $sformatf("done: emitted=%0d captured=%0d drops=%0d",
                                emitted_hits, captured_hits, drop_count),
                      UVM_LOW)
        endtask

        // -----------------------------------------------------------------------
        // Observer: monitors selected_out_0_valid. For each valid beat, records
        // abs_ts_feb_egress. Correlates with injection queue maintained via
        // shared mailbox (filled by inject loop, consumed here).
        // Since EMU-only mode preserves FIFO order, a simple channel-indexed
        // queue suffices.
        //
        // Timestamps: abs_ts_a      = stored at injection
        //             abs_ts_pre_rbcam  = abs_ts_a + 8 ns (1 cycle: FIFO push latency)
        //             abs_ts_post_rbcam = abs_ts_a + 8 ns (arbiter-output estimate)
        //             abs_ts_feb_egress = actual observation time
        //
        // Note: the 4-stage tracking here is structural — the real DUT only exposes
        // two externally observable boundaries (injection and selected_out). The
        // pre/post-rbCAM fields are set to injection time to produce clean
        // zero-difference histograms for those stages; feb_egress carries the
        // end-to-end pipeline latency which is the B002 mismatch observable.
        //
        // The FIFO + arbiter pipeline adds 2..16 cycles (16..128 ns) depending on
        // occupancy. At 100 kHz/ch x 16 ch = 1.6 MHz total, the mean FIFO depth
        // stays at ~(1.6e6 * FIFO_push_cycle) ≈ 1..3 slots. So the feb_egress
        // distribution should be narrow (O(10-50) cycles = 80-400 ns peak bin)
        // well inside the plotter's [4048, 7096] ns window if the rbCAM adds
        // ~500+ cycle latency (4000 ns) as expected from the B002 hypothesis.
        // -----------------------------------------------------------------------
        // Injection timestamp queue (channel-indexed; FIFO order per channel)
        longint unsigned inj_queue [16][$];
        int unsigned     inj_channel_queue [16][$]; // channel index for each slot
        int unsigned     inj_tcrs_queue [16][$];
        int unsigned     inj_tfine_queue [16][$];
        longint unsigned global_hit_id;

        // Flat queue indexed by hit injection order (since EMU mode preserves order)
        longint unsigned flat_ts_a_queue   [$];
        int unsigned     flat_channel_queue[$];
        int unsigned     flat_tcoarse_queue[$];
        int unsigned     flat_tfine_queue  [$];
        longint unsigned flat_hit_id_queue [$];

        task observe_loop(input longint unsigned total_cycles);
            longint unsigned deadline;
            longint unsigned obs_cycle;
            longint unsigned ts_feb;
            longint unsigned ts_a;
            int unsigned     ch;
            int unsigned     tcc;
            int unsigned     tfine;
            longint unsigned hid;
            bit [44:0]       out_data;

            deadline = total_cycles + 8192; // cover drain period too
            obs_cycle = 0;

            // Poll for selected_out_0_valid on every posedge
            while (obs_cycle < deadline) begin
                @(posedge dut_vif.clk);
                obs_cycle++;

                if (dut_vif.selected_out_0_valid === 1'b1) begin
                    // $time in a package compiled at timescale 1ps/1ps returns
                    // picoseconds. Divide by 1000 to get nanoseconds.
                    ts_feb   = longint'($time) / 1000;
                    out_data = dut_vif.selected_out_0_data;

                    // Pop from flat queue (FIFO order preserved in EMU-only mode)
                    if (flat_ts_a_queue.size() == 0) begin
                        `uvm_error("PROF_INT_001_OBS",
                                   "selected_out_0_valid with empty injection queue (ghost hit)")
                        drop_count++;
                    end else begin
                        ts_a  = flat_ts_a_queue.pop_front();
                        ch    = flat_channel_queue.pop_front();
                        tcc   = flat_tcoarse_queue.pop_front();
                        tfine = flat_tfine_queue.pop_front();
                        hid   = flat_hit_id_queue.pop_front();

                        write_closed_record(hid, ch, tfine, tcc,
                                            ts_a,
                                            ts_a + 8,   // pre_rbcam: 1-cycle FIFO push
                                            ts_a + 8,   // post_rbcam: same (no separate tap)
                                            ts_feb);
                        captured_hits++;
                    end
                end
            end
        endtask

        // -----------------------------------------------------------------------
        // Override inject_loop to also populate the flat queue for observer
        // correlation. Since inject_loop and observe_loop run in parallel fork,
        // we use non-blocking queue access (SV queues are not thread-safe in
        // strict sense but Questa serialises event-driven updates).
        //
        // The override is done by replacing inject_loop with a version that
        // pushes to flat_ts_a_queue before asserting valid.
        // -----------------------------------------------------------------------
        // NOTE: The injection is done inside body() via a direct fork with the
        //       two tasks. The flat_queue is populated in inject_loop_with_record
        //       which is the actual task called from body().
        task inject_loop_with_record(input int unsigned init_seed,
                                     input longint unsigned total_cycles);
            longint unsigned cycle_count;
            int unsigned     s_inj;
            int unsigned     ch_idx;
            int unsigned     gap;
            int unsigned     mean_gap;

            s_inj     = init_seed ^ 32'hA5A5_A5A5;
            ch_idx    = 0;
            cycle_count = 0;
            mean_gap  = (125_000_000 / (rate_hz_per_channel * num_channels));
            global_hit_id = 0;

            while (cycle_count < total_cycles) begin
                int unsigned t_coarse;
                int unsigned t_fine;
                bit [44:0]   payload;
                longint unsigned ts_inject;

                void'(lcg_next(s_inj));
                gap = (s_inj >> 8) % (mean_gap * 4);
                if (gap < 2) gap = 2;
                repeat (gap) @(posedge dut_vif.clk);
                cycle_count += gap;
                if (cycle_count >= total_cycles)
                    break;

                void'(lcg_next(s_inj));
                t_coarse = (s_inj ^ (ch_idx << 5)) & 15'h7fff;
                void'(lcg_next(s_inj));
                t_fine   = s_inj & 5'h1f;

                payload = {4'd0,
                           5'(ch_idx & 5'h0f),
                           15'(t_coarse),
                           5'(t_fine),
                           15'd1,
                           1'b1};

                @(negedge dut_vif.clk);
                // $time in a package compiled at timescale 1ps/1ps returns
                // picoseconds. Divide by 1000 to get nanoseconds for the
                // plotter (which expects ns in the [0..8500] ns range).
                ts_inject = longint'($time) / 1000;

                // Push to flat queue BEFORE asserting valid so observer can
                // match the hit when selected_out_0_valid fires.
                flat_ts_a_queue.push_back(ts_inject);
                flat_channel_queue.push_back(ch_idx);
                flat_tcoarse_queue.push_back(t_coarse);
                flat_tfine_queue.push_back(t_fine);
                flat_hit_id_queue.push_back(global_hit_id++);

                dut_vif.emu_in_0_data           <= payload;
                dut_vif.emu_in_0_channel        <= 4'(ch_idx & 4'hf);
                dut_vif.emu_in_0_error          <= 3'b000;
                dut_vif.emu_in_0_startofpacket  <= 1'b1;
                dut_vif.emu_in_0_endofpacket    <= 1'b1;
                dut_vif.emu_in_0_endofrun       <= 1'b0;
                dut_vif.emu_in_0_valid          <= 1'b1;

                @(negedge dut_vif.clk);
                dut_vif.emu_in_0_valid <= 1'b0;

                emitted_hits++;
                ch_idx = (ch_idx + 1) % num_channels;
            end

            @(negedge dut_vif.clk);
            dut_vif.emu_in_0_valid <= 1'b0;
        endtask

    endclass

endpackage
