`timescale 1ns/1ps

package sanity_1ms_periodic_all_channel_seq_pkg;
    import uvm_pkg::*;
    import feb_egress_meta_pkg::*;
    `include "uvm_macros.svh"

    class sanity_1ms_periodic_all_channel_seq extends uvm_sequence#(feb_egress_meta_record);
        `uvm_object_utils(sanity_1ms_periodic_all_channel_seq)

        localparam int unsigned RUN_WINDOW_8NS = 125000;
        localparam int unsigned HIT_PERIOD_8NS = 5000;
        localparam int unsigned CHANNELS_PER_ASIC = 32;
        localparam int unsigned ASIC_COUNT = 8;
        localparam int unsigned TARGET_HITS =
            (RUN_WINDOW_8NS / HIT_PERIOD_8NS) * CHANNELS_PER_ASIC * ASIC_COUNT;

        function new(string name = "sanity_1ms_periodic_all_channel_seq");
            super.new(name);
        endfunction

        virtual task body();
            for (int unsigned hit = 0; hit < TARGET_HITS; hit++) begin
                feb_egress_meta_record meta;

                meta = feb_egress_meta_record::type_id::create("meta");
                start_item(meta);
                meta.hit_id = hit;
                meta.ts_birth = $time;
                meta.channel = hit % CHANNELS_PER_ASIC;
                meta.lane = (hit / CHANNELS_PER_ASIC) % ASIC_COUNT;
                meta.packet_type = COSIM_PACKET_HIT;
                finish_item(meta);
            end
        endtask
    endclass
endpackage
