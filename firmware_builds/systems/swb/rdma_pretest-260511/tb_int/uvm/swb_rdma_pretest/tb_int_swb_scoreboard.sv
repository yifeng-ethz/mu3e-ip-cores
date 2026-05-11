// tb_int_swb_scoreboard.sv
// Per-stage ledger scoreboard for the SWB selected tb_int sweep.

package tb_int_swb_scoreboard_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    import tb_int_swb_case_model_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_swb_ledger_scoreboard extends uvm_component;
        `uvm_component_utils(tb_int_swb_ledger_scoreboard)

        uvm_analysis_imp#(swb_stage_record, tb_int_swb_ledger_scoreboard) stage_imp;
        string active_case;

        int unsigned rqe_ingress;
        int unsigned cqe_egress;
        int unsigned opq_accept;
        int unsigned opq_emit;
        int unsigned opq_drop;
        int unsigned dma_beats;
        int unsigned dma_events;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            active_case = "";
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            stage_imp = new("stage_imp", this);
            reset_counts();
        endfunction

        function void reset_counts();
            rqe_ingress = 0;
            cqe_egress = 0;
            opq_accept = 0;
            opq_emit = 0;
            opq_drop = 0;
            dma_beats = 0;
            dma_events = 0;
        endfunction

        function void start_case(string case_id);
            active_case = case_id;
            reset_counts();
            `uvm_info("SWB_SB", $sformatf("start case %s", case_id), UVM_LOW)
        endfunction

        virtual function void write(swb_stage_record item);
            if (item == null)
                return;
            case (item.stage)
                SWB_STAGE_RDMA_RQE_INGRESS: rqe_ingress++;
                SWB_STAGE_RDMA_CQE_EGRESS:  cqe_egress++;
                SWB_STAGE_OPQ_LANE_ACCEPT:  opq_accept++;
                SWB_STAGE_OPQ_LANE_EMIT:    opq_emit++;
                SWB_STAGE_OPQ_LANE_DROP:    opq_drop++;
                SWB_STAGE_PCIE_DMA_BEAT:    dma_beats++;
                SWB_STAGE_PCIE_DMA_EVENT:   dma_events++;
                default: begin
                end
            endcase
        endfunction

        function void check_count(string name, int unsigned actual, int unsigned expected);
            if (actual != expected) begin
                `uvm_error("SWB_SB",
                           $sformatf("%s %s actual=%0d expected=%0d",
                                     active_case, name, actual, expected))
            end
        endfunction

        function void check_case(string case_id);
            swb_case_expectation_t exp;

            exp = swb_case_expectation(case_id);
            check_count("rqe_ingress", rqe_ingress, exp.rqe_ingress);
            check_count("cqe_egress", cqe_egress, exp.cqe_egress);
            check_count("opq_accept", opq_accept, exp.opq_accept);
            check_count("opq_emit", opq_emit, exp.opq_emit);
            check_count("opq_drop", opq_drop, exp.opq_drop);
            check_count("dma_beats", dma_beats, exp.dma_beats);
            check_count("dma_events", dma_events, exp.dma_events);
            `uvm_info("SWB_SB",
                      $sformatf("%s PASS title=\"%s\" rqe=%0d cqe=%0d opq=%0d/%0d drop=%0d dma=%0d/%0d",
                                case_id, exp.title, rqe_ingress, cqe_egress,
                                opq_accept, opq_emit, opq_drop, dma_beats, dma_events),
                      UVM_LOW)
        endfunction
    endclass

endpackage
