`timescale 1ns/1ps

module phase4_5_sim_row_p45_026_lane0only_0x0000FFFF_default_dir_tb;
    localparam string ROW_ID = "p45_026_lane0only_0x0000FFFF_default_dir";
    localparam string AXIS_SECTION = "4.5.cross";
    localparam string EXPECTED_BEHAVIOR = "channel passes (low half) but only lane 0 admitted";
    localparam int unsigned NUM_LANES = 8;
    localparam int unsigned NUM_BINS = 256;
    localparam logic [7:0] LANE_MASK = 8'h01;
    localparam logic [31:0] CHANNEL_MASK = 32'h0000FFFF;
    localparam logic [15:0] RATE_88FP = 16'h0800;
    localparam logic [1:0] HIT_MODE = 2'b00;
    localparam bit SANITY_NEGATIVE = 1'b0;
    localparam longint unsigned DEFAULT_RUN_CYCLES = 64'd500000000;

    localparam logic [8:0] RC_IDLE        = 9'h001;
    localparam logic [8:0] RC_PREPARING   = 9'h002;
    localparam logic [8:0] RC_SYNCING     = 9'h004;
    localparam logic [8:0] RC_RUNNING     = 9'h008;
    localparam logic [8:0] RC_TERMINATING = 9'h010;

    localparam logic [5:0] EMU_CSR_CENTRAL       = 6'h07;
    localparam logic [5:0] EMU_CSR_SIGNAL        = 6'h08;
    localparam logic [5:0] EMU_CSR_BACKGROUND    = 6'h09;
    localparam logic [5:0] EMU_CSR_MUTRIG_FORMAT = 6'h0A;
    localparam logic [5:0] EMU_CSR_RATES         = 6'h0B;
    localparam logic [5:0] EMU_CSR_CLUSTER_FIX   = 6'h0C;
    localparam logic [5:0] EMU_CSR_CLUSTER_RAND  = 6'h0D;
    localparam logic [5:0] EMU_CSR_PRNG_SEED     = 6'h0E;
    localparam logic [5:0] EMU_CSR_TIMEBASE_SEED = 6'h0F;
    localparam logic [5:0] EMU_CSR_LANE_ENABLE   = 6'h12;
    localparam logic [5:0] EMU_CSR_LANE_BASE     = 6'h18;
    localparam logic [4:0] ARB_CSR_MODE          = 5'h02;
    localparam logic [4:0] ARB_CSR_STATUS        = 5'h03;
    localparam logic [4:0] ARB_CSR_WATCHDOG      = 5'h04;
    localparam logic [4:0] ARB_CSR_DROPS_EMU_LO  = 5'h10;
    localparam logic [4:0] ARB_CSR_DROPS_EMU_HI  = 5'h11;
    localparam logic [4:0] ARB_CSR_EGRESS_EMU_LO = 5'h14;
    localparam logic [4:0] ARB_CSR_EGRESS_EMU_HI = 5'h15;

    bit clk;
    logic rst;
    logic [8:0] ctrl_data;
    logic ctrl_valid;
    logic capture_enable;
    logic clear_counts;
    logic run_active;

    logic [NUM_LANES-1:0][5:0]  emu_csr_address;
    logic [NUM_LANES-1:0]       emu_csr_read;
    logic [NUM_LANES-1:0]       emu_csr_write;
    logic [NUM_LANES-1:0][31:0] emu_csr_writedata;
    logic [NUM_LANES-1:0][31:0] emu_csr_readdata;
    logic [NUM_LANES-1:0]       emu_csr_waitrequest;
    logic [NUM_LANES-1:0]       inject_pulse;

    logic [NUM_LANES-1:0][4:0]  arb_csr_address;
    logic [NUM_LANES-1:0]       arb_csr_read;
    logic [NUM_LANES-1:0]       arb_csr_write;
    logic [NUM_LANES-1:0][31:0] arb_csr_writedata;
    logic [NUM_LANES-1:0][31:0] arb_csr_readdata;
    logic [NUM_LANES-1:0]       arb_csr_waitrequest;

    logic [NUM_LANES-1:0]       emu_valid;
    logic [NUM_LANES-1:0][44:0] emu_data;
    logic [NUM_LANES-1:0][2:0]  emu_error;
    logic [NUM_LANES-1:0][3:0]  emu_channel;
    logic [NUM_LANES-1:0]       emu_sop;
    logic [NUM_LANES-1:0]       emu_eop;
    logic [NUM_LANES-1:0]       emu_eor;
    logic [NUM_LANES-1:0][15:0] emu_debug_fill;
    logic [NUM_LANES-1:0][63:0] emu_debug_meta;
    logic [NUM_LANES-1:0]       emu_debug_meta_valid;
    logic [NUM_LANES-1:0][63:0] emu_hit_debug_data;
    logic [NUM_LANES-1:0]       emu_hit_debug_valid;
    logic [NUM_LANES-1:0][3:0]  emu_hit_debug_channel;
    logic [NUM_LANES-1:0]       emu_hit_debug_sop;
    logic [NUM_LANES-1:0]       emu_hit_debug_eop;
    logic [NUM_LANES-1:0]       emu_hit_debug_eor;
    logic [NUM_LANES-1:0][8:0]  emu_tx8b1k_data;
    logic [NUM_LANES-1:0]       emu_tx8b1k_valid;
    logic [NUM_LANES-1:0][3:0]  emu_tx8b1k_channel;
    logic [NUM_LANES-1:0][2:0]  emu_tx8b1k_error;
    logic [NUM_LANES-1:0]       emu_ctrl_ready;

    logic [NUM_LANES-1:0][44:0] arb_data;
    logic [NUM_LANES-1:0]       arb_valid;
    logic [NUM_LANES-1:0][2:0]  arb_error;
    logic [NUM_LANES-1:0][3:0]  arb_channel;
    logic [NUM_LANES-1:0]       arb_sop;
    logic [NUM_LANES-1:0]       arb_eop;
    logic [NUM_LANES-1:0]       arb_eor;
    logic [NUM_LANES-1:0][4:0]  arb_dbg_real_level;
    logic [NUM_LANES-1:0][4:0]  arb_dbg_emu_level;
    logic [NUM_LANES-1:0][7:0]  arb_dbg_flags;
    logic [NUM_LANES-1:0][63:0] arb_dbg_selected_meta;
    logic [NUM_LANES-1:0]       arb_dbg_selected_meta_valid;

    logic [63:0] emu_tx_count [NUM_LANES];
    logic [63:0] lane_selected_count [NUM_LANES];
    logic [63:0] lane_payload_hist [NUM_LANES][NUM_BINS];
    logic [63:0] lane_fifo_emu_level_max [NUM_LANES];
    logic [63:0] lane_fifo_real_level_max [NUM_LANES];

    initial clk = 1'b0;
    always #4ns clk = ~clk;

    genvar lane;
    generate
        for (lane = 0; lane < NUM_LANES; lane++) begin : lane_gen
            emulator_mutrig_qsys_lane #(
                .CSR_ADDR_WIDTH(6),
                .ASIC_ID_DEFAULT(lane[3:0]),
                .BYTE_STREAM_ENABLE(1'b0),
                .DEBUG_LEVEL(0)
            ) u_emulator (
                .i_clk(clk),
                .i_rst(rst),
                .aso_hit_type0_data(emu_data[lane]),
                .aso_hit_type0_valid(emu_valid[lane]),
                .aso_hit_type0_error(emu_error[lane]),
                .aso_hit_type0_channel(emu_channel[lane]),
                .aso_hit_type0_startofpacket(emu_sop[lane]),
                .aso_hit_type0_endofpacket(emu_eop[lane]),
                .aso_hit_type0_endofrun(emu_eor[lane]),
                .coe_debug_fifo_fill_level(emu_debug_fill[lane]),
                .coe_debug_hit_metadata(emu_debug_meta[lane]),
                .coe_debug_hit_metadata_valid(emu_debug_meta_valid[lane]),
                .aso_hit_debug_data(emu_hit_debug_data[lane]),
                .aso_hit_debug_valid(emu_hit_debug_valid[lane]),
                .aso_hit_debug_channel(emu_hit_debug_channel[lane]),
                .aso_hit_debug_startofpacket(emu_hit_debug_sop[lane]),
                .aso_hit_debug_endofpacket(emu_hit_debug_eop[lane]),
                .aso_hit_debug_endofrun(emu_hit_debug_eor[lane]),
                .aso_tx8b1k_data(emu_tx8b1k_data[lane]),
                .aso_tx8b1k_valid(emu_tx8b1k_valid[lane]),
                .aso_tx8b1k_channel(emu_tx8b1k_channel[lane]),
                .aso_tx8b1k_error(emu_tx8b1k_error[lane]),
                .asi_ctrl_data(ctrl_data),
                .asi_ctrl_valid(ctrl_valid),
                .asi_ctrl_ready(emu_ctrl_ready[lane]),
                .coe_inject_pulse(inject_pulse[lane]),
                .coe_inject_masked_pulse(1'b0),
                .avs_csr_address(emu_csr_address[lane]),
                .avs_csr_read(emu_csr_read[lane]),
                .avs_csr_write(emu_csr_write[lane]),
                .avs_csr_writedata(emu_csr_writedata[lane]),
                .avs_csr_readdata(emu_csr_readdata[lane]),
                .avs_csr_waitrequest(emu_csr_waitrequest[lane])
            );

            arb_hit_type0 #(
                .MODE_DEFAULT(0),
                .FIFO_DEPTH(16),
                .DEBUG_LEVEL(0),
                .WATCHDOG_DEFAULT(0),
                .INSTANCE_ID(lane)
            ) u_arb (
                .clk(clk),
                .rst(rst),
                .avs_csr_address(arb_csr_address[lane]),
                .avs_csr_write(arb_csr_write[lane]),
                .avs_csr_read(arb_csr_read[lane]),
                .avs_csr_writedata(arb_csr_writedata[lane]),
                .avs_csr_readdata(arb_csr_readdata[lane]),
                .avs_csr_waitrequest(arb_csr_waitrequest[lane]),
                .asi_ctrl_data(ctrl_data),
                .asi_ctrl_valid(ctrl_valid),
                .asi_real_data(45'd0),
                .asi_real_valid(1'b0),
                .asi_real_error(3'd0),
                .asi_real_channel(4'(lane)),
                .asi_real_startofpacket(1'b0),
                .asi_real_endofpacket(1'b0),
                .asi_real_endofrun(1'b0),
                .asi_emu_data(emu_data[lane]),
                .asi_emu_valid(emu_valid[lane]),
                .asi_emu_error(emu_error[lane]),
                .asi_emu_channel(emu_channel[lane]),
                .asi_emu_startofpacket(emu_sop[lane]),
                .asi_emu_endofpacket(emu_eop[lane]),
                .asi_emu_endofrun(emu_eor[lane]),
                .aso_data(arb_data[lane]),
                .aso_valid(arb_valid[lane]),
                .aso_error(arb_error[lane]),
                .aso_channel(arb_channel[lane]),
                .aso_startofpacket(arb_sop[lane]),
                .aso_endofpacket(arb_eop[lane]),
                .aso_endofrun(arb_eor[lane]),
                .coe_debug_real_fifo_level(arb_dbg_real_level[lane]),
                .coe_debug_emu_fifo_level(arb_dbg_emu_level[lane]),
                .coe_debug_fifo_flags(arb_dbg_flags[lane]),
                .coe_debug_real_hit_metadata(64'd0),
                .coe_debug_real_hit_metadata_valid(1'b0),
                .coe_debug_emu_hit_metadata(emu_hit_debug_data[lane]),
                .coe_debug_emu_hit_metadata_valid(emu_hit_debug_valid[lane]),
                .coe_debug_selected_hit_metadata(arb_dbg_selected_meta[lane]),
                .coe_debug_selected_hit_metadata_valid(arb_dbg_selected_meta_valid[lane])
            );
        end
    endgenerate

    function automatic logic [31:0] cluster_fix_for_mask(input logic [31:0] mask);
        int low;
        int high;
        logic [31:0] word;

        low = -1;
        high = 0;
        for (int ch = 0; ch < 32; ch++) begin
            if (mask[ch]) begin
                if (low < 0) begin
                    low = ch;
                end
                high = ch;
            end
        end
        if (low < 0) begin
            low = 0;
            high = 0;
        end
        word = 32'd0;
        word[6:0] = low[6:0];
        word[13:7] = high[6:0];
        word[14] = 1'b1;
        return word;
    endfunction

    function automatic longint unsigned signal_period_cycles();
        longint unsigned period;

        if (RATE_88FP == 16'd0) begin
            period = 64'd1024;
        end else begin
            period = 64'd65536 / longint'(RATE_88FP);
            if (period < 64'd2) begin
                period = 64'd2;
            end
        end
        return period;
    endfunction

    function automatic logic [63:0] hist_bin_count(input int unsigned bin_idx);
        logic [63:0] total;

        total = 64'd0;
        for (int l = 0; l < NUM_LANES; l++) begin
            total += lane_payload_hist[l][bin_idx];
        end
        return total;
    endfunction

    function automatic logic [63:0] hist_bin_sum();
        logic [63:0] total;

        total = 64'd0;
        for (int b = 0; b < NUM_BINS; b++) begin
            total += hist_bin_count(b);
        end
        return total;
    endfunction

    task automatic wait_cycles(input longint unsigned cycle_count);
        for (longint unsigned cyc = 0; cyc < cycle_count; cyc++) begin
            @(posedge clk);
        end
    endtask

    task automatic init_bus();
        rst <= 1'b1;
        ctrl_data <= RC_IDLE;
        ctrl_valid <= 1'b0;
        capture_enable <= 1'b0;
        clear_counts <= 1'b0;
        run_active <= 1'b0;
        inject_pulse <= '0;
        for (int l = 0; l < NUM_LANES; l++) begin
            emu_csr_address[l] <= '0;
            emu_csr_read[l] <= 1'b0;
            emu_csr_write[l] <= 1'b0;
            emu_csr_writedata[l] <= '0;
            arb_csr_address[l] <= '0;
            arb_csr_read[l] <= 1'b0;
            arb_csr_write[l] <= 1'b0;
            arb_csr_writedata[l] <= '0;
        end
    endtask

    task automatic pulse_clear_counts();
        @(negedge clk);
        clear_counts <= 1'b1;
        @(negedge clk);
        clear_counts <= 1'b0;
    endtask

    task automatic hard_reset();
        capture_enable <= 1'b0;
        ctrl_valid <= 1'b0;
        ctrl_data <= RC_IDLE;
        inject_pulse <= '0;
        rst <= 1'b1;
        wait_cycles(32);
        rst <= 1'b0;
        wait_cycles(32);
        pulse_clear_counts();
    endtask

    task automatic emu_write32(input int unsigned l, input logic [5:0] address, input logic [31:0] data);
        if (l >= NUM_LANES) begin
            $fatal(1, "emu_write32 lane %0d out of range", l);
        end
        @(negedge clk);
        emu_csr_address[l] <= address;
        emu_csr_writedata[l] <= data;
        emu_csr_write[l] <= 1'b1;
        emu_csr_read[l] <= 1'b0;
        @(negedge clk);
        emu_csr_write[l] <= 1'b0;
        emu_csr_writedata[l] <= 32'h0000_0000;
    endtask

    task automatic emu_read32(input int unsigned l, input logic [5:0] address, output logic [31:0] data);
        if (l >= NUM_LANES) begin
            $fatal(1, "emu_read32 lane %0d out of range", l);
        end
        @(negedge clk);
        emu_csr_address[l] <= address;
        emu_csr_read[l] <= 1'b1;
        emu_csr_write[l] <= 1'b0;
        @(posedge clk);
        #1ps;
        data = emu_csr_readdata[l];
        @(negedge clk);
        emu_csr_read[l] <= 1'b0;
    endtask

    task automatic arb_write32(input int unsigned l, input logic [4:0] address, input logic [31:0] data);
        if (l >= NUM_LANES) begin
            $fatal(1, "arb_write32 lane %0d out of range", l);
        end
        @(negedge clk);
        arb_csr_address[l] <= address;
        arb_csr_writedata[l] <= data;
        arb_csr_write[l] <= 1'b1;
        arb_csr_read[l] <= 1'b0;
        @(negedge clk);
        arb_csr_write[l] <= 1'b0;
        arb_csr_writedata[l] <= 32'h0000_0000;
    endtask

    task automatic arb_read32(input int unsigned l, input logic [4:0] address, output logic [31:0] data);
        if (l >= NUM_LANES) begin
            $fatal(1, "arb_read32 lane %0d out of range", l);
        end
        @(negedge clk);
        arb_csr_address[l] <= address;
        arb_csr_read[l] <= 1'b1;
        arb_csr_write[l] <= 1'b0;
        @(posedge clk);
        #1ps;
        data = arb_csr_readdata[l];
        @(negedge clk);
        arb_csr_read[l] <= 1'b0;
    endtask

    task automatic drive_ctrl_word(input logic [8:0] word);
        @(negedge clk);
        ctrl_data <= word;
        ctrl_valid <= 1'b1;
        @(negedge clk);
        ctrl_valid <= 1'b0;
    endtask

    task automatic configure_emulator_lane(input int unsigned l);
        logic [31:0] cluster_fix;
        logic [31:0] signal_word;

        cluster_fix = cluster_fix_for_mask(CHANNEL_MASK);
        signal_word = {30'd0, HIT_MODE};
        emu_write32(l, EMU_CSR_CENTRAL, 32'h0000_0001);
        emu_write32(l, EMU_CSR_SIGNAL, signal_word);
        emu_write32(l, EMU_CSR_BACKGROUND, 32'h0000_0000);
        emu_write32(l, EMU_CSR_MUTRIG_FORMAT, 32'h0000_0020);
        emu_write32(l, EMU_CSR_RATES, {16'd0, RATE_88FP});
        emu_write32(l, EMU_CSR_CLUSTER_FIX, cluster_fix);
        emu_write32(l, EMU_CSR_CLUSTER_RAND, 32'h0001_0204);
        emu_write32(l, EMU_CSR_PRNG_SEED, 32'hDEAD_BEEF ^ (32'(l) << 8));
        emu_write32(l, EMU_CSR_TIMEBASE_SEED, 32'h0001_0001 ^ 32'(l));
        emu_write32(l, EMU_CSR_LANE_ENABLE, {20'd0, l[3:0], 8'h01});
    endtask

    task automatic configure_all_emulators();
        for (int l = 0; l < NUM_LANES; l++) begin
            configure_emulator_lane(l);
        end
        wait_cycles(16);
    endtask

    task automatic configure_all_arb_modes();
        logic [1:0] mode;
        logic [31:0] mode_word;

        for (int l = 0; l < NUM_LANES; l++) begin
            mode = LANE_MASK[l] ? 2'd1 : 2'd0;
            mode_word = {30'd0, mode};
            arb_write32(l, ARB_CSR_MODE, mode_word | 32'h0000_0004);
            arb_write32(l, ARB_CSR_MODE, mode_word);
            arb_write32(l, ARB_CSR_WATCHDOG, 32'h0000_0000);
        end
        wait_cycles(16);
    endtask

    task automatic signal_pulser(input longint unsigned period_cycles);
        while (run_active) begin
            @(negedge clk);
            for (int l = 0; l < NUM_LANES; l++) begin
                inject_pulse[l] <= LANE_MASK[l];
            end
            @(negedge clk);
            inject_pulse <= '0;
            if (period_cycles > 64'd2) begin
                wait_cycles(period_cycles - 64'd2);
            end
        end
        inject_pulse <= '0;
    endtask

    task automatic drive_run_window(input longint unsigned run_cycles);
        longint unsigned period_cycles;

        period_cycles = signal_period_cycles();
        run_active = 1'b1;
        if (HIT_MODE[0]) begin
            fork
                signal_pulser(period_cycles);
            join_none
        end
        wait_cycles(run_cycles);
        run_active = 1'b0;
        inject_pulse <= '0;
    endtask

    task automatic write_hist_csv(input string evidence_dir);
        int fd;
        string path;

        path = {evidence_dir, "/sim_hist_bin.csv"};
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $fatal(1, "failed to open %s", path);
        end
        $fdisplay(fd, "bin_idx,count");
        for (int b = 0; b < NUM_BINS; b++) begin
            $fdisplay(fd, "%0d,%0d", b, hist_bin_count(b));
        end
        $fclose(fd);
    endtask

    task automatic write_counters_json(input string evidence_dir, input bit pass, input string predicate, input longint unsigned run_cycles_actual);
        int fd;
        string path;
        string comma;
        logic [31:0] mode_rd [NUM_LANES];
        logic [31:0] status_rd [NUM_LANES];
        logic [31:0] watchdog_rd [NUM_LANES];
        logic [31:0] selected_lo [NUM_LANES];
        logic [31:0] selected_hi [NUM_LANES];
        logic [31:0] drops_lo [NUM_LANES];
        logic [31:0] drops_hi [NUM_LANES];
        logic [31:0] emu_frame_lo [NUM_LANES];
        logic [31:0] emu_frame_hi [NUM_LANES];
        logic [31:0] emu_hit_lo [NUM_LANES];
        logic [31:0] emu_hit_hi [NUM_LANES];
        logic [63:0] sim_total;

        for (int l = 0; l < NUM_LANES; l++) begin
            arb_read32(l, ARB_CSR_MODE, mode_rd[l]);
            arb_read32(l, ARB_CSR_STATUS, status_rd[l]);
            arb_read32(l, ARB_CSR_WATCHDOG, watchdog_rd[l]);
            arb_read32(l, ARB_CSR_EGRESS_EMU_LO, selected_lo[l]);
            arb_read32(l, ARB_CSR_EGRESS_EMU_HI, selected_hi[l]);
            arb_read32(l, ARB_CSR_DROPS_EMU_LO, drops_lo[l]);
            arb_read32(l, ARB_CSR_DROPS_EMU_HI, drops_hi[l]);
            emu_read32(l, EMU_CSR_LANE_BASE + 6'(0), emu_frame_lo[l]);
            emu_read32(l, EMU_CSR_LANE_BASE + 6'(1), emu_frame_hi[l]);
            emu_read32(l, EMU_CSR_LANE_BASE + 6'(2), emu_hit_lo[l]);
            emu_read32(l, EMU_CSR_LANE_BASE + 6'(3), emu_hit_hi[l]);
        end

        sim_total = hist_bin_sum();
        path = {evidence_dir, "/sim_counters.json"};
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $fatal(1, "failed to open %s", path);
        end

        $fdisplay(fd, "{");
        $fdisplay(fd, "  \"row\": {");
        $fdisplay(fd, "    \"row_id\": \"%s\",", ROW_ID);
        $fdisplay(fd, "    \"lane_mask\": \"0x%02h\",", LANE_MASK);
        $fdisplay(fd, "    \"channel_mask\": \"0x%08h\",", CHANNEL_MASK);
        $fdisplay(fd, "    \"rate_88fp\": \"0x%04h\",", RATE_88FP);
        $fdisplay(fd, "    \"hit_mode\": \"%02b\",", HIT_MODE);
        $fdisplay(fd, "    \"interval_seconds\": 4.000000,");
        $fdisplay(fd, "    \"axis_section\": \"%s\",", AXIS_SECTION);
        $fdisplay(fd, "    \"expected_behavior\": \"%s\",", EXPECTED_BEHAVIOR);
        $fdisplay(fd, "    \"sanity_negative\": %s", SANITY_NEGATIVE ? "true" : "false");
        $fdisplay(fd, "  },");
        $fdisplay(fd, "  \"sim\": {");
        $fdisplay(fd, "    \"verdict\": \"%s\",", pass ? "PASS" : "FAIL");
        $fdisplay(fd, "    \"sim_pass_predicate\": \"%s\",", predicate);
        $fdisplay(fd, "    \"sim_total_hits\": %0d,", sim_total);
        $fdisplay(fd, "    \"sim_hist_bin_sum\": %0d,", sim_total);
        $fdisplay(fd, "    \"run_cycles\": %0d,", run_cycles_actual);
        $fdisplay(fd, "    \"default_run_cycles\": %0d,", DEFAULT_RUN_CYCLES);
        $fdisplay(fd, "    \"clock_hz\": 125000000,");
        $fdisplay(fd, "    \"harness\": \"feb_swb_corun compact directed row sim\"");
        $fdisplay(fd, "  },");
        $fdisplay(fd, "  \"run_control_sequence\": [");
        $fdisplay(fd, "    {\"host_opcode\": \"0x10\", \"decoded_word\": \"0x002\", \"state\": \"PREPARING\"},");
        $fdisplay(fd, "    {\"host_opcode\": \"0x11\", \"decoded_word\": \"0x004\", \"state\": \"SYNCING\"},");
        $fdisplay(fd, "    {\"host_opcode\": \"0x12\", \"decoded_word\": \"0x008\", \"state\": \"RUNNING\"},");
        $fdisplay(fd, "    {\"host_opcode\": \"0x13\", \"decoded_word\": \"0x010\", \"state\": \"TERMINATING\"}");
        $fdisplay(fd, "  ],");
        $fdisplay(fd, "  \"emulator_cfg\": {");
        $fdisplay(fd, "    \"SIGNAL\": \"0x%08h\",", {30'd0, HIT_MODE});
        $fdisplay(fd, "    \"MUTRIG_FORMAT\": \"0x00000020\",");
        $fdisplay(fd, "    \"RATES\": \"0x%04h\",", RATE_88FP);
        $fdisplay(fd, "    \"CLUSTER_FIX\": \"0x%08h\",", cluster_fix_for_mask(CHANNEL_MASK));
        $fdisplay(fd, "    \"LANE_ENABLE_MASK\": \"0x01 per scalar emulator lane\"");
        $fdisplay(fd, "  },");
        $fdisplay(fd, "  \"histogram_statistics_v2\": {");
        $fdisplay(fd, "    \"LEFT_BOUND\": 0,");
        $fdisplay(fd, "    \"RIGHT_BOUND\": 255,");
        $fdisplay(fd, "    \"BIN_WIDTH\": 1,");
        $fdisplay(fd, "    \"KEY_LOC\": \"channel_post\",");
        $fdisplay(fd, "    \"INTERVAL_CFG\": \"0xFFFFFFFF\",");
        $fdisplay(fd, "    \"TOTAL_HITS\": %0d,", sim_total);
        $fdisplay(fd, "    \"LAST_INTERVAL_TOTAL_HITS\": 0,");
        $fdisplay(fd, "    \"hist_bin_sum\": %0d", sim_total);
        $fdisplay(fd, "  },");
        $fdisplay(fd, "  \"arb_hit_type0_supercore\": [");
        for (int l = 0; l < NUM_LANES; l++) begin
            comma = (l == NUM_LANES - 1) ? "" : ",";
            $fdisplay(fd, "    {\"lane\": %0d, \"expected_mode\": \"%s\", \"MODE\": \"0x%08h\", \"STATUS\": \"0x%08h\", \"WATCHDOG_COUNT\": %0d, \"SELECTED_COUNT\": %0d, \"DROP_COUNT\": %0d, \"FIFO_LEVEL_MAX_EMU\": %0d, \"FIFO_LEVEL_MAX_REAL\": %0d}%s",
                      l, LANE_MASK[l] ? "EMU" : "REAL", mode_rd[l], status_rd[l], watchdog_rd[l],
                      {selected_hi[l], selected_lo[l]}, {drops_hi[l], drops_lo[l]},
                      lane_fifo_emu_level_max[l], lane_fifo_real_level_max[l], comma);
        end
        $fdisplay(fd, "  ],");
        $fdisplay(fd, "  \"emulator_mutrig\": [");
        for (int l = 0; l < NUM_LANES; l++) begin
            comma = (l == NUM_LANES - 1) ? "" : ",";
            $fdisplay(fd, "    {\"lane\": %0d, \"frame_count\": %0d, \"hit_count\": %0d, \"drop_count\": 0, \"tx_observed\": %0d}%s",
                      l, {emu_frame_hi[l], emu_frame_lo[l]}, {emu_hit_hi[l], emu_hit_lo[l]}, emu_tx_count[l], comma);
        end
        $fdisplay(fd, "  ],");
        $fdisplay(fd, "  \"ring_buffer_cam_debug_counters\": {");
        $fdisplay(fd, "    \"available\": false,");
        $fdisplay(fd, "    \"reason\": \"compact feb_swb_corun Phase 4.5 row harness does not instantiate ring_buffer_cam\", ");
        $fdisplay(fd, "    \"push\": 0, \"pop\": 0, \"overwrite\": 0, \"drops\": 0");
        $fdisplay(fd, "  },");
        $fdisplay(fd, "  \"mts_preprocessor\": {");
        $fdisplay(fd, "    \"available\": false,");
        $fdisplay(fd, "    \"reason\": \"compact feb_swb_corun Phase 4.5 row harness does not instantiate mts_preprocessor\", ");
        $fdisplay(fd, "    \"PORT_STATUS\": \"0x00000000\", \"PROCESSOR_STATUS\": \"0x00000000\"");
        $fdisplay(fd, "  }");
        $fdisplay(fd, "}");
        $fclose(fd);
    endtask

    always_ff @(posedge clk) begin
        if (rst || clear_counts) begin
            for (int l = 0; l < NUM_LANES; l++) begin
                emu_tx_count[l] <= 64'd0;
                lane_selected_count[l] <= 64'd0;
                lane_fifo_emu_level_max[l] <= 64'd0;
                lane_fifo_real_level_max[l] <= 64'd0;
                for (int b = 0; b < NUM_BINS; b++) begin
                    lane_payload_hist[l][b] <= 64'd0;
                end
            end
        end else if (capture_enable) begin
            for (int l = 0; l < NUM_LANES; l++) begin
                if (emu_valid[l]) begin
                    emu_tx_count[l] <= emu_tx_count[l] + 64'd1;
                end
                if (arb_dbg_emu_level[l] > lane_fifo_emu_level_max[l][4:0]) begin
                    lane_fifo_emu_level_max[l] <= {59'd0, arb_dbg_emu_level[l]};
                end
                if (arb_dbg_real_level[l] > lane_fifo_real_level_max[l][4:0]) begin
                    lane_fifo_real_level_max[l] <= {59'd0, arb_dbg_real_level[l]};
                end
                if (arb_valid[l]) begin
                    int unsigned payload_channel;
                    payload_channel = int'(arb_data[l][40:36]);
                    lane_selected_count[l] <= lane_selected_count[l] + 64'd1;
                    if ((payload_channel < 32) && CHANNEL_MASK[payload_channel]) begin
                        lane_payload_hist[l][payload_channel] <= lane_payload_hist[l][payload_channel] + 64'd1;
                    end
                end
            end
        end
    end

    initial begin
        string evidence_dir;
        longint unsigned run_cycles;
        bit pass;
        string predicate;
        logic [63:0] sim_total;

        init_bus();
        if (!$value$plusargs("P45_SIM_EVIDENCE_DIR=%s", evidence_dir)) begin
            evidence_dir = {"../sim_evidence/", ROW_ID};
        end
        run_cycles = DEFAULT_RUN_CYCLES;
        void'($value$plusargs("P45_SIM_RUN_CYCLES=%d", run_cycles));

        repeat (4) @(posedge clk);
        $display("P45_SIM_ROW_START row_id=%s lane_mask=0x%02h channel_mask=0x%08h rate=0x%04h hit_mode=%02b run_cycles=%0d",
                 ROW_ID, LANE_MASK, CHANNEL_MASK, RATE_88FP, HIT_MODE, run_cycles);

        hard_reset();
        configure_all_emulators();
        drive_ctrl_word(RC_PREPARING);
        wait_cycles(16);
        configure_all_arb_modes();
        drive_ctrl_word(RC_SYNCING);
        wait_cycles(16);
        pulse_clear_counts();
        capture_enable <= 1'b1;
        drive_ctrl_word(RC_RUNNING);
        drive_run_window(run_cycles);
        drive_ctrl_word(RC_TERMINATING);
        wait_cycles(125);
        drive_ctrl_word(RC_IDLE);
        wait_cycles(128);
        capture_enable <= 1'b0;

        sim_total = hist_bin_sum();
        if (SANITY_NEGATIVE) begin
            pass = (sim_total == 64'd0);
            predicate = "sanity_negative_total_hits_eq_0";
        end else begin
            pass = (sim_total > 64'd0);
            predicate = "total_hits_gt_0";
        end
        write_hist_csv(evidence_dir);
        write_counters_json(evidence_dir, pass, predicate, run_cycles);

        if (pass) begin
            $display("P45_SIM_ROW_PASS row_id=%s sim_total_hits=%0d predicate=%s", ROW_ID, sim_total, predicate);
        end else begin
            $display("P45_SIM_ROW_FAIL row_id=%s sim_total_hits=%0d predicate=%s", ROW_ID, sim_total, predicate);
            $fatal(1, "Phase 4.5 sim row failed");
        end
        repeat (16) @(posedge clk);
        $finish;
    end
endmodule
