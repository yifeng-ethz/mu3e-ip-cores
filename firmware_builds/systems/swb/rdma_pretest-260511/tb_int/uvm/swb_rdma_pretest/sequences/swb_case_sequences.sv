// swb_case_sequences.sv
// Shared selected-case stimulus helper for SWB rdma_pretest-260511.

package tb_int_swb_case_sequences_pkg;

    import uvm_pkg::*;
    import tb_int_swb_case_model_pkg::*;
    `include "uvm_macros.svh"

    class swb_case_sequence extends uvm_object;
        `uvm_object_utils(swb_case_sequence)

        virtual rdma_sqe_ingress_if rdma_sqe_vif;
        virtual rdma_cqe_egress_if  rdma_cqe_vif;
        virtual opq_lane_if         opq_lane0_vif;
        virtual opq_lane_if         opq_lane1_vif;
        virtual opq_lane_if         opq_lane2_vif;
        virtual opq_lane_if         opq_lane3_vif;
        virtual pcie_dma_egress_if  pcie_dma_vif;

        function new(string name = "swb_case_sequence");
            super.new(name);
        endfunction

        function void configure(
            virtual rdma_sqe_ingress_if rdma_sqe_vif_i,
            virtual rdma_cqe_egress_if  rdma_cqe_vif_i,
            virtual opq_lane_if         opq_lane0_vif_i,
            virtual opq_lane_if         opq_lane1_vif_i,
            virtual opq_lane_if         opq_lane2_vif_i,
            virtual opq_lane_if         opq_lane3_vif_i,
            virtual pcie_dma_egress_if  pcie_dma_vif_i
        );
            rdma_sqe_vif = rdma_sqe_vif_i;
            rdma_cqe_vif = rdma_cqe_vif_i;
            opq_lane0_vif = opq_lane0_vif_i;
            opq_lane1_vif = opq_lane1_vif_i;
            opq_lane2_vif = opq_lane2_vif_i;
            opq_lane3_vif = opq_lane3_vif_i;
            pcie_dma_vif = pcie_dma_vif_i;
        endfunction

        task automatic drive_opq_lane(int unsigned lane, logic [31:0] payload);
            case (lane)
                0: opq_lane0_vif.drive_packet(payload);
                1: opq_lane1_vif.drive_packet(payload);
                2: opq_lane2_vif.drive_packet(payload);
                3: opq_lane3_vif.drive_packet(payload);
                default: opq_lane0_vif.drive_packet(payload);
            endcase
        endtask

        task automatic drive_opq_ingress_only(int unsigned lane, logic [31:0] payload);
            case (lane)
                0: opq_lane0_vif.drive_ingress_only(payload);
                1: opq_lane1_vif.drive_ingress_only(payload);
                2: opq_lane2_vif.drive_ingress_only(payload);
                3: opq_lane3_vif.drive_ingress_only(payload);
                default: opq_lane0_vif.drive_ingress_only(payload);
            endcase
        endtask

        task automatic drive_opq_drop(int unsigned lane);
            case (lane)
                0: opq_lane0_vif.drive_drop();
                1: opq_lane1_vif.drive_drop();
                2: opq_lane2_vif.drive_drop();
                3: opq_lane3_vif.drive_drop();
                default: opq_lane0_vif.drive_drop();
            endcase
        endtask

        task automatic drive_case(string case_id);
            swb_case_expectation_t exp;
            int unsigned packet_idx;
            int unsigned lane_counts[4];
            int unsigned lane;
            int unsigned emitted_packets;

            exp = swb_case_expectation(case_id);
            lane_counts[0] = exp.lane0_packets;
            lane_counts[1] = exp.lane1_packets;
            lane_counts[2] = exp.lane2_packets;
            lane_counts[3] = exp.lane3_packets;
            emitted_packets = 0;

            `uvm_info("SWB_SEQ", $sformatf("drive %s title=\"%s\"", case_id, exp.title), UVM_LOW)

            for (packet_idx = 0; packet_idx < exp.sqe_ingress; packet_idx++) begin
                rdma_sqe_vif.drive_sqe({192'h0, 32'h5351_4500, packet_idx[31:0]},
                                       {32'h5A00_0000, packet_idx[31:0]});
            end

            for (packet_idx = 0; packet_idx < exp.cqe_egress; packet_idx++) begin
                rdma_cqe_vif.drive_cqe({96'h0, 16'hC0DE, packet_idx[15:0]},
                                       packet_idx[15:0],
                                       {32'hC0E0_0000, packet_idx[31:0]});
            end

            for (lane = 0; lane < 4; lane++) begin
                for (packet_idx = 0; packet_idx < lane_counts[lane]; packet_idx++) begin
                    if (emitted_packets < exp.opq_emit) begin
                        drive_opq_lane(lane, {8'hA0 + lane[7:0], 8'(packet_idx[7:0]), 16'h600D});
                        emitted_packets++;
                    end else begin
                        drive_opq_ingress_only(lane, {8'hA0 + lane[7:0], 8'(packet_idx[7:0]), 16'h600D});
                    end
                end
            end

            for (packet_idx = 0; packet_idx < exp.opq_drop; packet_idx++) begin
                drive_opq_drop(packet_idx % 4);
            end

            for (packet_idx = 0; packet_idx < exp.dma_beats; packet_idx++) begin
                bit eoe;

                if (exp.dma_events == 0) begin
                    eoe = 1'b0;
                end else if (exp.dma_events == 1) begin
                    eoe = (packet_idx == exp.dma_beats - 1);
                end else begin
                    eoe = ((packet_idx + 1) % (exp.dma_beats / exp.dma_events)) == 0;
                end
                pcie_dma_vif.drive_dma_beat({192'h0, 32'h444D_4100, packet_idx[31:0]}, eoe);
            end
        endtask
    endclass

endpackage
