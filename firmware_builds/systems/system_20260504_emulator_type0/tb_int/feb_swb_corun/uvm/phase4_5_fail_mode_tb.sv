`timescale 1ns/1ps

module phase4_5_fail_mode_tb;
    localparam int unsigned NUM_LANES = 8;
    localparam int unsigned NUM_CHANNELS = 32;

    bit clk;
    string p45_test;
    string report_root;

    phase4_5_fail_mode_if p45_if(.clk(clk));

    logic        emu_valid;
    logic [44:0] emu_data;
    logic [2:0]  emu_error;
    logic [3:0]  emu_channel;
    logic        emu_sop;
    logic        emu_eop;
    logic        emu_eor;
    logic [15:0] emu_debug_fill;
    logic [63:0] emu_debug_meta;
    logic        emu_debug_meta_valid;
    logic [63:0] emu_hit_debug_data;
    logic        emu_hit_debug_valid;
    logic [3:0]  emu_hit_debug_channel;
    logic        emu_hit_debug_sop;
    logic        emu_hit_debug_eop;
    logic        emu_hit_debug_eor;
    logic [8:0]  emu_tx8b1k_data;
    logic        emu_tx8b1k_valid;
    logic [3:0]  emu_tx8b1k_channel;
    logic [2:0]  emu_tx8b1k_error;
    logic        emu_ctrl_ready;

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

    initial clk = 1'b0;
    always #4ns clk = ~clk;

    emulator_mutrig_qsys_lane #(
        .CSR_ADDR_WIDTH(4),
        .CLUSTER_LANE_COUNT_DEFAULT(4'd8),
        .CLUSTER_LANE_INDEX_DEFAULT(4'd0),
        .BYTE_STREAM_ENABLE(1'b0),
        .DEBUG_LEVEL(0)
    ) u_emulator (
        .i_clk                          (clk),
        .i_rst                          (p45_if.rst),
        .aso_hit_type0_data             (emu_data),
        .aso_hit_type0_valid            (emu_valid),
        .aso_hit_type0_error            (emu_error),
        .aso_hit_type0_channel          (emu_channel),
        .aso_hit_type0_startofpacket    (emu_sop),
        .aso_hit_type0_endofpacket      (emu_eop),
        .aso_hit_type0_endofrun         (emu_eor),
        .coe_debug_fifo_fill_level      (emu_debug_fill),
        .coe_debug_hit_metadata         (emu_debug_meta),
        .coe_debug_hit_metadata_valid   (emu_debug_meta_valid),
        .aso_hit_debug_data             (emu_hit_debug_data),
        .aso_hit_debug_valid            (emu_hit_debug_valid),
        .aso_hit_debug_channel          (emu_hit_debug_channel),
        .aso_hit_debug_startofpacket    (emu_hit_debug_sop),
        .aso_hit_debug_endofpacket      (emu_hit_debug_eop),
        .aso_hit_debug_endofrun         (emu_hit_debug_eor),
        .aso_tx8b1k_data                (emu_tx8b1k_data),
        .aso_tx8b1k_valid               (emu_tx8b1k_valid),
        .aso_tx8b1k_channel             (emu_tx8b1k_channel),
        .aso_tx8b1k_error               (emu_tx8b1k_error),
        .asi_ctrl_data                  (p45_if.ctrl_data),
        .asi_ctrl_valid                 (p45_if.ctrl_valid),
        .asi_ctrl_ready                 (emu_ctrl_ready),
        .coe_inject_pulse               (1'b0),
        .coe_inject_masked_pulse        (1'b0),
        .avs_csr_address                (p45_if.emu_csr_address),
        .avs_csr_read                   (p45_if.emu_csr_read),
        .avs_csr_write                  (p45_if.emu_csr_write),
        .avs_csr_writedata              (p45_if.emu_csr_writedata),
        .avs_csr_readdata               (p45_if.emu_csr_readdata),
        .avs_csr_waitrequest            (p45_if.emu_csr_waitrequest)
    );

    genvar lane;
    generate
        for (lane = 0; lane < NUM_LANES; lane++) begin : lane_gen
            arb_hit_type0 #(
                .MODE_DEFAULT(0),
                .FIFO_DEPTH(16),
                .DEBUG_LEVEL(0),
                .WATCHDOG_DEFAULT(0),
                .INSTANCE_ID(lane)
            ) u_arb (
                .clk                                  (clk),
                .rst                                  (p45_if.rst),
                .avs_csr_address                      (p45_if.arb_csr_address[lane]),
                .avs_csr_write                        (p45_if.arb_csr_write[lane]),
                .avs_csr_read                         (p45_if.arb_csr_read[lane]),
                .avs_csr_writedata                    (p45_if.arb_csr_writedata[lane]),
                .avs_csr_readdata                     (p45_if.arb_csr_readdata[lane]),
                .avs_csr_waitrequest                  (p45_if.arb_csr_waitrequest[lane]),
                .asi_ctrl_data                        (p45_if.ctrl_data),
                .asi_ctrl_valid                       (p45_if.ctrl_valid),
                .asi_real_data                        (45'd0),
                .asi_real_valid                       (1'b0),
                .asi_real_error                       (3'd0),
                .asi_real_channel                     (4'(lane)),
                .asi_real_startofpacket               (1'b0),
                .asi_real_endofpacket                 (1'b0),
                .asi_real_endofrun                    (1'b0),
                .asi_emu_data                         (emu_data),
                .asi_emu_valid                        (emu_valid),
                .asi_emu_error                        (emu_error),
                .asi_emu_channel                      (emu_channel),
                .asi_emu_startofpacket                (emu_sop),
                .asi_emu_endofpacket                  (emu_eop),
                .asi_emu_endofrun                     (emu_eor),
                .aso_data                             (arb_data[lane]),
                .aso_valid                            (arb_valid[lane]),
                .aso_error                            (arb_error[lane]),
                .aso_channel                          (arb_channel[lane]),
                .aso_startofpacket                    (arb_sop[lane]),
                .aso_endofpacket                      (arb_eop[lane]),
                .aso_endofrun                         (arb_eor[lane]),
                .coe_debug_real_fifo_level            (arb_dbg_real_level[lane]),
                .coe_debug_emu_fifo_level             (arb_dbg_emu_level[lane]),
                .coe_debug_fifo_flags                 (arb_dbg_flags[lane]),
                .coe_debug_real_hit_metadata          (64'd0),
                .coe_debug_real_hit_metadata_valid    (1'b0),
                .coe_debug_emu_hit_metadata           (emu_hit_debug_data),
                .coe_debug_emu_hit_metadata_valid     (emu_hit_debug_valid),
                .coe_debug_selected_hit_metadata      (arb_dbg_selected_meta[lane]),
                .coe_debug_selected_hit_metadata_valid(arb_dbg_selected_meta_valid[lane])
            );
        end
    endgenerate

    assign p45_if.dbg_run_generating = u_emulator.u_emulator_mutrig.run_generating;
    assign p45_if.dbg_run_draining = u_emulator.u_emulator_mutrig.run_draining;
    assign p45_if.dbg_emulator_lane_frames =
        u_emulator.u_emulator_mutrig.lane_frame_count[0];
    assign p45_if.dbg_emulator_lane_hits =
        u_emulator.u_emulator_mutrig.lane_hit_count[0];
    assign p45_if.dbg_emulator_l2_level =
        u_emulator.u_emulator_mutrig.lane_l2_fifo_level[0];
    assign p45_if.dbg_emulator_ticket_level =
        u_emulator.u_emulator_mutrig.lane_ticket_fifo_level[0];
    assign p45_if.dbg_ticket_overflow_count =
        u_emulator.u_emulator_mutrig.sig_ticket_overflow_count;

    always_ff @(posedge clk) begin
        if (p45_if.rst || p45_if.clear_counts) begin
            p45_if.emu_tx_count <= 64'd0;
            for (int lane_idx = 0; lane_idx < NUM_LANES; lane_idx++) begin
                p45_if.lane_selected_count[lane_idx] <= 64'd0;
                for (int ch = 0; ch < NUM_CHANNELS; ch++) begin
                    p45_if.lane_payload_hist[lane_idx][ch] <= 64'd0;
                end
            end
        end else if (p45_if.capture_enable) begin
            if (emu_valid) begin
                p45_if.emu_tx_count <= p45_if.emu_tx_count + 64'd1;
            end
            for (int lane_idx = 0; lane_idx < NUM_LANES; lane_idx++) begin
                if (arb_valid[lane_idx]) begin
                    logic [4:0] payload_channel;

                    payload_channel = arb_data[lane_idx][40:36];
                    p45_if.lane_selected_count[lane_idx] <=
                        p45_if.lane_selected_count[lane_idx] + 64'd1;
                    p45_if.lane_payload_hist[lane_idx][payload_channel] <=
                        p45_if.lane_payload_hist[lane_idx][payload_channel] + 64'd1;
                end
            end
        end
    end

    initial begin
        lane_admit_asymmetry_seq lane_seq;
        mode_dispatch_seq mode_seq;

        p45_if.init_bus();
        if (!$value$plusargs("P45_TEST=%s", p45_test)) begin
            p45_test = "lane";
        end
        if (!$value$plusargs("P45_REPORT_ROOT=%s", report_root)) begin
            report_root = "../REPORT";
        end

        repeat (4) @(posedge clk);
        if (p45_test == "lane") begin
            lane_seq = new(p45_if, report_root);
            lane_seq.body();
        end else if (p45_test == "mode") begin
            mode_seq = new(p45_if, report_root);
            mode_seq.body();
        end else begin
            $fatal(1, "unknown P45_TEST=%s", p45_test);
        end

        repeat (16) @(posedge clk);
        $finish;
    end
endmodule
