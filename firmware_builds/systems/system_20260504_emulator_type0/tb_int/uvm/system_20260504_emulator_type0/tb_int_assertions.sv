// tb_int_assertions.sv
// Focus-build integration smoke assertions and latency guardrails.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Use SciFi N_SHD=128 FEB-egress latency window.

module tb_int_assertions (
    input logic clk,
    input logic rst,
    input logic stage_a_valid,
    input logic pre_rbcam_valid,
    input logic post_rbcam_valid,
    input logic feb_egress_valid
);
    int unsigned cycle_count;
    int unsigned last_stage_a_cycle;
    int unsigned pre_rbcam_drop;
    int unsigned post_rbcam_drop;
    int unsigned feb_egress_drop;
    int unsigned pre_rbcam_accept_window_fail;

    localparam int unsigned PRE_RBCAM_MAX_CYCLES_CONST = 2000;
    localparam int unsigned POST_RBCAM_MAX_CYCLES_CONST = 3000;
    localparam int unsigned POST_RBCAM_TO_FEB_EGRESS_MAX_CYCLES_CONST = 5096;

    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_count        <= 0;

            last_stage_a_cycle <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (stage_a_valid)
                last_stage_a_cycle <= cycle_count;
        end
    end

    // Per-stage monitors are required because R-2026-04-18-01 in
    // mutrig_timestamp_processor showed that coarse-counter wrap bugs can
    // silently create wrong tcc_8n before rbCAM and look like downstream loss.
    property stage_a_to_pre_rbcam_p;
        @(posedge clk) disable iff (rst)
            stage_a_valid |-> ##[0:PRE_RBCAM_MAX_CYCLES_CONST] pre_rbcam_valid;
    endproperty

    property pre_rbcam_to_post_rbcam_p;
        @(posedge clk) disable iff (rst)
            pre_rbcam_valid |-> ##[0:POST_RBCAM_MAX_CYCLES_CONST] post_rbcam_valid;
    endproperty

    // Mu3e SciFi FEB egress uses N_SHD = 128, not the IP-internal default 256.
    // `feb_frame_assembly_hw.tcl:100-105` defines the N_SHD parameter; the
    // system Qsys-Tcl overrides the instance to 128. `feb_frame_assembly.vhd:1703`
    // gives the bucket-cycle relationship, so one frame is 128 * 16 = 2048 cycles.
    // `tb_int/doc/DV_PLAN.md` section 2.2 defines the absolute FEB-egress window:
    // lower = 2000 + 2048 = 4048 cycles, upper = 3000 + 4096 = 7096 cycles.
    // The relative Post-rbCAM -> FEB-egress SVA upper is 2 frames plus 1000 cycles
    // of drain residue: 4096 + 1000 = 5096 cycles.
    property post_rbcam_to_feb_egress_p;
        @(posedge clk) disable iff (rst)
            post_rbcam_valid |-> ##[0:POST_RBCAM_TO_FEB_EGRESS_MAX_CYCLES_CONST] feb_egress_valid;
    endproperty

    property pre_rbcam_accept_window_p;
        @(posedge clk) disable iff (rst)
            pre_rbcam_valid |-> ((cycle_count - last_stage_a_cycle) <= PRE_RBCAM_MAX_CYCLES_CONST);
    endproperty

    stage_a_to_pre_rbcam_a : assert property (stage_a_to_pre_rbcam_p)
        else begin
            pre_rbcam_drop++;
            $error("pre_rbcam_drop: Stage A hit missed Pre-RbCAM %0d-cycle window",
                   PRE_RBCAM_MAX_CYCLES_CONST);
        end

    pre_rbcam_to_post_rbcam_a : assert property (pre_rbcam_to_post_rbcam_p)
        else begin
            post_rbcam_drop++;
            $error("post_rbcam_drop: Pre-RbCAM hit missed Post-RbCAM %0d-cycle window",
                   POST_RBCAM_MAX_CYCLES_CONST);
        end

    post_rbcam_to_feb_egress_a : assert property (post_rbcam_to_feb_egress_p)
        else begin
            feb_egress_drop++;
            $error("feb_egress_drop: Post-RbCAM hit missed FEB-egress %0d-cycle relative window",
                   POST_RBCAM_TO_FEB_EGRESS_MAX_CYCLES_CONST);
        end

    pre_rbcam_accept_window_a : assert property (pre_rbcam_accept_window_p)
        else begin
            pre_rbcam_accept_window_fail++;
            $error("pre_rbcam_accept_window_fail: Pre-RbCAM accepted hit outside Stage-A + %0d cycles",
                   PRE_RBCAM_MAX_CYCLES_CONST);
        end
endmodule
