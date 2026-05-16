// arb_hit_type0_csr_trim3.sv
// Avalon-MM CSR slave with the resource-trimmed three-counter profile.
//
// Version : 26.6.5
// Date    : 20260516
// Change  : Keep only ingress-real, ingress-emu, and total-egress 64-bit
//           counters. Syndrome and error-counter CSR storage is not built.

module arb_hit_type0_csr_trim3 #(
    parameter integer MODE_DEFAULT     = 0,
    parameter integer WATCHDOG_DEFAULT = 500,
    parameter integer IP_UID           = 32'h41485430,
    parameter integer VERSION_MAJOR    = 26,
    parameter integer VERSION_MINOR    = 6,
    parameter integer VERSION_PATCH    = 5,
    parameter integer BUILD            = 518,
    parameter integer VERSION_DATE     = 20260516,
    parameter integer VERSION_GIT      = 32'h0000_0000,
    parameter integer INSTANCE_ID      = 0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        stream_clear,
    input  logic        counter_clear,

    input  logic [4:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    output logic [1:0]  mode,
    output logic [15:0] watchdog_cycles,

    input  logic [2:0]  run_state,
    input  logic        mode_commit,

    input  logic        real_full,
    input  logic        real_empty,
    input  logic [4:0]  real_depth,
    input  logic        real_ingress_open,
    input  logic        real_source_open,
    input  logic [15:0] real_idle_cycles,

    input  logic        emu_full,
    input  logic        emu_empty,
    input  logic [4:0]  emu_depth,
    input  logic        emu_ingress_open,
    input  logic        emu_source_open,
    input  logic [15:0] emu_idle_cycles,

    input  logic        merged_open,
    input  logic        last_grant,

    input  logic        real_push_accept,
    input  logic        emu_push_accept,
    input  logic        real_push_drop,
    input  logic        emu_push_drop,
    input  logic        ingress_real_frame_pulse,
    input  logic        ingress_emu_frame_pulse,
    input  logic        egress_valid,
    input  logic        egress_source_emu,
    input  logic        egress_synthesized,
    input  logic        egress_real_frame_pulse,
    input  logic        egress_emu_frame_pulse,
    input  logic        protocol_event,
    input  logic [2:0]  selected_error,
    input  logic [3:0]  selected_channel,
    input  logic        selected_startofpacket,
    input  logic        selected_endofpacket,
    input  logic        watchdog_fire_real,
    input  logic        watchdog_fire_emu,

    input  logic [3:0]  asi_real_channel,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_emu_channel,
    input  logic [2:0]  asi_emu_error
);

    localparam logic [1:0] MODE_REAL_CONST     = 2'd0;
    localparam logic [1:0] MODE_EMU_CONST      = 2'd1;
    localparam logic [1:0] MODE_MIX_RR_CONST   = 2'd2;
    localparam logic [1:0] MODE_RESERVED_CONST = 2'd3;

    localparam logic [31:0] IP_UID_WORD_CONST      = IP_UID;
    localparam logic [31:0] DATE_WORD_CONST        = VERSION_DATE;
    localparam logic [31:0] GIT_WORD_CONST         = VERSION_GIT;
    localparam logic [31:0] INSTANCE_ID_WORD_CONST = INSTANCE_ID;
    localparam logic [31:0] VERSION_WORD_CONST     =
        ((VERSION_MAJOR & 32'h0000_00FF) << 24) |
        ((VERSION_MINOR & 32'h0000_00FF) << 16) |
        ((VERSION_PATCH & 32'h0000_000F) << 12) |
        (BUILD & 32'h0000_0FFF);

    typedef struct packed {
        logic [1:0]  mode;
        logic [1:0]  mode_pending;
        logic [1:0]  meta_select;
        logic [15:0] watchdog_cycles;

        logic        partial_packet_drop_sticky;
        logic        mode_reserved_seen;
        logic        protocol_violation_sticky;
        logic        drop_mid_packet_sticky;
        logic        watchdog_synthesized_real;
        logic        watchdog_synthesized_emu;

        logic [63:0] ingress_real_hits;
        logic [63:0] ingress_emu_hits;
        logic [63:0] egress_hits;

        logic [31:0] ingress_real_hits_h_snap;
        logic [31:0] ingress_emu_hits_h_snap;
        logic [31:0] egress_hits_h_snap;

        logic [31:0] readdata;
    } csr_state_t;

    csr_state_t csr;
    csr_state_t csr_next;
    logic [31:0] meta_readdata;
    logic [31:0] status_readdata;
    logic [31:0] csr_read_data;
    logic        csr_write_valid_q;
    logic [4:0]  csr_write_address_q;
    logic [31:0] csr_write_data_q;
    logic        csr_clear_counters_q;
    logic        csr_clear_sticky_q;

    function automatic logic [1:0] mode_default_value();
        if (MODE_DEFAULT == 1) begin
            mode_default_value = MODE_EMU_CONST;
        end else if (MODE_DEFAULT == 2) begin
            mode_default_value = MODE_MIX_RR_CONST;
        end else begin
            mode_default_value = MODE_REAL_CONST;
        end
    endfunction

    function automatic logic [1:0] sanitize_mode(input logic [1:0] raw_mode);
        case (raw_mode)
            MODE_REAL_CONST:   sanitize_mode = MODE_REAL_CONST;
            MODE_EMU_CONST:    sanitize_mode = MODE_EMU_CONST;
            MODE_MIX_RR_CONST: sanitize_mode = MODE_MIX_RR_CONST;
            default:           sanitize_mode = MODE_REAL_CONST;
        endcase
    endfunction

    function automatic logic [15:0] watchdog_default_value();
        if (WATCHDOG_DEFAULT > 65535) begin
            watchdog_default_value = 16'hFFFF;
        end else if (WATCHDOG_DEFAULT < 0) begin
            watchdog_default_value = 16'h0000;
        end else begin
            watchdog_default_value = WATCHDOG_DEFAULT;
        end
    endfunction

    function automatic logic [63:0] saturating_increment64(input logic [63:0] value);
        if (value == 64'hFFFF_FFFF_FFFF_FFFF) begin
            saturating_increment64 = value;
        end else begin
            saturating_increment64 = value + 64'd1;
        end
    endfunction

    function automatic csr_state_t hard_reset_state();
        csr_state_t value;

        value                 = '0;
        value.mode            = mode_default_value();
        value.mode_pending    = mode_default_value();
        value.watchdog_cycles = watchdog_default_value();
        hard_reset_state      = value;
    endfunction

    assign avs_csr_waitrequest = 1'b0;
    assign avs_csr_readdata    = csr.readdata;
    assign mode                = csr.mode;
    assign watchdog_cycles     = csr.watchdog_cycles;

    always_comb begin : csr_read_mux
        case (csr.meta_select)
            2'd0:    meta_readdata = VERSION_WORD_CONST;
            2'd1:    meta_readdata = DATE_WORD_CONST;
            2'd2:    meta_readdata = GIT_WORD_CONST;
            2'd3:    meta_readdata = INSTANCE_ID_WORD_CONST;
            default: meta_readdata = 32'd0;
        endcase

        status_readdata        = 32'd0;
        status_readdata[1:0]   = csr.mode;
        status_readdata[3:2]   = csr.mode_pending;
        status_readdata[4]     = merged_open;
        status_readdata[5]     = real_source_open;
        status_readdata[6]     = emu_source_open;
        status_readdata[7]     = real_full;
        status_readdata[8]     = real_empty;
        status_readdata[9]     = emu_full;
        status_readdata[10]    = emu_empty;
        status_readdata[11]    = last_grant;
        status_readdata[12]    = csr.partial_packet_drop_sticky;
        status_readdata[13]    = csr.mode_reserved_seen;
        status_readdata[14]    = csr.protocol_violation_sticky;
        status_readdata[15]    = csr.drop_mid_packet_sticky;
        status_readdata[16]    = csr.watchdog_synthesized_real;
        status_readdata[17]    = csr.watchdog_synthesized_emu;
        status_readdata[20:18] = run_state;

        case (avs_csr_address)
            5'h00:   csr_read_data = IP_UID_WORD_CONST;
            5'h01:   csr_read_data = meta_readdata;
            5'h02:   csr_read_data = {30'd0, csr.mode_pending};
            5'h03:   csr_read_data = status_readdata;
            5'h04:   csr_read_data = {16'd0, csr.watchdog_cycles};
            5'h05:   csr_read_data = {emu_idle_cycles, real_idle_cycles};
            5'h0A:   csr_read_data = csr.ingress_real_hits[31:0];
            5'h0B:   csr_read_data = csr.ingress_real_hits_h_snap;
            5'h0C:   csr_read_data = csr.ingress_emu_hits[31:0];
            5'h0D:   csr_read_data = csr.ingress_emu_hits_h_snap;
            5'h12:   csr_read_data = csr.egress_hits[31:0];
            5'h13:   csr_read_data = csr.egress_hits_h_snap;
            default: csr_read_data = 32'd0;
        endcase
    end

    always_comb begin : csr_next_builder
        logic control_write;
        logic clear_counters;
        logic clear_sticky;
        logic real_drop_mid_event;
        logic emu_drop_mid_event;

        control_write       = csr_write_valid_q & (csr_write_address_q == 5'h02);
        clear_counters      = csr_clear_counters_q;
        clear_sticky        = csr_clear_sticky_q;
        real_drop_mid_event = real_push_drop & real_ingress_open;
        emu_drop_mid_event  = emu_push_drop & emu_ingress_open;

        csr_next            = csr;
        csr_next.readdata   = avs_csr_read ? csr_read_data : 32'd0;

        if (stream_clear) begin
            csr_next.mode                         = mode_default_value();
            csr_next.mode_pending                 = mode_default_value();
            csr_next.partial_packet_drop_sticky   = 1'b0;
            csr_next.mode_reserved_seen           = 1'b0;
            csr_next.protocol_violation_sticky    = 1'b0;
            csr_next.drop_mid_packet_sticky       = 1'b0;
            csr_next.watchdog_synthesized_real    = 1'b0;
            csr_next.watchdog_synthesized_emu     = 1'b0;
            csr_next.readdata                     = 32'd0;
        end else begin
            if (counter_clear | clear_counters) begin
                csr_next.ingress_real_hits        = 64'd0;
                csr_next.ingress_emu_hits         = 64'd0;
                csr_next.egress_hits              = 64'd0;
                csr_next.ingress_real_hits_h_snap = 32'd0;
                csr_next.ingress_emu_hits_h_snap  = 32'd0;
                csr_next.egress_hits_h_snap       = 32'd0;
            end

            if (clear_sticky) begin
                csr_next.partial_packet_drop_sticky = 1'b0;
                csr_next.mode_reserved_seen         = 1'b0;
                csr_next.protocol_violation_sticky  = 1'b0;
                csr_next.drop_mid_packet_sticky     = 1'b0;
                csr_next.watchdog_synthesized_real  = 1'b0;
                csr_next.watchdog_synthesized_emu   = 1'b0;
            end

            if (control_write) begin
                csr_next.mode_pending = sanitize_mode(csr_write_data_q[1:0]);

                if (csr_write_data_q[1:0] == MODE_RESERVED_CONST) begin
                    csr_next.mode_reserved_seen = 1'b1;
                end
            end

            if (csr_write_valid_q) begin
                case (csr_write_address_q)
                    5'h01: begin
                        csr_next.meta_select = csr_write_data_q[1:0];
                    end
                    5'h04: begin
                        csr_next.watchdog_cycles = csr_write_data_q[15:0];
                    end
                    default: begin
                    end
                endcase
            end

            if (real_push_accept) begin
                csr_next.ingress_real_hits =
                    saturating_increment64(csr_next.ingress_real_hits);
            end

            if (emu_push_accept) begin
                csr_next.ingress_emu_hits =
                    saturating_increment64(csr_next.ingress_emu_hits);
            end

            if (egress_valid & ~egress_synthesized) begin
                csr_next.egress_hits = saturating_increment64(csr_next.egress_hits);
            end

            if (real_push_drop & real_ingress_open) begin
                csr_next.partial_packet_drop_sticky = 1'b1;
            end

            if (emu_push_drop & emu_ingress_open) begin
                csr_next.partial_packet_drop_sticky = 1'b1;
            end

            if (real_drop_mid_event | emu_drop_mid_event) begin
                csr_next.drop_mid_packet_sticky = 1'b1;
            end

            if (protocol_event) begin
                csr_next.protocol_violation_sticky = 1'b1;
            end

            if (watchdog_fire_real) begin
                csr_next.watchdog_synthesized_real = 1'b1;
            end

            if (watchdog_fire_emu) begin
                csr_next.watchdog_synthesized_emu = 1'b1;
            end

            if (mode_commit) begin
                csr_next.mode = csr_next.mode_pending;
            end

            if (avs_csr_read) begin
                case (avs_csr_address)
                    5'h0A:   csr_next.ingress_real_hits_h_snap = csr.ingress_real_hits[63:32];
                    5'h0C:   csr_next.ingress_emu_hits_h_snap  = csr.ingress_emu_hits[63:32];
                    5'h12:   csr_next.egress_hits_h_snap       = csr.egress_hits[63:32];
                    default: begin
                    end
                endcase
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin : csr_state
        if (rst) begin
            csr                  <= hard_reset_state();
            csr_write_valid_q    <= 1'b0;
            csr_write_address_q  <= 5'd0;
            csr_write_data_q     <= 32'd0;
            csr_clear_counters_q <= 1'b0;
            csr_clear_sticky_q   <= 1'b0;
        end else begin
            csr                  <= csr_next;
            csr_write_valid_q    <= avs_csr_write & ~stream_clear;
            csr_write_address_q  <= avs_csr_address;
            csr_write_data_q     <= avs_csr_writedata;
            csr_clear_counters_q <= avs_csr_write & ~stream_clear &
                                    (avs_csr_address == 5'h02) & avs_csr_writedata[2];
            csr_clear_sticky_q   <= avs_csr_write & ~stream_clear &
                                    (avs_csr_address == 5'h02) & avs_csr_writedata[3];
        end
    end

endmodule
