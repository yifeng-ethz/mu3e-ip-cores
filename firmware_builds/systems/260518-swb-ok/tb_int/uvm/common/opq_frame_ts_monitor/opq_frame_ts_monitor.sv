// opq_frame_ts_monitor.sv
// Passive SWB OPQ frame monitor with true packet timestamp reconstruction.

package tb_int_opq_frame_ts_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    import tb_int_mu3e_frame_format_pkg::*;
    `include "uvm_macros.svh"

    class opq_frame_ts_monitor extends uvm_component;
        `uvm_component_utils(opq_frame_ts_monitor)

        virtual opq_lane_if vif;
        uvm_analysis_port#(swb_stage_record) ap;
        int unsigned lane_id;
        bit monitor_egress;
        mu3e_frame_checker frame_checker;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            lane_id = 0;
            monitor_egress = 1'b0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
            void'(uvm_config_db#(bit)::get(this, "", "monitor_egress", monitor_egress));
            if (!uvm_config_db#(virtual opq_lane_if)::get(this, "", "vif", vif))
                `uvm_info("OPQ_FRAME_TS_MON",
                          "opq_lane_if not configured; monitor disabled",
                          UVM_LOW)
            frame_checker = mu3e_frame_checker::type_id::create("frame_checker");
            frame_checker.configure(monitor_egress ? "swb_opq_egress" : "swb_opq_ingress",
                                    lane_id,
                                    MU3E_SUBHEADERS_PER_PACKET);
        endfunction

        function void publish_hit(bit [31:0] data,
                                  bit [3:0] datak,
                                  bit sop,
                                  bit eop,
                                  mu3e_frame_sample_t sample);
            swb_stage_record rec;

            rec = swb_stage_record::type_id::create("opq_frame_ts_record");
            rec.stage = monitor_egress
                        ? SWB_STAGE_OPQ_FRAME_EGRESS_HIT
                        : SWB_STAGE_OPQ_FRAME_INGRESS_HIT;
            rec.lane = lane_id;
            rec.data = {224'h0, data};
            rec.sop = sop;
            rec.eop = eop;
            rec.packet_ts_valid = sample.packet_ts_valid;
            rec.packet_ts = sample.packet_ts;
            rec.header_ts_high_word = sample.header_ts_high_word;
            rec.header_ts_low_word = sample.header_ts_low_word;
            rec.subheader_ts = sample.subheader_ts;
            rec.hit_ts_nibble = data[31:28];
            rec.word_index = sample.word_index;
            rec.declared_subheaders = sample.declared_subheaders;
            rec.seen_subheaders = sample.seen_subheaders;
            rec.declared_hits = sample.declared_hits;
            rec.seen_hits = sample.seen_hits;
            rec.subheader_declared_hits = sample.subheader_declared_hits;
            rec.subheader_seen_hits = sample.subheader_seen_hits;
            rec.expected_subheader_ts = sample.expected_subheader_ts;
            rec.header_page_base = sample.header_page_base;
            rec.format_error = sample.format_error;
            rec.sample_time = $time;
            ap.write(rec);
            `uvm_info("OPQ_FRAME_TS_MON", rec.describe(), UVM_HIGH)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                #1ps;
                if (vif.reset_n !== 1'b1) begin
                    frame_checker.reset_frame_state();
                    continue;
                end
                sample_selected_side();
            end
        endtask

        task sample_selected_side();
            bit valid;
            bit ready;
            bit sop;
            bit eop;
            bit [31:0] data;
            bit [3:0] datak;
            mu3e_frame_sample_t sample;

            valid = monitor_egress ? vif.egress_valid : vif.ingress_valid;
            ready = monitor_egress ? vif.egress_ready : vif.ingress_ready;
            sop   = monitor_egress ? vif.egress_sop   : vif.ingress_sop;
            eop   = monitor_egress ? vif.egress_eop   : vif.ingress_eop;
            data  = monitor_egress ? vif.egress_data  : vif.ingress_data;
            datak = monitor_egress ? vif.egress_datak : vif.ingress_datak;

            if (!(valid === 1'b1 && ready === 1'b1))
                return;

            frame_checker.sample_beat(valid, ready, sop, eop, data, datak, sample);
            if (sample.hit)
                publish_hit(data, datak, sop, eop, sample);
        endtask
    endclass

endpackage
