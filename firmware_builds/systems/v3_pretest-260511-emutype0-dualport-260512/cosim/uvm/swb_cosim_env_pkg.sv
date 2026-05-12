`timescale 1ns/1ps

package swb_cosim_env_pkg;
    import uvm_pkg::*;
    import swb_ingress_driver_pkg::*;
    import swb_ingress_meta_consumer_pkg::*;
    `include "uvm_macros.svh"

    class swb_cosim_env extends uvm_env;
        `uvm_component_utils(swb_cosim_env)

        swb_ingress_waveform_driver ingress_driver;
        swb_ingress_meta_consumer   meta_consumer;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ingress_driver = swb_ingress_waveform_driver::type_id::create(
                "ingress_driver", this);
            meta_consumer = swb_ingress_meta_consumer::type_id::create(
                "meta_consumer", this);
        endfunction
    endclass
endpackage
