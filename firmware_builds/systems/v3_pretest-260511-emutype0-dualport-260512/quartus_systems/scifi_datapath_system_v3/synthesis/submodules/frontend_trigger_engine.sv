// frontend_trigger_engine.sv
// Central signal trigger engine for emulator_mutrig.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Pipeline signal launch geometry before per-lane ticket shred.

module frontend_trigger_engine
    import frontend_ticket_bus_pkg::*;
#(
    parameter int LANE_COUNT = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             cfg_global_enable,
    input  logic             run_generating,
    input  logic             inject_pulse,
    input  logic             cfg_hit_mode_sig,
    input  logic             cfg_internal_sub_mode,
    input  logic             cfg_cluster_geom_mode,
    input  logic [15:0]      cfg_hit_rate,
    input  logic [7:0]       cfg_hit_channel_low,
    input  logic [7:0]       cfg_hit_channel_high,
    input  logic [7:0]       cfg_cluster_size_random,
    input  logic [1:0]       cfg_mirror_mode,
    input  logic signed [7:0] cfg_mirror_offset,
    input  logic [7:0]       cfg_random_center_seed,
    input  logic [31:0]      cfg_prng_seed,
    input  logic [14:0]      tcc_anchor,
    input  logic [14:0]      ecc_anchor,

    output logic             sig_offer_valid,
    output logic [$clog2((LANE_COUNT > 1) ? LANE_COUNT : 2)-1:0] sig_offer_lane,
    output frontend_ticket_t sig_offer_ticket,
    input  logic             sig_offer_ready,

    output logic [15:0]      ticket_overflow_count,
    output logic [7:0]       engine_busy_high_water
);

    localparam int LANE_INDEX_WIDTH = (LANE_COUNT > 1) ? $clog2(LANE_COUNT) : 1;

    logic [LANE_COUNT-1:0] pending_mask;
    logic [4:0] pending_ch_low [LANE_COUNT];
    logic [4:0] pending_ch_high [LANE_COUNT];
    logic [14:0] pending_tcc;
    logic [14:0] pending_ecc;
    logic [LANE_INDEX_WIDTH-1:0] rr_ptr;
    logic [LANE_INDEX_WIDTH-1:0] dispatch_base;
    logic [15:0] prng_state;
    logic [15:0] periodic_phase;
    logic [1:0] external_pending_count;
    logic [7:0] busy_run_count;
    logic       dispatch_found;
    logic [LANE_INDEX_WIDTH-1:0] dispatch_lane;
    logic       geom_stage_valid;
    logic       geom_stage_random;
    logic [7:0] geom_stage_channel_low;
    logic [7:0] geom_stage_channel_high;
    logic [7:0] geom_stage_size_random;
    logic [1:0] geom_stage_mirror_mode;
    logic signed [7:0] geom_stage_mirror_offset;
    logic [7:0] geom_stage_center_local;
    logic       geom_stage_primary_right_random;
    logic [14:0] geom_stage_tcc;
    logic [14:0] geom_stage_ecc;
    logic [LANE_INDEX_WIDTH-1:0] geom_stage_dispatch_base;
    logic       launch_stage_valid;
    logic [7:0] launch_stage_cluster0_low;
    logic [7:0] launch_stage_cluster0_high;
    logic [7:0] launch_stage_cluster1_low;
    logic [7:0] launch_stage_cluster1_high;
    logic       launch_stage_cluster1_valid;
    logic [14:0] launch_stage_tcc;
    logic [14:0] launch_stage_ecc;
    logic [LANE_INDEX_WIDTH-1:0] launch_stage_dispatch_base;
    logic       shred_stage_valid;
    logic [LANE_COUNT-1:0] shred_stage_mask;
    logic [4:0] shred_stage_ch_low [LANE_COUNT];
    logic [4:0] shred_stage_ch_high [LANE_COUNT];
    logic [14:0] shred_stage_tcc;
    logic [14:0] shred_stage_ecc;
    logic [LANE_INDEX_WIDTH-1:0] shred_stage_dispatch_base;

    function automatic logic [15:0] prng16_step(input logic [15:0] value);
        logic feedback_value;

        feedback_value = value[15] ^ value[13] ^ value[12] ^ value[10];
        return {value[14:0], feedback_value};
    endfunction

    function automatic logic [15:0] prng_seed_init(input logic [31:0] seed_word);
        logic [15:0] seed_value;

        seed_value = seed_word[15:0] ^ seed_word[31:16];
        if (seed_value == 16'h0000) begin
            seed_value = 16'h0001;
        end
        return seed_value;
    endfunction

    function automatic logic [7:0] random_size_clamped(input logic [7:0] raw_size);
        if (raw_size == 8'd0) begin
            return 8'd1;
        end
        if (raw_size > 8'd128) begin
            return 8'd128;
        end
        return raw_size;
    endfunction

    function automatic logic [7:0] clamp_start_128(input int signed center_value, input int unsigned size_value);
        int signed start_value;
        int signed max_start;

        max_start = 128 - int'(size_value);
        start_value = center_value - int'(size_value >> 1);
        if (start_value < 0) begin
            start_value = 0;
        end else if (start_value > max_start) begin
            start_value = max_start;
        end
        return start_value[7:0];
    endfunction

    function automatic logic [LANE_INDEX_WIDTH-1:0] lane_ptr_next(
        input logic [LANE_INDEX_WIDTH-1:0] lane_value
    );
        if (lane_value == LANE_INDEX_WIDTH'(LANE_COUNT - 1)) begin
            return '0;
        end
        return lane_value + LANE_INDEX_WIDTH'(1);
    endfunction

    always_comb begin
        dispatch_found = 1'b0;
        dispatch_lane = dispatch_base;
        for (int offset = 0; offset < LANE_COUNT; offset++) begin
            int candidate;

            candidate = (int'(dispatch_base) + offset) % LANE_COUNT;
            if (!dispatch_found && pending_mask[candidate]) begin
                dispatch_found = 1'b1;
                dispatch_lane = LANE_INDEX_WIDTH'(candidate);
            end
        end
    end

    // Register the offer outputs to break the worst path that previously
    // ran from dispatch_base through the per-lane mux into the lane FIFO
    // write. Adds 1 cycle of latency between pending_mask update and
    // sig_offer_valid; the lane back-end ticket FIFO already has slack.
    // Drop valid for one cycle after accept because pending_mask is cleared
    // on the same edge; reloading immediately would replay the same ticket.
    logic                          sig_offer_valid_q;
    logic [LANE_INDEX_WIDTH-1:0]   sig_offer_lane_q;
    frontend_ticket_t              sig_offer_ticket_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            sig_offer_valid_q  <= 1'b0;
            sig_offer_lane_q   <= '0;
            sig_offer_ticket_q <= '0;
        end else if (sig_offer_valid_q) begin
            if (sig_offer_ready) begin
                sig_offer_valid_q <= 1'b0;
            end
        end else begin
            sig_offer_valid_q <= dispatch_found;
            sig_offer_lane_q  <= dispatch_lane;
            sig_offer_ticket_q.ch_low  <= pending_ch_low[dispatch_lane];
            sig_offer_ticket_q.ch_high <= pending_ch_high[dispatch_lane];
            sig_offer_ticket_q.ts_a    <= pending_tcc;
            sig_offer_ticket_q.ts_b    <= pending_ecc;
        end
    end

    assign sig_offer_valid  = sig_offer_valid_q;
    assign sig_offer_lane   = sig_offer_lane_q;
    assign sig_offer_ticket = sig_offer_ticket_q;

    always_ff @(posedge clk) begin
        logic [15:0] prng_next;
        logic [16:0] phase_sum;
        logic        internal_active;
        logic        internal_fire;
        logic        launch_fire;
        logic        launch_random;
        logic        engine_occupied;
        logic [7:0]  cluster0_low;
        logic [7:0]  cluster0_high;
        logic [7:0]  cluster1_low;
        logic [7:0]  cluster1_high;
        logic        cluster1_valid;
        logic [7:0]  size_value;
        logic [7:0]  center_local;
        logic [7:0]  primary_start;
        logic [7:0]  mirror_start;
        logic        primary_right;
        int signed   mirror_center;
        int          lane_base;
        int          lane_limit;
        int          overlap_low;
        int          overlap_high;

        if (rst) begin
            pending_mask <= '0;
            for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
                pending_ch_low[lane_idx] <= '0;
                pending_ch_high[lane_idx] <= '0;
            end
            pending_tcc <= 15'h0001;
            pending_ecc <= 15'h0001;
            rr_ptr <= '0;
            dispatch_base <= '0;
            prng_state <= prng_seed_init(cfg_prng_seed);
            periodic_phase <= 16'h0000;
            external_pending_count <= 2'd0;
            ticket_overflow_count <= 16'h0000;
            busy_run_count <= 8'h00;
            engine_busy_high_water <= 8'h00;
            geom_stage_valid <= 1'b0;
            geom_stage_random <= 1'b0;
            geom_stage_channel_low <= 8'h00;
            geom_stage_channel_high <= 8'h00;
            geom_stage_size_random <= 8'h01;
            geom_stage_mirror_mode <= 2'b00;
            geom_stage_mirror_offset <= 8'sh00;
            geom_stage_center_local <= 8'h00;
            geom_stage_primary_right_random <= 1'b0;
            geom_stage_tcc <= 15'h0001;
            geom_stage_ecc <= 15'h0001;
            geom_stage_dispatch_base <= '0;
            launch_stage_valid <= 1'b0;
            launch_stage_cluster0_low <= 8'h00;
            launch_stage_cluster0_high <= 8'h00;
            launch_stage_cluster1_low <= 8'h00;
            launch_stage_cluster1_high <= 8'h00;
            launch_stage_cluster1_valid <= 1'b0;
            launch_stage_tcc <= 15'h0001;
            launch_stage_ecc <= 15'h0001;
            launch_stage_dispatch_base <= '0;
            shred_stage_valid <= 1'b0;
            shred_stage_mask <= '0;
            for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
                shred_stage_ch_low[lane_idx] <= '0;
                shred_stage_ch_high[lane_idx] <= '0;
            end
            shred_stage_tcc <= 15'h0001;
            shred_stage_ecc <= 15'h0001;
            shred_stage_dispatch_base <= '0;
        end else begin
            prng_next = prng16_step(prng_state);
            phase_sum = {1'b0, periodic_phase} + {1'b0, cfg_hit_rate};
            internal_active = cfg_global_enable && run_generating && !cfg_hit_mode_sig;
            internal_fire = 1'b0;
            launch_fire = 1'b0;
            launch_random = cfg_cluster_geom_mode;
            engine_occupied = (pending_mask != '0) || geom_stage_valid ||
                launch_stage_valid || shred_stage_valid;
            cluster0_low = 8'h00;
            cluster0_high = 8'h00;
            cluster1_low = 8'h00;
            cluster1_high = 8'h00;
            cluster1_valid = 1'b0;
            size_value = random_size_clamped(cfg_cluster_size_random);
            center_local = prng_state[7:0] + cfg_random_center_seed;
            center_local[7] = 1'b0;
            primary_start = 8'h00;
            mirror_start = 8'h00;
            primary_right = 1'b0;
            mirror_center = 0;

            if (cfg_global_enable) begin
                prng_state <= prng_next;
            end

            if (internal_active) begin
                if (!cfg_internal_sub_mode) begin
                    internal_fire = (prng_state < cfg_hit_rate);
                end else begin
                    internal_fire = phase_sum[16];
                    periodic_phase <= phase_sum[15:0];
                end
            end

            if (engine_occupied) begin
                if (busy_run_count != 8'hFF) begin
                    busy_run_count <= busy_run_count + 8'd1;
                end
                if (busy_run_count > engine_busy_high_water) begin
                    engine_busy_high_water <= busy_run_count;
                end
            end else begin
                busy_run_count <= 8'h00;
            end

            if (inject_pulse && engine_occupied) begin
                if (external_pending_count != 2'd2) begin
                    external_pending_count <= external_pending_count + 2'd1;
                end else if (ticket_overflow_count != 16'hFFFF) begin
                    ticket_overflow_count <= ticket_overflow_count + 16'd1;
                end
            end

            // sig_offer_lane is registered (sig_offer_lane_q); clear the
            // pending bit for the lane that was actually offered last
            // cycle, not the combinational dispatch_lane.
            if (sig_offer_valid_q && sig_offer_ready) begin
                pending_mask[sig_offer_lane_q] <= 1'b0;
            end

            if (shred_stage_valid) begin
                pending_mask <= shred_stage_mask;
                for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
                    pending_ch_low[lane_idx] <= shred_stage_ch_low[lane_idx];
                    pending_ch_high[lane_idx] <= shred_stage_ch_high[lane_idx];
                end

                pending_tcc <= shred_stage_tcc;
                pending_ecc <= shred_stage_ecc;
                dispatch_base <= shred_stage_dispatch_base;
                shred_stage_valid <= 1'b0;
            end

            if (geom_stage_valid) begin
                if (!geom_stage_random) begin
                    cluster0_low = geom_stage_channel_low;
                    if (geom_stage_channel_high < geom_stage_channel_low) begin
                        cluster0_high = geom_stage_channel_low;
                    end else begin
                        cluster0_high = geom_stage_channel_high;
                    end
                end else begin
                    unique case (geom_stage_mirror_mode)
                        2'b00: primary_right = 1'b0;
                        2'b01: primary_right = 1'b1;
                        2'b10: primary_right = geom_stage_primary_right_random;
                        default: primary_right = 1'b0;
                    endcase

                    size_value = random_size_clamped(geom_stage_size_random);
                    primary_start = clamp_start_128(int'({1'b0, geom_stage_center_local[6:0]}), size_value);
                    cluster0_low = primary_start + (primary_right ? 8'd128 : 8'd0);
                    cluster0_high = cluster0_low + size_value - 8'd1;

                    if (geom_stage_mirror_mode == 2'b10) begin
                        mirror_center = 127 - int'({1'b0, geom_stage_center_local[6:0]}) +
                            int'(geom_stage_mirror_offset);
                        mirror_start = clamp_start_128(mirror_center, size_value);
                        cluster1_low = mirror_start + (primary_right ? 8'd0 : 8'd128);
                        cluster1_high = cluster1_low + size_value - 8'd1;
                        cluster1_valid = 1'b1;
                    end
                end

                launch_stage_valid <= 1'b1;
                launch_stage_cluster0_low <= cluster0_low;
                launch_stage_cluster0_high <= cluster0_high;
                launch_stage_cluster1_low <= cluster1_low;
                launch_stage_cluster1_high <= cluster1_high;
                launch_stage_cluster1_valid <= cluster1_valid;
                launch_stage_tcc <= geom_stage_tcc;
                launch_stage_ecc <= geom_stage_ecc;
                launch_stage_dispatch_base <= geom_stage_dispatch_base;
                geom_stage_valid <= 1'b0;
            end

            if (launch_stage_valid) begin
                shred_stage_mask <= '0;
                for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
                    shred_stage_ch_low[lane_idx] <= '0;
                    shred_stage_ch_high[lane_idx] <= '0;

                    lane_base = lane_idx * 32;
                    lane_limit = lane_base + 31;

                    if ((int'(launch_stage_cluster0_low) <= lane_limit) &&
                        (int'(launch_stage_cluster0_high) >= lane_base)) begin
                        overlap_low = (int'(launch_stage_cluster0_low) > lane_base) ?
                            int'(launch_stage_cluster0_low) : lane_base;
                        overlap_high = (int'(launch_stage_cluster0_high) < lane_limit) ?
                            int'(launch_stage_cluster0_high) : lane_limit;
                        shred_stage_mask[lane_idx] <= 1'b1;
                        shred_stage_ch_low[lane_idx] <= 5'(overlap_low - lane_base);
                        shred_stage_ch_high[lane_idx] <= 5'(overlap_high - lane_base);
                    end

                    if (launch_stage_cluster1_valid &&
                        (int'(launch_stage_cluster1_low) <= lane_limit) &&
                        (int'(launch_stage_cluster1_high) >= lane_base)) begin
                        overlap_low = (int'(launch_stage_cluster1_low) > lane_base) ?
                            int'(launch_stage_cluster1_low) : lane_base;
                        overlap_high = (int'(launch_stage_cluster1_high) < lane_limit) ?
                            int'(launch_stage_cluster1_high) : lane_limit;
                        shred_stage_mask[lane_idx] <= 1'b1;
                        shred_stage_ch_low[lane_idx] <= 5'(overlap_low - lane_base);
                        shred_stage_ch_high[lane_idx] <= 5'(overlap_high - lane_base);
                    end
                end

                shred_stage_tcc <= launch_stage_tcc;
                shred_stage_ecc <= launch_stage_ecc;
                shred_stage_dispatch_base <= launch_stage_dispatch_base;
                shred_stage_valid <= 1'b1;
                launch_stage_valid <= 1'b0;
            end

            if (!engine_occupied) begin
                if (inject_pulse) begin
                    launch_fire = cfg_global_enable;
                end else if (external_pending_count != 2'd0) begin
                    launch_fire = cfg_global_enable;
                    external_pending_count <= external_pending_count - 2'd1;
                end else if (internal_fire) begin
                    launch_fire = 1'b1;
                end

                if (launch_fire) begin
                    geom_stage_valid <= 1'b1;
                    geom_stage_random <= launch_random;
                    geom_stage_channel_low <= cfg_hit_channel_low;
                    geom_stage_channel_high <= cfg_hit_channel_high;
                    geom_stage_size_random <= cfg_cluster_size_random;
                    geom_stage_mirror_mode <= cfg_mirror_mode;
                    geom_stage_mirror_offset <= cfg_mirror_offset;
                    geom_stage_center_local <= center_local;
                    geom_stage_primary_right_random <= prng_state[8];
                    geom_stage_tcc <= tcc_anchor;
                    geom_stage_ecc <= ecc_anchor;
                    geom_stage_dispatch_base <= rr_ptr;
                    rr_ptr <= lane_ptr_next(rr_ptr);
                end
            end
        end
    end

endmodule
