// tb_int_assertions.sv
// Lightweight integration TB assertions for monitor traffic sanity.

module tb_int_assertions (
    input logic clk,
    input logic rst,
    input logic stage_a_valid,
    input logic pre_rbcam_valid,
    input logic post_rbcam_valid,
    input logic feb_egress_valid,
    input logic feb_egress_ready,
    input logic enable_post_rbcam_checks,
    input logic enable_feb_egress_checks
);
    always_ff @(posedge clk) begin
        if (!rst) begin
            if (enable_post_rbcam_checks && post_rbcam_valid && !pre_rbcam_valid)
                $warning("tb_int_assertions: post-rbCAM valid observed without same-cycle pre-rbCAM valid in smoke shell");
            if (enable_feb_egress_checks && feb_egress_valid && !feb_egress_ready)
                $warning("tb_int_assertions: FEB egress valid without ready in smoke shell");
        end
    end
endmodule
