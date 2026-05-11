`ifndef SWB_RDMA_CQE_EGRESS_IF_SV
`define SWB_RDMA_CQE_EGRESS_IF_SV

interface rdma_cqe_egress_if (input logic clk, input logic reset_n);
    logic         valid;
    logic         ready;
    logic [127:0] data;
    logic [15:0]  tag;
    logic [63:0]  sidecar_id;
    logic         sidecar_valid;

    logic [31:0] posted_count;

    task automatic clear();
        valid = 1'b0;
        ready = 1'b0;
        data = 128'h0;
        tag = 16'h0;
        sidecar_id = 64'h0;
        sidecar_valid = 1'b0;
    endtask

    task automatic drive_cqe(input logic [127:0] payload, input logic [15:0] cqe_tag,
                             input logic [63:0] id);
        @(posedge clk);
        valid <= 1'b1;
        ready <= 1'b1;
        data <= payload;
        tag <= cqe_tag;
        sidecar_id <= id;
        sidecar_valid <= 1'b1;
        @(posedge clk);
        valid <= 1'b0;
        ready <= 1'b0;
        data <= 128'h0;
        tag <= 16'h0;
        sidecar_id <= 64'h0;
        sidecar_valid <= 1'b0;
    endtask

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            posted_count <= 32'd0;
        end else if (valid && ready) begin
            posted_count <= posted_count + 32'd1;
        end
    end

    modport monitor (
        input clk,
        input reset_n,
        input valid,
        input ready,
        input data,
        input tag,
        input sidecar_id,
        input sidecar_valid,
        input posted_count
    );
endinterface

`endif
