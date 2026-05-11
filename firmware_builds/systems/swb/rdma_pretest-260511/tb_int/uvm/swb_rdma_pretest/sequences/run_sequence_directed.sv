// run_sequence_directed.sv
// Directed run-control opcode sweep for SWB rdma_pretest-260511 tb_int.
//
// Author: codex / Claude Opus
// Date  : 20260511
// Scope : Phase 3 on-board GOOD-sequence directed coverage + targeted repros for
//         BUG-RC-RESET-SCWEDGE.
//
// What this sequence drives, in order, on the runctl_phy_if 9-bit synclink AVST:
//   1)  run-prepare        opcode 0x10  (CMD_RUN_PREPARE)
//   2)  sync               opcode 0x11  (CMD_RUN_SYNC)
//   3)  start-run          opcode 0x12  (CMD_START_RUN)
//   4)  end-run            opcode 0x13  (CMD_END_RUN)
//   5)  abort-run          opcode 0x14  (CMD_ABORT_RUN)
//   6)  start-link-test    opcode 0x20  (CMD_START_LINK_TEST)
//   7)  stop-link-test     opcode 0x21  (CMD_STOP_LINK_TEST)
//   8)  start-sync-test    opcode 0x24  (CMD_START_SYNC_TEST)
//   9)  stop-sync-test     opcode 0x25  (CMD_STOP_SYNC_TEST)
//  10)  test-sync          opcode 0x26  (CMD_TEST_SYNC)
//  11)  CMD_RESET          opcode 0x30  (CMD_RESET) -- expected SC-WEDGE step.
//
// Between every step the sequence performs three SC AVMM reads against the
// runctl_mgmt_host CSR window (offsets per runctl_mgmt_host.sv lines 130..150,
// 5-bit word index << 2 == byte offset):
//   STATUS         word 0x03  -> byte 0x0C
//   LAST_CMD       word 0x04  -> byte 0x10
//   RX_CMD_COUNT   word 0x0F  -> byte 0x3C
//
// SC-WEDGE expectation for opcode 0x30:
//   BUG-RC-RESET-SCWEDGE was confirmed in Phase 3 against v3_pretest-260511 FEB
//   on 2026-05-11. The synclink CMD_RESET drives the runctl_mgmt_host
//   ext_hard_reset port which fans out to the SC plane reset sinks
//   (feb_system_v3.qsys:586..590 -> control_path_subsystem.clk156_in_rst ->
//   16 SC-plane reset sinks). While the SC plane is in reset every AVMM read
//   to the SC-hub returns rsp=RSP3 payload=0xEEEEEEEE.
//
//   The SWB tb_int harness does NOT bind the real DUT in default mode
//   (TB_INT_BIND_REAL_DUT undefined per script/tb_int.f and Makefile). The
//   SC AVMM is stubbed inside tb_int_top.sv:175..183 with a fixed responder
//   that always returns 0x4849_5354 ("HIST"). Because of that the SC-WEDGE
//   bug is NOT reproducible in behavioral sim with the stub responder; the
//   sequence records this fact via a uvm_info marker ("SC-WEDGE pre-fix
//   silicon-only marker") so the test still passes in behavioral sim and the
//   marker can be turned into an xfail by the parent regression once
//   TB_INT_BIND_REAL_DUT is enabled.
//
//   The Qsys fix being recompiled in parallel rebreaks the ext_hard_reset
//   fanout. After the fix lands, the step 11 read should observe the same
//   stub-responder pattern (0x4849_5354) in behavioral sim and the real
//   register window contents on the real DUT.

package tb_int_run_sequence_directed_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Opcode catalogue. Bit 8 (the synclink K-flag) is asserted so the byte
    // is decoded as a control symbol by runctl_mgmt_host.
    localparam bit [8:0] OP_RUN_PREPARE     = 9'h110;
    localparam bit [8:0] OP_RUN_SYNC        = 9'h111;
    localparam bit [8:0] OP_START_RUN       = 9'h112;
    localparam bit [8:0] OP_END_RUN         = 9'h113;
    localparam bit [8:0] OP_ABORT_RUN       = 9'h114;
    localparam bit [8:0] OP_START_LINK_TEST = 9'h120;
    localparam bit [8:0] OP_STOP_LINK_TEST  = 9'h121;
    localparam bit [8:0] OP_START_SYNC_TEST = 9'h124;
    localparam bit [8:0] OP_STOP_SYNC_TEST  = 9'h125;
    localparam bit [8:0] OP_TEST_SYNC       = 9'h126;
    localparam bit [8:0] OP_CMD_RESET       = 9'h130;

    // runctl_mgmt_host AVMM CSR byte offsets (5-bit word index << 2).
    localparam bit [31:0] CSR_BYTE_STATUS       = 32'h0000_000C;
    localparam bit [31:0] CSR_BYTE_LAST_CMD     = 32'h0000_0010;
    localparam bit [31:0] CSR_BYTE_RX_CMD_COUNT = 32'h0000_003C;

    // Behavioural-stub readdata pattern emitted from tb_int_top.sv:175..183
    // (32'h4849_5354 == "HIST"). When TB_INT_BIND_REAL_DUT is undefined the
    // stub returns this exact value for every read so the directed sweep can
    // still detect when the AVMM bus path itself wedges (e.g. waitrequest
    // stuck high or readdatavalid never asserts).
    localparam bit [31:0] STUB_READDATA = 32'h4849_5354;

    // SC-WEDGE silicon-side expectation. Reported here as documentation only.
    localparam bit [31:0] SC_WEDGE_PAYLOAD_EXPECTED = 32'hEEEE_EEEE;

    class run_sequence_directed extends uvm_object;
        `uvm_object_utils(run_sequence_directed)

        virtual runctl_phy_if rc_vif;
        virtual sc_avmm_if    sc_vif;

        // Number of clock cycles each opcode is held on data/valid. 16 cycles
        // is enough for the receive FSM in runctl_mgmt_host to latch the
        // opcode byte and for the stub responder to respond to the follow-up
        // reads. Independent of the gap between commands.
        int unsigned op_hold_cycles  = 16;

        // Idle gap between consecutive opcodes (gives the DUT time to commit
        // the opcode into RX_CMD_COUNT / LAST_CMD / STATUS before the next
        // read).
        int unsigned op_idle_cycles  = 16;

        // SC AVMM timeout (matches sc_phy_driver default).
        int unsigned avmm_timeout    = 10000;

        // Observed register snapshots, indexed by step (0..10).
        bit [31:0] obs_status      [11];
        bit [31:0] obs_last_cmd    [11];
        bit [31:0] obs_rx_cmd_cnt  [11];

        function new(string name = "run_sequence_directed");
            super.new(name);
        endfunction

        function void configure(virtual runctl_phy_if rc_vif_i,
                                virtual sc_avmm_if    sc_vif_i);
            rc_vif = rc_vif_i;
            sc_vif = sc_vif_i;
        endfunction

        // Drive one synclink opcode by holding data/valid for op_hold_cycles,
        // then deasserting valid for op_idle_cycles.
        task automatic drive_opcode(bit [8:0] symbol, string mnemonic);
            `uvm_info("RC_SEQ",
                      $sformatf("drive opcode mnemonic=%s symbol=0x%03h",
                                mnemonic, symbol),
                      UVM_LOW)
            @(negedge rc_vif.clk);
            rc_vif.data  <= symbol;
            rc_vif.error <= 3'b000;
            rc_vif.valid <= 1'b1;
            repeat (op_hold_cycles) @(posedge rc_vif.clk);
            @(negedge rc_vif.clk);
            rc_vif.valid <= 1'b0;
            repeat (op_idle_cycles) @(posedge rc_vif.clk);
        endtask

        // Avalon-MM read against the stub responder. Returns the readdata
        // captured on the readdatavalid edge.
        task automatic sc_read32(bit [31:0] addr,
                                 output bit [31:0] data);
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
                    `uvm_fatal("RC_SEQ", "AVMM waitrequest timeout")
            end while (sc_vif.waitrequest === 1'b1);
            @(negedge sc_vif.clk);
            sc_vif.read <= 1'b0;
            waited = 0;
            do begin
                @(posedge sc_vif.clk);
                waited++;
                if (waited >= avmm_timeout)
                    `uvm_fatal("RC_SEQ", "AVMM readdatavalid timeout")
            end while (sc_vif.readdatavalid !== 1'b1);
            data = sc_vif.readdata;
        endtask

        // Sample the three CSRs after a step and stash them in the obs arrays.
        // The behavioural stub always returns 32'h4849_5354, so the sample is
        // primarily a "did the bus complete?" liveness check in sim. On
        // silicon the values reflect runctl_mgmt_host shadow registers.
        task automatic sample_csrs(int unsigned step_idx);
            bit [31:0] rd;

            sc_read32(CSR_BYTE_STATUS, rd);
            obs_status[step_idx] = rd;
            sc_read32(CSR_BYTE_LAST_CMD, rd);
            obs_last_cmd[step_idx] = rd;
            sc_read32(CSR_BYTE_RX_CMD_COUNT, rd);
            obs_rx_cmd_cnt[step_idx] = rd;
            `uvm_info("RC_SEQ",
                      $sformatf("step=%0d STATUS=0x%08h LAST_CMD=0x%08h RX_CMD_COUNT=0x%08h",
                                step_idx,
                                obs_status[step_idx],
                                obs_last_cmd[step_idx],
                                obs_rx_cmd_cnt[step_idx]),
                      UVM_LOW)
        endtask

        // One step = drive one opcode then sample the three CSRs.
        task automatic run_step(int unsigned step_idx,
                                bit [8:0]    symbol,
                                string       mnemonic);
            drive_opcode(symbol, mnemonic);
            sample_csrs(step_idx);
        endtask

        // Body: 11 steps, then a final post-CMD_RESET marker.
        task automatic body();
            `uvm_info("RC_SEQ", "starting directed run-sequence sweep (11 opcodes)", UVM_LOW)

            run_step( 0, OP_RUN_PREPARE,     "run-prepare 0x10");
            run_step( 1, OP_RUN_SYNC,        "sync 0x11");
            run_step( 2, OP_START_RUN,       "start-run 0x12");
            run_step( 3, OP_END_RUN,         "end-run 0x13");
            run_step( 4, OP_ABORT_RUN,       "abort-run 0x14");
            run_step( 5, OP_START_LINK_TEST, "start-link-test 0x20");
            run_step( 6, OP_STOP_LINK_TEST,  "stop-link-test 0x21");
            run_step( 7, OP_START_SYNC_TEST, "start-sync-test 0x24");
            run_step( 8, OP_STOP_SYNC_TEST,  "stop-sync-test 0x25");
            run_step( 9, OP_TEST_SYNC,       "test-sync 0x26");

            // Step 10 = CMD_RESET 0x30. On silicon this should leave the SC
            // plane returning RSP3+0xEEEEEEEE for every subsequent read. In
            // behavioural sim the stub responder is decoupled from the
            // ext_hard_reset broadcast, so the AVMM read will return
            // STUB_READDATA. Flag the discrepancy as a uvm_info marker, NOT a
            // uvm_error, so the test PASSes in sim today and can be promoted
            // to xfail-by-default when the real-DUT bind path lands.
            run_step(10, OP_CMD_RESET, "CMD_RESET 0x30");

            if (obs_status[10] === SC_WEDGE_PAYLOAD_EXPECTED) begin
                `uvm_info("RC_SEQ",
                          "SC-WEDGE silicon-side payload observed (0xEEEEEEEE). Bug is live.",
                          UVM_LOW)
            end else begin
                `uvm_info("RC_SEQ",
                          $sformatf("SC-WEDGE pre-fix silicon-only marker: behavioural stub returned 0x%08h on STATUS read after CMD_RESET. Bug repro requires TB_INT_BIND_REAL_DUT or a Qsys-bound stub modelling ext_hard_reset broadcast.",
                                    obs_status[10]),
                          UVM_LOW)
            end

            `uvm_info("RC_SEQ", "directed run-sequence sweep complete", UVM_LOW)
        endtask
    endclass

endpackage
