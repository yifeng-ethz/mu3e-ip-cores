// opq_lane_fill_monitor.sv
// Passive OPQ lane accepted/emitted/drop observation monitor.

package tb_int_opq_lane_fill_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    import tb_int_mu3e_frame_format_pkg::*;
    `include "uvm_macros.svh"

    class opq_lane_fill_monitor extends uvm_component;
        `uvm_component_utils(opq_lane_fill_monitor)

        virtual opq_lane_if vif;
        uvm_analysis_port#(swb_stage_record) ap;
        int unsigned lane_id;
        bit ingress_in_frame;
        bit ingress_after_subheader;
        bit egress_in_frame;
        bit egress_after_subheader;

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
            ingress_in_frame = 1'b0;
            ingress_after_subheader = 1'b0;
            egress_in_frame = 1'b0;
            egress_after_subheader = 1'b0;
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                #1ps;
                if (vif.reset_n !== 1'b1)
                    continue;
                if (vif.ingress_valid === 1'b1 && vif.ingress_ready === 1'b1) begin
                    if (logical_hit_accepted(vif.ingress_data,
                                             vif.ingress_datak,
                                             ingress_in_frame,
                                             ingress_after_subheader)) begin
                        publish(SWB_STAGE_OPQ_LANE_ACCEPT, vif.ingress_data,
                                vif.ingress_sop, vif.ingress_eop);
                    end
                end
                if (vif.egress_valid === 1'b1 && vif.egress_ready === 1'b1) begin
                    if (logical_hit_accepted(vif.egress_data,
                                             vif.egress_datak,
                                             egress_in_frame,
                                             egress_after_subheader)) begin
                        publish(SWB_STAGE_OPQ_LANE_EMIT, vif.egress_data,
                                vif.egress_sop, vif.egress_eop);
                    end
                end
                if (vif.drop_pulse === 1'b1)
                    publish(SWB_STAGE_OPQ_LANE_DROP, 32'h0, 1'b0, 1'b0);
            end
        endtask

        function bit logical_hit_accepted(bit [31:0] data,
                                          bit [3:0] datak,
                                          ref bit in_frame,
                                          ref bit after_subheader);
            logical_hit_accepted = 1'b0;
            if (mu3e_word_is_idle_sop(datak, data)) begin
                in_frame = 1'b0;
                after_subheader = 1'b0;
                return 1'b0;
            end
            if (mu3e_word_is_sop(datak, data)) begin
                in_frame = 1'b1;
                after_subheader = 1'b0;
                return 1'b0;
            end
            if (!in_frame)
                return 1'b0;
            if (mu3e_word_is_subheader(datak, data)) begin
                after_subheader = 1'b1;
                return 1'b0;
            end
            if (mu3e_word_is_eop(datak, data)) begin
                in_frame = 1'b0;
                after_subheader = 1'b0;
                return 1'b0;
            end
            if (after_subheader && (datak == 4'h0))
                logical_hit_accepted = 1'b1;
        endfunction

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
