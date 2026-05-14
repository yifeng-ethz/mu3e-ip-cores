// opq_frame_ts_monitor.sv
// Passive SWB OPQ frame monitor with true packet timestamp reconstruction.

package tb_int_opq_frame_ts_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    `include "uvm_macros.svh"

    localparam bit [7:0] SWB_OPQ_K285 = 8'hbc;
    localparam bit [7:0] SWB_OPQ_K284 = 8'h9c;
    localparam bit [7:0] SWB_OPQ_K237 = 8'hf7;
    localparam int unsigned SWB_OPQ_EXPECTED_SUBHEADERS = 128;

    function automatic bit [47:0] swb_opq_true_packet_ts(
        input bit [31:0] header_ts_high_word,
        input bit [31:0] header_ts_low_word,
        input bit [7:0]  subheader_ts,
        input bit [31:0] hit_word
    );
        return {
            header_ts_high_word,
            header_ts_low_word[31:28],
            subheader_ts,
            hit_word[31:28]
        };
    endfunction

    class opq_frame_ts_monitor extends uvm_component;
        `uvm_component_utils(opq_frame_ts_monitor)

        virtual opq_lane_if vif;
        uvm_analysis_port#(swb_stage_record) ap;
        int unsigned lane_id;
        bit monitor_egress;

        bit        in_frame;
        int unsigned word_index;
        bit        header_ts_valid;
        bit        subheader_ts_valid;
        bit [31:0] header_ts_high_word;
        bit [31:0] header_ts_low_word;
        bit [7:0]  current_subheader_ts;
        int unsigned declared_subheaders;
        int unsigned seen_subheaders;

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
            reset_frame_state();
        endfunction

        function void reset_frame_state();
            in_frame             = 1'b0;
            word_index           = 0;
            header_ts_valid      = 1'b0;
            subheader_ts_valid   = 1'b0;
            header_ts_high_word  = '0;
            header_ts_low_word   = '0;
            current_subheader_ts = '0;
            declared_subheaders  = 0;
            seen_subheaders      = 0;
        endfunction

        function bit word_is_sop(bit [3:0] datak, bit [31:0] data);
            return datak[0] && (data[7:0] == SWB_OPQ_K285);
        endfunction

        function bit word_is_eop(bit [3:0] datak, bit [31:0] data);
            return datak[0] && (data[7:0] == SWB_OPQ_K284);
        endfunction

        function bit word_is_subheader(bit [3:0] datak, bit [31:0] data);
            return datak[0] && (data[7:0] == SWB_OPQ_K237);
        endfunction

        function void check_frame_format();
            if (declared_subheaders != SWB_OPQ_EXPECTED_SUBHEADERS) begin
                `uvm_error("OPQ_FRAME_TS",
                           $sformatf("%s lane%0d declared_subheaders=%0d expected=%0d",
                                     monitor_egress ? "egress" : "ingress",
                                     lane_id, declared_subheaders,
                                     SWB_OPQ_EXPECTED_SUBHEADERS))
            end
            if (seen_subheaders != declared_subheaders) begin
                `uvm_error("OPQ_FRAME_TS",
                           $sformatf("%s lane%0d seen_subheaders=%0d declared=%0d",
                                     monitor_egress ? "egress" : "ingress",
                                     lane_id, seen_subheaders,
                                     declared_subheaders))
            end
        endfunction

        function void publish_hit(bit [31:0] data,
                                  bit [3:0] datak,
                                  bit sop,
                                  bit eop,
                                  bit [47:0] packet_ts);
            swb_stage_record rec;

            rec = swb_stage_record::type_id::create("opq_frame_ts_record");
            rec.stage = monitor_egress
                        ? SWB_STAGE_OPQ_FRAME_EGRESS_HIT
                        : SWB_STAGE_OPQ_FRAME_INGRESS_HIT;
            rec.lane = lane_id;
            rec.data = {224'h0, data};
            rec.sop = sop;
            rec.eop = eop;
            rec.packet_ts_valid = 1'b1;
            rec.packet_ts = packet_ts;
            rec.header_ts_high_word = header_ts_high_word;
            rec.header_ts_low_word = header_ts_low_word;
            rec.subheader_ts = current_subheader_ts;
            rec.hit_ts_nibble = data[31:28];
            rec.word_index = word_index;
            rec.declared_subheaders = declared_subheaders;
            rec.seen_subheaders = seen_subheaders;
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
                    reset_frame_state();
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
            bit sample_sop;
            bit sample_eop;
            bit sample_subheader;
            bit sample_hit;
            bit [47:0] sample_packet_ts;

            valid = monitor_egress ? vif.egress_valid : vif.ingress_valid;
            ready = monitor_egress ? vif.egress_ready : vif.ingress_ready;
            sop   = monitor_egress ? vif.egress_sop   : vif.ingress_sop;
            eop   = monitor_egress ? vif.egress_eop   : vif.ingress_eop;
            data  = monitor_egress ? vif.egress_data  : vif.ingress_data;
            datak = monitor_egress ? vif.egress_datak : vif.ingress_datak;

            if (!(valid === 1'b1 && ready === 1'b1))
                return;

            sample_sop = word_is_sop(datak, data);
            sample_eop = word_is_eop(datak, data);

            if (sample_sop) begin
                reset_frame_state();
                in_frame = 1'b1;
            end else if (in_frame) begin
                word_index++;
            end

            if (in_frame && word_index == 1)
                header_ts_high_word = data;
            if (in_frame && word_index == 2) begin
                header_ts_low_word = data;
                header_ts_valid = 1'b1;
            end
            if (in_frame && word_index == 3)
                declared_subheaders = int'(data[30:16]);

            sample_subheader = in_frame && word_is_subheader(datak, data);
            if (sample_subheader) begin
                current_subheader_ts = data[31:24];
                subheader_ts_valid = 1'b1;
                seen_subheaders++;
            end

            sample_hit = in_frame &&
                         header_ts_valid &&
                         subheader_ts_valid &&
                         (datak == 4'h0) &&
                         !sample_subheader;
            if (sample_hit) begin
                sample_packet_ts = swb_opq_true_packet_ts(
                    header_ts_high_word,
                    header_ts_low_word,
                    current_subheader_ts,
                    data);
                publish_hit(data, datak, sop, eop, sample_packet_ts);
            end

            if (sample_eop) begin
                if (in_frame)
                    check_frame_format();
                reset_frame_state();
            end
        endtask
    endclass

endpackage
