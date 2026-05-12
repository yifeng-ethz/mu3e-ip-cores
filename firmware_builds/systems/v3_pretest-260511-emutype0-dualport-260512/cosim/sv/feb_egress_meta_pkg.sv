`timescale 1ns/1ps

package feb_egress_meta_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        COSIM_PACKET_HIT = 0,
        COSIM_PACKET_SC  = 1,
        COSIM_PACKET_RC  = 2,
        COSIM_PACKET_UNKNOWN = 3
    } cosim_packet_type_e;

    class feb_egress_meta_record extends uvm_sequence_item;
        `uvm_object_utils(feb_egress_meta_record)

        longint unsigned hit_id;
        time             ts_birth;
        int unsigned     channel;
        int unsigned     lane;
        cosim_packet_type_e packet_type;

        function new(string name = "feb_egress_meta_record");
            super.new(name);
            hit_id = 0;
            ts_birth = 0;
            channel = 0;
            lane = 0;
            packet_type = COSIM_PACKET_HIT;
        endfunction

        function string key();
            return $sformatf("lane%0d_ch%0d_hit%0d", lane, channel, hit_id);
        endfunction

        function string convert2string();
            return $sformatf(
                "{hit_id=%0d ts_birth=%0t channel=%0d lane=%0d packet_type=%0d}",
                hit_id, ts_birth, channel, lane, packet_type);
        endfunction
    endclass
endpackage
