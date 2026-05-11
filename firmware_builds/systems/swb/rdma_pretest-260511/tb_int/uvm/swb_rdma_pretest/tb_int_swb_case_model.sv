// tb_int_swb_case_model.sv
// Selected SWB rdma_pretest-260511 case expectations.

package tb_int_swb_case_model_pkg;

    typedef struct {
        string       bucket;
        string       title;
        int unsigned sqe_ingress;
        int unsigned cqe_egress;
        int unsigned opq_accept;
        int unsigned opq_emit;
        int unsigned opq_drop;
        int unsigned dma_beats;
        int unsigned dma_events;
        int unsigned lane0_packets;
        int unsigned lane1_packets;
        int unsigned lane2_packets;
        int unsigned lane3_packets;
    } swb_case_expectation_t;

    function automatic swb_case_expectation_t swb_case_default(string case_id);
        swb_case_expectation_t e;

        e.bucket = case_id.substr(0, 0);
        e.title = "selected SWB structural UVM case";
        e.sqe_ingress = 0;
        e.cqe_egress = 0;
        e.opq_accept = 0;
        e.opq_emit = 0;
        e.opq_drop = 0;
        e.dma_beats = 0;
        e.dma_events = 0;
        e.lane0_packets = 0;
        e.lane1_packets = 0;
        e.lane2_packets = 0;
        e.lane3_packets = 0;
        return e;
    endfunction

    function automatic swb_case_expectation_t swb_case_expectation(string case_id);
        swb_case_expectation_t e;

        e = swb_case_default(case_id);

        if (case_id == "B001") begin
            e.title = "SWB RC firefly reset-link broadcast IDLE to RUN_PREP";
        end else if (case_id == "B006") begin
            e.title = "SWB RC full IDLE to RUNNING to IDLE walk with 1 ms gap";
        end else if (case_id == "B008") begin
            e.title = "CSR-toggle RC fallback alias B-RC-CSR-001";
        end else if (case_id == "B033") begin
            e.title = "SWB SC read OPQ CSR UID through PCIe BAR";
        end else if (case_id == "B034") begin
            e.title = "SWB SC read rdma_subsystem CSR UID";
        end else if (case_id == "B040") begin
            e.title = "SWB-local JTAG slow-control fallback alias B-SC-JTG-001";
        end else if (case_id == "B043") begin
            e.title = "SWB SC single-word scratch-pad RW round-trip";
        end else if (case_id == "B065") begin
            e.title = "one SQE ingress through OPQ to PCIe DMA egress";
            e.sqe_ingress = 1;
            e.opq_accept = 1;
            e.opq_emit = 1;
            e.dma_beats = 1;
            e.dma_events = 1;
            e.lane0_packets = 1;
        end else if (case_id == "B066") begin
            e.title = "rdma_subsystem CQE round-trip for one SQE";
            e.sqe_ingress = 1;
            e.cqe_egress = 1;
        end else if (case_id == "B067") begin
            e.title = "FEB-side RDMA SQE sidecar lineage";
            e.sqe_ingress = 1;
            e.cqe_egress = 1;
            e.opq_accept = 1;
            e.opq_emit = 1;
            e.dma_beats = 1;
            e.dma_events = 1;
            e.lane0_packets = 1;
        end else if (case_id == "B068") begin
            e.title = "OPQ 4-lane fairness, 4 sources each with 16 hits";
            e.opq_accept = 64;
            e.opq_emit = 64;
            e.dma_beats = 4;
            e.dma_events = 4;
            e.lane0_packets = 16;
            e.lane1_packets = 16;
            e.lane2_packets = 16;
            e.lane3_packets = 16;
        end else if (case_id == "B069") begin
            e.title = "PCIe x8 DMA capture matches scoreboard";
            e.dma_beats = 8;
            e.dma_events = 1;
        end else if (case_id == "E001") begin
            e.title = "back-to-back zero-gap run-control";
        end else if (case_id == "E033") begin
            e.title = "OPQ ticket FIFO full boundary";
            e.opq_accept = 32;
            e.opq_emit = 32;
            e.lane0_packets = 32;
        end else if (case_id == "E043") begin
            e.title = "concurrent PCIe sc_tool plus local JTAG arbitration alias E-SC-CONC-001";
        end else if (case_id == "E065") begin
            e.title = "PCIe DMA burst-boundary";
            e.dma_beats = 4;
            e.dma_events = 1;
        end else if (case_id == "X001") begin
            e.title = "mid-flight RESET while OPQ has SQEs in flight";
            e.sqe_ingress = 1;
            e.opq_accept = 1;
            e.opq_drop = 1;
            e.lane0_packets = 1;
        end else if (case_id == "X033") begin
            e.title = "illegal PCIe BAR write to RO field";
        end else if (case_id == "X065") begin
            e.title = "rdma CQE timeout with suppressed CQE writeback";
            e.sqe_ingress = 1;
        end else if (case_id == "X069") begin
            e.title = "RUN_PREP issued while OPQ is mid-drain";
            e.opq_accept = 2;
            e.opq_emit = 1;
            e.opq_drop = 1;
            e.dma_beats = 1;
            e.dma_events = 1;
            e.lane0_packets = 2;
        end else if (case_id == "P065") begin
            e.title = "scaled 100 kHz/channel x 4 lanes PROF smoke";
            e.sqe_ingress = 64;
            e.opq_accept = 64;
            e.opq_emit = 64;
            e.dma_beats = 16;
            e.dma_events = 4;
            e.lane0_packets = 16;
            e.lane1_packets = 16;
            e.lane2_packets = 16;
            e.lane3_packets = 16;
        end else if (case_id == "P068") begin
            e.title = "sustained SQE ingress at line-rate structural scale";
            e.sqe_ingress = 128;
            e.opq_accept = 128;
            e.opq_emit = 128;
            e.dma_beats = 128;
            e.dma_events = 8;
            e.lane0_packets = 32;
            e.lane1_packets = 32;
            e.lane2_packets = 32;
            e.lane3_packets = 32;
        end

        return e;
    endfunction

endpackage
