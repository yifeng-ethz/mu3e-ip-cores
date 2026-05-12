`timescale 1ns/1ps

package swb_ingress_meta_consumer_pkg;
    import uvm_pkg::*;
    import feb_egress_meta_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_cosim_meta)

    class swb_ingress_meta_consumer extends uvm_component;
        `uvm_component_utils(swb_ingress_meta_consumer)

        uvm_analysis_imp_cosim_meta#(feb_egress_meta_record,
                                     swb_ingress_meta_consumer) meta_imp;
        uvm_analysis_port#(feb_egress_meta_record) swb_scoreboard_meta_aport;
        longint unsigned meta_count;
        feb_egress_meta_record meta_by_hit[longint unsigned];

        function new(string name, uvm_component parent);
            super.new(name, parent);
            meta_count = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            meta_imp = new("meta_imp", this);
            swb_scoreboard_meta_aport = new("swb_scoreboard_meta_aport", this);
        endfunction

        function void write_cosim_meta(feb_egress_meta_record item);
            if (item == null)
                return;
            meta_by_hit[item.hit_id] = item;
            meta_count++;
            swb_scoreboard_meta_aport.write(item);
        endfunction
    endclass
endpackage
