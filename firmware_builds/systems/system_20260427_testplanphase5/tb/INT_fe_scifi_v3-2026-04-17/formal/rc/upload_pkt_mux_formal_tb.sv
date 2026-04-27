`include "formal_defs.svh"

module upload_pkt_mux_formal_tb;
    (* gclk *) reg gclk;

    reg       f_past_valid = 1'b0;
    reg [1:0] f_reset_sr   = 2'b11;
    reg [5:0] f_cycle      = 6'd0;

    wire rst     = f_reset_sr[1];
    wire reset_n = !rst;

    (* anyconst *) reg [1:0] start0;
    (* anyconst *) reg [1:0] start1;
    (* anyconst *) reg [1:0] start2;
    (* anyconst *) reg       long0;
    (* anyconst *) reg       long1;
    (* anyconst *) reg       long2;
    (* anyseq *)   reg       out_ready;

    reg src0_active  = 1'b0;
    reg src0_started = 1'b0;
    reg src0_done    = 1'b0;
    reg src0_beat    = 1'b0;

    reg src1_active  = 1'b0;
    reg src1_started = 1'b0;
    reg src1_done    = 1'b0;
    reg src1_beat    = 1'b0;

    reg src2_active  = 1'b0;
    reg src2_started = 1'b0;
    reg src2_done    = 1'b0;
    reg src2_beat    = 1'b0;

    wire       in0_valid = src0_active;
    wire [35:0] in0_data = beat_payload(2'd0, src0_beat);
    wire       in0_startofpacket = !src0_beat;
    wire       in0_endofpacket   = !long0 || src0_beat;
    wire       in0_ready;

    wire       in1_valid = src1_active;
    wire [35:0] in1_data = beat_payload(2'd1, src1_beat);
    wire       in1_startofpacket = !src1_beat;
    wire       in1_endofpacket   = !long1 || src1_beat;
    wire       in1_ready;

    wire       in2_valid = src2_active;
    wire [35:0] in2_data = beat_payload(2'd2, src2_beat);
    wire       in2_startofpacket = !src2_beat;
    wire       in2_endofpacket   = !long2 || src2_beat;
    wire       in2_ready;

    wire [1:0]  out_channel;
    wire        out_valid;
    wire [35:0] out_data;
    wire        out_startofpacket;
    wire        out_endofpacket;

    wire in0_fire = in0_valid && in0_ready;
    wire in1_fire = in1_valid && in1_ready;
    wire in2_fire = in2_valid && in2_ready;
    wire out_fire = out_valid && out_ready;

    wire [1:0] total_beats0 = long0 ? 2'd2 : 2'd1;
    wire [1:0] total_beats1 = long1 ? 2'd2 : 2'd1;
    wire [1:0] total_beats2 = long2 ? 2'd2 : 2'd1;

    wire src0_complete_now = out_fire && (out_channel == 2'd0) && (!long0 || src0_beat_for_out(2'd0));
    wire src1_complete_now = out_fire && (out_channel == 2'd1) && (!long1 || src1_beat_for_out(2'd1));
    wire src2_complete_now = out_fire && (out_channel == 2'd2) && (!long2 || src2_beat_for_out(2'd2));

    reg [1:0] in_count0  = 2'd0;
    reg [1:0] in_count1  = 2'd0;
    reg [1:0] in_count2  = 2'd0;
    reg [1:0] out_count0 = 2'd0;
    reg [1:0] out_count1 = 2'd0;
    reg [1:0] out_count2 = 2'd0;

    reg        req_pending0 = 1'b0;
    reg [5:0]  req_deadline0 = 6'd0;
    reg        req_pending1 = 1'b0;
    reg [5:0]  req_deadline1 = 6'd0;
    reg        req_pending2 = 1'b0;
    reg [5:0]  req_deadline2 = 6'd0;

    reg [3:0] out_stall_ctr = 4'd0;

    reg        prev_out_valid = 1'b0;
    reg        prev_out_ready = 1'b0;
    reg [35:0] prev_out_data = 36'd0;
    reg [1:0]  prev_out_channel = 2'd0;
    reg        prev_out_sop = 1'b0;
    reg        prev_out_eop = 1'b0;

    reg        frame_in_progress = 1'b0;
    reg [1:0]  frame_channel = 2'd0;

    function automatic [35:0] beat_payload(input [1:0] src, input beat_idx);
        begin
            beat_payload = {src, beat_idx, ~beat_idx, 32'h51A2_C300 ^ {29'd0, src, beat_idx}};
        end
    endfunction

    function automatic src0_beat_for_out(input [1:0] channel);
        begin
            src0_beat_for_out = (channel == 2'd0) && (out_count0 == 2'd1);
        end
    endfunction

    function automatic src1_beat_for_out(input [1:0] channel);
        begin
            src1_beat_for_out = (channel == 2'd1) && (out_count1 == 2'd1);
        end
    endfunction

    function automatic src2_beat_for_out(input [1:0] channel);
        begin
            src2_beat_for_out = (channel == 2'd2) && (out_count2 == 2'd1);
        end
    endfunction

    upload_system_v3_upload_pkt_mux dut (
        .out_channel       (out_channel),
        .out_valid         (out_valid),
        .out_ready         (out_ready),
        .out_data          (out_data),
        .out_startofpacket (out_startofpacket),
        .out_endofpacket   (out_endofpacket),
        .in0_valid         (in0_valid),
        .in0_ready         (in0_ready),
        .in0_data          (in0_data),
        .in0_startofpacket (in0_startofpacket),
        .in0_endofpacket   (in0_endofpacket),
        .in1_valid         (in1_valid),
        .in1_ready         (in1_ready),
        .in1_data          (in1_data),
        .in1_startofpacket (in1_startofpacket),
        .in1_endofpacket   (in1_endofpacket),
        .in2_valid         (in2_valid),
        .in2_ready         (in2_ready),
        .in2_data          (in2_data),
        .in2_startofpacket (in2_startofpacket),
        .in2_endofpacket   (in2_endofpacket),
        .clk               (gclk),
        .reset_n           (reset_n)
    );

    always @(posedge gclk) begin
        f_past_valid <= 1'b1;

        if (!f_past_valid) begin
            assume(rst);
            assume(start0 <= 2'd1);
            assume(start1 <= 2'd1);
            assume(start2 <= 2'd1);
        end

        if (f_reset_sr != 2'b00) begin
            f_reset_sr <= {f_reset_sr[0], 1'b0};
            f_cycle    <= 6'd0;
        end else if (f_cycle != 6'h3F) begin
            f_cycle <= f_cycle + 6'd1;
        end

        if (rst) begin
            src0_active        <= 1'b0;
            src0_started       <= 1'b0;
            src0_done          <= 1'b0;
            src0_beat          <= 1'b0;
            src1_active        <= 1'b0;
            src1_started       <= 1'b0;
            src1_done          <= 1'b0;
            src1_beat          <= 1'b0;
            src2_active        <= 1'b0;
            src2_started       <= 1'b0;
            src2_done          <= 1'b0;
            src2_beat          <= 1'b0;
            in_count0          <= 2'd0;
            in_count1          <= 2'd0;
            in_count2          <= 2'd0;
            out_count0         <= 2'd0;
            out_count1         <= 2'd0;
            out_count2         <= 2'd0;
            req_pending0       <= 1'b0;
            req_deadline0      <= 6'd0;
            req_pending1       <= 1'b0;
            req_deadline1      <= 6'd0;
            req_pending2       <= 1'b0;
            req_deadline2      <= 6'd0;
            out_stall_ctr      <= 4'd0;
            prev_out_valid     <= 1'b0;
            prev_out_ready     <= 1'b0;
            prev_out_data      <= 36'd0;
            prev_out_channel   <= 2'd0;
            prev_out_sop       <= 1'b0;
            prev_out_eop       <= 1'b0;
            frame_in_progress  <= 1'b0;
            frame_channel      <= 2'd0;
        end else begin
            if (!src0_started && (f_cycle >= start0)) begin
                src0_started <= 1'b1;
                src0_active  <= 1'b1;
                src0_beat    <= 1'b0;
            end
            if (!src1_started && (f_cycle >= start1)) begin
                src1_started <= 1'b1;
                src1_active  <= 1'b1;
                src1_beat    <= 1'b0;
            end
            if (!src2_started && (f_cycle >= start2)) begin
                src2_started <= 1'b1;
                src2_active  <= 1'b1;
                src2_beat    <= 1'b0;
            end

            if (in0_fire) begin
                in_count0 <= in_count0 + 2'd1;
                if (!long0 || src0_beat) begin
                    src0_active <= 1'b0;
                    src0_done   <= 1'b1;
                end else begin
                    src0_beat <= 1'b1;
                end
            end
            if (in1_fire) begin
                in_count1 <= in_count1 + 2'd1;
                if (!long1 || src1_beat) begin
                    src1_active <= 1'b0;
                    src1_done   <= 1'b1;
                end else begin
                    src1_beat <= 1'b1;
                end
            end
            if (in2_fire) begin
                in_count2 <= in_count2 + 2'd1;
                if (!long2 || src2_beat) begin
                    src2_active <= 1'b0;
                    src2_done   <= 1'b1;
                end else begin
                    src2_beat <= 1'b1;
                end
            end

            if (out_valid && !out_ready) begin
                out_stall_ctr <= out_stall_ctr + 4'd1;
            end else begin
                out_stall_ctr <= 4'd0;
            end
            assume(out_stall_ctr < `FORMAL_READY_STALL_MAX);

            if (f_past_valid && prev_out_valid && !prev_out_ready) begin
                assert(out_valid);
                assert(out_data == prev_out_data);
                assert(out_channel == prev_out_channel);
                assert(out_startofpacket == prev_out_sop);
                assert(out_endofpacket == prev_out_eop);
            end

            if (out_valid) begin
                assert(out_channel != 2'b11);
            end

            if (frame_in_progress && out_valid) begin
                assert(out_channel == frame_channel);
                assert(!out_startofpacket);
            end

            if (out_fire) begin
                case (out_channel)
                    2'd0: begin
                        assert(out_count0 < in_count0);
                        assert(out_data == beat_payload(2'd0, out_count0[0]));
                        assert(out_startofpacket == (out_count0 == 2'd0));
                        assert(out_endofpacket == (!long0 || (out_count0 == 2'd1)));
                        out_count0 <= out_count0 + 2'd1;
                    end
                    2'd1: begin
                        assert(out_count1 < in_count1);
                        assert(out_data == beat_payload(2'd1, out_count1[0]));
                        assert(out_startofpacket == (out_count1 == 2'd0));
                        assert(out_endofpacket == (!long1 || (out_count1 == 2'd1)));
                        out_count1 <= out_count1 + 2'd1;
                    end
                    2'd2: begin
                        assert(out_count2 < in_count2);
                        assert(out_data == beat_payload(2'd2, out_count2[0]));
                        assert(out_startofpacket == (out_count2 == 2'd0));
                        assert(out_endofpacket == (!long2 || (out_count2 == 2'd1)));
                        out_count2 <= out_count2 + 2'd1;
                    end
                    default: assert(1'b0);
                endcase

                if (out_startofpacket) begin
                    assert(!frame_in_progress);
                    frame_channel     <= out_channel;
                    frame_in_progress <= !out_endofpacket;
                end else if (frame_in_progress && out_endofpacket) begin
                    frame_in_progress <= 1'b0;
                end
            end

            if (!req_pending0 && src0_started && (out_count0 != total_beats0)) begin
                req_pending0  <= 1'b1;
                req_deadline0 <= `FORMAL_RR_STARVATION_BOUND;
            end
            if (!req_pending1 && src1_started && (out_count1 != total_beats1)) begin
                req_pending1  <= 1'b1;
                req_deadline1 <= `FORMAL_RR_STARVATION_BOUND;
            end
            if (!req_pending2 && src2_started && (out_count2 != total_beats2)) begin
                req_pending2  <= 1'b1;
                req_deadline2 <= `FORMAL_RR_STARVATION_BOUND;
            end

            if (req_pending0) begin
                if (src0_complete_now || (out_count0 == total_beats0)) begin
                    req_pending0  <= 1'b0;
                    req_deadline0 <= 6'd0;
                end else begin
                    assert(req_deadline0 != 6'd0);
                    req_deadline0 <= req_deadline0 - 6'd1;
                end
            end
            if (req_pending1) begin
                if (src1_complete_now || (out_count1 == total_beats1)) begin
                    req_pending1  <= 1'b0;
                    req_deadline1 <= 6'd0;
                end else begin
                    assert(req_deadline1 != 6'd0);
                    req_deadline1 <= req_deadline1 - 6'd1;
                end
            end
            if (req_pending2) begin
                if (src2_complete_now || (out_count2 == total_beats2)) begin
                    req_pending2  <= 1'b0;
                    req_deadline2 <= 6'd0;
                end else begin
                    assert(req_deadline2 != 6'd0);
                    req_deadline2 <= req_deadline2 - 6'd1;
                end
            end

            cover(out_fire && (out_channel == 2'd0));
            cover(out_fire && (out_channel == 2'd1));
            cover(out_fire && (out_channel == 2'd2));
            cover(src0_active && src1_active && src2_active);
            cover(frame_in_progress && out_valid && !out_ready);
            cover((out_count0 == total_beats0) && (out_count1 == total_beats1) && (out_count2 == total_beats2));

            prev_out_valid   <= out_valid;
            prev_out_ready   <= out_ready;
            prev_out_data    <= out_data;
            prev_out_channel <= out_channel;
            prev_out_sop     <= out_startofpacket;
            prev_out_eop     <= out_endofpacket;
        end
    end

endmodule
