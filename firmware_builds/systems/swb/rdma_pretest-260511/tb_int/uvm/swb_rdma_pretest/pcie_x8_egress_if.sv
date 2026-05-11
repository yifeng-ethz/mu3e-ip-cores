`ifndef SWB_PCIE_X8_EGRESS_IF_SV
`define SWB_PCIE_X8_EGRESS_IF_SV

interface pcie_x8_egress_if (input logic clk, input logic reset_n);
    logic         dma_wren;
    logic [255:0] dma_data;
    logic         endofevent;

    logic [31:0] beat_count;
    logic [31:0] event_count;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            beat_count  <= 32'd0;
            event_count <= 32'd0;
        end else begin
            if (dma_wren) begin
                beat_count <= beat_count + 32'd1;
            end
            if (dma_wren && endofevent) begin
                event_count <= event_count + 32'd1;
            end
        end
    end

    modport monitor (
        input clk,
        input reset_n,
        input dma_wren,
        input dma_data,
        input endofevent,
        input beat_count,
        input event_count
    );
endinterface

`endif
