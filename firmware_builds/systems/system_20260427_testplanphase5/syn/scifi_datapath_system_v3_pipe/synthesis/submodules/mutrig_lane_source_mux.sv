// mutrig_lane_source_mux.sv
// Runtime-selectable lane mux between real MuTRiG decoded traffic and the
// local emulator stream.
//
// Version : 26.1.0
// Date    : 20260427
// Change  : Added Avalon-MM CSR source select and diagnostic counters.
//
// CSR map, word addressed:
//   0x0 UID              RO     default 0x4D4C534D ("MLSM")
//   0x1 META             RW/RO  write 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID
//   0x2 CONTROL          RW     bit0 select_emulator, bit1 clear counters W1P
//   0x3 STATUS           RO     live source and current input/output sidebands
//   0x4 REAL_BEATS       RO     saturating count of real input valid beats
//   0x5 EMU_BEATS        RO     saturating count of emulator input valid beats
//   0x6 SELECTED_BEATS   RO     saturating count of selected output valid beats
//   0x7 SWITCH_COUNT     RO     saturating count of CSR source changes
//   0x8 LAST_SELECTED    RO     last selected source, error, channel, and data

module mutrig_lane_source_mux #(
    parameter integer SELECT_EMULATOR = 0,
    parameter integer IP_UID          = 32'h4D4C534D,
    parameter integer VERSION_MAJOR   = 26,
    parameter integer VERSION_MINOR   = 1,
    parameter integer VERSION_PATCH   = 0,
    parameter integer BUILD           = 427,
    parameter integer VERSION_DATE    = 20260427,
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

    localparam logic [31:0] IP_UID_WORD_CONST = IP_UID;
    localparam logic [31:0] DATE_WORD_CONST   = VERSION_DATE;
    localparam logic [31:0] GIT_WORD_CONST    = VERSION_GIT;
    localparam logic [31:0] INSTANCE_ID_CONST = INSTANCE_ID;
    localparam logic [31:0] VERSION_WORD_CONST =
        ((VERSION_MAJOR & 32'h0000_00FF) << 24) |
        ((VERSION_MINOR & 32'h0000_00FF) << 16) |
        ((VERSION_PATCH & 32'h0000_000F) << 12) |
        (BUILD & 32'h0000_0FFF);

    logic        select_emulator;
    logic [1:0]  meta_select;
    logic [31:0] real_beat_count;
    logic [31:0] emu_beat_count;
    logic [31:0] selected_beat_count;
    logic [31:0] source_switch_count;
    logic        last_selected_source;
    logic [8:0]  last_selected_data;
    logic [2:0]  last_selected_error;
    logic [3:0]  last_selected_channel;

    logic [31:0] meta_readdata;
    logic [31:0] status_readdata;

    function automatic logic [31:0] saturating_increment(input logic [31:0] value);
        if (value == 32'hFFFF_FFFF) begin
            saturating_increment = value;
        end else begin
            saturating_increment = value + 32'd1;
        end
    endfunction

    always_comb begin
        if (select_emulator) begin
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
            select_emulator          <= (SELECT_EMULATOR != 0);
            meta_select              <= 2'd0;
            real_beat_count          <= 32'd0;
            emu_beat_count           <= 32'd0;
            selected_beat_count      <= 32'd0;
            source_switch_count      <= 32'd0;
            last_selected_source     <= 1'b0;
            last_selected_data       <= 9'd0;
            last_selected_error      <= 3'd0;
            last_selected_channel    <= 4'd0;
        end else begin
            if (asi_real_valid) begin
                real_beat_count <= saturating_increment(real_beat_count);
            end
            if (asi_emu_valid) begin
                emu_beat_count <= saturating_increment(emu_beat_count);
            end
            if (aso_valid) begin
                selected_beat_count      <= saturating_increment(selected_beat_count);
                last_selected_source     <= select_emulator;
                last_selected_data       <= aso_data;
                last_selected_error      <= aso_error;
                last_selected_channel    <= aso_channel;
            end

            if (avs_csr_write) begin
                unique case (avs_csr_address)
                    4'h1: begin
                        meta_select <= avs_csr_writedata[1:0];
                    end
                    4'h2: begin
                        if (select_emulator != avs_csr_writedata[0]) begin
                            source_switch_count <= saturating_increment(source_switch_count);
                        end
                        select_emulator <= avs_csr_writedata[0];
                        if (avs_csr_writedata[1]) begin
                            real_beat_count          <= 32'd0;
                            emu_beat_count           <= 32'd0;
                            selected_beat_count      <= 32'd0;
                            source_switch_count      <= 32'd0;
                            last_selected_source     <= select_emulator;
                            last_selected_data       <= 9'd0;
                            last_selected_error      <= 3'd0;
                            last_selected_channel    <= 4'd0;
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

        unique case (meta_select)
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

        unique case (avs_csr_address)
            4'h0:    avs_csr_readdata = IP_UID_WORD_CONST;
            4'h1:    avs_csr_readdata = meta_readdata;
            4'h2:    avs_csr_readdata = {31'd0, select_emulator};
            4'h3:    avs_csr_readdata = status_readdata;
            4'h4:    avs_csr_readdata = real_beat_count;
            4'h5:    avs_csr_readdata = emu_beat_count;
            4'h6:    avs_csr_readdata = selected_beat_count;
            4'h7:    avs_csr_readdata = source_switch_count;
            4'h8:    avs_csr_readdata = {15'd0, last_selected_source, last_selected_error, last_selected_channel, last_selected_data};
            default: avs_csr_readdata = 32'd0;
        endcase

        if (!avs_csr_read) begin
            avs_csr_readdata = avs_csr_readdata;
        end
    end

endmodule
