module logging_fifo (
    input  wire [127:0] data,
    input  wire         rdclk,
    input  wire         rdreq,
    input  wire         wrclk,
    input  wire         wrreq,
    output wire [31:0]  q,
    output wire         rdempty,
    output wire         rdfull,
    output wire [9:0]   rdusedw,
    output wire         wrempty,
    output wire         wrfull,
    output wire [7:0]   wrusedw
);

    assign q       = 32'h0000_0000;
    assign rdempty = 1'b1;
    assign rdfull  = 1'b0;
    assign rdusedw = 10'd0;
    assign wrempty = 1'b1;
    assign wrfull  = 1'b0;
    assign wrusedw = 8'd0;

endmodule
