// mu3e_frame_format_pkg.sv
// Shared checker for Mu3e 32-bit data + 4-bit datak frames.

package tb_int_mu3e_frame_format_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam bit [7:0] MU3E_K285 = 8'hbc;
    localparam bit [7:0] MU3E_K284 = 8'h9c;
    localparam bit [7:0] MU3E_K237 = 8'hf7;
    localparam int unsigned MU3E_SUBHEADERS_PER_PACKET = 128;

    typedef enum int unsigned {
        MU3E_FRAME_WORD_NONE,
        MU3E_FRAME_WORD_IDLE,
        MU3E_FRAME_WORD_SOP,
        MU3E_FRAME_WORD_HEADER_TS_HI,
        MU3E_FRAME_WORD_HEADER_TS_LO,
        MU3E_FRAME_WORD_DEBUG_COUNTS,
        MU3E_FRAME_WORD_DEBUG_TIME,
        MU3E_FRAME_WORD_SUBHEADER,
        MU3E_FRAME_WORD_HIT,
        MU3E_FRAME_WORD_TRAILER,
        MU3E_FRAME_WORD_UNKNOWN
    } mu3e_frame_word_kind_e;

    typedef struct {
        bit                     accepted;
        bit                     idle;
        bit                     sop;
        bit                     eop;
        bit                     subheader;
        bit                     hit;
        bit                     frame_done;
        bit                     format_error;
        mu3e_frame_word_kind_e  kind;
        int unsigned            word_index;
        int unsigned            declared_subheaders;
        int unsigned            seen_subheaders;
        int unsigned            declared_hits;
        int unsigned            seen_hits;
        int unsigned            frame_accepted_words;
        int unsigned            expected_frame_words;
        int unsigned            subheader_declared_hit_sum;
        int unsigned            subheader_declared_hits;
        int unsigned            subheader_seen_hits;
        int unsigned            completed_frames;
        int unsigned            packet_count;
        int unsigned            expected_packet_count;
        int unsigned            expected_subheader_ts;
        int unsigned            header_page_base;
        int unsigned            expected_frame_page_base;
        bit                     packet_ts_valid;
        bit [47:0]              packet_ts;
        bit [31:0]              header_ts_high_word;
        bit [31:0]              header_ts_low_word;
        bit [7:0]               subheader_ts;
        bit [3:0]               hit_ts_nibble;
    } mu3e_frame_sample_t;

    function automatic bit mu3e_word_is_sop(bit [3:0] datak, bit [31:0] data);
        return datak[0] && (data[7:0] == MU3E_K285);
    endfunction

    function automatic bit mu3e_word_is_eop(bit [3:0] datak, bit [31:0] data);
        return datak[0] && (data[7:0] == MU3E_K284);
    endfunction

    function automatic bit mu3e_word_is_subheader(bit [3:0] datak, bit [31:0] data);
        return datak[0] && (data[7:0] == MU3E_K237);
    endfunction

    function automatic bit mu3e_word_is_idle_sop(bit [3:0] datak, bit [31:0] data);
        return mu3e_word_is_sop(datak, data) && (data[31:26] == 6'd0);
    endfunction

    function automatic bit [47:0] mu3e_true_packet_ts(
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

    function automatic bit [47:0] mu3e_frame_start_ts(
        input bit [31:0] header_ts_high_word,
        input bit [31:0] header_ts_low_word,
        input bit [7:0]  first_subheader_ts
    );
        return {
            header_ts_high_word,
            header_ts_low_word[31:28],
            first_subheader_ts,
            4'h0
        };
    endfunction

    class mu3e_frame_checker extends uvm_object;
        `uvm_object_utils(mu3e_frame_checker)

        string       stream_name;
        int unsigned lane_id;
        bit          strict_subheader_window;
        bit          strict_hit_count;
        bit          strict_cross_frame;
        int unsigned expected_subheaders;

        bit          in_frame;
        bit          header_ts_valid;
        bit          current_packet_count_valid;
        bit          current_subheader_valid;
        bit          first_subheader_seen;
        int unsigned word_index;
        int unsigned declared_subheaders;
        int unsigned seen_subheaders;
        int unsigned declared_hits;
        int unsigned seen_hits;
        int unsigned frame_accepted_words;
        int unsigned subheader_declared_hit_sum;
        int unsigned current_subheader_declared_hits;
        int unsigned current_subheader_seen_hits;
        int unsigned header_page_base;
        int unsigned completed_frames;
        bit [7:0]    last_subheader_ts;
        bit          last_subheader_valid;
        bit          last_frame_valid;
        bit [7:0]    last_frame_page_base;
        bit [15:0]   current_packet_count;
        bit [15:0]   last_frame_packet_count;
        bit [31:0]   header_ts_high_word;
        bit [31:0]   header_ts_low_word;
        bit [7:0]    current_subheader_ts;
        bit [47:0]   last_packet_ts;
        bit [47:0]   last_frame_start_ts;
        bit          last_packet_ts_valid;
        bit          last_frame_start_ts_valid;

        function new(string name = "mu3e_frame_checker");
            super.new(name);
            stream_name = name;
            lane_id = 0;
            strict_subheader_window = 1'b1;
            strict_hit_count = 1'b1;
            strict_cross_frame = 1'b1;
            expected_subheaders = MU3E_SUBHEADERS_PER_PACKET;
            reset_all_state();
        endfunction

        function void configure(string stream_name_i,
                                int unsigned lane_id_i,
                                int unsigned expected_subheaders_i = MU3E_SUBHEADERS_PER_PACKET);
            stream_name = stream_name_i;
            lane_id = lane_id_i;
            expected_subheaders = expected_subheaders_i;
        endfunction

        function void reset_frame_state();
            in_frame = 1'b0;
            header_ts_valid = 1'b0;
            current_packet_count_valid = 1'b0;
            current_subheader_valid = 1'b0;
            first_subheader_seen = 1'b0;
            word_index = 0;
            declared_subheaders = 0;
            seen_subheaders = 0;
            declared_hits = 0;
            seen_hits = 0;
            frame_accepted_words = 0;
            subheader_declared_hit_sum = 0;
            current_subheader_declared_hits = 0;
            current_subheader_seen_hits = 0;
            header_page_base = 0;
            current_packet_count = '0;
            last_subheader_ts = '0;
            last_subheader_valid = 1'b0;
            header_ts_high_word = '0;
            header_ts_low_word = '0;
            current_subheader_ts = '0;
            last_packet_ts = '0;
            last_packet_ts_valid = 1'b0;
        endfunction

        function void reset_all_state();
            reset_frame_state();
            completed_frames = 0;
            last_frame_valid = 1'b0;
            last_frame_page_base = '0;
            last_frame_packet_count = '0;
            last_frame_start_ts = '0;
            last_frame_start_ts_valid = 1'b0;
        endfunction

        function void init_sample(output mu3e_frame_sample_t sample);
            sample.accepted = 1'b0;
            sample.idle = 1'b0;
            sample.sop = 1'b0;
            sample.eop = 1'b0;
            sample.subheader = 1'b0;
            sample.hit = 1'b0;
            sample.frame_done = 1'b0;
            sample.format_error = 1'b0;
            sample.kind = MU3E_FRAME_WORD_NONE;
            sample.packet_ts_valid = 1'b0;
            sample.packet_ts = '0;
            sample.hit_ts_nibble = '0;
            sample.word_index = word_index;
            sample.declared_subheaders = declared_subheaders;
            sample.seen_subheaders = seen_subheaders;
            sample.declared_hits = declared_hits;
            sample.seen_hits = seen_hits;
            sample.frame_accepted_words = frame_accepted_words;
            sample.expected_frame_words = 5 + declared_subheaders + declared_hits + 1;
            sample.subheader_declared_hit_sum = subheader_declared_hit_sum;
            sample.subheader_declared_hits = current_subheader_declared_hits;
            sample.subheader_seen_hits = current_subheader_seen_hits;
            sample.completed_frames = completed_frames;
            sample.packet_count = int'(current_packet_count);
            sample.expected_packet_count = last_frame_valid
                ? int'((last_frame_packet_count + 16'd1) & 16'hffff)
                : int'(current_packet_count);
            sample.expected_subheader_ts = header_page_base + seen_subheaders;
            sample.header_page_base = header_page_base;
            sample.expected_frame_page_base = last_frame_valid
                ? int'((last_frame_page_base + (expected_subheaders & 8'hff)) & 8'hff)
                : header_page_base;
            sample.header_ts_high_word = header_ts_high_word;
            sample.header_ts_low_word = header_ts_low_word;
            sample.subheader_ts = current_subheader_ts;
        endfunction

        function void flag_error(string reason, inout mu3e_frame_sample_t sample);
            sample.format_error = 1'b1;
            uvm_report_error("MU3E_FRAME",
                             $sformatf("%s lane%0d %s word=%0d declared_subh=%0d seen_subh=%0d declared_hits=%0d seen_hits=%0d",
                                       stream_name,
                                       lane_id,
                                       reason,
                                       word_index,
                                       declared_subheaders,
                                       seen_subheaders,
                                       declared_hits,
                                       seen_hits));
        endfunction

        function void check_open_subheader(inout mu3e_frame_sample_t sample);
            if (!current_subheader_valid || !strict_hit_count)
                return;
            if (current_subheader_seen_hits != current_subheader_declared_hits) begin
                flag_error($sformatf("subheader_ts=0x%02h declared_hits=%0d seen_hits=%0d",
                                     current_subheader_ts,
                                     current_subheader_declared_hits,
                                     current_subheader_seen_hits),
                           sample);
            end
        endfunction

        function string subheader_sequence_reason(input bit [7:0] subheader_ts,
                                                  input bit [7:0] expected_ts);
            bit [7:0] delta;

            if (last_subheader_valid && (subheader_ts == last_subheader_ts))
                return "duplicate";
            if (last_subheader_valid) begin
                delta = subheader_ts - last_subheader_ts;
                if (delta != 8'd1) begin
                    if (delta[7])
                        return "backward";
                    return "gap";
                end
            end
            return "nonconsecutive";
        endfunction

        function void check_frame_close(inout mu3e_frame_sample_t sample);
            int unsigned expected_frame_words;
            bit [15:0] expected_packet_count;
            bit [7:0] expected_page_base;
            bit [7:0] current_page_base;
            bit [47:0] current_frame_start_ts;

            check_open_subheader(sample);
            expected_frame_words = 5 + declared_subheaders + declared_hits + 1;
            expected_packet_count = last_frame_packet_count + 16'd1;
            expected_page_base = last_frame_page_base + (expected_subheaders & 8'hff);
            current_page_base = header_page_base[7:0];
            current_frame_start_ts = mu3e_frame_start_ts(header_ts_high_word,
                                                         header_ts_low_word,
                                                         current_page_base);
            if (frame_accepted_words != expected_frame_words) begin
                flag_error($sformatf("broken packet length accepted_words=%0d expected_words=%0d header_words=5 declared_subheaders=%0d declared_hits=%0d trailer_words=1",
                                     frame_accepted_words,
                                     expected_frame_words,
                                     declared_subheaders,
                                     declared_hits),
                           sample);
            end
            if (declared_subheaders != expected_subheaders) begin
                flag_error($sformatf("declared_subheaders=%0d expected=%0d",
                                     declared_subheaders,
                                     expected_subheaders),
                           sample);
            end
            if (seen_subheaders != declared_subheaders) begin
                flag_error($sformatf("seen_subheaders=%0d declared_subheaders=%0d",
                                     seen_subheaders,
                                     declared_subheaders),
                           sample);
            end
            if (strict_hit_count && (seen_hits != declared_hits)) begin
                flag_error($sformatf("seen_hits=%0d declared_hits=%0d",
                                     seen_hits,
                                     declared_hits),
                           sample);
            end
            if (strict_hit_count && (subheader_declared_hit_sum != declared_hits)) begin
                flag_error($sformatf("subheader_declared_hit_sum=%0d declared_hits=%0d",
                                     subheader_declared_hit_sum,
                                     declared_hits),
                           sample);
            end
            if (!current_packet_count_valid) begin
                flag_error("missing packet count header word", sample);
            end
            if (strict_cross_frame && last_frame_valid && current_packet_count_valid
                && (current_packet_count != expected_packet_count)) begin
                flag_error($sformatf("packet count nonconsecutive got=0x%04h expected=0x%04h prev=0x%04h",
                                     current_packet_count,
                                     expected_packet_count,
                                     last_frame_packet_count),
                           sample);
            end
            if (strict_cross_frame && last_frame_valid && (current_page_base != expected_page_base)) begin
                flag_error($sformatf("frame page base nonconsecutive got=0x%02h expected=0x%02h prev=0x%02h",
                                     current_page_base,
                                     expected_page_base,
                                     last_frame_page_base),
                           sample);
            end
            if (strict_cross_frame && last_frame_start_ts_valid
                && (current_frame_start_ts < last_frame_start_ts)) begin
                flag_error($sformatf("frame header timestamp decreased got=0x%012h prev=0x%012h",
                                     current_frame_start_ts,
                                     last_frame_start_ts),
                           sample);
            end
            sample.frame_accepted_words = frame_accepted_words;
            sample.expected_frame_words = expected_frame_words;
            sample.subheader_declared_hit_sum = subheader_declared_hit_sum;
            sample.packet_count = int'(current_packet_count);
            sample.expected_packet_count = last_frame_valid ? int'(expected_packet_count) : int'(current_packet_count);
            sample.header_page_base = header_page_base;
            sample.expected_frame_page_base = last_frame_valid ? int'(expected_page_base) : header_page_base;
            completed_frames++;
            sample.completed_frames = completed_frames;
            last_frame_valid = 1'b1;
            last_frame_packet_count = current_packet_count;
            last_frame_page_base = current_page_base;
            last_frame_start_ts = current_frame_start_ts;
            last_frame_start_ts_valid = 1'b1;
        endfunction

        function void sample_beat(
            input bit valid,
            input bit ready,
            input bit sop,
            input bit eop,
            input bit [31:0] data,
            input bit [3:0] datak,
            output mu3e_frame_sample_t sample
        );
            bit sample_sop;
            bit sample_eop;
            bit sample_subheader;
            int unsigned expected_ts;
            bit [47:0] packet_ts;

            init_sample(sample);
            if (!(valid && ready))
                return;

            sample.accepted = 1'b1;
            sample.sop = sop;
            sample.eop = eop;
            sample_sop = mu3e_word_is_sop(datak, data);
            sample_eop = mu3e_word_is_eop(datak, data);
            sample_subheader = mu3e_word_is_subheader(datak, data);

            if (mu3e_word_is_idle_sop(datak, data)) begin
                sample.idle = 1'b1;
                sample.kind = MU3E_FRAME_WORD_IDLE;
                reset_frame_state();
                return;
            end

            if (sop && !sample_sop)
                flag_error($sformatf("SOP asserted without K28.5 data=0x%08h datak=0x%01h", data, datak), sample);
            if (eop && !sample_eop)
                flag_error($sformatf("EOP asserted without K28.4 data=0x%08h datak=0x%01h", data, datak), sample);

            if (sample_sop) begin
                if (in_frame) begin
                    flag_error($sformatf("SOP before previous frame EOP data=0x%08h datak=0x%01h",
                                         data,
                                         datak),
                               sample);
                end
                reset_frame_state();
                in_frame = 1'b1;
                frame_accepted_words = 1;
                sample.kind = MU3E_FRAME_WORD_SOP;
                sample.word_index = 0;
                sample.header_page_base = 0;
                sample.frame_accepted_words = frame_accepted_words;
                sample.expected_frame_words = 5 + declared_subheaders + declared_hits + 1;
                return;
            end

            if (!in_frame) begin
                sample.kind = MU3E_FRAME_WORD_UNKNOWN;
                if (!sample_eop)
                    flag_error($sformatf("data outside frame data=0x%08h datak=0x%01h", data, datak), sample);
                return;
            end

            word_index++;
            frame_accepted_words++;
            sample.word_index = word_index;
            sample.frame_accepted_words = frame_accepted_words;

            if (word_index == 1) begin
                header_ts_high_word = data;
                sample.header_ts_high_word = data;
                sample.kind = MU3E_FRAME_WORD_HEADER_TS_HI;
                return;
            end
            if (word_index == 2) begin
                header_ts_low_word = data;
                current_packet_count = data[15:0];
                current_packet_count_valid = 1'b1;
                header_ts_valid = 1'b1;
                sample.header_ts_low_word = data;
                sample.packet_count = int'(current_packet_count);
                sample.kind = MU3E_FRAME_WORD_HEADER_TS_LO;
                return;
            end
            if (word_index == 3) begin
                declared_subheaders = int'(data[30:16]);
                declared_hits = int'(data[15:0]);
                sample.declared_subheaders = declared_subheaders;
                sample.declared_hits = declared_hits;
                sample.kind = MU3E_FRAME_WORD_DEBUG_COUNTS;
                if (data[31])
                    flag_error($sformatf("debug count word bit31 set data=0x%08h", data), sample);
                return;
            end
            if (word_index == 4) begin
                sample.kind = MU3E_FRAME_WORD_DEBUG_TIME;
                return;
            end

            if (sample_subheader) begin
                check_open_subheader(sample);
                sample.kind = MU3E_FRAME_WORD_SUBHEADER;
                sample.subheader = 1'b1;
                sample.subheader_ts = data[31:24];
                current_subheader_ts = data[31:24];
                current_subheader_declared_hits = int'(data[15:8]);
                current_subheader_seen_hits = 0;
                current_subheader_valid = 1'b1;
                subheader_declared_hit_sum += current_subheader_declared_hits;
                if (!first_subheader_seen) begin
                    header_page_base = data[31] ? 128 : 0;
                    first_subheader_seen = 1'b1;
                    if (strict_subheader_window && (data[31:24] != header_page_base[7:0])) begin
                        flag_error($sformatf("first subheader=0x%02h expected page base=0x%02h",
                                             data[31:24],
                                             header_page_base[7:0]),
                                   sample);
                    end
                end
                expected_ts = header_page_base + seen_subheaders;
                sample.expected_subheader_ts = expected_ts;
                if (strict_subheader_window && (data[31:24] != expected_ts[7:0])) begin
                    flag_error($sformatf("subheader %s sequence got=0x%02h expected=0x%02h prev=%s",
                                         subheader_sequence_reason(data[31:24], expected_ts[7:0]),
                                         data[31:24],
                                         expected_ts[7:0],
                                         last_subheader_valid ? $sformatf("0x%02h", last_subheader_ts) : "none"),
                               sample);
                end
                last_subheader_ts = data[31:24];
                last_subheader_valid = 1'b1;
                seen_subheaders++;
                sample.header_page_base = header_page_base;
                sample.seen_subheaders = seen_subheaders;
                sample.subheader_declared_hit_sum = subheader_declared_hit_sum;
                sample.subheader_declared_hits = current_subheader_declared_hits;
                sample.subheader_seen_hits = current_subheader_seen_hits;
                return;
            end

            if (sample_eop) begin
                sample.kind = MU3E_FRAME_WORD_TRAILER;
                sample.frame_done = 1'b1;
                check_frame_close(sample);
                sample.declared_subheaders = declared_subheaders;
                sample.seen_subheaders = seen_subheaders;
                sample.declared_hits = declared_hits;
                sample.seen_hits = seen_hits;
                sample.frame_accepted_words = frame_accepted_words;
                sample.expected_frame_words = 5 + declared_subheaders + declared_hits + 1;
                sample.subheader_declared_hit_sum = subheader_declared_hit_sum;
                reset_frame_state();
                return;
            end

            if (header_ts_valid && current_subheader_valid && (datak == 4'h0)) begin
                sample.kind = MU3E_FRAME_WORD_HIT;
                sample.hit = 1'b1;
                if (strict_hit_count && (current_subheader_seen_hits >= current_subheader_declared_hits)) begin
                    flag_error($sformatf("subheader_ts=0x%02h hit overrun declared_hits=%0d next_hit_index=%0d",
                                         current_subheader_ts,
                                         current_subheader_declared_hits,
                                         current_subheader_seen_hits + 1),
                               sample);
                end
                if (strict_hit_count && (seen_hits >= declared_hits)) begin
                    flag_error($sformatf("frame hit overrun declared_hits=%0d next_hit_index=%0d",
                                         declared_hits,
                                         seen_hits + 1),
                               sample);
                end
                current_subheader_seen_hits++;
                seen_hits++;
                packet_ts = mu3e_true_packet_ts(header_ts_high_word,
                                                header_ts_low_word,
                                                current_subheader_ts,
                                                data);
                sample.packet_ts_valid = 1'b1;
                sample.packet_ts = packet_ts;
                sample.hit_ts_nibble = data[31:28];
                sample.header_ts_high_word = header_ts_high_word;
                sample.header_ts_low_word = header_ts_low_word;
                sample.subheader_ts = current_subheader_ts;
                sample.declared_subheaders = declared_subheaders;
                sample.seen_subheaders = seen_subheaders;
                sample.declared_hits = declared_hits;
                sample.seen_hits = seen_hits;
                sample.frame_accepted_words = frame_accepted_words;
                sample.expected_frame_words = 5 + declared_subheaders + declared_hits + 1;
                sample.subheader_declared_hit_sum = subheader_declared_hit_sum;
                sample.subheader_declared_hits = current_subheader_declared_hits;
                sample.subheader_seen_hits = current_subheader_seen_hits;
                if (last_packet_ts_valid && (packet_ts < last_packet_ts)) begin
                    flag_error($sformatf("packet timestamp decreased prev=0x%012h now=0x%012h",
                                         last_packet_ts,
                                         packet_ts),
                               sample);
                end
                last_packet_ts = packet_ts;
                last_packet_ts_valid = 1'b1;
                return;
            end

            sample.kind = MU3E_FRAME_WORD_UNKNOWN;
            flag_error($sformatf("unknown in-frame word data=0x%08h datak=0x%01h", data, datak), sample);
        endfunction
    endclass

endpackage
