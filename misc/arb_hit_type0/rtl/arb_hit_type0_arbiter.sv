// arb_hit_type0_arbiter.sv
// Beat-level source selection plus merge-packet FSM.
//
// Version : 26.2.0
// Date    : 20260504
// Change  : Add native-EOP egress frame pulses for CSR counters.

module arb_hit_type0_arbiter (
    input  logic        clk,
    input  logic        rst,
    input  logic        stream_clear,
    input  logic        grant_enable,
    input  logic [1:0]  mode,

    input  logic        real_empty,
    input  logic [44:0] real_head_data,
    input  logic [2:0]  real_head_error,
    input  logic [3:0]  real_head_channel,
    input  logic        real_head_startofpacket,
    input  logic        real_head_endofpacket,
    input  logic        real_head_endofrun,

    input  logic        emu_empty,
    input  logic [44:0] emu_head_data,
    input  logic [2:0]  emu_head_error,
    input  logic [3:0]  emu_head_channel,
    input  logic        emu_head_startofpacket,
    input  logic        emu_head_endofpacket,
    input  logic        emu_head_endofrun,

    input  logic [3:0]  last_channel_real,
    input  logic [3:0]  last_channel_emu,
    input  logic        watchdog_fire_real,
    input  logic        watchdog_fire_emu,

    output logic        real_pop,
    output logic        emu_pop,
    output logic        real_open,
    output logic        emu_open,
    output logic        eor_seen_real,
    output logic        eor_seen_emu,
    output logic        merged_locked,
    output logic        last_grant,
    output logic        merged_open,
    output logic        mode_commit,

    output logic        egress_valid,
    output logic        egress_source_emu,
    output logic        egress_synthesized,
    output logic [44:0] egress_data,
    output logic [2:0]  egress_error,
    output logic [3:0]  egress_channel,
    output logic        egress_startofpacket,
    output logic        egress_endofpacket,
    output logic        egress_endofrun,
    output logic        egress_real_frame_pulse,
    output logic        egress_emu_frame_pulse,
    output logic        protocol_event,
    output logic [2:0]  selected_error,
    output logic [3:0]  selected_channel,
    output logic        selected_startofpacket,
    output logic        selected_endofpacket
);

    localparam logic [1:0] MODE_REAL_CONST   = 2'd0;
    localparam logic [1:0] MODE_EMU_CONST    = 2'd1;
    localparam logic [1:0] MODE_MIX_RR_CONST = 2'd2;

    logic        real_open_next;
    logic        emu_open_next;
    logic        eor_seen_real_next;
    logic        eor_seen_emu_next;
    logic        merged_locked_next;
    logic        grant_real;
    logic        grant_emu;
    logic        selected_is_emu;
    logic [44:0] selected_data;
    logic [2:0]  selected_error_comb;
    logic [3:0]  selected_channel_comb;
    logic        selected_sop_comb;
    logic        selected_eop_comb;
    logic        selected_eor_comb;
    logic        was_open_self;
    logic        was_open_other;
    logic        self_open_next;
    logic        merged_open_next;

    function automatic logic mode_eor_complete(
        input logic [1:0] mode_value,
        input logic       real_seen,
        input logic       emu_seen
    );
        case (mode_value)
            MODE_EMU_CONST:    mode_eor_complete = emu_seen;
            MODE_MIX_RR_CONST: mode_eor_complete = real_seen & emu_seen;
            default:           mode_eor_complete = real_seen;
        endcase
    endfunction

    assign merged_open          = real_open | emu_open;
    assign selected_error       = selected_error_comb;
    assign selected_channel     = selected_channel_comb;
    assign selected_startofpacket = selected_sop_comb;
    assign selected_endofpacket   = selected_eop_comb | selected_eor_comb;

    always_comb begin : arbiter_select
        grant_real             = 1'b0;
        grant_emu              = 1'b0;
        selected_is_emu        = 1'b0;
        selected_data          = 45'd0;
        selected_error_comb    = 3'd0;
        selected_channel_comb  = 4'd0;
        selected_sop_comb      = 1'b0;
        selected_eop_comb      = 1'b0;
        selected_eor_comb      = 1'b0;
        real_pop               = 1'b0;
        emu_pop                = 1'b0;

        egress_valid           = 1'b0;
        egress_source_emu      = 1'b0;
        egress_synthesized     = 1'b0;
        egress_data            = 45'd0;
        egress_error           = 3'd0;
        egress_channel         = 4'd0;
        egress_startofpacket   = 1'b0;
        egress_endofpacket     = 1'b0;
        egress_endofrun        = 1'b0;
        egress_real_frame_pulse = 1'b0;
        egress_emu_frame_pulse  = 1'b0;
        protocol_event         = 1'b0;

        real_open_next         = real_open;
        emu_open_next          = emu_open;
        eor_seen_real_next     = eor_seen_real;
        eor_seen_emu_next      = eor_seen_emu;
        merged_locked_next     = merged_locked;
        was_open_self          = 1'b0;
        was_open_other         = 1'b0;
        self_open_next         = 1'b0;

        if (watchdog_fire_real) begin
            egress_valid          = 1'b1;
            egress_source_emu     = 1'b0;
            egress_synthesized    = 1'b1;
            egress_error          = 3'b100;
            egress_channel        = last_channel_real;
            egress_endofpacket    = 1'b1;
            real_open_next        = 1'b0;
            eor_seen_real_next    = eor_seen_real | eor_seen_emu;
            egress_endofrun       = mode_eor_complete(mode, eor_seen_real_next, eor_seen_emu_next);
        end else if (watchdog_fire_emu) begin
            egress_valid          = 1'b1;
            egress_source_emu     = 1'b1;
            egress_synthesized    = 1'b1;
            egress_error          = 3'b100;
            egress_channel        = last_channel_emu;
            egress_endofpacket    = 1'b1;
            emu_open_next         = 1'b0;
            eor_seen_emu_next     = eor_seen_emu | eor_seen_real;
            egress_endofrun       = mode_eor_complete(mode, eor_seen_real_next, eor_seen_emu_next);
        end else if (grant_enable & ~merged_locked) begin
            case (mode)
                MODE_EMU_CONST: begin
                    grant_emu = ~emu_empty;
                end
                MODE_MIX_RR_CONST: begin
                    if (~real_empty & ~emu_empty) begin
                        grant_real = last_grant;
                        grant_emu  = ~last_grant;
                    end else if (~real_empty) begin
                        grant_real = 1'b1;
                    end else if (~emu_empty) begin
                        grant_emu = 1'b1;
                    end
                end
                default: begin
                    grant_real = ~real_empty;
                end
            endcase

            real_pop              = grant_real;
            emu_pop               = grant_emu;
            egress_valid          = grant_real | grant_emu;
            egress_source_emu     = grant_emu;
            selected_is_emu       = grant_emu;

            selected_data         = selected_is_emu ? emu_head_data : real_head_data;
            selected_error_comb   = selected_is_emu ? emu_head_error : real_head_error;
            selected_channel_comb = selected_is_emu ? emu_head_channel : real_head_channel;
            selected_sop_comb     = selected_is_emu ? emu_head_startofpacket : real_head_startofpacket;
            selected_eop_comb     = selected_is_emu ? emu_head_endofpacket : real_head_endofpacket;
            selected_eor_comb     = selected_is_emu ? emu_head_endofrun : real_head_endofrun;
            egress_real_frame_pulse = grant_real & selected_eop_comb;
            egress_emu_frame_pulse  = grant_emu & selected_eop_comb;

            if (egress_valid) begin
                was_open_self  = selected_is_emu ? emu_open : real_open;
                was_open_other = selected_is_emu ? real_open : emu_open;
                self_open_next = was_open_self;

                if (selected_sop_comb & ~(selected_eop_comb | selected_eor_comb)) begin
                    self_open_next       = 1'b1;
                    egress_startofpacket = ~was_open_self & ~was_open_other;
                end else if (~selected_sop_comb & (selected_eop_comb | selected_eor_comb)) begin
                    self_open_next     = 1'b0;
                    egress_endofpacket = ~was_open_other;
                end else if (selected_sop_comb & (selected_eop_comb | selected_eor_comb)) begin
                    self_open_next       = 1'b0;
                    egress_startofpacket = ~was_open_other;
                    egress_endofpacket   = ~was_open_other;
                end

                if (selected_is_emu) begin
                    emu_open_next      = self_open_next;
                    eor_seen_emu_next  = eor_seen_emu | selected_eor_comb;
                end else begin
                    real_open_next     = self_open_next;
                    eor_seen_real_next = eor_seen_real | selected_eor_comb;
                end

                protocol_event   = selected_sop_comb & was_open_self;
                egress_endofrun  = egress_endofpacket &
                                    mode_eor_complete(mode, eor_seen_real_next, eor_seen_emu_next);
                egress_data      = selected_data;
                egress_error     = selected_error_comb;
                egress_channel   = selected_channel_comb;
            end
        end

        merged_open_next   = real_open_next | emu_open_next;
        merged_locked_next = merged_locked | egress_endofrun;
        mode_commit        = ~merged_open_next;
    end

    always_ff @(posedge clk or posedge rst) begin : merge_state
        if (rst) begin
            real_open        <= 1'b0;
            emu_open         <= 1'b0;
            eor_seen_real    <= 1'b0;
            eor_seen_emu     <= 1'b0;
            merged_locked    <= 1'b0;
            last_grant       <= 1'b0;
        end else if (stream_clear) begin
            real_open        <= 1'b0;
            emu_open         <= 1'b0;
            eor_seen_real    <= 1'b0;
            eor_seen_emu     <= 1'b0;
            merged_locked    <= 1'b0;
            last_grant       <= 1'b0;
        end else begin
            real_open        <= real_open_next;
            emu_open         <= emu_open_next;
            eor_seen_real    <= eor_seen_real_next;
            eor_seen_emu     <= eor_seen_emu_next;
            merged_locked    <= merged_locked_next;

            if (egress_valid & ~egress_synthesized) begin
                last_grant <= egress_source_emu;
            end
        end
    end

endmodule
