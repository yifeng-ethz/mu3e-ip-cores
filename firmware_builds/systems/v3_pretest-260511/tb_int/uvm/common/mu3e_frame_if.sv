// mu3e_frame_if.sv
// 36-bit Mu3e AVST frame tap: data[31:0] plus datak[35:32].

interface mu3e_frame_if (
    input logic clk,
    input logic rst
);
    logic        valid;
    logic        ready;
    logic        sop;
    logic        eop;
    logic [35:0] data;
    logic [1:0]  channel;
    int unsigned frame_seq;

    localparam logic [7:0] MU3E_IF_K285 = 8'hbc;
    localparam logic [7:0] MU3E_IF_K284 = 8'h9c;
    localparam logic [7:0] MU3E_IF_K237 = 8'hf7;

    task automatic clear();
        valid = 1'b0;
        ready = 1'b1;
        sop = 1'b0;
        eop = 1'b0;
        data = 36'h0;
        channel = 2'd0;
        frame_seq = 0;
    endtask

    task automatic drive_beat(input logic [31:0] beat_data,
                              input logic [3:0] beat_datak,
                              input logic beat_sop,
                              input logic beat_eop,
                              input logic [1:0] beat_channel = 2'd0);
        @(posedge clk);
        valid <= 1'b1;
        ready <= 1'b1;
        sop <= beat_sop;
        eop <= beat_eop;
        data <= {beat_datak, beat_data};
        channel <= beat_channel;
        @(posedge clk);
        valid <= 1'b0;
        sop <= 1'b0;
        eop <= 1'b0;
        data <= 36'h0;
        channel <= 2'd0;
    endtask

    task automatic drive_mu3e_frame(input logic [31:0] payload,
                                    input int unsigned total_hits = 1,
                                    input logic [1:0] beat_channel = 2'd0);
        int unsigned shd;
        int unsigned hit;
        int unsigned hit_subheader_offset;
        logic [7:0] page_base;
        logic [7:0] subheader_ts;
        logic [15:0] frame_count;
        logic [31:0] hit_word;

        if (total_hits > 255)
            $fatal(1, "mu3e_frame_if.drive_mu3e_frame total_hits=%0d exceeds one-subheader 8-bit declaration", total_hits);

        page_base = frame_seq[0] ? 8'd128 : 8'd0;
        hit_subheader_offset = (frame_seq >> 1) % 128;
        frame_count = frame_seq[15:0];

        drive_beat({8'ha5, 2'b00, 14'd0, MU3E_IF_K285},
                   4'b0001, 1'b1, 1'b0, beat_channel);
        drive_beat({16'h2026, frame_seq[15:0]},
                   4'b0000, 1'b0, 1'b0, beat_channel);
        drive_beat({page_base[7:4], 12'h000, frame_count},
                   4'b0000, 1'b0, 1'b0, beat_channel);
        drive_beat({1'b0, 15'd128, total_hits[15:0]},
                   4'b0000, 1'b0, 1'b0, beat_channel);
        drive_beat({16'hc001, frame_seq[15:0]},
                   4'b0000, 1'b0, 1'b0, beat_channel);

        for (shd = 0; shd < 128; shd++) begin
            subheader_ts = page_base + shd[7:0];
            drive_beat({subheader_ts,
                        8'h00,
                        ((shd == hit_subheader_offset) ? total_hits[7:0] : 8'd0),
                        MU3E_IF_K237},
                       4'b0001, 1'b0, 1'b0, beat_channel);
            if (shd == hit_subheader_offset) begin
                for (hit = 0; hit < total_hits; hit++) begin
                    hit_word = {hit[3:0], payload[27:0]};
                    drive_beat(hit_word, 4'b0000, 1'b0, 1'b0, beat_channel);
                end
            end
        end

        drive_beat({24'h0, MU3E_IF_K284},
                   4'b0001, 1'b0, 1'b1, beat_channel);
        frame_seq++;
    endtask
endinterface
