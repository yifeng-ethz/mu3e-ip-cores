`timescale 1ns/1ps

module cosim_packet_steering_monitor #(
    parameter int CHANNEL_W = 8
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 valid,
    input  logic [31:0]          data,
    input  logic [3:0]           datak,
    input  logic                 sop,
    input  logic                 eop,
    input  logic [CHANNEL_W-1:0] channel,
    output logic [31:0]          hit_packets,
    output logic [31:0]          sc_packets,
    output logic [31:0]          rc_packets,
    output logic [31:0]          unknown_packets
);
    localparam logic [7:0] K285 = 8'hbc;
    localparam logic [5:0] SCIFI_HIT_HEADER_ID = 6'b111000;

    logic in_packet;
    logic [1:0] packet_word_idx;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit_packets <= '0;
            sc_packets <= '0;
            rc_packets <= '0;
            unknown_packets <= '0;
            in_packet <= 1'b0;
            packet_word_idx <= '0;
        end else if (valid) begin
            if (sop || (datak[0] && data[7:0] == K285)) begin
                in_packet <= 1'b1;
                packet_word_idx <= '0;
                if (data[31:26] == SCIFI_HIT_HEADER_ID) begin
                    hit_packets <= hit_packets + 1'b1;
                end else begin
                    unknown_packets <= unknown_packets + 1'b1;
                end
            end else if (in_packet) begin
                packet_word_idx <= packet_word_idx + 1'b1;
            end

            if (eop) begin
                in_packet <= 1'b0;
                packet_word_idx <= '0;
            end
        end
    end
endmodule
