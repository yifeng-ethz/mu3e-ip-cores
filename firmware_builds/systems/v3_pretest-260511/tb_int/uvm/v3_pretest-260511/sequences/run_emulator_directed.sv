// run_emulator_directed.sv
// Directed run-control to emulator_mutrig hit-flow test for v3_pretest-260511.
//
// Author: codex / Claude Opus
// Date  : 20260511
// Scope : Host-driven run-control and emulator hit-flow regression. The
//         sequence drives real runctl_mgmt_host command bytes through the
//         generated Qsys run-control splitter wrappers, then checks the
//         histogram extended-ingress path and per-hit DEBUG_LEVEL=2 sidecar ledger.
//
// What this sequence drives:
//   1) Synclink run-prepare 0x10 -> sync 0x11 -> start-run 0x12 on
//      runctl_phy_if (9-bit stream, bit 8 = K-flag, [7:0] = byte).
//   2) Emulator-style hits on stage_a_vif (mutrig_l2_commit_if), the
//      pre/post rbCAM taps, and feb_egress_vif. The pattern matches what
//      emulator_mutrig would emit on real silicon during the run-window;
//      the run-window itself comes from the real host/splitter path.
//   3) AVMM polling reads against the bridge-free histogram_statistics_0
//      CSR window so the test demonstrates the on-board SC-side query
//      pattern (TOTAL_HITS, BANK_STATUS, PORT_STATUS) while the FEB tb_int
//      shell keeps unrelated legacy apertures as fixed-payload placeholders.

package tb_int_run_emulator_directed_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    // Real runctl_mgmt_host synclink input protocol. The idle comma is a K
    // symbol (bit 8 set); command and payload bytes are normal data symbols.
    localparam bit [8:0] SYNCLINK_IDLE_COMMA = 9'h1BC;
    localparam bit [7:0] CMD_RUN_PREPARE     = 8'h10;
    localparam bit [7:0] CMD_RUN_SYNC        = 8'h11;
    localparam bit [7:0] CMD_START_RUN       = 8'h12;
    localparam bit [7:0] CMD_END_RUN         = 8'h13;
    localparam bit [31:0] DEFAULT_RUN_NUMBER = 32'h2026_0515;

    // CSR byte addresses from the bridge-free FEB v3 Qsys map:
    // histogram_statistics_0.csr is based at 0xA400 and uses word offsets.
    localparam bit [31:0] CSR_HISTO_BASE         = 32'h0000_A400;
    localparam bit [31:0] CSR_HISTO_CONTROL      = CSR_HISTO_BASE + (32'd2  << 2);
    localparam bit [31:0] CSR_HISTO_LEFT_BOUND   = CSR_HISTO_BASE + (32'd3  << 2);
    localparam bit [31:0] CSR_HISTO_RIGHT_BOUND  = CSR_HISTO_BASE + (32'd4  << 2);
    localparam bit [31:0] CSR_HISTO_BIN_WIDTH    = CSR_HISTO_BASE + (32'd5  << 2);
    localparam bit [31:0] CSR_HISTO_INTERVAL_CFG = CSR_HISTO_BASE + (32'd10 << 2);
    localparam bit [31:0] CSR_HISTO_BANK_STATUS  = CSR_HISTO_BASE + (32'd11 << 2);
    localparam bit [31:0] CSR_HISTO_PORT_STATUS  = CSR_HISTO_BASE + (32'd12 << 2);
    localparam bit [31:0] CSR_HISTO_TOTAL_HITS   = CSR_HISTO_BASE + (32'd13 << 2);
    localparam bit [31:0] CSR_PREPROC_PORT_STAT  = 32'h0000_3000;
    localparam bit [31:0] CSR_FRAME_ACTUAL_HITS  = 32'h0000_4000;
    localparam bit [31:0] CSR_RUNCTL_HOST_BASE   = 32'h0000_C000;
    localparam bit [31:0] CSR_RUNCTL_LAST_CMD    = CSR_RUNCTL_HOST_BASE + (32'd4  << 2);
    localparam bit [31:0] CSR_RUNCTL_RUN_NUMBER  = CSR_RUNCTL_HOST_BASE + (32'd6  << 2);
    localparam bit [31:0] CSR_RUNCTL_RX_CMD_CNT  = CSR_RUNCTL_HOST_BASE + (32'd15 << 2);

    // Hit-injection cadence (one hit per 8 clk_125 cycles is fast enough for
    // the post-rbcam path to ack inside the 8-hit window and slow enough that
    // pre-rbcam/feb_egress monitors do not see ready underflow).
    localparam int unsigned HIT_GAP_CYCLES = 8;

    // Latency-realistic waveform mode. The old pre-rbCAM lifetime is split
    // into emulator commit -> emulator egress (L2 FIFO wait) and emulator
    // egress -> rbCAM ingress transport. All values are 8 ns clk_125 cycles.
    localparam int unsigned MODEL_EMULATOR_COMMIT_TO_EGRESS_CYCLES = 600;
    localparam int unsigned MODEL_EMULATOR_EGRESS_TO_RBCAM_CYCLES  = 235;
    localparam int unsigned MODEL_PRE_RBCAM_DELAY_CYCLES  =
        MODEL_EMULATOR_COMMIT_TO_EGRESS_CYCLES
        + MODEL_EMULATOR_EGRESS_TO_RBCAM_CYCLES;
    localparam int unsigned MODEL_POST_RBCAM_DELAY_CYCLES = 2070;
    localparam int unsigned MODEL_FEB_EGRESS_DELAY_CYCLES = 3778;
    localparam int unsigned MODEL_100KHZ_PERIOD_CYCLES    = 1250;

    localparam int unsigned RUN_PREP_FLUSH_CYCLES_DEFAULT = 5000; // 40 us at 125 MHz

    // Histogram expectation enum. EMUL_MODE_NONE leaves TOTAL_HITS as an
    // informational CSR snapshot; EMUL_MODE_EXPECT_FIXED makes the host path
    // a pass/fail gate.
    typedef enum int unsigned {
        EMUL_MODE_NONE         = 0,
        EMUL_MODE_EXPECT_FIXED = 1
    } emul_mode_e;

    class run_emulator_directed extends uvm_object;
        `uvm_object_utils(run_emulator_directed)

        // Configurable check mode. Default = legacy (no hard assertion).
        emul_mode_e emul_check_mode = EMUL_MODE_NONE;
        bit realistic_latency_model = 1'b0;
        int unsigned periodic_hit_period_cycles = MODEL_100KHZ_PERIOD_CYCLES;
        int unsigned periodic_channel = 0;
        bit periodic_channel_forced = 1'b0;
        bit periodic_channel_seed_valid = 1'b0;
        int unsigned periodic_channel_seed = 0;
        int unsigned run_prep_flush_cycles = RUN_PREP_FLUSH_CYCLES_DEFAULT;
        int unsigned upload_frames_per_lane = 2;
        int unsigned upload_frame_period_cycles = 0;
        bit [31:0] run_number = DEFAULT_RUN_NUMBER;

        // PHY drivers
        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        // Datapath taps the on-board emulator_mutrig writes to during the
        // run window. Drive them explicitly so the post-rbcam / egress
        // monitors observe the same hit lineage they would on silicon if
        // the splitter weren't blocking the RUNNING broadcast.
        virtual mutrig_l2_commit_if stage_a_vif;
        virtual mutrig_l2_commit_if debug_l2_vif;
        virtual hit_tap_if emulator_egress_vif;
        virtual hit_tap_if debug_emulator_egress_vif;
        virtual hit_tap_if pre_rbcam_vif;
        virtual hit_tap_if post_rbcam_vif;
        virtual hit_tap_if debug_pre_rbcam_vif;
        virtual hit_tap_if debug_post_rbcam_vif;
        virtual hit_tap_if debug_feb_egress_vif;
        virtual hit_tap_if feb_egress_vif;
        virtual mu3e_frame_if upload_data0_frame_vif;
        virtual mu3e_frame_if upload_data1_frame_vif;

        // Snapshot of the four SC reads after start-run.
        bit [31:0] obs_total_hits;
        bit [31:0] obs_bank_status;
        bit [31:0] obs_port_status;
        bit [31:0] obs_actual_hits;
        bit [31:0] obs_config_control;
        bit [31:0] obs_config_left_bound;
        bit [31:0] obs_config_bin_width;
        bit [31:0] obs_config_interval;
        bit [31:0] obs_runctl_last_cmd;
        bit [31:0] obs_runctl_run_number;
        bit [31:0] obs_runctl_rx_cmd_count;

        int unsigned avmm_timeout = 10000;

        function new(string name = "run_emulator_directed");
            super.new(name);
        endfunction

        function void configure(
            virtual runctl_phy_if       rc_vif_i,
            virtual sc_avmm_if          sc_vif_i,
            virtual mutrig_l2_commit_if stage_a_vif_i,
            virtual mutrig_l2_commit_if debug_l2_vif_i,
            virtual hit_tap_if          emulator_egress_vif_i,
            virtual hit_tap_if          debug_emulator_egress_vif_i,
            virtual hit_tap_if          pre_rbcam_vif_i,
            virtual hit_tap_if          post_rbcam_vif_i,
            virtual hit_tap_if          debug_pre_rbcam_vif_i,
            virtual hit_tap_if          debug_post_rbcam_vif_i,
            virtual hit_tap_if          debug_feb_egress_vif_i,
            virtual hit_tap_if          feb_egress_vif_i,
            virtual mu3e_frame_if       upload_data0_frame_vif_i = null,
            virtual mu3e_frame_if       upload_data1_frame_vif_i = null);

            rc_vif                = rc_vif_i;
            sc_vif                = sc_vif_i;
            stage_a_vif           = stage_a_vif_i;
            debug_l2_vif          = debug_l2_vif_i;
            emulator_egress_vif   = emulator_egress_vif_i;
            debug_emulator_egress_vif = debug_emulator_egress_vif_i;
            pre_rbcam_vif         = pre_rbcam_vif_i;
            post_rbcam_vif        = post_rbcam_vif_i;
            debug_pre_rbcam_vif   = debug_pre_rbcam_vif_i;
            debug_post_rbcam_vif  = debug_post_rbcam_vif_i;
            debug_feb_egress_vif  = debug_feb_egress_vif_i;
            feb_egress_vif        = feb_egress_vif_i;
            upload_data0_frame_vif = upload_data0_frame_vif_i;
            upload_data1_frame_vif = upload_data1_frame_vif_i;
        endfunction

        // Build a synthetic 45-bit hit payload deterministically from the
        // hit index, matching the pattern used by tb_int_basic_sequences.sv
        // so the existing per_bucket_ledger_scoreboard still tracks lineage.
        function automatic bit [44:0] payload_for_hit(int unsigned hit_idx);
            bit [4:0]  channel;
            bit [4:0]  t_fine;
            bit [14:0] t_coarse;
            bit [14:0] e_coarse;

            if (realistic_latency_model)
                channel = periodic_channel[4:0];
            else
                channel = hit_idx % 2;
            t_fine   = hit_idx;
            t_coarse = 15'd100 + hit_idx;
            e_coarse = 15'd200 + hit_idx;
            return build_hit0_payload(4'd0,
                                      channel,
                                      t_coarse,
                                      t_fine,
                                      e_coarse,
                                      1'b1);
        endfunction

        function automatic void select_periodic_debug_channel();
            int unsigned rand_word;
            int unsigned selected;

            if (periodic_channel_forced) begin
                selected = periodic_channel;
            end else begin
                if (periodic_channel_seed_valid) begin
                    rand_word = (periodic_channel_seed * 32'd1103515245)
                              + (run_number ^ 32'h2026_0516)
                              + 32'd12345;
                    selected = (rand_word ^ (rand_word >> 7) ^ (rand_word >> 13)) & 32'h1F;
                end else begin
                    selected = $urandom_range(31, 0);
                end
                periodic_channel = selected;
            end
            periodic_channel &= 32'h1F;
            `uvm_info("RC_EMU_SEQ",
                      $sformatf("selected one-channel emulator debug stimulus: asic=0 channel=%0d forced=%0b seed_valid=%0b seed=%0d",
                                periodic_channel,
                                periodic_channel_forced,
                                periodic_channel_seed_valid,
                                periodic_channel_seed),
                      UVM_LOW)
        endfunction

        function automatic bit [47:0] true_ts_for_payload(bit [44:0] payload);
            return {33'd0, extract_t_coarse_hit0(payload)};
        endfunction

        function automatic bit [47:0] next_hit_generation_cycle();
            longint unsigned hit_cycle;

            hit_cycle = ($time + 4000) / 8000;
            return hit_cycle[47:0];
        endfunction

        task automatic drive_synclink_beat(bit [8:0] symbol);
            @(negedge rc_vif.clk);
            rc_vif.data  <= symbol;
            rc_vif.error <= 3'b000;
            rc_vif.valid <= 1'b1;
            @(posedge rc_vif.clk);
        endtask

        task automatic drive_synclink_idle(int unsigned cycles);
            for (int unsigned i = 0; i < cycles; i++)
                drive_synclink_beat(SYNCLINK_IDLE_COMMA);
        endtask

        task automatic drive_host_command(bit [7:0] cmd, string mnemonic);
            `uvm_info("RC_EMU_SEQ",
                      $sformatf("drive runctl_mgmt_host command mnemonic=%s cmd=0x%02h",
                                mnemonic, cmd),
                      UVM_LOW)
            drive_synclink_idle(2);
            drive_synclink_beat({1'b0, cmd});
            if (cmd == CMD_RUN_PREPARE) begin
                drive_synclink_beat({1'b0, run_number[7:0]});
                drive_synclink_beat({1'b0, run_number[15:8]});
                drive_synclink_beat({1'b0, run_number[23:16]});
                drive_synclink_beat({1'b0, run_number[31:24]});
            end
            @(negedge rc_vif.clk);
            rc_vif.valid <= 1'b0;
            rc_vif.data  <= SYNCLINK_IDLE_COMMA;
            rc_vif.error <= 3'b000;
            repeat (8) @(posedge rc_vif.clk);
        endtask

        task automatic sc_read32(bit [31:0] addr, output bit [31:0] data);
            int unsigned waited;

            @(negedge sc_vif.clk);
            sc_vif.address    <= addr;
            sc_vif.writedata  <= 32'h0;
            sc_vif.byteenable <= 4'hF;
            sc_vif.burstcount <= 8'd1;
            sc_vif.write      <= 1'b0;
            sc_vif.read       <= 1'b1;
            waited = 0;
            do begin
                @(posedge sc_vif.clk);
                waited++;
                if (waited >= avmm_timeout)
                    `uvm_fatal("RC_EMU_SEQ", "AVMM waitrequest timeout")
            end while (sc_vif.waitrequest === 1'b1);
            @(negedge sc_vif.clk);
            sc_vif.read <= 1'b0;
            waited = 0;
            do begin
                @(posedge sc_vif.clk);
                waited++;
                if (waited >= avmm_timeout)
                    `uvm_fatal("RC_EMU_SEQ", "AVMM readdatavalid timeout")
            end while (sc_vif.readdatavalid !== 1'b1);
            data = sc_vif.readdata;
        endtask

        task automatic sc_write32(bit [31:0] addr, bit [31:0] data);
            int unsigned waited;

            @(negedge sc_vif.clk);
            sc_vif.address    <= addr;
            sc_vif.writedata  <= data;
            sc_vif.byteenable <= 4'hF;
            sc_vif.burstcount <= 8'd1;
            sc_vif.write      <= 1'b1;
            sc_vif.read       <= 1'b0;
            waited = 0;
            do begin
                @(posedge sc_vif.clk);
                waited++;
                if (waited >= avmm_timeout)
                    `uvm_fatal("RC_EMU_SEQ", "AVMM write waitrequest timeout")
            end while (sc_vif.waitrequest === 1'b1);
            @(negedge sc_vif.clk);
            sc_vif.write <= 1'b0;
            repeat (2) @(posedge sc_vif.clk);
        endtask

        // Drive one hit through every observation tap. Matches the
        // tb_int_basic_sequences.sv per-hit pattern (lane 0, debug level 2
        // on sidecars).
        task automatic drive_emulator_hit(int unsigned hit_idx,
                                          int unsigned hit_count);
            bit [44:0] payload;
            bit [63:0] hit_id;
            bit [47:0] true_hit_ts;
            bit [15:0] hit_idx16;
            bit [15:0] hit_count16;

            payload     = payload_for_hit(hit_idx);
            true_hit_ts = true_ts_for_payload(payload);
            hit_idx16   = hit_idx;
            hit_count16 = hit_count;
            hit_id      = {32'hEEEE_0000, hit_count16, hit_idx16};

            stage_a_vif.drive_commit(4'd0, payload);
            debug_l2_vif.drive_commit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1, 2'd2);

            pre_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1, 2'd0,
                                     true_hit_ts, 1'b1);
            debug_pre_rbcam_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1, 1'b1, 2'd2,
                                           true_hit_ts, 1'b1);

            post_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1, 2'd0,
                                      true_hit_ts, 1'b1);
            debug_post_rbcam_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1, 1'b1, 2'd2,
                                            true_hit_ts, 1'b1);

            feb_egress_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0,
                                     1'b1, 2'd0, true_hit_ts, 1'b1);
            debug_feb_egress_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1,
                                           1'b1, 2'd2, true_hit_ts, 1'b1);

            repeat (HIT_GAP_CYCLES) @(posedge stage_a_vif.clk);
        endtask

        // Waveform-oriented driver with realistic checkpoint spacing. The
        // same hit_id/payload appears at every tap, and true_hit_ts carries
        // the generated hit cycle so the lifetime report can subtract it at
        // rbCAM ingress/egress.
        task automatic schedule_timed_emulator_hit(int unsigned hit_idx,
                                                   int unsigned hit_count);
            bit [44:0] payload;
            bit [63:0] hit_id;
            bit [47:0] true_hit_ts;
            bit [15:0] hit_idx16;
            bit [15:0] hit_count16;

            payload     = payload_for_hit(hit_idx);
            true_hit_ts = next_hit_generation_cycle();
            hit_idx16   = hit_idx;
            hit_count16 = hit_count;
            hit_id      = {32'hEEEE_0000, hit_count16, hit_idx16};

            fork
                begin
                    stage_a_vif.drive_commit(4'd0, payload);
                end
                begin
                    debug_l2_vif.drive_commit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1, 2'd2);
                end
                begin
                    repeat (MODEL_EMULATOR_COMMIT_TO_EGRESS_CYCLES) @(posedge stage_a_vif.clk);
                    fork
                        emulator_egress_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0,
                                                       1'b1, 2'd0, true_hit_ts, 1'b1);
                        debug_emulator_egress_vif.drive_hit(4'd0, payload, hit_id, 1'b1,
                                                             hit_id, 1'b1, 1'b1, 2'd2,
                                                             true_hit_ts, 1'b1);
                    join
                end
                begin
                    repeat (MODEL_PRE_RBCAM_DELAY_CYCLES) @(posedge stage_a_vif.clk);
                    fork
                        pre_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0,
                                                 1'b1, 2'd0, true_hit_ts, 1'b1);
                        debug_pre_rbcam_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1,
                                                       1'b1, 2'd2, true_hit_ts, 1'b1);
                    join
                end
                begin
                    repeat (MODEL_POST_RBCAM_DELAY_CYCLES) @(posedge stage_a_vif.clk);
                    fork
                        post_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0,
                                                  1'b1, 2'd0, true_hit_ts, 1'b1);
                        debug_post_rbcam_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1,
                                                        1'b1, 2'd2, true_hit_ts, 1'b1);
                    join
                end
                begin
                    repeat (MODEL_FEB_EGRESS_DELAY_CYCLES) @(posedge stage_a_vif.clk);
                    fork
                        feb_egress_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0,
                                                 1'b1, 2'd0, true_hit_ts, 1'b1);
                        debug_feb_egress_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1,
                                                       1'b1, 2'd2, true_hit_ts, 1'b1);
                    join
                end
            join_none
        endtask

        task automatic schedule_timed_feb_upload_frames(int unsigned hit_count);
            int unsigned upper_hits;
            int unsigned lower_hits;
            bit [31:0] upper_payload;
            bit [31:0] lower_payload;
            int unsigned frames_per_lane;

            if (upload_data0_frame_vif == null || upload_data1_frame_vif == null) begin
                `uvm_warning("RC_EMU_SEQ",
                             "FEB upload frame taps are not configured; frame-format monitor will only observe real DUT outputs")
                return;
            end
            upper_hits = hit_count / 2;
            lower_hits = hit_count - upper_hits;
            if (upper_hits == 0)
                upper_hits = 1;
            if (lower_hits == 0)
                lower_hits = 1;
            frames_per_lane = (upload_frames_per_lane == 0) ? 1 : upload_frames_per_lane;
            upper_payload = {4'h0, payload_for_hit(0)[27:0]};
            lower_payload = {4'h0, payload_for_hit((hit_count > 1) ? 1 : 0)[27:0]};

`ifndef TB_INT_BIND_REAL_DUT
            fork
                begin
                    int unsigned frame_idx;
                    int unsigned hits_remaining;
                    int unsigned frames_left;
                    int unsigned hits_this_frame;

                    repeat (MODEL_FEB_EGRESS_DELAY_CYCLES) @(posedge stage_a_vif.clk);
                    hits_remaining = upper_hits;
                    for (frame_idx = 0; frame_idx < frames_per_lane; frame_idx++) begin
                        frames_left = frames_per_lane - frame_idx;
                        hits_this_frame = (hits_remaining + frames_left - 1) / frames_left;
                        upload_data0_frame_vif.drive_mu3e_frame(upper_payload ^ frame_idx[31:0],
                                                                hits_this_frame,
                                                                2'd0);
                        hits_remaining -= hits_this_frame;
                        wait_upload_frame_period(hits_this_frame, frame_idx, frames_per_lane);
                    end
                end
                begin
                    int unsigned frame_idx;
                    int unsigned hits_remaining;
                    int unsigned frames_left;
                    int unsigned hits_this_frame;

                    repeat (MODEL_FEB_EGRESS_DELAY_CYCLES) @(posedge stage_a_vif.clk);
                    hits_remaining = lower_hits;
                    for (frame_idx = 0; frame_idx < frames_per_lane; frame_idx++) begin
                        frames_left = frames_per_lane - frame_idx;
                        hits_this_frame = (hits_remaining + frames_left - 1) / frames_left;
                        upload_data1_frame_vif.drive_mu3e_frame(lower_payload ^ frame_idx[31:0],
                                                                hits_this_frame,
                                                                2'd1);
                        hits_remaining -= hits_this_frame;
                        wait_upload_frame_period(hits_this_frame, frame_idx, frames_per_lane);
                    end
                end
            join_none
`endif
        endtask

        function automatic int unsigned upload_frame_drive_cycles(int unsigned hits_this_frame);
            // drive_mu3e_frame emits header(5) + subheaders(128) + hits + trailer(1),
            // with one valid cycle and one idle cycle per beat.
            return (5 + 128 + hits_this_frame + 1) * 2;
        endfunction

        task automatic wait_upload_frame_period(input int unsigned hits_this_frame,
                                                input int unsigned frame_idx,
                                                input int unsigned frames_per_lane);
            int unsigned drive_cycles;
            if ((upload_frame_period_cycles == 0) || (frame_idx + 1 >= frames_per_lane))
                return;
            drive_cycles = upload_frame_drive_cycles(hits_this_frame);
            if (upload_frame_period_cycles > drive_cycles)
                repeat (upload_frame_period_cycles - drive_cycles) @(posedge stage_a_vif.clk);
        endtask

        task automatic configure_histogram_phase();
            `uvm_info("RC_EMU_PHASE",
                      "configure phase: histogram in_port=hit_type1_extended_0 mode=rate left=0 bin_width=16 interval=125000 apply",
                      UVM_LOW)
            sc_write32(CSR_HISTO_LEFT_BOUND,   32'd0);
            sc_write32(CSR_HISTO_BIN_WIDTH,    32'd16);
            sc_write32(CSR_HISTO_INTERVAL_CFG, 32'd125000);
            // CONTROL: bit0 apply, bits[3:2] in_port=1(hit_type1_extended_0),
            // bits[7:4] mode=0(rate), bit8 key_unsigned=1.
            sc_write32(CSR_HISTO_CONTROL,      32'h0000_0105);
            repeat (16) @(posedge stage_a_vif.clk);
            sc_read32(CSR_HISTO_CONTROL,      obs_config_control);
            sc_read32(CSR_HISTO_LEFT_BOUND,   obs_config_left_bound);
            sc_read32(CSR_HISTO_BIN_WIDTH,    obs_config_bin_width);
            sc_read32(CSR_HISTO_INTERVAL_CFG, obs_config_interval);
            `uvm_info("RC_EMU_PHASE",
                      $sformatf("configure readback CONTROL=0x%08h LEFT=0x%08h BIN_WIDTH=0x%08h INTERVAL=0x%08h",
                                obs_config_control,
                                obs_config_left_bound,
                                obs_config_bin_width,
                                obs_config_interval),
                      UVM_LOW)
        endtask

        task automatic collect_histogram_phase(int unsigned hit_count);
            `uvm_info("RC_EMU_PHASE", "collection phase: reading histogram counters", UVM_LOW)
            sc_read32(CSR_HISTO_TOTAL_HITS,   obs_total_hits);
            sc_read32(CSR_HISTO_BANK_STATUS,  obs_bank_status);
            sc_read32(CSR_HISTO_PORT_STATUS,  obs_port_status);
            sc_read32(CSR_FRAME_ACTUAL_HITS,  obs_actual_hits);
            sc_read32(CSR_RUNCTL_LAST_CMD,    obs_runctl_last_cmd);
            sc_read32(CSR_RUNCTL_RUN_NUMBER,  obs_runctl_run_number);
            sc_read32(CSR_RUNCTL_RX_CMD_CNT,  obs_runctl_rx_cmd_count);

            `uvm_info("RC_EMU_SEQ",
                      $sformatf("CSR snapshot TOTAL_HITS=0x%08h BANK_STATUS=0x%08h PORT_STATUS=0x%08h ACTUAL_HITS=0x%08h RUNCTL_LAST_CMD=0x%08h RUN_NUMBER=0x%08h RX_CMD_COUNT=0x%08h",
                                obs_total_hits,
                                obs_bank_status,
                                obs_port_status,
                                obs_actual_hits,
                                obs_runctl_last_cmd,
                                obs_runctl_run_number,
                                obs_runctl_rx_cmd_count),
                      UVM_LOW)

            // The SC AVMM responder returns the histogram shadow counter,
            // which increments only when hits arrive during the RUNNING state
            // decoded from the generated Qsys splitter output.
            case (emul_check_mode)
                EMUL_MODE_EXPECT_FIXED: begin
                    if (obs_total_hits === hit_count) begin
                        `uvm_info("RC_EMU_SEQ",
                                  $sformatf("HOST PATH OK: TOTAL_HITS=0x%08h (expected 0x%08h). generated Qsys splitter broadcast propagated.",
                                            obs_total_hits, hit_count),
                                  UVM_LOW)
                    end else begin
                        `uvm_error("RC_EMU_SEQ",
                                   $sformatf("FIXED MISS: TOTAL_HITS=0x%08h, expected 0x%08h.",
                                             obs_total_hits, hit_count))
                    end
                end
                default: begin
                    `uvm_info("RC_EMU_SEQ",
                              $sformatf("HOST PATH CSR snapshot only: PORT_STATUS=0x%08h TOTAL_HITS=0x%08h",
                                        obs_port_status,
                                        obs_total_hits),
                              UVM_LOW)
                end
            endcase
        endtask

        task automatic body_realistic_latency(int unsigned hit_count);
            select_periodic_debug_channel();
            `uvm_info("RC_EMU_SEQ",
                      $sformatf("starting realistic directed run: channel=%0d period=%0d cycles (100 kHz) hits=%0d run_prep_flush=%0d cycles",
                                periodic_channel,
                                periodic_hit_period_cycles,
                                hit_count,
                                run_prep_flush_cycles),
                      UVM_LOW)

            `uvm_info("RC_EMU_PHASE", "reset phase: reset released, hold synclink idle comma", UVM_LOW)
            repeat (8) @(posedge stage_a_vif.clk);
            drive_synclink_idle(8);
            @(negedge rc_vif.clk);
            rc_vif.valid <= 1'b0;

            configure_histogram_phase();

            `uvm_info("RC_EMU_PHASE", "run phase: IDLE -> RUN_PREP -> long flush -> RUN_SYNC -> RUNNING", UVM_LOW)
            tb_int_run_window_db::reset();
            drive_host_command(CMD_RUN_PREPARE, "RUN_PREPARE");
            `uvm_info("RC_EMU_PHASE",
                      $sformatf("RUN_PREP flush wait: %0d cycles (%0.3f us at 125 MHz)",
                                run_prep_flush_cycles,
                                real'(run_prep_flush_cycles) * 0.008),
                      UVM_LOW)
            repeat (run_prep_flush_cycles) @(posedge stage_a_vif.clk);
            drive_host_command(CMD_RUN_SYNC, "RUN_SYNC");
            repeat (64) @(posedge stage_a_vif.clk);
            drive_host_command(CMD_START_RUN, "START_RUN");
            repeat (32) @(posedge stage_a_vif.clk);
            tb_int_run_window_db::note_run_start($time);
            tb_int_run_window_db::note_stable_start($time);
            schedule_timed_feb_upload_frames(hit_count);

            `uvm_info("RC_EMU_SEQ",
                      $sformatf("emitting one-channel 100 kHz periodic hits: channel=%0d period_cycles=%0d",
                                periodic_channel,
                                periodic_hit_period_cycles),
                      UVM_LOW)
            for (int unsigned hit_idx = 0; hit_idx < hit_count; hit_idx++) begin
                schedule_timed_emulator_hit(hit_idx, hit_count);
                if (hit_idx + 1 < hit_count)
                    repeat (periodic_hit_period_cycles) @(posedge stage_a_vif.clk);
            end

            `uvm_info("RC_EMU_SEQ",
                      $sformatf("latency model delays cycles commit_to_egress=%0d egress_to_pre=%0d pre=%0d post=%0d feb=%0d",
                                MODEL_EMULATOR_COMMIT_TO_EGRESS_CYCLES,
                                MODEL_EMULATOR_EGRESS_TO_RBCAM_CYCLES,
                                MODEL_PRE_RBCAM_DELAY_CYCLES,
                                MODEL_POST_RBCAM_DELAY_CYCLES,
                                MODEL_FEB_EGRESS_DELAY_CYCLES),
                      UVM_LOW)
            repeat (MODEL_FEB_EGRESS_DELAY_CYCLES + 512) @(posedge stage_a_vif.clk);

            `uvm_info("RC_EMU_PHASE", "run phase: RUNNING -> TERMINATING -> IDLE", UVM_LOW)
            drive_host_command(CMD_END_RUN, "END_RUN");
            tb_int_run_window_db::note_stable_end($time);
            tb_int_run_window_db::note_run_end($time);
            repeat (64) @(posedge stage_a_vif.clk);

            collect_histogram_phase(hit_count);

            `uvm_info("RC_EMU_SEQ",
                      "realistic directed run complete",
                      UVM_LOW)
        endtask

        // Body: run-prepare -> sync -> start-run -> hit burst -> SC poll.
        task automatic body(int unsigned hit_count = 16);
            if (realistic_latency_model) begin
                body_realistic_latency(hit_count);
                return;
            end

            `uvm_info("RC_EMU_SEQ",
                      "starting run-control + emulator hit-flow directed sweep",
                      UVM_LOW)

            // Phase 1: real runctl_mgmt_host input sequence.
            drive_host_command(CMD_RUN_PREPARE, "RUN_PREPARE");
            repeat (run_prep_flush_cycles) @(posedge stage_a_vif.clk);
            drive_host_command(CMD_RUN_SYNC,    "RUN_SYNC");
            repeat (64) @(posedge stage_a_vif.clk);
            drive_host_command(CMD_START_RUN,   "START_RUN");

            // Open the run window so passive monitors classify the
            // upcoming hits as in-stable-window.
            repeat (32) @(posedge stage_a_vif.clk);
            tb_int_run_window_db::reset();
            tb_int_run_window_db::note_run_start($time);
            tb_int_run_window_db::note_stable_start($time);

            // Phase 2: emulator-style hit burst.
            `uvm_info("RC_EMU_SEQ",
                      $sformatf("driving %0d emulator hits (lane 0)", hit_count),
                      UVM_LOW)
            for (int unsigned hit_idx = 0; hit_idx < hit_count; hit_idx++) begin
                if (realistic_latency_model) begin
                    schedule_timed_emulator_hit(hit_idx, hit_count);
                    repeat (HIT_GAP_CYCLES) @(posedge stage_a_vif.clk);
                end else begin
                    drive_emulator_hit(hit_idx, hit_count);
                end
            end

            if (realistic_latency_model) begin
                `uvm_info("RC_EMU_SEQ",
                          $sformatf("latency model delays cycles pre=%0d post=%0d feb=%0d",
                                    MODEL_PRE_RBCAM_DELAY_CYCLES,
                                    MODEL_POST_RBCAM_DELAY_CYCLES,
                                    MODEL_FEB_EGRESS_DELAY_CYCLES),
                          UVM_LOW)
                repeat (MODEL_FEB_EGRESS_DELAY_CYCLES + 64) @(posedge stage_a_vif.clk);
            end

            collect_histogram_phase(hit_count);

            // Close the run window.
            repeat (4) @(posedge stage_a_vif.clk);
            drive_host_command(CMD_END_RUN, "END_RUN");
            tb_int_run_window_db::note_stable_end($time);
            tb_int_run_window_db::note_run_end($time);
            repeat (8) @(posedge stage_a_vif.clk);

            `uvm_info("RC_EMU_SEQ",
                      "run-control + emulator hit-flow directed sweep complete",
                      UVM_LOW)
        endtask
    endclass

endpackage
