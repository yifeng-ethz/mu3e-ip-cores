// frontend_bkg_generator.sv
// Background ticket source for emulator_mutrig.
// Author : Yifeng Wang
// Version: 26.2.0
// Date   : 20260502
// Change : Add folded 256-channel IID background generator.

module frontend_bkg_generator
    import frontend_ticket_bus_pkg::*;
#(
    parameter int LANE_COUNT = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             cfg_global_enable,
    input  logic             run_generating,
    input  logic             cfg_hit_mode_bkg,
    input  logic [15:0]      cfg_noise_rate,
    input  logic [31:0]      cfg_prng_seed,
    input  logic [14:0]      tcc_anchor,
    input  logic [14:0]      ecc_anchor,
    input  logic [LANE_COUNT-1:0] cfg_lane_enable_mask,

    output logic             bkg_offer_valid,
    output logic [$clog2((LANE_COUNT > 1) ? LANE_COUNT : 2)-1:0] bkg_offer_lane,
    output frontend_ticket_t bkg_offer_ticket,
    input  logic             bkg_offer_ready
);

    localparam int LANE_INDEX_WIDTH = (LANE_COUNT > 1) ? $clog2(LANE_COUNT) : 1;

    logic [7:0]  scan_pos;
    logic [15:0] prng_state;
    logic        pending_valid;
    logic [7:0]  pending_channel;
    logic [14:0] pending_tcc;
    logic [14:0] pending_ecc;

    function automatic logic [15:0] prng_seed_init(input logic [31:0] seed_word);
        logic [15:0] seed_value;

        seed_value = seed_word[15:0] ^ 16'hA5C3;
        if (seed_value == 16'h0000) begin
            seed_value = 16'h0001;
        end
        return seed_value;
    endfunction

    function automatic logic [15:0] prng16_step(input logic [15:0] value);
        logic feedback_value;

        feedback_value = value[15] ^ value[13] ^ value[12] ^ value[10];
        return {value[14:0], feedback_value};
    endfunction

    function automatic logic [15:0] folded_noise_threshold(input logic [15:0] rate_value);
        logic [23:0] scaled_value;

        scaled_value = {8'h00, rate_value} << 8;
        if (scaled_value[23:16] != 8'h00) begin
            return 16'hFFFF;
        end
        return scaled_value[15:0];
    endfunction

    assign bkg_offer_valid          = pending_valid;
    assign bkg_offer_lane           = LANE_INDEX_WIDTH'(pending_channel[7:5]);
    assign bkg_offer_ticket.ch_low  = pending_channel[4:0];
    assign bkg_offer_ticket.ch_high = pending_channel[4:0];
    assign bkg_offer_ticket.ts_a    = pending_tcc;
    assign bkg_offer_ticket.ts_b    = pending_ecc;

    always_ff @(posedge clk) begin : bkg_scan
        logic [15:0] decision_value;
        logic [15:0] threshold_value;
        logic [7:0]  lane_index_value;
        logic        fire_value;

        if (rst) begin
            scan_pos        <= 8'h00;
            prng_state      <= prng_seed_init(cfg_prng_seed);
            pending_valid   <= 1'b0;
            pending_channel <= 8'h00;
            pending_tcc     <= 15'h0001;
            pending_ecc     <= 15'h0001;
        end else begin
            if (pending_valid) begin
                if (bkg_offer_ready) begin
                    pending_valid <= 1'b0;
                end
            end else if (cfg_global_enable && run_generating && cfg_hit_mode_bkg) begin
                decision_value  = prng_state ^ {scan_pos, cfg_prng_seed[7:0]};
                threshold_value = folded_noise_threshold(cfg_noise_rate);
                lane_index_value = scan_pos[7:5];
                fire_value      = (decision_value < threshold_value) &&
                                  (lane_index_value < LANE_COUNT) &&
                                  cfg_lane_enable_mask[lane_index_value[LANE_INDEX_WIDTH-1:0]];

                prng_state <= prng16_step(prng_state);
                scan_pos   <= scan_pos + 8'd1;

                if (fire_value) begin
                    pending_valid   <= 1'b1;
                    pending_channel <= scan_pos;
                    pending_tcc     <= tcc_anchor;
                    pending_ecc     <= ecc_anchor;
                end
            end
        end
    end

endmodule
