// latency_reporter.sv
// CSV writer for Python-side latency/CDF post-processing.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add closed-record and drop CSV writer for integration UVM.

package tb_int_latency_pkg;

    import uvm_pkg::*;
    import tb_int_record_pkg::*;
    `include "uvm_macros.svh"

    class latency_reporter extends uvm_object;
        `uvm_object_utils(latency_reporter)

        int closed_fd;
        int drops_fd;
        string output_dir;
        bit stable_only_export;

        function new(string name = "latency_reporter");
            super.new(name);
            closed_fd = 0;
            drops_fd  = 0;
            stable_only_export = 1'b0;
        endfunction

        function void open(string dir, bit enable_stable_only = 1'b0);
            output_dir = dir;
            stable_only_export = enable_stable_only;
            void'($system($sformatf("mkdir -p %s", output_dir)));
            closed_fd = $fopen({output_dir, "/closed_records.csv"}, "w");
            drops_fd  = $fopen({output_dir, "/drops.csv"}, "w");
            if (closed_fd == 0)
                `uvm_fatal("LAT_RPT", $sformatf("failed to open %s/closed_records.csv", output_dir))
            if (drops_fd == 0)
                `uvm_fatal("LAT_RPT", $sformatf("failed to open %s/drops.csv", output_dir))
            $fdisplay(closed_fd,
                      "hit_id,lane,channel,t_fine,t_coarse,root_hit_id,abs_ts_a,abs_ts_pre_rbcam,abs_ts_post_rbcam,abs_ts_feb_egress,run_origin");
            $fdisplay(drops_fd,
                      "hit_id,lane,key.channel,key.t_fine,t_coarse,last_seen_stage,last_seen_abs_ts,run_state_at_drop,run_origin");
        endfunction

        function void close();
            if (closed_fd != 0)
                $fclose(closed_fd);
            if (drops_fd != 0)
                $fclose(drops_fd);
            closed_fd = 0;
            drops_fd  = 0;
        endfunction

        function void write_closed(
            hit_record stage_a,
            hit_record pre_rbcam,
            hit_record post_rbcam,
            hit_record feb_egress
        );
            bit [63:0] root_id;

            if (stable_only_export && !(stage_a != null && stage_a.run_origin))
                return;
            if (closed_fd == 0 || stage_a == null)
                return;
            root_id = stage_a.root_hit_id_valid ? stage_a.root_hit_id : stage_a.hit_id;
            $fdisplay(closed_fd,
                      "%0d,%0d,%0d,%0d,%0d,%0d,%0t,%0t,%0t,%0t,%0d",
                      stage_a.hit_id,
                      stage_a.lane_id,
                      stage_a.key.channel,
                      stage_a.key.t_fine,
                      stage_a.t_coarse,
                      root_id,
                      stage_a.abs_ts,
                      (pre_rbcam == null) ? 0 : pre_rbcam.abs_ts,
                      (post_rbcam == null) ? 0 : post_rbcam.abs_ts,
                      (feb_egress == null) ? 0 : feb_egress.abs_ts,
                      stage_a.run_origin);
        endfunction

        function void write_drop(
            hit_record source,
            string last_seen_stage,
            time last_seen_abs_ts,
            string run_state_at_drop
        );
            if (stable_only_export && !(source != null && source.run_origin))
                return;
            if (drops_fd == 0 || source == null)
                return;
            $fdisplay(drops_fd,
                      "%0d,%0d,%0d,%0d,%0d,%s,%0t,%s,%0d",
                      source.hit_id,
                      source.lane_id,
                      source.key.channel,
                      source.key.t_fine,
                      source.t_coarse,
                      last_seen_stage,
                      last_seen_abs_ts,
                      run_state_at_drop,
                      source.run_origin);
        endfunction
    endclass

endpackage
