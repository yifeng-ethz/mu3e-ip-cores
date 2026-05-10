// error_int_b002_supercore_runctl_propagation_test.sv
// Integration error-bucket repro for B002:
//   arb_hit_type0_supercore lane run_state does not advance after RC sequence.
//
// Verdict encoding:
//   Any lane stuck (run_state != expected after step) => UVM_ERROR
//                                                        "REPRO_HIT_INTEGRATION"
//   All lanes advance correctly                        => UVM_INFO
//                                                        "NO_REPRO_INTEGRATION"
//
// Author: Mu3e IP team
// Version : 26.2.0
// Date    : 20260504
// Change  : New — B002 integration repro test.

`timescale 1ns / 1ps

package error_int_b002_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import error_int_b002_seq_pkg::*;

    class error_int_b002_supercore_runctl_propagation_test extends uvm_test;
        `uvm_component_utils(error_int_b002_supercore_runctl_propagation_test)

        virtual runctl_b002_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_b002_if)::get(this, "", "vif", vif))
                `uvm_fatal("B002_TEST", "runctl_b002_if not in uvm_config_db — check error_int_b002_top.sv")
        endfunction

        virtual task run_phase(uvm_phase phase);
            error_int_b002_supercore_runctl_propagation_seq seq;
            bit any_repro;

            phase.raise_objection(this);

            // Wait for hardware reset to de-assert (active-high rst driven by top)
            @(negedge vif.rst);
            repeat (4) @(posedge vif.clk);

            seq = error_int_b002_supercore_runctl_propagation_seq::type_id::create("seq");
            seq.vif = vif;
            seq.start(null);

            any_repro = |seq.lane_repro_hit;

            // Report per-lane verdict
            for (int lane = 0; lane < 8; lane++) begin
                if (seq.lane_repro_hit[lane]) begin
                    `uvm_error("REPRO_HIT_INTEGRATION",
                        $sformatf("lane_%0d: run_state did NOT advance correctly through RC sequence — B002 REPRODUCED in integration sim",
                                  lane))
                end else begin
                    `uvm_info("NO_REPRO_INTEGRATION",
                        $sformatf("lane_%0d: run_state advanced correctly — no integration-level repro on this lane",
                                  lane),
                        UVM_NONE)
                end
            end

            if (!any_repro) begin
                `uvm_info("NO_REPRO_INTEGRATION",
                    "All 8 lanes advanced correctly through full RC sequence. Bug is silicon-side (Quartus optimization or timing-only).",
                    UVM_NONE)
                $display("*** B002 NO_REPRO_INTEGRATION — all lanes OK ***");
            end else begin
                `uvm_info("REPRO_HIT_INTEGRATION",
                    "At least one lane failed to advance. Bug is present in Qsys-inserted glue (adapter/splitter path).",
                    UVM_NONE)
                $display("*** B002 REPRO_HIT_INTEGRATION — see UVM_ERROR lines above ***");
            end

            phase.drop_objection(this);
        endtask

    endclass

endpackage
