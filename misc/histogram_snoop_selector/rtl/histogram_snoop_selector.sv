// histogram_snoop_selector.sv
// Nonblocking histogram observation selector for FE SciFi hit streams.
//
// Version : 26.1.0
// Date    : 20260502
// Change  : Accept raw rbCAM type2 sidebands while preserving nonblocking
//           selection and rbCAM hit-word repacking.
//
// The input ready signals are intentionally tied high. This IP is a monitor:
// if the downstream histogram is not ready, the selected sample is dropped and
// counted rather than backpressuring either observed datapath.

module histogram_snoop_selector #(
    parameter integer DEFAULT_SELECT_RBCAM = 0,
    parameter integer DEFAULT_FILTER_RBCAM = 1,
    parameter integer IP_UID               = 32'h48534E50,
    parameter integer VERSION_MAJOR        = 26,
    parameter integer VERSION_MINOR        = 1,
    parameter integer VERSION_PATCH        = 0,
    parameter integer BUILD                = 502,
    parameter integer VERSION_DATE         = 20260502,
    parameter integer VERSION_GIT          = 32'h0528DBAD,
    parameter integer INSTANCE_ID          = 0
) (
    input  logic        clk,
    input  logic        rst,

    input  logic [2:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    input  logic [38:0] asi_hp_data,
    input  logic        asi_hp_valid,
    output logic        asi_hp_ready,
    input  logic        asi_hp_startofpacket,
    input  logic        asi_hp_endofpacket,
    input  logic [3:0]  asi_hp_channel,
    input  logic        asi_hp_empty,
    input  logic        asi_hp_error,

    input  logic [35:0] asi_rb_data,
    input  logic        asi_rb_valid,
    output logic        asi_rb_ready,
    input  logic        asi_rb_startofpacket,
    input  logic        asi_rb_endofpacket,
    input  logic [3:0]  asi_rb_channel,
    input  logic        asi_rb_empty,
    input  logic        asi_rb_error,

    output logic [38:0] aso_hist_data,
    output logic        aso_hist_valid,
    input  logic        aso_hist_ready,
    output logic        aso_hist_startofpacket,
    output logic        aso_hist_endofpacket,
    output logic [3:0]  aso_hist_channel
);

    localparam logic [31:0] IP_UID_WORD_CONST  = IP_UID;
    localparam logic [31:0] DATE_WORD_CONST    = VERSION_DATE;
    localparam logic [31:0] GIT_WORD_CONST     = VERSION_GIT;
    localparam logic [31:0] INSTANCE_ID_CONST  = INSTANCE_ID;
    localparam logic [31:0] VERSION_WORD_CONST =
        ((VERSION_MAJOR & 32'h0000_00FF) << 24) |
        ((VERSION_MINOR & 32'h0000_00FF) << 16) |
        ((VERSION_PATCH & 32'h0000_000F) << 12) |
        (BUILD & 32'h0000_0FFF);
    localparam logic [3:0] K_FLAG_CONST = 4'b0001;
    localparam logic [7:0] K237_CONST   = 8'hF7;
    localparam logic [7:0] K284_CONST   = 8'h9C;
    localparam logic [7:0] K285_CONST   = 8'hBC;

    logic        select_rbcam;
    logic        filter_rbcam_hits;
    logic [1:0]  meta_select;
    logic        rb_hit_region;
    logic [7:0]  rb_subheader_ts_11_4;
    logic [63:0] hp_seen_count;
    logic [63:0] rb_seen_count;
    logic [63:0] hist_emit_count;
    logic [63:0] hist_drop_count;

    logic        rb_word_is_k;
    logic        rb_word_is_subheader;
    logic        rb_word_is_frame_header;
    logic        rb_word_is_frame_trailer;
    logic        rb_hist_word_accept;
    logic [38:0] rb_hist_data;
    logic        selected_valid;
    logic        selected_sample;
    logic        selected_drop;
    logic [31:0] meta_readdata;
    logic [31:0] status_readdata;

    function automatic logic [63:0] saturating_increment64(input logic [63:0] value);
        if (value == 64'hFFFF_FFFF_FFFF_FFFF) begin
            saturating_increment64 = value;
        end else begin
            saturating_increment64 = value + 64'd1;
        end
    endfunction

    assign asi_hp_ready = 1'b1;
    assign asi_rb_ready = 1'b1;

    assign rb_word_is_k             = (asi_rb_data[35:32] == K_FLAG_CONST);
    assign rb_word_is_subheader     = rb_word_is_k && (asi_rb_data[7:0] == K237_CONST);
    assign rb_word_is_frame_header  = rb_word_is_k && (asi_rb_data[7:0] == K285_CONST);
    assign rb_word_is_frame_trailer = rb_word_is_k && (asi_rb_data[7:0] == K284_CONST);
    assign rb_hist_word_accept      = !filter_rbcam_hits ||
                                      (rb_hit_region && !rb_word_is_k);

    assign rb_hist_data[38:35] = asi_rb_data[25:22];
    assign rb_hist_data[34:30] = asi_rb_data[21:17];
    assign rb_hist_data[29]    = 1'b0;
    assign rb_hist_data[28:21] = rb_subheader_ts_11_4;
    assign rb_hist_data[20:17] = asi_rb_data[31:28];
    assign rb_hist_data[16:0]  = asi_rb_data[16:0];

    always_comb begin : hist_select
        if (select_rbcam) begin
            selected_valid           = asi_rb_valid && rb_hist_word_accept;
            aso_hist_data            = rb_hist_data;
            aso_hist_startofpacket   = 1'b0;
            aso_hist_endofpacket     = 1'b0;
            aso_hist_channel         = 4'd0;
        end else begin
            selected_valid           = asi_hp_valid;
            aso_hist_data            = asi_hp_data;
            aso_hist_startofpacket   = asi_hp_startofpacket;
            aso_hist_endofpacket     = asi_hp_endofpacket;
            aso_hist_channel         = asi_hp_channel;
        end

        selected_sample = selected_valid && aso_hist_ready;
        selected_drop   = selected_valid && !aso_hist_ready;
        aso_hist_valid  = selected_sample;
    end

    always_ff @(posedge clk or posedge rst) begin : snoop_reg
        if (rst) begin
            select_rbcam            <= (DEFAULT_SELECT_RBCAM != 0);
            filter_rbcam_hits       <= (DEFAULT_FILTER_RBCAM != 0);
            meta_select             <= 2'd0;
            rb_hit_region           <= 1'b0;
            rb_subheader_ts_11_4    <= 8'd0;
            hp_seen_count           <= 64'd0;
            rb_seen_count           <= 64'd0;
            hist_emit_count         <= 64'd0;
            hist_drop_count         <= 64'd0;
        end else begin
            if (asi_hp_valid) begin
                hp_seen_count <= saturating_increment64(hp_seen_count);
            end
            if (asi_rb_valid && rb_hist_word_accept) begin
                rb_seen_count <= saturating_increment64(rb_seen_count);
            end
            if (selected_sample) begin
                hist_emit_count <= saturating_increment64(hist_emit_count);
            end
            if (selected_drop) begin
                hist_drop_count <= saturating_increment64(hist_drop_count);
            end

            if (asi_rb_valid) begin
                if (rb_word_is_subheader) begin
                    rb_hit_region           <= 1'b1;
                    rb_subheader_ts_11_4    <= asi_rb_data[31:24];
                end else if (asi_rb_startofpacket ||
                             rb_word_is_frame_header ||
                             rb_word_is_frame_trailer) begin
                    rb_hit_region <= 1'b0;
                end
            end

            if (avs_csr_write) begin
                case (avs_csr_address)
                    3'h0: begin
                        hp_seen_count      <= 64'd0;
                        rb_seen_count      <= 64'd0;
                        hist_emit_count    <= 64'd0;
                        hist_drop_count    <= 64'd0;
                    end
                    3'h1: begin
                        meta_select <= avs_csr_writedata[1:0];
                    end
                    3'h2: begin
                        select_rbcam         <= avs_csr_writedata[0];
                        filter_rbcam_hits    <= avs_csr_writedata[1];
                        if (avs_csr_writedata[8]) begin
                            hp_seen_count      <= 64'd0;
                            rb_seen_count      <= 64'd0;
                            hist_emit_count    <= 64'd0;
                            hist_drop_count    <= 64'd0;
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

        status_readdata        = 32'd0;
        status_readdata[0]     = select_rbcam;
        status_readdata[1]     = filter_rbcam_hits;
        status_readdata[2]     = asi_hp_valid;
        status_readdata[3]     = asi_rb_valid;
        status_readdata[4]     = rb_hist_word_accept;
        status_readdata[5]     = rb_hit_region;
        status_readdata[6]     = aso_hist_ready;
        status_readdata[7]     = aso_hist_valid;
        status_readdata[15:8]  = rb_subheader_ts_11_4;

        case (avs_csr_address)
            3'h0:    avs_csr_readdata = IP_UID_WORD_CONST;
            3'h1:    avs_csr_readdata = meta_readdata;
            3'h2:    avs_csr_readdata = {22'd0, 1'b0, 7'd0, filter_rbcam_hits, select_rbcam};
            3'h3:    avs_csr_readdata = status_readdata;
            3'h4:    avs_csr_readdata = hp_seen_count[31:0];
            3'h5:    avs_csr_readdata = rb_seen_count[31:0];
            3'h6:    avs_csr_readdata = hist_emit_count[31:0];
            3'h7:    avs_csr_readdata = hist_drop_count[31:0];
            default: avs_csr_readdata = 32'd0;
        endcase

        if (!avs_csr_read) begin
            avs_csr_readdata = 32'd0;
        end
    end

endmodule
