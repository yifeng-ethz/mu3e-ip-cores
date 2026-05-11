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
        input drop_count
    );
endinterface

`endif
