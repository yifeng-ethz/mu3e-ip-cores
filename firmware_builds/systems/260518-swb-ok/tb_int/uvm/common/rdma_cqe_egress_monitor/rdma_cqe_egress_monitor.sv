// rdma_cqe_egress_monitor.sv
// Passive SWB-to-FEB RDMA CQE writeback monitor.

package tb_int_rdma_cqe_egress_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    `include "uvm_macros.svh"

    class rdma_cqe_egress_monitor extends uvm_component;
        `uvm_component_utils(rdma_cqe_egress_monitor)

        virtual rdma_cqe_egress_if vif;
        uvm_analysis_port#(swb_stage_record) ap;
        int unsigned total_cqe;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            total_cqe = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual rdma_cqe_egress_if)::get(this, "", "vif", vif))
                `uvm_info("RDMA_CQE_MON", "rdma_cqe_egress_if not configured; monitor disabled", UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                #1ps;
                if (vif.reset_n !== 1'b1)
                    continue;
                if (vif.valid === 1'b1 && vif.ready === 1'b1) begin
                    swb_stage_record rec;

                    rec = swb_stage_record::type_id::create("rdma_cqe_record");
                    rec.stage = SWB_STAGE_RDMA_CQE_EGRESS;
                    rec.data = {128'h0, vif.data};
                    rec.sidecar_id = vif.sidecar_id;
                    rec.sidecar_valid = vif.sidecar_valid;
                    rec.sop = 1'b1;
                    rec.eop = 1'b1;
                    rec.sample_time = $time;
                    total_cqe++;
                    ap.write(rec);
                    `uvm_info("RDMA_CQE_MON", rec.describe(), UVM_HIGH)
                end
            end
        endtask
    endclass

endpackage
