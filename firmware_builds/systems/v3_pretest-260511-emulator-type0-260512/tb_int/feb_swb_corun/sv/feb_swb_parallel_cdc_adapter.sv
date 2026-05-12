`timescale 1ns/1ps

module feb_swb_parallel_cdc_adapter #(
  parameter int ACTIVE_LANES = 2,
  parameter int FIFO_DEPTH_LOG2 = 6
) (
  input  logic                         feb_clk,
  input  logic                         feb_reset,
  input  logic [ACTIVE_LANES-1:0]      feb_valid,
  output logic [ACTIVE_LANES-1:0]      feb_ready,
  input  logic [ACTIVE_LANES*36-1:0]   feb_data,
  input  logic [ACTIVE_LANES-1:0]      feb_startofpacket,
  input  logic [ACTIVE_LANES-1:0]      feb_endofpacket,
  input  logic [ACTIVE_LANES-1:0]      feb_debug_valid,
  input  logic [ACTIVE_LANES*64-1:0]   feb_debug_meta,

  input  logic                         swb_clk,
  input  logic                         swb_reset,
  output logic [127:0]                 swb_data,
  output logic [15:0]                  swb_datak,
  output logic [3:0]                   swb_valid,
  output logic [3:0]                   swb_startofpacket,
  output logic [3:0]                   swb_endofpacket,
  output logic [3:0]                   swb_debug_valid,
  output logic [255:0]                 swb_debug_meta,
  output logic [3:0]                   swb_enable_mask,
  output logic [ACTIVE_LANES-1:0]      fifo_overflow,
  output logic [ACTIVE_LANES-1:0]      fifo_underflow
);
  import feb_swb_corun_pkg::*;

  localparam int FIFO_WIDTH = 103;
  localparam int FIFO_SOP_BIT = 102;
  localparam int FIFO_EOP_BIT = 101;
  localparam int FIFO_DBG_VALID_BIT = 100;
  localparam int FIFO_DBG_MSB = 99;
  localparam int FIFO_DBG_LSB = 36;
  localparam int FIFO_DATA_MSB = 35;
  localparam int FIFO_DATA_LSB = 0;

  logic [31:0] swb_data_lane [0:3];
  logic [3:0]  swb_datak_lane [0:3];
  logic        swb_valid_lane [0:3];
  logic        swb_sop_lane [0:3];
  logic        swb_eop_lane [0:3];
  logic        swb_debug_valid_lane [0:3];
  logic [63:0] swb_debug_meta_lane [0:3];

  assign swb_enable_mask = FEB_SWB_CORUN_ACTIVE_MASK;

  generate
    for (genvar lane = 0; lane < 4; lane++) begin : g_pack_outputs
      assign swb_data[lane*32 +: 32] = swb_data_lane[lane];
      assign swb_datak[lane*4 +: 4] = swb_datak_lane[lane];
      assign swb_valid[lane] = swb_valid_lane[lane];
      assign swb_startofpacket[lane] = swb_sop_lane[lane];
      assign swb_endofpacket[lane] = swb_eop_lane[lane];
      assign swb_debug_valid[lane] = swb_debug_valid_lane[lane];
      assign swb_debug_meta[lane*64 +: 64] = swb_debug_meta_lane[lane];
    end

    for (genvar lane = 0; lane < 4; lane++) begin : g_lanes
      if (lane < ACTIVE_LANES) begin : g_active
        logic [FIFO_WIDTH-1:0] fifo_wr_data;
        logic [FIFO_WIDTH-1:0] fifo_rd_data;
        logic                  fifo_full;
        logic                  fifo_empty;
        logic                  fifo_rd_en;

        assign fifo_wr_data = {
          feb_startofpacket[lane],
          feb_endofpacket[lane],
          feb_debug_valid[lane],
          feb_debug_meta[lane*64 +: 64],
          feb_data[lane*36 +: 36]
        };

        assign feb_ready[lane] = !fifo_full;
        assign fifo_rd_en = !swb_reset && !fifo_empty;

        feb_swb_async_fifo #(
          .WIDTH(FIFO_WIDTH),
          .DEPTH_LOG2(FIFO_DEPTH_LOG2)
        ) u_fifo (
          .wr_clk(feb_clk),
          .wr_rst(feb_reset),
          .wr_en(feb_valid[lane] && feb_ready[lane]),
          .wr_data(fifo_wr_data),
          .full(fifo_full),
          .overflow(fifo_overflow[lane]),
          .rd_clk(swb_clk),
          .rd_rst(swb_reset),
          .rd_en(fifo_rd_en),
          .rd_data(fifo_rd_data),
          .empty(fifo_empty),
          .underflow(fifo_underflow[lane])
        );

        assign swb_valid_lane[lane] = !fifo_empty;
        assign swb_sop_lane[lane] = !fifo_empty && fifo_rd_data[FIFO_SOP_BIT];
        assign swb_eop_lane[lane] = !fifo_empty && fifo_rd_data[FIFO_EOP_BIT];
        assign swb_debug_valid_lane[lane] =
            !fifo_empty && fifo_rd_data[FIFO_DBG_VALID_BIT];
        assign swb_debug_meta_lane[lane] =
            fifo_empty ? 64'h0 : fifo_rd_data[FIFO_DBG_MSB:FIFO_DBG_LSB];
        assign swb_datak_lane[lane] =
            fifo_empty ? 4'h0 : fifo_rd_data[FIFO_DATA_MSB:FIFO_DATA_MSB-3];
        assign swb_data_lane[lane] =
            fifo_empty ? 32'h0 : fifo_rd_data[31:0];
      end else begin : g_inactive
        assign swb_data_lane[lane] = 32'h0;
        assign swb_datak_lane[lane] = 4'h0;
        assign swb_valid_lane[lane] = 1'b0;
        assign swb_sop_lane[lane] = 1'b0;
        assign swb_eop_lane[lane] = 1'b0;
        assign swb_debug_valid_lane[lane] = 1'b0;
        assign swb_debug_meta_lane[lane] = 64'h0;
      end
    end
  endgenerate
endmodule
