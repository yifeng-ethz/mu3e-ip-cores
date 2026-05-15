// be_mutrig_lane_emitter.sv
// MuTRiG per-lane ticket consumer and L2 hit-word emitter.
// Author: Yifeng Wang
// Version : 26.3.0
// Date    : 20260506
// Change  : Export ticket and L2 FIFO fill levels for DEBUG_LEVEL observability.

module be_mutrig_lane_emitter
#(
    parameter int FIFO_DEPTH = be_mutrig_pkg::RAW_FIFO_DEPTH_CONST
) (
    input  logic              clk,
    input  logic              rst,
    input  logic              enable,
    input  logic [31:0]       cfg_prng_seed,
    input  logic              frame_count_pulse,

    input  frontend_ticket_bus_pkg::frontend_ticket_t  ticket_data,
    input  logic              ticket_valid,
    output logic              ticket_ready,

    input  logic              l2_rd_en,
    output logic [47:0]       l2_rd_data,
    output logic              l2_rd_valid,
    output logic              l2_empty,
    output logic              l2_full,
    output logic              l2_almost_full,
    output logic [9:0]        l2_event_count,
    output logic [3:0]        debug_ticket_fifo_level,
    output logic [9:0]        debug_l2_fifo_level,

    output logic [63:0]       frame_count,
    output logic [63:0]       hit_count,
    input  logic              clear_fifo_full_sticky,
    input  logic              clear_ticket_overflow_sticky,
    output logic              fifo_full_sticky,
    output logic              ticket_overflow_sticky
);

    import frontend_ticket_bus_pkg::*;
    import be_mutrig_pkg::*;

    localparam int TICKET_DEPTH = be_mutrig_pkg::TICKET_FIFO_DEPTH_CONST;
    localparam int TICKET_PTR_WIDTH = $clog2(TICKET_DEPTH);
    localparam int TICKET_COUNT_WIDTH = TICKET_PTR_WIDTH + 1;

    (* ramstyle = "MLAB" *) frontend_ticket_t ticket_mem [0:TICKET_DEPTH-1];
    logic [TICKET_PTR_WIDTH-1:0] ticket_wr_ptr;
    logic [TICKET_PTR_WIDTH-1:0] ticket_rd_ptr;
    logic [TICKET_COUNT_WIDTH-1:0] ticket_count;
    logic active_valid;
    frontend_ticket_t active_ticket;
    logic [4:0] current_ch;
    logic [15:0] fine_prng;
    logic pending_valid;
    logic [47:0] pending_word;
    logic l2_wr_ready;
    logic [$clog2(FIFO_DEPTH+1)-1:0] l2_level;

    function automatic logic [TICKET_PTR_WIDTH-1:0] ticket_ptr_next(
        input logic [TICKET_PTR_WIDTH-1:0] ptr
    );
        if (ptr == TICKET_PTR_WIDTH'(TICKET_DEPTH - 1)) begin
            return '0;
        end
        return ptr + TICKET_PTR_WIDTH'(1);
    endfunction

    function automatic logic [15:0] fine_prng_seed(input logic [31:0] seed_word);
        logic [15:0] seed_value;

        seed_value = seed_word[15:0] ^ seed_word[31:16] ^ 16'h9E37;
        if (seed_value == 16'h0000) begin
            seed_value = 16'h0001;
        end
        return seed_value;
    endfunction

    function automatic logic [15:0] fine_prng_step(input logic [15:0] value);
        logic feedback_value;

        feedback_value = value[15] ^ value[13] ^ value[12] ^ value[10];
        return {value[14:0], feedback_value};
    endfunction

    function automatic logic [47:0] build_hit_word(
        input logic [4:0] channel,
        input logic [14:0] tcc,
        input logic [14:0] ecc,
        input logic [15:0] rnd
    );
        // Simple model per RTL_PLAN_central_trigger.md §2.5: T_Fine and
        // E_Fine are tied to 5'd0 for every emitted hit. The `rnd`
        // argument is kept for ABI stability with the prior fine-PRNG
        // signature; future patches can re-introduce jitter here under a
        // CSR enable without touching the call site.
        logic unused_rnd;
        unused_rnd = |rnd;
        return pack_hit_long(channel, 1'b0, tcc, 5'd0, 1'b0, ecc, 5'd0, 1'b1);
    endfunction

    assign ticket_ready = enable && (ticket_count != TICKET_COUNT_WIDTH'(TICKET_DEPTH));
    assign l2_event_count = {1'b0, l2_level};
    assign debug_ticket_fifo_level = ticket_count;
    assign debug_l2_fifo_level = {1'b0, l2_level};

    be_mutrig_l2_fifo #(
        .WIDTH              (48),
        .DEPTH              (FIFO_DEPTH),
        .ALMOST_FULL_MARGIN (be_mutrig_pkg::FIFO_ALMOST_FULL_MARGIN_CONST)
    ) u_l2_fifo (
        .clk         (clk),
        .rst         (rst),
        .wr_valid    (pending_valid),
        .wr_ready    (l2_wr_ready),
        .wr_data     (pending_word),
        .rd_en       (l2_rd_en),
        .rd_data     (l2_rd_data),
        .rd_valid    (l2_rd_valid),
        .empty       (l2_empty),
        .full        (l2_full),
        .almost_full (l2_almost_full),
        .level       (l2_level)
    );

    always_ff @(posedge clk) begin
        logic ticket_push;
        logic [TICKET_COUNT_WIDTH-1:0] ticket_count_next;

        if (rst) begin
            ticket_wr_ptr <= '0;
            ticket_rd_ptr <= '0;
            ticket_count <= '0;
            active_valid <= 1'b0;
            active_ticket <= '0;
            current_ch <= '0;
            fine_prng <= fine_prng_seed(cfg_prng_seed);
            pending_valid <= 1'b0;
            pending_word <= '0;
            frame_count <= 64'h0000_0000_0000_0000;
            hit_count <= 64'h0000_0000_0000_0000;
            fifo_full_sticky <= 1'b0;
            ticket_overflow_sticky <= 1'b0;
        end else begin
            ticket_push = ticket_valid && ticket_ready;
            ticket_count_next = ticket_count;

            if (clear_ticket_overflow_sticky) begin
                ticket_overflow_sticky <= 1'b0;
            end else if (ticket_valid && !ticket_ready) begin
                ticket_overflow_sticky <= 1'b1;
            end

            if (clear_fifo_full_sticky) begin
                fifo_full_sticky <= 1'b0;
            end else if (l2_full) begin
                fifo_full_sticky <= 1'b1;
            end

            if (frame_count_pulse) begin
                frame_count <= saturating_inc64(frame_count);
            end

            if (pending_valid && l2_wr_ready) begin
                pending_valid <= 1'b0;
                hit_count <= saturating_inc64(hit_count);
            end

            if (ticket_push) begin
                ticket_mem[ticket_wr_ptr] <= ticket_data;
                ticket_wr_ptr <= ticket_ptr_next(ticket_wr_ptr);
                ticket_count_next = ticket_count_next + TICKET_COUNT_WIDTH'(1);
            end

            if (!active_valid && (ticket_count != TICKET_COUNT_WIDTH'(0))) begin
                active_ticket <= ticket_mem[ticket_rd_ptr];
                current_ch <= ticket_mem[ticket_rd_ptr].ch_low;
                active_valid <= 1'b1;
                ticket_rd_ptr <= ticket_ptr_next(ticket_rd_ptr);
                ticket_count_next = ticket_count_next - TICKET_COUNT_WIDTH'(1);
            end

            if (enable && active_valid && !pending_valid) begin
                pending_word <= build_hit_word(current_ch, active_ticket.ts_a, active_ticket.ts_b, fine_prng);
                pending_valid <= 1'b1;
                fine_prng <= fine_prng_step(fine_prng);
                if (current_ch >= active_ticket.ch_high) begin
                    active_valid <= 1'b0;
                end else begin
                    current_ch <= current_ch + 5'd1;
                end
            end

            if (!enable) begin
                active_valid <= 1'b0;
                pending_valid <= 1'b0;
            end

            ticket_count <= ticket_count_next;
        end
    end

endmodule
