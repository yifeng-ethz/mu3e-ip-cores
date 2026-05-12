`timescale 1ns/1ps

interface swb_ingress_avst_if(input logic clk, input logic rst_n);
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

package swb_ingress_driver_pkg;
    import uvm_pkg::*;
    import feb_egress_monitor_pkg::*;
    `include "uvm_macros.svh"

    class swb_ingress_waveform_driver extends uvm_component;
        `uvm_component_utils(swb_ingress_waveform_driver)

        virtual swb_ingress_avst_if vif;
        mailbox#(feb_egress_waveform_cycle) replay_mb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            replay_mb = new();
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual swb_ingress_avst_if)::get(this, "", "vif", vif))
                `uvm_info("SWB_ING_DRV",
                          "SWB ingress vif not configured; driver disabled",
                          UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            feb_egress_waveform_cycle cyc;

            if (vif == null)
                return;
            drive_idle();
            forever begin
                replay_mb.get(cyc);
                @(posedge vif.clk);
                if (!vif.rst_n) begin
                    drive_idle();
                    continue;
                end
                drive_cycle(cyc);
            end
        endtask

        task enqueue(feb_egress_waveform_cycle cyc);
            replay_mb.put(cyc);
        endtask

        task drive_idle();
            vif.valid <= 1'b0;
            vif.data <= 32'h000000bc;
            vif.datak <= 4'b0001;
            vif.sop <= 1'b0;
            vif.eop <= 1'b0;
            vif.channel <= '0;
            vif.error <= 1'b0;
            vif.meta_valid <= 1'b0;
            vif.meta_bits <= '0;
        endtask

        task drive_cycle(feb_egress_waveform_cycle cyc);
            vif.valid <= cyc.valid;
            vif.data <= cyc.data;
            vif.datak <= cyc.datak;
            vif.sop <= cyc.sop;
            vif.eop <= cyc.eop;
            vif.channel <= cyc.channel[7:0];
            vif.error <= cyc.error;
            vif.meta_valid <= cyc.meta_valid;
            vif.meta_bits <= cyc.meta_bits;
        endtask
    endclass
endpackage
