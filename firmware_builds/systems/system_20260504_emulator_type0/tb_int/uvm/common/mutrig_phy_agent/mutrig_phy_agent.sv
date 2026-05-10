// mutrig_phy_agent.sv
// Active virtual MuTRiG source shell with LCG-reproducible profiles.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable virtual-MuTRiG agent scaffold for integration UVM.

package tb_int_mutrig_phy_agent_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        MUTRIG_SPATIAL_FIXED,
        MUTRIG_SPATIAL_RANDOM,
        MUTRIG_SPATIAL_CLUSTERED
    } mutrig_spatial_mode_e;

    typedef enum int unsigned {
        MUTRIG_TEMPORAL_DETERMINISTIC,
        MUTRIG_TEMPORAL_POISSON,
        MUTRIG_TEMPORAL_BURST
    } mutrig_temporal_mode_e;

    class mutrig_phy_cfg extends uvm_object;
        `uvm_object_utils(mutrig_phy_cfg)

        int unsigned          lane_count;
        int unsigned          rate_hz_per_channel;
        int unsigned          multiplicity;
        mutrig_spatial_mode_e spatial_mode;
        mutrig_temporal_mode_e temporal_mode;
        bit [31:0]            seed;

        function new(string name = "mutrig_phy_cfg");
            super.new(name);
            lane_count          = 1;
            rate_hz_per_channel = 0;
            multiplicity        = 1;
            spatial_mode        = MUTRIG_SPATIAL_FIXED;
            temporal_mode       = MUTRIG_TEMPORAL_DETERMINISTIC;
            seed                = 32'h1;
        endfunction
    endclass

    class mutrig_phy_item extends uvm_sequence_item;
        `uvm_object_utils(mutrig_phy_item)

        rand bit [3:0]  lane_id;
        rand bit [4:0]  channel;
        rand bit [14:0] t_coarse;
        rand bit [4:0]  t_fine;
        rand int unsigned idle_cycles;

        constraint sane_c {
            lane_id < 8;
            idle_cycles inside {[0:4096]};
        }

        function new(string name = "mutrig_phy_item");
            super.new(name);
        endfunction
    endclass

    class mutrig_phy_sequencer extends uvm_sequencer#(mutrig_phy_item);
        `uvm_component_utils(mutrig_phy_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class mutrig_phy_driver extends uvm_driver#(mutrig_phy_item);
        `uvm_component_utils(mutrig_phy_driver)

        virtual lvds_phy_if vif;
        mutrig_phy_cfg cfg;
        bit [31:0] lcg_state;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            int plusarg_seed;

            super.build_phase(phase);
            if (!uvm_config_db#(virtual lvds_phy_if)::get(this, "", "vif", vif))
                `uvm_fatal("MUTRIG_PHY", "lvds_phy_if not found")
            if (!uvm_config_db#(mutrig_phy_cfg)::get(this, "", "cfg", cfg))
                cfg = mutrig_phy_cfg::type_id::create("cfg");
            if ($value$plusargs("ARB_SEED=%d", plusarg_seed))
                cfg.seed = plusarg_seed;
            lcg_state = (cfg.seed == 32'h0) ? 32'h1 : cfg.seed;
        endfunction

        function automatic bit [31:0] lcg_next();
            lcg_state = (32'd1664525 * lcg_state) + 32'd1013904223;
            return lcg_state;
        endfunction

        virtual task run_phase(uvm_phase phase);
            mutrig_phy_item item;

            vif.clear();
            forever begin
                seq_item_port.get_next_item(item);
                repeat (item.idle_cycles) @(posedge vif.clk);
                @(negedge vif.clk);
                vif.channel <= item.lane_id;
                vif.data    <= {1'b0, item.channel[4:0], item.t_fine[2:0]};
                vif.valid   <= 1'b1;
                @(negedge vif.clk);
                vif.valid   <= 1'b0;
                void'(lcg_next());
                seq_item_port.item_done();
            end
        endtask
    endclass

    class mutrig_phy_agent extends uvm_agent;
        `uvm_component_utils(mutrig_phy_agent)

        mutrig_phy_cfg       cfg;
        mutrig_phy_sequencer sqr;
        mutrig_phy_driver    drv;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(mutrig_phy_cfg)::get(this, "", "cfg", cfg))
                cfg = mutrig_phy_cfg::type_id::create("cfg");
            sqr = mutrig_phy_sequencer::type_id::create("sqr", this);
            drv = mutrig_phy_driver::type_id::create("drv", this);
            uvm_config_db#(mutrig_phy_cfg)::set(this, "drv", "cfg", cfg);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

endpackage
