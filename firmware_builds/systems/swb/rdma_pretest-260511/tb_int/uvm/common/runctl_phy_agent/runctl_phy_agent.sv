// runctl_phy_agent.sv
// Active run-control source for synclink AVST 9-bit commands.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable run-control agent with run-window timestamp hooks.

package tb_int_runctl_phy_agent_pkg;

    import uvm_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        RUNCTL_IDLE,
        RUNCTL_RUN_PREP,
        RUNCTL_SYNC,
        RUNCTL_RUNNING,
        RUNCTL_TERMINATING,
        RUNCTL_RESET
    } runctl_state_e;

    class runctl_phy_item extends uvm_sequence_item;
        `uvm_object_utils(runctl_phy_item)

        rand runctl_state_e state;
        rand int unsigned   hold_cycles;

        constraint hold_c {
            hold_cycles inside {[1:1000000]};
        }

        function new(string name = "runctl_phy_item");
            super.new(name);
        endfunction
    endclass

    class runctl_phy_sequencer extends uvm_sequencer#(runctl_phy_item);
        `uvm_component_utils(runctl_phy_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class runctl_phy_driver extends uvm_driver#(runctl_phy_item);
        `uvm_component_utils(runctl_phy_driver)

        virtual runctl_phy_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_phy_if)::get(this, "", "vif", vif))
                `uvm_fatal("RUNCTL_PHY", "runctl_phy_if not found")
        endfunction

        function automatic bit [8:0] state_to_symbol(runctl_state_e state);
            case (state)
                RUNCTL_IDLE:        return 9'h001;
                RUNCTL_RUN_PREP:    return 9'h002;
                RUNCTL_SYNC:        return 9'h004;
                RUNCTL_RUNNING:     return 9'h008;
                RUNCTL_TERMINATING: return 9'h010;
                RUNCTL_RESET:       return 9'h100;
                default:            return 9'h001;
            endcase
        endfunction

        virtual task drive_item(runctl_phy_item item);
            @(negedge vif.clk);
            vif.data  <= state_to_symbol(item.state);
            vif.error <= 3'b000;
            vif.valid <= 1'b1;
            case (item.state)
                RUNCTL_RUN_PREP: tb_int_run_window_db::reset();
                RUNCTL_RUNNING: begin
                    tb_int_run_window_db::note_run_start($time);
                    tb_int_run_window_db::note_stable_start($time);
                end
                RUNCTL_TERMINATING: begin
                    tb_int_run_window_db::note_stable_end($time);
                    tb_int_run_window_db::note_run_end($time);
                end
                default: begin
                end
            endcase
            repeat (item.hold_cycles) @(posedge vif.clk);
            @(negedge vif.clk);
            vif.valid <= 1'b0;
        endtask

        virtual task run_phase(uvm_phase phase);
            runctl_phy_item item;

            vif.clear();
            tb_int_run_window_db::reset();
            forever begin
                seq_item_port.get_next_item(item);
                drive_item(item);
                seq_item_port.item_done();
            end
        endtask
    endclass

    class runctl_phy_agent extends uvm_agent;
        `uvm_component_utils(runctl_phy_agent)

        runctl_phy_sequencer sqr;
        runctl_phy_driver    drv;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = runctl_phy_sequencer::type_id::create("sqr", this);
            drv = runctl_phy_driver::type_id::create("drv", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

endpackage
