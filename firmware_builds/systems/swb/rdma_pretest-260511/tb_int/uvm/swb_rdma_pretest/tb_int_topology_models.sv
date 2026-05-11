// tb_int_topology_models.sv
// Behavioural topology stubs for SWB rdma_pretest-260511 tb_int.
//
// Author : Claude Opus
// Date   : 20260511
// Scope  : Phase 3 BUG-RC-RESET-SCWEDGE behavioural repro. Model the
//          runctl_mgmt_host ext_hard_reset broadcast topology that the FEB
//          Qsys system implements but the SWB tb_int stub responder cannot
//          observe directly (TB_INT_BIND_REAL_DUT undefined in default
//          mode).
//
// Topology being modelled (mirrors feb_system_v3.qsys:586..590 + the 16
// SC-plane reset sinks at quartus_systems/debug_sc_system_v3.qsys:1093..1177
// on the FEB; the SWB tb_int is the upstream sender of the same opcode
// stream so the modelling is purely about exercising the post-reset wedge
// signature locally inside the SWB harness):
//
//      runctl_phy_if (9-bit AVST, K-flag bit 8)
//             |
//             v
//      mock_ext_hard_reset (sticky, 16384-cycle bounded pulse)
//             |
//             v
//      2-flop pipeline (mirrors ext_reset_pipe2_cclk156)
//             |
//             v
//      mock_sc_plane_reset
//             |
//             v
//      sc_avmm_if read responder
//        - while  mock_sc_plane_reset=1: readdata = 0xEEEE_EEEE,
//                                        readdatavalid forced LOW
//        - otherwise: existing 0x4849_5354 ("HIST") stub pattern
//
// BUG_RC_RESET_SCWEDGE_FIXED guard:
//   When defined, the connection mock_ext_hard_reset -> mock_sc_plane_reset
//   is BROKEN, so the SC plane stays clean across CMD_RESET 0x30. This is
//   the fix being applied in parallel in feb_system_v3.qsys.

`ifndef TB_INT_SWB_TOPOLOGY_MODELS_SV
`define TB_INT_SWB_TOPOLOGY_MODELS_SV

// CMD_RESET opcode encoding on the synclink AVST PHY:
//   bit 8       = K-flag (1 => control symbol)
//   bits [7:0]  = opcode byte (0x30 == CMD_RESET)
//   => full 9-bit symbol = 9'h130
`define TB_INT_OP_CMD_RESET_SYMBOL 9'h130

// Bounded hard-reset pulse width in clk cycles. runctl_mgmt_host emits a
// 16384-cycle ext_hard_reset and lets it fall again on its own. We mirror
// that here so the wedge is observable for a finite window and the test
// driver doesn't have to issue a separate STOP_RESET (mirrors the on-board
// symptom: STOP_RESET 0x31 does NOT recover; the reset cascades autonomously
// to the SC plane).
`define TB_INT_HARD_RESET_CYCLES 16384

// SC-WEDGE response payload on silicon (rsp=RSP3, payload 0xEEEE_EEEE).
`define TB_INT_SC_WEDGE_PAYLOAD 32'hEEEE_EEEE

module mock_sc_plane_reset_model #(
    parameter int unsigned HARD_RESET_CYCLES = `TB_INT_HARD_RESET_CYCLES
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [8:0]  runctl_data,
    input  logic        runctl_valid,
    output logic        mock_ext_hard_reset,
    output logic        mock_sc_plane_reset
);
    // Detect the CMD_RESET opcode on runctl_phy. The bounded pulse is a
    // sticky counter that decrements every clk while >0.
    logic [$clog2(HARD_RESET_CYCLES+1)-1:0] cycle_cnt;
    logic                                    pulse_active;

    // Sticky ext_hard_reset pulse. Mirrors runctl_mgmt_host's bounded
    // 16384-cycle output.
    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_cnt    <= '0;
            pulse_active <= 1'b0;
        end else begin
            if (runctl_valid && runctl_data == `TB_INT_OP_CMD_RESET_SYMBOL) begin
                cycle_cnt    <= HARD_RESET_CYCLES[$bits(cycle_cnt)-1:0];
                pulse_active <= 1'b1;
            end else if (cycle_cnt != '0) begin
                cycle_cnt    <= cycle_cnt - 1'b1;
                pulse_active <= (cycle_cnt != 1);
            end else begin
                pulse_active <= 1'b0;
            end
        end
    end

    assign mock_ext_hard_reset = pulse_active;

    // 2-flop pipeline. Mirrors feb_system_v3.qsys:586..590
    // ext_reset_pipe2_cclk156 chain. Without the fix the pulse propagates
    // straight through. With the fix the connection is broken and the SC
    // plane stays clean.
    logic stage1, stage2;
`ifdef BUG_RC_RESET_SCWEDGE_FIXED
    // FIX: break the mock_ext_hard_reset -> mock_sc_plane_reset connection.
    // Mirrors the parallel Qsys fix that disconnects
    // ext_reset_pipe2_cclk156.out_reset from control_path_subsystem.clk156_in_rst
    // and drives clk156_in_rst directly from cclk156_source.clk_reset.
    always_ff @(posedge clk) begin
        if (rst) begin
            stage1 <= 1'b0;
            stage2 <= 1'b0;
        end else begin
            stage1 <= 1'b0; // disconnected from mock_ext_hard_reset
            stage2 <= 1'b0;
        end
    end
`else
    // PRE-FIX: 2-flop pipeline carries the broadcast straight through.
    always_ff @(posedge clk) begin
        if (rst) begin
            stage1 <= 1'b0;
            stage2 <= 1'b0;
        end else begin
            stage1 <= mock_ext_hard_reset;
            stage2 <= stage1;
        end
    end
`endif

    assign mock_sc_plane_reset = stage2;
endmodule

`endif // TB_INT_SWB_TOPOLOGY_MODELS_SV
