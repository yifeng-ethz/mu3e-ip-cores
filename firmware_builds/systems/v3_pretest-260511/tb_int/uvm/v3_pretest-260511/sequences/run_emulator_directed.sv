// run_emulator_directed.sv
// Directed run-control to emulator_mutrig hit-flow test for v3_pretest-260511.
//
// Author: codex / Claude Opus
// Date  : 20260511
// Scope : Phase 3 BUG-RC-RUN-EMUL repro. After start-run (0x12) on the
//         v3_pretest-260511 on-board FEB, the 8 emulator_mutrig instances
//         stay quiescent for >4 s (TOTAL_HITS = 0, BANK_STATUS unchanged,
//         PORT_STATUS = 0x000000FF). Working hypothesis: B002-pattern --
//         the Qsys run_control_splitter (USE_READY=0) has dangling
//         outN_ready inputs that synthesize as logic 0 by the AND-default
//         policy, blocking the RUNNING-state broadcast to emulator_mutrig.
//
// What this sequence drives:
//   1) Synclink run-prepare 0x10 -> sync 0x11 -> start-run 0x12 on
//      runctl_phy_if (9-bit AVST, bit 8 = K-flag, [7:0] = opcode).
//   2) Emulator-style hits on stage_a_vif (mutrig_l2_commit_if), the
//      pre/post rbCAM taps, and feb_egress_vif. The pattern matches what
//      emulator_mutrig would emit on real silicon during the run-window;
//      driving these explicitly from the sequence side-steps the
//      run_control_splitter and proves the downstream datapath itself is
//      live. In behavioural sim the splitter is NOT modelled (the FEB
//      tb_int does not bind the Qsys-generated DUT in default mode), so
//      the splitter outN_ready dangling-input wire never exists. The bug
//      is therefore silicon-only or requires TB_INT_BIND_REAL_DUT with the
//      generated feb_system_v3 synthesis tree compiled in.
//   3) AVMM writes configure histogram_statistics_0 and the histogram ingress
//      bridge before RUNNING; post-run AVMM reads check CONTROL, INTERVAL_CFG,
//      TOTAL_HITS, LAST_INTERVAL_TOTAL_HITS, BANK_STATUS, PORT_STATUS, and
//      bridge-local counters.
//
// Splitter-blockage repro flag:
//   The sequence emits a uvm_info marker after the start-run step
//   describing whether the behavioural sim shows the silicon-side
//   PORT_STATUS = 0x000000FF idle pattern (it cannot, because the stub
//   returns 0x4849_5354 for every read). The marker is the hook the
//   parent regression flips to xfail when the real-DUT bind path lands.

package tb_int_run_emulator_directed_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    // Synclink K-symbol-tagged opcodes (bit 8 = '1' is the K-flag, bits 7:0
    // hold the opcode byte per runctl_mgmt_host.sv:74).
    localparam bit [8:0] OP_RUN_PREPARE = 9'h110;  // CMD_RUN_PREPARE 0x10
    localparam bit [8:0] OP_RUN_SYNC    = 9'h111;  // CMD_RUN_SYNC    0x11
    localparam bit [8:0] OP_START_RUN   = 9'h112;  // CMD_START_RUN   0x12

    // CSR byte offsets used by the on-board sc_tool pattern. Exact byte
    // addresses depend on the FEB Qsys map; the stub responder ignores the
    // address and returns the fixed pattern, so for this directed sequence
    // any offset within the SC window exercises the bus path. Keep the
    // addresses 4-byte aligned so the stub responder + (future) Qsys-bound
    // responder both accept the burst.
    localparam bit [31:0] CSR_HISTO_BASE                     = 32'h0000_A400;
    localparam bit [31:0] CSR_HISTO_CONTROL                  = CSR_HISTO_BASE + 32'h008;
    localparam bit [31:0] CSR_HISTO_INTERVAL_CFG             = CSR_HISTO_BASE + 32'h028;
    localparam bit [31:0] CSR_HISTO_BANK_STATUS              = CSR_HISTO_BASE + 32'h02C;
    localparam bit [31:0] CSR_HISTO_PORT_STATUS              = CSR_HISTO_BASE + 32'h030;
    localparam bit [31:0] CSR_HISTO_TOTAL_HITS               = CSR_HISTO_BASE + 32'h034;
    localparam bit [31:0] CSR_HISTO_DROPPED_HITS             = CSR_HISTO_BASE + 32'h038;
    localparam bit [31:0] CSR_HISTO_LAST_INTERVAL_TOTAL_HITS = CSR_HISTO_BASE + 32'h044;
    localparam bit [31:0] CSR_HISTO_LAST_INTERVAL_DROP_HITS  = CSR_HISTO_BASE + 32'h048;
    localparam bit [31:0] CSR_HIST_BRIDGE_BASE               = 32'h0000_AC00;
    localparam bit [31:0] CSR_HIST_BRIDGE_CONTROL            = CSR_HIST_BRIDGE_BASE + 32'h008;
    localparam bit [31:0] CSR_HIST_BRIDGE_STATUS             = CSR_HIST_BRIDGE_BASE + 32'h00C;
    localparam bit [31:0] CSR_HIST_BRIDGE_PRE_COUNT          = CSR_HIST_BRIDGE_BASE + 32'h010;
    localparam bit [31:0] CSR_HIST_BRIDGE_POST_COUNT         = CSR_HIST_BRIDGE_BASE + 32'h014;
    localparam bit [31:0] CSR_HIST_BRIDGE_HIST_COUNT         = CSR_HIST_BRIDGE_BASE + 32'h018;
    localparam bit [31:0] CSR_HIST_BRIDGE_DROP_COUNT         = CSR_HIST_BRIDGE_BASE + 32'h01C;
    localparam bit [31:0] CSR_FRAME_ACTUAL_HITS  = 32'h0000_4000;

    // On-board observed signatures from Phase 3 (silicon-side, what the
    // sequence should observe once TB_INT_BIND_REAL_DUT promotes the real
    // DUT compile and the splitter dangling-ready bug is reproduced).
    localparam bit [31:0] SI_PORT_STATUS_IDLE   = 32'h0000_00FF;

    // Hit-injection cadence (one hit per 8 clk_125 cycles is fast enough for
    // the post-rbcam path to ack inside the 8-hit window and slow enough that
    // pre-rbcam/feb_egress monitors do not see ready underflow).
    localparam int unsigned HIT_GAP_CYCLES = 8;

    // Per-opcode hold + idle cycles. 16/16 mirrors the SWB directed sweep.
    localparam int unsigned OP_HOLD_CYCLES = 16;
    localparam int unsigned OP_IDLE_CYCLES = 16;

    // Splitter-check expectation enum. Used by the run_emul_blocked /
    // run_emul_fixed test wrappers to assert the post-start-run TOTAL_HITS
    // signature.
    typedef enum int unsigned {
        EMUL_MODE_NONE          = 0, // legacy: emit info marker only
        EMUL_MODE_EXPECT_BLOCKED = 1, // expect TOTAL_HITS == 0 (splitter blocks)
        EMUL_MODE_EXPECT_FIXED   = 2  // expect TOTAL_HITS == hit_count
    } emul_mode_e;

    class run_emulator_directed extends uvm_object;
        `uvm_object_utils(run_emulator_directed)

        // Configurable check mode. Default = legacy (no hard assertion).
        emul_mode_e emul_check_mode = EMUL_MODE_NONE;

        // PHY drivers
        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        // Datapath taps the on-board emulator_mutrig writes to during the
        // run window. Drive them explicitly so the post-rbcam / egress
        // monitors observe the same hit lineage they would on silicon if
        // the splitter weren't blocking the RUNNING broadcast.
        virtual mutrig_l2_commit_if stage_a_vif;
        virtual mutrig_l2_commit_if debug_l2_vif;
        virtual hit_tap_if pre_rbcam_vif;
        virtual hit_tap_if post_rbcam_vif;
        virtual hit_tap_if debug_pre_rbcam_vif;
        virtual hit_tap_if debug_post_rbcam_vif;
        virtual hit_tap_if debug_feb_egress_vif;
        virtual hit_tap_if feb_egress_vif;

        // Snapshot of the four SC reads after start-run.
        bit [31:0] obs_control;
        bit [31:0] obs_interval_cfg;
        bit [31:0] obs_total_hits;
        bit [31:0] obs_dropped_hits;
        bit [31:0] obs_last_interval_total_hits;
        bit [31:0] obs_last_interval_drop_hits;
        bit [31:0] obs_bank_status;
        bit [31:0] obs_port_status;
        bit [31:0] obs_actual_hits;
        bit [31:0] obs_bridge_status;
        bit [31:0] obs_bridge_pre_count;
        bit [31:0] obs_bridge_post_count;
        bit [31:0] obs_bridge_hist_count;
        bit [31:0] obs_bridge_drop_count;

        int unsigned avmm_timeout = 10000;
        int unsigned hist_interval_cycles = 128;
        int unsigned hist_min_intervals = 4;
        int unsigned hist_select_post = 0;
        int unsigned hist_mode = 1;

        function new(string name = "run_emulator_directed");
            super.new(name);
        endfunction

        function void configure(
            virtual runctl_phy_if       rc_vif_i,
            virtual sc_avmm_if          sc_vif_i,
            virtual mutrig_l2_commit_if stage_a_vif_i,
            virtual mutrig_l2_commit_if debug_l2_vif_i,
            virtual hit_tap_if          pre_rbcam_vif_i,
            virtual hit_tap_if          post_rbcam_vif_i,
            virtual hit_tap_if          debug_pre_rbcam_vif_i,
            virtual hit_tap_if          debug_post_rbcam_vif_i,
            virtual hit_tap_if          debug_feb_egress_vif_i,
            virtual hit_tap_if          feb_egress_vif_i);

            rc_vif                = rc_vif_i;
            sc_vif                = sc_vif_i;
            stage_a_vif           = stage_a_vif_i;
            debug_l2_vif          = debug_l2_vif_i;
            pre_rbcam_vif         = pre_rbcam_vif_i;
            post_rbcam_vif        = post_rbcam_vif_i;
            debug_pre_rbcam_vif   = debug_pre_rbcam_vif_i;
            debug_post_rbcam_vif  = debug_post_rbcam_vif_i;
            debug_feb_egress_vif  = debug_feb_egress_vif_i;
            feb_egress_vif        = feb_egress_vif_i;
        endfunction

        // Build a synthetic 45-bit hit payload deterministically from the
        // hit index, matching the pattern used by tb_int_basic_sequences.sv
        // so the existing per_bucket_ledger_scoreboard still tracks lineage.
        function automatic bit [44:0] payload_for_hit(int unsigned hit_idx);
            bit [4:0]  channel;
            bit [4:0]  t_fine;
            bit [14:0] t_coarse;
            bit [14:0] e_coarse;

            channel  = hit_idx % 2;
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

        function automatic bit [47:0] true_ts_for_payload(bit [44:0] payload);
            return {33'd0, extract_t_coarse_hit0(payload)};
        endfunction

        task automatic drive_opcode(bit [8:0] symbol, string mnemonic);
            `uvm_info("RC_EMU_SEQ",
                      $sformatf("drive opcode mnemonic=%s symbol=0x%03h",
                                mnemonic, symbol),
                      UVM_LOW)
            @(negedge rc_vif.clk);
            rc_vif.data  <= symbol;
            rc_vif.error <= 3'b000;
            rc_vif.valid <= 1'b1;
            repeat (OP_HOLD_CYCLES) @(posedge rc_vif.clk);
            @(negedge rc_vif.clk);
            rc_vif.valid <= 1'b0;
            repeat (OP_IDLE_CYCLES) @(posedge rc_vif.clk);
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
            sc_vif.read       <= 1'b0;
            sc_vif.write      <= 1'b1;
            waited = 0;
            do begin
                @(posedge sc_vif.clk);
                waited++;
                if (waited >= avmm_timeout)
                    `uvm_fatal("RC_EMU_SEQ", "AVMM write waitrequest timeout")
            end while (sc_vif.waitrequest === 1'b1);
            @(negedge sc_vif.clk);
            sc_vif.write <= 1'b0;
        endtask

        task automatic configure_histogram_before_running();
            bit [31:0] hist_control_word;
            bit [31:0] bridge_control_word;

            void'($value$plusargs("TB_INT_HIST_INTERVAL_CYCLES=%d", hist_interval_cycles));
            void'($value$plusargs("TB_INT_HIST_MIN_INTERVALS=%d", hist_min_intervals));
            void'($value$plusargs("TB_INT_HIST_SELECT_POST=%d", hist_select_post));
            void'($value$plusargs("TB_INT_HIST_MODE=%d", hist_mode));

            hist_control_word = 32'h0;
            hist_control_word[0] = 1'b1; // apply
            hist_control_word[7:4] = hist_mode[3:0];
            hist_control_word[8] = 1'b1; // unsigned timestamp/key

            bridge_control_word = 32'h0000_0100 | (hist_select_post[0] ? 32'h1 : 32'h0);

            sc_write32(CSR_HISTO_INTERVAL_CFG, hist_interval_cycles[31:0]);
            sc_write32(CSR_HIST_BRIDGE_CONTROL, bridge_control_word);
            sc_write32(CSR_HISTO_CONTROL, hist_control_word);

            sc_read32(CSR_HISTO_INTERVAL_CFG, obs_interval_cfg);
            sc_read32(CSR_HISTO_CONTROL, obs_control);
            sc_read32(CSR_HIST_BRIDGE_STATUS, obs_bridge_status);

            `uvm_info("RC_EMU_SEQ",
                      $sformatf("CONFIG histogram before RUNNING: interval=%0d readback=0x%08h mode=%0d control=0x%08h bridge_select_post=%0d bridge_status=0x%08h",
                                hist_interval_cycles,
                                obs_interval_cfg,
                                hist_mode,
                                obs_control,
                                hist_select_post[0],
                                obs_bridge_status),
                      UVM_LOW)

            if (obs_interval_cfg !== hist_interval_cycles[31:0]) begin
                `uvm_error("RC_EMU_SEQ",
                           $sformatf("HIST CFG MISS: INTERVAL_CFG readback=0x%08h expected=0x%08h",
                                     obs_interval_cfg, hist_interval_cycles[31:0]))
            end
            if (obs_control[7:4] !== hist_mode[3:0]) begin
                `uvm_error("RC_EMU_SEQ",
                           $sformatf("HIST CFG MISS: CONTROL.mode readback=%0d expected=%0d",
                                     obs_control[7:4], hist_mode[3:0]))
            end
            if (obs_bridge_status[0] !== hist_select_post[0]) begin
                `uvm_error("RC_EMU_SEQ",
                           $sformatf("HIST CFG MISS: bridge live_select_post=%0b expected=%0b",
                                     obs_bridge_status[0], hist_select_post[0]))
            end
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

        // Body: histogram CSR configure -> run-prepare -> sync -> start-run
        // -> hit burst longer than ping-pong -> SC poll.
        task automatic body(int unsigned hit_count = 16);
            longint unsigned driven_cycles;
            longint unsigned required_cycles;
            bit hist_has_live_or_latched_hit;

            `uvm_info("RC_EMU_SEQ",
                      "starting run-control + emulator hit-flow directed sweep",
                      UVM_LOW)

            // Phase 1: configure histogram and source bridge before RUNNING.
            // Default mode=1 uses the 48-bit true timestamp sideband carried
            // by Type-1/pre or post-rbCAM data; mode=0 can still be selected
            // by plusarg for rate-only experiments.
            configure_histogram_before_running();

            driven_cycles = longint'(hit_count) * longint'(HIT_GAP_CYCLES);
            required_cycles = longint'(hist_interval_cycles) * longint'(hist_min_intervals);
            if (driven_cycles < required_cycles) begin
                `uvm_error("RC_EMU_SEQ",
                           $sformatf("run length too short for ping-pong: hit_count=%0d gap=%0d gives %0d cycles, need at least %0d cycles (%0d intervals x %0d)",
                                     hit_count,
                                     HIT_GAP_CYCLES,
                                     driven_cycles,
                                     required_cycles,
                                     hist_min_intervals,
                                     hist_interval_cycles))
            end

            // Phase 2: synclink run-prepare -> sync -> start-run.
            drive_opcode(OP_RUN_PREPARE, "run-prepare 0x10");
            drive_opcode(OP_RUN_SYNC,    "sync 0x11");
            drive_opcode(OP_START_RUN,   "start-run 0x12");

            // Open the run window so passive monitors classify the
            // upcoming hits as in-stable-window.
            repeat (8) @(posedge stage_a_vif.clk);
            tb_int_run_window_db::reset();
            tb_int_run_window_db::note_run_start($time);
            tb_int_run_window_db::note_stable_start($time);

            // Phase 3: emulator-style hit burst.
            `uvm_info("RC_EMU_SEQ",
                      $sformatf("driving %0d emulator hits (lane 0)", hit_count),
                      UVM_LOW)
            for (int unsigned hit_idx = 0; hit_idx < hit_count; hit_idx++) begin
                drive_emulator_hit(hit_idx, hit_count);
            end

            // Phase 4: SC CSR poll. The histogram model resets TOTAL_HITS at
            // ping-pong interval boundaries, so fixed verification checks the
            // live counter, the last-interval counter, and the bridge's
            // non-interval hist emit counter.
            sc_read32(CSR_HISTO_CONTROL,      obs_control);
            sc_read32(CSR_HISTO_INTERVAL_CFG, obs_interval_cfg);
            sc_read32(CSR_HISTO_TOTAL_HITS,   obs_total_hits);
            sc_read32(CSR_HISTO_DROPPED_HITS, obs_dropped_hits);
            sc_read32(CSR_HISTO_LAST_INTERVAL_TOTAL_HITS, obs_last_interval_total_hits);
            sc_read32(CSR_HISTO_LAST_INTERVAL_DROP_HITS,  obs_last_interval_drop_hits);
            sc_read32(CSR_HISTO_BANK_STATUS,  obs_bank_status);
            sc_read32(CSR_HISTO_PORT_STATUS,  obs_port_status);
            sc_read32(CSR_FRAME_ACTUAL_HITS,  obs_actual_hits);
            sc_read32(CSR_HIST_BRIDGE_STATUS,     obs_bridge_status);
            sc_read32(CSR_HIST_BRIDGE_PRE_COUNT,  obs_bridge_pre_count);
            sc_read32(CSR_HIST_BRIDGE_POST_COUNT, obs_bridge_post_count);
            sc_read32(CSR_HIST_BRIDGE_HIST_COUNT, obs_bridge_hist_count);
            sc_read32(CSR_HIST_BRIDGE_DROP_COUNT, obs_bridge_drop_count);

            `uvm_info("RC_EMU_SEQ",
                      $sformatf("CSR snapshot CONTROL=0x%08h INTERVAL_CFG=0x%08h TOTAL_HITS=0x%08h LAST_INTERVAL_TOTAL_HITS=0x%08h DROPPED=0x%08h LAST_DROPPED=0x%08h BANK_STATUS=0x%08h PORT_STATUS=0x%08h BRIDGE_STATUS=0x%08h BRIDGE_PRE=0x%08h BRIDGE_POST=0x%08h BRIDGE_HIST=0x%08h BRIDGE_DROP=0x%08h ACTUAL_HITS=0x%08h",
                                obs_control,
                                obs_interval_cfg,
                                obs_total_hits,
                                obs_last_interval_total_hits,
                                obs_dropped_hits,
                                obs_last_interval_drop_hits,
                                obs_bank_status,
                                obs_port_status,
                                obs_bridge_status,
                                obs_bridge_pre_count,
                                obs_bridge_post_count,
                                obs_bridge_hist_count,
                                obs_bridge_drop_count,
                                obs_actual_hits),
                      UVM_LOW)

            // Splitter-blockage check. With the behavioural topology model
            // in tb_int_top.sv, the SC AVMM responder is address-aware:
            // histogram CSR model increments only when the selected Type-1
            // timestamp-bearing hist tap is valid and mock_emulator_running is
            // high. With TB_INT_REPRO_DANGLING_READY defined, the splitter
            // dangling-ready collapse keeps mock_emulator_running=0 and all
            // hist counters stay zero. In the default fixed build the
            // broadcast propagates, ping-pong may reset TOTAL_HITS, and the
            // bridge emit counter reaches hit_count.
            hist_has_live_or_latched_hit = (obs_total_hits != 32'h0)
                || (obs_last_interval_total_hits != 32'h0)
                || (obs_bridge_hist_count != 32'h0);
            case (emul_check_mode)
                EMUL_MODE_EXPECT_BLOCKED: begin
                    if (obs_total_hits === 32'h0
                            && obs_last_interval_total_hits === 32'h0
                            && obs_bridge_hist_count === 32'h0) begin
                        `uvm_info("RC_EMU_SEQ",
                                  $sformatf("BLOCKED OK: TOTAL_HITS=0x%08h LAST_INTERVAL_TOTAL_HITS=0x%08h BRIDGE_HIST=0x%08h (expected all zero). BUG-RC-RUN-EMUL splitter dangling-ready collapse is LIVE.",
                                            obs_total_hits,
                                            obs_last_interval_total_hits,
                                            obs_bridge_hist_count),
                                  UVM_LOW)
                    end else begin
                        `uvm_error("RC_EMU_SEQ",
                                   $sformatf("BLOCKED MISS: TOTAL_HITS=0x%08h LAST_INTERVAL_TOTAL_HITS=0x%08h BRIDGE_HIST=0x%08h, expected all zero.",
                                             obs_total_hits,
                                             obs_last_interval_total_hits,
                                             obs_bridge_hist_count))
                    end
                end
                EMUL_MODE_EXPECT_FIXED: begin
                    if (hist_has_live_or_latched_hit
                            && obs_bridge_hist_count === hit_count) begin
                        `uvm_info("RC_EMU_SEQ",
                                  $sformatf("FIXED OK: TOTAL_HITS=0x%08h LAST_INTERVAL_TOTAL_HITS=0x%08h BRIDGE_HIST=0x%08h expected_bridge=0x%08h after >=%0d ping-pong intervals.",
                                            obs_total_hits,
                                            obs_last_interval_total_hits,
                                            obs_bridge_hist_count,
                                            hit_count,
                                            hist_min_intervals),
                                  UVM_LOW)
                    end else begin
                        `uvm_error("RC_EMU_SEQ",
                                   $sformatf("FIXED MISS: TOTAL_HITS=0x%08h LAST_INTERVAL_TOTAL_HITS=0x%08h BRIDGE_HIST=0x%08h expected_bridge=0x%08h.",
                                             obs_total_hits,
                                             obs_last_interval_total_hits,
                                             obs_bridge_hist_count,
                                             hit_count))
                    end
                end
                default: begin
                    if (obs_port_status === SI_PORT_STATUS_IDLE
                            && obs_total_hits === 32'h0) begin
                        `uvm_info("RC_EMU_SEQ",
                                  "BUG-RC-RUN-EMUL silicon-side signature observed: PORT_STATUS=0x000000FF, TOTAL_HITS=0. run_control_splitter likely blocks broadcast.",
                                  UVM_LOW)
                    end else begin
                        `uvm_info("RC_EMU_SEQ",
                                  $sformatf("BUG-RC-RUN-EMUL pre-fix silicon-only marker: behavioural stub returned PORT_STATUS=0x%08h TOTAL_HITS=0x%08h (not the silicon-idle 0x000000FF/0x00000000 signature). Bug repro requires TB_INT_BIND_REAL_DUT with feb_system_v3 Qsys tree.",
                                            obs_port_status, obs_total_hits),
                                  UVM_LOW)
                    end
                end
            endcase

            // Close the run window.
            repeat (4) @(posedge stage_a_vif.clk);
            tb_int_run_window_db::note_stable_end($time);
            tb_int_run_window_db::note_run_end($time);
            repeat (8) @(posedge stage_a_vif.clk);

            `uvm_info("RC_EMU_SEQ",
                      "run-control + emulator hit-flow directed sweep complete",
                      UVM_LOW)
        endtask
    endclass

endpackage
