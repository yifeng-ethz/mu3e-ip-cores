// pcie_dma_egress_monitor.sv
// Passive host-side PCIe DMA egress observation monitor.

package tb_int_pcie_dma_egress_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    `include "uvm_macros.svh"

    class pcie_dma_egress_monitor extends uvm_component;
        `uvm_component_utils(pcie_dma_egress_monitor)

        virtual pcie_dma_egress_if vif;
        uvm_analysis_port#(swb_stage_record) ap;
        int unsigned total_beats;
        int unsigned total_events;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            total_beats = 0;
            total_events = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual pcie_dma_egress_if)::get(this, "", "vif", vif))
                `uvm_info("PCIE_DMA_MON", "pcie_dma_egress_if not configured; monitor disabled", UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                #1ps;
                if (vif.reset_n !== 1'b1)
                    continue;
                if (vif.dma_wren === 1'b1) begin
                    publish(SWB_STAGE_PCIE_DMA_BEAT, vif.dma_data, vif.endofevent);
                    total_beats++;
                    if (vif.endofevent === 1'b1) begin
                        publish(SWB_STAGE_PCIE_DMA_EVENT, vif.dma_data, 1'b1);
                        total_events++;
                    end
                end
            end
        endtask

        function void publish(swb_stage_e stage, bit [255:0] data, bit eop);
            swb_stage_record rec;

            rec = swb_stage_record::type_id::create("pcie_dma_record");
            rec.stage = stage;
            rec.data = data;
            rec.sop = 1'b1;
            rec.eop = eop;
            rec.sample_time = $time;
            ap.write(rec);
            `uvm_info("PCIE_DMA_MON", rec.describe(), UVM_HIGH)
        endfunction
    endclass

endpackage
