// tb_int_swb_scoreboard.sv
// Per-stage ledger scoreboard for the SWB selected tb_int sweep.
//
// The SWB datapath splits into two parallel observability scopes:
//   - count-only stages (OPQ ingress/emit/drop + PCIe DMA beat/event):
//     the underlying AVST interfaces have no sidecar conduit, so these
//     stages cannot carry per-hit lineage. We track running counts only.
//   - lineage stages (cosim ingress + RDMA RQE ingress + RDMA CQE egress):
//     the cosim ingress sidecar is the FEB ground-truth hit id. The RDMA
//     monitors carry a 64-bit sidecar_id for WQE lineage.

package tb_int_swb_scoreboard_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    import tb_int_swb_case_model_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_swb_ledger_scoreboard extends uvm_component;
        `uvm_component_utils(tb_int_swb_ledger_scoreboard)

        uvm_analysis_imp#(swb_stage_record, tb_int_swb_ledger_scoreboard) stage_imp;
        string active_case;

        int unsigned cosim_ingress;
        int unsigned rqe_ingress;
        int unsigned cqe_egress;
        int unsigned opq_accept;
        int unsigned opq_emit;
        int unsigned opq_drop;
        int unsigned opq_frame_ingress_hits;
        int unsigned opq_frame_egress_hits;
        int unsigned opq_frame_ts_invalid;
        int unsigned dma_beats;
        int unsigned dma_events;

        time rqe_seen_ts[bit [63:0]];
        time cqe_seen_ts[bit [63:0]];
        time cosim_ingress_seen_ts[bit [63:0]];

        int unsigned cosim_missing_sidecar;
        int unsigned cosim_duplicate_sidecar;
        int unsigned rqe_missing_sidecar;
        int unsigned cqe_missing_sidecar;
        int unsigned rqe_duplicate_sidecar;
        int unsigned cqe_duplicate_sidecar;
        int unsigned sidecar_matched;
        int unsigned sidecar_missing_cqe;
        int unsigned sidecar_ghost_cqe;
        time         sidecar_latency_total;
        int unsigned sidecar_latency_samples;

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
            cosim_ingress = 0;
            rqe_ingress = 0;
            cqe_egress = 0;
            opq_accept = 0;
            opq_emit = 0;
            opq_drop = 0;
            opq_frame_ingress_hits = 0;
            opq_frame_egress_hits = 0;
            opq_frame_ts_invalid = 0;
            dma_beats = 0;
            dma_events = 0;
            rqe_seen_ts.delete();
            cqe_seen_ts.delete();
            cosim_ingress_seen_ts.delete();
            cosim_missing_sidecar = 0;
            cosim_duplicate_sidecar = 0;
            rqe_missing_sidecar = 0;
            cqe_missing_sidecar = 0;
            rqe_duplicate_sidecar = 0;
            cqe_duplicate_sidecar = 0;
            sidecar_matched = 0;
            sidecar_missing_cqe = 0;
            sidecar_ghost_cqe = 0;
            sidecar_latency_total = 0;
            sidecar_latency_samples = 0;
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
                SWB_STAGE_COSIM_INGRESS: begin
                    cosim_ingress++;
                    record_cosim_ingress_sidecar(item);
                end
                SWB_STAGE_RDMA_RQE_INGRESS: begin
                    rqe_ingress++;
                    record_rqe_sidecar(item);
                end
                SWB_STAGE_RDMA_CQE_EGRESS:  begin
                    cqe_egress++;
                    record_cqe_sidecar(item);
                end
                SWB_STAGE_OPQ_LANE_ACCEPT:  opq_accept++;
                SWB_STAGE_OPQ_LANE_EMIT:    opq_emit++;
                SWB_STAGE_OPQ_LANE_DROP:    opq_drop++;
                SWB_STAGE_OPQ_FRAME_INGRESS_HIT: begin
                    opq_frame_ingress_hits++;
                    if (!item.packet_ts_valid)
                        opq_frame_ts_invalid++;
                end
                SWB_STAGE_OPQ_FRAME_EGRESS_HIT: begin
                    opq_frame_egress_hits++;
                    if (!item.packet_ts_valid)
                        opq_frame_ts_invalid++;
                end
                SWB_STAGE_PCIE_DMA_BEAT:    dma_beats++;
                SWB_STAGE_PCIE_DMA_EVENT:   dma_events++;
                default: begin
                end
            endcase
        endfunction

        function void record_cosim_ingress_sidecar(swb_stage_record item);
            if (!item.sidecar_valid) begin
                cosim_missing_sidecar++;
                `uvm_warning("SWB_SB_COSIM",
                             $sformatf("%s cosim ingress without sidecar_valid; %s",
                                       active_case, item.describe()))
                return;
            end
            if (cosim_ingress_seen_ts.exists(item.sidecar_id)) begin
                cosim_duplicate_sidecar++;
                `uvm_error("SWB_SB_COSIM",
                           $sformatf("%s duplicate cosim ingress sidecar_id=0x%016h first_ts=%0t now=%s",
                                     active_case, item.sidecar_id,
                                     cosim_ingress_seen_ts[item.sidecar_id],
                                     item.describe()))
                return;
            end
            cosim_ingress_seen_ts[item.sidecar_id] = item.sample_time;
        endfunction

        function void record_rqe_sidecar(swb_stage_record item);
            if (!item.sidecar_valid) begin
                rqe_missing_sidecar++;
                `uvm_warning("SWB_SB_LIN",
                             $sformatf("%s RQE ingress without sidecar_valid; %s",
                                       active_case, item.describe()))
                return;
            end
            if (rqe_seen_ts.exists(item.sidecar_id)) begin
                rqe_duplicate_sidecar++;
                `uvm_error("SWB_SB_LIN",
                           $sformatf("%s duplicate RQE sidecar_id=0x%016h first_ts=%0t now=%s",
                                     active_case, item.sidecar_id,
                                     rqe_seen_ts[item.sidecar_id],
                                     item.describe()))
                return;
            end
            rqe_seen_ts[item.sidecar_id] = item.sample_time;
        endfunction

        function void record_cqe_sidecar(swb_stage_record item);
            if (!item.sidecar_valid) begin
                cqe_missing_sidecar++;
                `uvm_warning("SWB_SB_LIN",
                             $sformatf("%s CQE egress without sidecar_valid; %s",
                                       active_case, item.describe()))
                return;
            end
            if (cqe_seen_ts.exists(item.sidecar_id)) begin
                cqe_duplicate_sidecar++;
                `uvm_error("SWB_SB_LIN",
                           $sformatf("%s duplicate CQE sidecar_id=0x%016h first_ts=%0t now=%s",
                                     active_case, item.sidecar_id,
                                     cqe_seen_ts[item.sidecar_id],
                                     item.describe()))
                return;
            end
            cqe_seen_ts[item.sidecar_id] = item.sample_time;
        endfunction

        function void reconcile_sidecars();
            bit [63:0] sid;
            bit        ok;

            sidecar_matched = 0;
            sidecar_missing_cqe = 0;
            sidecar_ghost_cqe = 0;
            sidecar_latency_total = 0;
            sidecar_latency_samples = 0;

            if (rqe_seen_ts.first(sid)) begin
                ok = 1'b1;
                while (ok) begin
                    if (cqe_seen_ts.exists(sid)) begin
                        sidecar_matched++;
                        if (cqe_seen_ts[sid] >= rqe_seen_ts[sid]) begin
                            sidecar_latency_total += (cqe_seen_ts[sid] - rqe_seen_ts[sid]);
                            sidecar_latency_samples++;
                        end
                    end else begin
                        sidecar_missing_cqe++;
                    end
                    ok = rqe_seen_ts.next(sid);
                end
            end
            if (cqe_seen_ts.first(sid)) begin
                ok = 1'b1;
                while (ok) begin
                    if (!rqe_seen_ts.exists(sid))
                        sidecar_ghost_cqe++;
                    ok = cqe_seen_ts.next(sid);
                end
            end
        endfunction

        function void check_count(string name, int unsigned actual, int unsigned expected);
            if (actual != expected) begin
                `uvm_error("SWB_SB",
                           $sformatf("%s %s actual=%0d expected=%0d",
                                     active_case, name, actual, expected))
            end
        endfunction

        function void check_sidecar_expectation(int unsigned expected_rqe,
                                                 int unsigned expected_cqe);
            time         avg_latency;
            int unsigned expected_matched;
            int unsigned expected_missing_cqe;
            int unsigned expected_ghost_cqe;

            reconcile_sidecars();
            avg_latency = (sidecar_latency_samples != 0)
                          ? (sidecar_latency_total / sidecar_latency_samples)
                          : 0;
            expected_matched = (expected_rqe < expected_cqe)
                               ? expected_rqe : expected_cqe;
            expected_missing_cqe = expected_rqe - expected_matched;
            expected_ghost_cqe   = expected_cqe - expected_matched;
            `uvm_info("SWB_SB_LIN",
                      $sformatf("%s sidecar matched=%0d/%0d missing_cqe=%0d/%0d ghost_cqe=%0d/%0d dup_rqe=%0d dup_cqe=%0d no_sidecar_rqe=%0d no_sidecar_cqe=%0d avg_lat=%0t",
                                active_case,
                                sidecar_matched, expected_matched,
                                sidecar_missing_cqe, expected_missing_cqe,
                                sidecar_ghost_cqe, expected_ghost_cqe,
                                rqe_duplicate_sidecar, cqe_duplicate_sidecar,
                                rqe_missing_sidecar, cqe_missing_sidecar,
                                avg_latency),
                      UVM_LOW)
            if (sidecar_matched != expected_matched) begin
                `uvm_error("SWB_SB_LIN",
                           $sformatf("%s sidecar_matched=%0d expected=%0d",
                                     active_case, sidecar_matched, expected_matched))
            end
            if (sidecar_missing_cqe != expected_missing_cqe) begin
                `uvm_error("SWB_SB_LIN",
                           $sformatf("%s sidecar_missing_cqe=%0d expected=%0d",
                                     active_case, sidecar_missing_cqe, expected_missing_cqe))
            end
            if (sidecar_ghost_cqe != expected_ghost_cqe) begin
                `uvm_error("SWB_SB_LIN",
                           $sformatf("%s sidecar_ghost_cqe=%0d expected=%0d",
                                     active_case, sidecar_ghost_cqe, expected_ghost_cqe))
            end
            if (rqe_duplicate_sidecar != 0 || cqe_duplicate_sidecar != 0) begin
                `uvm_error("SWB_SB_LIN",
                           $sformatf("%s duplicate sidecar_id: dup_rqe=%0d dup_cqe=%0d",
                                     active_case,
                                     rqe_duplicate_sidecar, cqe_duplicate_sidecar))
            end
            if (opq_frame_ts_invalid != 0) begin
                `uvm_error("SWB_SB_OPQ_TS",
                           $sformatf("%s OPQ frame monitor saw %0d hits without reconstructed packet timestamp",
                                     active_case, opq_frame_ts_invalid))
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

            check_sidecar_expectation(exp.rqe_ingress, exp.cqe_egress);

            `uvm_info("SWB_SB",
                      $sformatf("%s PASS title=\"%s\" cosim_ingress=%0d rqe=%0d cqe=%0d opq=%0d/%0d frame_hits=%0d/%0d drop=%0d dma=%0d/%0d sidecar_matched=%0d",
                                case_id, exp.title, cosim_ingress, rqe_ingress, cqe_egress,
                                opq_accept, opq_emit,
                                opq_frame_ingress_hits, opq_frame_egress_hits,
                                opq_drop, dma_beats, dma_events,
                                sidecar_matched),
                      UVM_LOW)
        endfunction
    endclass

endpackage
