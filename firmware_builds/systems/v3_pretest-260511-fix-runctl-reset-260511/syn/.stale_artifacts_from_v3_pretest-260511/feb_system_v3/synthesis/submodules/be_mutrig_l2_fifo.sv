// be_mutrig_l2_fifo.sv
// MuTRiG lane L2 FIFO wrapper.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add 256x48 backend FIFO wrapper for central trigger lanes.

module be_mutrig_l2_fifo #(
    parameter int WIDTH = 48,
    parameter int DEPTH = 256,
    parameter int ALMOST_FULL_MARGIN = 3
) (
    input  logic                         clk,
    input  logic                         rst,

    input  logic                         wr_valid,
    output logic                         wr_ready,
    input  logic [WIDTH-1:0]             wr_data,

    input  logic                         rd_en,
    output logic [WIDTH-1:0]             rd_data,
    output logic                         rd_valid,

    output logic                         empty,
    output logic                         full,
    output logic                         almost_full,
    output logic [$clog2(DEPTH+1)-1:0]   level
);

    localparam int PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam int ALMOST_FULL_LEVEL = (DEPTH > ALMOST_FULL_MARGIN) ? (DEPTH - ALMOST_FULL_MARGIN) : DEPTH;

    (* ramstyle = "M10K" *) logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr;
    logic [PTR_WIDTH-1:0] rd_ptr;
    logic [COUNT_WIDTH-1:0] count;

    function automatic logic [PTR_WIDTH-1:0] ptr_next(input logic [PTR_WIDTH-1:0] ptr);
        if (ptr == PTR_WIDTH'(DEPTH - 1)) begin
            return '0;
        end
        return ptr + PTR_WIDTH'(1);
    endfunction

    assign empty = (count == COUNT_WIDTH'(0));
    assign full = (count == COUNT_WIDTH'(DEPTH));
    assign almost_full = (count >= COUNT_WIDTH'(ALMOST_FULL_LEVEL));
    assign wr_ready = !full;
    assign level = count;

    always_ff @(posedge clk) begin
        logic push_fire;
        logic pop_fire;

        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count <= '0;
            rd_data <= '0;
            rd_valid <= 1'b0;
        end else begin
            push_fire = wr_valid && wr_ready;
            pop_fire = rd_en && !empty;
            rd_valid <= pop_fire;

            if (push_fire) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= ptr_next(wr_ptr);
            end

            if (pop_fire) begin
                rd_data <= mem[rd_ptr];
                rd_ptr <= ptr_next(rd_ptr);
            end

            unique case ({push_fire, pop_fire})
                2'b10: count <= count + COUNT_WIDTH'(1);
                2'b01: count <= count - COUNT_WIDTH'(1);
                default: count <= count;
            endcase
        end
    end

endmodule
