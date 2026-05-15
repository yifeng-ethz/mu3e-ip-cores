// be_mutrig_lane_type0_emit.sv
// MuTRiG lane hit_type0 emitter with link-bottleneck pacer.
// Author: Yifeng Wang
// Version : 26.3.0
// Date    : 20260506
// Change  : Add DEBUG_LEVEL metadata emitted one-to-one with hit_type0 payloads.

module be_mutrig_lane_type0_emit
    import be_mutrig_pkg::*;
#(
    parameter int FIFO_COUNT_WIDTH = 10,
    parameter int DEBUG_LEVEL = 0
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         enable,
    input  logic                         own_drain,
    input  logic                         frame_start_req,
    input  logic                         frame_start_allowed,
    input  logic                         run_terminating,
    input  logic                         run_idle,
    input  logic                         cfg_short_mode,
    input  logic [3:0]                   asic_id,
    input  logic [2:0]                   error_inject_mask,
    input  logic                         error_target_lane,

    input  logic                         l2_empty,
    input  logic [FIFO_COUNT_WIDTH-1:0]  l2_level,
    output logic                         l2_rd_en,
    input  logic [47:0]                  l2_rd_data,
    input  logic                         l2_rd_valid,

    output logic [3:0]                   aso_hit_type0_channel,
    output logic                         aso_hit_type0_startofpacket,
    output logic                         aso_hit_type0_endofpacket,
    output logic                         aso_hit_type0_endofrun,
    output logic [2:0]                   aso_hit_type0_error,
    output logic [44:0]                  aso_hit_type0_data,
    output logic                         aso_hit_type0_valid,

    output logic [63:0]                  aso_hit_debug_data,
    output logic                         aso_hit_debug_valid,
    output logic [3:0]                   aso_hit_debug_channel,
    output logic                         aso_hit_debug_startofpacket,
    output logic                         aso_hit_debug_endofpacket,
    output logic                         aso_hit_debug_endofrun
);

    logic [FIFO_COUNT_WIDTH-1:0] issue_remaining;
    logic [FIFO_COUNT_WIDTH-1:0] emit_remaining;
    logic in_packet;
    logic prev_terminating;
    logic [31:0] debug_cycle;
    logic [23:0] debug_hit_seq;
    logic [63:0] debug_data_comb;

    // Link-bottleneck pacer. Models the real MuTRiG output bandwidth at
    // the 125 MHz emulator boundary so the hit_type0 path imposes the
    // same offered-rate envelope as if the byte stream were running.
    //   short_mode = 1: alternating 3 / 4 cycles between l2_rd_en pulses
    //                   (ping-pong, average 3.5 cycles/hit)
    //   short_mode = 0: every 6 cycles between l2_rd_en pulses (long hit)
    logic [2:0] pacer_cnt;
    logic       pacer_pingpong;
    logic       pacer_window_open;
    logic       pacer_pop;
    logic [2:0] pacer_window_max;

    assign pacer_window_max = cfg_short_mode
        ? (pacer_pingpong ? 3'd2 : 3'd3)   // 3-cycle + 4-cycle alternation
        : 3'd5;                            // 6-cycle long-hit window
    assign pacer_window_open = (pacer_cnt == pacer_window_max);
    assign pacer_pop = own_drain && enable && (issue_remaining != '0)
                       && !l2_empty && pacer_window_open;

    assign l2_rd_en = pacer_pop;
    // -- legacy unconstrained pop kept here for reference; see pacer above
    // assign l2_rd_en = own_drain && enable && (issue_remaining != '0) && !l2_empty;
    assign aso_hit_type0_channel = asic_id;
    assign aso_hit_type0_error = error_target_lane ? error_inject_mask : 3'b000;
    assign debug_data_comb = {
        debug_cycle,
        4'h1,
        asic_id,
        debug_hit_seq
    };

    always_ff @(posedge clk) begin
        if (rst) begin
            issue_remaining <= '0;
            emit_remaining <= '0;
            in_packet <= 1'b0;
            prev_terminating <= 1'b0;
            pacer_cnt <= '0;
            pacer_pingpong <= 1'b0;
            aso_hit_type0_startofpacket <= 1'b0;
            aso_hit_type0_endofpacket <= 1'b0;
            aso_hit_type0_endofrun <= 1'b0;
            aso_hit_type0_data <= '0;
            aso_hit_type0_valid <= 1'b0;
            aso_hit_debug_data <= '0;
            aso_hit_debug_valid <= 1'b0;
            aso_hit_debug_channel <= 4'd0;
            aso_hit_debug_startofpacket <= 1'b0;
            aso_hit_debug_endofpacket <= 1'b0;
            aso_hit_debug_endofrun <= 1'b0;
            debug_cycle <= 32'h0000_0000;
            debug_hit_seq <= 24'h000000;
        end else begin
            debug_cycle <= debug_cycle + 32'd1;
            // Pacer counter advances every cycle; resets on a successful
            // pop and toggles the ping-pong bit so the next short-mode
            // window alternates 3 vs 4 cycles.
            if (pacer_pop) begin
                pacer_cnt <= '0;
                pacer_pingpong <= ~pacer_pingpong;
            end else if (pacer_cnt != pacer_window_max) begin
                pacer_cnt <= pacer_cnt + 3'd1;
            end
            aso_hit_type0_startofpacket <= 1'b0;
            aso_hit_type0_endofpacket <= 1'b0;
            aso_hit_type0_endofrun <= 1'b0;
            aso_hit_type0_valid <= 1'b0;
            aso_hit_debug_valid <= 1'b0;
            aso_hit_debug_startofpacket <= 1'b0;
            aso_hit_debug_endofpacket <= 1'b0;
            aso_hit_debug_endofrun <= 1'b0;
            prev_terminating <= run_terminating;

            if (frame_start_req && frame_start_allowed && enable && !l2_empty) begin
                issue_remaining <= l2_level;
                emit_remaining <= l2_level;
            end

            if (l2_rd_en && (issue_remaining != '0)) begin
                issue_remaining <= issue_remaining - FIFO_COUNT_WIDTH'(1);
            end

            if (enable && l2_rd_valid && (emit_remaining != '0)) begin
                aso_hit_type0_valid <= 1'b1;
                aso_hit_type0_data <= pack_hit_type0(l2_rd_data, asic_id);
                aso_hit_type0_startofpacket <= !in_packet;
                aso_hit_type0_endofpacket <= (emit_remaining == FIFO_COUNT_WIDTH'(1));
                debug_hit_seq <= debug_hit_seq + 24'd1;
                if (DEBUG_LEVEL >= 2) begin
                    aso_hit_debug_valid <= 1'b1;
                    aso_hit_debug_data <= debug_data_comb;
                    aso_hit_debug_channel <= asic_id;
                    aso_hit_debug_startofpacket <= !in_packet;
                    aso_hit_debug_endofpacket <= (emit_remaining == FIFO_COUNT_WIDTH'(1));
                end

                if (emit_remaining == FIFO_COUNT_WIDTH'(1)) begin
                    emit_remaining <= '0;
                    in_packet <= 1'b0;
                end else begin
                    emit_remaining <= emit_remaining - FIFO_COUNT_WIDTH'(1);
                    in_packet <= 1'b1;
                end
            end

            if (prev_terminating && run_idle && l2_empty && (emit_remaining == '0)) begin
                aso_hit_type0_endofrun <= 1'b1;
                if (DEBUG_LEVEL >= 2) begin
                    aso_hit_debug_endofrun <= 1'b1;
                end
            end

            if (!enable) begin
                issue_remaining <= '0;
                emit_remaining <= '0;
                in_packet <= 1'b0;
            end
        end
    end

endmodule
