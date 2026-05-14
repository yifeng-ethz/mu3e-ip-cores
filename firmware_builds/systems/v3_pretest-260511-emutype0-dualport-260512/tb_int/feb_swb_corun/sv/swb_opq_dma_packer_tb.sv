// -----------------------------------------------------------------------------
// swb_opq_dma_packer_tb.sv — minimal cosim of the new packer.
//
// Stimulus: drive synthetic OPQ-egress-shaped beats (32b data + sop/eop
// markers) at full clk rate. Validate conservation:
//   - sum(opq_valid 32b words) == sum(dma_data 32b slots reconstructed)
//   - dma_event_cnt == # of EOPs
//
// This isolates the packer from FEB/OPQ for fast unit-level confidence
// before integration. Mirrors the cosim discipline used by feb_swb_corun.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module swb_opq_dma_packer_tb;

    localparam int unsigned N_HITS_PER_EVENT = 32;
    localparam int unsigned N_EVENTS         = 100;

    logic         clk        = 1'b0;
    logic         reset_n    = 1'b0;
    logic [31:0]  opq_data   = '0;
    logic [3:0]   opq_datak  = '0;
    logic         opq_valid  = 1'b0;
    logic         opq_sop    = 1'b0;
    logic         opq_eop    = 1'b0;
    logic         halffull   = 1'b0;

    logic [255:0] dma_data;
    logic [31:0]  dma_datak;
    logic         dma_wen;
    logic         end_of_event;
    logic [31:0]  input_word_cnt, output_word_cnt, event_cnt, halt_cnt;

    swb_opq_dma_packer u_dut (
        .i_clk           (clk),
        .i_reset_n       (reset_n),
        .i_opq_data      (opq_data),
        .i_opq_datak     (opq_datak),
        .i_opq_valid     (opq_valid),
        .i_opq_sop       (opq_sop),
        .i_opq_eop       (opq_eop),
        .i_dma_halffull  (halffull),
        .o_dma_data      (dma_data),
        .o_dma_datak     (dma_datak),
        .o_dma_wen       (dma_wen),
        .o_end_of_event  (end_of_event),
        .o_input_word_cnt(input_word_cnt),
        .o_output_word_cnt(output_word_cnt),
        .o_event_cnt     (event_cnt),
        .o_halt_cnt      (halt_cnt)
    );

    always #5 clk = ~clk;  // 100 MHz

    // Scoreboard
    int unsigned dma_words_observed = 0;
    int unsigned dma_eoe_observed   = 0;
    logic [31:0] sb_words[$];

    always_ff @(posedge clk) if (dma_wen) begin
        for (int slot = 0; slot < 8; slot++)
            sb_words.push_back(dma_data[slot*32 +: 32]);
        dma_words_observed += 8;
        if (end_of_event) dma_eoe_observed++;
    end

    int unsigned non_pad_outputs;

    initial begin
        reset_n = 1'b0;
        repeat (5) @(posedge clk);
        reset_n = 1'b1;
        @(posedge clk);

        // Drive 100 events × 32 hits each
        for (int unsigned ev = 0; ev < N_EVENTS; ev++) begin
            for (int unsigned h = 0; h < N_HITS_PER_EVENT; h++) begin
                @(posedge clk);
                opq_data  <= 32'h8000_0000 | (ev << 16) | h;
                opq_datak <= 4'h0;
                opq_valid <= 1'b1;
                opq_sop   <= (h == 0);
                opq_eop   <= (h == N_HITS_PER_EVENT - 1);
            end
            @(posedge clk);
            opq_valid <= 1'b0;
            opq_sop   <= 1'b0;
            opq_eop   <= 1'b0;
            // small inter-event gap
            repeat (3) @(posedge clk);
        end

        // Drain
        opq_valid <= 1'b0;
        repeat (50) @(posedge clk);

        // Validate
        $display("=== TB summary ===");
        $display("  inputs (32b)  : %0d", input_word_cnt);
        $display("  expected hits : %0d", N_EVENTS * N_HITS_PER_EVENT);
        $display("  outputs (256b): %0d", output_word_cnt);
        $display("  events seen   : %0d", event_cnt);
        $display("  expected events: %0d", N_EVENTS);
        $display("  halts         : %0d", halt_cnt);

        if (input_word_cnt !== N_EVENTS * N_HITS_PER_EVENT) begin
            $display("FAIL: input count mismatch");
            $finish(1);
        end
        if (event_cnt !== N_EVENTS) begin
            $display("FAIL: event count mismatch");
            $finish(1);
        end

        // Conservation: each input 32b word should appear in some output slot
        // (allowing for padding zeros in last partial line of each event).
        non_pad_outputs = 0;
        for (int i = 0; i < sb_words.size(); i++)
            if (sb_words[i][31] == 1'b1) non_pad_outputs++;
        $display("  non-pad output 32b words: %0d (vs input %0d)",
                 non_pad_outputs, input_word_cnt);
        if (non_pad_outputs != input_word_cnt) begin
            $display("FAIL: conservation broken");
            $finish(1);
        end

        $display("PASS: swb_opq_dma_packer_tb");
        $finish(0);
    end

    initial begin
        #1000000;
        $display("FAIL: timeout");
        $finish(2);
    end

endmodule
