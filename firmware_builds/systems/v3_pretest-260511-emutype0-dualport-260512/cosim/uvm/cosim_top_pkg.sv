`timescale 1ns/1ps

package cosim_top_pkg;
    import uvm_pkg::*;
    import feb_cosim_env_pkg::*;
    import swb_cosim_env_pkg::*;
    import cosim_scoreboard_pkg::*;
    `include "uvm_macros.svh"

    class cosim_top_env extends uvm_env;
        `uvm_component_utils(cosim_top_env)

        feb_cosim_env   feb_env;
        swb_cosim_env   swb_env;
        cosim_scoreboard scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            feb_env = feb_cosim_env::type_id::create("feb_env", this);
            swb_env = swb_cosim_env::type_id::create("swb_env", this);
            scoreboard = cosim_scoreboard::type_id::create("scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            feb_env.egress_monitor.egress_waveform_aport.connect(scoreboard.wave_imp);
            feb_env.egress_monitor.meta_ground_truth_aport.connect(scoreboard.meta_imp);
            feb_env.egress_monitor.meta_ground_truth_aport.connect(
                swb_env.meta_consumer.meta_imp);
        endfunction
    endclass

    class cosim_top_test extends uvm_test;
        `uvm_component_utils(cosim_top_test)

        cosim_top_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = cosim_top_env::type_id::create("env", this);
        endfunction
    endclass
endpackage
