`timescale 1ns/1ps

module feb_swb_parallel_cdc_adapter_smoke_tb;
  import feb_swb_corun_pkg::*;

  localparam int ACTIVE_LANES = 2;

  logic feb_clk = 1'b0;
  logic swb_clk = 1'b0;
  logic feb_reset = 1'b1;
  logic swb_reset = 1'b1;

  logic [ACTIVE_LANES-1:0] feb_valid;
  logic [ACTIVE_LANES-1:0] feb_ready;
  logic [ACTIVE_LANES*36-1:0] feb_data;
  logic [ACTIVE_LANES-1:0] feb_startofpacket;
  logic [ACTIVE_LANES-1:0] feb_endofpacket;
  logic [ACTIVE_LANES-1:0] feb_debug_valid;
  logic [ACTIVE_LANES*64-1:0] feb_debug_meta;

  logic [127:0] swb_data;
  logic [15:0] swb_datak;
  logic [3:0] swb_valid;
  logic [3:0] swb_startofpacket;
  logic [3:0] swb_endofpacket;
  logic [3:0] swb_debug_valid;
  logic [255:0] swb_debug_meta;
  logic [3:0] swb_enable_mask;
  logic [ACTIVE_LANES-1:0] fifo_overflow;
  logic [ACTIVE_LANES-1:0] fifo_underflow;

  int seen_lane0;
  int seen_lane1;

  always #3.2 feb_clk = ~feb_clk;
  always #2.0 swb_clk = ~swb_clk;

  feb_swb_parallel_cdc_adapter #(
    .ACTIVE_LANES(ACTIVE_LANES),
    .FIFO_DEPTH_LOG2(4)
  ) dut (
    .feb_clk(feb_clk),
    .feb_reset(feb_reset),
    .feb_valid(feb_valid),
    .feb_ready(feb_ready),
    .feb_data(feb_data),
    .feb_startofpacket(feb_startofpacket),
    .feb_endofpacket(feb_endofpacket),
    .feb_debug_valid(feb_debug_valid),
    .feb_debug_meta(feb_debug_meta),
    .swb_clk(swb_clk),
    .swb_reset(swb_reset),
    .swb_data(swb_data),
    .swb_datak(swb_datak),
    .swb_valid(swb_valid),
    .swb_startofpacket(swb_startofpacket),
    .swb_endofpacket(swb_endofpacket),
    .swb_debug_valid(swb_debug_valid),
    .swb_debug_meta(swb_debug_meta),
    .swb_enable_mask(swb_enable_mask),
    .fifo_overflow(fifo_overflow),
    .fifo_underflow(fifo_underflow)
  );

  task automatic drive_word(
      input int lane,
      input logic [3:0] datak,
      input logic [31:0] data,
      input logic sop,
      input logic eop,
      input logic [63:0] meta);
    @(posedge feb_clk);
    while (!feb_ready[lane]) begin
      @(posedge feb_clk);
    end
    feb_data[lane*36 +: 36] <= {datak, data};
    feb_startofpacket[lane] <= sop;
    feb_endofpacket[lane] <= eop;
    feb_debug_valid[lane] <= 1'b1;
    feb_debug_meta[lane*64 +: 64] <= meta;
    feb_valid[lane] <= 1'b1;
    @(posedge feb_clk);
    feb_valid[lane] <= 1'b0;
    feb_startofpacket[lane] <= 1'b0;
    feb_endofpacket[lane] <= 1'b0;
    feb_debug_valid[lane] <= 1'b0;
  endtask

  always @(posedge swb_clk) begin
    if (!swb_reset) begin
      if (swb_valid[0]) begin
        seen_lane0++;
        if (seen_lane0 == 1) begin
          assert(swb_data[0 +: 32] == 32'h1000_0001) else $fatal(1, "lane0 word0 data mismatch");
          assert(swb_datak[0 +: 4] == 4'h1) else $fatal(1, "lane0 word0 datak mismatch");
          assert(swb_startofpacket[0]) else $fatal(1, "lane0 word0 sop missing");
        end
        if (seen_lane0 == 2) begin
          assert(swb_data[0 +: 32] == 32'h1000_0002) else $fatal(1, "lane0 word1 data mismatch");
          assert(swb_endofpacket[0]) else $fatal(1, "lane0 word1 eop missing");
        end
      end

      if (swb_valid[1]) begin
        seen_lane1++;
        assert(swb_data[32 +: 32] == 32'h2000_0001) else $fatal(1, "lane1 data mismatch");
        assert(swb_debug_valid[1]) else $fatal(1, "lane1 debug valid missing");
      end

      assert(!swb_valid[2]) else $fatal(1, "lane2 should be masked idle");
      assert(!swb_valid[3]) else $fatal(1, "lane3 should be masked idle");
      assert(swb_enable_mask == 4'h3) else $fatal(1, "SWB enable mask mismatch");
    end
  end

  initial begin
    feb_valid = '0;
    feb_data = '0;
    feb_startofpacket = '0;
    feb_endofpacket = '0;
    feb_debug_valid = '0;
    feb_debug_meta = '0;
    seen_lane0 = 0;
    seen_lane1 = 0;

    repeat (6) @(posedge feb_clk);
    feb_reset = 1'b0;
    repeat (6) @(posedge swb_clk);
    swb_reset = 1'b0;

    fork
      begin
        drive_word(0, 4'h1, 32'h1000_0001, 1'b1, 1'b0,
            feb_swb_pack_debug_meta('{2'd2, 2'd0, FEB_SWB_SOURCE_FEB_FRAME, 8'h11, 16'h0101, 32'h0000_0001}));
        drive_word(0, 4'h0, 32'h1000_0002, 1'b0, 1'b1,
            feb_swb_pack_debug_meta('{2'd2, 2'd0, FEB_SWB_SOURCE_FEB_FRAME, 8'h11, 16'h0102, 32'h0000_0002}));
      end
      begin
        drive_word(1, 4'h2, 32'h2000_0001, 1'b1, 1'b1,
            feb_swb_pack_debug_meta('{2'd2, 2'd1, FEB_SWB_SOURCE_FEB_FRAME, 8'h12, 16'h0201, 32'h0000_0101}));
      end
    join

    repeat (40) @(posedge swb_clk);
    assert(seen_lane0 == 2) else $fatal(1, "expected 2 lane0 words, saw %0d", seen_lane0);
    assert(seen_lane1 == 1) else $fatal(1, "expected 1 lane1 word, saw %0d", seen_lane1);
    assert(fifo_overflow == '0) else $fatal(1, "unexpected FIFO overflow");
    assert(fifo_underflow == '0) else $fatal(1, "unexpected FIFO underflow");
    $display("FEB_SWB_PARALLEL_CDC_ADAPTER_SMOKE_PASS");
    $finish;
  end
endmodule
