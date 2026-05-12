`timescale 1ns/1ps

package feb_cosim_env_pkg;
    import uvm_pkg::*;
    import feb_egress_monitor_pkg::*;
    `include "uvm_macros.svh"

    class feb_cosim_env extends uvm_env;
        `uvm_component_utils(feb_cosim_env)

        feb_egress_monitor egress_monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            egress_monitor = feb_egress_monitor::type_id::create(
                "egress_monitor", this);
        endfunction
    endclass
endpackage
