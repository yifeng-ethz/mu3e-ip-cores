// prof_sc_029_concurrent_dt_peak_stride_5_seq.sv
// Generated PROF bucket sequence for tb_int.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add generated PROF bucket sequence coverage.

package prof_sc_029_concurrent_dt_peak_stride_5_seq_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    localparam int unsigned CASE_KIND_RC = 0;
    localparam int unsigned CASE_KIND_SC = 1;
    localparam int unsigned CASE_KIND_DT = 2;

    localparam int unsigned RC_GROUP_LONG_SOAK = 0;
    localparam int unsigned RC_GROUP_RUN_NUMBER = 1;
    localparam int unsigned RC_GROUP_WATCHDOG = 2;
    localparam int unsigned RC_GROUP_RESYNC = 3;

    localparam int unsigned SC_GROUP_SINGLE = 0;
    localparam int unsigned SC_GROUP_BURST = 1;
    localparam int unsigned SC_GROUP_MIXED = 2;
    localparam int unsigned SC_GROUP_CONCURRENT = 3;

    localparam int unsigned DT_GROUP_POISSON = 0;
    localparam int unsigned DT_GROUP_RAW_CEILING = 1;
    localparam int unsigned DT_GROUP_LONG_BUMP = 2;
    localparam int unsigned DT_GROUP_WATCHDOG = 3;
    localparam int unsigned DT_GROUP_HIST_SAT = 4;

    localparam int unsigned SOURCE_REAL = 0;
    localparam int unsigned SOURCE_EMU = 1;
    localparam int unsigned SOURCE_MIX_RR = 2;
    localparam int unsigned SOURCE_MIX_CROSS = 3;

    localparam int unsigned RUNCTL_IDLE = 0;
    localparam int unsigned RUNCTL_RUN_PREP = 1;
    localparam int unsigned RUNCTL_SYNC = 2;
    localparam int unsigned RUNCTL_RUNNING = 3;
    localparam int unsigned RUNCTL_TERMINATING = 4;
    localparam int unsigned RUNCTL_RESET = 5;

    class prof_sc_029_concurrent_dt_peak_stride_5_seq extends uvm_sequence#(uvm_sequence_item);
        `uvm_object_utils(prof_sc_029_concurrent_dt_peak_stride_5_seq)

        virtual mutrig_l2_commit_if stage_a_vif;
        virtual hit_tap_if          pre_rbcam_vif;
        virtual hit_tap_if          post_rbcam_vif;
        virtual hit_tap_if          feb_egress_vif;
        virtual sc_avmm_if          sc_vif;
        virtual runctl_phy_if       runctl_vif;

        string       case_id;
        string       case_name;
        int unsigned case_number;
        int unsigned case_kind;
        int unsigned group_index;
        int unsigned variant_index;
        int unsigned running_cycles;
        int unsigned hit_count;
        int unsigned sc_ops;
        int unsigned rate_hz;
        int unsigned cluster_size;
        int unsigned source_mode;
        bit          saturation_case;
        int unsigned seed;
        int unsigned emitted_hits;
        int unsigned completed_sc_ops;

        function new(string name = "prof_sc_029_concurrent_dt_peak_stride_5_seq");
            super.new(name);
            case_id = "PROF-SC-029";
            case_name = "concurrent_dt_peak_stride_5";
            case_number = 29;
            case_kind = CASE_KIND_SC;
            group_index = 3;
            variant_index = 4;
            running_cycles = 100000;
            hit_count = 192;
            sc_ops = 10000;
            rate_hz = 1000000;
            cluster_size = 4;
            source_mode = 2;
            saturation_case = 1'b0;
            seed = 32'h1 ^ 29;
            emitted_hits = 0;
            completed_sc_ops = 0;
        endfunction

        function bit [8:0] runctl_symbol(int unsigned state);
            case (state)
                RUNCTL_IDLE:        return 9'h001;
                RUNCTL_RUN_PREP:    return 9'h002;
                RUNCTL_SYNC:        return 9'h004;
                RUNCTL_RUNNING:     return 9'h008;
                RUNCTL_TERMINATING: return 9'h010;
                RUNCTL_RESET:       return 9'h100;
                default:            return 9'h001;
            endcase
        endfunction

        function int unsigned lcg_next();
            seed = (32'd1664525 * seed) + 32'd1013904223;
            return seed;
        endfunction

        function int unsigned select_lane(int unsigned hit_idx);
            return (hit_idx + variant_index + case_number) % 8;
        endfunction

        function int unsigned select_channel(int unsigned hit_idx);
            int unsigned cluster_offset;
            int unsigned base_channel;
            int unsigned random_step;

            cluster_offset = hit_idx % cluster_size;
            random_step = (lcg_next() >> 8) & 5'h1f;
            case (source_mode)
                SOURCE_REAL: base_channel = 0;
                SOURCE_EMU: base_channel = 8;
                SOURCE_MIX_RR: base_channel = ((hit_idx + variant_index) & 1) ? 8 : 0;
                SOURCE_MIX_CROSS: base_channel = ((hit_idx + variant_index) & 1) ? 8 : 7;
                default: base_channel = 0;
            endcase
            return (base_channel + cluster_offset + random_step + variant_index) & 5'h1f;
        endfunction

        function int unsigned hit_gap_cycles();
            if (rate_hz >= 5000000)
                return 0;
            if (rate_hz >= 2000000)
                return 1;
            if (rate_hz >= 1000000)
                return 2;
            if (rate_hz >= 500000)
                return 4;
            if (rate_hz >= 100000)
                return 8;
            return 16;
        endfunction

        task wait_cycles(int unsigned cycles);
            for (int unsigned cycle_idx = 0; cycle_idx < cycles; cycle_idx++)
                @(posedge stage_a_vif.clk);
        endtask

        task wait_reset_release();
            if (stage_a_vif == null)
                `uvm_fatal("PROF_SEQ", "stage_a_vif is null")
            if (pre_rbcam_vif == null)
                `uvm_fatal("PROF_SEQ", "pre_rbcam_vif is null")
            if (post_rbcam_vif == null)
                `uvm_fatal("PROF_SEQ", "post_rbcam_vif is null")
            if (feb_egress_vif == null)
                `uvm_fatal("PROF_SEQ", "feb_egress_vif is null")
            if (sc_vif == null)
                `uvm_fatal("PROF_SEQ", "sc_vif is null")
            if (runctl_vif == null)
                `uvm_fatal("PROF_SEQ", "runctl_vif is null")
            while (stage_a_vif.rst === 1'b1)
                @(posedge stage_a_vif.clk);
            wait_cycles(8);
        endtask

        task clear_hit_taps();
            @(negedge stage_a_vif.clk);
            stage_a_vif.valid = 1'b0;
            pre_rbcam_vif.valid = 1'b0;
            post_rbcam_vif.valid = 1'b0;
            feb_egress_vif.valid = 1'b0;
        endtask

        task drive_run_state(int unsigned state, int unsigned hold_cycles);
            @(negedge runctl_vif.clk);
            runctl_vif.data = runctl_symbol(state);
            runctl_vif.error = 3'b000;
            runctl_vif.valid = 1'b1;
            if (state == RUNCTL_RUN_PREP)
                tb_int_run_window_db::reset();
            if (state == RUNCTL_RUNNING) begin
                tb_int_run_window_db::note_run_start($time);
                tb_int_run_window_db::note_stable_start($time);
            end
            if (state == RUNCTL_TERMINATING) begin
                tb_int_run_window_db::note_stable_end($time);
                tb_int_run_window_db::note_run_end($time);
            end
            wait_cycles(hold_cycles);
            @(negedge runctl_vif.clk);
            runctl_vif.valid = 1'b0;
        endtask

        task emit_closed_hit(int unsigned hit_idx);
            bit [44:0] payload;
            int unsigned lane;
            int unsigned channel;
            int unsigned t_coarse;
            int unsigned t_fine;
            int unsigned e_coarse;

            lane = select_lane(hit_idx);
            channel = select_channel(hit_idx);
            t_coarse = (case_number * 97 + hit_idx * 3 + variant_index) & 15'h7fff;
            t_fine = (hit_idx + variant_index * 3 + case_number) & 5'h1f;
            e_coarse = (t_coarse + 17 + (hit_idx & 15)) & 15'h7fff;
            payload = build_hit0_payload(4'(lane & 4'hf),
                                         5'(channel & 5'h1f),
                                         15'(t_coarse & 15'h7fff),
                                         5'(t_fine & 5'h1f),
                                         15'(e_coarse & 15'h7fff),
                                         1'b1);

            @(negedge stage_a_vif.clk);
            stage_a_vif.lane_id = 4'(lane & 4'hf);
            stage_a_vif.payload = payload;
            stage_a_vif.channel = payload[40:36];
            stage_a_vif.t_coarse = payload[35:21];
            stage_a_vif.t_fine = payload[20:16];
            stage_a_vif.valid = 1'b1;

            pre_rbcam_vif.lane_id = 4'(lane & 4'hf);
            pre_rbcam_vif.payload = payload;
            pre_rbcam_vif.hit_id = 64'd0;
            pre_rbcam_vif.hit_id_valid = 1'b0;
            pre_rbcam_vif.root_hit_id = 64'd0;
            pre_rbcam_vif.root_hit_id_valid = 1'b0;
            pre_rbcam_vif.run_origin = 1'b1;
            pre_rbcam_vif.valid = 1'b1;

            post_rbcam_vif.lane_id = 4'(lane & 4'hf);
            post_rbcam_vif.payload = payload;
            post_rbcam_vif.hit_id = 64'd0;
            post_rbcam_vif.hit_id_valid = 1'b0;
            post_rbcam_vif.root_hit_id = 64'd0;
            post_rbcam_vif.root_hit_id_valid = 1'b0;
            post_rbcam_vif.run_origin = 1'b1;
            post_rbcam_vif.valid = 1'b1;

            feb_egress_vif.lane_id = 4'(lane & 4'hf);
            feb_egress_vif.payload = payload;
            feb_egress_vif.hit_id = 64'd0;
            feb_egress_vif.hit_id_valid = 1'b0;
            feb_egress_vif.root_hit_id = 64'd0;
            feb_egress_vif.root_hit_id_valid = 1'b0;
            feb_egress_vif.run_origin = 1'b1;
            feb_egress_vif.valid = 1'b1;

            @(negedge stage_a_vif.clk);
            stage_a_vif.valid = 1'b0;
            pre_rbcam_vif.valid = 1'b0;
            post_rbcam_vif.valid = 1'b0;
            feb_egress_vif.valid = 1'b0;
            emitted_hits++;
        endtask

        task emit_hit_stream(int unsigned count);
            int unsigned gap_cycles;

            gap_cycles = hit_gap_cycles();
            for (int unsigned hit_idx = 0; hit_idx < count; hit_idx++) begin
                emit_closed_hit(hit_idx);
                wait_cycles(gap_cycles);
            end
        endtask

        task canonical_run(int unsigned run_cycles, int unsigned hits);
            drive_run_state(RUNCTL_RUN_PREP, 4 + (variant_index & 3));
            drive_run_state(RUNCTL_SYNC, 4 + ((variant_index >> 1) & 3));
            fork
                begin
                    drive_run_state(RUNCTL_RUNNING, run_cycles);
                end
                begin
                    wait_cycles(32 + (variant_index & 7));
                    emit_hit_stream(hits);
                end
            join
            drive_run_state(RUNCTL_TERMINATING, 16);
            drive_run_state(RUNCTL_IDLE, 8);
        endtask

        task run_number_sweep();
            for (int unsigned run_idx = 0; run_idx < 100; run_idx++) begin
                drive_run_state(RUNCTL_RUN_PREP, 2 + (variant_index & 1));
                drive_run_state(RUNCTL_SYNC, 2 + ((variant_index >> 1) & 1));
                fork
                    begin
                        drive_run_state(RUNCTL_RUNNING, 1000 + variant_index);
                    end
                    begin
                        wait_cycles(8);
                        emit_closed_hit(run_idx);
                    end
                join
                drive_run_state(RUNCTL_TERMINATING, 2);
                drive_run_state(RUNCTL_IDLE, 2);
            end
        endtask

        task watchdog_overlap_run();
            drive_run_state(RUNCTL_RUN_PREP, 4);
            drive_run_state(RUNCTL_SYNC, 4);
            fork
                begin
                    drive_run_state(RUNCTL_RUNNING, running_cycles);
                end
                begin
                    wait_cycles(64 + variant_index * 8);
                    emit_hit_stream(hit_count / 2);
                    wait_cycles(2048 + variant_index * 64);
                    emit_hit_stream(hit_count - (hit_count / 2));
                end
            join
            drive_run_state(RUNCTL_RESET, 8);
            drive_run_state(RUNCTL_IDLE, 8);
        endtask

        task resync_stress_run();
            drive_run_state(RUNCTL_RUN_PREP, 4);
            drive_run_state(RUNCTL_SYNC, 4);
            @(negedge runctl_vif.clk);
            runctl_vif.data = runctl_symbol(RUNCTL_RUNNING);
            runctl_vif.error = 3'b000;
            runctl_vif.valid = 1'b1;
            tb_int_run_window_db::note_run_start($time);
            tb_int_run_window_db::note_stable_start($time);
            fork
                begin
                    for (int unsigned pulse_idx = 0; pulse_idx < 16; pulse_idx++) begin
                        wait_cycles((running_cycles / 20) + variant_index + pulse_idx);
                        @(negedge runctl_vif.clk);
                        runctl_vif.data = runctl_symbol(RUNCTL_SYNC);
                        wait_cycles(1);
                        @(negedge runctl_vif.clk);
                        runctl_vif.data = runctl_symbol(RUNCTL_RUNNING);
                    end
                    wait_cycles(running_cycles / 5);
                    @(negedge runctl_vif.clk);
                    runctl_vif.valid = 1'b0;
                end
                begin
                    wait_cycles(64);
                    emit_hit_stream(hit_count);
                end
            join
            drive_run_state(RUNCTL_TERMINATING, 8);
            drive_run_state(RUNCTL_IDLE, 8);
        endtask

        task sc_transfer(bit write_enable,
                         bit [31:0] address,
                         bit [31:0] writedata,
                         int unsigned burstcount);
            int unsigned waited;

            @(negedge sc_vif.clk);
            sc_vif.address = address;
            sc_vif.writedata = writedata;
            sc_vif.byteenable = 4'hf;
            sc_vif.burstcount = 8'(burstcount & 8'hff);
            sc_vif.write = write_enable;
            sc_vif.read = !write_enable;
            waited = 0;
            do begin
                @(posedge sc_vif.clk);
                waited++;
                if (waited > 10000)
                    `uvm_fatal("PROF_SC", "AVMM waitrequest timeout")
            end while (sc_vif.waitrequest === 1'b1);
            if (!write_enable) begin
                waited = 0;
                do begin
                    @(posedge sc_vif.clk);
                    waited++;
                    if (waited > 10000)
                        `uvm_fatal("PROF_SC", "AVMM readdatavalid timeout")
                end while (sc_vif.readdatavalid !== 1'b1);
                if (sc_vif.readdata !== 32'h4849_5354)
                    `uvm_error("PROF_SC", $sformatf("unexpected read data 0x%08h", sc_vif.readdata))
            end
            @(negedge sc_vif.clk);
            sc_vif.write = 1'b0;
            sc_vif.read = 1'b0;
            completed_sc_ops++;
        endtask

        task sc_single_word_soak();
            for (int unsigned op_idx = 0; op_idx < sc_ops; op_idx++) begin
                bit write_enable;
                bit [31:0] address;

                write_enable = ((op_idx + variant_index) % 8) == 0;
                address = 32'(4 * ((op_idx * (variant_index + 1)) & 16'h03ff));
                sc_transfer(write_enable,
                            address,
                            32'(32'h5a5a_0000 ^ op_idx ^ case_number),
                            1);
            end
        endtask

        task sc_burst_soak();
            for (int unsigned burst_idx = 0; burst_idx < sc_ops; burst_idx++) begin
                bit [31:0] address;

                address = 32'(4 * ((burst_idx * 32 + variant_index) & 16'h03ff));
                sc_transfer(1'b0, address, 32'h0, 32);
            end
        endtask

        task sc_mixed_soak();
            for (int unsigned pair_idx = 0; pair_idx < sc_ops; pair_idx++) begin
                bit [31:0] address;

                address = 32'(4 * (((pair_idx << 1) + variant_index) & 16'h03ff));
                sc_transfer(1'b1,
                            address,
                            32'(32'ha500_0000 ^ pair_idx ^ (case_number << 4)),
                            1);
                sc_transfer(1'b0, address, 32'h0, 1);
            end
        endtask

        task sc_concurrent_dt();
            fork
                begin
                    sc_single_word_soak();
                end
                begin
                    canonical_run(running_cycles, hit_count);
                end
            join
        endtask

        task run_sc_case();
            int unsigned start_ops;

            start_ops = completed_sc_ops;
            case (group_index)
                SC_GROUP_SINGLE: sc_single_word_soak();
                SC_GROUP_BURST: sc_burst_soak();
                SC_GROUP_MIXED: sc_mixed_soak();
                SC_GROUP_CONCURRENT: sc_concurrent_dt();
                default: sc_single_word_soak();
            endcase
            if (completed_sc_ops == start_ops && group_index != SC_GROUP_CONCURRENT)
                `uvm_error("PROF_SC", "SC case completed no transactions")
            wait_cycles(100000);
        endtask

        task run_dt_long_bump();
            int unsigned hits_per_run;

            hits_per_run = (hit_count + 9) / 10;
            for (int unsigned run_idx = 0; run_idx < 10; run_idx++) begin
                drive_run_state(RUNCTL_RUN_PREP, 3);
                drive_run_state(RUNCTL_SYNC, 3);
                fork
                    begin
                        drive_run_state(RUNCTL_RUNNING, 100000);
                    end
                    begin
                        wait_cycles(32 + run_idx);
                        emit_hit_stream(hits_per_run);
                    end
                join
                drive_run_state(RUNCTL_TERMINATING, 3);
                drive_run_state(RUNCTL_IDLE, 3);
            end
        endtask

        task run_dt_watchdog();
            watchdog_overlap_run();
        endtask

        task run_dt_hist_saturation();
            canonical_run(running_cycles, hit_count);
        endtask

        task run_rc_case();
            case (group_index)
                RC_GROUP_LONG_SOAK: canonical_run(running_cycles, hit_count);
                RC_GROUP_RUN_NUMBER: run_number_sweep();
                RC_GROUP_WATCHDOG: watchdog_overlap_run();
                RC_GROUP_RESYNC: resync_stress_run();
                default: canonical_run(running_cycles, hit_count);
            endcase
        endtask

        task run_dt_case();
            case (group_index)
                DT_GROUP_POISSON: canonical_run(running_cycles, hit_count);
                DT_GROUP_RAW_CEILING: canonical_run(running_cycles, hit_count);
                DT_GROUP_LONG_BUMP: run_dt_long_bump();
                DT_GROUP_WATCHDOG: run_dt_watchdog();
                DT_GROUP_HIST_SAT: run_dt_hist_saturation();
                default: canonical_run(running_cycles, hit_count);
            endcase
        endtask

        virtual task body();
            int plus_seed;

            if ($value$plusargs("ARB_SEED=%d", plus_seed))
                seed = plus_seed ^ case_number;
            emitted_hits = 0;
            completed_sc_ops = 0;
            wait_reset_release();
            clear_hit_taps();
            `uvm_info("PROF_CASE",
                      $sformatf("start %s %s kind=%0d group=%0d variant=%0d run_cycles=%0d hits=%0d sc_ops=%0d rate_hz=%0d cluster=%0d source=%0d saturation=%0b",
                                case_id,
                                case_name,
                                case_kind,
                                group_index,
                                variant_index,
                                running_cycles,
                                hit_count,
                                sc_ops,
                                rate_hz,
                                cluster_size,
                                source_mode,
                                saturation_case),
                      UVM_LOW)
            case (case_kind)
                CASE_KIND_RC: run_rc_case();
                CASE_KIND_SC: run_sc_case();
                CASE_KIND_DT: run_dt_case();
                default: `uvm_fatal("PROF_CASE", "unknown PROF case kind")
            endcase
            clear_hit_taps();
            `uvm_info("PROF_CASE",
                      $sformatf("done %s emitted_hits=%0d completed_sc_ops=%0d",
                                case_id,
                                emitted_hits,
                                completed_sc_ops),
                      UVM_LOW)
        endtask

    endclass

endpackage
