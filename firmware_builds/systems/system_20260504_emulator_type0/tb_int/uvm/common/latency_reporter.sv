// latency_reporter.sv
// CSV writer for Python-side latency/CDF post-processing.
// Author: Yifeng Wang
// Version : 26.2.2
// Date    : 20260507
// Change  : Export post-rbCAM stage records independent of FEB egress closure.

package tb_int_latency_pkg;

    import uvm_pkg::*;
    import tb_int_record_pkg::*;
    `include "uvm_macros.svh"

    class latency_reporter extends uvm_object;
        `uvm_object_utils(latency_reporter)

        int closed_fd;
        int pre_rbcam_fd;
        int post_rbcam_fd;
        int drops_fd;
        int counter_fd;
        string output_dir;
        bit stable_only_export;

        function new(string name = "latency_reporter");
            super.new(name);
            closed_fd = 0;
            pre_rbcam_fd = 0;
            post_rbcam_fd = 0;
            drops_fd  = 0;
            counter_fd = 0;
            stable_only_export = 1'b0;
        endfunction

        function void open(string dir, bit enable_stable_only = 1'b0);
            output_dir = dir;
            stable_only_export = enable_stable_only;
            void'($system($sformatf("mkdir -p %s", output_dir)));
            closed_fd = $fopen({output_dir, "/closed_records.csv"}, "w");
            pre_rbcam_fd = $fopen({output_dir, "/pre_rbcam_records.csv"}, "w");
            post_rbcam_fd = $fopen({output_dir, "/post_rbcam_records.csv"}, "w");
            drops_fd  = $fopen({output_dir, "/drops.csv"}, "w");
            counter_fd = $fopen({output_dir, "/counter_agreement.csv"}, "w");
            if (closed_fd == 0)
                `uvm_fatal("LAT_RPT", $sformatf("failed to open %s/closed_records.csv", output_dir))
            if (pre_rbcam_fd == 0)
                `uvm_fatal("LAT_RPT", $sformatf("failed to open %s/pre_rbcam_records.csv", output_dir))
            if (post_rbcam_fd == 0)
                `uvm_fatal("LAT_RPT", $sformatf("failed to open %s/post_rbcam_records.csv", output_dir))
            if (drops_fd == 0)
                `uvm_fatal("LAT_RPT", $sformatf("failed to open %s/drops.csv", output_dir))
            if (counter_fd == 0)
                `uvm_fatal("LAT_RPT", $sformatf("failed to open %s/counter_agreement.csv", output_dir))
            $fdisplay(closed_fd,
                      "hit_id,lane,channel,t_fine,t_coarse,root_hit_id,abs_ts_a,abs_ts_pre_rbcam,abs_ts_post_rbcam,abs_ts_feb_egress,run_origin");
            $fdisplay(pre_rbcam_fd,
                      "hit_id,lane,channel,t_fine,t_coarse,root_hit_id,abs_ts_a,abs_ts_pre_rbcam,run_origin");
            $fdisplay(post_rbcam_fd,
                      "hit_id,lane,channel,t_fine,t_coarse,root_hit_id,abs_ts_a,abs_ts_pre_rbcam,abs_ts_post_rbcam,run_origin");
            $fdisplay(drops_fd,
                      "hit_id,lane,key.channel,key.t_fine,t_coarse,last_seen_stage,last_seen_abs_ts,run_state_at_drop,run_origin");
            $fdisplay(counter_fd,
                      "phase,counter,scoreboard_count,counter_count,available,agree");
        endfunction

        function void close();
            if (closed_fd != 0)
                $fclose(closed_fd);
            if (pre_rbcam_fd != 0)
                $fclose(pre_rbcam_fd);
            if (post_rbcam_fd != 0)
                $fclose(post_rbcam_fd);
            if (drops_fd != 0)
                $fclose(drops_fd);
            if (counter_fd != 0)
                $fclose(counter_fd);
            closed_fd = 0;
            pre_rbcam_fd = 0;
            post_rbcam_fd = 0;
            drops_fd  = 0;
            counter_fd = 0;
        endfunction

        function void write_pre_rbcam_pair(
            hit_record stage_a,
            hit_record pre_rbcam
        );
            bit [63:0] root_id;

            if (stable_only_export && !(stage_a != null && stage_a.run_origin))
                return;
            if (pre_rbcam_fd == 0 || stage_a == null || pre_rbcam == null)
                return;
            root_id = stage_a.root_hit_id_valid ? stage_a.root_hit_id : stage_a.hit_id;
            $fdisplay(pre_rbcam_fd,
                      "%0d,%0d,%0d,%0d,%0d,%0d,%0t,%0t,%0d",
                      stage_a.hit_id,
                      stage_a.lane_id,
                      stage_a.key.channel,
                      stage_a.key.t_fine,
                      stage_a.t_coarse,
                      root_id,
                      stage_a.abs_ts,
                      pre_rbcam.abs_ts,
                      stage_a.run_origin);
        endfunction

        function void write_post_rbcam_pair(
            hit_record stage_a,
            hit_record pre_rbcam,
            hit_record post_rbcam
        );
            bit [63:0] root_id;

            if (stable_only_export && !(stage_a != null && stage_a.run_origin))
                return;
            if (post_rbcam_fd == 0 || stage_a == null ||
                pre_rbcam == null || post_rbcam == null)
                return;
            root_id = stage_a.root_hit_id_valid ? stage_a.root_hit_id : stage_a.hit_id;
            $fdisplay(post_rbcam_fd,
                      "%0d,%0d,%0d,%0d,%0d,%0d,%0t,%0t,%0t,%0d",
                      stage_a.hit_id,
                      stage_a.lane_id,
                      stage_a.key.channel,
                      stage_a.key.t_fine,
                      stage_a.t_coarse,
                      root_id,
                      stage_a.abs_ts,
                      pre_rbcam.abs_ts,
                      post_rbcam.abs_ts,
                      stage_a.run_origin);
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

        function void write_counter_agreement(
            string phase_name,
            string counter_name,
            longint unsigned scoreboard_count,
            longint unsigned counter_count,
            bit available,
            bit agree
        );
            if (counter_fd == 0)
                return;
            $fdisplay(counter_fd,
                      "%s,%s,%0d,%0d,%0d,%0d",
                      phase_name,
                      counter_name,
                      scoreboard_count,
                      counter_count,
                      available,
                      agree);
        endfunction
    endclass

endpackage
