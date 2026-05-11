// host_polling_core.sv
// NUMA-pinned single-core polling model for SWB tb_int host memory.

package tb_int_host_polling_core_pkg;

    import uvm_pkg::*;
    import tb_int_host_memory_pkg::*;
    import tb_int_host_memory_model_pkg::*;
    `include "uvm_macros.svh"

    class host_polling_core extends uvm_component;
        `uvm_component_utils(host_polling_core)

        host_memory_config_t cfg;
        host_memory_model    host_mem;
        rqe_t                pending_wqe[$];
        int unsigned         prev_cq_head;
        int unsigned         next_rq_slot;
        int unsigned         record_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cfg = host_memory_default_config();
            prev_cq_head = 0;
            next_rq_slot = 0;
            record_count = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            void'(uvm_config_db#(host_memory_config_t)::get(this, "", "cfg", cfg));
        endfunction

        function void set_host_model(host_memory_model host_mem_i);
            host_mem = host_mem_i;
        endfunction

        function void queue_rqe(input rqe_t rqe);
            pending_wqe.push_back(rqe);
        endfunction

        task automatic consume_cqes();
            cqe_t cqe;
            int unsigned head;

            head = host_mem.cq_head();
            while (prev_cq_head != head) begin
                if (host_mem.host_peek_cqe(prev_cq_head, cqe)) begin
                    if (cfg.record_write_latency != 0ns)
                        #(cfg.record_write_latency);
                    record_count++;
                    `uvm_info("HOST_POLL",
                              $sformatf("record CQE slot=%0d status=0x%08h tag=0x%08h sidecar=0x%016h records=%0d",
                                        prev_cq_head, cqe.status, cqe.tag,
                                        cqe.sidecar_id, record_count),
                              UVM_HIGH)
                end
                prev_cq_head = (prev_cq_head + 1) % cfg.CQ_DEPTH;
                head = host_mem.cq_head();
            end
        endtask

        task automatic post_next_rqe();
            rqe_t rqe;

            if (pending_wqe.size() == 0)
                return;
            rqe = pending_wqe.pop_front();
            host_mem.host_post_rqe(next_rq_slot, rqe);
            next_rq_slot = (next_rq_slot + 1) % cfg.RQ_DEPTH;
        endtask

        virtual task run_phase(uvm_phase phase);
            if (host_mem == null) begin
                `uvm_warning("HOST_POLL",
                             "host_memory_model handle not set; polling core is idle")
                return;
            end
            forever begin
                consume_cqes();
                post_next_rqe();
                if (cfg.poll_cadence == 0ns)
                    #100ns;
                else
                    #(cfg.poll_cadence);
            end
        endtask
    endclass

endpackage
