`timescale 1 ps / 1 ps

module arriav_tsdblock #(
    parameter clock_divider_enable = "true",
    parameter clock_divider_value  = 80,
    parameter sim_tsdcalo          = 0,
    parameter lpm_type             = "arriav_tsdblock"
) (
    input  wire      ce,
    input  wire      clk,
    input  wire      clr,
    output reg       tsdcaldone,
    output reg [7:0] tsdcalo
);

    always @(posedge clk or posedge clr) begin
        if (clr) begin
            tsdcaldone <= 1'b0;
            tsdcalo    <= sim_tsdcalo[7:0];
        end else if (ce) begin
            tsdcaldone <= 1'b1;
            tsdcalo    <= sim_tsdcalo[7:0];
        end
    end

endmodule

