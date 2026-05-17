`timescale 1ns/1ps

module tb_feb_upload_backpressure;
    localparam int unsigned PERIOD_CYCLES = 1250;
    localparam int unsigned PACKET_BEATS = 8;
    localparam int unsigned STALL_CYCLES = 16;
    localparam int unsigned RUN_CYCLES = 12000;
    localparam logic [35:0] RUNCTL_IDLE_WORD = {27'd0, 9'h1bc};

    logic clk = 1'b0;
    logic reset_n = 1'b0;

    logic [35:0] src_data;
    logic        src_valid;
    logic        src_sop;
    logic        src_eop;
    logic        src_empty;
    logic        src_ready;

    logic [35:0] upload_data;
    logic        upload_valid;
    logic        upload_ready;
    logic        upload_sop;
    logic        upload_eop;

    logic [35:0] out_data;
    logic        out_valid;
    logic        out_ready;
    logic        out_sop;
    logic        out_eop;
    logic [1:0]  out_channel;

    logic        in1_valid;
    logic        in1_ready;
    logic [35:0] in1_data;
    logic        in1_sop;
    logic        in1_eop;

    logic        in2_valid;
    logic        in2_ready;
    logic [35:0] in2_data;
    logic        in2_sop;
    logic        in2_eop;

    int unsigned cycle_count;
    int unsigned source_beat;
    int unsigned source_period;
    int unsigned stall_count;
    bit          stall_armed_for_packet;

    int unsigned in0_valid_held_cycles;
    int unsigned in0_ready_pulses;
    int unsigned in2_ready_pulses;
    int unsigned idle_words_seen;
    int unsigned in0_eop_offered;
    int unsigned in0_eop_accepted;
    int unsigned stall_windows;

    bit expect_broken;
    bit expect_fixed;

    always #4 clk = ~clk;

    initial begin
        if (!$value$plusargs("EXPECT_BROKEN=%d", expect_broken))
            expect_broken = 1'b0;
        if (!$value$plusargs("EXPECT_FIXED=%d", expect_fixed))
            expect_fixed = 1'b0;
        if (expect_broken == expect_fixed)
            $fatal(1, "Set exactly one of +EXPECT_BROKEN=1 or +EXPECT_FIXED=1");

        repeat (8) @(posedge clk);
        reset_n <= 1'b1;
    end

`ifdef FEB_UPLOAD_BROKEN_ADAPTER
    assign src_ready = 1'b1;

    feb_system_v3_avalon_st_adapter u_generated_adapter (
        .in_clk_0_clk        (clk),
        .in_rst_0_reset      (~reset_n),
        .in_0_data           (src_data),
        .in_0_valid          (src_valid),
        .in_0_startofpacket  (src_sop),
        .in_0_endofpacket    (src_eop),
        .in_0_empty          (src_empty),
        .out_0_data          (upload_data),
        .out_0_valid         (upload_valid),
        .out_0_ready         (upload_ready),
        .out_0_startofpacket (upload_sop),
        .out_0_endofpacket   (upload_eop)
    );
`elsif FEB_UPLOAD_DIRECT_READY
    assign src_ready = upload_ready;
    assign upload_data = src_data;
    assign upload_valid = src_valid;
    assign upload_sop = src_sop;
    assign upload_eop = src_eop;
`else
    initial $fatal(1, "Compile with FEB_UPLOAD_BROKEN_ADAPTER or FEB_UPLOAD_DIRECT_READY");
`endif

    feb_system_v3_upload_subsystem_upload_pkt_mux u_generated_upload_pkt_mux (
        .out_channel       (out_channel),
        .out_valid         (out_valid),
        .out_ready         (out_ready),
        .out_data          (out_data),
        .out_startofpacket (out_sop),
        .out_endofpacket   (out_eop),
        .in0_valid         (upload_valid),
        .in0_ready         (upload_ready),
        .in0_data          (upload_data),
        .in0_startofpacket (upload_sop),
        .in0_endofpacket   (upload_eop),
        .in1_valid         (in1_valid),
        .in1_ready         (in1_ready),
        .in1_data          (in1_data),
        .in1_startofpacket (in1_sop),
        .in1_endofpacket   (in1_eop),
        .in2_valid         (in2_valid),
        .in2_ready         (in2_ready),
        .in2_data          (in2_data),
        .in2_startofpacket (in2_sop),
        .in2_endofpacket   (in2_eop),
        .clk               (clk),
        .reset_n           (reset_n)
    );

    assign in1_valid = 1'b0;
    assign in1_data = 36'h0;
    assign in1_sop = 1'b0;
    assign in1_eop = 1'b0;

    assign in2_valid = reset_n;
    assign in2_data = RUNCTL_IDLE_WORD;
    assign in2_sop = 1'b1;
    assign in2_eop = 1'b1;

    assign out_ready = reset_n
        && (stall_count == 0)
        && !(src_valid && src_eop && !stall_armed_for_packet);

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            cycle_count <= 0;
            source_beat <= 0;
            source_period <= 0;
            src_valid <= 1'b0;
            src_sop <= 1'b0;
            src_eop <= 1'b0;
            src_empty <= 1'b0;
            src_data <= 36'h0;
            stall_count <= 0;
            stall_armed_for_packet <= 1'b0;
            in0_valid_held_cycles <= 0;
            in0_ready_pulses <= 0;
            in2_ready_pulses <= 0;
            idle_words_seen <= 0;
            in0_eop_offered <= 0;
            in0_eop_accepted <= 0;
            stall_windows <= 0;
        end else begin
            cycle_count <= cycle_count + 1'b1;

            if (stall_count != 0)
                stall_count <= stall_count - 1'b1;
            if (src_valid && src_eop && !stall_armed_for_packet) begin
                stall_count <= STALL_CYCLES;
                stall_armed_for_packet <= 1'b1;
                stall_windows <= stall_windows + 1'b1;
            end

`ifdef FEB_UPLOAD_BROKEN_ADAPTER
            source_period <= (source_period == PERIOD_CYCLES - 1) ? 0 : source_period + 1'b1;
            src_valid <= (source_period < PACKET_BEATS);
            src_sop <= (source_period == 0);
            src_eop <= (source_period == PACKET_BEATS - 1);
            src_data <= {4'h3, 8'hA5, source_period[11:0], cycle_count[11:0]};
            if (source_period == PACKET_BEATS - 1)
                stall_armed_for_packet <= 1'b0;
`else
            if (!src_valid) begin
                if (source_period == PERIOD_CYCLES - 1) begin
                    source_period <= 0;
                    source_beat <= 0;
                    src_valid <= 1'b1;
                    src_sop <= 1'b1;
                    src_eop <= (PACKET_BEATS == 1);
                    src_data <= {4'h3, 8'hA5, 12'd0, cycle_count[11:0]};
                    stall_armed_for_packet <= 1'b0;
                end else begin
                    source_period <= source_period + 1'b1;
                end
            end else if (src_ready) begin
                if (src_eop) begin
                    src_valid <= 1'b0;
                    src_sop <= 1'b0;
                    src_eop <= 1'b0;
                    source_beat <= 0;
                end else begin
                    source_beat <= source_beat + 1'b1;
                    src_sop <= 1'b0;
                    src_eop <= (source_beat == PACKET_BEATS - 2);
                    src_data <= {4'h3, 8'hA5, source_beat[11:0] + 12'd1, cycle_count[11:0]};
                end
            end
`endif

            if (upload_valid)
                in0_valid_held_cycles <= in0_valid_held_cycles + 1'b1;
            if (upload_valid && upload_ready)
                in0_ready_pulses <= in0_ready_pulses + 1'b1;
            if (in2_valid && in2_ready)
                in2_ready_pulses <= in2_ready_pulses + 1'b1;
            if (out_valid && out_ready && out_channel == 2'd2 && out_data[8:0] == 9'h1bc)
                idle_words_seen <= idle_words_seen + 1'b1;
            if (upload_valid && upload_eop)
                in0_eop_offered <= in0_eop_offered + 1'b1;
            if (upload_valid && upload_ready && upload_eop)
                in0_eop_accepted <= in0_eop_accepted + 1'b1;

            if (cycle_count == RUN_CYCLES) begin
                $display("UPLOAD_BACKPRESSURE_SUMMARY mode=%s rate_q16=52 cluster_fix=18448 period_cycles=%0d packet_beats=%0d stall_cycles=%0d in0_valid_held=%0d in0_ready_pulses=%0d in0_eop_offered=%0d in0_eop_accepted=%0d in2_valid=1 in2_ready_pulses=%0d idle_words=%0d stall_windows=%0d",
`ifdef FEB_UPLOAD_BROKEN_ADAPTER
                         "broken_adapter",
`else
                         "direct_ready",
`endif
                         PERIOD_CYCLES,
                         PACKET_BEATS,
                         STALL_CYCLES,
                         in0_valid_held_cycles,
                         in0_ready_pulses,
                         in0_eop_offered,
                         in0_eop_accepted,
                         in2_ready_pulses,
                         idle_words_seen,
                         stall_windows);

                if (expect_broken) begin
                    if (in2_ready_pulses <= 1 && idle_words_seen <= 1 && in0_eop_offered > in0_eop_accepted) begin
                        $display("UPLOAD_BACKPRESSURE_BROKEN_REPRO in0_valid_held=%0d in0_ready_pulses=%0d in2_ready_pulses=%0d idle_words=%0d missed_eop=%0d",
                                 in0_valid_held_cycles,
                                 in0_ready_pulses,
                                 in2_ready_pulses,
                                 idle_words_seen,
                                 in0_eop_offered - in0_eop_accepted);
                    end else begin
                        $fatal(1, "Expected broken adapter starvation, got in2_ready=%0d idle_words=%0d eop_offered=%0d eop_accepted=%0d",
                               in2_ready_pulses,
                               idle_words_seen,
                               in0_eop_offered,
                               in0_eop_accepted);
                    end
                end

                if (expect_fixed) begin
                    if (in2_ready_pulses > 16 && idle_words_seen > 16 && in0_eop_accepted >= stall_windows) begin
                        $display("UPLOAD_BACKPRESSURE_FIXED_PASS in0_valid_held=%0d in0_ready_pulses=%0d in2_ready_pulses=%0d idle_words=%0d eop_accepted=%0d",
                                 in0_valid_held_cycles,
                                 in0_ready_pulses,
                                 in2_ready_pulses,
                                 idle_words_seen,
                                 in0_eop_accepted);
                    end else begin
                        $fatal(1, "Expected direct-ready recovery, got in2_ready=%0d idle_words=%0d eop_accepted=%0d stall_windows=%0d",
                               in2_ready_pulses,
                               idle_words_seen,
                               in0_eop_accepted,
                               stall_windows);
                    end
                end
                $finish;
            end
        end
    end
endmodule
