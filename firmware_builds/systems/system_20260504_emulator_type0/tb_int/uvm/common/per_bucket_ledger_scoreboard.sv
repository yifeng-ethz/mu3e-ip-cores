// per_bucket_ledger_scoreboard.sv
// Per-lane, per-key FIFO-ledger scoreboard for focus-build tb_int.
// Author: Yifeng Wang
// Version : 26.2.1
// Date    : 20260506
// Change  : Collapse physical pre-rbCAM broadcast fanout to logical hits.

package tb_int_scoreboard_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_record_pkg::*;
    import tb_int_latency_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_stage_a)
    `uvm_analysis_imp_decl(_pre_rbcam)
    `uvm_analysis_imp_decl(_post_rbcam)
    `uvm_analysis_imp_decl(_feb_egress)
    `uvm_analysis_imp_decl(_histogram)

    localparam int unsigned NUM_LANES = 8;

    typedef hit_record obs_q_t [$];

    class per_bucket_ledger_scoreboard extends uvm_component;
        `uvm_component_utils(per_bucket_ledger_scoreboard)

        uvm_analysis_imp_stage_a#(hit_record, per_bucket_ledger_scoreboard) stage_a_imp;
        uvm_analysis_imp_pre_rbcam#(hit_record, per_bucket_ledger_scoreboard) pre_rbcam_imp;
        uvm_analysis_imp_post_rbcam#(hit_record, per_bucket_ledger_scoreboard) post_rbcam_imp;
        uvm_analysis_imp_feb_egress#(hit_record, per_bucket_ledger_scoreboard) feb_egress_imp;
        uvm_analysis_imp_histogram#(hit_record, per_bucket_ledger_scoreboard) histogram_imp;

        obs_q_t stage_a_ledger[NUM_LANES][bit [9:0]];
        obs_q_t stage_pre_rbcam_ledger[NUM_LANES][bit [9:0]];
        obs_q_t stage_post_rbcam_ledger[NUM_LANES][bit [9:0]];
        obs_q_t stage_feb_egress_ledger[NUM_LANES][bit [9:0]];

        int unsigned total_stage_a;
        int unsigned total_stage_a_stable;
        int unsigned total_pre_rbcam;
        int unsigned total_pre_rbcam_fanout_duplicates;
        int unsigned total_post_rbcam;
        int unsigned total_feb_egress;
        int unsigned total_matched_a_pre;
        int unsigned total_missing_pre;
        int unsigned total_ghost_pre;
        int unsigned total_matched_pre_post;
        int unsigned total_missing_post;
        int unsigned total_ghost_post;
        int unsigned total_matched_post_feb;
        int unsigned total_missing_feb;
        int unsigned total_ghost_feb;
        int unsigned total_closed_records;
        int unsigned total_closed_records_stable;
        int unsigned stable_missing_pre;
        int unsigned stable_missing_post;
        int unsigned stable_missing_feb;
        int unsigned expected_closed_records;
        int unsigned min_closed_pct;
        int unsigned dbg_stage_a_logged;
        int unsigned dbg_pre_rbcam_logged;
        bit          stable_only_export;
        bit          require_zero_residual;
        bit          exported_records;
        string       output_dir;
        latency_reporter reporter;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            string plusarg_dir;
            int    plusarg_expected;
            int    plusarg_require_zero;
            int    plusarg_min_closed_pct;
            int    plusarg_stable_only_export;

            super.build_phase(phase);
            stage_a_imp    = new("stage_a_imp", this);
            pre_rbcam_imp  = new("pre_rbcam_imp", this);
            post_rbcam_imp = new("post_rbcam_imp", this);
            feb_egress_imp = new("feb_egress_imp", this);
            histogram_imp  = new("histogram_imp", this);
            reporter       = latency_reporter::type_id::create("reporter");
            require_zero_residual = 1'b1;
            min_closed_pct        = 0;
            dbg_stage_a_logged    = 0;
            dbg_pre_rbcam_logged  = 0;
            exported_records      = 1'b0;
            output_dir = "sim/tb_int";
            if ($value$plusargs("TB_INT_SIM_DIR=%s", plusarg_dir))
                output_dir = plusarg_dir;
            expected_closed_records = 0;
            if ($value$plusargs("TB_INT_EXPECTED_HITS=%d", plusarg_expected))
                expected_closed_records = plusarg_expected;
            if ($value$plusargs("TB_INT_REQUIRE_ZERO_RESIDUAL=%d", plusarg_require_zero))
                require_zero_residual = (plusarg_require_zero != 0);
            if ($value$plusargs("TB_INT_MIN_CLOSED_PCT=%d", plusarg_min_closed_pct))
                min_closed_pct = plusarg_min_closed_pct;
            stable_only_export = 1'b0;
            if ($value$plusargs("TB_INT_STABLE_ONLY_EXPORT=%d", plusarg_stable_only_export))
                stable_only_export = (plusarg_stable_only_export != 0);
        endfunction

        virtual function void start_of_simulation_phase(uvm_phase phase);
            super.start_of_simulation_phase(phase);
            reporter.open(output_dir, stable_only_export);
        endfunction

        function automatic void copy_root_hit_id(hit_record dst, hit_record src);
            if (dst == null || src == null)
                return;
            dst.run_origin = src.run_origin;
            if (!src.root_hit_id_valid)
                return;
            dst.root_hit_id_valid = 1'b1;
            dst.root_hit_id       = src.root_hit_id;
        endfunction

        function automatic hit_record clone_observation(hit_record item);
            hit_record obs;

            if (item == null)
                return null;
            obs = hit_record::type_id::create("ledger_obs");
            obs.copy(item);
            return obs;
        endfunction

        function automatic void push_obs(ref obs_q_t ledger[bit [9:0]],
                                         hit_record item);
            bit [9:0]  key_bits;
            hit_record obs;

            if (item == null)
                return;
            key_bits = item.key_bits();
            obs = clone_observation(item);
            obs.seq_in_bucket = ledger.exists(key_bits) ? ledger[key_bits].size() : 0;
            ledger[key_bits].push_back(obs);
        endfunction

        function automatic bit is_same_cycle_duplicate(
            ref obs_q_t ledger[bit [9:0]],
            hit_record item
        );
            bit [9:0]  key_bits;
            hit_record last_obs;

            if (item == null)
                return 1'b0;
            key_bits = item.key_bits();
            if (!ledger.exists(key_bits) || ledger[key_bits].size() == 0)
                return 1'b0;
            last_obs = ledger[key_bits][ledger[key_bits].size() - 1];
            return (last_obs != null &&
                    last_obs.abs_ts == item.abs_ts &&
                    last_obs.payload == item.payload &&
                    last_obs.lane_id == item.lane_id);
        endfunction

        virtual function void write_stage_a(hit_record item);
            int unsigned lane_idx;

            if (item == null)
                return;
            lane_idx = item.lane_id;
            if (lane_idx >= NUM_LANES)
                return;
            item.observation_point = OBS_STAGE_A;
            item.root_hit_id_valid = 1'b1;
            item.root_hit_id       = item.hit_id;
            push_obs(stage_a_ledger[lane_idx], item);
            total_stage_a++;
            if (item.run_origin)
                total_stage_a_stable++;
            if (dbg_stage_a_logged < 16) begin
                `uvm_info("TB_INT_OBS",
                          $sformatf("stage_a[%0d] %s",
                                    dbg_stage_a_logged,
                                    item.describe()),
                          UVM_LOW)
                dbg_stage_a_logged++;
            end
        endfunction

        virtual function void write_pre_rbcam(hit_record item);
            int unsigned lane_idx;
            bit [9:0]    key_bits;
            int unsigned match_seq;

            if (item == null)
                return;
            lane_idx = item.lane_id;
            if (lane_idx >= NUM_LANES)
                return;
            item.observation_point = OBS_STAGE_PRE_RBCAM;
            key_bits = item.key_bits();
            if (is_same_cycle_duplicate(stage_pre_rbcam_ledger[lane_idx], item)) begin
                total_pre_rbcam_fanout_duplicates++;
                return;
            end
            match_seq = stage_pre_rbcam_ledger[lane_idx].exists(key_bits)
                        ? stage_pre_rbcam_ledger[lane_idx][key_bits].size() : 0;
            if (stage_a_ledger[lane_idx].exists(key_bits) &&
                stage_a_ledger[lane_idx][key_bits].size() > match_seq)
                copy_root_hit_id(item, stage_a_ledger[lane_idx][key_bits][match_seq]);
            push_obs(stage_pre_rbcam_ledger[lane_idx], item);
            total_pre_rbcam++;
            if (dbg_pre_rbcam_logged < 16) begin
                `uvm_info("TB_INT_OBS",
                          $sformatf("pre_rbcam[%0d] match_seq=%0d stage_a_bucket=%0d %s",
                                    dbg_pre_rbcam_logged,
                                    match_seq,
                                    stage_a_ledger[lane_idx].exists(key_bits)
                                        ? stage_a_ledger[lane_idx][key_bits].size() : 0,
                                    item.describe()),
                          UVM_LOW)
                dbg_pre_rbcam_logged++;
            end
        endfunction

        virtual function void write_post_rbcam(hit_record item);
            int unsigned lane_idx;
            bit [9:0]    key_bits;
            int unsigned match_seq;

            if (item == null)
                return;
            lane_idx = item.lane_id;
            if (lane_idx >= NUM_LANES)
                return;
            item.observation_point = OBS_STAGE_POST_RBCAM;
            key_bits = item.key_bits();
            match_seq = stage_post_rbcam_ledger[lane_idx].exists(key_bits)
                        ? stage_post_rbcam_ledger[lane_idx][key_bits].size() : 0;
            if (stage_pre_rbcam_ledger[lane_idx].exists(key_bits) &&
                stage_pre_rbcam_ledger[lane_idx][key_bits].size() > match_seq)
                copy_root_hit_id(item, stage_pre_rbcam_ledger[lane_idx][key_bits][match_seq]);
            push_obs(stage_post_rbcam_ledger[lane_idx], item);
            total_post_rbcam++;
        endfunction

        virtual function void write_feb_egress(hit_record item);
            int unsigned lane_idx;
            bit [9:0]    key_bits;
            int unsigned match_seq;

            if (item == null)
                return;
            lane_idx = item.lane_id;
            if (lane_idx >= NUM_LANES)
                return;
            item.observation_point = OBS_STAGE_FEB_EGRESS;
            key_bits = item.key_bits();
            match_seq = stage_feb_egress_ledger[lane_idx].exists(key_bits)
                        ? stage_feb_egress_ledger[lane_idx][key_bits].size() : 0;
            if (stage_post_rbcam_ledger[lane_idx].exists(key_bits) &&
                stage_post_rbcam_ledger[lane_idx][key_bits].size() > match_seq)
                copy_root_hit_id(item, stage_post_rbcam_ledger[lane_idx][key_bits][match_seq]);
            push_obs(stage_feb_egress_ledger[lane_idx], item);
            total_feb_egress++;
        endfunction

        virtual function void write_histogram(hit_record item);
            if (item != null)
                `uvm_info("TB_INT_HIST", item.describe(), UVM_HIGH)
        endfunction

        function automatic void reconcile_boundary(
            ref obs_q_t up_ledger[bit [9:0]],

            ref obs_q_t dn_ledger[bit [9:0]],
            output int unsigned matched,
            output int unsigned missing,
            output int unsigned ghost
        );
            bit [9:0] key_bits;
            bit       ok;

            matched = 0;
            missing = 0;
            ghost   = 0;

            if (up_ledger.first(key_bits)) begin
                ok = 1'b1;
                while (ok) begin
                    int up_n;
                    int dn_n;

                    up_n = up_ledger[key_bits].size();
                    dn_n = dn_ledger.exists(key_bits) ? dn_ledger[key_bits].size() : 0;
                    matched += (up_n < dn_n) ? up_n : dn_n;
                    if (up_n > dn_n)
                        missing += (up_n - dn_n);
                    ok = up_ledger.next(key_bits);
                end
            end

            if (dn_ledger.first(key_bits)) begin
                ok = 1'b1;
                while (ok) begin
                    int up_n;
                    int dn_n;

                    dn_n = dn_ledger[key_bits].size();
                    up_n = up_ledger.exists(key_bits) ? up_ledger[key_bits].size() : 0;
                    if (dn_n > up_n)
                        ghost += (dn_n - up_n);
                    ok = dn_ledger.next(key_bits);
                end
            end
        endfunction

        function automatic int unsigned count_stable_missing(
            ref obs_q_t up_ledger[bit [9:0]],
            ref obs_q_t dn_ledger[bit [9:0]]
        );
            bit [9:0]    key_bits;
            bit          ok;
            int unsigned stable_missing;

            stable_missing = 0;
            if (up_ledger.first(key_bits)) begin
                ok = 1'b1;
                while (ok) begin
                    int up_n;
                    int dn_n;

                    up_n = up_ledger[key_bits].size();
                    dn_n = dn_ledger.exists(key_bits) ? dn_ledger[key_bits].size() : 0;
                    for (int obs_idx = dn_n; obs_idx < up_n; obs_idx++) begin
                        if (up_ledger[key_bits][obs_idx].run_origin)
                            stable_missing++;
                    end
                    ok = up_ledger.next(key_bits);
                end
            end
            return stable_missing;
        endfunction

        function automatic void export_closed_and_drops(bit do_export);
            for (int lane_idx = 0; lane_idx < NUM_LANES; lane_idx++) begin
                bit [9:0] key_bits;
                bit       ok;

                if (stage_a_ledger[lane_idx].first(key_bits)) begin
                    ok = 1'b1;
                    while (ok) begin
                        int a_n;
                        int pre_n;
                        int post_n;
                        int feb_n;
                        int matched_pre;
                        int matched_all;

                        a_n = stage_a_ledger[lane_idx][key_bits].size();
                        pre_n = stage_pre_rbcam_ledger[lane_idx].exists(key_bits)
                                ? stage_pre_rbcam_ledger[lane_idx][key_bits].size() : 0;
                        post_n = stage_post_rbcam_ledger[lane_idx].exists(key_bits)
                                 ? stage_post_rbcam_ledger[lane_idx][key_bits].size() : 0;
                        feb_n = stage_feb_egress_ledger[lane_idx].exists(key_bits)
                                ? stage_feb_egress_ledger[lane_idx][key_bits].size() : 0;
                        matched_all = a_n;
                        if (pre_n < matched_all)
                            matched_all = pre_n;
                        if (post_n < matched_all)
                            matched_all = post_n;
                        if (feb_n < matched_all)
                            matched_all = feb_n;

                        matched_pre = (a_n < pre_n) ? a_n : pre_n;
                        for (int obs_idx = 0; obs_idx < matched_pre; obs_idx++) begin
                            if (do_export)
                                reporter.write_pre_rbcam_pair(stage_a_ledger[lane_idx][key_bits][obs_idx],
                                                              stage_pre_rbcam_ledger[lane_idx][key_bits][obs_idx]);
                        end

                        for (int obs_idx = 0; obs_idx < matched_all; obs_idx++) begin
                            if (do_export &&
                                (!stable_only_export || stage_a_ledger[lane_idx][key_bits][obs_idx].run_origin)) begin
                                reporter.write_closed(stage_a_ledger[lane_idx][key_bits][obs_idx],
                                                      stage_pre_rbcam_ledger[lane_idx][key_bits][obs_idx],
                                                      stage_post_rbcam_ledger[lane_idx][key_bits][obs_idx],
                                                      stage_feb_egress_ledger[lane_idx][key_bits][obs_idx]);
                            end
                            total_closed_records++;
                            if (stage_a_ledger[lane_idx][key_bits][obs_idx].run_origin)
                                total_closed_records_stable++;
                        end

                        for (int obs_idx = matched_all; obs_idx < a_n; obs_idx++) begin
                            string stage_name;
                            time   last_seen_ts;
                            bit is_stable;

                            stage_name   = "stage_a";
                            last_seen_ts = stage_a_ledger[lane_idx][key_bits][obs_idx].abs_ts;
                            if (obs_idx < pre_n) begin
                                stage_name   = "pre_rbcam";
                                last_seen_ts = stage_pre_rbcam_ledger[lane_idx][key_bits][obs_idx].abs_ts;
                            end
                            if (obs_idx < post_n) begin
                                stage_name   = "post_rbcam";
                                last_seen_ts = stage_post_rbcam_ledger[lane_idx][key_bits][obs_idx].abs_ts;
                            end
                            is_stable = stage_a_ledger[lane_idx][key_bits][obs_idx].run_origin;
                            if (do_export &&
                                (!stable_only_export || is_stable)) begin
                                reporter.write_drop(stage_a_ledger[lane_idx][key_bits][obs_idx],
                                                    stage_name,
                                                    last_seen_ts,
                                                    "unknown");
                            end
                        end
                        ok = stage_a_ledger[lane_idx].next(key_bits);
                    end
                end
            end
        endfunction

        virtual function void reconcile(string phase_name = "unknown");
            bit export_now;

            total_matched_a_pre   = 0;
            total_missing_pre     = 0;
            total_ghost_pre       = 0;
            total_matched_pre_post = 0;
            total_missing_post    = 0;
            total_ghost_post      = 0;
            total_matched_post_feb = 0;
            total_missing_feb     = 0;
            total_ghost_feb       = 0;
            total_closed_records  = 0;
            total_closed_records_stable = 0;
            stable_missing_pre    = 0;
            stable_missing_post   = 0;
            stable_missing_feb    = 0;

            for (int lane_idx = 0; lane_idx < NUM_LANES; lane_idx++) begin
                int unsigned matched;
                int unsigned missing;
                int unsigned ghost;

                reconcile_boundary(stage_a_ledger[lane_idx],
                                   stage_pre_rbcam_ledger[lane_idx],
                                   matched, missing, ghost);
                total_matched_a_pre += matched;
                total_missing_pre   += missing;
                total_ghost_pre     += ghost;
                stable_missing_pre  += count_stable_missing(stage_a_ledger[lane_idx],
                                                            stage_pre_rbcam_ledger[lane_idx]);

                reconcile_boundary(stage_pre_rbcam_ledger[lane_idx],
                                   stage_post_rbcam_ledger[lane_idx],
                                   matched, missing, ghost);
                total_matched_pre_post += matched;
                total_missing_post     += missing;
                total_ghost_post       += ghost;
                stable_missing_post    += count_stable_missing(stage_pre_rbcam_ledger[lane_idx],
                                                               stage_post_rbcam_ledger[lane_idx]);

                reconcile_boundary(stage_post_rbcam_ledger[lane_idx],
                                   stage_feb_egress_ledger[lane_idx],
                                   matched, missing, ghost);
                total_matched_post_feb += matched;
                total_missing_feb      += missing;
                total_ghost_feb        += ghost;
                stable_missing_feb     += count_stable_missing(stage_post_rbcam_ledger[lane_idx],
                                                               stage_feb_egress_ledger[lane_idx]);
            end

            export_now = !exported_records;
            export_closed_and_drops(export_now);
            if (export_now)
                exported_records = 1'b1;
            `uvm_info("TB_INT_SB",
                      $sformatf("reconcile[%s] A=%0d stable_A=%0d PRE=%0d pre_fanout_dupe=%0d POST=%0d FEB=%0d closed=%0d stable_closed=%0d residuals A->PRE matched/missing/ghost=%0d/%0d/%0d PRE->POST=%0d/%0d/%0d POST->FEB=%0d/%0d/%0d stable_missing A->PRE/PRE->POST/POST->FEB=%0d/%0d/%0d",
                                phase_name,
                                total_stage_a,
                                total_stage_a_stable,
                                total_pre_rbcam,
                                total_pre_rbcam_fanout_duplicates,
                                total_post_rbcam,
                                total_feb_egress,
                                total_closed_records,
                                total_closed_records_stable,
                                total_matched_a_pre,
                                total_missing_pre,
                                total_ghost_pre,
                                total_matched_pre_post,
                                total_missing_post,
                                total_ghost_post,
                                total_matched_post_feb,
                                total_missing_feb,
                                total_ghost_feb,
                                stable_missing_pre,
                                stable_missing_post,
                                stable_missing_feb),
                      UVM_LOW)
        endfunction

        virtual function void extract_phase(uvm_phase phase);
            super.extract_phase(phase);
            reconcile("extract");
        endfunction

        virtual function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            reconcile("check");
            if (require_zero_residual &&
                (total_missing_pre != 0 || total_ghost_pre != 0 ||
                 total_missing_post != 0 || total_ghost_post != 0 ||
                 total_missing_feb != 0 || total_ghost_feb != 0)) begin
                `uvm_error("TB_INT_SB",
                           "non-zero per-bucket residual in strict smoke scoreboard")
            end
            if (expected_closed_records != 0 &&
                total_closed_records != expected_closed_records) begin
                `uvm_error("TB_INT_SB",
                           $sformatf("closed_records mismatch expected=%0d actual=%0d",
                                     expected_closed_records,
                                     total_closed_records))
            end
            if (min_closed_pct != 0) begin
                int unsigned actual_pct;

                if (total_stage_a_stable == 0) begin
                    `uvm_error("TB_INT_SB",
                               "closed-record percentage gate has no stable-origin Stage-A observations")
                end else begin
                    actual_pct = (100 * total_closed_records_stable) / total_stage_a_stable;
                    if (actual_pct < min_closed_pct) begin
                        `uvm_error("TB_INT_SB",
                                   $sformatf("closed-record percentage below gate min=%0d actual=%0d stable_closed=%0d stable_stage_a=%0d",
                                             min_closed_pct,
                                             actual_pct,
                                             total_closed_records_stable,
                                             total_stage_a_stable))
                    end
                end
            end
        endfunction

        virtual function void final_phase(uvm_phase phase);
            super.final_phase(phase);
            reporter.close();
        endfunction
    endclass

endpackage
