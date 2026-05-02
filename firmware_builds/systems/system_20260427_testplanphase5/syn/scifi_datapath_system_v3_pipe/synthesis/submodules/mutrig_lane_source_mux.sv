// mutrig_lane_source_mux.sv
// Runtime-selectable lane source combiner between real MuTRiG decoded traffic
// and the local emulator stream.
//
// Version : 26.2.0
// Date    : 20260502
// Change  : Added mixed real+emulator RR mode with shallow per-input FIFOs.
//
// CSR map, word addressed:
//   0x0 UID              RO     default 0x4D4C534D ("MLSM")
//   0x1 META             RW/RO  write 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID
//   0x2 CONTROL          RW     bit0 select_emulator, bit1 clear W1P, bit2 mixed_rr
//   0x3 STATUS           RO     live source and current input/output sidebands
//   0x4 REAL_BEATS       RO     saturating count of real input valid beats
//   0x5 EMU_BEATS        RO     saturating count of emulator input valid beats
//   0x6 SELECTED_BEATS   RO     saturating count of selected output valid beats
//   0x7 SWITCH_COUNT     RO     saturating count of source-mode changes
//   0x8 LAST_SELECTED    RO     last selected source, error, channel, and data
//   0x9 FIFO_STATUS      RO     mixed-mode FIFO levels, full, empty, next grant
//   0xa REAL_DROPS       RO     real-input FIFO overflow drops in mixed mode
//   0xb EMU_DROPS        RO     emulator-input FIFO overflow drops in mixed mode
//   0xc REAL_SELECTED    RO     selected-output beats sourced from real input
//   0xd EMU_SELECTED     RO     selected-output beats sourced from emulator input

module mutrig_lane_source_mux #(
    parameter integer SELECT_EMULATOR = 0,
    parameter integer FIFO_DEPTH      = 4,
    parameter integer IP_UID          = 32'h4D4C534D,
    parameter integer VERSION_MAJOR   = 26,
    parameter integer VERSION_MINOR   = 2,
    parameter integer VERSION_PATCH   = 0,
    parameter integer BUILD           = 502,
    parameter integer VERSION_DATE    = 20260502,
    parameter integer VERSION_GIT     = 32'h0528DBAD,
    parameter integer INSTANCE_ID     = 0
) (
    input  logic        clk,
    input  logic        rst,

    input  logic [3:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    input  logic [8:0]  asi_real_data,
    input  logic        asi_real_valid,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_real_channel,

    input  logic [8:0]  asi_emu_data,
    input  logic        asi_emu_valid,
    input  logic [2:0]  asi_emu_error,
    input  logic [3:0]  asi_emu_channel,

    output logic [8:0]  aso_data,
    output logic        aso_valid,
    output logic [2:0]  aso_error,
    output logic [3:0]  aso_channel
);

    localparam integer      FIFO_DEPTH_CONST       = (FIFO_DEPTH < 2) ? 2 : FIFO_DEPTH;
    localparam integer      FIFO_COUNT_WIDTH_CONST = $clog2(FIFO_DEPTH_CONST + 1);
    localparam integer      FIFO_BEAT_WIDTH_CONST  = 16;
    localparam logic [FIFO_COUNT_WIDTH_CONST-1:0] FIFO_DEPTH_VALUE_CONST = FIFO_DEPTH_CONST;
    localparam logic [31:0] IP_UID_WORD_CONST      = IP_UID;
    localparam logic [31:0] DATE_WORD_CONST        = VERSION_DATE;
    localparam logic [31:0] GIT_WORD_CONST         = VERSION_GIT;
    localparam logic [31:0] INSTANCE_ID_CONST      = INSTANCE_ID;
    localparam logic [31:0] VERSION_WORD_CONST     =
        ((VERSION_MAJOR & 32'h0000_00FF) << 24) |
        ((VERSION_MINOR & 32'h0000_00FF) << 16) |
        ((VERSION_PATCH & 32'h0000_000F) << 12) |
        (BUILD & 32'h0000_0FFF);

    logic        select_emulator;
    logic        mixed_rr_enable;
    logic [1:0]  meta_select;

    logic [31:0] real_beat_count;
    logic [31:0] emu_beat_count;
    logic [31:0] selected_beat_count;
    logic [31:0] source_switch_count;
    logic [31:0] real_drop_count;
    logic [31:0] emu_drop_count;
    logic [31:0] real_selected_count;
    logic [31:0] emu_selected_count;

    logic        last_selected_source;
    logic [8:0]  last_selected_data;
    logic [2:0]  last_selected_error;
    logic [3:0]  last_selected_channel;

    logic [FIFO_BEAT_WIDTH_CONST-1:0] real_fifo [0:FIFO_DEPTH_CONST-1];
    logic [FIFO_BEAT_WIDTH_CONST-1:0] emu_fifo [0:FIFO_DEPTH_CONST-1];
    logic [FIFO_COUNT_WIDTH_CONST-1:0] real_fifo_count;
    logic [FIFO_COUNT_WIDTH_CONST-1:0] emu_fifo_count;
    logic                              rr_next_emulator;

    logic [FIFO_BEAT_WIDTH_CONST-1:0] real_input_beat;
    logic [FIFO_BEAT_WIDTH_CONST-1:0] emu_input_beat;
    logic [FIFO_BEAT_WIDTH_CONST-1:0] mixed_output_beat;
    logic [FIFO_COUNT_WIDTH_CONST-1:0] real_push_index;
    logic [FIFO_COUNT_WIDTH_CONST-1:0] emu_push_index;

    logic real_fifo_has_data;
    logic emu_fifo_has_data;
    logic real_fifo_full;
    logic emu_fifo_full;
    logic mixed_pop_real;
    logic mixed_pop_emu;
    logic mixed_output_valid;
    logic mixed_output_source_emulator;
    logic real_push_accept;
    logic emu_push_accept;
    logic real_push_drop;
    logic emu_push_drop;
    logic [1:0] source_mode;
    logic [1:0] requested_source_mode;

    logic [31:0] meta_readdata;
    logic [31:0] status_readdata;
    logic [31:0] fifo_status_readdata;

    function automatic logic [31:0] saturating_increment(input logic [31:0] value);
        if (value == 32'hFFFF_FFFF) begin
            saturating_increment = value;
        end else begin
            saturating_increment = value + 32'd1;
        end
    endfunction

    assign real_input_beat = {asi_real_error, asi_real_channel, asi_real_data};
    assign emu_input_beat  = {asi_emu_error, asi_emu_channel, asi_emu_data};

    always_comb begin : mixed_rr_arbiter
        real_fifo_has_data          = (real_fifo_count != '0);
        emu_fifo_has_data           = (emu_fifo_count != '0);
        real_fifo_full              = (real_fifo_count == FIFO_DEPTH_VALUE_CONST);
        emu_fifo_full               = (emu_fifo_count == FIFO_DEPTH_VALUE_CONST);
        mixed_pop_real              = 1'b0;
        mixed_pop_emu               = 1'b0;
        mixed_output_valid          = 1'b0;
        mixed_output_source_emulator= 1'b0;
        mixed_output_beat           = '0;

        if (mixed_rr_enable) begin
            if (real_fifo_has_data && emu_fifo_has_data) begin
                mixed_pop_emu                = rr_next_emulator;
                mixed_pop_real               = !rr_next_emulator;
                mixed_output_source_emulator = rr_next_emulator;
            end else if (real_fifo_has_data) begin
                mixed_pop_real               = 1'b1;
                mixed_output_source_emulator = 1'b0;
            end else if (emu_fifo_has_data) begin
                mixed_pop_emu                = 1'b1;
                mixed_output_source_emulator = 1'b1;
            end

            mixed_output_valid = mixed_pop_real || mixed_pop_emu;
            if (mixed_pop_emu) begin
                mixed_output_beat = emu_fifo[0];
            end else if (mixed_pop_real) begin
                mixed_output_beat = real_fifo[0];
            end
        end

        real_push_accept = mixed_rr_enable && asi_real_valid && (!real_fifo_full || mixed_pop_real);
        emu_push_accept  = mixed_rr_enable && asi_emu_valid && (!emu_fifo_full || mixed_pop_emu);
        real_push_drop   = mixed_rr_enable && asi_real_valid && !real_push_accept;
        emu_push_drop    = mixed_rr_enable && asi_emu_valid && !emu_push_accept;
        real_push_index  = real_fifo_count - {{(FIFO_COUNT_WIDTH_CONST-1){1'b0}}, mixed_pop_real};
        emu_push_index   = emu_fifo_count - {{(FIFO_COUNT_WIDTH_CONST-1){1'b0}}, mixed_pop_emu};

        source_mode           = mixed_rr_enable ? 2'd2 : (select_emulator ? 2'd1 : 2'd0);
        requested_source_mode = avs_csr_writedata[2] ? 2'd2 : (avs_csr_writedata[0] ? 2'd1 : 2'd0);
    end

    always_comb begin : selected_stream_mux
        if (mixed_rr_enable) begin
            aso_data    = mixed_output_beat[8:0];
            aso_channel = mixed_output_beat[12:9];
            aso_error   = mixed_output_beat[15:13];
            aso_valid   = mixed_output_valid;
        end else if (select_emulator) begin
            aso_data    = asi_emu_data;
            aso_valid   = asi_emu_valid;
            aso_error   = asi_emu_error;
            aso_channel = asi_emu_channel;
        end else begin
            aso_data    = asi_real_data;
            aso_valid   = asi_real_valid;
            aso_error   = asi_real_error;
            aso_channel = asi_real_channel;
        end
    end

    always_ff @(posedge clk or posedge rst) begin : csr_reg
        if (rst) begin
            select_emulator       <= (SELECT_EMULATOR != 0);
            mixed_rr_enable       <= 1'b0;
            meta_select           <= 2'd0;
            real_beat_count       <= 32'd0;
            emu_beat_count        <= 32'd0;
            selected_beat_count   <= 32'd0;
            source_switch_count   <= 32'd0;
            real_drop_count       <= 32'd0;
            emu_drop_count        <= 32'd0;
            real_selected_count   <= 32'd0;
            emu_selected_count    <= 32'd0;
            last_selected_source  <= 1'b0;
            last_selected_data    <= 9'd0;
            last_selected_error   <= 3'd0;
            last_selected_channel <= 4'd0;
            real_fifo_count       <= '0;
            emu_fifo_count        <= '0;
            rr_next_emulator      <= 1'b0;
        end else begin
            if (asi_real_valid) begin
                real_beat_count <= saturating_increment(real_beat_count);
            end
            if (asi_emu_valid) begin
                emu_beat_count <= saturating_increment(emu_beat_count);
            end
            if (real_push_drop) begin
                real_drop_count <= saturating_increment(real_drop_count);
            end
            if (emu_push_drop) begin
                emu_drop_count <= saturating_increment(emu_drop_count);
            end

            if (mixed_rr_enable) begin
                if (mixed_pop_real) begin
                    for (int idx = 0; idx < FIFO_DEPTH_CONST - 1; idx++) begin
                        real_fifo[idx] <= real_fifo[idx + 1];
                    end
                    rr_next_emulator <= 1'b1;
                end
                if (mixed_pop_emu) begin
                    for (int idx = 0; idx < FIFO_DEPTH_CONST - 1; idx++) begin
                        emu_fifo[idx] <= emu_fifo[idx + 1];
                    end
                    rr_next_emulator <= 1'b0;
                end

                if (real_push_accept) begin
                    real_fifo[real_push_index] <= real_input_beat;
                end
                if (emu_push_accept) begin
                    emu_fifo[emu_push_index] <= emu_input_beat;
                end

                case ({real_push_accept, mixed_pop_real})
                    2'b10: real_fifo_count <= real_fifo_count + 1'b1;
                    2'b01: real_fifo_count <= real_fifo_count - 1'b1;
                    default: begin
                    end
                endcase
                case ({emu_push_accept, mixed_pop_emu})
                    2'b10: emu_fifo_count <= emu_fifo_count + 1'b1;
                    2'b01: emu_fifo_count <= emu_fifo_count - 1'b1;
                    default: begin
                    end
                endcase
            end

            if (aso_valid) begin
                selected_beat_count   <= saturating_increment(selected_beat_count);
                last_selected_source  <= mixed_rr_enable ? mixed_output_source_emulator : select_emulator;
                last_selected_data    <= aso_data;
                last_selected_error   <= aso_error;
                last_selected_channel <= aso_channel;
                if (mixed_rr_enable ? mixed_output_source_emulator : select_emulator) begin
                    emu_selected_count <= saturating_increment(emu_selected_count);
                end else begin
                    real_selected_count <= saturating_increment(real_selected_count);
                end
            end

            if (avs_csr_write) begin
                case (avs_csr_address)
                    4'h1: begin
                        meta_select <= avs_csr_writedata[1:0];
                    end
                    4'h2: begin
                        if (source_mode != requested_source_mode) begin
                            source_switch_count <= saturating_increment(source_switch_count);
                            real_fifo_count     <= '0;
                            emu_fifo_count      <= '0;
                            rr_next_emulator    <= 1'b0;
                        end

                        select_emulator <= avs_csr_writedata[0];
                        mixed_rr_enable <= avs_csr_writedata[2];

                        if (avs_csr_writedata[1]) begin
                            real_beat_count       <= 32'd0;
                            emu_beat_count        <= 32'd0;
                            selected_beat_count   <= 32'd0;
                            source_switch_count   <= 32'd0;
                            real_drop_count       <= 32'd0;
                            emu_drop_count        <= 32'd0;
                            real_selected_count   <= 32'd0;
                            emu_selected_count    <= 32'd0;
                            last_selected_source  <= avs_csr_writedata[0];
                            last_selected_data    <= 9'd0;
                            last_selected_error   <= 3'd0;
                            last_selected_channel <= 4'd0;
                            real_fifo_count       <= '0;
                            emu_fifo_count        <= '0;
                            rr_next_emulator      <= 1'b0;
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    always_comb begin : csr_read_mux
        avs_csr_waitrequest = 1'b0;

        case (meta_select)
            2'd0:    meta_readdata = VERSION_WORD_CONST;
            2'd1:    meta_readdata = DATE_WORD_CONST;
            2'd2:    meta_readdata = GIT_WORD_CONST;
            2'd3:    meta_readdata = INSTANCE_ID_CONST;
            default: meta_readdata = 32'd0;
        endcase

        status_readdata           = 32'd0;
        status_readdata[0]        = select_emulator;
        status_readdata[1]        = asi_real_valid;
        status_readdata[2]        = asi_emu_valid;
        status_readdata[3]        = aso_valid;
        status_readdata[7:4]      = aso_channel;
        status_readdata[10:8]     = aso_error;
        status_readdata[14:11]    = asi_real_channel;
        status_readdata[17:15]    = asi_real_error;
        status_readdata[21:18]    = asi_emu_channel;
        status_readdata[24:22]    = asi_emu_error;
        status_readdata[25]       = asi_real_valid & asi_emu_valid;
        status_readdata[26]       = mixed_rr_enable;
        status_readdata[27]       = real_fifo_full;
        status_readdata[28]       = emu_fifo_full;
        status_readdata[29]       = real_fifo_has_data;
        status_readdata[30]       = emu_fifo_has_data;
        status_readdata[31]       = rr_next_emulator;

        fifo_status_readdata      = 32'd0;
        fifo_status_readdata[7:0] = {{(8-FIFO_COUNT_WIDTH_CONST){1'b0}}, real_fifo_count};
        fifo_status_readdata[15:8]= {{(8-FIFO_COUNT_WIDTH_CONST){1'b0}}, emu_fifo_count};
        fifo_status_readdata[16]  = real_fifo_full;
        fifo_status_readdata[17]  = emu_fifo_full;
        fifo_status_readdata[18]  = real_fifo_has_data;
        fifo_status_readdata[19]  = emu_fifo_has_data;
        fifo_status_readdata[20]  = rr_next_emulator;

        case (avs_csr_address)
            4'h0:    avs_csr_readdata = IP_UID_WORD_CONST;
            4'h1:    avs_csr_readdata = meta_readdata;
            4'h2:    avs_csr_readdata = {29'd0, mixed_rr_enable, 1'b0, select_emulator};
            4'h3:    avs_csr_readdata = status_readdata;
            4'h4:    avs_csr_readdata = real_beat_count;
            4'h5:    avs_csr_readdata = emu_beat_count;
            4'h6:    avs_csr_readdata = selected_beat_count;
            4'h7:    avs_csr_readdata = source_switch_count;
            4'h8:    avs_csr_readdata = {15'd0, last_selected_source, last_selected_error, last_selected_channel, last_selected_data};
            4'h9:    avs_csr_readdata = fifo_status_readdata;
            4'ha:    avs_csr_readdata = real_drop_count;
            4'hb:    avs_csr_readdata = emu_drop_count;
            4'hc:    avs_csr_readdata = real_selected_count;
            4'hd:    avs_csr_readdata = emu_selected_count;
            default: avs_csr_readdata = 32'd0;
        endcase

        if (!avs_csr_read) begin
            avs_csr_readdata = 32'd0;
        end
    end

endmodule
