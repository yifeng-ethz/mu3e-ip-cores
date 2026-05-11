`ifndef SWB_RDMA_SQE_INGRESS_IF_SV
`define SWB_RDMA_SQE_INGRESS_IF_SV

interface rdma_sqe_ingress_if (input logic clk, input logic reset_n);
    logic        valid;
    logic        ready;
    logic        sop;
    logic        eop;
    logic [255:0] data;
    logic [63:0]  sidecar_id;

    logic [31:0] accepted_count;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            accepted_count <= 32'd0;
        end else if (valid && ready) begin
            accepted_count <= accepted_count + 32'd1;
        end
    end

    modport monitor (
        input clk,
        input reset_n,
        input valid,
        input ready,
        input sop,
        input eop,
        input data,
        input sidecar_id,
        input accepted_count
    );
endinterface

`endif
