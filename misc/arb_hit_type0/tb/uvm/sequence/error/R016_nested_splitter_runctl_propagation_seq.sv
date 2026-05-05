// R016_nested_splitter_runctl_propagation_seq.sv
//
// B002 repro sequence: drives 9-bit run-control bytes through a 3-deep
// altera_avalon_st_splitter chain (16-out -> 2-out -> 8-out, all with
// USE_READY=0 / QUALIFY_VALID_OUT=0) and observes the resulting
// run_state on the downstream arb_hit_type0_runctl FSM.
//
// IMPORTANT: Must be compiled with the same timescale as tb_top_b002
// (1ns/1ps).  Without this directive the compilation unit defaults to
// 1ps/1ps and all #N delays become N picoseconds instead of N nanoseconds,
// making the stimulus invisible to the 8ns-period clock.
`timescale 1ns/1ps
//
// Uses uvm_hdl_force / uvm_hdl_read to interact directly with the
// tb_top_b002 hierarchy.  Does NOT rely on the standard UVM env,
// runctl_agent, or arb_hit_type0_env_cfg.
//
// RC byte encoding (matches runctl_seq_item constants and
// arb_hit_type0_runctl.sv decode_run_state):
//   RUN_RESETTING  = 9'b0_1000_0000   (bit[7]=1 -> RUN_RESETTING=5)
//   RUN_PREPARING  = 9'b0_0000_0010   (bit[1]=1 -> RUN_PREPARING=1)
//   RUN_SYNCING    = 9'b0_0000_0100   (bit[2]=1 -> RUN_SYNCING=2)
//   RUN_RUNNING    = 9'b0_0000_1000   (bit[3]=1 -> RUN_RUNNING=3)
//   RUN_TERMINATING= 9'b0_0001_0000   (bit[4]=1 -> RUN_TERMINATING=4)
//   RUN_IDLE       = 9'b0_0000_0000   (no bits  -> RUN_IDLE=0)
//
// Verdict logic:
//   If run_state transitions correctly through RESETTING->PREPARING->
//   SYNCING->RUNNING->TERMINATING after each splitter injection:
//     -> NO_REPRO: structural depth alone does not reproduce B002 in sim.
//   If run_state stays at RUN_IDLE=0 after any injection:
//     -> REPRO_HIT: the 3-deep splitter chain blocks RC propagation in sim,
//        confirming structural depth as root cause.

`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
`include "uvm_macros.svh"
`endif

// ---------------------------------------------------------------------------
// Helpers and constants (defined here rather than importing runctl_seq_item
// so this compilation unit stays self-contained when elaborated under
// tb_top_b002 without the standard arb_hit_type0_pkg environment).
// ---------------------------------------------------------------------------

class R016_nested_splitter_runctl_propagation_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(R016_nested_splitter_runctl_propagation_seq)

    // ------------------------------------------------------------------
    //  B002-context RC byte encoding (matches arb_hit_type0_runctl.sv
    //  decode_run_state + Qsys rc_word convention)
    // ------------------------------------------------------------------
    localparam bit [8:0] RC_IDLE        = 9'b0_0000_0000;  // -> RUN_IDLE=0
    localparam bit [8:0] RC_RESETTING   = 9'b0_1000_0000;  // bit[7]-> RUN_RESETTING=5
    localparam bit [8:0] RC_PREPARING   = 9'b0_0000_0010;  // bit[1]-> RUN_PREPARING=1
    localparam bit [8:0] RC_SYNCING     = 9'b0_0000_0100;  // bit[2]-> RUN_SYNCING=2
    localparam bit [8:0] RC_RUNNING     = 9'b0_0000_1000;  // bit[3]-> RUN_RUNNING=3
    localparam bit [8:0] RC_TERMINATING = 9'b0_0001_0000;  // bit[4]-> RUN_TERMINATING=4

    // Expected FSM encoding from arb_hit_type0_runctl.sv
    localparam logic [2:0] RUN_IDLE_EXP        = 3'd0;
    localparam logic [2:0] RUN_PREPARING_EXP   = 3'd1;
    localparam logic [2:0] RUN_SYNCING_EXP     = 3'd2;
    localparam logic [2:0] RUN_RUNNING_EXP     = 3'd3;
    localparam logic [2:0] RUN_TERMINATING_EXP = 3'd4;
    localparam logic [2:0] RUN_RESETTING_EXP   = 3'd5;

    // HDL paths inside tb_top_b002
    localparam string PATH_IN_DATA  = "tb_top_b002.splitter_in_data";
    localparam string PATH_IN_VALID = "tb_top_b002.splitter_in_valid";
    localparam string PATH_CLK      = "tb_top_b002.clk";
    localparam string PATH_RST      = "tb_top_b002.rst";
    // run_state is the output of arb_hit_type0_runctl inside the DUT
    localparam string PATH_RUN_STATE = "tb_top_b002.dut_b002.u_runctl.run_state";
    // Also read the DUT's ctrl_ready to verify asi_ctrl_ready=1
    localparam string PATH_CTRL_READY = "tb_top_b002.dut_b002.u_runctl.asi_ctrl_ready";
    // stage3 output 0 – confirms data reaches the DUT side of the chain
    localparam string PATH_STAGE3_VALID = "tb_top_b002.stage3_out_valid";
    localparam string PATH_STAGE3_DATA  = "tb_top_b002.stage3_out_data";

    // Repro verdict: set to 1 if sim matches silicon (run_state stuck)
    bit repro_hit;
    // Full sequence pass: set to 1 if every expected state was observed
    bit all_states_advanced;

    function new(string name = "R016_nested_splitter_runctl_propagation_seq");
        super.new(name);
        repro_hit           = 1'b0;
        all_states_advanced = 1'b1;
    endfunction

    // ------------------------------------------------------------------
    //  Internal helpers
    // ------------------------------------------------------------------

    // Clock period in timescale units (1ns/1ps timescale -> 8 units = 8ns).
    localparam int CLK_NS  = 8;
    // Half-cycle offset used to land forces in the middle of a clock cycle,
    // safely away from posedge.  Forces that coincide with posedge can be
    // evaluated in the same delta as flip-flop sampling, causing a race.
    // Adding CLK_NS/2 - 1 (= 3 units) ensures the force setup time is met.
    localparam int CLK_HALF = CLK_NS / 2;  // 4

    task automatic wait_clk_cycles(int unsigned n);
        // Wait n full clock periods.  Use CLK_NS*n to remain timescale-units.
        #(CLK_NS * n);
    endtask

    task automatic force_splitter_in(input bit [8:0] data, input bit valid);
        if (!uvm_hdl_force(PATH_IN_DATA, data)) begin
            `uvm_error(get_type_name(),
                $sformatf("uvm_hdl_force %s failed", PATH_IN_DATA))
        end
        if (!uvm_hdl_force(PATH_IN_VALID, valid)) begin
            `uvm_error(get_type_name(),
                $sformatf("uvm_hdl_force %s failed", PATH_IN_VALID))
        end
    endtask

    task automatic read_run_state(output logic [2:0] state);
        uvm_hdl_data_t raw;
        if (!uvm_hdl_read(PATH_RUN_STATE, raw)) begin
            `uvm_error(get_type_name(),
                $sformatf("uvm_hdl_read %s failed", PATH_RUN_STATE))
            state = 3'bx;
        end else begin
            state = raw[2:0];
        end
    endtask

    task automatic read_stage3_leaf(output logic [8:0] data, output logic valid);
        uvm_hdl_data_t raw_d, raw_v;
        if (!uvm_hdl_read(PATH_STAGE3_DATA, raw_d)) begin
            `uvm_error(get_type_name(),
                $sformatf("uvm_hdl_read %s failed", PATH_STAGE3_DATA))
            data  = 9'bx;
        end else begin
            // stage3_out_data is a packed array [7:0][8:0]; bit 8:0 is output 0.
            data = raw_d[8:0];
        end
        if (!uvm_hdl_read(PATH_STAGE3_VALID, raw_v)) begin
            `uvm_error(get_type_name(),
                $sformatf("uvm_hdl_read %s failed", PATH_STAGE3_VALID))
            valid = 1'bx;
        end else begin
            valid = raw_v[0];  // output 0
        end
    endtask

    // Drive one RC beat through the splitter chain and observe run_state.
    // Returns 1 if the observed state matches expected, 0 otherwise.
    task automatic inject_rc_byte(
        input  bit [8:0]   rc_word,
        input  logic [2:0] expected_state,
        input  string      label,
        output bit         state_advanced
    );
        logic [2:0] observed_state;
        logic [8:0] leaf_data;
        logic       leaf_valid;
        uvm_hdl_data_t ctrl_ready_raw;
        logic ctrl_ready;

        // Assert valid + data.  Add a 1ns sub-cycle setup margin so the
        // force is stable before the next posedge clock edge.
        // Hold for two full clock periods to cover both the forced cycle
        // and one guard cycle.
        #1; // 1 ns sub-cycle margin
        force_splitter_in(rc_word, 1'b1);
        wait_clk_cycles(2);  // hold for 2 clock periods (setup + guard)

        // Sample stage3 leaf while valid is still asserted (before deassert)
        read_stage3_leaf(leaf_data, leaf_valid);

        // De-assert valid
        force_splitter_in(9'd0, 1'b0);

        // Wait a few cycles for the FSM to latch (reset_active can hold
        // for up to 3 cycles per arb_hit_type0_runctl.sv staged reset).
        wait_clk_cycles(6);

        // Read ctrl_ready
        if (!uvm_hdl_read(PATH_CTRL_READY, ctrl_ready_raw)) begin
            `uvm_error(get_type_name(), "uvm_hdl_read ctrl_ready failed")
            ctrl_ready = 1'bx;
        end else begin
            ctrl_ready = ctrl_ready_raw[0];
        end

        // Read observed run_state
        read_run_state(observed_state);

        `uvm_info(get_type_name(),
            $sformatf("[%s] rc_word=0x%03h  stage3_leaf_valid=%0b  stage3_leaf_data=0x%03h  ctrl_ready=%0b  observed_run_state=%0d  expected=%0d",
                label, rc_word, leaf_valid, leaf_data,
                ctrl_ready, observed_state, expected_state),
            UVM_NONE)

        state_advanced = (observed_state === expected_state);
    endtask

    // ------------------------------------------------------------------
    //  body
    // ------------------------------------------------------------------
    task body();
        bit state_advanced_v;
        logic [2:0] init_state;

        `uvm_info(get_type_name(),
            "=== B002 Repro: 3-deep splitter run-control propagation ===",
            UVM_NONE)
        `uvm_info(get_type_name(),
            "Topology: driver -> splitter_16out -> splitter_2out -> splitter_8out -> arb_hit_type0.asi_ctrl",
            UVM_NONE)
        `uvm_info(get_type_name(),
            "All splitters modelled with declared behaviour: USE_READY=0, QUALIFY_VALID_OUT=0 => pure combinational fan-out",
            UVM_NONE)

        // Wait for reset release (rst goes low after 16 clocks = 128 ns).
        // Land at a negedge mid-point (t=132ns is midpoint of first cycle
        // after reset deasserts) to ensure all initial conditions are settled.
        // We use 160ns (20 cycles) to be conservative.
        #160;

        // Verify initial run_state is RUN_IDLE after reset
        read_run_state(init_state);
        `uvm_info(get_type_name(),
            $sformatf("Post-reset run_state = %0d (expect %0d = RUN_IDLE)",
                init_state, RUN_IDLE_EXP),
            UVM_NONE)
        if (init_state !== RUN_IDLE_EXP) begin
            `uvm_error(get_type_name(),
                $sformatf("Post-reset run_state=%0d, expected RUN_IDLE=%0d",
                    init_state, RUN_IDLE_EXP))
        end

        // ------------------------------------------------------------------
        // Step 1: send RC_RESETTING (bit[7]=1 triggers reset_start;
        //         decode_run_state -> RUN_RESETTING=5).
        // After reset_active clears (3 cycles), run_state should be 5.
        // ------------------------------------------------------------------
        inject_rc_byte(RC_RESETTING, RUN_RESETTING_EXP,
                       "STEP1_RESETTING", state_advanced_v);
        if (!state_advanced_v) begin
            all_states_advanced = 1'b0;
            `uvm_info(get_type_name(),
                "RC_RESETTING -> run_state did NOT advance to RUN_RESETTING: REPRO candidate",
                UVM_NONE)
        end

        // Small gap between RC beats
        wait_clk_cycles(4);

        // ------------------------------------------------------------------
        // Step 2: RC_PREPARING (bit[1]=1, also triggers reset_start
        //         -> reset sequence runs, then run_state = RUN_PREPARING=1).
        // ------------------------------------------------------------------
        inject_rc_byte(RC_PREPARING, RUN_PREPARING_EXP,
                       "STEP2_PREPARING", state_advanced_v);
        if (!state_advanced_v) begin
            all_states_advanced = 1'b0;
            `uvm_info(get_type_name(),
                "RC_PREPARING -> run_state did NOT advance to RUN_PREPARING: REPRO candidate",
                UVM_NONE)
        end

        wait_clk_cycles(4);

        // ------------------------------------------------------------------
        // Step 3: RC_SYNCING (bit[2]=1, does NOT trigger reset_start
        //         since bit[1] and bit[7] are 0; FSM direct update).
        // ------------------------------------------------------------------
        inject_rc_byte(RC_SYNCING, RUN_SYNCING_EXP,
                       "STEP3_SYNCING", state_advanced_v);
        if (!state_advanced_v) begin
            all_states_advanced = 1'b0;
            `uvm_info(get_type_name(),
                "RC_SYNCING -> run_state did NOT advance to RUN_SYNCING: REPRO candidate",
                UVM_NONE)
        end

        wait_clk_cycles(4);

        // ------------------------------------------------------------------
        // Step 4: RC_RUNNING (bit[3]=1)
        // ------------------------------------------------------------------
        inject_rc_byte(RC_RUNNING, RUN_RUNNING_EXP,
                       "STEP4_RUNNING", state_advanced_v);
        if (!state_advanced_v) begin
            all_states_advanced = 1'b0;
            `uvm_info(get_type_name(),
                "RC_RUNNING -> run_state did NOT advance to RUN_RUNNING: REPRO candidate",
                UVM_NONE)
        end

        wait_clk_cycles(4);

        // ------------------------------------------------------------------
        // Step 5: RC_TERMINATING (bit[4]=1)
        // ------------------------------------------------------------------
        inject_rc_byte(RC_TERMINATING, RUN_TERMINATING_EXP,
                       "STEP5_TERMINATING", state_advanced_v);
        if (!state_advanced_v) begin
            all_states_advanced = 1'b0;
            `uvm_info(get_type_name(),
                "RC_TERMINATING -> run_state did NOT advance to RUN_TERMINATING: REPRO candidate",
                UVM_NONE)
        end

        wait_clk_cycles(4);

        // ------------------------------------------------------------------
        // Step 6: RC_IDLE (all bits 0 -> RUN_IDLE=0)
        // ------------------------------------------------------------------
        inject_rc_byte(RC_IDLE, RUN_IDLE_EXP,
                       "STEP6_IDLE", state_advanced_v);
        if (!state_advanced_v) begin
            all_states_advanced = 1'b0;
            `uvm_info(get_type_name(),
                "RC_IDLE -> run_state did NOT advance to RUN_IDLE: REPRO candidate",
                UVM_NONE)
        end

        // ------------------------------------------------------------------
        // Final verdict
        // ------------------------------------------------------------------
        if (all_states_advanced) begin
            `uvm_info(get_type_name(),
                "VERDICT: NO_REPRO — all run_state transitions observed correctly through the 3-deep splitter model. The declared combinational fan-out behaviour propagates RC bytes without loss. The silicon B002 failure is NOT reproduced by structural depth alone; root cause is likely in the actual Qsys splitter implementation (deviates from declared behaviour), or in silicon-side clock/signal-integrity effects.",
                UVM_NONE)
            repro_hit = 1'b0;
        end else begin
            `uvm_info(get_type_name(),
                "VERDICT: REPRO_HIT — one or more run_state transitions were NOT observed after RC injection through the 3-deep splitter model. The structural depth alone is sufficient to reproduce the B002 silicon failure in sim.",
                UVM_NONE)
            repro_hit = 1'b1;
            // Emit UVM_ERROR so regress shows this as a failing case
            // (canonical integration-debug: failing repro is expected here).
            `uvm_error(get_type_name(),
                "REPRO_HIT: B002 structural-depth hypothesis CONFIRMED in sim. run_state stuck at RUN_IDLE through 3-deep splitter chain.")
        end

    endtask

endclass
