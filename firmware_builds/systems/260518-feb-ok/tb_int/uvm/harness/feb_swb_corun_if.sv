`timescale 1ns/1ps

interface feb_swb_feb_stream_if(
    input logic clk,
    input logic rst_n
);
    logic        valid;
    logic        ready;
    logic [35:0] data;
    logic        sop;
    logic        eop;
    logic        debug_valid;
    logic [63:0] debug_meta;
    logic [3:0]  source_asic;
    logic [3:0]  source_channel;
    logic [31:0] hit_rate_hz;

    task automatic clear();
        valid          <= 1'b0;
        ready          <= 1'b1;
        data           <= '0;
        sop            <= 1'b0;
        eop            <= 1'b0;
        debug_valid    <= 1'b0;
        debug_meta     <= '0;
        source_asic    <= '0;
        source_channel <= '0;
        hit_rate_hz    <= 32'd100000;
    endtask

    task automatic drive_beat(
        input logic [35:0] beat_data,
        input logic        beat_sop,
        input logic        beat_eop,
        input logic        beat_debug_valid,
        input logic [63:0] beat_debug_meta,
        input logic [3:0]  beat_source_asic,
        input logic [3:0]  beat_source_channel,
        input logic [31:0] beat_hit_rate_hz
    );
        @(negedge clk);
        valid          <= 1'b1;
        ready          <= 1'b1;
        data           <= beat_data;
        sop            <= beat_sop;
        eop            <= beat_eop;
        debug_valid    <= beat_debug_valid;
        debug_meta     <= beat_debug_meta;
        source_asic    <= beat_source_asic;
        source_channel <= beat_source_channel;
        hit_rate_hz    <= beat_hit_rate_hz;
        @(negedge clk);
        clear();
    endtask
endinterface

interface feb_swb_opq_stream_if(
    input logic clk,
    input logic rst_n
);
    logic        valid;
    logic        ready;
    logic [31:0] data;
    logic [3:0]  datak;
    logic        sop;
    logic        eop;
    logic        debug_valid;
    logic [63:0] debug_meta;

    task automatic clear();
        valid       <= 1'b0;
        ready       <= 1'b1;
        data        <= '0;
        datak       <= '0;
        sop         <= 1'b0;
        eop         <= 1'b0;
        debug_valid <= 1'b0;
        debug_meta  <= '0;
    endtask

    task automatic drive_beat(
        input logic [31:0] beat_data,
        input logic [3:0]  beat_datak,
        input logic        beat_sop,
        input logic        beat_eop,
        input logic        beat_debug_valid,
        input logic [63:0] beat_debug_meta
    );
        @(negedge clk);
        valid       <= 1'b1;
        ready       <= 1'b1;
        data        <= beat_data;
        datak       <= beat_datak;
        sop         <= beat_sop;
        eop         <= beat_eop;
        debug_valid <= beat_debug_valid;
        debug_meta  <= beat_debug_meta;
        @(negedge clk);
        clear();
    endtask
endinterface

interface feb_swb_dma_stream_if(
    input logic clk,
    input logic rst_n
);
    logic               valid;
    logic               ready;
    logic [255:0]       data;
    logic [3:0]         keep;
    logic [3:0]         debug_valid;
    logic [3:0][63:0]   debug_meta;

    task automatic clear();
        valid       <= 1'b0;
        ready       <= 1'b1;
        data        <= '0;
        keep        <= '0;
        debug_valid <= '0;
        debug_meta  <= '0;
    endtask

    task automatic drive_word(
        input logic [255:0]     word_data,
        input logic [3:0]       word_keep,
        input logic [3:0]       word_debug_valid,
        input logic [3:0][63:0] word_debug_meta
    );
        @(negedge clk);
        valid       <= 1'b1;
        ready       <= 1'b1;
        data        <= word_data;
        keep        <= word_keep;
        debug_valid <= word_debug_valid;
        debug_meta  <= word_debug_meta;
        @(negedge clk);
        clear();
    endtask
endinterface
