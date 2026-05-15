// runctl_mgmt_host.sv
// Run-Control Management Host: on-FPGA receiver and dispatcher for the Mu3e
// central run-control box.
//
//   - <synclink> AVST sink   (9b+3b, lvdspll_clk) : incoming 8b/1k command bytes
//   - <runctl>   AVST source (9b,    lvdspll_clk) : decoded fanout to agents
//   - <upload>   AVST source (36b,   lvdspll_clk) : RC ack packets (sop/eop)
//   - <csr>      AVMM  slave (5b word, 32b, mm_clk): expanded CSR block
//   - log FIFO   dcfifo_mixed_widths 128b x 32b    : 4-sub-word log entries
//   - dp_hard_reset, ct_hard_reset                  : local lvdspll_clk conduits
//   - ext_hard_reset                                : exported lvdspll_clk conduit
//
// Replaces legacy/runctl_mgmt_host_v24.vhd. The synclink / runctl / upload
// datapath semantics are preserved; the old single-endpoint <log> Avalon
// mailbox is replaced by a word-addressed CSR block with an identity header.
//
// Author  : Yifeng Wang (yifenwan@phys.ethz.ch)
// Version : 26.3.0
// Date    : 20260505
// Change  : 26.3.0 — make the runctl fanout stream readyless so decoded
//                     commands broadcast without downstream backpressure.
//           26.2.6 — make ext_hard_reset a bounded pulse so the exported
//                     subsystem reset cannot hold the LVDS/upload response
//                     path in reset until STOP_RESET.
//           26.2.5 — accept reset-protocol link-test and sync-test opcodes
//                     and fan them out as LINK_TEST/SYNC_TEST/IDLE states.
//           26.2.4 — decode synclink RUN_PREPARE payload bytes in the
//                     least-significant-byte-first order emitted by the SWB
//                     reset-link transmitter.
//           26.2.3 — process CMD_RESET / CMD_STOP_RESET as hard-reset conduit
//                     commands without run-control fanout backpressure. This
//                     avoids a reset-release deadlock when downstream runctl
//                     slaves are themselves held in the reset tree that the
//                     command is trying to release.
//           26.2.2 — initialize exported hard-reset conduits low at time zero
//                     so subsystem reset merges do not start from X before the
//                     lvdspll_reset domain becomes active in simulation.
//           26.2.1 — require a trained synclink K-idle/comma before accepting
//                     a command byte from RECV_IDLE. This blocks false startup
//                     commands during clean boot before the link has shown a
//                     stable post-train control symbol.
//           26.2.0 — align synclink CMD_RESET / CMD_STOP_RESET with the Mu3e
//                     SpecBook section 4.6.2 single-byte reset-distribution
//                     contract. payload_len_lut returns 0 for these opcodes
//                     (instead of 2); the recv FSM now transitions directly
//                     IDLE -> LOGGING on the opcode byte with no per-packet
//                     mask fields. The local_cmd path still accepts an
//                     optional assert/release mask via CSR_LOCAL_CMD for
//                     software-driven per-channel reset selection.
//           26.1.0 — Added ext_hard_reset reset-source conduit for external
//                     subsystems. RESET/STOP_RESET drive local dp/ct resets
//                     plus an exported subsystem-level hard reset, while
//                     preserving CSR and synclink/runctl/upload behavior.

`timescale 1 ps / 1 ps

module runctl_mgmt_host #(
    // Upload ack symbol parameters (8b/1k k-codes)
    parameter logic [7:0]  RUN_START_ACK_SYMBOL = 8'hFE, // K30.7
    parameter logic [7:0]  RUN_END_ACK_SYMBOL   = 8'hFD, // K29.7
    parameter int          DEBUG                = 1,
    // Identity header (integration-overridable)
    parameter logic [31:0] IP_UID         = 32'h5243_4D48, // ASCII "RCMH"
    parameter logic [7:0]  VERSION_MAJOR  = 8'd26,
    parameter logic [7:0]  VERSION_MINOR  = 8'd3,
    parameter logic [3:0]  VERSION_PATCH  = 4'd0,
    parameter logic [11:0] BUILD          = 12'h505,     // MMDD = 0505
    parameter logic [31:0] VERSION_DATE   = 32'h2026_0505,
    parameter logic [31:0] VERSION_GIT    = 32'h0,
    parameter logic [31:0] INSTANCE_ID    = 32'h0,
    parameter logic [15:0] EXT_HARD_RESET_PULSE_CYCLES = 16'd16384
)(
    // <synclink> AVST sink (lvdspll_clk) — passive byte stream
    input  logic [8:0]  asi_synclink_data,   // {k, data[7:0]}
    input  logic [2:0]  asi_synclink_error,  // {loss_sync, parity, decode}

    // <upload> AVST source (lvdspll_clk)
    output logic [35:0] aso_upload_data,
    output logic        aso_upload_valid,
    input  logic        aso_upload_ready,
    output logic        aso_upload_startofpacket,
    output logic        aso_upload_endofpacket,

    // <runctl> AVST source (lvdspll_clk), readyless broadcast
    output logic        aso_runctl_valid,
    output logic [8:0]  aso_runctl_data,

    // <csr> AVMM slave (mm_clk) — 5-bit word address
    input  logic [4:0]  avs_csr_address,
    input  logic        avs_csr_read,
    output logic [31:0] avs_csr_readdata,
    input  logic        avs_csr_write,
    input  logic [31:0] avs_csr_writedata,
    output logic        avs_csr_waitrequest,

    // Hard reset conduits (lvdspll_clk)
    output logic        dp_hard_reset,
    output logic        ct_hard_reset,
    output logic        ext_hard_reset,

    // Clocks and resets
    input  logic        mm_clk,
    input  logic        mm_reset,
    input  logic        lvdspll_clk,
    input  logic        lvdspll_reset
);

    // ============================================================
    // Command byte constants
    // ============================================================
    localparam logic [7:0] CMD_RUN_PREPARE = 8'h10;
    localparam logic [7:0] CMD_RUN_SYNC    = 8'h11;
    localparam logic [7:0] CMD_START_RUN   = 8'h12;
    localparam logic [7:0] CMD_END_RUN     = 8'h13;
    localparam logic [7:0] CMD_ABORT_RUN   = 8'h14;
    localparam logic [7:0] CMD_START_LINK_TEST = 8'h20;
    localparam logic [7:0] CMD_STOP_LINK_TEST  = 8'h21;
    localparam logic [7:0] CMD_START_SYNC_TEST = 8'h24;
    localparam logic [7:0] CMD_STOP_SYNC_TEST  = 8'h25;
    localparam logic [7:0] CMD_TEST_SYNC       = 8'h26;
    localparam logic [7:0] CMD_RESET       = 8'h30;
    localparam logic [7:0] CMD_STOP_RESET  = 8'h31;
    localparam logic [7:0] CMD_ENABLE      = 8'h32;
    localparam logic [7:0] CMD_DISABLE     = 8'h33;
    localparam logic [7:0] CMD_ADDRESS     = 8'h40;

    // ============================================================
    // CSR word addresses
    // ============================================================
    localparam logic [4:0] CSR_UID          = 5'h00;
    localparam logic [4:0] CSR_META         = 5'h01;
    localparam logic [4:0] CSR_CONTROL      = 5'h02;
    localparam logic [4:0] CSR_STATUS       = 5'h03;
    localparam logic [4:0] CSR_LAST_CMD     = 5'h04;
    localparam logic [4:0] CSR_SCRATCH      = 5'h05;
    localparam logic [4:0] CSR_RUN_NUMBER   = 5'h06;
    localparam logic [4:0] CSR_RESET_MASK   = 5'h07;
    localparam logic [4:0] CSR_FPGA_ADDRESS = 5'h08;
    localparam logic [4:0] CSR_RECV_TS_L    = 5'h09;
    localparam logic [4:0] CSR_RECV_TS_H    = 5'h0A;
    localparam logic [4:0] CSR_EXEC_TS_L    = 5'h0B;
    localparam logic [4:0] CSR_EXEC_TS_H    = 5'h0C;
    localparam logic [4:0] CSR_GTS_L        = 5'h0D;
    localparam logic [4:0] CSR_GTS_H        = 5'h0E;
    localparam logic [4:0] CSR_RX_CMD_COUNT = 5'h0F;
    localparam logic [4:0] CSR_RX_ERR_COUNT = 5'h10;
    localparam logic [4:0] CSR_LOG_STATUS   = 5'h11;
    localparam logic [4:0] CSR_LOG_POP      = 5'h12;
    localparam logic [4:0] CSR_LOCAL_CMD    = 5'h13;
    localparam logic [4:0] CSR_ACK_SYMBOLS  = 5'h14;

    // ============================================================
    // FSM state encodings (8-bit, exposed via STATUS)
    // ============================================================
    localparam logic [7:0] RECV_IDLE       = 8'h00;
    localparam logic [7:0] RECV_RX_PAYLOAD = 8'h01;
    localparam logic [7:0] RECV_LOGGING    = 8'h02;
    localparam logic [7:0] RECV_LOG_ERROR  = 8'h03;
    localparam logic [7:0] RECV_CLEANUP    = 8'h04;

    localparam logic [7:0] HOST_IDLE_ST    = 8'h00;
    localparam logic [7:0] HOST_POSTING    = 8'h01;
    localparam logic [7:0] HOST_CLEANUP    = 8'h02;

    localparam logic [7:0] UPL_IDLE        = 8'h00;
    localparam logic [7:0] UPL_SEND        = 8'h01;

    localparam logic [8:0] SYNCLINK_IDLE_COMMA = 9'h1BC;

    // ============================================================
    // Forward signal declarations
    // ============================================================
    // lvds domain status → mm (individual-bit 2FF)
    logic        recv_idle_lvds, host_idle_lvds;
    logic [7:0]  recv_state_lvds, host_state_lvds;
    logic        dp_hard_reset_raw, ct_hard_reset_raw;
    logic        log_fifo_wrempty;

    // mm domain status shadows
    logic [1:0]  recv_idle_sync, host_idle_sync;
    logic [1:0]  dp_hreset_sync, ct_hreset_sync;
    logic [15:0] recv_state_sync_q0, recv_state_sync_q1;
    logic [15:0] host_state_sync_q0, host_state_sync_q1;

    // host FSM forward declarations (used by recv FSM's log-write path)
    logic [47:0] host_exec_ts;
    logic [31:0] host_exec_ts_lo;
    assign host_exec_ts_lo = host_exec_ts[31:0];

    // ============================================================
    // GTS counter (lvdspll_clk)
    // ============================================================
    logic [47:0] gts_counter;
    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset)
            gts_counter <= 48'd0;
        else
            gts_counter <= gts_counter + 48'd1;
    end

    // ============================================================
    // GTS 48-bit gray-code CDC (lvdspll_clk → mm_clk)
    // ============================================================
    // Binary-to-gray on source, 2FF sync, gray-to-binary on dest.
    logic [47:0] gts_gray_lvds;
    logic [47:0] gts_gray_mm_ff0, gts_gray_mm_ff1;
    logic [47:0] gts_mm_binary;

    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset)
            gts_gray_lvds <= 48'd0;
        else
            gts_gray_lvds <= (gts_counter >> 1) ^ gts_counter;
    end

    always_ff @(posedge mm_clk) begin
        if (mm_reset) begin
            gts_gray_mm_ff0 <= 48'd0;
            gts_gray_mm_ff1 <= 48'd0;
        end else begin
            gts_gray_mm_ff0 <= gts_gray_lvds;
            gts_gray_mm_ff1 <= gts_gray_mm_ff0;
        end
    end

    // gray → binary: b[i] = ^g[47:i]
    always_comb begin
        gts_mm_binary[47] = gts_gray_mm_ff1[47];
        for (int i = 46; i >= 0; i--)
            gts_mm_binary[i] = gts_mm_binary[i+1] ^ gts_gray_mm_ff1[i];
    end

    // ============================================================
    // Soft-reset toggle CDC (mm → lvds)
    // ============================================================
    logic        soft_reset_req_mm;    // toggle
    logic [1:0]  soft_reset_req_lvds_sync;
    logic        soft_reset_req_lvds_seen;
    logic        soft_reset_pulse_lvds;

    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset) begin
            soft_reset_req_lvds_sync <= 2'b00;
            soft_reset_req_lvds_seen <= 1'b0;
            soft_reset_pulse_lvds    <= 1'b0;
        end else begin
            soft_reset_req_lvds_sync <= {soft_reset_req_lvds_sync[0], soft_reset_req_mm};
            soft_reset_pulse_lvds    <= 1'b0;
            if (soft_reset_req_lvds_sync[1] != soft_reset_req_lvds_seen) begin
                soft_reset_req_lvds_seen <= soft_reset_req_lvds_sync[1];
                soft_reset_pulse_lvds    <= 1'b1;
            end
        end
    end

    // lvds-side aggregate reset for FSMs: hard reset or soft reset pulse
    logic lvds_fsm_rst;
    assign lvds_fsm_rst = lvdspll_reset | soft_reset_pulse_lvds;

    // ============================================================
    // CONTROL mask bits CDC (mm → lvds), direct 2FF (near-static)
    // ============================================================
    logic       rst_mask_dp_mm, rst_mask_ct_mm;
    logic [1:0] rst_mask_dp_lvds_sync, rst_mask_ct_lvds_sync;
    logic       rst_mask_dp_lvds, rst_mask_ct_lvds;

    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset) begin
            rst_mask_dp_lvds_sync <= 2'b00;
            rst_mask_ct_lvds_sync <= 2'b00;
        end else begin
            rst_mask_dp_lvds_sync <= {rst_mask_dp_lvds_sync[0], rst_mask_dp_mm};
            rst_mask_ct_lvds_sync <= {rst_mask_ct_lvds_sync[0], rst_mask_ct_mm};
        end
    end
    assign rst_mask_dp_lvds = rst_mask_dp_lvds_sync[1];
    assign rst_mask_ct_lvds = rst_mask_ct_lvds_sync[1];

    // ============================================================
    // local_cmd toggle-handshake CDC (mm → lvds)
    // ============================================================
    logic [31:0] local_cmd_word_mm;
    logic        local_cmd_req_mm;             // toggle
    logic [1:0]  local_cmd_ack_mm_sync;
    logic        local_cmd_busy_mm;

    logic [1:0]  local_cmd_req_lvds_sync;
    logic        local_cmd_req_lvds_seen;
    logic        local_cmd_ack_lvds;           // toggle
    logic [31:0] local_cmd_word_lvds_sync_q0, local_cmd_word_lvds_sync_q1;
    logic        local_cmd_pending_lvds;
    logic        local_cmd_consume_lvds;
    logic [31:0] local_cmd_word_lvds;

    assign local_cmd_busy_mm = local_cmd_req_mm ^ local_cmd_ack_mm_sync[1];

    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset) begin
            local_cmd_req_lvds_sync     <= 2'b00;
            local_cmd_req_lvds_seen     <= 1'b0;
            local_cmd_ack_lvds          <= 1'b0;
            local_cmd_pending_lvds      <= 1'b0;
            local_cmd_word_lvds         <= 32'd0;
            local_cmd_word_lvds_sync_q0 <= 32'd0;
            local_cmd_word_lvds_sync_q1 <= 32'd0;
        end else begin
            local_cmd_req_lvds_sync     <= {local_cmd_req_lvds_sync[0], local_cmd_req_mm};
            local_cmd_word_lvds_sync_q0 <= local_cmd_word_mm;
            local_cmd_word_lvds_sync_q1 <= local_cmd_word_lvds_sync_q0;

            if (local_cmd_consume_lvds) begin
                local_cmd_pending_lvds <= 1'b0;
                local_cmd_ack_lvds     <= ~local_cmd_ack_lvds;
            end
            if (local_cmd_req_lvds_sync[1] != local_cmd_req_lvds_seen) begin
                local_cmd_req_lvds_seen <= local_cmd_req_lvds_sync[1];
                local_cmd_word_lvds     <= local_cmd_word_lvds_sync_q1;
                local_cmd_pending_lvds  <= 1'b1;
            end
        end
    end

    always_ff @(posedge mm_clk) begin
        if (mm_reset)
            local_cmd_ack_mm_sync <= 2'b00;
        else
            local_cmd_ack_mm_sync <= {local_cmd_ack_mm_sync[0], local_cmd_ack_lvds};
    end

    // ============================================================
    // Payload length decode
    // ============================================================
    // Mu3e SpecBook §4.6.2 "Run Start Sequence": only RUN_PREPARE carries a
    // payload (run_number) on the reset-distribution wire. SYNC / START / STOP
    // and RESET / STOP_RESET are single-byte signals. CMD_ADDRESS is a local
    // extension for per-FEB address assignment (kept as 2-byte payload).
    function automatic logic [3:0] payload_len_lut (input logic [7:0] cmd);
        case (cmd)
            CMD_RUN_PREPARE: payload_len_lut = 4'd4;
            CMD_ADDRESS:     payload_len_lut = 4'd2;
            CMD_RESET,
            CMD_STOP_RESET,
            CMD_RUN_SYNC,
            CMD_START_RUN,
            CMD_END_RUN,
            CMD_ABORT_RUN,
            CMD_START_LINK_TEST,
            CMD_STOP_LINK_TEST,
            CMD_START_SYNC_TEST,
            CMD_STOP_SYNC_TEST,
            CMD_TEST_SYNC,
            CMD_ENABLE,
            CMD_DISABLE:     payload_len_lut = 4'd0;
            default:         payload_len_lut = 4'd15; // 0xF = unknown marker
        endcase
    endfunction

    function automatic logic cmd_is_known (input logic [7:0] cmd);
        case (cmd)
            CMD_RUN_PREPARE, CMD_RUN_SYNC, CMD_START_RUN, CMD_END_RUN,
            CMD_ABORT_RUN, CMD_START_LINK_TEST, CMD_STOP_LINK_TEST,
            CMD_START_SYNC_TEST, CMD_STOP_SYNC_TEST, CMD_TEST_SYNC,
            CMD_RESET, CMD_STOP_RESET, CMD_ENABLE, CMD_DISABLE,
            CMD_ADDRESS: cmd_is_known = 1'b1;
            default:                  cmd_is_known = 1'b0;
        endcase
    endfunction

    // Map command byte → runctl AVST 9-bit one-hot (fanout code)
    function automatic logic [8:0] dec_runcmd (input logic [7:0] cmd);
        case (cmd)
            CMD_RUN_PREPARE:     dec_runcmd = 9'b000000010;
            CMD_RUN_SYNC:        dec_runcmd = 9'b000000100;
            CMD_START_RUN:       dec_runcmd = 9'b000001000;
            CMD_END_RUN:         dec_runcmd = 9'b000010000;
            CMD_ABORT_RUN:       dec_runcmd = 9'b000000001;
            CMD_START_LINK_TEST: dec_runcmd = 9'b000100000;
            CMD_STOP_LINK_TEST:  dec_runcmd = 9'b000000001;
            CMD_START_SYNC_TEST: dec_runcmd = 9'b001000000;
            CMD_TEST_SYNC:       dec_runcmd = 9'b001000000;
            CMD_STOP_SYNC_TEST:  dec_runcmd = 9'b000000001;
            CMD_RESET:           dec_runcmd = 9'b010000000;
            CMD_STOP_RESET:      dec_runcmd = 9'b000000001;
            CMD_ENABLE:          dec_runcmd = 9'b000000001;
            CMD_DISABLE:         dec_runcmd = 9'b100000000;
            default:             dec_runcmd = 9'b000000001;
        endcase
    endfunction

    function automatic logic cmd_requires_fanout (input logic [7:0] cmd);
        case (cmd)
            CMD_RUN_PREPARE,
            CMD_RUN_SYNC,
            CMD_START_RUN,
            CMD_END_RUN,
            CMD_ABORT_RUN,
            CMD_START_LINK_TEST,
            CMD_STOP_LINK_TEST,
            CMD_START_SYNC_TEST,
            CMD_STOP_SYNC_TEST,
            CMD_TEST_SYNC,
            CMD_ENABLE,
            CMD_DISABLE:
                cmd_requires_fanout = 1'b1;
            default:
                cmd_requires_fanout = 1'b0;
        endcase
    endfunction

    function automatic logic [31:0] payload32_set_byte_le (
        input logic [31:0] payload,
        input logic [3:0]  byte_index,
        input logic [7:0]  byte_value
    );
        logic [31:0] payload_next;
        begin
            payload_next = payload;
            unique case (byte_index)
                4'd0: payload_next[7:0]   = byte_value;
                4'd1: payload_next[15:8]  = byte_value;
                4'd2: payload_next[23:16] = byte_value;
                4'd3: payload_next[31:24] = byte_value;
                default: ;
            endcase
            return payload_next;
        end
    endfunction

    // ============================================================
    // synclink_recv FSM (lvdspll_clk)
    // ============================================================
    logic [7:0]  recv_state, recv_state_nxt;
    logic [7:0]  recv_run_command;
    logic [47:0] recv_timestamp;
    logic [31:0] recv_run_number;
    logic [15:0] recv_reset_assert_mask;
    logic [15:0] recv_reset_release_mask;
    logic [15:0] recv_fpga_address;
    logic [31:0] recv_payload32;
    logic [3:0]  recv_payload_len;
    logic [3:0]  recv_payload_cnt;
    logic        synclink_idle_armed;

    // recv→host start/done pipe
    logic        pipe_r2h_start, pipe_r2h_done;

    // Snapshot update toggle (lvds→mm notification)
    logic        snap_update_lvds;     // toggle
    logic [1:0]  snap_update_mm_sync;
    logic        snap_update_mm_seen;

    // Saturating event strobes
    logic        ev_cmd_accepted;
    logic        ev_rx_error;
    logic        ev_log_drop;

    // log FIFO write-side signals
    logic         log_fifo_wrreq;
    logic [127:0] log_fifo_data;
    logic         log_fifo_wrfull;
    logic [7:0]   log_fifo_wrusedw;

    always_ff @(posedge lvdspll_clk) begin
        if (lvds_fsm_rst) begin
            recv_state              <= RECV_IDLE;
            recv_run_command        <= 8'h00;
            recv_timestamp          <= 48'd0;
            recv_run_number         <= 32'd0;
            recv_reset_assert_mask  <= 16'h0000;
            recv_reset_release_mask <= 16'h0000;
            recv_fpga_address       <= 16'h0000;
            recv_payload32          <= 32'd0;
            recv_payload_len        <= 4'd0;
            recv_payload_cnt        <= 4'd0;
            synclink_idle_armed     <= 1'b0;
            pipe_r2h_start          <= 1'b0;
            snap_update_lvds        <= 1'b0;
            local_cmd_consume_lvds  <= 1'b0;
            log_fifo_wrreq          <= 1'b0;
            log_fifo_data           <= 128'd0;
            ev_cmd_accepted         <= 1'b0;
            ev_rx_error             <= 1'b0;
            ev_log_drop             <= 1'b0;
            // Note: lvdspll_reset (not lvds_fsm_rst) also clears recv_*, but
            // soft_reset should also clear them — so the reset branch here
            // handles both.
        end else begin
            log_fifo_wrreq         <= 1'b0;
            log_fifo_data          <= 128'd0;
            local_cmd_consume_lvds <= 1'b0;
            ev_cmd_accepted        <= 1'b0;
            ev_rx_error            <= 1'b0;
            ev_log_drop            <= 1'b0;

            case (recv_state)
                RECV_IDLE: begin
                    // Priority 1: local_cmd injection (complete word in one shot)
                    if (local_cmd_pending_lvds) begin
                        local_cmd_consume_lvds <= 1'b1;
                        synclink_idle_armed    <= 1'b0;
                        recv_run_command       <= local_cmd_word_lvds[7:0];
                        recv_timestamp         <= gts_counter;
                        recv_payload_len       <= payload_len_lut(local_cmd_word_lvds[7:0]);
                        recv_payload_cnt       <= 4'd0;
                        // Extract the meaningful payload bits from the upper 24b.
                        unique case (local_cmd_word_lvds[7:0])
                            CMD_RUN_PREPARE: begin
                                recv_payload32  <= {8'h00, local_cmd_word_lvds[31:8]};
                                recv_run_number <= {8'h00, local_cmd_word_lvds[31:8]};
                            end
                            CMD_RESET: begin
                                recv_payload32         <= {16'h0000, local_cmd_word_lvds[23:8]};
                                recv_reset_assert_mask <= local_cmd_word_lvds[23:8];
                            end
                            CMD_STOP_RESET: begin
                                recv_payload32          <= {16'h0000, local_cmd_word_lvds[23:8]};
                                recv_reset_release_mask <= local_cmd_word_lvds[23:8];
                            end
                            CMD_ADDRESS: begin
                                recv_payload32    <= {16'h0000, local_cmd_word_lvds[23:8]};
                                recv_fpga_address <= local_cmd_word_lvds[23:8];
                            end
                            default: recv_payload32 <= 32'd0;
                        endcase
                        if (cmd_is_known(local_cmd_word_lvds[7:0]))
                            recv_state <= RECV_LOGGING;
                        else
                            recv_state <= RECV_CLEANUP;
                    end
                    // Priority 2: synclink byte, link trained
                    else if (asi_synclink_error[2] == 1'b1) begin
                        synclink_idle_armed <= 1'b0;
                    end
                    else if (asi_synclink_error[2] == 1'b0) begin
                        if (asi_synclink_error[1:0] != 2'b00) begin
                            recv_state  <= RECV_LOG_ERROR;
                            ev_rx_error <= 1'b1;
                            synclink_idle_armed <= 1'b0;
                        end else if (asi_synclink_data[8] == 1'b1) begin
                            if (asi_synclink_data == SYNCLINK_IDLE_COMMA)
                                synclink_idle_armed <= 1'b1;
                        end else if (synclink_idle_armed) begin
                            synclink_idle_armed    <= 1'b0;
                            recv_run_command        <= asi_synclink_data[7:0];
                            recv_timestamp          <= gts_counter;
                            recv_payload_len        <= payload_len_lut(asi_synclink_data[7:0]);
                            recv_payload_cnt        <= 4'd0;
                            recv_payload32          <= 32'd0;
                            // Spec-aligned broadcast masks for single-byte
                            // CMD_RESET / CMD_STOP_RESET arriving via synclink.
                            // The per-channel mask gating is still done in the
                            // hard-reset generator against CSR rst_mask_dp/ct.
                            if (asi_synclink_data[7:0] == CMD_RESET)
                                recv_reset_assert_mask  <= 16'hFFFF;
                            if (asi_synclink_data[7:0] == CMD_STOP_RESET)
                                recv_reset_release_mask <= 16'hFFFF;
                            if (!cmd_is_known(asi_synclink_data[7:0])) begin
                                // Unknown byte: drop silently, return to IDLE.
                                recv_state <= RECV_CLEANUP;
                            end else if (payload_len_lut(asi_synclink_data[7:0]) == 4'd0) begin
                                recv_state <= RECV_LOGGING;
                            end else begin
                                recv_state <= RECV_RX_PAYLOAD;
                            end
                        end
                    end
                end

                RECV_RX_PAYLOAD: begin
                    if (asi_synclink_error[2]) begin
                        synclink_idle_armed <= 1'b0;
                        recv_state  <= RECV_LOG_ERROR;
                        ev_rx_error <= 1'b1;
                    end else if (asi_synclink_error[1:0] != 2'b00) begin
                        synclink_idle_armed <= 1'b0;
                        recv_state  <= RECV_LOG_ERROR;
                        ev_rx_error <= 1'b1;
                    end else if (asi_synclink_data[8] == 1'b0) begin
                        // SWB a10_reset_link sends RUN_PREPARE run-number
                        // bytes least-significant first. Keep payload32 in the
                        // resolved integer order as bytes arrive.
                        recv_payload32 <= payload32_set_byte_le(recv_payload32,
                                                                 recv_payload_cnt,
                                                                 asi_synclink_data[7:0]);
                        recv_payload_cnt <= recv_payload_cnt + 4'd1;
                        if (recv_payload_cnt + 4'd1 >= recv_payload_len) begin
                            // Latch destination snapshot field
                            unique case (recv_run_command)
                                CMD_RUN_PREPARE: begin
                                    recv_run_number <= payload32_set_byte_le(
                                        recv_payload32,
                                        recv_payload_cnt,
                                        asi_synclink_data[7:0]);
                                end
                                CMD_RESET: begin
                                    recv_reset_assert_mask <=
                                        {recv_payload32[7:0], asi_synclink_data[7:0]};
                                end
                                CMD_STOP_RESET: begin
                                    recv_reset_release_mask <=
                                        {recv_payload32[7:0], asi_synclink_data[7:0]};
                                end
                                CMD_ADDRESS: begin
                                    recv_fpga_address <=
                                        {recv_payload32[7:0], asi_synclink_data[7:0]};
                                end
                                default: ;
                            endcase
                            recv_state <= RECV_LOGGING;
                        end
                    end
                end

                RECV_LOGGING: begin
                    // Handshake with runctl_host (except CMD_ADDRESS which
                    // does not fan out and is masked directly to CLEANUP).
                    if (recv_run_command == CMD_ADDRESS) begin
                        pipe_r2h_start   <= 1'b0;
                        snap_update_lvds <= ~snap_update_lvds;
                        ev_cmd_accepted  <= 1'b1;
                        recv_state       <= RECV_CLEANUP;
                    end else if (!pipe_r2h_start && !pipe_r2h_done) begin
                        pipe_r2h_start <= 1'b1;
                    end else if (pipe_r2h_start && pipe_r2h_done) begin
                        pipe_r2h_start <= 1'b0;
                        // Write log entry:
                        //   [127:80] = recv_ts[47:0]
                        //   [79:72]  = run_command[7:0]
                        //   [71:64]  = reserved (0)
                        //   [63:32]  = payload32 (run_number / masks / address)
                        //   [31:0]   = exec_ts[31:0]
                        if (!log_fifo_wrfull) begin
                            log_fifo_wrreq <= 1'b1;
                            log_fifo_data  <= {
                                recv_timestamp,                // [127:80]
                                recv_run_command,              // [79:72]
                                8'h00,                         // [71:64] reserved
                                host_exec_payload32_display(), // [63:32] payload snapshot
                                host_exec_ts_lo                // [31:0]  exec_ts[31:0]
                            };
                        end else begin
                            ev_log_drop <= 1'b1;
                        end
                        snap_update_lvds <= ~snap_update_lvds;
                        ev_cmd_accepted  <= 1'b1;
                        recv_state       <= RECV_CLEANUP;
                    end
                end

                RECV_LOG_ERROR: begin
                    recv_state <= RECV_CLEANUP;
                end

                RECV_CLEANUP: begin
                    recv_payload_cnt <= 4'd0;
                    recv_state       <= RECV_IDLE;
                end

                default: recv_state <= RECV_IDLE;
            endcase
        end
    end

    // NOTE: host_exec_payload32_display / host_exec_ts_lo are forward
    // declared below; they are plain combinational aliases of the recv
    // snapshot fields and the host-side exec_ts capture.
    function automatic logic [31:0] host_exec_payload32_display();
        // Encode payload32 field of log entry. For RUN_PREPARE use run_number
        // so downstream software sees the resolved 32-bit run number; for
        // other commands pass through payload32 directly.
        case (recv_run_command)
            CMD_RUN_PREPARE: host_exec_payload32_display = recv_run_number;
            CMD_RESET:       host_exec_payload32_display = {16'h0000, recv_reset_assert_mask};
            CMD_STOP_RESET:  host_exec_payload32_display = {16'h0000, recv_reset_release_mask};
            CMD_ADDRESS:     host_exec_payload32_display = {16'h0000, recv_fpga_address};
            default:         host_exec_payload32_display = recv_payload32;
        endcase
    endfunction

    // ============================================================
    // runctl_host FSM (lvdspll_clk)
    // ============================================================
    logic [7:0]  host_state;

    always_ff @(posedge lvdspll_clk) begin
        if (lvds_fsm_rst) begin
            host_state       <= HOST_IDLE_ST;
            aso_runctl_valid <= 1'b0;
            aso_runctl_data  <= 9'd0;
            pipe_r2h_done    <= 1'b0;
            host_exec_ts     <= 48'd0;
        end else begin
            case (host_state)
                HOST_IDLE_ST: begin
                    if (pipe_r2h_start && !pipe_r2h_done) begin
                        if (cmd_requires_fanout(recv_run_command)) begin
                            host_state       <= HOST_POSTING;
                            aso_runctl_valid <= 1'b1;
                            aso_runctl_data  <= dec_runcmd(recv_run_command);
                        end else begin
                            aso_runctl_valid <= 1'b0;
                            host_exec_ts     <= gts_counter;
                            pipe_r2h_done    <= 1'b1;
                            host_state       <= HOST_CLEANUP;
                        end
                    end
                end
                HOST_POSTING: begin
                    aso_runctl_valid    <= 1'b0;
                    host_exec_ts        <= gts_counter;
                    pipe_r2h_done       <= 1'b1;
                    host_state          <= HOST_CLEANUP;
                end
                HOST_CLEANUP: begin
                    if (!pipe_r2h_start) begin
                        pipe_r2h_done <= 1'b0;
                        host_state    <= HOST_IDLE_ST;
                    end
                end
                default: host_state <= HOST_IDLE_ST;
            endcase
        end
    end

    // STATUS helpers
    assign recv_idle_lvds  = (recv_state == RECV_IDLE);
    assign host_idle_lvds  = (host_state == HOST_IDLE_ST);
    assign recv_state_lvds = recv_state;
    assign host_state_lvds = host_state;

    // ============================================================
    // rc_pkt_upload FSM (lvdspll_clk)
    // ============================================================
    logic [7:0] upload_state;

    always_ff @(posedge lvdspll_clk) begin
        if (lvds_fsm_rst) begin
            upload_state             <= UPL_IDLE;
            aso_upload_data          <= 36'd0;
            aso_upload_valid         <= 1'b0;
            aso_upload_startofpacket <= 1'b0;
            aso_upload_endofpacket   <= 1'b0;
        end else begin
            case (upload_state)
                UPL_IDLE: begin
                    aso_upload_valid         <= 1'b0;
                    aso_upload_startofpacket <= 1'b0;
                    aso_upload_endofpacket   <= 1'b0;
                    // Trigger when host finished and the command requires an ack.
                    if (pipe_r2h_done &&
                        (recv_run_command == CMD_RUN_PREPARE ||
                         recv_run_command == CMD_END_RUN)) begin
                        aso_upload_data[35:32] <= 4'b0001;
                        if (recv_run_command == CMD_RUN_PREPARE) begin
                            aso_upload_data[31:8] <= recv_run_number[23:0];
                            aso_upload_data[7:0]  <= RUN_START_ACK_SYMBOL;
                        end else begin
                            aso_upload_data[31:8] <= 24'h000000;
                            aso_upload_data[7:0]  <= RUN_END_ACK_SYMBOL;
                        end
                        aso_upload_valid         <= 1'b1;
                        aso_upload_startofpacket <= 1'b1;
                        aso_upload_endofpacket   <= 1'b1;
                        upload_state             <= UPL_SEND;
                    end
                end
                UPL_SEND: begin
                    if (aso_upload_valid && aso_upload_ready) begin
                        aso_upload_valid         <= 1'b0;
                        aso_upload_startofpacket <= 1'b0;
                        aso_upload_endofpacket   <= 1'b0;
                        upload_state             <= UPL_IDLE;
                    end
                end
                default: upload_state <= UPL_IDLE;
            endcase
        end
    end

    // ============================================================
    // Hard-reset generator (lvdspll_clk)
    // ============================================================
    logic dp_hard_reset_q  = 1'b0;
    logic ct_hard_reset_q  = 1'b0;
    logic ext_hard_reset_q = 1'b0;
    logic [15:0] ext_hard_reset_count = 16'd0;

    always @(posedge lvdspll_clk) begin
        if (lvdspll_reset) begin
            dp_hard_reset_q         <= 1'b0;
            ct_hard_reset_q         <= 1'b0;
            ext_hard_reset_q        <= 1'b0;
            ext_hard_reset_count    <= 16'd0;
        end else begin
            // Trigger on the cycle a command has been fully latched and is
            // about to be logged — gate on recv_state transitioning into
            // LOGGING. For this simple implementation, assert/deassert when
            // the host completes the command fan-out (pipe_r2h_done rising).
            if (pipe_r2h_done) begin
                if (recv_run_command == CMD_RESET) begin
                    if (!rst_mask_dp_lvds)
                        dp_hard_reset_q <= 1'b1;
                    if (!rst_mask_ct_lvds)
                        ct_hard_reset_q <= 1'b1;
                    ext_hard_reset_q        <= 1'b1;
                    ext_hard_reset_count    <= EXT_HARD_RESET_PULSE_CYCLES - 16'd1;
                end else if (recv_run_command == CMD_STOP_RESET) begin
                    if (!rst_mask_dp_lvds)
                        dp_hard_reset_q <= 1'b0;
                    if (!rst_mask_ct_lvds)
                        ct_hard_reset_q <= 1'b0;
                    ext_hard_reset_q        <= 1'b0;
                    ext_hard_reset_count    <= 16'd0;
                end
            end else if (ext_hard_reset_q) begin
                if (ext_hard_reset_count == 16'd0)
                    ext_hard_reset_q    <= 1'b0;
                else
                    ext_hard_reset_count <= ext_hard_reset_count - 16'd1;
            end
        end
    end
    assign dp_hard_reset      = dp_hard_reset_q;
    assign ct_hard_reset      = ct_hard_reset_q;
    assign ext_hard_reset     = ext_hard_reset_q;
    assign dp_hard_reset_raw  = dp_hard_reset_q;
    assign ct_hard_reset_raw  = ct_hard_reset_q;

    // ============================================================
    // Snapshot register bank (lvds) & handshake to mm
    // ============================================================
    // Mirror of the "interesting" fields captured by the recv FSM. These are
    // held stable between snap_update toggles so the mm-side shadow latch is
    // safe despite multi-bit CDC.
    logic [7:0]  snap_last_cmd_lvds;
    logic [31:0] snap_run_number_lvds;
    logic [15:0] snap_reset_assert_lvds, snap_reset_release_lvds;
    logic [15:0] snap_fpga_addr_lvds;
    logic        snap_fpga_addr_valid_lvds;
    logic [47:0] snap_recv_ts_lvds;
    logic [47:0] snap_exec_ts_lvds;

    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset) begin
            snap_last_cmd_lvds        <= 8'h00;
            snap_run_number_lvds      <= 32'd0;
            snap_reset_assert_lvds    <= 16'd0;
            snap_reset_release_lvds   <= 16'd0;
            snap_fpga_addr_lvds       <= 16'd0;
            snap_fpga_addr_valid_lvds <= 1'b0;
            snap_recv_ts_lvds         <= 48'd0;
            snap_exec_ts_lvds         <= 48'd0;
        end else if (ev_cmd_accepted) begin
            snap_last_cmd_lvds      <= recv_run_command;
            snap_recv_ts_lvds       <= recv_timestamp;
            snap_exec_ts_lvds       <= host_exec_ts;
            unique case (recv_run_command)
                CMD_RUN_PREPARE: snap_run_number_lvds    <= recv_run_number;
                CMD_RESET:       snap_reset_assert_lvds  <= recv_reset_assert_mask;
                CMD_STOP_RESET:  snap_reset_release_lvds <= recv_reset_release_mask;
                CMD_ADDRESS: begin
                    snap_fpga_addr_lvds       <= recv_fpga_address;
                    snap_fpga_addr_valid_lvds <= 1'b1;
                end
                default: ;
            endcase
        end
    end

    // mm-side shadow registers
    logic [7:0]  shadow_last_cmd;
    logic [31:0] shadow_run_number;
    logic [15:0] shadow_reset_assert, shadow_reset_release;
    logic [15:0] shadow_fpga_addr;
    logic        shadow_fpga_addr_valid;
    logic [47:0] shadow_recv_ts, shadow_exec_ts;

    always_ff @(posedge mm_clk) begin
        if (mm_reset) begin
            snap_update_mm_sync    <= 2'b00;
            snap_update_mm_seen    <= 1'b0;
            shadow_last_cmd        <= 8'h00;
            shadow_run_number      <= 32'd0;
            shadow_reset_assert    <= 16'd0;
            shadow_reset_release   <= 16'd0;
            shadow_fpga_addr       <= 16'd0;
            shadow_fpga_addr_valid <= 1'b0;
            shadow_recv_ts         <= 48'd0;
            shadow_exec_ts         <= 48'd0;
        end else begin
            snap_update_mm_sync <= {snap_update_mm_sync[0], snap_update_lvds};
            if (snap_update_mm_sync[1] != snap_update_mm_seen) begin
                snap_update_mm_seen    <= snap_update_mm_sync[1];
                shadow_last_cmd        <= snap_last_cmd_lvds;
                shadow_run_number      <= snap_run_number_lvds;
                shadow_reset_assert    <= snap_reset_assert_lvds;
                shadow_reset_release   <= snap_reset_release_lvds;
                shadow_fpga_addr       <= snap_fpga_addr_lvds;
                shadow_fpga_addr_valid <= snap_fpga_addr_valid_lvds;
                shadow_recv_ts         <= snap_recv_ts_lvds;
                shadow_exec_ts         <= snap_exec_ts_lvds;
            end
        end
    end

    // ============================================================
    // Saturating counters (lvdspll_clk) → 32-bit gray CDC → mm
    // ============================================================
    logic [31:0] rx_cmd_count_lvds, rx_err_count_lvds, log_drop_count_lvds;
    logic [31:0] rx_cmd_gray_lvds, rx_err_gray_lvds, log_drop_gray_lvds;
    logic [31:0] rx_cmd_gray_ff0, rx_cmd_gray_ff1;
    logic [31:0] rx_err_gray_ff0, rx_err_gray_ff1;
    logic [31:0] log_drop_gray_ff0, log_drop_gray_ff1;
    logic [31:0] rx_cmd_count_mm, rx_err_count_mm;

    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset) begin
            rx_cmd_count_lvds  <= 32'd0;
            rx_err_count_lvds  <= 32'd0;
            log_drop_count_lvds<= 32'd0;
        end else begin
            if (ev_cmd_accepted && rx_cmd_count_lvds != 32'hFFFF_FFFF)
                rx_cmd_count_lvds <= rx_cmd_count_lvds + 32'd1;
            if (ev_rx_error && rx_err_count_lvds != 32'hFFFF_FFFF)
                rx_err_count_lvds <= rx_err_count_lvds + 32'd1;
            if (ev_log_drop && log_drop_count_lvds != 32'hFFFF_FFFF)
                log_drop_count_lvds <= log_drop_count_lvds + 32'd1;
        end
    end

    always_ff @(posedge lvdspll_clk) begin
        if (lvdspll_reset) begin
            rx_cmd_gray_lvds   <= 32'd0;
            rx_err_gray_lvds   <= 32'd0;
            log_drop_gray_lvds <= 32'd0;
        end else begin
            rx_cmd_gray_lvds   <= (rx_cmd_count_lvds >> 1)   ^ rx_cmd_count_lvds;
            rx_err_gray_lvds   <= (rx_err_count_lvds >> 1)   ^ rx_err_count_lvds;
            log_drop_gray_lvds <= (log_drop_count_lvds >> 1) ^ log_drop_count_lvds;
        end
    end

    always_ff @(posedge mm_clk) begin
        if (mm_reset) begin
            rx_cmd_gray_ff0   <= 32'd0; rx_cmd_gray_ff1   <= 32'd0;
            rx_err_gray_ff0   <= 32'd0; rx_err_gray_ff1   <= 32'd0;
            log_drop_gray_ff0 <= 32'd0; log_drop_gray_ff1 <= 32'd0;
        end else begin
            rx_cmd_gray_ff0   <= rx_cmd_gray_lvds;
            rx_cmd_gray_ff1   <= rx_cmd_gray_ff0;
            rx_err_gray_ff0   <= rx_err_gray_lvds;
            rx_err_gray_ff1   <= rx_err_gray_ff0;
            log_drop_gray_ff0 <= log_drop_gray_lvds;
            log_drop_gray_ff1 <= log_drop_gray_ff0;
        end
    end

    // Gray → binary decoders (combinational)
    function automatic logic [31:0] gray_to_bin32 (input logic [31:0] g);
        logic [31:0] b;
        b[31] = g[31];
        for (int i = 30; i >= 0; i--) b[i] = b[i+1] ^ g[i];
        gray_to_bin32 = b;
    endfunction

    assign rx_cmd_count_mm = gray_to_bin32(rx_cmd_gray_ff1);
    assign rx_err_count_mm = gray_to_bin32(rx_err_gray_ff1);

    // ============================================================
    // Status single-bit 2FF sync (lvds → mm)
    // ============================================================
    always_ff @(posedge mm_clk) begin
        if (mm_reset) begin
            recv_idle_sync     <= 2'b00;
            host_idle_sync     <= 2'b00;
            dp_hreset_sync     <= 2'b00;
            ct_hreset_sync     <= 2'b00;
            recv_state_sync_q0 <= 16'd0;
            recv_state_sync_q1 <= 16'd0;
            host_state_sync_q0 <= 16'd0;
            host_state_sync_q1 <= 16'd0;
        end else begin
            recv_idle_sync <= {recv_idle_sync[0], recv_idle_lvds};
            host_idle_sync <= {host_idle_sync[0], host_idle_lvds};
            dp_hreset_sync <= {dp_hreset_sync[0], dp_hard_reset_raw};
            ct_hreset_sync <= {ct_hreset_sync[0], ct_hard_reset_raw};
            recv_state_sync_q0 <= {8'h00, recv_state_lvds};
            recv_state_sync_q1 <= recv_state_sync_q0;
            host_state_sync_q0 <= {8'h00, host_state_lvds};
            host_state_sync_q1 <= host_state_sync_q0;
        end
    end

    // ============================================================
    // Logging FIFO instantiation (dcfifo_mixed_widths)
    // ============================================================
    logic         log_fifo_rdreq;
    logic [31:0]  log_fifo_q;
    logic         log_fifo_rdempty;
    logic         log_fifo_rdfull;
    logic [9:0]   log_fifo_rdusedw;

    logging_fifo u_log_fifo (
        .data    (log_fifo_data),
        .rdclk   (mm_clk),
        .rdreq   (log_fifo_rdreq),
        .wrclk   (lvdspll_clk),
        .wrreq   (log_fifo_wrreq),
        .q       (log_fifo_q),
        .rdempty (log_fifo_rdempty),
        .rdfull  (log_fifo_rdfull),
        .rdusedw (log_fifo_rdusedw),
        .wrempty (log_fifo_wrempty),
        .wrfull  (log_fifo_wrfull),
        .wrusedw (log_fifo_wrusedw)
    );

    // ============================================================
    // CSR slave (mm_clk)
    // ============================================================
    // mm-side CSR state:
    //   IDLE: handle a read or a write in one cycle (waitrequest=0)
    //   LOCAL_WAIT: stall write to LOCAL_CMD until !busy
    //   LOG_FLUSH: drain log FIFO (rdreq held) until rdempty
    localparam logic [1:0] CSR_IDLE      = 2'd0;
    localparam logic [1:0] CSR_LOCAL_WAIT= 2'd1;
    localparam logic [1:0] CSR_LOG_FLUSH = 2'd2;

    logic [1:0]  csr_state;
    logic [31:0] csr_scratch;
    logic [1:0]  meta_page;
    logic [31:0] gts_h_shadow;    // latched at GTS_L read
    logic [31:0] meta_readdata;
    logic        local_cmd_req_hold_mm;
    logic [31:0] local_cmd_hold_word_mm;

    // META page mux
    always_comb begin
        case (meta_page)
            2'd0: meta_readdata = {VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH, BUILD};
            2'd1: meta_readdata = VERSION_DATE;
            2'd2: meta_readdata = VERSION_GIT;
            2'd3: meta_readdata = INSTANCE_ID;
            default: meta_readdata = 32'd0;
        endcase
    end

    always_ff @(posedge mm_clk) begin
        if (mm_reset) begin
            csr_state            <= CSR_IDLE;
            avs_csr_readdata     <= 32'd0;
            avs_csr_waitrequest  <= 1'b1;
            csr_scratch          <= 32'd0;
            meta_page            <= 2'd0;
            rst_mask_dp_mm       <= 1'b0;
            rst_mask_ct_mm       <= 1'b0;
            soft_reset_req_mm    <= 1'b0;
            local_cmd_word_mm    <= 32'd0;
            local_cmd_req_mm     <= 1'b0;
            local_cmd_req_hold_mm<= 1'b0;
            local_cmd_hold_word_mm <= 32'd0;
            log_fifo_rdreq       <= 1'b0;
            gts_h_shadow         <= 32'd0;
        end else begin
            // Defaults
            avs_csr_waitrequest <= 1'b1;
            avs_csr_readdata    <= 32'd0;
            log_fifo_rdreq      <= 1'b0;
            if (!avs_csr_write ||
                (avs_csr_address != CSR_LOCAL_CMD) ||
                (avs_csr_writedata != local_cmd_hold_word_mm)) begin
                local_cmd_req_hold_mm <= 1'b0;
            end

            case (csr_state)
                CSR_IDLE: begin
                    if (avs_csr_write) begin
                        avs_csr_waitrequest <= 1'b0;
                        case (avs_csr_address)
                            CSR_UID: ; // RO
                            CSR_META: begin
                                meta_page <= avs_csr_writedata[1:0];
                            end
                            CSR_CONTROL: begin
                                // soft_reset (W1P) → toggle to lvds + start LOG_FLUSH
                                if (avs_csr_writedata[0]) begin
                                    soft_reset_req_mm   <= ~soft_reset_req_mm;
                                    avs_csr_waitrequest <= 1'b1;
                                    csr_state           <= CSR_LOG_FLUSH;
                                end
                                if (avs_csr_writedata[1]) begin
                                    // log_flush (W1P)
                                    avs_csr_waitrequest <= 1'b1;
                                    csr_state           <= CSR_LOG_FLUSH;
                                end
                                rst_mask_dp_mm <= avs_csr_writedata[4];
                                rst_mask_ct_mm <= avs_csr_writedata[5];
                            end
                            CSR_SCRATCH: begin
                                csr_scratch <= avs_csr_writedata;
                            end
                            CSR_LOCAL_CMD: begin
                                if (!local_cmd_req_hold_mm) begin
                                    local_cmd_req_hold_mm <= 1'b1;
                                    local_cmd_hold_word_mm <= avs_csr_writedata;
                                    if (!local_cmd_busy_mm) begin
                                        local_cmd_word_mm <= avs_csr_writedata;
                                        local_cmd_req_mm  <= ~local_cmd_req_mm;
                                    end else begin
                                        // Stall until CDC handshake completes.
                                        avs_csr_waitrequest <= 1'b1;
                                        csr_state           <= CSR_LOCAL_WAIT;
                                        local_cmd_word_mm   <= avs_csr_writedata;
                                    end
                                end
                            end
                            default: ; // reserved/RO → accept, no side effects
                        endcase
                    end else if (avs_csr_read) begin
                        avs_csr_waitrequest <= 1'b0;
                        case (avs_csr_address)
                            CSR_UID:        avs_csr_readdata <= IP_UID;
                            CSR_META:       avs_csr_readdata <= meta_readdata;
                            CSR_CONTROL:    avs_csr_readdata <= {26'd0, rst_mask_ct_mm,
                                                                rst_mask_dp_mm, 4'd0};
                            CSR_STATUS:     avs_csr_readdata <= {
                                                log_fifo_rdempty,           // [31]
                                                local_cmd_busy_mm,          // [30]
                                                6'd0,                       // [29:24]
                                                host_state_sync_q1[7:0],    // [23:16]
                                                recv_state_sync_q1[7:0],    // [15:8]
                                                2'd0,                       // [7:6]
                                                ct_hreset_sync[1],          // [5]
                                                dp_hreset_sync[1],          // [4]
                                                2'd0,                       // [3:2]
                                                host_idle_sync[1],          // [1]
                                                recv_idle_sync[1]           // [0]
                                            };
                            CSR_LAST_CMD:   avs_csr_readdata <= {shadow_fpga_addr, 8'd0,
                                                                shadow_last_cmd};
                            CSR_SCRATCH:    avs_csr_readdata <= csr_scratch;
                            CSR_RUN_NUMBER: avs_csr_readdata <= shadow_run_number;
                            CSR_RESET_MASK: avs_csr_readdata <= {shadow_reset_release,
                                                                shadow_reset_assert};
                            CSR_FPGA_ADDRESS: avs_csr_readdata <= {shadow_fpga_addr_valid,
                                                                15'd0, shadow_fpga_addr};
                            CSR_RECV_TS_L:  avs_csr_readdata <= shadow_recv_ts[31:0];
                            CSR_RECV_TS_H:  avs_csr_readdata <= {16'd0, shadow_recv_ts[47:32]};
                            CSR_EXEC_TS_L:  avs_csr_readdata <= shadow_exec_ts[31:0];
                            CSR_EXEC_TS_H:  avs_csr_readdata <= {16'd0, shadow_exec_ts[47:32]};
                            CSR_GTS_L: begin
                                avs_csr_readdata <= gts_mm_binary[31:0];
                                gts_h_shadow     <= {16'd0, gts_mm_binary[47:32]};
                            end
                            CSR_GTS_H:      avs_csr_readdata <= gts_h_shadow;
                            CSR_RX_CMD_COUNT: avs_csr_readdata <= rx_cmd_count_mm;
                            CSR_RX_ERR_COUNT: avs_csr_readdata <= rx_err_count_mm;
                            CSR_LOG_STATUS: avs_csr_readdata <= {14'd0, log_fifo_rdfull,
                                                                log_fifo_rdempty, 6'd0,
                                                                log_fifo_rdusedw};
                            CSR_LOG_POP: begin
                                if (!log_fifo_rdempty) begin
                                    avs_csr_readdata <= log_fifo_q;
                                    log_fifo_rdreq   <= 1'b1;
                                end else begin
                                    avs_csr_readdata <= 32'd0;
                                end
                            end
                            CSR_LOCAL_CMD:  avs_csr_readdata <= local_cmd_word_mm;
                            CSR_ACK_SYMBOLS: avs_csr_readdata <= {16'd0, RUN_END_ACK_SYMBOL,
                                                                RUN_START_ACK_SYMBOL};
                            default:        avs_csr_readdata <= 32'd0;
                        endcase
                    end
                end

                CSR_LOCAL_WAIT: begin
                    // Hold the write captured at LOCAL_CMD and stall the bus
                    // until the previous toggle completes, then re-issue.
                    if (!local_cmd_busy_mm) begin
                        local_cmd_req_mm    <= ~local_cmd_req_mm;
                        avs_csr_waitrequest <= 1'b0;
                        csr_state           <= CSR_IDLE;
                    end
                end

                CSR_LOG_FLUSH: begin
                    // Hold rdreq high to drain the FIFO. Keep the bus stalled
                    // until empty so that the triggering W1P write completes.
                    if (!log_fifo_rdempty) begin
                        log_fifo_rdreq <= 1'b1;
                    end else begin
                        avs_csr_waitrequest <= 1'b0;
                        csr_state           <= CSR_IDLE;
                    end
                end

                default: csr_state <= CSR_IDLE;
            endcase
        end
    end

endmodule
