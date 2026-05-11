// tb_int_topology_models.sv
// Behavioural topology stubs for FEB v3_pretest-260511 tb_int.
//
// Author : Claude Opus
// Date   : 20260511
// Scope  : Phase 3 BUG-RC-RUN-EMUL behavioural repro. Models the
//          run_control_splitter (USE_READY=0) topology that the FEB Qsys
//          system uses to broadcast the run_state one-hot to 8
//          emulator_mutrig instances, plus a tiny "RUNNING enable" gate
//          that wires each emulator output back to stage_a_vif.valid so
//          the post-rbCAM datapath only sees hits when the splitter
//          actually delivers RUNNING.
//
// Topology being modelled (mirrors run_control_splitter inside
// scifi_datapath_system_v3_pipe.qsys):
//
//      runctl_phy_if .valid + .data ([7:0]==0x12 START_RUN)
//             |
//             v
//      mock_run_control_splitter (USE_READY=0 broadcast)
//             | out_valid <= in_valid & (out0_ready_int & out1_ready_int &
//             |                          ... & out8_ready_int)
//             |
//             +--> out[0]..out[7] -> emulator_mutrig RUNNING enable
//             '--> out[8]         -> spare lane (legacy aux)
//
// Auto-memory feedback_qsys_terminate_dangling: a USE_READY=0 splitter
// still has internal ready inputs. Un-driven outN_ready inputs synthesize
// as logic 0 (AND default), gating the broadcast to 0 on silicon. In
// behavioural sim the dangling logic 0 default reproduces the bug.
//
// BUG_RC_RUN_EMUL_FIXED guard:
//   When defined, outN_ready inputs are tied to 1'b1 explicitly, mirroring
//   the Qsys-level fix (forcing outN_ready connections to a constant
//   driver). The broadcast then passes through and stage_a_vif.valid is
//   gated true so the post-rbCAM hits actually flow.

`ifndef TB_INT_FEB_TOPOLOGY_MODELS_SV
`define TB_INT_FEB_TOPOLOGY_MODELS_SV

// START_RUN opcode encoding on the synclink AVST PHY:
//   bit 8       = K-flag (1 => control symbol)
//   bits [7:0]  = opcode byte (0x12 == CMD_START_RUN)
//   => full 9-bit symbol = 9'h112
`define TB_INT_OP_START_RUN_SYMBOL 9'h112

// END_RUN opcode (0x13) and ABORT_RUN (0x14) clear the RUNNING latch.
`define TB_INT_OP_END_RUN_SYMBOL    9'h113
`define TB_INT_OP_ABORT_RUN_SYMBOL  9'h114

// Number of fanout ports on the splitter. The Qsys run_control_splitter
// has 9 outputs in scifi_datapath_system_v3_pipe.qsys; outputs 0..7 fan
// to the 8 emulator_mutrig lanes, output 8 is an aux/legacy tap.
parameter int TB_INT_SPLITTER_FANOUT_PORTS = 9;

module mock_run_control_splitter (
    input  logic        clk,
    input  logic        rst,

    // Avalon-ST input port. valid + 8-bit one-hot run state; data carries
    // the RUNNING flag in bit 0 (the only bit we need for the broadcast).
    input  logic        in_valid,
    input  logic [7:0]  in_data,

    // 9 Avalon-ST output ports. valid + 8-bit data passthrough.
    output logic                                       out_valid [TB_INT_SPLITTER_FANOUT_PORTS],
    output logic [7:0]                                 out_data  [TB_INT_SPLITTER_FANOUT_PORTS],

    // 9 outN_ready inputs. In Qsys these would be drawn as Avalon-ST ready
    // backpressure, but with USE_READY=0 the splitter ignores them on
    // paper. On silicon, the AND default still consumes them; an undriven
    // outN_ready collapses out_valid to 0. We model both the dangling
    // (no driver) and the explicit-1 case via the BUG_RC_RUN_EMUL_FIXED
    // guard.
    input  logic                                       out_ready [TB_INT_SPLITTER_FANOUT_PORTS]
);
    // Internal ready gate. Each lane's ready_int is the OR of the explicit
    // input and the BUG_RC_RUN_EMUL_FIXED tie. The B002 silicon symptom
    // models the case where the input is dangling (logic 0 by AND default).
    logic [TB_INT_SPLITTER_FANOUT_PORTS-1:0] ready_int;
    logic                                    ready_and;

    always_comb begin
        ready_and = 1'b1;
        for (int i = 0; i < TB_INT_SPLITTER_FANOUT_PORTS; i++) begin
`ifdef BUG_RC_RUN_EMUL_FIXED
            // FIX: explicit tie-to-1 mirrors the Qsys connection-list
            // change "set <splitter>.out<N>_ready <- one_const.out".
            ready_int[i] = 1'b1;
`else
            // PRE-FIX: the input is honored as-is. In a real testbench the
            // out_ready ports get no driver, so SV resolves the value to
            // X. In Qsys synthesis the resolution is "logic 0 by AND default"
            // -- match that by treating X as 0 here.
            ready_int[i] = (out_ready[i] === 1'b1) ? 1'b1 : 1'b0;
`endif
            ready_and = ready_and & ready_int[i];
        end
    end

    // Broadcast. Mirrors the Qsys "USE_READY=0 means broadcast unconditionally"
    // contract on paper, but inserts the AND-of-internal-readies that the
    // silicon implementation does NOT remove. With pre-fix ready_int=0 the
    // out_valid collapses to 0 even though USE_READY=0 was supposed to mean
    // "ignore ready".
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < TB_INT_SPLITTER_FANOUT_PORTS; i++) begin
                out_valid[i] <= 1'b0;
                out_data[i]  <= 8'h00;
            end
        end else begin
            for (int i = 0; i < TB_INT_SPLITTER_FANOUT_PORTS; i++) begin
                out_valid[i] <= in_valid & ready_and;
                out_data[i]  <= in_data;
            end
        end
    end
endmodule

// Tiny opcode-to-one-hot extractor + RUNNING latch. Mirrors the
// runctl_mgmt_host receive FSM: latch RUNNING on opcode 0x12 (START_RUN),
// clear on 0x13/0x14 (END_RUN/ABORT_RUN).
module mock_run_state_latch (
    input  logic        clk,
    input  logic        rst,
    input  logic [8:0]  runctl_data,
    input  logic        runctl_valid,
    output logic [7:0]  run_state_onehot, // bit 0 = RUNNING
    output logic        run_state_valid
);
    logic running_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            running_q <= 1'b0;
        end else if (runctl_valid) begin
            if      (runctl_data == `TB_INT_OP_START_RUN_SYMBOL)  running_q <= 1'b1;
            else if (runctl_data == `TB_INT_OP_END_RUN_SYMBOL)    running_q <= 1'b0;
            else if (runctl_data == `TB_INT_OP_ABORT_RUN_SYMBOL)  running_q <= 1'b0;
        end
    end

    assign run_state_onehot = {7'b0, running_q};
    // Drive the splitter input valid for as long as RUNNING is latched.
    // This is broader than the on-board one-shot run-state broadcast but
    // matches what the splitter must propagate during the run window.
    assign run_state_valid  = running_q;
endmodule

`endif // TB_INT_FEB_TOPOLOGY_MODELS_SV
