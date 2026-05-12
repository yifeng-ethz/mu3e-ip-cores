`timescale 1ns/1ps

interface feb_egress_avst_if(input logic clk, input logic rst_n);
    logic [31:0] data;
    logic        valid;
    logic        ready;
    logic        sop;
    logic        eop;
    logic [3:0]  datak;
    logic [7:0]  channel;
    logic        error;
    logic        meta_valid;
    logic [63:0] meta_bits;
endinterface

package feb_egress_monitor_pkg;
    import uvm_pkg::*;
    import feb_egress_meta_pkg::*;
    `include "uvm_macros.svh"

    class feb_egress_waveform_cycle extends uvm_sequence_item;
        `uvm_object_utils(feb_egress_waveform_cycle)

        bit [31:0]   data;
        bit          valid;
        bit          ready;
        bit          sop;
        bit          eop;
        bit [3:0]    datak;
        int unsigned channel;
        bit          error;
        bit          meta_valid;
        bit [63:0]   meta_bits;
        time         sample_time;

        function new(string name = "feb_egress_waveform_cycle");
            super.new(name);
            data = '0;
            valid = 1'b0;
            ready = 1'b0;
            sop = 1'b0;
            eop = 1'b0;
            datak = '0;
            channel = 0;
            error = 1'b0;
            meta_valid = 1'b0;
            meta_bits = '0;
            sample_time = 0;
        endfunction

        function string convert2string();
            return $sformatf(
                "{t=%0t ch=%0d v=%0b r=%0b sop=%0b eop=%0b err=%0b datak=0x%0h data=0x%08h meta_valid=%0b meta=0x%016h}",
                sample_time, channel, valid, ready, sop, eop, error,
                datak, data, meta_valid, meta_bits);
        endfunction
    endclass

    class feb_egress_monitor extends uvm_component;
        `uvm_component_utils(feb_egress_monitor)

        virtual feb_egress_avst_if vif;
        uvm_analysis_port#(feb_egress_waveform_cycle) egress_waveform_aport;
        uvm_analysis_port#(feb_egress_meta_record)    meta_ground_truth_aport;

        longint unsigned next_hit_id;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            next_hit_id = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            egress_waveform_aport = new("egress_waveform_aport", this);
            meta_ground_truth_aport = new("meta_ground_truth_aport", this);
            if (!uvm_config_db#(virtual feb_egress_avst_if)::get(this, "", "vif", vif))
                `uvm_info("FEB_EGRESS_MON",
                          "FEB egress AVST vif not configured; monitor disabled",
                          UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                if (!vif.rst_n) begin
                    next_hit_id = 0;
                    continue;
                end
                sample_cycle();
            end
        endtask

        function void sample_cycle();
            feb_egress_waveform_cycle cyc;

            cyc = feb_egress_waveform_cycle::type_id::create("cyc");
            cyc.data = vif.data;
            cyc.valid = vif.valid;
            cyc.ready = vif.ready;
            cyc.sop = vif.sop;
            cyc.eop = vif.eop;
            cyc.datak = vif.datak;
            cyc.channel = vif.channel;
            cyc.error = vif.error;
            cyc.meta_valid = vif.meta_valid;
            cyc.meta_bits = vif.meta_bits;
            cyc.sample_time = $time;
            egress_waveform_aport.write(cyc);

            if (vif.valid && vif.ready && vif.meta_valid)
                publish_meta(cyc);
        endfunction

        function void publish_meta(feb_egress_waveform_cycle cyc);
            feb_egress_meta_record meta;

            meta = feb_egress_meta_record::type_id::create("meta");
            meta.hit_id = next_hit_id++;
            meta.ts_birth = cyc.sample_time;
            meta.channel = cyc.channel;
            meta.lane = cyc.channel;
            meta.packet_type = COSIM_PACKET_HIT;
            meta_ground_truth_aport.write(meta);
        endfunction
    endclass
endpackage
