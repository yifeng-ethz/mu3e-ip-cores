// error_int_b002_supercore_runctl_propagation_seq.sv
// 6-step RC sequence driver for B002 integration repro.
// Drives run_ctrl_data / run_ctrl_valid on the virtual interface supplied
// by the test, then samples run_state[2:0] from each lane's runctl instance
// via uvm_hdl_read.  No behavioral mock — the DUT under stimulus is the
// real generated arb_hit_type0_supercore.
//
// Author: Mu3e IP team
// Version : 26.2.0
// Date    : 20260504
// Change  : New — B002 integration repro sequence.

`timescale 1ns / 1ps

package error_int_b002_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------------------------
    // Virtual interface type used by this sequence.
    // The test binds a runctl_b002_if handle into the config-db under the
    // key "runctl_b002_vif".
    // -------------------------------------------------------------------------

    // RC word encoding (bit positions match arb_hit_type0_runctl.sv)
    //   bit 7 = RESETTING (reset pulse)
    //   bit 1 = PREPARING
    //   bit 2 = SYNCING
    //   bit 3 = RUNNING
    //   bit 4 = TERMINATING
    //   bit 0 = (unused / IDLE when all zero)
    localparam logic [8:0] RC_RESETTING   = 9'h080;
    localparam logic [8:0] RC_PREPARING   = 9'h002;
    localparam logic [8:0] RC_SYNCING     = 9'h004;
    localparam logic [8:0] RC_RUNNING     = 9'h008;
    localparam logic [8:0] RC_TERMINATING = 9'h010;
    localparam logic [8:0] RC_IDLE        = 9'h000;

    // Expected run_state progression from arb_hit_type0_runctl.sv constants
    //   RUN_RESETTING  = 5
    //   RUN_PREPARING  = 1
    //   RUN_SYNCING    = 2
    //   RUN_RUNNING    = 3
    //   RUN_TERMINATING= 4
    //   RUN_IDLE       = 0
    localparam int unsigned EXP_AFTER_RESETTING   = 5;
    localparam int unsigned EXP_AFTER_PREPARING   = 1;
    localparam int unsigned EXP_AFTER_SYNCING      = 2;
    localparam int unsigned EXP_AFTER_RUNNING      = 3;
    localparam int unsigned EXP_AFTER_TERMINATING  = 4;
    localparam int unsigned EXP_AFTER_IDLE         = 0;

    // Note: run_state is read from the virtual interface's input ports
    // (wired from the DUT hierarchy in error_int_b002_top.sv) so that no
    // DPI / uvm_hdl_read is needed even when compiled with +define+UVM_NO_DPI.

    // -------------------------------------------------------------------------
    class error_int_b002_supercore_runctl_propagation_seq extends uvm_sequence;
        `uvm_object_utils(error_int_b002_supercore_runctl_propagation_seq)

        // Virtual interface handle — set by the test via uvm_config_db
        virtual interface runctl_b002_if vif;

        // Per-lane result tracking
        // Index [0..7]: 0 = NO_REPRO (lane progressed correctly),
        //               1 = REPRO_HIT (lane stuck or wrong state)
        bit [7:0] lane_repro_hit;

        function new(string name = "error_int_b002_supercore_runctl_propagation_seq");
            super.new(name);
            lane_repro_hit = 8'h00;
        endfunction

        // -----------------------------------------------------------------------
        // Helper: read run_state from all 8 lanes via virtual interface inputs
        // (wired from DUT hierarchy in error_int_b002_top.sv — no DPI needed)
        // -----------------------------------------------------------------------
        task read_all_lane_states(output logic [2:0] states[8]);
            // Sample after any combinational settle: wait 1 step past current time
            #1;
            states[0] = vif.run_state_0;
            states[1] = vif.run_state_1;
            states[2] = vif.run_state_2;
            states[3] = vif.run_state_3;
            states[4] = vif.run_state_4;
            states[5] = vif.run_state_5;
            states[6] = vif.run_state_6;
            states[7] = vif.run_state_7;
        endtask

        // -----------------------------------------------------------------------
        // Helper: drive one RC beat (1 cycle valid=1, then gap cycles valid=0)
        // -----------------------------------------------------------------------
        task drive_rc_beat(input logic [8:0] data_word, input int gap_cycles = 8);
            @(posedge vif.clk);
            #1;  // drive after clock edge
            vif.run_ctrl_data  = data_word;
            vif.run_ctrl_valid = 1'b1;
            @(posedge vif.clk);
            #1;
            vif.run_ctrl_valid = 1'b0;
            vif.run_ctrl_data  = RC_IDLE;
            repeat (gap_cycles) @(posedge vif.clk);
        endtask

        // -----------------------------------------------------------------------
        // Helper: check lane states vs expected, log results
        // -----------------------------------------------------------------------
        task check_lane_states(
            input logic [2:0] states[8],
            input int unsigned expected_state,
            input string step_name
        );
            for (int lane = 0; lane < 8; lane++) begin
                if (states[lane] !== expected_state[2:0]) begin
                    `uvm_info("B002_SEQ",
                        $sformatf("After %s: lane_%0d run_state=%0d (expected %0d) [STUCK]",
                                  step_name, lane, states[lane], expected_state),
                        UVM_NONE)
                    lane_repro_hit[lane] = 1'b1;
                end else begin
                    `uvm_info("B002_SEQ",
                        $sformatf("After %s: lane_%0d run_state=%0d [OK]",
                                  step_name, lane, states[lane]),
                        UVM_NONE)
                end
            end
        endtask

        // -----------------------------------------------------------------------
        // Main body
        // -----------------------------------------------------------------------
        virtual task body();
            logic [2:0] states[8];
            string path;

            `uvm_info("B002_SEQ", "=== B002 RC propagation sequence START ===", UVM_NONE)

            // ---- Step 1: RESETTING (0x080) ----
            `uvm_info("B002_SEQ", "Step 1: drive RC_RESETTING (0x080)", UVM_NONE)
            drive_rc_beat(RC_RESETTING, 8);
            read_all_lane_states(states);
            check_lane_states(states, EXP_AFTER_RESETTING, "RESETTING");

            // ---- Step 2: PREPARING (0x002) ----
            `uvm_info("B002_SEQ", "Step 2: drive RC_PREPARING (0x002)", UVM_NONE)
            drive_rc_beat(RC_PREPARING, 8);
            read_all_lane_states(states);
            check_lane_states(states, EXP_AFTER_PREPARING, "PREPARING");

            // ---- Step 3: SYNCING (0x004) ----
            `uvm_info("B002_SEQ", "Step 3: drive RC_SYNCING (0x004)", UVM_NONE)
            drive_rc_beat(RC_SYNCING, 8);
            read_all_lane_states(states);
            check_lane_states(states, EXP_AFTER_SYNCING, "SYNCING");

            // ---- Step 4: RUNNING (0x008) ----
            `uvm_info("B002_SEQ", "Step 4: drive RC_RUNNING (0x008)", UVM_NONE)
            drive_rc_beat(RC_RUNNING, 8);
            read_all_lane_states(states);
            check_lane_states(states, EXP_AFTER_RUNNING, "RUNNING");

            // ---- Step 5: TERMINATING (0x010) ----
            `uvm_info("B002_SEQ", "Step 5: drive RC_TERMINATING (0x010)", UVM_NONE)
            drive_rc_beat(RC_TERMINATING, 8);
            read_all_lane_states(states);
            check_lane_states(states, EXP_AFTER_TERMINATING, "TERMINATING");

            // ---- Step 6: IDLE (0x000) ----
            `uvm_info("B002_SEQ", "Step 6: drive RC_IDLE (0x000)", UVM_NONE)
            drive_rc_beat(RC_IDLE, 8);
            read_all_lane_states(states);
            check_lane_states(states, EXP_AFTER_IDLE, "IDLE");

            `uvm_info("B002_SEQ", "=== B002 RC propagation sequence END ===", UVM_NONE)
        endtask

    endclass

endpackage
