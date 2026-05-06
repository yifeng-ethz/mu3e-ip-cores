// hit_record.sv
// Canonical hit observation transaction for tb_int integration stages.
// Author: Yifeng Wang
// Version : 26.2.1
// Date    : 20260504
// Change  : Track source-supplied debug lineage independently from inferred IDs.

package tb_int_record_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        OBS_STAGE_A,
        OBS_STAGE_PRE_RBCAM,
        OBS_STAGE_POST_RBCAM,
        OBS_STAGE_FEB_EGRESS,
        OBS_HISTOGRAM_CSR
    } observation_point_e;

    function automatic string observation_point_name(observation_point_e point);
        case (point)
            OBS_STAGE_A:           return "stage_a";
            OBS_STAGE_PRE_RBCAM:   return "pre_rbcam";
            OBS_STAGE_POST_RBCAM:  return "post_rbcam";
            OBS_STAGE_FEB_EGRESS:  return "feb_egress";
            OBS_HISTOGRAM_CSR:     return "histogram_csr";
            default:               return "unknown";
        endcase
    endfunction

    class hit_record extends uvm_sequence_item;
        `uvm_object_utils(hit_record)

        bit [63:0]          hit_id;
        hit_key_t           key;
        int unsigned        lane_id;
        int unsigned        seq_in_bucket;
        time                abs_ts;
        int unsigned        feb_id;
        int unsigned        datapath_id;
        bit [63:0]          payload;
        bit                 run_origin;
        observation_point_e observation_point;
        bit                 root_hit_id_valid;
        bit [63:0]          root_hit_id;
        bit [14:0]          t_coarse;
        bit                 monitor_debug_valid;
        bit [63:0]          monitor_debug_id;
        int unsigned        monitor_debug_level;

        function new(string name = "hit_record");
            super.new(name);
        endfunction

        function bit [9:0] key_bits();
            return hit_key_pack(key);
        endfunction

        function void set_from_hit0(
            bit [63:0]          new_hit_id,
            int unsigned        new_lane_id,
            bit [44:0]          hit0_payload,
            time                new_abs_ts,
            observation_point_e new_point
        );
            hit_id            = new_hit_id;
            lane_id           = new_lane_id;
            abs_ts            = new_abs_ts;
            payload           = {19'd0, hit0_payload};
            key               = extract_key_hit0(hit0_payload);
            t_coarse          = extract_t_coarse_hit0(hit0_payload);
            observation_point = new_point;
        endfunction

        function void copy_lineage_from(hit_record src);
            if (src == null)
                return;
            run_origin = src.run_origin;
            if (!src.root_hit_id_valid)
                return;
            root_hit_id_valid = 1'b1;
            root_hit_id       = src.root_hit_id;
        endfunction

        function string describe();
            string id_desc;

            if (root_hit_id_valid)
                id_desc = $sformatf("0x%016h", root_hit_id);
            else
                id_desc = "?";
            return $sformatf("{point=%s hit_id=0x%016h lane=%0d ch=%0d tfine=%0d seq=%0d t=%0t root=%s dbg_valid=%0b dbg_id=0x%016h dbg_level=%0d run_origin=%0b payload=0x%016h}",
                             observation_point_name(observation_point),
                             hit_id, lane_id, key.channel, key.t_fine,
                             seq_in_bucket, abs_ts, id_desc,
                             monitor_debug_valid, monitor_debug_id,
                             monitor_debug_level,
                             run_origin, payload);
        endfunction

        virtual function void do_copy(uvm_object rhs);
            hit_record rhs_record;

            if (!$cast(rhs_record, rhs))
                `uvm_fatal("HIT_RECORD", "do_copy rhs is not a hit_record")
            super.do_copy(rhs);
            hit_id            = rhs_record.hit_id;
            key               = rhs_record.key;
            lane_id           = rhs_record.lane_id;
            seq_in_bucket     = rhs_record.seq_in_bucket;
            abs_ts            = rhs_record.abs_ts;
            feb_id            = rhs_record.feb_id;
            datapath_id       = rhs_record.datapath_id;
            payload           = rhs_record.payload;
            run_origin        = rhs_record.run_origin;
            observation_point = rhs_record.observation_point;
            root_hit_id_valid = rhs_record.root_hit_id_valid;
            root_hit_id       = rhs_record.root_hit_id;
            t_coarse          = rhs_record.t_coarse;
            monitor_debug_valid = rhs_record.monitor_debug_valid;
            monitor_debug_id    = rhs_record.monitor_debug_id;
            monitor_debug_level = rhs_record.monitor_debug_level;
        endfunction
    endclass

endpackage
