// rdma_rqe_ingress_monitor.sv
// Passive FEB-to-SWB RDMA RQE ingress monitor.

package tb_int_rdma_rqe_ingress_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    `include "uvm_macros.svh"

    class rdma_rqe_ingress_monitor extends uvm_component;
        `uvm_component_utils(rdma_rqe_ingress_monitor)

        virtual rdma_rqe_ingress_if vif;
        uvm_analysis_port#(swb_stage_record) ap;
        int unsigned total_accepted;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            total_accepted = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual rdma_rqe_ingress_if)::get(this, "", "vif", vif))
                `uvm_info("RDMA_RQE_MON", "rdma_rqe_ingress_if not configured; monitor disabled", UVM_LOW)
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

                    rec = swb_stage_record::type_id::create("rdma_rqe_record");
                    rec.stage = SWB_STAGE_RDMA_RQE_INGRESS;
                    rec.data = vif.data;
                    rec.sidecar_id = vif.sidecar_id;
                    rec.sidecar_valid = 1'b1;
                    rec.sop = vif.sop;
                    rec.eop = vif.eop;
                    rec.sample_time = $time;
                    total_accepted++;
                    ap.write(rec);
                    `uvm_info("RDMA_RQE_MON", rec.describe(), UVM_HIGH)
                end
            end
        endtask
    endclass

endpackage
