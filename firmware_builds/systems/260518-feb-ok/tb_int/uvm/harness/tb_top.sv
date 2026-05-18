`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import feb_swb_corun_uvm_pkg::*;

    bit feb_clk;
    bit swb_clk;
    bit feb_rst_n;
    bit swb_rst_n;

    feb_swb_feb_stream_if feb_if0(.clk(feb_clk), .rst_n(feb_rst_n));
    feb_swb_feb_stream_if feb_if1(.clk(feb_clk), .rst_n(feb_rst_n));
    feb_swb_feb_stream_if feb_if2(.clk(feb_clk), .rst_n(feb_rst_n));
    feb_swb_feb_stream_if feb_if3(.clk(feb_clk), .rst_n(feb_rst_n));

    feb_swb_opq_stream_if opq_if0(.clk(swb_clk), .rst_n(swb_rst_n));
    feb_swb_opq_stream_if opq_if1(.clk(swb_clk), .rst_n(swb_rst_n));
    feb_swb_opq_stream_if opq_if2(.clk(swb_clk), .rst_n(swb_rst_n));
    feb_swb_opq_stream_if opq_if3(.clk(swb_clk), .rst_n(swb_rst_n));

    feb_swb_dma_stream_if dma_if(.clk(swb_clk), .rst_n(swb_rst_n));

    initial feb_clk = 1'b0;
    initial swb_clk = 1'b0;
    always #4ns feb_clk = ~feb_clk;
    always #2ns swb_clk = ~swb_clk;

    initial begin
        feb_rst_n = 1'b0;
        swb_rst_n = 1'b0;
        feb_if0.clear();
        feb_if1.clear();
        feb_if2.clear();
        feb_if3.clear();
        opq_if0.clear();
        opq_if1.clear();
        opq_if2.clear();
        opq_if3.clear();
        dma_if.clear();
        repeat (8) @(posedge swb_clk);
        feb_rst_n = 1'b1;
        swb_rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual feb_swb_feb_stream_if)::set(
            null, "uvm_test_top.env.feb_mon0", "vif", feb_if0);
        uvm_config_db#(virtual feb_swb_feb_stream_if)::set(
            null, "uvm_test_top.env.feb_mon1", "vif", feb_if1);
        uvm_config_db#(virtual feb_swb_feb_stream_if)::set(
            null, "uvm_test_top.env.feb_mon2", "vif", feb_if2);
        uvm_config_db#(virtual feb_swb_feb_stream_if)::set(
            null, "uvm_test_top.env.feb_mon3", "vif", feb_if3);

        uvm_config_db#(virtual feb_swb_opq_stream_if)::set(
            null, "uvm_test_top.env.opq_mon0", "vif", opq_if0);
        uvm_config_db#(virtual feb_swb_opq_stream_if)::set(
            null, "uvm_test_top.env.opq_mon1", "vif", opq_if1);
        uvm_config_db#(virtual feb_swb_opq_stream_if)::set(
            null, "uvm_test_top.env.opq_mon2", "vif", opq_if2);
        uvm_config_db#(virtual feb_swb_opq_stream_if)::set(
            null, "uvm_test_top.env.opq_mon3", "vif", opq_if3);

        uvm_config_db#(virtual feb_swb_dma_stream_if)::set(
            null, "uvm_test_top.env.dma_mon", "vif", dma_if);

        run_test("feb_swb_corun_base_test");
    end

    task automatic drive_opq_frame_lane0(
        input logic [15:0] ts_tag,
        input logic [31:0] payload,
        input logic [63:0] meta_bits
    );
        int unsigned shd;

        opq_if0.drive_beat({8'ha5, 2'b00, 14'd0, FEB_SWB_K285},
                           4'b0001, 1'b1, 1'b0, 1'b0, 64'd0);
        opq_if0.drive_beat(32'h00000000, 4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        opq_if0.drive_beat({ts_tag[15:12], 12'h000, 16'd1},
                           4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        opq_if0.drive_beat({1'b0, 15'd128, 16'd1},
                           4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        opq_if0.drive_beat(32'hc0010000, 4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        for (shd = 0; shd < FEB_SWB_EXPECTED_SUBHEADERS; shd++) begin
            opq_if0.drive_beat({shd[7:0],
                                ((shd[7:0] == ts_tag[11:4]) ? 16'd1 : 16'd0),
                                FEB_SWB_K237},
                               4'b0001, 1'b0, 1'b0, 1'b0, 64'd0);
            if (shd[7:0] == ts_tag[11:4]) begin
                opq_if0.drive_beat({ts_tag[3:0], payload[27:0]},
                                   4'b0000, 1'b0, 1'b0, 1'b1, meta_bits);
            end
        end
        opq_if0.drive_beat({24'h000000, FEB_SWB_K284},
                           4'b0001, 1'b0, 1'b1, 1'b0, 64'd0);
    endtask

    task automatic drive_opq_frame_lane1(
        input logic [15:0] ts_tag,
        input logic [31:0] payload,
        input logic [63:0] meta_bits
    );
        int unsigned shd;

        opq_if1.drive_beat({8'ha5, 2'b00, 14'd1, FEB_SWB_K285},
                           4'b0001, 1'b1, 1'b0, 1'b0, 64'd0);
        opq_if1.drive_beat(32'h00000000, 4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        opq_if1.drive_beat({ts_tag[15:12], 12'h000, 16'd1},
                           4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        opq_if1.drive_beat({1'b0, 15'd128, 16'd1},
                           4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        opq_if1.drive_beat(32'hc0010001, 4'b0000, 1'b0, 1'b0, 1'b0, 64'd0);
        for (shd = 0; shd < FEB_SWB_EXPECTED_SUBHEADERS; shd++) begin
            opq_if1.drive_beat({shd[7:0],
                                ((shd[7:0] == ts_tag[11:4]) ? 16'd1 : 16'd0),
                                FEB_SWB_K237},
                               4'b0001, 1'b0, 1'b0, 1'b0, 64'd0);
            if (shd[7:0] == ts_tag[11:4]) begin
                opq_if1.drive_beat({ts_tag[3:0], payload[27:0]},
                                   4'b0000, 1'b0, 1'b0, 1'b1, meta_bits);
            end
        end
        opq_if1.drive_beat({24'h000000, FEB_SWB_K284},
                           4'b0001, 1'b0, 1'b1, 1'b0, 64'd0);
    endtask

    task automatic drive_feb_frame_lane0(
        input logic [15:0] ts_tag,
        input logic [31:0] payload,
        input logic [63:0] meta_bits
    );
        int unsigned shd;

        feb_if0.drive_beat({4'h1, 8'ha5, 2'b00, 14'd0, FEB_SWB_K285},
                           1'b1, 1'b0, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
        feb_if0.drive_beat(36'h0_00000000, 1'b0, 1'b0, 1'b0, 64'd0,
                           4'd0, 4'd0, 32'd100000);
        feb_if0.drive_beat({4'h0, ts_tag[15:12], 12'h000, 16'd1},
                           1'b0, 1'b0, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
        feb_if0.drive_beat({4'h0, 1'b0, 15'd128, 16'd1},
                           1'b0, 1'b0, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
        feb_if0.drive_beat({4'h0, 32'hc0010000}, 1'b0, 1'b0, 1'b0,
                           64'd0, 4'd0, 4'd0, 32'd100000);
        for (shd = 0; shd < FEB_SWB_EXPECTED_SUBHEADERS; shd++) begin
            feb_if0.drive_beat({4'h1,
                                shd[7:0],
                                ((shd[7:0] == ts_tag[11:4]) ? 16'd1 : 16'd0),
                                FEB_SWB_K237},
                               1'b0, 1'b0, 1'b0, 64'd0,
                               4'd0, 4'd0, 32'd100000);
            if (shd[7:0] == ts_tag[11:4]) begin
                feb_if0.drive_beat({4'h0, ts_tag[3:0], payload[27:0]},
                                   1'b0, 1'b0, 1'b1, meta_bits,
                                   4'd0, 4'd0, 32'd100000);
            end
        end
        feb_if0.drive_beat({4'h1, 24'h000000, FEB_SWB_K284},
                           1'b0, 1'b1, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
    endtask

    task automatic drive_feb_frame_lane1(
        input logic [15:0] ts_tag,
        input logic [31:0] payload,
        input logic [63:0] meta_bits
    );
        int unsigned shd;

        feb_if1.drive_beat({4'h1, 8'ha5, 2'b00, 14'd1, FEB_SWB_K285},
                           1'b1, 1'b0, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
        feb_if1.drive_beat(36'h0_00000000, 1'b0, 1'b0, 1'b0, 64'd0,
                           4'd0, 4'd0, 32'd100000);
        feb_if1.drive_beat({4'h0, ts_tag[15:12], 12'h000, 16'd1},
                           1'b0, 1'b0, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
        feb_if1.drive_beat({4'h0, 1'b0, 15'd128, 16'd1},
                           1'b0, 1'b0, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
        feb_if1.drive_beat({4'h0, 32'hc0010001}, 1'b0, 1'b0, 1'b0,
                           64'd0, 4'd0, 4'd0, 32'd100000);
        for (shd = 0; shd < FEB_SWB_EXPECTED_SUBHEADERS; shd++) begin
            feb_if1.drive_beat({4'h1,
                                shd[7:0],
                                ((shd[7:0] == ts_tag[11:4]) ? 16'd1 : 16'd0),
                                FEB_SWB_K237},
                               1'b0, 1'b0, 1'b0, 64'd0,
                               4'd0, 4'd0, 32'd100000);
            if (shd[7:0] == ts_tag[11:4]) begin
                feb_if1.drive_beat({4'h0, ts_tag[3:0], payload[27:0]},
                                   1'b0, 1'b0, 1'b1, meta_bits,
                                   4'd0, 4'd0, 32'd100000);
            end
        end
        feb_if1.drive_beat({4'h1, 24'h000000, FEB_SWB_K284},
                           1'b0, 1'b1, 1'b0, 64'd0, 4'd0, 4'd0, 32'd100000);
    endtask

    initial begin
        feb_swb_debug_meta_t meta0;
        feb_swb_debug_meta_t meta1;
        logic [63:0] meta_bits0;
        logic [63:0] meta_bits1;
        logic [255:0] dma_word;
        logic [3:0][63:0] dma_meta;
        logic [31:0] payload0;
        logic [31:0] payload1;

        if ($test$plusargs("FEB_SWB_SELF_SMOKE")) begin
            wait (feb_rst_n && swb_rst_n);
            repeat (8) @(posedge swb_clk);

            payload0 = 32'h00010001;
            payload1 = 32'h00010002;

            meta0.debug_level = 2'd2;
            meta0.swb_lane    = 2'd0;
            meta0.source_id   = FEB_SWB_SOURCE_MUTRIG_EMU[3:0];
            meta0.ps_tag      = 8'h56;
            meta0.ts_tag      = 16'h3456;
            meta0.hit_id      = 32'h00000001;
            meta_bits0        = feb_swb_pack_debug_meta(meta0);

            meta1.debug_level = 2'd2;
            meta1.swb_lane    = 2'd1;
            meta1.source_id   = FEB_SWB_SOURCE_MUTRIG_EMU[3:0];
            meta1.ps_tag      = 8'h56;
            meta1.ts_tag      = 16'h3456;
            meta1.hit_id      = 32'h00000002;
            meta_bits1        = feb_swb_pack_debug_meta(meta1);

            fork
                drive_feb_frame_lane0(meta0.ts_tag, payload0, meta_bits0);
                drive_feb_frame_lane1(meta1.ts_tag, payload1, meta_bits1);
                begin
                    repeat (4) @(posedge swb_clk);
                    drive_opq_frame_lane0(meta0.ts_tag, payload0, meta_bits0);
                end
                begin
                    repeat (4) @(posedge swb_clk);
                    drive_opq_frame_lane1(meta1.ts_tag, payload1, meta_bits1);
                end
            join

            repeat (8) @(posedge swb_clk);
            dma_word = '0;
            dma_meta = '0;
            dma_word[63:0]   = {32'h0, payload0};
            dma_word[127:64] = {32'h0, payload1};
            dma_meta[0] = meta_bits0;
            dma_meta[1] = meta_bits1;
            dma_if.drive_word(dma_word, 4'h3, 4'h3, dma_meta);
        end
    end
endmodule
