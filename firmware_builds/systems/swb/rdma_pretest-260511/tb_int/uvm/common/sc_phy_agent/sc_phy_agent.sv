// sc_phy_agent.sv
// Active slow-control Avalon-MM master scaffold.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable SC AVMM master agent for integration UVM.

package tb_int_sc_phy_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        SC_READ,
        SC_WRITE
    } sc_op_e;

    class sc_phy_item extends uvm_sequence_item;
        `uvm_object_utils(sc_phy_item)

        rand sc_op_e      op;
        rand bit [31:0]   address;
        rand bit [31:0]   writedata;
        rand bit [3:0]    byteenable;
        rand int unsigned idle_cycles;
        bit [31:0]        readdata;

        constraint sane_c {
            idle_cycles inside {[0:1024]};
            byteenable != 4'h0;
        }

        function new(string name = "sc_phy_item");
            super.new(name);
            byteenable = 4'hf;
        endfunction
    endclass

    class sc_phy_sequencer extends uvm_sequencer#(sc_phy_item);
        `uvm_component_utils(sc_phy_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class sc_phy_driver extends uvm_driver#(sc_phy_item);
        `uvm_component_utils(sc_phy_driver)

        virtual sc_avmm_if vif;
        int unsigned timeout_cycles;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            timeout_cycles = 10000;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual sc_avmm_if)::get(this, "", "vif", vif))
                `uvm_fatal("SC_PHY", "sc_avmm_if not found")
        endfunction

        virtual task drive_item(sc_phy_item item);
            int unsigned waited;

            repeat (item.idle_cycles) @(posedge vif.clk);
            @(negedge vif.clk);
            vif.address    <= item.address;
            vif.writedata  <= item.writedata;
            vif.byteenable <= item.byteenable;
            vif.burstcount <= 8'd1;
            vif.write      <= (item.op == SC_WRITE);
            vif.read       <= (item.op == SC_READ);
            waited = 0;
            do begin
                @(posedge vif.clk);
                waited++;
                if (waited >= timeout_cycles)
                    `uvm_fatal("SC_PHY", "AVMM waitrequest timeout")
            end while (vif.waitrequest === 1'b1);
            @(negedge vif.clk);
            vif.write <= 1'b0;
            vif.read  <= 1'b0;
            if (item.op == SC_READ) begin
                waited = 0;
                do begin
                    @(posedge vif.clk);
                    waited++;
                    if (waited >= timeout_cycles)
                        `uvm_fatal("SC_PHY", "AVMM readdatavalid timeout")
                end while (vif.readdatavalid !== 1'b1);
                item.readdata = vif.readdata;
            end
        endtask

        virtual task run_phase(uvm_phase phase);
            sc_phy_item item;

            vif.clear_master();
            forever begin
                seq_item_port.get_next_item(item);
                drive_item(item);
                seq_item_port.item_done();
            end
        endtask
    endclass

    class sc_phy_agent extends uvm_agent;
        `uvm_component_utils(sc_phy_agent)

        sc_phy_sequencer sqr;
        sc_phy_driver    drv;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = sc_phy_sequencer::type_id::create("sqr", this);
            drv = sc_phy_driver::type_id::create("drv", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

endpackage
