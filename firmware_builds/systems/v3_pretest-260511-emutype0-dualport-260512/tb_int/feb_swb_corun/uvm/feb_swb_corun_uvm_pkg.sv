`timescale 1ns/1ps

package feb_swb_corun_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int unsigned FEB_SWB_CORUN_LANES = 4;
    localparam bit [3:0]    FEB_SWB_CORUN_ACTIVE_MASK_DEFAULT = 4'h3;
    localparam int unsigned FEB_SWB_CORUN_DEFAULT_RATE_HZ = 100000;
    localparam bit [7:0]    FEB_SWB_K285 = 8'hbc;
    localparam bit [7:0]    FEB_SWB_K284 = 8'h9c;
    localparam bit [7:0]    FEB_SWB_K237 = 8'hf7;

    typedef enum int unsigned {
        FEB_SWB_SOURCE_UNKNOWN    = 0,
        FEB_SWB_SOURCE_MUTRIG_EMU = 1,
        FEB_SWB_SOURCE_REAL_LVDS  = 2,
        FEB_SWB_SOURCE_FEB_FRAME  = 3
    } feb_swb_source_id_e;

    typedef struct packed {
        bit [1:0]  debug_level;
        bit [1:0]  swb_lane;
        bit [3:0]  source_id;
        bit [7:0]  ps_tag;
        bit [15:0] ts_tag;
        bit [31:0] hit_id;
    } feb_swb_debug_meta_t;

    function automatic bit [63:0] feb_swb_pack_debug_meta(
        input feb_swb_debug_meta_t meta
    );
        return {
            meta.debug_level,
            meta.swb_lane,
            meta.source_id,
            meta.ps_tag,
            meta.ts_tag,
            meta.hit_id
        };
    endfunction

    function automatic feb_swb_debug_meta_t feb_swb_unpack_debug_meta(
        input bit [63:0] bits
    );
        feb_swb_debug_meta_t meta;

        meta.debug_level = bits[63:62];
        meta.swb_lane    = bits[61:60];
        meta.source_id   = bits[59:56];
        meta.ps_tag      = bits[55:48];
        meta.ts_tag      = bits[47:32];
        meta.hit_id      = bits[31:0];
        return meta;
    endfunction

    function automatic string feb_swb_meta_key(input feb_swb_debug_meta_t meta);
        return $sformatf("ps%02h_ts%04h_hit%08h",
                         meta.ps_tag, meta.ts_tag, meta.hit_id);
    endfunction

    function automatic bit [63:0] feb_swb_normalize_dma_hit(
        input bit [63:0] raw_hit
    );
        return raw_hit;
    endfunction

    function automatic bit feb_swb_word_is_subheader(
        input bit [3:0]  datak,
        input bit [31:0] data
    );
        return datak[0] && (data[7:0] == FEB_SWB_K237);
    endfunction

    function automatic bit [47:0] feb_swb_true_packet_ts(
        input bit [31:0] header_ts_high_word,
        input bit [31:0] header_ts_low_word,
        input bit [7:0]  subheader_ts,
        input bit [31:0] hit_word
    );
        return {
            header_ts_high_word,
            header_ts_low_word[31:28],
            subheader_ts,
            hit_word[31:28]
        };
    endfunction

    class feb_swb_corun_cfg extends uvm_object;
        `uvm_object_utils(feb_swb_corun_cfg)

        bit [3:0]    active_lane_mask;
        int unsigned virtual_mutrig_asic;
        int unsigned virtual_mutrig_channel;
        int unsigned virtual_mutrig_rate_hz;
        int unsigned debug_level;
        int unsigned feb_clk_hz;
        int unsigned swb_clk_hz;
        bit          require_dma_match;
        bit          require_observations;
        bit          drop_idle_dma_slots;
        bit          csr_config_done;
        bit          run_control_synced;
        int unsigned max_observations;
        int unsigned max_tunnel_latency_cycles;

        function new(string name = "feb_swb_corun_cfg");
            super.new(name);
            active_lane_mask      = FEB_SWB_CORUN_ACTIVE_MASK_DEFAULT;
            virtual_mutrig_asic   = 0;
            virtual_mutrig_channel = 0;
            virtual_mutrig_rate_hz = FEB_SWB_CORUN_DEFAULT_RATE_HZ;
            debug_level           = 2;
            feb_clk_hz            = 125000000;
            swb_clk_hz            = 250000000;
            require_dma_match     = 1'b1;
            require_observations  = 1'b0;
            drop_idle_dma_slots   = 1'b1;
            csr_config_done       = 1'b0;
            run_control_synced    = 1'b0;
            max_observations      = 100000;
            max_tunnel_latency_cycles = 200000;
        endfunction

        function bit lane_active(input int unsigned lane_id);
            return (lane_id < FEB_SWB_CORUN_LANES) &&
                   (active_lane_mask[lane_id] == 1'b1);
        endfunction

        function void apply_plusargs();
            int plusarg_value;

            if ($value$plusargs("FEB_SWB_ACTIVE_MASK=%h", plusarg_value))
                active_lane_mask = plusarg_value[3:0];
            if ($value$plusargs("FEB_SWB_MUTRIG_ASIC=%d", plusarg_value))
                virtual_mutrig_asic = plusarg_value;
            if ($value$plusargs("FEB_SWB_MUTRIG_CHANNEL=%d", plusarg_value))
                virtual_mutrig_channel = plusarg_value;
            if ($value$plusargs("FEB_SWB_HIT_RATE_HZ=%d", plusarg_value))
                virtual_mutrig_rate_hz = plusarg_value;
            if ($value$plusargs("FEB_SWB_DEBUG_LEVEL=%d", plusarg_value))
                debug_level = plusarg_value;
            if (debug_level < 1 || debug_level > 2)
                `uvm_fatal("FEB_SWB_CFG",
                           $sformatf("FEB_SWB_DEBUG_LEVEL must be 1 or 2, got %0d",
                                     debug_level))
            if ($value$plusargs("FEB_SWB_MAX_OBSERVATIONS=%d", plusarg_value))
                max_observations = plusarg_value;
            if ($value$plusargs("FEB_SWB_MAX_TUNNEL_LATENCY_CYCLES=%d", plusarg_value))
                max_tunnel_latency_cycles = plusarg_value;
            if ($value$plusargs("FEB_SWB_REQUIRE_DMA=%d", plusarg_value))
                require_dma_match = (plusarg_value != 0);
            require_observations = require_observations ||
                                   $test$plusargs("FEB_SWB_SELF_SMOKE");
        endfunction

        function string convert2string();
            return $sformatf(
                "{active_mask=0x%0h mutrig=asic%0d/ch%0d rate_hz=%0d debug=%0d feb_clk=%0d swb_clk=%0d require_dma=%0b csr_done=%0b run_sync=%0b max_obs=%0d max_latency_cycles=%0d}",
                active_lane_mask,
                virtual_mutrig_asic,
                virtual_mutrig_channel,
                virtual_mutrig_rate_hz,
                debug_level,
                feb_clk_hz,
                swb_clk_hz,
                require_dma_match,
                csr_config_done,
                run_control_synced,
                max_observations,
                max_tunnel_latency_cycles
            );
        endfunction
    endclass

    class feb_swb_feb_frame_beat extends uvm_sequence_item;
        `uvm_object_utils(feb_swb_feb_frame_beat)

        int unsigned lane_id;
        bit          valid_ready_sample;
        bit [35:0]   data36;
        bit [31:0]   data32;
        bit [3:0]    datak;
        bit          sop;
        bit          eop;
        bit          debug_valid;
        bit [63:0]   debug_meta_bits;
        feb_swb_debug_meta_t meta;
        int unsigned source_asic;
        int unsigned source_channel;
        int unsigned hit_rate_hz;
        bit          true_ts_valid;
        bit [47:0]   true_ts;
        bit [7:0]    subheader_ts;
        bit [3:0]    hit_ts_nibble;
        time         sample_time;

        function new(string name = "feb_swb_feb_frame_beat");
            super.new(name);
        endfunction

        function string key();
            if (!debug_valid)
                return $sformatf("payload_%08h_lane%0d", data32, lane_id);
            return feb_swb_meta_key(meta);
        endfunction

        function string payload_key();
            return $sformatf("feb_lane%0d_datak%0h_data%08h",
                             lane_id, datak, data32);
        endfunction

        function string convert2string();
            return $sformatf(
                "{lane=%0d data36=0x%09h sop=%0b eop=%0b dbg=%0b key=%s asic=%0d ch=%0d rate=%0d true_ts_valid=%0b true_ts=0x%012h subh=0x%02h hit_ts=0x%01h t=%0t}",
                lane_id, data36, sop, eop, debug_valid, key(),
                source_asic, source_channel, hit_rate_hz,
                true_ts_valid, true_ts, subheader_ts, hit_ts_nibble,
                sample_time
            );
        endfunction
    endclass

    class feb_swb_opq_beat extends uvm_sequence_item;
        `uvm_object_utils(feb_swb_opq_beat)

        int unsigned lane_id;
        bit [31:0]   data32;
        bit [3:0]    datak;
        bit          sop;
        bit          eop;
        bit          debug_valid;
        bit [63:0]   debug_meta_bits;
        feb_swb_debug_meta_t meta;
        bit          frame_ts_valid;
        bit [47:0]   frame_ts;
        bit [15:0]   bucket_ts;
        bit          true_ts_valid;
        bit [47:0]   true_ts;
        bit [7:0]    subheader_ts;
        bit [3:0]    hit_ts_nibble;
        int unsigned word_index;
        time         sample_time;

        function new(string name = "feb_swb_opq_beat");
            super.new(name);
        endfunction

        function string key();
            if (!debug_valid)
                return $sformatf("opq_lane%0d_word%0d_%08h",
                                 lane_id, word_index, data32);
            return feb_swb_meta_key(meta);
        endfunction

        function string payload_key();
            return $sformatf("opq_lane%0d_datak%0h_data%08h",
                             lane_id, datak, data32);
        endfunction

        function string convert2string();
            return $sformatf(
                "{lane=%0d word=%0d data=0x%08h datak=0x%0h sop=%0b eop=%0b dbg=%0b key=%s frame_ts_valid=%0b frame_ts=0x%012h bucket_ts=0x%04h true_ts_valid=%0b true_ts=0x%012h subh=0x%02h hit_ts=0x%01h t=%0t}",
                lane_id, word_index, data32, datak, sop, eop,
                debug_valid, key(), frame_ts_valid, frame_ts, bucket_ts,
                true_ts_valid, true_ts, subheader_ts, hit_ts_nibble,
                sample_time
            );
        endfunction
    endclass

    class feb_swb_dma_hit_word extends uvm_sequence_item;
        `uvm_object_utils(feb_swb_dma_hit_word)

        int unsigned slot_id;
        bit [255:0]  dma_word;
        bit [63:0]   raw_hit64;
        bit [63:0]   normalized_hit64;
        bit          debug_valid;
        bit [63:0]   debug_meta_bits;
        feb_swb_debug_meta_t meta;
        time         sample_time;

        function new(string name = "feb_swb_dma_hit_word");
            super.new(name);
        endfunction

        function string key();
            if (!debug_valid)
                return $sformatf("hit_%016h", normalized_hit64);
            return feb_swb_meta_key(meta);
        endfunction

        function string payload_key();
            return $sformatf("dma_hit%016h", normalized_hit64);
        endfunction

        function string convert2string();
            return $sformatf(
                "{slot=%0d raw=0x%016h norm=0x%016h dbg=%0b key=%s t=%0t}",
                slot_id, raw_hit64, normalized_hit64, debug_valid, key(),
                sample_time
            );
        endfunction
    endclass

    `uvm_analysis_imp_decl(_feb)
    `uvm_analysis_imp_decl(_opq)
    `uvm_analysis_imp_decl(_dma)

    class feb_swb_feb_monitor extends uvm_component;
        `uvm_component_utils(feb_swb_feb_monitor)

        virtual feb_swb_feb_stream_if vif;
        feb_swb_corun_cfg cfg;
        int unsigned lane_id;
        uvm_analysis_port#(feb_swb_feb_frame_beat) ap;
        bit        in_frame;
        int unsigned word_index;
        bit        header_ts_valid;
        bit        subheader_ts_valid;
        bit [31:0] header_ts_high_word;
        bit [31:0] header_ts_low_word;
        bit [7:0]  current_subheader_ts;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            int lane_tmp;

            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual feb_swb_feb_stream_if)::get(
                    this, "", "vif", vif))
                `uvm_info("FEB_SWB_FEB_MON",
                          "FEB stream vif not configured; monitor disabled",
                          UVM_LOW)
            if (uvm_config_db#(int)::get(this, "", "lane_id", lane_tmp))
                lane_id = lane_tmp;
            else
                lane_id = 0;
            if (!uvm_config_db#(feb_swb_corun_cfg)::get(this, "", "cfg", cfg))
                cfg = feb_swb_corun_cfg::type_id::create("cfg");
            in_frame              = 1'b0;
            word_index            = 0;
            header_ts_valid       = 1'b0;
            subheader_ts_valid    = 1'b0;
            header_ts_high_word   = '0;
            header_ts_low_word    = '0;
            current_subheader_ts  = '0;
        endfunction

        function bit sop_word();
            return vif.sop || (vif.data[32] && vif.data[7:0] == FEB_SWB_K285);
        endfunction

        function bit eop_word();
            return vif.eop || (vif.data[32] && vif.data[7:0] == FEB_SWB_K284);
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                if (!vif.rst_n) begin
                    in_frame             = 1'b0;
                    word_index           = 0;
                    header_ts_valid      = 1'b0;
                    subheader_ts_valid   = 1'b0;
                    header_ts_high_word  = '0;
                    header_ts_low_word   = '0;
                    current_subheader_ts = '0;
                    continue;
                end
                if (vif.valid && vif.ready) begin
                    feb_swb_feb_frame_beat item;
                    bit sample_sop;
                    bit sample_eop;
                    bit sample_subheader;
                    bit sample_hit;
                    bit sample_true_ts_valid;
                    bit [47:0] sample_true_ts;

                    sample_sop = sop_word();
                    sample_eop = eop_word();
                    sample_subheader =
                        in_frame && feb_swb_word_is_subheader(vif.data[35:32],
                                                              vif.data[31:0]);

                    if (sample_sop) begin
                        in_frame             = 1'b1;
                        word_index           = 0;
                        header_ts_valid      = 1'b0;
                        subheader_ts_valid   = 1'b0;
                        header_ts_high_word  = '0;
                        header_ts_low_word   = '0;
                        current_subheader_ts = '0;
                    end else if (in_frame) begin
                        word_index++;
                    end

                    if (in_frame && word_index == 1)
                        header_ts_high_word = vif.data[31:0];
                    if (in_frame && word_index == 2) begin
                        header_ts_low_word = vif.data[31:0];
                        header_ts_valid    = 1'b1;
                    end
                    if (sample_subheader) begin
                        current_subheader_ts = vif.data[31:24];
                        subheader_ts_valid   = 1'b1;
                    end

                    sample_hit = in_frame && header_ts_valid &&
                                 subheader_ts_valid &&
                                 (vif.data[35:32] == 4'h0) &&
                                 !sample_subheader;
                    sample_true_ts_valid = sample_hit;
                    sample_true_ts = feb_swb_true_packet_ts(
                        header_ts_high_word,
                        header_ts_low_word,
                        current_subheader_ts,
                        vif.data[31:0]);

                    item = feb_swb_feb_frame_beat::type_id::create("feb_item");
                    item.lane_id            = lane_id;
                    item.valid_ready_sample = 1'b1;
                    item.data36             = vif.data;
                    item.datak              = vif.data[35:32];
                    item.data32             = vif.data[31:0];
                    item.sop                = vif.sop;
                    item.eop                = vif.eop;
                    item.debug_valid        = vif.debug_valid;
                    item.debug_meta_bits    = vif.debug_meta;
                    item.meta               = feb_swb_unpack_debug_meta(vif.debug_meta);
                    item.source_asic        = vif.source_asic;
                    item.source_channel     = vif.source_channel;
                    item.hit_rate_hz        = vif.hit_rate_hz;
                    item.true_ts_valid      = sample_true_ts_valid;
                    item.true_ts            = sample_true_ts;
                    item.subheader_ts       = current_subheader_ts;
                    item.hit_ts_nibble      = vif.data[31:28];
                    item.sample_time        = $time;
                    ap.write(item);

                    if (sample_eop) begin
                        in_frame             = 1'b0;
                        word_index           = 0;
                        header_ts_valid      = 1'b0;
                        subheader_ts_valid   = 1'b0;
                        header_ts_high_word  = '0;
                        header_ts_low_word   = '0;
                        current_subheader_ts = '0;
                    end
                end
            end
        endtask
    endclass

    class feb_swb_opq_monitor extends uvm_component;
        `uvm_component_utils(feb_swb_opq_monitor)

        virtual feb_swb_opq_stream_if vif;
        feb_swb_corun_cfg cfg;
        int unsigned lane_id;
        uvm_analysis_port#(feb_swb_opq_beat) ap;

        bit        in_frame;
        int unsigned word_index;
        bit        frame_ts_valid;
        bit [47:0] frame_ts;
        bit        subheader_ts_valid;
        bit [31:0] header_ts_high_word;
        bit [31:0] header_ts_low_word;
        bit [7:0]  current_subheader_ts;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            int lane_tmp;

            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual feb_swb_opq_stream_if)::get(
                    this, "", "vif", vif))
                `uvm_info("FEB_SWB_OPQ_MON",
                          "OPQ stream vif not configured; monitor disabled",
                          UVM_LOW)
            if (uvm_config_db#(int)::get(this, "", "lane_id", lane_tmp))
                lane_id = lane_tmp;
            else
                lane_id = 0;
            if (!uvm_config_db#(feb_swb_corun_cfg)::get(this, "", "cfg", cfg))
                cfg = feb_swb_corun_cfg::type_id::create("cfg");
            in_frame       = 1'b0;
            word_index     = 0;
            frame_ts_valid = 1'b0;
            frame_ts       = '0;
            subheader_ts_valid   = 1'b0;
            header_ts_high_word  = '0;
            header_ts_low_word   = '0;
            current_subheader_ts = '0;
        endfunction

        function bit sop_word();
            return vif.sop || (vif.datak[0] && vif.data[7:0] == FEB_SWB_K285);
        endfunction

        function bit eop_word();
            return vif.eop || (vif.datak[0] && vif.data[7:0] == FEB_SWB_K284);
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                if (!vif.rst_n) begin
                    in_frame       = 1'b0;
                    word_index     = 0;
                    frame_ts_valid = 1'b0;
                    frame_ts       = '0;
                    subheader_ts_valid   = 1'b0;
                    header_ts_high_word  = '0;
                    header_ts_low_word   = '0;
                    current_subheader_ts = '0;
                    continue;
                end
                if (vif.valid && vif.ready) begin
                    feb_swb_opq_beat item;
                    bit sample_subheader;
                    bit sample_hit;
                    bit sample_true_ts_valid;
                    bit [47:0] sample_true_ts;

                    if (sop_word()) begin
                        in_frame       = 1'b1;
                        word_index     = 0;
                        frame_ts_valid = 1'b0;
                        frame_ts       = '0;
                        subheader_ts_valid   = 1'b0;
                        header_ts_high_word  = '0;
                        header_ts_low_word   = '0;
                        current_subheader_ts = '0;
                    end else if (in_frame) begin
                        word_index++;
                    end

                    if (in_frame && word_index == 1) begin
                        header_ts_high_word = vif.data;
                        frame_ts[47:16] = vif.data;
                    end
                    if (in_frame && word_index == 2) begin
                        header_ts_low_word = vif.data;
                        frame_ts[15:0]  = vif.data[31:16];
                        frame_ts_valid  = 1'b1;
                    end

                    sample_subheader =
                        in_frame && feb_swb_word_is_subheader(vif.datak,
                                                              vif.data);
                    if (sample_subheader) begin
                        current_subheader_ts = vif.data[31:24];
                        subheader_ts_valid   = 1'b1;
                    end
                    sample_hit = in_frame && frame_ts_valid &&
                                 subheader_ts_valid &&
                                 (vif.datak == 4'h0) &&
                                 !sample_subheader;
                    sample_true_ts_valid = sample_hit;
                    sample_true_ts = feb_swb_true_packet_ts(
                        header_ts_high_word,
                        header_ts_low_word,
                        current_subheader_ts,
                        vif.data);

                    item = feb_swb_opq_beat::type_id::create("opq_item");
                    item.lane_id         = lane_id;
                    item.data32          = vif.data;
                    item.datak           = vif.datak;
                    item.sop             = sop_word();
                    item.eop             = eop_word();
                    item.debug_valid     = vif.debug_valid;
                    item.debug_meta_bits = vif.debug_meta;
                    item.meta            = feb_swb_unpack_debug_meta(vif.debug_meta);
                    item.frame_ts_valid  = frame_ts_valid;
                    item.frame_ts        = frame_ts;
                    item.bucket_ts       = frame_ts[15:0];
                    item.true_ts_valid   = sample_true_ts_valid;
                    item.true_ts         = sample_true_ts;
                    item.subheader_ts    = current_subheader_ts;
                    item.hit_ts_nibble   = vif.data[31:28];
                    item.word_index      = word_index;
                    item.sample_time     = $time;
                    ap.write(item);

                    if (eop_word()) begin
                        in_frame       = 1'b0;
                        word_index     = 0;
                        frame_ts_valid = 1'b0;
                        frame_ts       = '0;
                        subheader_ts_valid   = 1'b0;
                        header_ts_high_word  = '0;
                        header_ts_low_word   = '0;
                        current_subheader_ts = '0;
                    end
                end
            end
        endtask
    endclass

    class feb_swb_dma_monitor extends uvm_component;
        `uvm_component_utils(feb_swb_dma_monitor)

        virtual feb_swb_dma_stream_if vif;
        feb_swb_corun_cfg cfg;
        uvm_analysis_port#(feb_swb_dma_hit_word) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual feb_swb_dma_stream_if)::get(
                    this, "", "vif", vif))
                `uvm_info("FEB_SWB_DMA_MON",
                          "DMA stream vif not configured; monitor disabled",
                          UVM_LOW)
            if (!uvm_config_db#(feb_swb_corun_cfg)::get(this, "", "cfg", cfg))
                cfg = feb_swb_corun_cfg::type_id::create("cfg");
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                if (!vif.rst_n)
                    continue;
                if (vif.valid && vif.ready) begin
                    for (int slot = 0; slot < 4; slot++) begin
                        bit [63:0] raw_hit;
                        feb_swb_dma_hit_word item;

                        if (!vif.keep[slot])
                            continue;
                        raw_hit = vif.data[(slot * 64) +: 64];
                        if (cfg.drop_idle_dma_slots &&
                            (raw_hit == 64'h0 || raw_hit == 64'hffffffffffffffff))
                            continue;
                        item = feb_swb_dma_hit_word::type_id::create("dma_item");
                        item.slot_id          = slot;
                        item.dma_word         = vif.data;
                        item.raw_hit64        = raw_hit;
                        item.normalized_hit64 = feb_swb_normalize_dma_hit(raw_hit);
                        item.debug_valid      = vif.debug_valid[slot];
                        item.debug_meta_bits  = vif.debug_meta[slot];
                        item.meta             =
                            feb_swb_unpack_debug_meta(vif.debug_meta[slot]);
                        item.sample_time      = $time;
                        ap.write(item);
                    end
                end
            end
        endtask
    endclass

    typedef feb_swb_feb_frame_beat feb_q_t[$];
    typedef feb_swb_opq_beat       opq_q_t[$];
    typedef feb_swb_dma_hit_word   dma_q_t[$];

    class feb_swb_corun_scoreboard extends uvm_component;
        `uvm_component_utils(feb_swb_corun_scoreboard)

        uvm_analysis_imp_feb#(feb_swb_feb_frame_beat,
                              feb_swb_corun_scoreboard) feb_imp;
        uvm_analysis_imp_opq#(feb_swb_opq_beat,
                              feb_swb_corun_scoreboard) opq_imp;
        uvm_analysis_imp_dma#(feb_swb_dma_hit_word,
                              feb_swb_corun_scoreboard) dma_imp;

        feb_swb_corun_cfg cfg;
        feb_q_t feb_by_key[string];
        feb_q_t feb_by_payload[string];
        opq_q_t opq_by_key[string];
        opq_q_t opq_by_payload[string];
        dma_q_t dma_by_key[string];
        dma_q_t dma_by_payload[string];
        time feb_time_by_key[string];

        int unsigned total_feb;
        int unsigned total_opq_debug;
        int unsigned total_opq_payload;
        int unsigned total_dma;
        int unsigned total_dma_payload;
        int unsigned inactive_lane_observations;
        int unsigned frame_ts_mismatches;
        int unsigned packet_ts_mismatches;
        int unsigned tunnel_latency_violations;
        int unsigned max_seen_tunnel_latency_cycles;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            feb_imp = new("feb_imp", this);
            opq_imp = new("opq_imp", this);
            dma_imp = new("dma_imp", this);
            if (!uvm_config_db#(feb_swb_corun_cfg)::get(this, "", "cfg", cfg))
                cfg = feb_swb_corun_cfg::type_id::create("cfg");
        endfunction

        function void check_observation_limit(input string stage_name,
                                              input int unsigned count_value);
            if (cfg.max_observations != 0 &&
                count_value > cfg.max_observations) begin
                `uvm_fatal("FEB_SWB_LIMIT",
                           $sformatf("%s observations exceeded hard limit: %0d > %0d",
                                     stage_name, count_value,
                                     cfg.max_observations))
            end
        endfunction

        function void check_tunnel_latency(input string tunnel_name,
                                           input string key,
                                           input time start_time,
                                           input time end_time);
            int unsigned latency_cycles;

            if (end_time < start_time) begin
                tunnel_latency_violations++;
                `uvm_error("FEB_SWB_LATENCY",
                           $sformatf("%s negative latency key=%s start=%0t end=%0t",
                                     tunnel_name, key, start_time, end_time))
                return;
            end
            latency_cycles = int'((end_time - start_time) / 8000);
            if (latency_cycles > max_seen_tunnel_latency_cycles)
                max_seen_tunnel_latency_cycles = latency_cycles;
            if (cfg.max_tunnel_latency_cycles != 0 &&
                latency_cycles > cfg.max_tunnel_latency_cycles) begin
                tunnel_latency_violations++;
                `uvm_error("FEB_SWB_LATENCY",
                           $sformatf("%s latency exceeded hard limit key=%s latency=%0d cycles limit=%0d",
                                     tunnel_name, key, latency_cycles,
                                     cfg.max_tunnel_latency_cycles))
            end
        endfunction

        function void check_true_packet_ts(
            input string stage_name,
            input string key,
            input bit debug_valid,
            input bit true_ts_valid,
            input bit [47:0] true_ts,
            input feb_swb_debug_meta_t meta,
            input string item_text
        );
            if (!debug_valid)
                return;
            if (!true_ts_valid) begin
                packet_ts_mismatches++;
                `uvm_error("FEB_SWB_TS",
                           $sformatf("%s debug hit has no reconstructed true packet timestamp key=%s item=%s",
                                     stage_name, key, item_text))
                return;
            end
            if (true_ts[15:0] != meta.ts_tag ||
                true_ts[7:0] != meta.ps_tag) begin
                packet_ts_mismatches++;
                `uvm_error("FEB_SWB_TS",
                           $sformatf("%s true packet timestamp mismatch key=%s true_ts=0x%012h meta_ts=0x%04h meta_ps=0x%02h subheader=0x%02h hit_ts=0x%01h item=%s",
                                     stage_name, key, true_ts, meta.ts_tag,
                                     meta.ps_tag, true_ts[11:4],
                                     true_ts[3:0], item_text))
            end
        endfunction

        function void write_feb(feb_swb_feb_frame_beat item);
            string key;

            if (item == null)
                return;
            if (!cfg.lane_active(item.lane_id)) begin
                inactive_lane_observations++;
                `uvm_error("FEB_SWB_SB",
                           $sformatf("FEB lane%0d observed while masked: %s",
                                     item.lane_id, item.convert2string()))
            end
            if (item.source_asic != cfg.virtual_mutrig_asic ||
                item.source_channel != cfg.virtual_mutrig_channel ||
                item.hit_rate_hz != cfg.virtual_mutrig_rate_hz) begin
                `uvm_warning("FEB_SWB_SOURCE",
                             $sformatf("unexpected source/rate observed: %s expected asic%0d/ch%0d/%0dHz",
                                       item.convert2string(),
                                       cfg.virtual_mutrig_asic,
                                       cfg.virtual_mutrig_channel,
                                       cfg.virtual_mutrig_rate_hz))
            end
            key = item.key();
            feb_by_payload[item.payload_key()].push_back(item);
            if (item.debug_valid) begin
                check_true_packet_ts("FEB", key, item.debug_valid,
                                     item.true_ts_valid, item.true_ts,
                                     item.meta, item.convert2string());
                feb_by_key[key].push_back(item);
                if (!feb_time_by_key.exists(key))
                    feb_time_by_key[key] = item.sample_time;
            end
            total_feb++;
            check_observation_limit("FEB", total_feb);
        endfunction

        function void write_opq(feb_swb_opq_beat item);
            string key;

            if (item == null)
                return;
            if (!cfg.lane_active(item.lane_id) && item.debug_valid) begin
                inactive_lane_observations++;
                `uvm_error("FEB_SWB_SB",
                           $sformatf("OPQ lane%0d observed debug payload while masked: %s",
                                     item.lane_id, item.convert2string()))
            end
            opq_by_payload[item.payload_key()].push_back(item);
            total_opq_payload++;
            check_observation_limit("OPQ payload", total_opq_payload);
            if (!item.debug_valid)
                return;
            key = item.key();
            check_true_packet_ts("OPQ", key, item.debug_valid,
                                 item.true_ts_valid, item.true_ts,
                                 item.meta, item.convert2string());
            opq_by_key[key].push_back(item);
            total_opq_debug++;
            check_observation_limit("OPQ debug", total_opq_debug);
            if (feb_time_by_key.exists(key))
                check_tunnel_latency("FEB->OPQ", key, feb_time_by_key[key],
                                     item.sample_time);
            if (item.true_ts_valid && item.true_ts[15:0] != item.meta.ts_tag) begin
                frame_ts_mismatches++;
                `uvm_error("FEB_SWB_TS",
                           $sformatf("OPQ true timestamp low16 mismatch key=%s true_ts=0x%012h meta_ts=0x%04h",
                                     key, item.true_ts, item.meta.ts_tag))
            end
        endfunction

        function void write_dma(feb_swb_dma_hit_word item);
            string key;

            if (item == null)
                return;
            key = item.key();
            dma_by_key[key].push_back(item);
            dma_by_payload[item.payload_key()].push_back(item);
            total_dma++;
            total_dma_payload++;
            check_observation_limit("DMA", total_dma);
            if (item.debug_valid && feb_time_by_key.exists(key))
                check_tunnel_latency("FEB->DMA", key, feb_time_by_key[key],
                                     item.sample_time);
        endfunction

        virtual function void check_phase(uvm_phase phase);
            int unsigned missing_opq;
            int unsigned missing_dma;
            int unsigned ghost_opq;
            int unsigned ghost_dma;

            super.check_phase(phase);
            foreach (feb_by_key[key]) begin
                if (!opq_by_key.exists(key) ||
                    opq_by_key[key].size() < feb_by_key[key].size()) begin
                    missing_opq++;
                    `uvm_error("FEB_SWB_SB",
                               $sformatf("missing OPQ observation for key=%s expected=%0d observed=%0d",
                                         key, feb_by_key[key].size(),
                                         opq_by_key.exists(key) ?
                                             opq_by_key[key].size() : 0))
                end
                if (cfg.require_dma_match &&
                    (!dma_by_key.exists(key) ||
                     dma_by_key[key].size() < feb_by_key[key].size())) begin
                    missing_dma++;
                    `uvm_error("FEB_SWB_SB",
                               $sformatf("missing DMA observation for key=%s expected=%0d observed=%0d",
                                         key, feb_by_key[key].size(),
                                         dma_by_key.exists(key) ?
                                             dma_by_key[key].size() : 0))
                end
            end
            foreach (opq_by_key[key]) begin
                if (!feb_by_key.exists(key)) begin
                    ghost_opq++;
                    `uvm_error("FEB_SWB_SB",
                               $sformatf("ghost OPQ observation for key=%s count=%0d",
                                         key, opq_by_key[key].size()))
                end
            end
            foreach (dma_by_key[key]) begin
                if (!feb_by_key.exists(key)) begin
                    ghost_dma++;
                    `uvm_error("FEB_SWB_SB",
                               $sformatf("ghost DMA observation for key=%s count=%0d",
                                         key, dma_by_key[key].size()))
                end
            end
            if (cfg.require_observations && total_feb == 0)
                `uvm_error("FEB_SWB_SB", "no FEB observations captured")
            `uvm_info("FEB_SWB_SB",
                      $sformatf("summary feb=%0d opq_debug=%0d opq_payload=%0d dma=%0d dma_payload=%0d missing_opq=%0d missing_dma=%0d ghost_opq=%0d ghost_dma=%0d inactive_lane=%0d ts_mismatch=%0d true_ts_mismatch=%0d latency_violations=%0d max_latency_cycles=%0d",
                                total_feb, total_opq_debug, total_opq_payload,
                                total_dma, total_dma_payload,
                                missing_opq, missing_dma, ghost_opq, ghost_dma,
                                inactive_lane_observations,
                                frame_ts_mismatches,
                                packet_ts_mismatches,
                                tunnel_latency_violations,
                                max_seen_tunnel_latency_cycles),
                      UVM_LOW)
        endfunction
    endclass

    class feb_swb_corun_env extends uvm_env;
        `uvm_component_utils(feb_swb_corun_env)

        feb_swb_corun_cfg cfg;
        feb_swb_feb_monitor feb_mon[FEB_SWB_CORUN_LANES];
        feb_swb_opq_monitor opq_mon[FEB_SWB_CORUN_LANES];
        feb_swb_dma_monitor dma_mon;
        feb_swb_corun_scoreboard scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(feb_swb_corun_cfg)::get(this, "", "cfg", cfg))
                cfg = feb_swb_corun_cfg::type_id::create("cfg");
            uvm_config_db#(feb_swb_corun_cfg)::set(this, "*", "cfg", cfg);
            for (int lane = 0; lane < FEB_SWB_CORUN_LANES; lane++) begin
                feb_mon[lane] = feb_swb_feb_monitor::type_id::create(
                    $sformatf("feb_mon%0d", lane), this);
                opq_mon[lane] = feb_swb_opq_monitor::type_id::create(
                    $sformatf("opq_mon%0d", lane), this);
                uvm_config_db#(int)::set(this,
                                         $sformatf("feb_mon%0d", lane),
                                         "lane_id",
                                         lane);
                uvm_config_db#(int)::set(this,
                                         $sformatf("opq_mon%0d", lane),
                                         "lane_id",
                                         lane);
            end
            dma_mon = feb_swb_dma_monitor::type_id::create("dma_mon", this);
            scoreboard = feb_swb_corun_scoreboard::type_id::create(
                "scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            for (int lane = 0; lane < FEB_SWB_CORUN_LANES; lane++) begin
                feb_mon[lane].ap.connect(scoreboard.feb_imp);
                opq_mon[lane].ap.connect(scoreboard.opq_imp);
            end
            dma_mon.ap.connect(scoreboard.dma_imp);
        endfunction
    endclass

    class feb_swb_corun_base_test extends uvm_test;
        `uvm_component_utils(feb_swb_corun_base_test)

        feb_swb_corun_cfg cfg;
        feb_swb_corun_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            cfg = feb_swb_corun_cfg::type_id::create("cfg");
            cfg.apply_plusargs();
            uvm_config_db#(feb_swb_corun_cfg)::set(this, "env", "cfg", cfg);
            env = feb_swb_corun_env::type_id::create("env", this);
            `uvm_info("FEB_SWB_TEST",
                      $sformatf("build config %s", cfg.convert2string()),
                      UVM_LOW)
        endfunction

        virtual task configure_phase(uvm_phase phase);
            phase.raise_objection(this);
            cfg.csr_config_done = 1'b1;
            `uvm_info("FEB_SWB_CFG",
                      "CSR concept: configure FEB emulator DEBUG_LEVEL, SWB lane mask 0x3, OPQ/generic mode, DMA enable, and event/readout limits before run release",
                      UVM_LOW)
            phase.drop_objection(this);
        endtask

        virtual task main_phase(uvm_phase phase);
            phase.raise_objection(this);
            cfg.run_control_synced = 1'b1;
            `uvm_info("FEB_SWB_RUNCTL",
                      "run-control concept: release FEB and SWB from one synchronized simulation epoch; start scoreboarding only after CSR acceptance",
                      UVM_LOW)
            #2000ns;
            phase.drop_objection(this);
        endtask
    endclass
endpackage
