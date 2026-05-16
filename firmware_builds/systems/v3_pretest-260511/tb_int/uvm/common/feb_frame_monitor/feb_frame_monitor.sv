// feb_frame_monitor.sv
// Passive FEB upload-frame monitor for 36-bit Mu3e AVST streams.

package tb_int_feb_frame_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_mu3e_frame_format_pkg::*;
    `include "uvm_macros.svh"

    class feb_frame_monitor extends uvm_component;
        `uvm_component_utils(feb_frame_monitor)

        virtual mu3e_frame_if vif;
        mu3e_frame_checker frame_checker;
        int unsigned lane_id;
        string stream_name;
        int unsigned frame_hits;
        int unsigned frame_count;
        int unsigned frame_errors;
        bit require_frame_hits;
        int unsigned min_frame_hits;
        int unsigned min_frame_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            lane_id = 0;
            stream_name = name;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
            void'(uvm_config_db#(string)::get(this, "", "stream_name", stream_name));
            if (!uvm_config_db#(virtual mu3e_frame_if)::get(this, "", "vif", vif))
                `uvm_info("FEB_FRAME_MON", "mu3e_frame_if not configured; monitor disabled", UVM_LOW)
            frame_checker = mu3e_frame_checker::type_id::create("frame_checker");
            frame_checker.configure(stream_name, lane_id, MU3E_SUBHEADERS_PER_PACKET);
            frame_hits = 0;
            frame_count = 0;
            frame_errors = 0;
            require_frame_hits = $test$plusargs("TB_INT_REQUIRE_FEB_UPLOAD_FRAMES");
            min_frame_hits = 1;
            min_frame_count = 1;
            void'($value$plusargs("TB_INT_MIN_FEB_UPLOAD_HITS=%d", min_frame_hits));
            void'($value$plusargs("TB_INT_MIN_FEB_UPLOAD_FRAMES=%d", min_frame_count));
        endfunction

        virtual task run_phase(uvm_phase phase);
            mu3e_frame_sample_t sample;
            bit [31:0] data32;
            bit [3:0] datak;

            if (vif == null)
                return;

            forever begin
                @(posedge vif.clk);
                #1ps;
                if (vif.rst === 1'b1) begin
                    frame_checker.reset_all_state();
                    continue;
                end

                data32 = vif.data[31:0];
                datak = vif.data[35:32];
                frame_checker.sample_beat(vif.valid === 1'b1,
                                          vif.ready === 1'b1,
                                          vif.sop === 1'b1,
                                          vif.eop === 1'b1,
                                          data32,
                                          datak,
                                          sample);
                if (!sample.accepted || sample.idle)
                    continue;
                if (sample.format_error)
                    frame_errors++;
                if (sample.hit) begin
                    frame_hits++;
                    `uvm_info("FEB_FRAME_MON",
                              $sformatf("%s lane%0d hit%0d word=%0d packet_ts=0x%012h subh=0x%02h declared_hits=%0d seen_hits=%0d data=0x%08h datak=0x%01h",
                                        stream_name,
                                        lane_id,
                                        frame_hits,
                                        sample.word_index,
                                        sample.packet_ts,
                                        sample.subheader_ts,
                                        sample.declared_hits,
                                        sample.seen_hits,
                                        data32,
                                        datak),
                              UVM_HIGH)
                end
                if (sample.frame_done) begin
                    frame_count = sample.completed_frames;
                    `uvm_info("FEB_FRAME_MON",
                              $sformatf("%s lane%0d frame_done frame_count=%0d packet_count=0x%04h expected_packet_count=0x%04h page_base=0x%02h expected_page_base=0x%02h declared_subh=%0d seen_subh=%0d declared_hits=%0d seen_hits=%0d accepted_words=%0d expected_words=%0d frame_errors=%0d",
                                        stream_name,
                                        lane_id,
                                        frame_count,
                                        sample.packet_count,
                                        sample.expected_packet_count,
                                        sample.header_page_base,
                                        sample.expected_frame_page_base,
                                        sample.declared_subheaders,
                                        sample.seen_subheaders,
                                        sample.declared_hits,
                                        sample.seen_hits,
                                        sample.frame_accepted_words,
                                        sample.expected_frame_words,
                                        frame_errors),
                              UVM_LOW)
                end
            end
        endtask

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            if (frame_errors != 0) begin
                `uvm_error("FEB_FRAME_MON",
                           $sformatf("%s lane%0d saw %0d Mu3e frame-format errors",
                                     stream_name,
                                     lane_id,
                                     frame_errors))
            end
            if (require_frame_hits && (frame_hits < min_frame_hits)) begin
                `uvm_error("FEB_FRAME_MON",
                           $sformatf("%s lane%0d saw only %0d upload-frame hits, expected at least %0d",
                                     stream_name,
                                     lane_id,
                                     frame_hits,
                                     min_frame_hits))
            end
            if (require_frame_hits && (frame_count < min_frame_count)) begin
                `uvm_error("FEB_FRAME_MON",
                           $sformatf("%s lane%0d saw only %0d upload data frames, expected at least %0d",
                                     stream_name,
                                     lane_id,
                                     frame_count,
                                     min_frame_count))
            end
        endfunction
    endclass

endpackage
