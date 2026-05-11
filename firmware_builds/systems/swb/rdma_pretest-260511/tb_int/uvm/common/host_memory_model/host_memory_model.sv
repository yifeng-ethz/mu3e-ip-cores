// host_memory_model.sv
// Behavioral RQ/CQ/data-buffer host model for SWB tb_int.

package tb_int_host_memory_model_pkg;

    import uvm_pkg::*;
    import tb_int_swb_stage_pkg::*;
    import tb_int_host_memory_pkg::*;
    import tb_int_host_axi_responder_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_host_cqe)
    `uvm_analysis_imp_decl(_host_data)

    class host_memory_model extends uvm_component;
        `uvm_component_utils(host_memory_model)

        host_memory_config_t cfg;
        host_axi_responder   axi;

        uvm_analysis_port#(host_cqe_event)       cqe_ap;
        uvm_analysis_port#(host_data_seg_event)  data_seg_ap;
        uvm_analysis_port#(swb_stage_record)     stage_ap;

        uvm_analysis_imp_host_cqe#(host_cqe_event, host_memory_model)      cqe_imp;
        uvm_analysis_imp_host_data#(host_data_seg_event, host_memory_model) data_seg_imp;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cfg = host_memory_default_config();
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            void'(uvm_config_db#(host_memory_config_t)::get(this, "", "cfg", cfg));
            cqe_ap = new("cqe_ap", this);
            data_seg_ap = new("data_seg_ap", this);
            stage_ap = new("stage_ap", this);
            cqe_imp = new("cqe_imp", this);
            data_seg_imp = new("data_seg_imp", this);
            uvm_config_db#(host_memory_config_t)::set(this, "axi", "cfg", cfg);
            axi = host_axi_responder::type_id::create("axi", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            axi.cqe_ap.connect(cqe_imp);
            axi.data_seg_ap.connect(data_seg_imp);
        endfunction

        function void write_host_cqe(host_cqe_event ev);
            swb_stage_record rec;

            if (ev == null)
                return;
            cqe_ap.write(ev);
            rec = swb_stage_record::type_id::create("host_cqe_stage");
            rec.stage = SWB_STAGE_RDMA_CQE_EGRESS;
            rec.lane = 0;
            rec.data = {128'h0, ev.cqe.status, ev.cqe.tag, ev.cqe.sidecar_id};
            rec.sidecar_id = ev.cqe.sidecar_id;
            rec.sidecar_valid = 1'b1;
            rec.sop = 1'b1;
            rec.eop = 1'b1;
            rec.sample_time = ev.sample_time;
            stage_ap.write(rec);
        endfunction

        function void write_host_data(host_data_seg_event ev);
            if (ev == null)
                return;
            data_seg_ap.write(ev);
        endfunction

        function void host_post_rqe(input int unsigned slot_idx,
                                    input rqe_t rqe);
            axi.host_post_rqe(slot_idx, rqe);
        endfunction

        function void host_write_cqe(input int unsigned slot_idx,
                                     input cqe_t cqe);
            axi.host_write_cqe(slot_idx, cqe);
        endfunction

        function bit host_segment_check(input int unsigned seg_idx,
                                        input byte unsigned expected_bytes[]);
            return axi.host_segment_check(seg_idx, expected_bytes);
        endfunction

        function int unsigned cq_head();
            return axi.cq_head();
        endfunction

        function int unsigned rq_tail();
            return axi.rq_tail();
        endfunction

        function bit host_peek_cqe(input int unsigned slot_idx,
                                   output cqe_t cqe);
            return axi.peek_cqe(slot_idx, cqe);
        endfunction

        function bit sidecar_for_rqe_slot(input int unsigned slot_idx,
                                          output bit [63:0] sidecar_id);
            sidecar_id = '0;
            if (!axi.rqe_sidecar_by_slot.exists(slot_idx))
                return 1'b0;
            sidecar_id = axi.rqe_sidecar_by_slot[slot_idx];
            return 1'b1;
        endfunction
    endclass

endpackage
