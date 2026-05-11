// swb_stage_record.sv
// Shared SWB tb_int observation record for passive boundary monitors.

package tb_int_swb_stage_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        SWB_STAGE_RDMA_SQE_INGRESS,
        SWB_STAGE_RDMA_CQE_EGRESS,
        SWB_STAGE_OPQ_LANE_ACCEPT,
        SWB_STAGE_OPQ_LANE_EMIT,
        SWB_STAGE_OPQ_LANE_DROP,
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
        time         sample_time;

        function new(string name = "swb_stage_record");
            super.new(name);
            stage = SWB_STAGE_RDMA_SQE_INGRESS;
            lane = 0;
            data = '0;
            sidecar_id = '0;
            sidecar_valid = 1'b0;
            sop = 1'b0;
            eop = 1'b0;
            sample_time = 0;
        endfunction

        function string describe();
            return $sformatf(
                "{stage=%0d lane=%0d sop=%0b eop=%0b sidecar_valid=%0b sidecar=0x%016h data=0x%064h t=%0t}",
                stage, lane, sop, eop, sidecar_valid, sidecar_id, data, sample_time);
        endfunction
    endclass

endpackage
