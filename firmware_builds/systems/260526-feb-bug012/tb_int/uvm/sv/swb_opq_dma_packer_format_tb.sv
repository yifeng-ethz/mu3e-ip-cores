// -----------------------------------------------------------------------------
// swb_opq_dma_packer_format_tb.sv
//
// Directed packet-format test for the SWB OPQ -> DMA packer.
//
// The test drives canonical Mu3e wire frames:
//   K28.5 SOP, timestamp high, timestamp low, 128-subheader count word,
//   send timestamp, 128 subheaders (including zero-hit buckets), hit payloads,
//   and canonical K28.4 EOP.
//
// The scoreboard checks the exact 32-bit word stream reconstructed from DMA
// slots, not only hit metadata. With +BACKPRESSURE, DMA halffull pulses over
// selected OPQ words; the packer must preserve the full packet format.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module swb_opq_dma_packer_format_tb;

    localparam int unsigned N_SHD_CONST       = 128;
    localparam int unsigned N_FRAMES_CONST    = 3;
    localparam int unsigned SLOTS_PER_DMA     = 8;
    localparam int unsigned PACKER_FIFO_DEPTH = 16;
    localparam logic [7:0]  K285_CONST        = 8'hbc;
    localparam logic [7:0]  K284_CONST        = 8'h9c;
    localparam logic [7:0]  K237_CONST        = 8'hf7;

    typedef struct packed {
        logic [31:0] data;
        logic [3:0]  datak;
    } wire_word_t;

    logic         clk       = 1'b0;
    logic         reset_n   = 1'b0;
    logic [31:0]  opq_data  = '0;
    logic [3:0]   opq_datak = '0;
    logic         opq_valid = 1'b0;
    logic         opq_sop   = 1'b0;
    logic         opq_eop   = 1'b0;
    logic         opq_ready;
    logic         halffull  = 1'b0;

    logic [255:0] dma_data;
    logic [31:0]  dma_datak;
    logic         dma_wen;
    logic         end_of_event;
    logic [31:0]  input_word_cnt;
    logic [31:0]  output_word_cnt;
    logic [31:0]  event_cnt;
    logic [31:0]  halt_cnt;

    bit           enable_backpressure;
    int unsigned  offered_word_idx;
    int unsigned  drive_cycle;
    int unsigned  observed_eoe_count;
    int unsigned  fail_count;
    bit           ready_low_seen;
    bit           dma_monitor_in_frame;
    wire_word_t   expected_words[$];
    wire_word_t   observed_words[$];

    swb_opq_dma_packer #(
        .BACKPRESSURE_FIFO_DEPTH(PACKER_FIFO_DEPTH)
    ) u_dut (
        .i_clk            (clk),
        .i_reset_n        (reset_n),
        .i_opq_data       (opq_data),
        .i_opq_datak      (opq_datak),
        .i_opq_valid      (opq_valid),
        .i_opq_sop        (opq_sop),
        .i_opq_eop        (opq_eop),
        .o_opq_ready      (opq_ready),
        .i_dma_halffull   (halffull),
        .o_dma_data       (dma_data),
        .o_dma_datak      (dma_datak),
        .o_dma_wen        (dma_wen),
        .o_end_of_event   (end_of_event),
        .o_input_word_cnt (input_word_cnt),
        .o_output_word_cnt(output_word_cnt),
        .o_event_cnt      (event_cnt),
        .o_halt_cnt       (halt_cnt)
    );

    always #5 clk = ~clk;

    function automatic int unsigned hit_count_for(
        input int unsigned frame_id,
        input int unsigned shd
    );
        if (((frame_id + shd) % 37) == 0) begin
            return 2;
        end
        if (((frame_id + shd) % 5) == 0) begin
            return 1;
        end
        return 0;
    endfunction

    function automatic int unsigned frame_hit_count(input int unsigned frame_id);
        int unsigned total;
        begin
            total = 0;
            for (int unsigned shd = 0; shd < N_SHD_CONST; shd++) begin
                total += hit_count_for(frame_id, shd);
            end
            return total;
        end
    endfunction

    function automatic logic [31:0] sop_word(input int unsigned frame_id);
        return {6'h01, frame_id[17:0], K285_CONST};
    endfunction

    function automatic logic [31:0] ts_hi_word(input int unsigned frame_id);
        return {16'h0000, frame_id[15:0]};
    endfunction

    function automatic logic [31:0] ts_lo_word(input int unsigned frame_id);
        return 32'h0010_0000 + (frame_id * 32'h0000_0800);
    endfunction

    function automatic logic [31:0] count_word(input int unsigned frame_id);
        return {1'b0, N_SHD_CONST[14:0], frame_hit_count(frame_id)[15:0]};
    endfunction

    function automatic logic [31:0] send_ts_word(input int unsigned frame_id);
        return 32'h5a00_0000 | frame_id[15:0];
    endfunction

    function automatic logic [31:0] subheader_word(
        input int unsigned frame_id,
        input int unsigned shd
    );
        return {shd[7:0], hit_count_for(frame_id, shd)[15:0], K237_CONST};
    endfunction

    function automatic logic [31:0] hit_word(
        input int unsigned frame_id,
        input int unsigned shd,
        input int unsigned hit
    );
        return 32'h8000_0000 | (frame_id[7:0] << 20) | (shd[7:0] << 4) | hit[3:0];
    endfunction

    function automatic bit word_is_sop(input wire_word_t word);
        return (word.datak == 4'h1) && (word.data[7:0] == K285_CONST);
    endfunction

    function automatic bit word_is_eop(input wire_word_t word);
        return (word.datak == 4'h1) && (word.data[7:0] == K284_CONST);
    endfunction

    function automatic bit backpressure_for_cycle(input int unsigned cycle_idx);
        if (!enable_backpressure) begin
            return 1'b0;
        end
        return ((cycle_idx >= 20)  && (cycle_idx < 90)) ||
               ((cycle_idx >= 180) && (cycle_idx < 255)) ||
               ((cycle_idx >= 360) && (cycle_idx < 430));
    endfunction

    task automatic push_expected(input logic [31:0] data, input logic [3:0] datak);
        wire_word_t word;
        begin
            word.data  = data;
            word.datak = datak;
            expected_words.push_back(word);
        end
    endtask

    task automatic drive_word(
        input logic [31:0] data,
        input logic [3:0]  datak,
        input bit          sop,
        input bit          eop
    );
        bit accepted;
        begin
            accepted = 1'b0;
            while (!accepted) begin
                @(negedge clk);
                opq_data  = data;
                opq_datak = datak;
                opq_valid = 1'b1;
                opq_sop   = sop;
                opq_eop   = eop;
                halffull  = backpressure_for_cycle(drive_cycle);
                drive_cycle++;
                @(posedge clk);
                accepted = opq_ready;
            end
            push_expected(data, datak);
            offered_word_idx++;
        end
    endtask

    task automatic drive_frame(input int unsigned frame_id);
        int unsigned hits;
        begin
            drive_word(sop_word(frame_id),     4'h1, 1'b1, 1'b0);
            drive_word(ts_hi_word(frame_id),   4'h0, 1'b0, 1'b0);
            drive_word(ts_lo_word(frame_id),   4'h0, 1'b0, 1'b0);
            drive_word(count_word(frame_id),   4'h0, 1'b0, 1'b0);
            drive_word(send_ts_word(frame_id), 4'h0, 1'b0, 1'b0);
            for (int unsigned shd = 0; shd < N_SHD_CONST; shd++) begin
                drive_word(subheader_word(frame_id, shd), 4'h1, 1'b0, 1'b0);
                hits = hit_count_for(frame_id, shd);
                for (int unsigned hit = 0; hit < hits; hit++) begin
                    drive_word(hit_word(frame_id, shd, hit), 4'h0, 1'b0, 1'b0);
                end
            end
            drive_word({24'h0, K284_CONST}, 4'h1, 1'b0, 1'b1);
        end
    endtask

    task automatic record_failure(input string message);
        begin
            $display("FAIL: %s", message);
            fail_count++;
        end
    endtask

    task automatic expect_word_at(
        input int unsigned index,
        input logic [31:0] expected_data,
        input logic [3:0]  expected_datak,
        input string       label
    );
        begin
            if (index >= observed_words.size()) begin
                record_failure($sformatf("%s missing at observed index %0d", label, index));
            end else if ((observed_words[index].data !== expected_data) ||
                         (observed_words[index].datak !== expected_datak)) begin
                record_failure($sformatf(
                    "%s mismatch at observed index %0d expected datak=0x%0h data=0x%08h got datak=0x%0h data=0x%08h",
                    label, index, expected_datak, expected_data,
                    observed_words[index].datak, observed_words[index].data));
            end
        end
    endtask

    task automatic check_frame_format(
        input int unsigned frame_id,
        ref   int unsigned index
    );
        int unsigned hits;
        begin
            expect_word_at(index++, sop_word(frame_id), 4'h1,
                           $sformatf("frame%0d SOP", frame_id));
            expect_word_at(index++, ts_hi_word(frame_id), 4'h0,
                           $sformatf("frame%0d timestamp-high", frame_id));
            expect_word_at(index++, ts_lo_word(frame_id), 4'h0,
                           $sformatf("frame%0d timestamp-low", frame_id));
            expect_word_at(index, count_word(frame_id), 4'h0,
                           $sformatf("frame%0d count word", frame_id));
            if (index < observed_words.size()) begin
                if (observed_words[index].data[30:16] != N_SHD_CONST[14:0]) begin
                    record_failure($sformatf(
                        "frame%0d declared subheaders expected %0d got %0d at index %0d",
                        frame_id, N_SHD_CONST, observed_words[index].data[30:16], index));
                end
                if (observed_words[index].data[15:0] != frame_hit_count(frame_id)[15:0]) begin
                    record_failure($sformatf(
                        "frame%0d declared hits expected %0d got %0d at index %0d",
                        frame_id, frame_hit_count(frame_id), observed_words[index].data[15:0], index));
                end
            end
            index++;
            expect_word_at(index++, send_ts_word(frame_id), 4'h0,
                           $sformatf("frame%0d send timestamp", frame_id));
            for (int unsigned shd = 0; shd < N_SHD_CONST; shd++) begin
                expect_word_at(index++, subheader_word(frame_id, shd), 4'h1,
                               $sformatf("frame%0d subheader%0d", frame_id, shd));
                hits = hit_count_for(frame_id, shd);
                for (int unsigned hit = 0; hit < hits; hit++) begin
                    expect_word_at(index++, hit_word(frame_id, shd, hit), 4'h0,
                                   $sformatf("frame%0d subheader%0d hit%0d",
                                             frame_id, shd, hit));
                end
            end
            expect_word_at(index++, {24'h0, K284_CONST}, 4'h1,
                           $sformatf("frame%0d EOP", frame_id));
        end
    endtask

    always_ff @(posedge clk) begin
        bit monitor_in_frame_v;

        if (!reset_n) begin
            ready_low_seen <= 1'b0;
        end else if (opq_valid && !opq_ready) begin
            ready_low_seen <= 1'b1;
        end

        monitor_in_frame_v = dma_monitor_in_frame;
        if (dma_wen) begin
            for (int slot = 0; slot < SLOTS_PER_DMA; slot++) begin
                wire_word_t word;
                word.data  = dma_data[slot*32 +: 32];
                word.datak = dma_datak[slot*4 +: 4];

                if (word_is_sop(word)) begin
                    monitor_in_frame_v = 1'b1;
                end
                if (monitor_in_frame_v) begin
                    observed_words.push_back(word);
                end
                if (word_is_eop(word)) begin
                    monitor_in_frame_v = 1'b0;
                end
            end
            if (end_of_event) begin
                observed_eoe_count++;
            end
        end
        dma_monitor_in_frame <= monitor_in_frame_v;
    end

    initial begin
        int unsigned frame_index;

        enable_backpressure = $test$plusargs("BACKPRESSURE");
        $display("INFO: swb_opq_dma_packer_format_tb backpressure=%0b",
                 enable_backpressure);

        reset_n = 1'b0;
        repeat (6) @(posedge clk);
        reset_n = 1'b1;
        repeat (2) @(posedge clk);

        for (int unsigned frame_id = 0; frame_id < N_FRAMES_CONST; frame_id++) begin
            drive_frame(frame_id);
            @(negedge clk);
            opq_valid = 1'b0;
            opq_sop   = 1'b0;
            opq_eop   = 1'b0;
            halffull  = 1'b0;
            repeat (3) @(posedge clk);
        end

        @(negedge clk);
        opq_valid = 1'b0;
        opq_sop   = 1'b0;
        opq_eop   = 1'b0;
        halffull  = 1'b0;
        repeat (200) @(posedge clk);

        $display("=== swb_opq_dma_packer_format_tb summary ===");
        $display("  expected OPQ words : %0d", expected_words.size());
        $display("  observed DMA words : %0d", observed_words.size());
        $display("  input_word_cnt     : %0d", input_word_cnt);
        $display("  output_word_cnt    : %0d", output_word_cnt);
        $display("  event_cnt          : %0d", event_cnt);
        $display("  observed EOE count : %0d", observed_eoe_count);
        $display("  halt_cnt           : %0d", halt_cnt);
        $display("  ready_low_seen     : %0d", ready_low_seen);

        if (input_word_cnt != expected_words.size()) begin
            record_failure($sformatf("input_word_cnt expected %0d got %0d",
                                     expected_words.size(), input_word_cnt));
        end
        if (event_cnt != N_FRAMES_CONST) begin
            record_failure($sformatf("event_cnt expected %0d got %0d",
                                     N_FRAMES_CONST, event_cnt));
        end
        if (observed_eoe_count != N_FRAMES_CONST) begin
            record_failure($sformatf("EOE count expected %0d got %0d",
                                     N_FRAMES_CONST, observed_eoe_count));
        end
        if (observed_words.size() != expected_words.size()) begin
            record_failure($sformatf("observed non-pad word count expected %0d got %0d",
                                     expected_words.size(), observed_words.size()));
        end
        if (enable_backpressure && !ready_low_seen) begin
            record_failure("expected OPQ ready to deassert under directed RDMA backpressure");
        end
        if (enable_backpressure && (halt_cnt == 0)) begin
            record_failure("expected nonzero halt_cnt under directed RDMA backpressure");
        end
        for (int i = 0; (i < expected_words.size()) && (i < observed_words.size()); i++) begin
            if ((observed_words[i].data !== expected_words[i].data) ||
                (observed_words[i].datak !== expected_words[i].datak)) begin
                record_failure($sformatf(
                    "stream word%0d mismatch expected datak=0x%0h data=0x%08h got datak=0x%0h data=0x%08h",
                    i, expected_words[i].datak, expected_words[i].data,
                    observed_words[i].datak, observed_words[i].data));
                break;
            end
        end

        frame_index = 0;
        for (int unsigned frame_id = 0; frame_id < N_FRAMES_CONST; frame_id++) begin
            check_frame_format(frame_id, frame_index);
        end
        if (frame_index != observed_words.size()) begin
            record_failure($sformatf("packet parser consumed %0d words, observed %0d",
                                     frame_index, observed_words.size()));
        end

        if (fail_count != 0) begin
            $display("FAIL: swb_opq_dma_packer_format_tb failures=%0d", fail_count);
            $finish(1);
        end

        $display("PASS: swb_opq_dma_packer_format_tb");
        $finish(0);
    end

    initial begin
        #5000000;
        $display("FAIL: timeout");
        $finish(2);
    end

endmodule
