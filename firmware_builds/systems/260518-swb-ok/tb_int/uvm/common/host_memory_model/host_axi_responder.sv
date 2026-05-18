// host_axi_responder.sv
// AXI4 host-memory responder for SWB tb_int.

interface host_axi_if #(
    parameter int ADDR_WIDTH = 64,
    parameter int DATA_WIDTH = 256,
    parameter int ID_WIDTH = 4
) (
    input logic ACLK,
    input logic ARESETn
);
    localparam int STRB_WIDTH = DATA_WIDTH / 8;

    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic                  awvalid;
    logic                  awready;

    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] wstrb;
    logic                  wlast;
    logic                  wvalid;
    logic                  wready;

    logic [ID_WIDTH-1:0]   bid;
    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    logic [ID_WIDTH-1:0]   arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arvalid;
    logic                  arready;

    logic [ID_WIDTH-1:0]   rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic                  rvalid;
    logic                  rready;

    task automatic clear_responder();
        awready = 1'b0;
        wready = 1'b0;
        bid = '0;
        bresp = 2'b00;
        bvalid = 1'b0;
        arready = 1'b0;
        rid = '0;
        rdata = '0;
        rresp = 2'b00;
        rlast = 1'b0;
        rvalid = 1'b0;
    endtask
endinterface

package tb_int_host_axi_responder_pkg;

    import uvm_pkg::*;
    import tb_int_host_memory_pkg::*;
    `include "uvm_macros.svh"

    class host_axi_responder extends uvm_component;
        `uvm_component_utils(host_axi_responder)

        localparam int DATA_BYTES = 32;

        virtual host_axi_if vif;
        host_memory_config_t cfg;

        byte unsigned rq_region[];
        byte unsigned cq_region[];
        byte unsigned data_region[];

        bit [63:0] rqe_sidecar_by_slot[int unsigned];
        int unsigned rq_tail_shadow;
        int unsigned cq_head_shadow;

        uvm_analysis_port#(host_cqe_event)      cqe_ap;
        uvm_analysis_port#(host_data_seg_event) data_seg_ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cfg = host_memory_default_config();
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            cqe_ap = new("cqe_ap", this);
            data_seg_ap = new("data_seg_ap", this);
            void'(uvm_config_db#(virtual host_axi_if)::get(this, "", "vif", vif));
            void'(uvm_config_db#(host_memory_config_t)::get(this, "", "cfg", cfg));
            reset_regions();
        endfunction

        function void reset_regions();
            int unsigned rq_bytes;
            int unsigned cq_bytes;
            int unsigned data_bytes;

            rq_bytes = cfg.RQ_DEPTH * 64;
            cq_bytes = cfg.CQ_DEPTH * 16;
            data_bytes = cfg.N_SEGMENTS * cfg.SEG_BYTES;
            rq_region = new[rq_bytes];
            cq_region = new[cq_bytes];
            data_region = new[data_bytes];
            foreach (rq_region[i])
                rq_region[i] = 8'h00;
            foreach (cq_region[i])
                cq_region[i] = 8'h00;
            foreach (data_region[i])
                data_region[i] = 8'h00;
            rqe_sidecar_by_slot.delete();
            rq_tail_shadow = 0;
            cq_head_shadow = 0;
        endfunction

        function bit random_ready();
            return ($urandom_range(0, 99) >= 15);
        endfunction

        function bit burst_4kb_ok(longint unsigned addr, int unsigned bytes);
            return ((addr % 4096) + bytes) <= 4096;
        endfunction

        function int unsigned burst_bytes(input logic [7:0] len,
                                          input logic [2:0] size);
            return (int'(len) + 1) * (1 << int'(size));
        endfunction

        function bit decode_region(longint unsigned addr,
                                   output string region,
                                   output int unsigned offset);
            if ((addr >= cfg.HOST_RQ_BASE_ADDR) &&
                (addr < (cfg.HOST_RQ_BASE_ADDR + rq_region.size()))) begin
                region = "RQ";
                offset = int'(addr - cfg.HOST_RQ_BASE_ADDR);
                return 1'b1;
            end
            if ((addr >= cfg.HOST_CQ_BASE_ADDR) &&
                (addr < (cfg.HOST_CQ_BASE_ADDR + cq_region.size()))) begin
                region = "CQ";
                offset = int'(addr - cfg.HOST_CQ_BASE_ADDR);
                return 1'b1;
            end
            if ((addr >= cfg.HOST_DATA_BASE_ADDR) &&
                (addr < (cfg.HOST_DATA_BASE_ADDR + data_region.size()))) begin
                region = "DATA";
                offset = int'(addr - cfg.HOST_DATA_BASE_ADDR);
                return 1'b1;
            end
            region = "MISS";
            offset = 0;
            return 1'b0;
        endfunction

        function void host_post_rqe(input int unsigned slot_idx,
                                    input rqe_t rqe);
            byte unsigned bytes[64];
            int unsigned offset;

            if (slot_idx >= cfg.RQ_DEPTH) begin
                `uvm_error("HOST_MEM", $sformatf("RQ slot %0d outside depth %0d",
                                                 slot_idx, cfg.RQ_DEPTH))
                return;
            end
            host_memory_pack_rqe(rqe, bytes);
            offset = slot_idx * 64;
            foreach (bytes[i])
                rq_region[offset + i] = bytes[i];
            rq_tail_shadow = (slot_idx + 1) % cfg.RQ_DEPTH;
            rqe_sidecar_by_slot[slot_idx] = rqe.sidecar_id;
            `uvm_info("HOST_MEM",
                      $sformatf("post RQE slot=%0d len=%0d addr=0x%016h sidecar=0x%016h rq_tail=%0d",
                                slot_idx, rqe.len, rqe.addr, rqe.sidecar_id,
                                rq_tail_shadow),
                      UVM_HIGH)
        endfunction

        function void host_write_cqe(input int unsigned slot_idx,
                                     input cqe_t cqe);
            byte unsigned bytes[16];
            byte unsigned dyn_bytes[];
            int unsigned offset;

            if (slot_idx >= cfg.CQ_DEPTH) begin
                `uvm_error("HOST_MEM", $sformatf("CQ slot %0d outside depth %0d",
                                                 slot_idx, cfg.CQ_DEPTH))
                return;
            end
            host_memory_pack_cqe(cqe, bytes);
            dyn_bytes = new[16];
            foreach (bytes[i])
                dyn_bytes[i] = bytes[i];
            offset = slot_idx * 16;
            write_bytes(cfg.HOST_CQ_BASE_ADDR + offset, dyn_bytes);
        endfunction

        function bit peek_cqe(input int unsigned slot_idx,
                              output cqe_t cqe);
            byte unsigned bytes[16];
            int unsigned offset;

            cqe = '0;
            if (slot_idx >= cfg.CQ_DEPTH)
                return 1'b0;
            offset = slot_idx * 16;
            foreach (bytes[i])
                bytes[i] = cq_region[offset + i];
            cqe = host_memory_unpack_cqe(bytes);
            return 1'b1;
        endfunction

        function bit host_segment_check(input int unsigned seg_idx,
                                        input byte unsigned expected_bytes[]);
            int unsigned base;

            if (seg_idx >= cfg.N_SEGMENTS) begin
                `uvm_error("HOST_MEM", $sformatf("segment %0d outside count %0d",
                                                 seg_idx, cfg.N_SEGMENTS))
                return 1'b0;
            end
            if (expected_bytes.size() > cfg.SEG_BYTES) begin
                `uvm_error("HOST_MEM", $sformatf("expected segment bytes %0d exceed segment size %0d",
                                                 expected_bytes.size(),
                                                 cfg.SEG_BYTES))
                return 1'b0;
            end
            base = seg_idx * cfg.SEG_BYTES;
            foreach (expected_bytes[i]) begin
                if (data_region[base + i] != expected_bytes[i]) begin
                    `uvm_error("HOST_MEM",
                               $sformatf("segment %0d byte %0d actual=0x%02h expected=0x%02h",
                                         seg_idx, i, data_region[base + i],
                                         expected_bytes[i]))
                    return 1'b0;
                end
            end
            return 1'b1;
        endfunction

        function int unsigned rq_tail();
            return rq_tail_shadow;
        endfunction

        function int unsigned cq_head();
            return cq_head_shadow;
        endfunction

        function void write_bytes(longint unsigned addr,
                                  input byte unsigned bytes[]);
            string region;
            int unsigned offset;
            int unsigned slot_idx;
            int unsigned seg_idx;
            int unsigned seg_offset;
            host_cqe_event cqe_ev;
            host_data_seg_event data_ev;

            if (!decode_region(addr, region, offset)) begin
                `uvm_warning("HOST_AXI",
                             $sformatf("write outside host regions addr=0x%016h nbytes=%0d",
                                       addr, bytes.size()))
                return;
            end

            if (region == "RQ") begin
                foreach (bytes[i]) begin
                    if ((offset + i) < rq_region.size())
                        rq_region[offset + i] = bytes[i];
                end
            end else if (region == "CQ") begin
                foreach (bytes[i]) begin
                    if ((offset + i) < cq_region.size())
                        cq_region[offset + i] = bytes[i];
                end
                slot_idx = offset / 16;
                if (slot_idx < cfg.CQ_DEPTH) begin
                    cqe_ev = host_cqe_event::type_id::create("cqe_ev");
                    void'(peek_cqe(slot_idx, cqe_ev.cqe));
                    cqe_ev.slot_idx = slot_idx;
                    cqe_ev.addr = cfg.HOST_CQ_BASE_ADDR + (slot_idx * 16);
                    cqe_ev.sample_time = $time;
                    cq_head_shadow = (slot_idx + 1) % cfg.CQ_DEPTH;
                    cqe_ap.write(cqe_ev);
                end
            end else if (region == "DATA") begin
                foreach (bytes[i]) begin
                    if ((offset + i) < data_region.size())
                        data_region[offset + i] = bytes[i];
                end
                seg_idx = offset / cfg.SEG_BYTES;
                seg_offset = offset % cfg.SEG_BYTES;
                data_ev = host_data_seg_event::type_id::create("data_ev");
                data_ev.seg_idx = seg_idx;
                data_ev.offset = seg_offset;
                data_ev.addr = addr;
                data_ev.sample_time = $time;
                data_ev.set_bytes(bytes);
                data_seg_ap.write(data_ev);
            end
        endfunction

        task automatic read_bytes(input longint unsigned addr,
                                  input int unsigned n_bytes,
                                  output byte unsigned bytes[]);
            string region;
            int unsigned offset;

            bytes = new[n_bytes];
            foreach (bytes[i])
                bytes[i] = 8'h00;
            if (!decode_region(addr, region, offset)) begin
                `uvm_warning("HOST_AXI",
                             $sformatf("read outside host regions addr=0x%016h nbytes=%0d",
                                       addr, n_bytes))
                return;
            end
            if (region == "RQ") begin
                foreach (bytes[i]) begin
                    if ((offset + i) < rq_region.size())
                        bytes[i] = rq_region[offset + i];
                end
            end else if (region == "CQ") begin
                foreach (bytes[i]) begin
                    if ((offset + i) < cq_region.size())
                        bytes[i] = cq_region[offset + i];
                end
            end else if (region == "DATA") begin
                foreach (bytes[i]) begin
                    if ((offset + i) < data_region.size())
                        bytes[i] = data_region[offset + i];
                end
            end
        endtask

        virtual task run_phase(uvm_phase phase);
            if (vif == null) begin
                `uvm_info("HOST_AXI",
                          "no host AXI vif configured; host_memory_model runs standalone until the SWB top exposes the conduit",
                          UVM_LOW)
                return;
            end
            vif.clear_responder();
            fork
                write_channel_loop();
                read_channel_loop();
            join_none
        endtask

        task automatic wait_reset_released();
            while (vif.ARESETn !== 1'b1) begin
                vif.clear_responder();
                @(posedge vif.ACLK);
            end
        endtask

        task automatic write_channel_loop();
            logic [3:0]            awid_q;
            longint unsigned       awaddr_q;
            logic [7:0]            awlen_q;
            logic [2:0]            awsize_q;
            logic [1:0]            awburst_q;
            byte unsigned          beat_bytes[];
            int unsigned           beat;
            int unsigned           lane;
            int unsigned           bytes_per_beat;
            bit                    ok;

            forever begin
                wait_reset_released();
                do begin
                    @(posedge vif.ACLK);
                    vif.awready <= random_ready();
                end while (!(vif.awvalid && vif.awready));
                awid_q = vif.awid;
                awaddr_q = vif.awaddr;
                awlen_q = vif.awlen;
                awsize_q = vif.awsize;
                awburst_q = vif.awburst;
                bytes_per_beat = 1 << int'(awsize_q);
                ok = (awburst_q == 2'b01) && burst_4kb_ok(awaddr_q, burst_bytes(awlen_q, awsize_q));
                vif.awready <= 1'b0;

                for (beat = 0; beat <= int'(awlen_q); beat++) begin
                    do begin
                        @(posedge vif.ACLK);
                        vif.wready <= random_ready();
                    end while (!(vif.wvalid && vif.wready));
                    beat_bytes = new[DATA_BYTES];
                    for (lane = 0; lane < DATA_BYTES; lane++)
                        beat_bytes[lane] = vif.wdata[lane * 8 +: 8];
                    if (ok)
                        write_bytes(awaddr_q + (beat * bytes_per_beat), beat_bytes);
                    if ((beat != int'(awlen_q)) && vif.wlast)
                        ok = 1'b0;
                end
                vif.wready <= 1'b0;
                vif.bid <= awid_q;
                vif.bresp <= ok ? 2'b00 : 2'b10;
                vif.bvalid <= 1'b1;
                do begin
                    @(posedge vif.ACLK);
                end while (!vif.bready);
                vif.bvalid <= 1'b0;
            end
        endtask

        task automatic read_channel_loop();
            logic [3:0]            arid_q;
            longint unsigned       araddr_q;
            logic [7:0]            arlen_q;
            logic [2:0]            arsize_q;
            logic [1:0]            arburst_q;
            byte unsigned          beat_bytes[];
            int unsigned           beat;
            int unsigned           lane;
            int unsigned           bytes_per_beat;
            bit                    ok;

            forever begin
                wait_reset_released();
                do begin
                    @(posedge vif.ACLK);
                    vif.arready <= random_ready();
                end while (!(vif.arvalid && vif.arready));
                arid_q = vif.arid;
                araddr_q = vif.araddr;
                arlen_q = vif.arlen;
                arsize_q = vif.arsize;
                arburst_q = vif.arburst;
                bytes_per_beat = 1 << int'(arsize_q);
                ok = (arburst_q == 2'b01) && burst_4kb_ok(araddr_q, burst_bytes(arlen_q, arsize_q));
                vif.arready <= 1'b0;

                for (beat = 0; beat <= int'(arlen_q); beat++) begin
                    if (ok)
                        read_bytes(araddr_q + (beat * bytes_per_beat), DATA_BYTES, beat_bytes);
                    else begin
                        beat_bytes = new[DATA_BYTES];
                        foreach (beat_bytes[i])
                            beat_bytes[i] = 8'h00;
                    end
                    vif.rid <= arid_q;
                    vif.rdata <= '0;
                    for (lane = 0; lane < DATA_BYTES; lane++)
                        vif.rdata[lane * 8 +: 8] <= beat_bytes[lane];
                    vif.rresp <= ok ? 2'b00 : 2'b10;
                    vif.rlast <= (beat == int'(arlen_q));
                    vif.rvalid <= 1'b1;
                    do begin
                        @(posedge vif.ACLK);
                    end while (!vif.rready);
                    vif.rvalid <= 1'b0;
                    vif.rlast <= 1'b0;
                end
            end
        endtask
    endclass

endpackage
