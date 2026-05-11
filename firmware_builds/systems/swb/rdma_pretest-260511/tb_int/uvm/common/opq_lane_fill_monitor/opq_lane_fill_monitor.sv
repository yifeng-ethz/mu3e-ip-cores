// opq_lane_fill_monitor.sv
// Passive OPQ lane accepted/emitted/drop observation monitor.

package tb_int_opq_lane_fill_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    `include "uvm_macros.svh"

    class opq_lane_fill_monitor extends uvm_component;
        `uvm_component_utils(opq_lane_fill_monitor)

        virtual opq_lane_if vif;
        uvm_analysis_port#(swb_stage_record) ap;
        int unsigned lane_id;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            lane_id = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
            if (!uvm_config_db#(virtual opq_lane_if)::get(this, "", "vif", vif))
                `uvm_info("OPQ_LANE_MON", "opq_lane_if not configured; monitor disabled", UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                #1ps;
                if (vif.reset_n !== 1'b1)
                    continue;
                if (vif.ingress_valid === 1'b1 && vif.ingress_ready === 1'b1)
                    publish(SWB_STAGE_OPQ_LANE_ACCEPT, vif.ingress_data, vif.ingress_sop, vif.ingress_eop);
                if (vif.egress_valid === 1'b1 && vif.egress_ready === 1'b1)
                    publish(SWB_STAGE_OPQ_LANE_EMIT, vif.egress_data, vif.egress_sop, vif.egress_eop);
                if (vif.drop_pulse === 1'b1)
                    publish(SWB_STAGE_OPQ_LANE_DROP, 32'h0, 1'b0, 1'b0);
            end
        endtask

        function void publish(swb_stage_e stage, bit [31:0] data, bit sop, bit eop);
            swb_stage_record rec;

            rec = swb_stage_record::type_id::create("opq_lane_record");
            rec.stage = stage;
            rec.lane = lane_id;
            rec.data = {224'h0, data};
            rec.sop = sop;
            rec.eop = eop;
            rec.sample_time = $time;
            ap.write(rec);
            `uvm_info("OPQ_LANE_MON", rec.describe(), UVM_HIGH)
        endfunction
    endclass

endpackage
