`ifndef SWB_OPQ_LANE_IF_SV
`define SWB_OPQ_LANE_IF_SV

interface opq_lane_if (input logic clk, input logic reset_n);
    logic        ingress_valid;
    logic        ingress_ready;
    logic        ingress_sop;
    logic        ingress_eop;
    logic [31:0] ingress_data;
    logic [3:0]  ingress_datak;

    logic        egress_valid;
    logic        egress_ready;
    logic        egress_sop;
    logic        egress_eop;
    logic [31:0] egress_data;
    logic [3:0]  egress_datak;

    logic [31:0] accepted_count;
    logic [31:0] emitted_count;
    logic [31:0] drop_count;
    logic        drop_pulse;
    int unsigned frame_seq;

    localparam logic [7:0] MU3E_IF_K285 = 8'hbc;
    localparam logic [7:0] MU3E_IF_K284 = 8'h9c;
    localparam logic [7:0] MU3E_IF_K237 = 8'hf7;
    localparam logic [5:0] MU3E_IF_SCIFI_HEADER_ID = 6'b111000;

    task automatic clear();
        ingress_valid = 1'b0;
        ingress_ready = 1'b0;
        ingress_sop = 1'b0;
        ingress_eop = 1'b0;
        ingress_data = 32'h0;
        ingress_datak = 4'h0;
        egress_valid = 1'b0;
        egress_ready = 1'b0;
        egress_sop = 1'b0;
        egress_eop = 1'b0;
        egress_data = 32'h0;
        egress_datak = 4'h0;
        drop_pulse = 1'b0;
        frame_seq = 0;
    endtask

    task automatic drive_mu3e_beat(input bit drive_ingress,
                                   input bit drive_egress,
                                   input logic [31:0] data,
                                   input logic [3:0] datak,
                                   input logic sop,
                                   input logic eop);
        @(posedge clk);
        if (drive_ingress) begin
            ingress_valid <= 1'b1;
            ingress_ready <= 1'b1;
            ingress_sop <= sop;
            ingress_eop <= eop;
            ingress_data <= data;
            ingress_datak <= datak;
        end
        if (drive_egress) begin
            egress_valid <= 1'b1;
            egress_ready <= 1'b1;
            egress_sop <= sop;
            egress_eop <= eop;
            egress_data <= data;
            egress_datak <= datak;
        end
        @(posedge clk);
        if (drive_ingress) begin
            ingress_valid <= 1'b0;
            ingress_ready <= 1'b0;
            ingress_sop <= 1'b0;
            ingress_eop <= 1'b0;
            ingress_datak <= 4'h0;
        end
        if (drive_egress) begin
            egress_valid <= 1'b0;
            egress_ready <= 1'b0;
            egress_sop <= 1'b0;
            egress_eop <= 1'b0;
            egress_datak <= 4'h0;
        end
    endtask

    task automatic drive_mu3e_frame(input logic [31:0] payload,
                                    input bit drive_ingress = 1'b1,
                                    input bit drive_egress = 1'b1,
                                    input int unsigned total_hits = 1);
        int unsigned shd;
        int unsigned hit;
        int unsigned hit_subheader_offset;
        logic [7:0] page_base;
        logic [7:0] subheader_ts;
        logic [15:0] frame_count;
        logic [31:0] hit_word;

        if (total_hits > 255)
            $fatal(1, "opq_lane_if.drive_mu3e_frame total_hits=%0d exceeds one-subheader 8-bit declaration", total_hits);

        page_base = frame_seq[0] ? 8'd128 : 8'd0;
        hit_subheader_offset = (frame_seq >> 1) % 128;
        frame_count = frame_seq[15:0];

        drive_mu3e_beat(drive_ingress, drive_egress,
                        {MU3E_IF_SCIFI_HEADER_ID, 2'b00, 16'h0001, MU3E_IF_K285},
                        4'b0001, 1'b1, 1'b0);
        drive_mu3e_beat(drive_ingress, drive_egress,
                        {16'h2026, frame_seq[15:0]},
                        4'b0000, 1'b0, 1'b0);
        drive_mu3e_beat(drive_ingress, drive_egress,
                        {page_base[7:4], 12'h000, frame_count},
                        4'b0000, 1'b0, 1'b0);
        drive_mu3e_beat(drive_ingress, drive_egress,
                        {1'b0, 15'd128, total_hits[15:0]},
                        4'b0000, 1'b0, 1'b0);
        drive_mu3e_beat(drive_ingress, drive_egress,
                        {16'hc001, frame_seq[15:0]},
                        4'b0000, 1'b0, 1'b0);

        for (shd = 0; shd < 128; shd++) begin
            subheader_ts = page_base + shd[7:0];
            drive_mu3e_beat(drive_ingress, drive_egress,
                            {subheader_ts,
                             8'h00,
                             ((shd == hit_subheader_offset) ? total_hits[7:0] : 8'd0),
                             MU3E_IF_K237},
                            4'b0001, 1'b0, 1'b0);
            if (shd == hit_subheader_offset) begin
                for (hit = 0; hit < total_hits; hit++) begin
                    hit_word = {hit[3:0], payload[27:0]};
                    drive_mu3e_beat(drive_ingress, drive_egress,
                                    hit_word,
                                    4'b0000, 1'b0, 1'b0);
                end
            end
        end

        drive_mu3e_beat(drive_ingress, drive_egress,
                        {24'h0, MU3E_IF_K284},
                        4'b0001, 1'b0, 1'b1);
        frame_seq++;
    endtask

    task automatic drive_packet(input logic [31:0] payload);
        drive_mu3e_frame(payload, 1'b1, 1'b1, 1);
    endtask

    task automatic drive_ingress_only(input logic [31:0] payload);
        drive_mu3e_frame(payload, 1'b1, 1'b0, 1);
    endtask

    task automatic drive_drop();
        @(posedge clk);
        drop_pulse <= 1'b1;
        @(posedge clk);
        drop_pulse <= 1'b0;
    endtask

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            accepted_count <= 32'd0;
            emitted_count  <= 32'd0;
            drop_count     <= 32'd0;
        end else begin
            if (ingress_valid && ingress_ready) begin
                accepted_count <= accepted_count + 32'd1;
            end
            if (egress_valid && egress_ready) begin
                emitted_count <= emitted_count + 32'd1;
            end
            if (drop_pulse) begin
                drop_count <= drop_count + 32'd1;
            end
        end
    end

    modport monitor (
        input clk,
        input reset_n,
        input ingress_valid,
        input ingress_ready,
        input ingress_sop,
        input ingress_eop,
        input ingress_data,
        input ingress_datak,
        input egress_valid,
        input egress_ready,
        input egress_sop,
        input egress_eop,
        input egress_data,
        input egress_datak,
        input accepted_count,
        input emitted_count,
        input drop_count,
        input drop_pulse
    );
endinterface

`endif
