// hit_key_pkg.sv
// Common hit identity helpers for system_20260504_emulator_type0/tb_int.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable per-bucket hit key package for integration UVM.

package tb_int_hit_key_pkg;

    // -----------------------------------------------------------------------
    // Content-aware hit identity tuple.
    //
    // Identity bits that survive the entire datapath unchanged:
    //   - channel : 5-bit SiPM channel 0..31
    //   - t_fine  : 5-bit 50ps fine time (T_Fine)
    //
    // Everything else moves: T_CC is LUT-decoded and gts-folded in
    // mts_processor between stages A and B, and the hit_type2 layout drops
    // the error / badhit bits entirely. For per-lane FIFO matching against a
    // common key this 10-bit tuple is adequate     each of 1024 buckets holds
    // ~6 hits per lane in a 200k-cycle run, and order within a bucket is
    // preserved end-to-end because the datapath is point-to-point FIFO.
    //
    // The source lane is recovered from the 4-bit asic field at stages
    // B..E. Lane identification at stage A comes from (feb_id, datapath_id)
    // in the stage_a_if tap. Both numbering systems are aligned via
    // datapath_stub's LANE_ASIC_ID = FEB_ID*2 + DATAPATH_ID tie-off.
    // -----------------------------------------------------------------------
    typedef struct packed {
        bit [4:0] channel;
        bit [4:0] t_fine;
    } hit_key_t;

    function automatic bit [9:0] hit_key_pack(hit_key_t key);
        return {key.channel, key.t_fine};
    endfunction

    function automatic hit_key_t hit_key_unpack(bit [9:0] packed_key);
        hit_key_t key;

        key.channel = packed_key[9:5];
        key.t_fine  = packed_key[4:0];
        return key;
    endfunction

    // Extract the identity tuple from a 45-bit hit_type0 word.
    // Layout (frame_rcv_ip aso_hit_type0_data):
    //   [44:41]=asic, [40:36]=channel, [35:21]=t_cc, [20:16]=t_fine,
    //   [15:1]=e_cc, [0]=e_flag
    function automatic hit_key_t extract_key_hit0(bit [44:0] data);
        hit_key_t key;

        key.channel = data[40:36];
        key.t_fine  = data[20:16];
        return key;
    endfunction

    function automatic int unsigned extract_lane_hit0(bit [44:0] data);
        return int'(data[44:41]);
    endfunction

    // Extract the identity tuple from a 36-bit hit_type2 body word.
    // Layout (rb_cam aso_hit_type2_data for a hit beat, byte_is_k == "0000"):
    //   [35:32]=0000, [31:28]=ts[3:0], [27:26]="00", [25:22]=asic,
    //   [21:17]=channel, [16:14]=tcc_1n6, [13:9]=t_fine, [8:0]=et_1n6
    function automatic hit_key_t extract_key_hit2(bit [35:0] data);
        hit_key_t key;

        key.channel = data[21:17];
        key.t_fine  = data[13:9];
        return key;
    endfunction

    function automatic int unsigned extract_lane_hit2(bit [35:0] data);
        return int'(data[25:22]);
    endfunction

    function automatic bit [44:0] build_hit0_payload(
        bit [3:0]  asic,

        bit [4:0]  channel,

        bit [14:0] t_coarse,

        bit [4:0]  t_fine,

        bit [14:0] e_coarse,

        bit        e_flag
    );
        return {asic, channel, t_coarse, t_fine, e_coarse, e_flag};
    endfunction

    function automatic bit [14:0] extract_t_coarse_hit0(bit [44:0] data);
        return data[35:21];
    endfunction

endpackage
