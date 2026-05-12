`timescale 1ns/1ps

class mode_dispatch_seq;
    virtual phase4_5_fail_mode_if vif;
    string report_root;

    logic [31:0] mode_word [3];
    string mode_name [3];
    logic [63:0] tx_count [3];
    logic [63:0] hist_total [3];
    logic [63:0] hist_bins [3][32];
    string shape [3];

    function new(
        virtual phase4_5_fail_mode_if vif_i,
        string report_root_i = "../REPORT"
    );
        vif = vif_i;
        report_root = report_root_i;

        mode_word[0] = 32'h0000_0020;
        mode_word[1] = 32'h0000_0021;
        mode_word[2] = 32'h0000_0023;
        mode_name[0] = "0x00 direct";
        mode_name[1] = "0x01 burst-board-write";
        mode_name[2] = "0x11 periodic-board-write";

        for (int idx = 0; idx < 3; idx++) begin
            tx_count[idx] = 64'd0;
            hist_total[idx] = 64'd0;
            shape[idx] = "unrun";
            for (int ch = 0; ch < 32; ch++) begin
                hist_bins[idx][ch] = 64'd0;
            end
        end
    endfunction

    task automatic body();
        bit fail;

        fail = 1'b0;
        for (int idx = 0; idx < 3; idx++) begin
            $display("P45_MODE_DISPATCH mode=%s mutrig_format=0x%02h start",
                     mode_name[idx], mode_word[idx][7:0]);
            vif.hard_reset();
            vif.configure_emulator_common(mode_word[idx]);
            vif.drive_prepare_sync();
            vif.configure_all_arb_modes(-1);
            vif.pulse_clear_counts();
            vif.capture_enable <= 1'b1;
            vif.drive_running_terminate_1ms();
            vif.capture_enable <= 1'b0;

            tx_count[idx] = vif.emu_tx_count;
            hist_total[idx] = 64'd0;
            for (int lane = 0; lane < 8; lane++) begin
                hist_total[idx] += vif.lane_selected_count[lane];
                for (int ch = 0; ch < 32; ch++) begin
                    hist_bins[idx][ch] += vif.lane_payload_hist[lane][ch];
                end
            end
            shape[idx] = classify_shape(idx);
            write_mode_json(idx);
            if (tx_count[idx] == 64'd0 || hist_total[idx] == 64'd0) begin
                fail = 1'b1;
            end
            $display("P45_MODE_DISPATCH mode=%s tx=%0d hist_total=%0d shape=%s",
                     mode_name[idx], tx_count[idx], hist_total[idx], shape[idx]);
        end

        write_summary(fail);
        if (fail) begin
            $display("P45_MODE_DISPATCH_FAIL");
            $fatal(1, "mode dispatch sim baseline failed");
        end

        $display("P45_MODE_DISPATCH_PASS");
    endtask

    function automatic string classify_shape(input int idx);
        int active_bins;
        int first_bin;
        int last_bin;
        logic [63:0] min_nonzero;
        logic [63:0] max_nonzero;

        active_bins = 0;
        first_bin = -1;
        last_bin = -1;
        min_nonzero = 64'hFFFF_FFFF_FFFF_FFFF;
        max_nonzero = 64'd0;

        for (int ch = 0; ch < 32; ch++) begin
            if (hist_bins[idx][ch] != 64'd0) begin
                if (first_bin < 0) begin
                    first_bin = ch;
                end
                last_bin = ch;
                active_bins++;
                if (hist_bins[idx][ch] < min_nonzero) begin
                    min_nonzero = hist_bins[idx][ch];
                end
                if (hist_bins[idx][ch] > max_nonzero) begin
                    max_nonzero = hist_bins[idx][ch];
                end
            end
        end

        if (hist_total[idx] == 64'd0) begin
            return "zero";
        end
        if (active_bins == 1) begin
            return $sformatf("delta_ch%0d", first_bin);
        end
        if (active_bins <= 4 && (last_bin - first_bin + 1) == active_bins) begin
            return $sformatf("fixed_cluster_ch%0d_%0d", first_bin, last_bin);
        end
        if ((min_nonzero != 64'd0) && (max_nonzero <= (min_nonzero * 64'd2))) begin
            return $sformatf("flat_%0d_bins", active_bins);
        end
        return $sformatf("sparse_%0d_bins_ch%0d_%0d", active_bins, first_bin, last_bin);
    endfunction

    task automatic write_mode_json(input int idx);
        int fd;
        string path;
        string mode_suffix;

        mode_suffix = (idx < 10) ? $sformatf("0%0d", idx) : $sformatf("%0d", idx);
        path = $sformatf("%s/mode_dispatch/mode_%s_counts.json",
                         report_root, mode_suffix);
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $fatal(1, "failed to open %s", path);
        end

        $fdisplay(fd, "{");
        $fdisplay(fd, "  \"mode_index\": %0d,", idx);
        $fdisplay(fd, "  \"mode_name\": \"%s\",", mode_name[idx]);
        $fdisplay(fd, "  \"mutrig_format\": \"0x%02h\",", mode_word[idx][7:0]);
        $fdisplay(fd, "  \"emulator_tx_count\": %0d,", tx_count[idx]);
        $fdisplay(fd, "  \"hist_total_hits\": %0d,", hist_total[idx]);
        $fdisplay(fd, "  \"hist_distribution_shape\": \"%s\",", shape[idx]);
        $fdisplay(fd, "  \"hist_bins\": [");
        for (int ch = 0; ch < 32; ch++) begin
            string comma;
            comma = (ch == 31) ? "" : ",";
            $fdisplay(fd, "    {\"channel\": %0d, \"count\": %0d}%s",
                      ch, hist_bins[idx][ch], comma);
        end
        $fdisplay(fd, "  ]");
        $fdisplay(fd, "}");
        $fclose(fd);
    endtask

    task automatic write_summary(input bit fail);
        int fd;
        string path;
        string verdict;

        path = $sformatf("%s/mode_dispatch/summary.md", report_root);
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $fatal(1, "failed to open %s", path);
        end

        verdict = fail ? "FAIL" : "PASS";
        $fdisplay(fd, "# Phase 4.5 Mode-Dispatch Directed Sim");
        $fdisplay(fd, "");
        $fdisplay(fd, "## Summary");
        $fdisplay(fd, "");
        $fdisplay(fd, "- Verdict: %s", verdict);
        $fdisplay(fd, "- Window: 1 ms at 125 MHz after decoded RUNNING.");
        $fdisplay(fd, "- Admitted lanes: all eight arb_hit_type0 lanes in EMU mode.");
        $fdisplay(fd, "- Channel mask model: all payload channels counted.");
        $fdisplay(fd, "");
        $fdisplay(fd, "## Description");
        $fdisplay(fd, "");
        $fdisplay(fd, "The test reproduces the board-side MUTRIG_FORMAT writes 0x20, 0x21, and 0x23 against the current emulator_mutrig CSR map. The decoded PREP/SYNC reset phase is driven first, then all arb lanes are set to EMU before decoded RUNNING. In this RTL, those MUTRIG_FORMAT bits are format controls, while signal random/periodic dispatch is controlled by the SIGNAL CSR at address 0x08.");
        $fdisplay(fd, "");
        $fdisplay(fd, "## File Structure");
        $fdisplay(fd, "");
        $fdisplay(fd, "- `mode_NN_counts.json`: per-mode tx count, selected total, and payload-channel bins.");
        $fdisplay(fd, "- `summary.md`: pass/fail table and shape classification.");
        $fdisplay(fd, "");
        $fdisplay(fd, "## Usage");
        $fdisplay(fd, "");
        $fdisplay(fd, "Run from `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm`:");
        $fdisplay(fd, "");
        $fdisplay(fd, "```sh");
        $fdisplay(fd, "make run_MODE_DISPATCH");
        $fdisplay(fd, "```");
        $fdisplay(fd, "");
        $fdisplay(fd, "## Test");
        $fdisplay(fd, "");
        $fdisplay(fd, "| mode | MUTRIG_FORMAT | tx_count | hist_total | dist_shape |");
        $fdisplay(fd, "|---|---:|---:|---:|---|");
        for (int idx = 0; idx < 3; idx++) begin
            $fdisplay(fd, "| %s | 0x%02h | %0d | %0d | %s |",
                      mode_name[idx], mode_word[idx][7:0],
                      tx_count[idx], hist_total[idx], shape[idx]);
        end
        $fdisplay(fd, "");
        $fdisplay(fd, "## Documentation");
        $fdisplay(fd, "");
        $fdisplay(fd, "This is a sim-only baseline for the Phase 4.5 live-sweep mode rows p45_023 and p45_024 from commit 36f71604, plus direct 0x20 as the control mode.");
        $fclose(fd);
    endtask
endclass
