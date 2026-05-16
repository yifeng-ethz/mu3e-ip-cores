// swb_stage_record.sv
// Shared SWB tb_int observation record for passive boundary monitors.

package tb_int_swb_stage_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        SWB_STAGE_COSIM_INGRESS,
        SWB_STAGE_RDMA_RQE_INGRESS,
        SWB_STAGE_RDMA_CQE_EGRESS,
        SWB_STAGE_OPQ_LANE_ACCEPT,
        SWB_STAGE_OPQ_LANE_EMIT,
        SWB_STAGE_OPQ_LANE_DROP,
        SWB_STAGE_OPQ_FRAME_INGRESS_HIT,
        SWB_STAGE_OPQ_FRAME_EGRESS_HIT,
        SWB_STAGE_PCIE_DMA_BEAT,
        SWB_STAGE_PCIE_DMA_EVENT
    } swb_stage_e;

    class swb_stage_record extends uvm_sequence_item;
        `uvm_object_utils(swb_stage_record)

        swb_stage_e  stage;
        int unsigned lane;
        bit [255:0]  data;
        bit [63:0]   sidecar_id;
        bit          sidecar_valid;
        bit          sop;
        bit          eop;
        bit          packet_ts_valid;
        bit [47:0]   packet_ts;
        bit [31:0]   header_ts_high_word;
        bit [31:0]   header_ts_low_word;
        bit [7:0]    subheader_ts;
        bit [3:0]    hit_ts_nibble;
        int unsigned word_index;
        int unsigned declared_subheaders;
        int unsigned seen_subheaders;
        int unsigned declared_hits;
        int unsigned seen_hits;
        int unsigned subheader_declared_hits;
        int unsigned subheader_seen_hits;
        int unsigned expected_subheader_ts;
        int unsigned header_page_base;
        bit          format_error;
        time         sample_time;

        function new(string name = "swb_stage_record");
            super.new(name);
            stage = SWB_STAGE_COSIM_INGRESS;
            lane = 0;
            data = '0;
            sidecar_id = '0;
            sidecar_valid = 1'b0;
            sop = 1'b0;
            eop = 1'b0;
            packet_ts_valid = 1'b0;
            packet_ts = '0;
            header_ts_high_word = '0;
            header_ts_low_word = '0;
            subheader_ts = '0;
            hit_ts_nibble = '0;
            word_index = 0;
            declared_subheaders = 0;
            seen_subheaders = 0;
            declared_hits = 0;
            seen_hits = 0;
            subheader_declared_hits = 0;
            subheader_seen_hits = 0;
            expected_subheader_ts = 0;
            header_page_base = 0;
            format_error = 1'b0;
            sample_time = 0;
        endfunction

        function string describe();
            return $sformatf(
                "{stage=%0d lane=%0d sop=%0b eop=%0b sidecar_valid=%0b sidecar=0x%016h packet_ts_valid=%0b packet_ts=0x%012h subh=0x%02h hit_ts=0x%01h word=%0d declared_subh=%0d seen_subh=%0d declared_hits=%0d seen_hits=%0d subh_hits=%0d/%0d exp_subh=0x%02h page=%0d format_error=%0b data=0x%064h t=%0t}",
                stage, lane, sop, eop, sidecar_valid, sidecar_id,
                packet_ts_valid, packet_ts, subheader_ts, hit_ts_nibble,
                word_index, declared_subheaders, seen_subheaders,
                declared_hits, seen_hits,
                subheader_seen_hits, subheader_declared_hits,
                expected_subheader_ts[7:0], header_page_base,
                format_error, data, sample_time);
        endfunction
    endclass

endpackage
