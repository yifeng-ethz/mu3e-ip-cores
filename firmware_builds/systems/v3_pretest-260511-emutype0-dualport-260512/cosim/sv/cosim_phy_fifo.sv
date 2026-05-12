`timescale 1ns/1ps

module cosim_phy_fifo #(
    parameter int WIDTH = 103,
    parameter int DEPTH_LOG2 = 6
) (
    input  logic             wr_clk,
    input  logic             wr_rst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             wr_full,
    output logic             wr_overflow,

    input  logic             rd_clk,
    input  logic             rd_rst_n,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             rd_empty,
    output logic             rd_underflow
);
    localparam int DEPTH = 1 << DEPTH_LOG2;
    localparam int PTR_W = DEPTH_LOG2 + 1;

    logic [WIDTH-1:0] mem [DEPTH];
    logic [PTR_W-1:0] wr_ptr_bin;
    logic [PTR_W-1:0] wr_ptr_gray;
    logic [PTR_W-1:0] wr_ptr_gray_rd1;
    logic [PTR_W-1:0] wr_ptr_gray_rd2;
    logic [PTR_W-1:0] rd_ptr_bin;
    logic [PTR_W-1:0] rd_ptr_gray;
    logic [PTR_W-1:0] rd_ptr_gray_wr1;
    logic [PTR_W-1:0] rd_ptr_gray_wr2;

    function automatic logic [PTR_W-1:0] bin2gray(input logic [PTR_W-1:0] bin);
        return (bin >> 1) ^ bin;
    endfunction

    wire [PTR_W-1:0] wr_ptr_bin_next = wr_ptr_bin + {{(PTR_W-1){1'b0}}, (wr_en && !wr_full)};
    wire [PTR_W-1:0] wr_ptr_gray_next = bin2gray(wr_ptr_bin_next);
    wire [PTR_W-1:0] rd_ptr_bin_next = rd_ptr_bin + {{(PTR_W-1){1'b0}}, (rd_en && !rd_empty)};
    wire [PTR_W-1:0] rd_ptr_gray_next = bin2gray(rd_ptr_bin_next);

    wire full_next = (wr_ptr_gray_next ==
                      {~rd_ptr_gray_wr2[PTR_W-1:PTR_W-2],
                       rd_ptr_gray_wr2[PTR_W-3:0]});

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin <= '0;
            wr_ptr_gray <= '0;
            rd_ptr_gray_wr1 <= '0;
            rd_ptr_gray_wr2 <= '0;
            wr_full <= 1'b0;
            wr_overflow <= 1'b0;
        end else begin
            rd_ptr_gray_wr1 <= rd_ptr_gray;
            rd_ptr_gray_wr2 <= rd_ptr_gray_wr1;
            wr_full <= full_next;
            if (wr_en && wr_full) begin
                wr_overflow <= 1'b1;
            end else if (wr_en) begin
                mem[wr_ptr_bin[DEPTH_LOG2-1:0]] <= wr_data;
                wr_ptr_bin <= wr_ptr_bin_next;
                wr_ptr_gray <= wr_ptr_gray_next;
            end
        end
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin <= '0;
            rd_ptr_gray <= '0;
            wr_ptr_gray_rd1 <= '0;
            wr_ptr_gray_rd2 <= '0;
            rd_data <= '0;
            rd_empty <= 1'b1;
            rd_underflow <= 1'b0;
        end else begin
            wr_ptr_gray_rd1 <= wr_ptr_gray;
            wr_ptr_gray_rd2 <= wr_ptr_gray_rd1;
            rd_empty <= (rd_ptr_gray_next == wr_ptr_gray_rd2);
            if (rd_en && rd_empty) begin
                rd_underflow <= 1'b1;
            end else if (rd_en) begin
                rd_data <= mem[rd_ptr_bin[DEPTH_LOG2-1:0]];
                rd_ptr_bin <= rd_ptr_bin_next;
                rd_ptr_gray <= rd_ptr_gray_next;
            end
        end
    end
endmodule
