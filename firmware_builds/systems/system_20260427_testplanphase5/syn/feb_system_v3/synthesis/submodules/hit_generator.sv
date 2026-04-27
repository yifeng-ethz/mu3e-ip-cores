// hit_generator.sv
// Compact MuTRiG event source with one RAM-backed L2 FIFO per lane.
// Version : 26.1.9
// Date    : 20260418
// Change  : Recover the compact bank8 signoff target by keeping the advanced
//           folded modes lightweight and removing redundant per-lane scan
//           state from the shared-bank release path.
//
// External behavior intentionally stays aligned with the existing emulator:
//   - frame_assembler still sees a single dequeue/data/event-count interface
//   - the directed TB compatibility mirrors hit_wr_en/hit_wr_data/fifo_* remain
//   - burst and inject handling still support the shared global cluster domain
//
// Area strategy:
//   - one 48-bit x FIFO_DEPTH lane-local L2 FIFO inferred into M10Ks
//   - no per-channel staging RAMs and no per-group L1 FIFOs
//   - one emitted hit candidate per active clock

module hit_generator
    import emulator_mutrig_pkg::*;
#(
    parameter int FIFO_DEPTH = RAW_FIFO_DEPTH,
    parameter bit ENABLE_LOCAL_MASKED_TRIGGER = 1'b1
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    // Configuration
    input  logic [1:0]  cfg_hit_mode,
    input  logic [15:0] cfg_hit_rate,
    input  logic [4:0]  cfg_burst_size,
    input  logic [4:0]  cfg_burst_center,
    input  logic        cfg_cluster_cross_asic,
    input  logic [7:0]  cfg_cluster_center_global,
    input  logic [3:0]  cfg_cluster_lane_index,
    input  logic [3:0]  cfg_cluster_lane_count,
    input  logic [15:0] cfg_noise_rate,
    input  logic [31:0] cfg_prng_seed,
    input  logic        cfg_short_mode,
    input  logic        inject_pulse,
    input  logic        inject_masked_pulse,
    input  logic [N_CHANNELS-1:0] cfg_inject_channel_mask,

    // Reserved simulation hook. The standalone IP keeps this disabled so the
    // lane datapath does not pay the timing/area cost of an extra offer mux.
    input  logic        sim_offer_valid,
    input  logic [47:0] sim_offer_word,
    output logic        sim_offer_ready,

    // Coarse time reference
    input  logic [14:0] tcc_lfsr,
    input  logic [14:0] ecc_lfsr,

    // L2 dequeue interface to the frame assembler
    input  logic        fifo_rd_en,
    output logic [47:0] fifo_data,
    output logic [9:0]  event_count,
    output logic        fifo_empty,
    output logic        fifo_full,
    output logic        fifo_almost_full
);

    localparam int FIFO_STORAGE_DEPTH   = FIFO_DEPTH;
    localparam int FIFO_TOTAL_DEPTH     = FIFO_DEPTH;
    localparam int FIFO_PTR_WIDTH       = (FIFO_STORAGE_DEPTH > 1) ? $clog2(FIFO_STORAGE_DEPTH) : 1;
    localparam int FIFO_COUNT_WIDTH     = FIFO_PTR_WIDTH + 1;
    localparam int FIFO_VISIBLE_MAX     = (1 << FIFO_PTR_WIDTH) - 1;
    localparam int LANE_INDEX_WIDTH     = GLOBAL_CHANNEL_WIDTH - CHANNEL_WIDTH;
    localparam int DOMAIN_COUNT_WIDTH   = GLOBAL_CHANNEL_WIDTH + 1;
    localparam int FIFO_ALMOST_FULL_LVL =
        (FIFO_TOTAL_DEPTH > FIFO_ALMOST_FULL_MARGIN) ? (FIFO_TOTAL_DEPTH - FIFO_ALMOST_FULL_MARGIN) : FIFO_TOTAL_DEPTH;

    localparam int PRNG1_WIDTH = 21;
    localparam int PRNG2_WIDTH = 5;
    localparam logic [PRNG2_WIDTH-1:0] PRNG2_SEED_XOR = 5'h0F;

    logic [47:0] l2_fifo_mem [0:FIFO_STORAGE_DEPTH-1];

    logic [PRNG1_WIDTH-1:0] prng_state;
    logic [PRNG2_WIDTH-1:0] prng2_state;
    logic [GLOBAL_CHANNEL_WIDTH-1:0] scan_pos;
    logic [CHANNEL_WIDTH-1:0] channel_scan_pos;
    logic [4:0] burst_remaining;
    logic [GLOBAL_CHANNEL_WIDTH-1:0] burst_global_ch;
    logic [7:0] burst_cooldown;
    logic burst_ready;
    logic inject_burst_pending;
    logic [14:0] cluster_tcc_anchor;
    logic [14:0] cluster_ecc_anchor;
    logic [4:0]  cluster_fine_anchor;
    // Directed TB compatibility mirrors.
    logic [FIFO_PTR_WIDTH-1:0] fifo_wr_ptr;
    logic [FIFO_PTR_WIDTH-1:0] fifo_rd_ptr;
    logic [FIFO_COUNT_WIDTH-1:0] fifo_count;
    logic [15:0]              periodic_phase;
    logic                     inject_masked_active;
    logic [N_CHANNELS-1:0]    inject_masked_shift;
    logic [CHANNEL_WIDTH-1:0] inject_masked_channel;
    logic [14:0]              inject_masked_tcc_anchor;
    logic [14:0]              inject_masked_ecc_anchor;
    logic [4:0]               inject_masked_fine_anchor;
    logic                     pending_valid;
    logic [47:0]              pending_word;
    logic                     hit_wr_en;
    logic [47:0]              hit_wr_data;
`ifndef SYNTHESIS
    logic [47:0]              debug_true_gts_8n;
    logic [47:0]              debug_hit_gen_gts_8n;
    logic [47:0]              cluster_true_gts_anchor;
    logic [47:0]              inject_masked_true_gts_anchor;
`endif

    // The frame assembler always consumes the long-word layout. Short-mode
    // normalization happens later during packet assembly.
    logic unused_cfg_short_mode;
    assign unused_cfg_short_mode = cfg_short_mode;

    function automatic logic [4:0] normalized_cluster_size(input logic [4:0] size);
        if (size == 5'd0)
            return 5'd1;
        return size;
    endfunction

    function automatic logic [FIFO_PTR_WIDTH-1:0] fifo_ptr_next(
        input logic [FIFO_PTR_WIDTH-1:0] ptr
    );
        if (ptr == FIFO_PTR_WIDTH'(FIFO_STORAGE_DEPTH - 1))
            return '0;
        return ptr + FIFO_PTR_WIDTH'(1);
    endfunction

    function automatic logic [CLUSTER_LANE_WIDTH-1:0] normalized_lane_count(input logic [3:0] lane_count);
        logic [CLUSTER_LANE_WIDTH-1:0] lane_count_v;

        lane_count_v = lane_count;
        if (lane_count_v < CLUSTER_LANE_WIDTH'(1))
            lane_count_v = CLUSTER_LANE_WIDTH'(1);
        else if (lane_count_v > MAX_EMU_LANES)
            lane_count_v = CLUSTER_LANE_WIDTH'(MAX_EMU_LANES);
        return lane_count_v;
    endfunction

    function automatic logic [DOMAIN_COUNT_WIDTH-1:0] domain_channel_count(
        input logic       cross_asic,
        input logic [3:0] lane_count
    );
        if (!cross_asic)
            return DOMAIN_COUNT_WIDTH'(N_CHANNELS);
        return {normalized_lane_count(lane_count), 5'b0};
    endfunction

    function automatic logic [LANE_INDEX_WIDTH-1:0] normalized_lane_index(
        input logic        cross_asic,
        input logic [3:0]  lane_index,
        input logic [3:0]  lane_count
    );
        logic [CLUSTER_LANE_WIDTH-1:0] lane_count_v;
        logic [CLUSTER_LANE_WIDTH-1:0] lane_index_v;

        if (!cross_asic)
            return LANE_INDEX_WIDTH'(0);

        lane_count_v = normalized_lane_count(lane_count);
        lane_index_v = lane_index;
        if (lane_index_v >= lane_count_v)
            lane_index_v = lane_count_v - CLUSTER_LANE_WIDTH'(1);
        return lane_index_v[LANE_INDEX_WIDTH-1:0];
    endfunction

    function automatic logic [PRNG1_WIDTH-1:0] prng1_seed_init(input logic [31:0] seed_word);
        logic [PRNG1_WIDTH-1:0] seed_v;

        seed_v = seed_word[PRNG1_WIDTH-1:0];
        if (seed_v == '0)
            seed_v = PRNG1_WIDTH'(21'h1);
        return seed_v;
    endfunction

    function automatic logic [PRNG2_WIDTH-1:0] prng2_seed_init(input logic [31:0] seed_word);
        logic [PRNG2_WIDTH-1:0] seed_v;

        seed_v = seed_word[20:16] ^ PRNG2_SEED_XOR;
        if (seed_v == '0)
            seed_v = PRNG2_WIDTH'(5'h1);
        return seed_v;
    endfunction

    function automatic logic [PRNG1_WIDTH-1:0] prng1_step(input logic [PRNG1_WIDTH-1:0] state);
        logic feedback_v;

        feedback_v = state[20] ^ state[1];
        return {state[19:0], feedback_v};
    endfunction

    function automatic logic [PRNG2_WIDTH-1:0] prng2_step(input logic [PRNG2_WIDTH-1:0] state);
        logic feedback_v;

        feedback_v = state[4] ^ state[2];
        return {state[3:0], feedback_v};
    endfunction

    function automatic logic [15:0] prng16_step(input logic [15:0] state);
        logic feedback_v;

        feedback_v = state[15] ^ state[13] ^ state[12] ^ state[10];
        return {state[14:0], feedback_v};
    endfunction

    function automatic logic [15:0] channel_seed_init(
        input logic [31:0] seed_word,
        input logic [4:0]  channel
    );
        logic [15:0] seed_v;

        seed_v = seed_word[15:0] ^ {8'h5A, 3'b000, channel};
        if (seed_v == 16'h0000)
            seed_v = {11'h001, channel};
        return seed_v;
    endfunction

    function automatic logic [15:0] periodic_phase_init(
        input logic [31:0] seed_word,
        input logic [4:0]  channel
    );
        logic [15:0] phase_v;

        phase_v = seed_word[31:16] ^ {8'hC3, 3'b000, channel};
        return phase_v;
    endfunction

    function automatic logic [15:0] folded_channel_rate(
        input logic [15:0] rate_per_channel,
        input int unsigned fold_factor
    );
        logic [31:0] scaled_v;

        scaled_v = rate_per_channel * fold_factor;
        if (scaled_v > 32'h0000_FFFF)
            return 16'hFFFF;
        return scaled_v[15:0];
    endfunction

    function automatic logic [GLOBAL_CHANNEL_WIDTH-1:0] clamp_cluster_start(
        input logic [GLOBAL_CHANNEL_WIDTH-1:0] center,
        input logic [4:0]                 size,
        input logic [DOMAIN_COUNT_WIDTH-1:0] domain_channels
    );
        logic [4:0]                 size_clamped;
        logic [DOMAIN_COUNT_WIDTH-1:0] half_size;
        logic [DOMAIN_COUNT_WIDTH-1:0] center_ext;
        logic [DOMAIN_COUNT_WIDTH-1:0] start_v;
        logic [DOMAIN_COUNT_WIDTH-1:0] max_start;

        size_clamped = normalized_cluster_size(size);
        half_size    = DOMAIN_COUNT_WIDTH'({1'b0, size_clamped} >> 1);
        center_ext   = DOMAIN_COUNT_WIDTH'({1'b0, center});
        max_start    = domain_channels - DOMAIN_COUNT_WIDTH'(size_clamped);

        if (center_ext <= half_size)
            return 0;
        start_v = center_ext - half_size;
        if (start_v > max_start)
            return max_start[GLOBAL_CHANNEL_WIDTH-1:0];
        return start_v[GLOBAL_CHANNEL_WIDTH-1:0];
    endfunction

    function automatic logic [4:0] clamp_fine_with_jitter(
        input logic [4:0] anchor,
        input logic [2:0] pos_rnd,
        input logic [2:0] neg_rnd
    );
        int signed jitter_v;
        int signed fine_v;

        // 250 ps fine LSB -> +/-4 codes is about +/-1 ns.
        jitter_v = $signed({1'b0, pos_rnd}) - $signed({1'b0, neg_rnd});
        if (jitter_v > 4)
            jitter_v = 4;
        else if (jitter_v < -4)
            jitter_v = -4;

        fine_v = anchor + jitter_v;
        if (fine_v < 0)
            fine_v = 0;
        else if (fine_v > 31)
            fine_v = 31;
        return logic'(fine_v[4:0]);
    endfunction

    function automatic logic [47:0] build_l2_hit_from_fine(
        input logic [4:0]  channel,
        input logic [14:0] tcc_base,
        input logic [14:0] ecc_base,
        input logic [4:0]  fine_a_v,
        input logic [4:0]  fine_b_v
    );
        logic [4:0] t_fine_v;
        logic [4:0] e_fine_v;

        // Default long-hit timing contract:
        //   - the hit commits on the energy timestamp
        //   - `E` therefore reflects the current coarse reference
        //   - `T` must never land later than `E`, so sort the two fine samples
        //     and keep both timestamps on the current coarse counter value
        if (fine_a_v <= fine_b_v) begin
            t_fine_v = fine_a_v;
            e_fine_v = fine_b_v;
        end else begin
            t_fine_v = fine_b_v;
            e_fine_v = fine_a_v;
        end

        return pack_hit_long(
            .channel  (channel),
            .t_badhit (1'b0),
            .tcc      (tcc_base),
            .t_fine   (t_fine_v),
            .e_badhit (1'b0),
            // Keep E_Flag aligned with the pre-compaction raw-contract model.
            .e_flag   (1'b1),
            .ecc      (ecc_base),
            .e_fine   (e_fine_v)
        );
    endfunction

    function automatic logic [47:0] build_l2_hit_poisson(
        input logic [4:0]  channel,
        input logic [14:0] tcc_base,
        input logic [14:0] ecc_base,
        input logic [4:0]  t_fine_v,
        input logic [4:0]  e_fine_v
    );
        return build_l2_hit_from_fine(channel, tcc_base, ecc_base, t_fine_v, e_fine_v);
    endfunction

    function automatic logic [47:0] build_l2_hit_cluster(
        input logic [4:0]  channel,
        input logic [14:0] tcc_base,
        input logic [14:0] ecc_base,
        input logic [4:0]  fine_anchor,
        input logic [2:0]  e_pos_rnd,
        input logic [2:0]  e_neg_rnd,
        input logic [2:0]  t_pos_rnd,
        input logic [2:0]  t_neg_rnd
    );
        logic [4:0] t_fine_v;
        logic [4:0] e_fine_v;

        e_fine_v = clamp_fine_with_jitter(fine_anchor, e_pos_rnd, e_neg_rnd);
        t_fine_v = clamp_fine_with_jitter(fine_anchor, t_pos_rnd, t_neg_rnd);
        return build_l2_hit_from_fine(channel, tcc_base, ecc_base, t_fine_v, e_fine_v);
    endfunction

    function automatic logic [47:0] build_l2_hit_masked(
        input logic [4:0]  channel,
        input logic [14:0] tcc_base,
        input logic [14:0] ecc_base,
        input logic [4:0]  fine_anchor
    );
        logic [4:0] t_fine_v;

        if (fine_anchor == 5'd0)
            t_fine_v = 5'd0;
        else
            t_fine_v = fine_anchor - 5'd1;

        return build_l2_hit_from_fine(channel, tcc_base, ecc_base, t_fine_v, fine_anchor);
    endfunction

    always_comb begin : fifo_status_comb
        integer fifo_count_v;
        integer fifo_total_count_v;
        bit     pop_from_mem_c;
        bit     pop_from_pending_c;
        bit     push_from_pending_c;

        fifo_total_count_v = fifo_count + (pending_valid ? 1 : 0);
        fifo_empty       = (fifo_total_count_v == 0);
        fifo_full        = (fifo_total_count_v >= FIFO_TOTAL_DEPTH);
        fifo_almost_full = (fifo_total_count_v >= FIFO_ALMOST_FULL_LVL);
        pop_from_mem_c      = fifo_rd_en && (fifo_count != FIFO_COUNT_WIDTH'(0));
        pop_from_pending_c  = fifo_rd_en && (fifo_count == FIFO_COUNT_WIDTH'(0)) && pending_valid;
        // `pending_valid` can only coexist with at most `FIFO_DEPTH-1` words in
        // RAM, so the pending word always has room to spill into the M10K copy
        // unless it is consumed directly by the assembler in the same cycle.
        push_from_pending_c = pending_valid && !pop_from_pending_c;
        sim_offer_ready     = (fifo_count != FIFO_COUNT_WIDTH'(FIFO_DEPTH)) &&
                              !(pending_valid && (fifo_count == FIFO_COUNT_WIDTH'(FIFO_DEPTH - 1)));

        fifo_count_v = fifo_total_count_v;
        if (fifo_count_v > FIFO_VISIBLE_MAX)
            event_count = 10'(FIFO_VISIBLE_MAX);
        else
            event_count = 10'(fifo_count_v);
    end

    always_ff @(posedge clk) begin : datapath_state
        logic [DOMAIN_COUNT_WIDTH-1:0] domain_channels_v;
        logic [LANE_INDEX_WIDTH-1:0] lane_index_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] domain_last_ch_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] configured_center_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] candidate_global_ch_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] burst_start_v;
        logic [4:0] cluster_size_v;
        logic [4:0] candidate_ch_v;
        logic [47:0] candidate_word_v;
        logic [PRNG1_WIDTH-1:0] prng_state_next_v;
        logic [PRNG2_WIDTH-1:0] prng2_state_next_v;
        logic [4:0] burst_remaining_next_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] burst_global_next_v;
        logic [7:0] burst_cooldown_next_v;
        logic burst_ready_next_v;
        logic [14:0] cluster_tcc_anchor_next_v;
        logic [14:0] cluster_ecc_anchor_next_v;
        logic [4:0]  cluster_fine_anchor_next_v;
        logic inject_burst_pending_next_v;
        logic consume_cluster_word_v;
        logic candidate_local_valid_v;
        logic l2_push_valid_v;
        logic l2_pop_from_mem_v;
        logic l2_pop_from_pending_v;
        logic accept_capacity_v;
        logic pending_valid_next_v;
        logic [47:0] pending_word_next_v;
        logic [4:0] poisson_t_fine_v;
        logic [4:0] poisson_e_fine_v;
        logic inject_pulse_seen_v;
        logic [15:0] folded_hit_rate_v;
        logic [16:0] periodic_phase_sum_v;
        logic [15:0] periodic_phase_next_v;
        logic        inject_masked_active_next_v;
        logic [N_CHANNELS-1:0] inject_masked_shift_next_v;
        logic [CHANNEL_WIDTH-1:0] inject_masked_channel_next_v;
        logic [14:0] inject_masked_tcc_anchor_next_v;
        logic [14:0] inject_masked_ecc_anchor_next_v;
        logic [4:0]  inject_masked_fine_anchor_next_v;
        logic        masked_sequence_word_v;
        logic        launch_cluster_v;
        logic [GLOBAL_CHANNEL_WIDTH-1:0] launch_cluster_start_v;
`ifndef SYNTHESIS
        logic [47:0] debug_true_gts_next_v;
        logic [47:0] cluster_true_gts_anchor_next_v;
        logic [47:0] inject_masked_true_gts_anchor_next_v;
`endif

        if (rst) begin
            prng_state           <= prng1_seed_init(cfg_prng_seed);
            prng2_state          <= prng2_seed_init(cfg_prng_seed);
            scan_pos             <= '0;
            channel_scan_pos     <= '0;
            burst_remaining      <= '0;
            burst_global_ch      <= '0;
            burst_cooldown       <= '0;
            burst_ready          <= 1'b1;
            inject_burst_pending <= 1'b0;
            cluster_tcc_anchor   <= LFSR15_INIT;
            cluster_ecc_anchor   <= LFSR15_INIT;
            cluster_fine_anchor  <= '0;
            fifo_wr_ptr          <= '0;
            fifo_rd_ptr          <= '0;
            fifo_count           <= '0;
            periodic_phase       <= periodic_phase_init(cfg_prng_seed, 5'd0);
            inject_masked_active <= 1'b0;
            inject_masked_shift <= '0;
            inject_masked_channel <= '0;
            inject_masked_tcc_anchor <= LFSR15_INIT;
            inject_masked_ecc_anchor <= LFSR15_INIT;
            inject_masked_fine_anchor <= '0;
            pending_valid        <= 1'b0;
            pending_word         <= '0;
            fifo_data            <= '0;
            hit_wr_en            <= 1'b0;
            hit_wr_data          <= '0;
`ifndef SYNTHESIS
            debug_true_gts_8n    <= '0;
            debug_hit_gen_gts_8n <= '0;
            cluster_true_gts_anchor <= '0;
            inject_masked_true_gts_anchor <= '0;
`endif
        end else begin
            hit_wr_en           <= 1'b0;
            consume_cluster_word_v = 1'b0;
            candidate_local_valid_v = 1'b0;
            candidate_global_ch_v = '0;
            candidate_ch_v = '0;
            candidate_word_v = '0;
            burst_start_v = '0;
            burst_cooldown_next_v = burst_cooldown;
            burst_ready_next_v = burst_ready;
            cluster_tcc_anchor_next_v = cluster_tcc_anchor;
            cluster_ecc_anchor_next_v = cluster_ecc_anchor;
            cluster_fine_anchor_next_v = cluster_fine_anchor;
            inject_pulse_seen_v = inject_pulse;
            inject_burst_pending_next_v = inject_burst_pending | inject_pulse_seen_v;
            burst_remaining_next_v = burst_remaining;
            burst_global_next_v = burst_global_ch;
            poisson_t_fine_v = prng_state[4:0];
            poisson_e_fine_v = prng2_state[4:0];
            l2_pop_from_mem_v     = fifo_rd_en && (fifo_count != FIFO_COUNT_WIDTH'(0));
            l2_pop_from_pending_v = fifo_rd_en && (fifo_count == FIFO_COUNT_WIDTH'(0)) && pending_valid;
            l2_push_valid_v       = pending_valid && !l2_pop_from_pending_v;
            // Total visible occupancy is full only in 2 legal states:
            //   1. RAM holds all 256 words (`fifo_count == FIFO_DEPTH`)
            //   2. RAM holds 255 words and the pending slot holds the 256th
            accept_capacity_v     = (fifo_count != FIFO_COUNT_WIDTH'(FIFO_DEPTH)) &&
                                    !(pending_valid && (fifo_count == FIFO_COUNT_WIDTH'(FIFO_DEPTH - 1)));
            pending_valid_next_v = pending_valid;
            pending_word_next_v  = pending_word;
            folded_hit_rate_v    = folded_channel_rate(cfg_hit_rate, N_CHANNELS);
            periodic_phase_sum_v = 17'h0_0000;
            periodic_phase_next_v = periodic_phase;
            inject_masked_active_next_v = inject_masked_active;
            inject_masked_shift_next_v = inject_masked_shift;
            inject_masked_channel_next_v = inject_masked_channel;
            inject_masked_tcc_anchor_next_v = inject_masked_tcc_anchor;
            inject_masked_ecc_anchor_next_v = inject_masked_ecc_anchor;
            inject_masked_fine_anchor_next_v = inject_masked_fine_anchor;
            masked_sequence_word_v = 1'b0;
            launch_cluster_v = 1'b0;
            launch_cluster_start_v = '0;
`ifndef SYNTHESIS
            debug_true_gts_next_v = debug_true_gts_8n + 48'd1;
            cluster_true_gts_anchor_next_v = cluster_true_gts_anchor;
            inject_masked_true_gts_anchor_next_v = inject_masked_true_gts_anchor;
`endif

            if (l2_push_valid_v || l2_pop_from_pending_v)
                pending_valid_next_v = 1'b0;

            if (enable) begin
                domain_channels_v   = domain_channel_count(cfg_cluster_cross_asic, cfg_cluster_lane_count);
                lane_index_v        = normalized_lane_index(cfg_cluster_cross_asic, cfg_cluster_lane_index, cfg_cluster_lane_count);
                domain_last_ch_v    = domain_channels_v[GLOBAL_CHANNEL_WIDTH-1:0] - GLOBAL_CHANNEL_WIDTH'(1);
                configured_center_v = cfg_cluster_cross_asic ? cfg_cluster_center_global : cfg_burst_center;
                cluster_size_v      = normalized_cluster_size(cfg_burst_size);

                prng_state_next_v  = prng1_step(prng_state);
                prng2_state_next_v = prng2_step(prng2_state);
                prng_state         <= prng_state_next_v;
                prng2_state        <= prng2_state_next_v;

                if (scan_pos >= GLOBAL_CHANNEL_WIDTH'(domain_channels_v - 1))
                    scan_pos <= '0;
                else
                    scan_pos <= scan_pos + GLOBAL_CHANNEL_WIDTH'(1);

                if (channel_scan_pos == CHANNEL_WIDTH'(N_CHANNELS - 1))
                    channel_scan_pos <= '0;
                else
                    channel_scan_pos <= channel_scan_pos + CHANNEL_WIDTH'(1);

                if (burst_cooldown != 8'd0) begin
                    burst_cooldown_next_v = burst_cooldown_next_v - 8'd1;
                    if (burst_cooldown == 8'd1)
                        burst_ready_next_v = 1'b1;
                end

                if (ENABLE_LOCAL_MASKED_TRIGGER &&
                    (inject_masked_active || (inject_masked_pulse && (cfg_inject_channel_mask != '0)))) begin
                    if (!inject_masked_active) begin
                        inject_masked_shift_next_v = cfg_inject_channel_mask;
                        inject_masked_channel_next_v = '0;
                        inject_masked_tcc_anchor_next_v = tcc_lfsr;
                        inject_masked_ecc_anchor_next_v = ecc_lfsr;
                        inject_masked_fine_anchor_next_v = prng2_state[4:0];
`ifndef SYNTHESIS
                        inject_masked_true_gts_anchor_next_v = debug_true_gts_next_v;
`endif
                    end

                    candidate_ch_v = inject_masked_channel_next_v;
                    candidate_local_valid_v = inject_masked_shift_next_v[0];
                    masked_sequence_word_v = 1'b1;
                    inject_masked_shift_next_v = {1'b0, inject_masked_shift_next_v[N_CHANNELS-1:1]};

                    if (inject_masked_channel_next_v == CHANNEL_WIDTH'(N_CHANNELS - 1)) begin
                        inject_masked_active_next_v = 1'b0;
                        inject_masked_channel_next_v = '0;
                    end else begin
                        inject_masked_active_next_v = 1'b1;
                        inject_masked_channel_next_v =
                            inject_masked_channel_next_v + CHANNEL_WIDTH'(1);
                    end
                end else begin
                    if (inject_burst_pending && (burst_remaining == 5'd0)) begin
                        launch_cluster_v = 1'b1;
                        launch_cluster_start_v =
                            clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                        inject_burst_pending_next_v = inject_pulse_seen_v;
                    end else if (burst_remaining != 5'd0) begin
                        consume_cluster_word_v = 1'b1;
                        candidate_global_ch_v = burst_global_ch;
                        burst_remaining_next_v = burst_remaining - 5'd1;
                        if ((burst_remaining != 5'd1) && (burst_global_ch < domain_last_ch_v))
                            burst_global_next_v = burst_global_ch + GLOBAL_CHANNEL_WIDTH'(1);
                        else
                            burst_global_next_v = burst_global_ch;
                    end else begin
                        unique case (hit_mode_t'(cfg_hit_mode))
                        HIT_MODE_POISSON: begin
                            if (prng_state[15:0] < cfg_hit_rate) begin
                                launch_cluster_v = 1'b1;
                                launch_cluster_start_v =
                                    clamp_cluster_start(scan_pos, cfg_burst_size, domain_channels_v);
                            end
                        end

                        HIT_MODE_BURST: begin
                            if (burst_ready) begin
                                launch_cluster_v = 1'b1;
                                launch_cluster_start_v =
                                    clamp_cluster_start(configured_center_v, cfg_burst_size, domain_channels_v);
                                burst_cooldown_next_v = 8'd199;
                                burst_ready_next_v    = 1'b0;
                            end
                        end

                        HIT_MODE_POISSON_IID: begin
                            if (prng_state[15:0] < folded_hit_rate_v) begin
                                candidate_local_valid_v = 1'b1;
                                candidate_ch_v = channel_scan_pos;
                            end
                        end

                        HIT_MODE_PERIODIC: begin
                            periodic_phase_sum_v = {1'b0, periodic_phase} + {1'b0, folded_hit_rate_v};
                            periodic_phase_next_v = periodic_phase_sum_v[15:0];
                            if (periodic_phase_sum_v[16]) begin
                                candidate_local_valid_v = 1'b1;
                                candidate_ch_v = channel_scan_pos;
                            end
                        end

                        default: begin
                            if (prng_state[15:0] < cfg_hit_rate) begin
                                launch_cluster_v = 1'b1;
                                launch_cluster_start_v =
                                    clamp_cluster_start(scan_pos, cfg_burst_size, domain_channels_v);
                            end
                        end
                        endcase
                    end

                    if (launch_cluster_v) begin
                        cluster_tcc_anchor_next_v = tcc_lfsr;
                        cluster_ecc_anchor_next_v = ecc_lfsr;
                        cluster_fine_anchor_next_v = prng2_state[4:0];
`ifndef SYNTHESIS
                        cluster_true_gts_anchor_next_v = debug_true_gts_next_v;
`endif
                        burst_remaining_next_v = cluster_size_v;
                        burst_global_next_v = launch_cluster_start_v;
                    end
                end

                if (consume_cluster_word_v) begin
                    if (!cfg_cluster_cross_asic) begin
                        candidate_local_valid_v = 1'b1;
                        candidate_ch_v = CHANNEL_WIDTH'(candidate_global_ch_v[CHANNEL_WIDTH-1:0]);
                    end else if ((candidate_global_ch_v <= domain_last_ch_v) &&
                                 (candidate_global_ch_v[GLOBAL_CHANNEL_WIDTH-1:5] == lane_index_v)) begin
                        candidate_local_valid_v = 1'b1;
                        candidate_ch_v = CHANNEL_WIDTH'(candidate_global_ch_v[CHANNEL_WIDTH-1:0]);
                    end
                end

                burst_cooldown       <= burst_cooldown_next_v;
                burst_ready          <= burst_ready_next_v;
                cluster_tcc_anchor   <= cluster_tcc_anchor_next_v;
                cluster_ecc_anchor   <= cluster_ecc_anchor_next_v;
                cluster_fine_anchor  <= cluster_fine_anchor_next_v;
`ifndef SYNTHESIS
                cluster_true_gts_anchor <= cluster_true_gts_anchor_next_v;
                inject_masked_true_gts_anchor <= inject_masked_true_gts_anchor_next_v;
`endif
                inject_burst_pending <= inject_burst_pending_next_v;
                burst_remaining      <= burst_remaining_next_v;
                burst_global_ch      <= burst_global_next_v;
                periodic_phase       <= periodic_phase_next_v;
                inject_masked_active <= inject_masked_active_next_v;
                inject_masked_shift <= inject_masked_shift_next_v;
                inject_masked_channel <= inject_masked_channel_next_v;
                inject_masked_tcc_anchor <= inject_masked_tcc_anchor_next_v;
                inject_masked_ecc_anchor <= inject_masked_ecc_anchor_next_v;
                inject_masked_fine_anchor <= inject_masked_fine_anchor_next_v;
            end

            if (candidate_local_valid_v && accept_capacity_v) begin
                if (masked_sequence_word_v) begin
                    candidate_word_v = build_l2_hit_masked(
                        candidate_ch_v,
                        inject_masked_tcc_anchor_next_v,
                        inject_masked_ecc_anchor_next_v,
                        inject_masked_fine_anchor_next_v
                    );
                end else if (consume_cluster_word_v) begin
                    candidate_word_v = build_l2_hit_cluster(
                        candidate_ch_v,
                        cluster_tcc_anchor_next_v,
                        cluster_ecc_anchor_next_v,
                        cluster_fine_anchor_next_v,
                        prng_state[2:0],
                        prng2_state[2:0],
                        prng_state[5:3],
                        prng2_state[4:2]
                    );
                end else begin
                    candidate_word_v = build_l2_hit_poisson(
                        candidate_ch_v,
                        tcc_lfsr,
                        ecc_lfsr,
                        poisson_t_fine_v,
                        poisson_e_fine_v
                    );
                end
                pending_valid_next_v = 1'b1;
                pending_word_next_v  = candidate_word_v;
                hit_wr_en            <= 1'b1;
                hit_wr_data          <= candidate_word_v;
`ifndef SYNTHESIS
                if (masked_sequence_word_v)
                    debug_hit_gen_gts_8n <= inject_masked_true_gts_anchor_next_v;
                else if (consume_cluster_word_v)
                    debug_hit_gen_gts_8n <= cluster_true_gts_anchor_next_v;
                else
                    debug_hit_gen_gts_8n <= debug_true_gts_next_v;
`endif
            end else if (sim_offer_valid && accept_capacity_v) begin
                pending_valid_next_v = 1'b1;
                pending_word_next_v  = sim_offer_word;
                hit_wr_en            <= 1'b1;
                hit_wr_data          <= sim_offer_word;
            end

            pending_valid <= pending_valid_next_v;
            pending_word  <= pending_word_next_v;
`ifndef SYNTHESIS
            debug_true_gts_8n <= debug_true_gts_next_v;
`endif

            if (l2_push_valid_v) begin
                l2_fifo_mem[fifo_wr_ptr] <= pending_word;
                fifo_wr_ptr              <= fifo_ptr_next(fifo_wr_ptr);
            end

            if (l2_pop_from_mem_v) begin
                fifo_data   <= l2_fifo_mem[fifo_rd_ptr];
                fifo_rd_ptr <= fifo_ptr_next(fifo_rd_ptr);
            end else if (l2_pop_from_pending_v) begin
                fifo_data   <= pending_word;
            end

            case ({l2_push_valid_v, l2_pop_from_mem_v})
                2'b10:   fifo_count <= fifo_count + FIFO_COUNT_WIDTH'(1);
                2'b01:   fifo_count <= fifo_count - FIFO_COUNT_WIDTH'(1);
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule
