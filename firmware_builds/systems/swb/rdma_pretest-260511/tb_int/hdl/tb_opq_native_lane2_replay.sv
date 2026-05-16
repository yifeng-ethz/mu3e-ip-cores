`timescale 1ns/1ps

// Focused replay for the active SWB native-SV OPQ path. The stimulus drives
// legal FEB-v3 Mu3e data frames on logical lane 2 for a RUNNING-equivalent
// window longer than 1 ms and checks the raw OPQ egress frame contract.
module tb_opq_native_lane2_replay;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned N_LANE = 4;
    localparam int unsigned ACTIVE_LANE_CONST = 2;
    localparam int unsigned DEFAULT_ACTIVE_LANE_MASK_CONST = 1 << ACTIVE_LANE_CONST;
    localparam int unsigned DEFAULT_FRAME_COUNT_CONST = 64;
    localparam int unsigned DEFAULT_FRAME_PERIOD_CYCLES_CONST = 2048;
    localparam int unsigned DEFAULT_DRAIN_CYCLES_CONST = 100000;
    localparam logic [7:0] K285_CONST = 8'hBC;
    localparam logic [7:0] K237_CONST = 8'hF7;
    localparam logic [7:0] K284_CONST = 8'h9C;
    localparam logic [31:0] FEB_V3_SCI_DATA_SOP_CONST = 32'hA50000BC;

    logic clk;
    logic reset_n;
    logic d_reset;

    logic [N_LANE-1:0][35:0] asi_data;
    logic [N_LANE-1:0]       asi_valid;
    logic [N_LANE-1:0][1:0]  asi_channel;
    logic [N_LANE-1:0]       asi_sop;
    logic [N_LANE-1:0]       asi_eop;
    logic [N_LANE-1:0][2:0]  asi_error;

    logic [35:0] aso_data;
    logic        aso_valid;
    logic        aso_ready;
    logic        aso_sop;
    logic        aso_eop;
    logic [2:0]  aso_error;

    logic [8:0]  csr_address;
    logic        csr_read;
    logic        csr_write;
    logic [31:0] csr_writedata;
    logic [31:0] csr_readdata;
    logic        csr_readdatavalid;
    logic        csr_waitrequest;
    logic        csr_burstcount;

    longint unsigned cycle_count;
    int unsigned frame_count;
    int unsigned frame_period_cycles;
    int unsigned drain_cycles;
    int unsigned active_lane_mask;

    int unsigned checker_errors;
    int unsigned egress_frames;
    bit          in_frame;
    int unsigned word_index;
    int unsigned declared_subheaders;
    int unsigned declared_hits;
    int unsigned seen_subheaders;
    int unsigned seen_hits;
    int unsigned hits_left;
    logic [7:0]  last_subheader_ts;
    bit          last_subheader_valid;
    logic [15:0] last_frame_serial;
    bit          last_frame_serial_valid;

    function automatic logic [35:0] make_preamble();
        return {4'h1, FEB_V3_SCI_DATA_SOP_CONST};
    endfunction

    function automatic logic [35:0] make_header(input logic [31:0] word_v);
        return {4'h0, word_v};
    endfunction

    function automatic logic [35:0] make_subheader(input logic [7:0] subheader_ts_v,
                                                   input logic [15:0] hit_count_v);
        return {4'h1, subheader_ts_v, hit_count_v, K237_CONST};
    endfunction

    function automatic logic [35:0] make_hit(input int unsigned frame_idx_v,
                                             input int unsigned hit_idx_v);
        return {4'h0, hit_idx_v[3:0], 8'h52, frame_idx_v[15:0], hit_idx_v[7:0]};
    endfunction

    function automatic logic [35:0] make_trailer();
        return {4'h1, 24'h0, K284_CONST};
    endfunction

    function automatic bit is_preamble(input logic [35:0] word_v);
        return (word_v[35:32] == 4'h1) && (word_v[7:0] == K285_CONST);
    endfunction

    function automatic bit is_subheader(input logic [35:0] word_v);
        return (word_v[35:32] == 4'h1) && (word_v[7:0] == K237_CONST);
    endfunction

    function automatic bit is_trailer(input logic [35:0] word_v);
        return (word_v[35:32] == 4'h1) && (word_v[7:0] == K284_CONST);
    endfunction

    function automatic bit is_hit(input logic [35:0] word_v);
        return word_v[35:32] == 4'h0;
    endfunction

    task automatic note_error(input string reason_v);
        checker_errors++;
        $error("OPQ_NATIVE_LANE2_CHECK %s time=%0t word_index=%0d data=0x%09h sop=%0b eop=%0b",
               reason_v, $time, word_index, aso_data, aso_sop, aso_eop);
    endtask

    task automatic drive_beat(input int unsigned lane_v,
                              input logic [35:0] word_v,
                              input bit sop_v,
                              input bit eop_v);
        @(posedge clk);
        asi_data[lane_v]  <= word_v;
        asi_valid[lane_v] <= 1'b1;
        asi_sop[lane_v]   <= sop_v;
        asi_eop[lane_v]   <= eop_v;
        @(posedge clk);
        asi_valid[lane_v] <= 1'b0;
        asi_sop[lane_v]   <= 1'b0;
        asi_eop[lane_v]   <= 1'b0;
        asi_data[lane_v]  <= '0;
    endtask

    task automatic drive_frame(input int unsigned lane_v,
                               input int unsigned frame_idx_v);
        logic [7:0] page_base_v;
        int unsigned hit_subheader_v;

        page_base_v = frame_idx_v[0] ? 8'd128 : 8'd0;
        hit_subheader_v = (frame_idx_v >> 1) % 128;

        drive_beat(lane_v, make_preamble(), 1'b1, 1'b0);
        drive_beat(lane_v, make_header({16'h2026, frame_idx_v[15:0]}), 1'b0, 1'b0);
        drive_beat(lane_v, make_header({page_base_v[7:4], 12'h000, frame_idx_v[15:0]}), 1'b0, 1'b0);
        drive_beat(lane_v, make_header({16'd128, 16'd1}), 1'b0, 1'b0);
        drive_beat(lane_v, make_header({16'hC001, frame_idx_v[15:0]}), 1'b0, 1'b0);
        for (int unsigned shd = 0; shd < 128; shd++) begin
            logic [15:0] hit_count_v;
            hit_count_v = (shd == hit_subheader_v) ? 16'd1 : 16'd0;
            drive_beat(lane_v, make_subheader(page_base_v + shd[7:0], hit_count_v), 1'b0, 1'b0);
            if (hit_count_v != 16'd0) begin
                drive_beat(lane_v, make_hit(frame_idx_v, 0), 1'b0, 1'b0);
            end
        end
        drive_beat(lane_v, make_trailer(), 1'b0, 1'b1);
    endtask

    task automatic drive_frame_group(input logic [N_LANE-1:0] lane_mask_v,
                                     input int unsigned frame_idx_v);
        fork
            begin
                if (lane_mask_v[0]) begin
                    drive_frame(0, frame_idx_v);
                end
            end
            begin
                if (lane_mask_v[1]) begin
                    drive_frame(1, frame_idx_v);
                end
            end
            begin
                if (lane_mask_v[2]) begin
                    drive_frame(2, frame_idx_v);
                end
            end
            begin
                if (lane_mask_v[3]) begin
                    drive_frame(3, frame_idx_v);
                end
            end
        join
    endtask

    task automatic write_csr(input logic [8:0] addr_v,
                             input logic [31:0] data_v);
        @(posedge clk);
        csr_address   <= addr_v;
        csr_writedata <= data_v;
        csr_write     <= 1'b1;
        @(posedge clk);
        csr_write     <= 1'b0;
        csr_address   <= '0;
        csr_writedata <= '0;
    endtask

    always #4 clk = ~clk;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            checker_errors          <= 0;
            egress_frames           <= 0;
            in_frame                <= 1'b0;
            word_index              <= 0;
            declared_subheaders     <= 0;
            declared_hits           <= 0;
            seen_subheaders         <= 0;
            seen_hits               <= 0;
            hits_left               <= 0;
            last_subheader_ts       <= '0;
            last_subheader_valid    <= 1'b0;
            last_frame_serial       <= '0;
            last_frame_serial_valid <= 1'b0;
        end else if (aso_valid && aso_ready) begin
            int unsigned idx_v;
            logic [15:0] hit_count_v;
            logic [15:0] serial_v;
            int unsigned expected_words_v;

            idx_v = aso_sop ? 0 : (word_index + 1);

            if (aso_error != 3'b000) begin
                note_error("egress error sideband asserted");
            end
            if (aso_sop && !is_preamble(aso_data)) begin
                note_error("SOP asserted without K28.5 preamble");
            end
            if (aso_eop && !is_trailer(aso_data)) begin
                note_error("EOP asserted without K28.4 trailer");
            end
            if (!in_frame && !aso_sop) begin
                note_error("data beat outside frame");
            end
            if (in_frame && aso_sop) begin
                note_error("SOP before previous frame trailer");
            end

            if (aso_sop) begin
                in_frame             <= 1'b1;
                word_index           <= 0;
                declared_subheaders  <= 0;
                declared_hits        <= 0;
                seen_subheaders      <= 0;
                seen_hits            <= 0;
                hits_left            <= 0;
                last_subheader_ts    <= '0;
                last_subheader_valid <= 1'b0;
            end else begin
                word_index <= idx_v;
            end

            if (idx_v == 0) begin
                if (!is_preamble(aso_data)) begin
                    note_error("frame word 0 is not preamble");
                end
            end else if (idx_v == 2) begin
                serial_v = aso_data[15:0];
                if (last_frame_serial_valid && (serial_v != (last_frame_serial + 16'd1))) begin
                    note_error("frame serial is not consecutive");
                end
                last_frame_serial       <= serial_v;
                last_frame_serial_valid <= 1'b1;
            end else if (idx_v == 3) begin
                if (aso_data[31:16] != 16'd128) begin
                    note_error("header declares a non-128 subheader frame");
                end
                declared_subheaders <= aso_data[31:16];
                declared_hits       <= aso_data[15:0];
            end else if (idx_v >= 5) begin
                if (is_trailer(aso_data)) begin
                    expected_words_v = 5 + declared_subheaders + declared_hits + 1;
                    if (hits_left != 0) begin
                        note_error("trailer arrived before declared hit payload finished");
                    end
                    if (seen_subheaders != declared_subheaders) begin
                        note_error("trailer arrived before declared subheaders finished");
                    end
                    if (seen_hits != declared_hits) begin
                        note_error("trailer hit count does not match header declaration");
                    end
                    if ((idx_v + 1) != expected_words_v) begin
                        note_error("frame accepted word length does not match declaration");
                    end
                    egress_frames <= egress_frames + 1;
                    in_frame <= 1'b0;
                    hits_left <= 0;
                end else if (is_subheader(aso_data)) begin
                    if (hits_left != 0) begin
                        note_error("subheader arrived before prior declared hits finished");
                    end
                    if (last_subheader_valid &&
                        (aso_data[31:24] != (last_subheader_ts + 8'd1))) begin
                        note_error("subheader timestamp is not consecutive");
                    end
                    hit_count_v = aso_data[23:8];
                    seen_subheaders <= seen_subheaders + 1;
                    hits_left <= hit_count_v;
                    last_subheader_ts <= aso_data[31:24];
                    last_subheader_valid <= 1'b1;
                end else if (is_hit(aso_data)) begin
                    if (hits_left == 0) begin
                        note_error("hit beat without active hit declaration");
                    end else begin
                        hits_left <= hits_left - 1;
                        seen_hits <= seen_hits + 1;
                    end
                end else begin
                    note_error("unclassified word inside frame");
                end
            end
        end
    end

    ordered_priority_queue_dut_sv dut (
        .asi_ingress_0_data         (asi_data[0]),
        .asi_ingress_0_valid        ({asi_valid[0]}),
        .asi_ingress_0_channel      (asi_channel[0]),
        .asi_ingress_0_startofpacket({asi_sop[0]}),
        .asi_ingress_0_endofpacket  ({asi_eop[0]}),
        .asi_ingress_0_error        (asi_error[0]),
        .asi_ingress_1_data         (asi_data[1]),
        .asi_ingress_1_valid        ({asi_valid[1]}),
        .asi_ingress_1_channel      (asi_channel[1]),
        .asi_ingress_1_startofpacket({asi_sop[1]}),
        .asi_ingress_1_endofpacket  ({asi_eop[1]}),
        .asi_ingress_1_error        (asi_error[1]),
        .asi_ingress_2_data         (asi_data[2]),
        .asi_ingress_2_valid        ({asi_valid[2]}),
        .asi_ingress_2_channel      (asi_channel[2]),
        .asi_ingress_2_startofpacket({asi_sop[2]}),
        .asi_ingress_2_endofpacket  ({asi_eop[2]}),
        .asi_ingress_2_error        (asi_error[2]),
        .asi_ingress_3_data         (asi_data[3]),
        .asi_ingress_3_valid        ({asi_valid[3]}),
        .asi_ingress_3_channel      (asi_channel[3]),
        .asi_ingress_3_startofpacket({asi_sop[3]}),
        .asi_ingress_3_endofpacket  ({asi_eop[3]}),
        .asi_ingress_3_error        (asi_error[3]),
        .aso_egress_data            (aso_data),
        .aso_egress_valid           (aso_valid),
        .aso_egress_ready           (aso_ready),
        .aso_egress_startofpacket   (aso_sop),
        .aso_egress_endofpacket     (aso_eop),
        .aso_egress_error           (aso_error),
        .avs_csr_address            (csr_address),
        .avs_csr_read               (csr_read),
        .avs_csr_write              (csr_write),
        .avs_csr_writedata          (csr_writedata),
        .avs_csr_readdata           (csr_readdata),
        .avs_csr_readdatavalid      (csr_readdatavalid),
        .avs_csr_waitrequest        (csr_waitrequest),
        .avs_csr_burstcount         (csr_burstcount),
        .d_clk                      (clk),
        .d_reset                    (d_reset)
    );

    initial begin
        clk                 = 1'b0;
        reset_n             = 1'b0;
        d_reset             = 1'b1;
        aso_ready           = 1'b1;
        asi_data            = '0;
        asi_valid           = '0;
        asi_sop             = '0;
        asi_eop             = '0;
        asi_error           = '0;
        csr_address         = '0;
        csr_read            = 1'b0;
        csr_write           = 1'b0;
        csr_writedata       = '0;
        csr_burstcount      = 1'b0;
        frame_count         = DEFAULT_FRAME_COUNT_CONST;
        frame_period_cycles = DEFAULT_FRAME_PERIOD_CYCLES_CONST;
        drain_cycles        = DEFAULT_DRAIN_CYCLES_CONST;
        active_lane_mask    = DEFAULT_ACTIVE_LANE_MASK_CONST;

        for (int unsigned lane = 0; lane < N_LANE; lane++) begin
            asi_channel[lane] = lane[1:0];
        end

        void'($value$plusargs("FRAME_COUNT=%d", frame_count));
        void'($value$plusargs("FRAME_PERIOD_CYCLES=%d", frame_period_cycles));
        void'($value$plusargs("DRAIN_CYCLES=%d", drain_cycles));
        void'($value$plusargs("ACTIVE_LANE_MASK=%h", active_lane_mask));

        repeat (16) @(posedge clk);
        reset_n = 1'b1;
        d_reset = 1'b0;
        repeat (16) @(posedge clk);

        // Unmask all lanes and clear counters. This mirrors the default SWB
        // data path, while keeping the CSR side deterministic in simulation.
        write_csr(9'h002, 32'h0000_0000);
        write_csr(9'h003, 32'h0000_0001);

        for (int unsigned frame = 0; frame < frame_count; frame++) begin
            longint unsigned frame_start_cycle;
            frame_start_cycle = cycle_count;
            drive_frame_group(active_lane_mask[N_LANE-1:0], frame);
            while ((cycle_count - frame_start_cycle) < frame_period_cycles) begin
                @(posedge clk);
            end
        end

        repeat (drain_cycles) @(posedge clk);

        if (checker_errors != 0) begin
            $fatal(1, "OPQ native lane2 replay failed: checker_errors=%0d egress_frames=%0d",
                   checker_errors, egress_frames);
        end
        if (egress_frames < frame_count) begin
            $fatal(1, "OPQ native lane2 replay drained only %0d/%0d frames",
                   egress_frames, frame_count);
        end

        $display("*** TEST PASSED *** OPQ_NATIVE_LANE2_REPLAY active_lane_mask=0x%0h frames=%0d period_cycles=%0d running_cycles=%0d running_time_ns=%0d",
                 active_lane_mask[N_LANE-1:0],
                 egress_frames,
                 frame_period_cycles,
                 frame_count * frame_period_cycles,
                 frame_count * frame_period_cycles * 8);
        $finish;
    end
endmodule
