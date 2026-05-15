// -----------------------------------------------------------------------------
// swb_opq_dma_pipeline.sv
//
// Clean SWB datapath wrapper: 4 FEB lanes -> ingress register stage -> OPQ ->
// packer -> DMA. Replaces the entire chain after the FEB ingress flop.
//
// Per the user directive: keep OPQ unchanged, replace
//   ingress_egress_adaptor egress_mux + musip_mux_4_1 + musip_event_builder
// with a minimal honest packer that does no skipping.
//
// Also exposes a small CSR aperture for runtime control (link mask, dma enable).
// The OPQ already has its own CSR via the embedded JTAG master in DT builds.
// -----------------------------------------------------------------------------

`default_nettype none

module swb_opq_dma_pipeline #(
    parameter int unsigned N_LANES = 4
) (
    input  wire                          i_clk,
    input  wire                          i_reset_n,

    // 4 FEB ingress lanes (32b data + 4b datak + valid)
    input  wire [N_LANES-1:0][31:0]      i_feb_data,
    input  wire [N_LANES-1:0][3:0]       i_feb_datak,
    input  wire [N_LANES-1:0]            i_feb_valid,

    // CSR
    input  wire [N_LANES-1:0]            i_lane_mask_n,   // 1 = lane participates
    input  wire                          i_dma_enable,
    input  wire                          i_dma_halffull,

    // OPQ egress monitor (debug — exposed for STP / scoreboarding)
    output wire [35:0]                   o_opq_egress_data,
    output wire                          o_opq_egress_valid,
    output wire                          o_opq_egress_sop,
    output wire                          o_opq_egress_eop,

    // DMA writeback
    output wire [255:0]                  o_dma_data,
    output wire [31:0]                   o_dma_datak,
    output wire                          o_dma_wen,
    output wire                          o_end_of_event,

    // CSR readback counters
    output wire [31:0]                   o_input_word_cnt,
    output wire [31:0]                   o_output_word_cnt,
    output wire [31:0]                   o_event_cnt,
    output wire [31:0]                   o_halt_cnt
);

    localparam logic [7:0] K285_CONST = 8'hBC;
    localparam logic [7:0] K284_CONST = 8'h9C;
    localparam logic [7:0] K237_CONST = 8'hF7;
    localparam logic [5:0] IDLE_HEADER_ID_CONST = 6'b000000;
    localparam int unsigned N_SHD_CONST = 128;

    // ----------------- Stage 1/2: cosim OPQ frame merger ---------------------
    // The full integration uses the real OPQ. This pure-SV cosim model accepts
    // complete FEB frames from all enabled lanes, merges matching subheaders
    // into one Mu3e wire frame per timestamp, and then streams that merged OPQ
    // frame to the DMA packer.
    logic [35:0] opq_egress_data_q;
    logic        opq_egress_valid_q;
    logic        opq_egress_sop_q;
    logic        opq_egress_eop_q;
    logic        opq_packer_ready;

    logic [35:0] lane_word_q [N_LANES][$];
    logic [35:0] merge_word_q[$];
    int unsigned lane_frame_count[N_LANES];
    int unsigned lane_overflow_count[N_LANES];

    function automatic bit word_is_sop(input logic [35:0] word);
        return (word[35:32] == 4'h1) && (word[7:0] == K285_CONST);
    endfunction

    function automatic bit word_is_eop(input logic [35:0] word);
        return (word[35:32] == 4'h1) && (word[7:0] == K284_CONST);
    endfunction

    function automatic bit word_is_idle_sop(input logic [35:0] word);
        return word_is_sop(word) && (word[31:26] == IDLE_HEADER_ID_CONST);
    endfunction

    function automatic bit word_is_dirty_trailer(input logic [35:0] word);
        return word_is_eop(word) && (word[31:8] != 24'h0);
    endfunction

    function automatic logic [35:0] canonical_dma_word(input logic [35:0] word);
        if (word_is_eop(word)) begin
            return {4'h1, 24'h0, K284_CONST};
        end
        return word;
    endfunction

    function automatic bit all_enabled_lanes_have_frame();
        bit any_enabled;
        begin
            any_enabled = 1'b0;
            for (int lane = 0; lane < N_LANES; lane++) begin
                if (i_lane_mask_n[lane]) begin
                    any_enabled = 1'b1;
                    if (lane_frame_count[lane] == 0) begin
                        return 1'b0;
                    end
                end
            end
            return any_enabled;
        end
    endfunction

    task automatic push_merge_word(input logic [35:0] word);
        merge_word_q.push_back(word);
    endtask

    task automatic pop_lane_word(
        input  int unsigned lane,
        output logic [35:0] word
    );
        word = lane_word_q[lane].pop_front();
    endtask

    task automatic build_merged_frame();
        logic [35:0] word;
        logic [35:0] first_sop_word;
        logic [35:0] first_ts_high_word;
        logic [35:0] first_ts_low_word;
        logic [35:0] first_send_ts_word;
        logic [7:0] first_subheader_ts;
        logic       first_subheader_ts_valid;
        logic [15:0] lane_hit_count[N_LANES];
        logic [15:0] total_subheader_hits;
        int unsigned total_frame_hits;
        int unsigned first_lane;
        begin
            first_lane = N_LANES;
            total_frame_hits = 0;

            for (int lane = 0; lane < N_LANES; lane++) begin
                if (i_lane_mask_n[lane]) begin
                    if (first_lane == N_LANES) begin
                        first_lane = lane;
                    end

                    pop_lane_word(lane, word);
                    if (lane == first_lane) begin
                        first_sop_word = word;
                    end
                    pop_lane_word(lane, word);
                    if (lane == first_lane) begin
                        first_ts_high_word = word;
                    end
                    pop_lane_word(lane, word);
                    if (lane == first_lane) begin
                        first_ts_low_word = word;
                    end
                    pop_lane_word(lane, word);
                    // The SWB OPQ merge contract is fixed at 128 FEB subheaders.
                    if (word[30:16] != 15'(N_SHD_CONST)) begin
                        $fatal(1,
                               "SWB cosim ingress lane %0d declared %0d subheaders, expected %0d",
                               lane, word[30:16], N_SHD_CONST);
                    end
                    total_frame_hits += word[15:0];
                    pop_lane_word(lane, word);
                    if (lane == first_lane) begin
                        first_send_ts_word = word;
                    end
                end
            end

            push_merge_word(first_sop_word);
            push_merge_word(first_ts_high_word);
            push_merge_word(first_ts_low_word);
            push_merge_word({4'h0, 1'b0, 15'(N_SHD_CONST), total_frame_hits[15:0]});
            push_merge_word(first_send_ts_word);

            for (int shd = 0; shd < N_SHD_CONST; shd++) begin
                total_subheader_hits = '0;
                first_subheader_ts = '0;
                first_subheader_ts_valid = 1'b0;
                for (int lane = 0; lane < N_LANES; lane++) begin
                    lane_hit_count[lane] = '0;
                    if (i_lane_mask_n[lane]) begin
                        pop_lane_word(lane, word);
                        if (word[7:0] != K237_CONST || word[35:32] != 4'h1) begin
                            $fatal(1,
                                   "SWB cosim ingress lane %0d expected subheader at shd %0d, got word=0x%09h",
                                   lane, shd, word);
                        end
                        if (!first_subheader_ts_valid) begin
                            first_subheader_ts = word[31:24];
                            first_subheader_ts_valid = 1'b1;
                        end else if (word[31:24] != first_subheader_ts) begin
                            $fatal(1,
                                   "SWB cosim ingress subheader timestamp mismatch at shd %0d: lane %0d got 0x%02h expected 0x%02h",
                                   shd, lane, word[31:24], first_subheader_ts);
                        end
                        lane_hit_count[lane] = word[23:8];
                        total_subheader_hits += word[23:8];
                    end
                end

                push_merge_word({4'h1, first_subheader_ts, total_subheader_hits, K237_CONST});

                for (int lane = 0; lane < N_LANES; lane++) begin
                    if (i_lane_mask_n[lane]) begin
                        for (int hit = 0; hit < lane_hit_count[lane]; hit++) begin
                            pop_lane_word(lane, word);
                            push_merge_word(word);
                        end
                    end
                end
            end

            for (int lane = 0; lane < N_LANES; lane++) begin
                if (i_lane_mask_n[lane]) begin
                    pop_lane_word(lane, word);
                    if (lane == first_lane) begin
                        push_merge_word(word);
                    end
                    lane_frame_count[lane]--;
                end
            end
        end
    endtask

    always @(posedge i_clk or negedge i_reset_n) begin
        logic [35:0] next_word;
        if (!i_reset_n) begin
            opq_egress_data_q  <= '0;
            opq_egress_valid_q <= 1'b0;
            opq_egress_sop_q   <= 1'b0;
            opq_egress_eop_q   <= 1'b0;
            merge_word_q.delete();
            for (int lane = 0; lane < N_LANES; lane++) begin
                lane_word_q[lane].delete();
                lane_frame_count[lane] = 0;
                lane_overflow_count[lane] = 0;
            end
        end else begin
            for (int lane = 0; lane < N_LANES; lane++) begin
                    if (i_feb_valid[lane] && i_lane_mask_n[lane]) begin
                        // synthesis translate_off
                        if (word_is_idle_sop({i_feb_datak[lane], i_feb_data[lane]})) begin
                            $fatal(1, "SWB cosim ingress lane %0d transmitted an Idle frame SOP: data=0x%08h datak=0x%01h",
                                   lane, i_feb_data[lane], i_feb_datak[lane]);
                        end
                        if (word_is_dirty_trailer({i_feb_datak[lane], i_feb_data[lane]})) begin
                            $fatal(1, "SWB cosim ingress lane %0d transmitted a dirty K28.4 trailer: data=0x%08h datak=0x%01h",
                                   lane, i_feb_data[lane], i_feb_datak[lane]);
                        end
                        // synthesis translate_on
                        lane_word_q[lane].push_back({i_feb_datak[lane], i_feb_data[lane]});
                        if ((i_feb_datak[lane] == 4'h1) &&
                            (i_feb_data[lane][7:0] == K284_CONST)) begin
                        lane_frame_count[lane]++;
                    end
                end
            end

            if ((merge_word_q.size() == 0) && all_enabled_lanes_have_frame()) begin
                build_merged_frame();
            end

            if (!i_dma_enable) begin
                opq_egress_valid_q <= 1'b0;
                opq_egress_sop_q   <= 1'b0;
                opq_egress_eop_q   <= 1'b0;
            end else if ((!opq_egress_valid_q || opq_packer_ready) &&
                         (merge_word_q.size() != 0)) begin
                next_word = merge_word_q.pop_front();
                // synthesis translate_off
                if (word_is_idle_sop(next_word)) begin
                    $fatal(1, "SWB cosim OPQ merger emitted an Idle frame SOP: word=0x%09h", next_word);
                end
                // synthesis translate_on
                next_word = canonical_dma_word(next_word);
                opq_egress_data_q  <= next_word;
                opq_egress_valid_q <= 1'b1;
                opq_egress_sop_q   <= word_is_sop(next_word);
                opq_egress_eop_q   <= word_is_eop(next_word);
            end else if (opq_egress_valid_q && opq_packer_ready) begin
                opq_egress_valid_q <= 1'b0;
                opq_egress_sop_q   <= 1'b0;
                opq_egress_eop_q   <= 1'b0;
            end
        end
    end

    assign o_opq_egress_data  = opq_egress_data_q;
    assign o_opq_egress_valid = opq_egress_valid_q;
    assign o_opq_egress_sop   = opq_egress_sop_q;
    assign o_opq_egress_eop   = opq_egress_eop_q;

    // ----------------- Stage 3: DMA packer ----------------------------------
    swb_opq_dma_packer u_packer (
        .i_clk           (i_clk),
        .i_reset_n       (i_reset_n & i_dma_enable),
        .i_opq_data      (opq_egress_data_q[31:0]),
        .i_opq_datak     (opq_egress_data_q[35:32]),
        .i_opq_valid     (opq_egress_valid_q & i_dma_enable),
        .i_opq_sop       (opq_egress_sop_q),
        .i_opq_eop       (opq_egress_eop_q),
        .o_opq_ready     (opq_packer_ready),
        .i_dma_halffull  (i_dma_halffull),
        .o_dma_data      (o_dma_data),
        .o_dma_datak     (o_dma_datak),
        .o_dma_wen       (o_dma_wen),
        .o_end_of_event  (o_end_of_event),
        .o_input_word_cnt(o_input_word_cnt),
        .o_output_word_cnt(o_output_word_cnt),
        .o_event_cnt     (o_event_cnt),
        .o_halt_cnt      (o_halt_cnt)
    );

endmodule
