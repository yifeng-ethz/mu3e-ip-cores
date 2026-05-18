`timescale 1ns/1ps

module feb_swb_async_fifo #(
  parameter int WIDTH = 103,
  parameter int DEPTH_LOG2 = 6
) (
  input  logic             wr_clk,
  input  logic             wr_rst,
  input  logic             wr_en,
  input  logic [WIDTH-1:0] wr_data,
  output logic             full,
  output logic             overflow,

  input  logic             rd_clk,
  input  logic             rd_rst,
  input  logic             rd_en,
  output logic [WIDTH-1:0] rd_data,
  output logic             empty,
  output logic             underflow
);
  localparam int DEPTH = 1 << DEPTH_LOG2;
  localparam int PTR_WIDTH = DEPTH_LOG2 + 1;

  logic [WIDTH-1:0] mem [0:DEPTH-1];

  logic [PTR_WIDTH-1:0] wbin;
  logic [PTR_WIDTH-1:0] wgray;
  logic [PTR_WIDTH-1:0] rbin;
  logic [PTR_WIDTH-1:0] rgray;

  logic [PTR_WIDTH-1:0] rgray_wclk_q1;
  logic [PTR_WIDTH-1:0] rgray_wclk_q2;
  logic [PTR_WIDTH-1:0] wgray_rclk_q1;
  logic [PTR_WIDTH-1:0] wgray_rclk_q2;

  logic [PTR_WIDTH-1:0] wbin_inc;
  logic [PTR_WIDTH-1:0] wbin_next;
  logic [PTR_WIDTH-1:0] wgray_next;
  logic [PTR_WIDTH-1:0] rbin_next;
  logic [PTR_WIDTH-1:0] rgray_next;
  logic [PTR_WIDTH-1:0] full_compare;

  function automatic logic [PTR_WIDTH-1:0] bin_to_gray(
      input logic [PTR_WIDTH-1:0] bin);
    return (bin >> 1) ^ bin;
  endfunction

  assign wbin_inc = wbin + {{(PTR_WIDTH-1){1'b0}}, 1'b1};

  always_comb begin
    full_compare = rgray_wclk_q2;
    full_compare[PTR_WIDTH-1:PTR_WIDTH-2] =
        ~rgray_wclk_q2[PTR_WIDTH-1:PTR_WIDTH-2];
  end

  assign full = (bin_to_gray(wbin_inc) == full_compare);
  assign empty = (rgray == wgray_rclk_q2);

  wire wr_fire = wr_en && !full;
  wire rd_fire = rd_en && !empty;

  assign wbin_next = wbin + {{(PTR_WIDTH-1){1'b0}}, wr_fire};
  assign wgray_next = bin_to_gray(wbin_next);
  assign rbin_next = rbin + {{(PTR_WIDTH-1){1'b0}}, rd_fire};
  assign rgray_next = bin_to_gray(rbin_next);

  assign rd_data = mem[rbin[DEPTH_LOG2-1:0]];

  always_ff @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
      wbin <= '0;
      wgray <= '0;
      rgray_wclk_q1 <= '0;
      rgray_wclk_q2 <= '0;
      overflow <= 1'b0;
    end else begin
      rgray_wclk_q1 <= rgray;
      rgray_wclk_q2 <= rgray_wclk_q1;
      overflow <= wr_en && full;
      if (wr_fire) begin
        mem[wbin[DEPTH_LOG2-1:0]] <= wr_data;
        wbin <= wbin_next;
        wgray <= wgray_next;
      end
    end
  end

  always_ff @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
      rbin <= '0;
      rgray <= '0;
      wgray_rclk_q1 <= '0;
      wgray_rclk_q2 <= '0;
      underflow <= 1'b0;
    end else begin
      wgray_rclk_q1 <= wgray;
      wgray_rclk_q2 <= wgray_rclk_q1;
      underflow <= rd_en && empty;
      if (rd_fire) begin
        rbin <= rbin_next;
        rgray <= rgray_next;
      end
    end
  end
endmodule
