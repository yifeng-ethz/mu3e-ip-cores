`timescale 1ns/1ps

class lane_admit_asymmetry_seq;
    virtual phase4_5_fail_mode_if vif;
    string report_root;

    logic [63:0] selected_count [8];
    logic [63:0] hit_count [8];

    function new(
        virtual phase4_5_fail_mode_if vif_i,
        string report_root_i = "../REPORT"
    );
        vif = vif_i;
        report_root = report_root_i;
        for (int lane = 0; lane < 8; lane++) begin
            selected_count[lane] = 64'd0;
            hit_count[lane] = 64'd0;
        end
    endfunction

    task automatic body();
        logic [31:0] csr_selected_lo;
        logic [63:0] min_count;
        logic [63:0] max_count;
        bit fail;

        fail = 1'b0;
        for (int lane = 0; lane < 8; lane++) begin
            $display("P45_LANE_ASYM lane=%0d start", lane);
            vif.hard_reset();
            vif.configure_emulator_common(32'h0000_0020);
            vif.drive_prepare_sync();
            vif.configure_all_arb_modes(lane);
            vif.pulse_clear_counts();
            vif.capture_enable <= 1'b1;
            vif.drive_running_terminate_1ms();
            vif.capture_enable <= 1'b0;
            vif.arb_read32(lane, vif.ARB_CSR_EGRESS_EMU_LO, csr_selected_lo);
            selected_count[lane] = {32'h0000_0000, csr_selected_lo};
            hit_count[lane] = vif.lane_selected_count[lane];
            write_lane_json(lane);
            $display("P45_LANE_ASYM lane=%0d selected=%0d hits=%0d emu_tx=%0d emu_lane_hits=%0d frames=%0d l2_level=%0d ticket_level=%0d overflow=%0d run_gen=%0b run_drain=%0b",
                     lane, selected_count[lane], hit_count[lane],
                     vif.emu_tx_count, vif.dbg_emulator_lane_hits,
                     vif.dbg_emulator_lane_frames, vif.dbg_emulator_l2_level,
                     vif.dbg_emulator_ticket_level,
                     vif.dbg_ticket_overflow_count,
                     vif.dbg_run_generating, vif.dbg_run_draining);
        end

        min_count = selected_count[0];
        max_count = selected_count[0];
        for (int lane = 0; lane < 8; lane++) begin
            if (selected_count[lane] < min_count) begin
                min_count = selected_count[lane];
            end
            if (selected_count[lane] > max_count) begin
                max_count = selected_count[lane];
            end
            if (selected_count[lane] == 64'd0 || hit_count[lane] == 64'd0) begin
                fail = 1'b1;
            end
        end

        if ((max_count > 64'd0) && ((max_count - min_count) * 64'd100 > max_count * 64'd10)) begin
            fail = 1'b1;
        end

        write_summary(fail, min_count, max_count);
        if (fail) begin
            $display("P45_LANE_ASYM_FAIL min=%0d max=%0d", min_count, max_count);
            $fatal(1, "lane admit asymmetry sim baseline failed");
        end

        $display("P45_LANE_ASYM_PASS min=%0d max=%0d", min_count, max_count);
    endtask

    task automatic write_lane_json(input int lane);
        int fd;
        string path;
        string lane_suffix;

        lane_suffix = (lane < 10) ? $sformatf("0%0d", lane) : $sformatf("%0d", lane);
        path = $sformatf("%s/lane_admit_asymmetry/lane_%s_counts.json",
                         report_root, lane_suffix);
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $fatal(1, "failed to open %s", path);
        end

        $fdisplay(fd, "{");
        $fdisplay(fd, "  \"lane\": %0d,", lane);
        $fdisplay(fd, "  \"arb_mode\": \"EMU\",");
        $fdisplay(fd, "  \"mutrig_format\": \"0x20\",");
        $fdisplay(fd, "  \"selected_count\": %0d,", selected_count[lane]);
        $fdisplay(fd, "  \"hit_count_observed\": %0d,", hit_count[lane]);
        $fdisplay(fd, "  \"emulator_tx_count\": %0d,", vif.emu_tx_count);
        $fdisplay(fd, "  \"emulator_lane_hit_count\": %0d,", vif.dbg_emulator_lane_hits);
        $fdisplay(fd, "  \"emulator_lane_frame_count\": %0d,", vif.dbg_emulator_lane_frames);
        $fdisplay(fd, "  \"emulator_l2_level\": %0d,", vif.dbg_emulator_l2_level);
        $fdisplay(fd, "  \"emulator_ticket_level\": %0d,", vif.dbg_emulator_ticket_level);
        $fdisplay(fd, "  \"ticket_overflow_count\": %0d,", vif.dbg_ticket_overflow_count);
        $fdisplay(fd, "  \"hist_bins\": [");
        for (int ch = 0; ch < 32; ch++) begin
            string comma;
            comma = (ch == 31) ? "" : ",";
            $fdisplay(fd, "    {\"channel\": %0d, \"count\": %0d}%s",
                      ch, vif.lane_payload_hist[lane][ch], comma);
        end
        $fdisplay(fd, "  ]");
        $fdisplay(fd, "}");
        $fclose(fd);
    endtask

    task automatic write_summary(
        input bit fail,
        input logic [63:0] min_count,
        input logic [63:0] max_count
    );
        int fd;
        string path;
        string verdict;

        path = $sformatf("%s/lane_admit_asymmetry/summary.md", report_root);
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $fatal(1, "failed to open %s", path);
        end

        verdict = fail ? "FAIL" : "PASS";
        $fdisplay(fd, "# Phase 4.5 Lane-Admit Asymmetry Directed Sim");
        $fdisplay(fd, "");
        $fdisplay(fd, "## Summary");
        $fdisplay(fd, "");
        $fdisplay(fd, "- Verdict: %s", verdict);
        $fdisplay(fd, "- Window: 1 ms at 125 MHz after decoded RUNNING.");
        $fdisplay(fd, "- Emulator MUTRIG_FORMAT: 0x20.");
        $fdisplay(fd, "- Expected lane spread: within 10 percent.");
        $fdisplay(fd, "- Observed selected-count span: min=%0d max=%0d.", min_count, max_count);
        $fdisplay(fd, "");
        $fdisplay(fd, "## Description");
        $fdisplay(fd, "");
        $fdisplay(fd, "The test instantiates one BYTE_STREAM_ENABLE=false emulator_mutrig_qsys_lane and fans its hit_type0 stream to eight arb_hit_type0 lanes. For each row, the decoded PREP/SYNC reset phase is driven first, then one arb lane is set to EMU while all others remain REAL before decoded RUNNING.");
        $fdisplay(fd, "");
        $fdisplay(fd, "## File Structure");
        $fdisplay(fd, "");
        $fdisplay(fd, "- `lane_NN_counts.json`: per-lane selected counter and payload-channel bins.");
        $fdisplay(fd, "- `summary.md`: pass/fail table and spread check.");
        $fdisplay(fd, "");
        $fdisplay(fd, "## Usage");
        $fdisplay(fd, "");
        $fdisplay(fd, "Run from `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm`:");
        $fdisplay(fd, "");
        $fdisplay(fd, "```sh");
        $fdisplay(fd, "make run_LANE_ASYM");
        $fdisplay(fd, "```");
        $fdisplay(fd, "");
        $fdisplay(fd, "## Test");
        $fdisplay(fd, "");
        $fdisplay(fd, "| lane | SELECTED_COUNT | hit_count |");
        $fdisplay(fd, "|---:|---:|---:|");
        for (int lane = 0; lane < 8; lane++) begin
            $fdisplay(fd, "| %0d | %0d | %0d |",
                      lane, selected_count[lane], hit_count[lane]);
        end
        $fdisplay(fd, "");
        $fdisplay(fd, "## Documentation");
        $fdisplay(fd, "");
        $fdisplay(fd, "This is a sim-only baseline for the Phase 4.5 live-sweep lane-isolation rows p45_006 through p45_013 from commit 36f71604.");
        $fclose(fd);
    endtask
endclass
