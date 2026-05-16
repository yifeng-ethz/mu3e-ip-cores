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
        localparam bit [8:0] SYNCLINK_IDLE_COMMA = 9'h1BC;
        localparam bit [7:0] CMD_RUN_PREPARE = 8'h10;
        localparam bit [7:0] CMD_RUN_SYNC    = 8'h11;
        localparam bit [7:0] CMD_START_RUN   = 8'h12;
        localparam bit [7:0] CMD_END_RUN     = 8'h13;
        localparam bit [7:0] CMD_RESET       = 8'h30;
        localparam bit [31:0] DEFAULT_RUN_NUMBER = 32'h2026_0515;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual runctl_phy_if)::get(this, "", "vif", vif))
                `uvm_fatal("RUNCTL_PHY", "runctl_phy_if not found")
        endfunction

        function automatic bit [7:0] state_to_cmd(runctl_state_e state);
            case (state)
                RUNCTL_RUN_PREP:    return CMD_RUN_PREPARE;
                RUNCTL_SYNC:        return CMD_RUN_SYNC;
                RUNCTL_RUNNING:     return CMD_START_RUN;
                RUNCTL_TERMINATING: return CMD_END_RUN;
                RUNCTL_RESET:       return CMD_RESET;
                default:            return 8'h00;
            endcase
        endfunction

        task automatic drive_synclink_beat(bit [8:0] symbol);
            @(negedge vif.clk);
            vif.data  <= symbol;
            vif.error <= 3'b000;
            vif.valid <= 1'b1;
            @(posedge vif.clk);
        endtask

        task automatic drive_synclink_idle(int unsigned cycles);
            for (int unsigned i = 0; i < cycles; i++)
                drive_synclink_beat(SYNCLINK_IDLE_COMMA);
        endtask

        task automatic drive_host_command(bit [7:0] cmd);
            drive_synclink_idle(2);
            drive_synclink_beat({1'b0, cmd});
            if (cmd == CMD_RUN_PREPARE) begin
                drive_synclink_beat({1'b0, DEFAULT_RUN_NUMBER[7:0]});
                drive_synclink_beat({1'b0, DEFAULT_RUN_NUMBER[15:8]});
                drive_synclink_beat({1'b0, DEFAULT_RUN_NUMBER[23:16]});
                drive_synclink_beat({1'b0, DEFAULT_RUN_NUMBER[31:24]});
            end
            @(negedge vif.clk);
            vif.valid <= 1'b0;
            vif.data  <= SYNCLINK_IDLE_COMMA;
            vif.error <= 3'b000;
        endtask

        virtual task drive_item(runctl_phy_item item);
            case (item.state)
                RUNCTL_IDLE: begin
                    drive_synclink_idle(item.hold_cycles);
                    @(negedge vif.clk);
                    vif.valid <= 1'b0;
                    vif.data  <= SYNCLINK_IDLE_COMMA;
                end
                RUNCTL_RUN_PREP: begin
                    tb_int_run_window_db::reset();
                    drive_host_command(state_to_cmd(item.state));
                end
                RUNCTL_RUNNING: begin
                    drive_host_command(state_to_cmd(item.state));
                    tb_int_run_window_db::note_run_start($time);
                    tb_int_run_window_db::note_stable_start($time);
                end
                RUNCTL_TERMINATING: begin
                    drive_host_command(state_to_cmd(item.state));
                    tb_int_run_window_db::note_stable_end($time);
                    tb_int_run_window_db::note_run_end($time);
                end
                default: begin
                    drive_host_command(state_to_cmd(item.state));
                end
            endcase
            if (item.state != RUNCTL_IDLE)
                repeat (item.hold_cycles) @(posedge vif.clk);
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
