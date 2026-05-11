// host_memory_pkg.sv
// Shared host-memory transaction types for SWB tb_int.

package tb_int_host_memory_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam longint unsigned HOST_RQ_BASE   = 64'h0000_0000_1000_0000;
    localparam longint unsigned HOST_CQ_BASE   = 64'h0000_0000_1001_0000;
    localparam longint unsigned HOST_DATA_BASE = 64'h0000_0000_1002_0000;

    typedef struct packed {
        logic [63:0]  addr;
        logic [31:0]  len;
        logic [31:0]  key;
        logic [63:0]  sidecar_id;
        logic [127:0] opaque_tag;
        logic [191:0] reserved;
    } rqe_t;

    typedef struct packed {
        logic [31:0] status;
        logic [31:0] tag;
        logic [63:0] sidecar_id;
    } cqe_t;

    typedef struct {
        int unsigned      RQ_DEPTH;
        int unsigned      CQ_DEPTH;
        int unsigned      N_SEGMENTS;
        int unsigned      SEG_BYTES;
        longint unsigned  HOST_RQ_BASE_ADDR;
        longint unsigned  HOST_CQ_BASE_ADDR;
        longint unsigned  HOST_DATA_BASE_ADDR;
        time              poll_cadence;
        time              record_write_latency;
    } host_memory_config_t;

    function automatic host_memory_config_t host_memory_default_config();
        host_memory_default_config.RQ_DEPTH = 256;
        host_memory_default_config.CQ_DEPTH = 256;
        host_memory_default_config.N_SEGMENTS = 64;
        host_memory_default_config.SEG_BYTES = 4096;
        host_memory_default_config.HOST_RQ_BASE_ADDR = HOST_RQ_BASE;
        host_memory_default_config.HOST_CQ_BASE_ADDR = HOST_CQ_BASE;
        host_memory_default_config.HOST_DATA_BASE_ADDR = HOST_DATA_BASE;
        host_memory_default_config.poll_cadence = 100ns;
        host_memory_default_config.record_write_latency = 0ns;
    endfunction

    function automatic void host_memory_pack_rqe(input rqe_t rqe,
                                                 output byte unsigned bytes[64]);
        logic [511:0] raw;

        raw = rqe;
        foreach (bytes[i])
            bytes[i] = raw[i * 8 +: 8];
    endfunction

    function automatic rqe_t host_memory_unpack_rqe(input byte unsigned bytes[64]);
        logic [511:0] raw;

        raw = '0;
        foreach (bytes[i])
            raw[i * 8 +: 8] = bytes[i];
        host_memory_unpack_rqe = rqe_t'(raw);
    endfunction

    function automatic void host_memory_pack_cqe(input cqe_t cqe,
                                                 output byte unsigned bytes[16]);
        logic [127:0] raw;

        raw = cqe;
        foreach (bytes[i])
            bytes[i] = raw[i * 8 +: 8];
    endfunction

    function automatic cqe_t host_memory_unpack_cqe(input byte unsigned bytes[16]);
        logic [127:0] raw;

        raw = '0;
        foreach (bytes[i])
            raw[i * 8 +: 8] = bytes[i];
        host_memory_unpack_cqe = cqe_t'(raw);
    endfunction

    class host_cqe_event extends uvm_sequence_item;
        `uvm_object_utils(host_cqe_event)

        cqe_t             cqe;
        int unsigned      slot_idx;
        longint unsigned  addr;
        time              sample_time;

        function new(string name = "host_cqe_event");
            super.new(name);
            cqe = '0;
            slot_idx = 0;
            addr = 0;
            sample_time = 0;
        endfunction

        function string convert2string();
            return $sformatf("slot=%0d addr=0x%016h status=0x%08h tag=0x%08h sidecar=0x%016h t=%0t",
                             slot_idx, addr, cqe.status, cqe.tag,
                             cqe.sidecar_id, sample_time);
        endfunction
    endclass

    class host_data_seg_event extends uvm_sequence_item;
        `uvm_object_utils(host_data_seg_event)

        int unsigned      seg_idx;
        int unsigned      offset;
        longint unsigned  addr;
        byte unsigned     bytes[];
        time              sample_time;

        function new(string name = "host_data_seg_event");
            super.new(name);
            seg_idx = 0;
            offset = 0;
            addr = 0;
            sample_time = 0;
        endfunction

        function void set_bytes(input byte unsigned src[]);
            bytes = new[src.size()];
            foreach (src[i])
                bytes[i] = src[i];
        endfunction

        function string convert2string();
            return $sformatf("seg=%0d offset=%0d addr=0x%016h nbytes=%0d t=%0t",
                             seg_idx, offset, addr, bytes.size(), sample_time);
        endfunction
    endclass

endpackage
