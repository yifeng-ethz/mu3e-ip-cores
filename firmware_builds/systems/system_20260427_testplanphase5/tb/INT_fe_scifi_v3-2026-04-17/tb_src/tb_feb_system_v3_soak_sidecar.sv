`timescale 1ns/1ps

module tb_feb_system_v3_soak_sidecar;

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;
    localparam logic [8:0] CTRL_TERMINATING = 9'b000010000;
    localparam logic [8:0] IDLE_COMMA       = 9'h1BC;

    localparam int unsigned RC_PULSE_CYCLES = 32;
    localparam int unsigned RC_PREPARE_GAP  = 64;
    localparam int unsigned RC_SYNC_GAP     = 32;
    localparam int unsigned RC_TERM_GAP     = 128;

    typedef enum logic [3:0] {
        RC_IDLE_STABLE,
        RC_PREPARE_PULSE,
        RC_PREPARE_WAIT,
        RC_SYNC_PULSE,
        RC_SYNC_WAIT,
        RC_RUNNING_PULSE,
        RC_RUNNING_WAIT,
        RC_TERM_PULSE,
        RC_TERM_WAIT,
        RC_FINAL_IDLE_PULSE
    } rc_phase_t;

    rc_phase_t rc_phase_q = RC_IDLE_STABLE;
    logic      external_rc_active_q = 1'b0;
    logic      rc_valid_q = 1'b0;
    logic [8:0] rc_data_q = CTRL_IDLE;
    logic      rc_valid_mon_q = 1'b0;
    logic [8:0] rc_data_mon_q = CTRL_IDLE;
    int unsigned rc_count_q = 0;
    logic      rc_all_ready = 1'b0;
    bit        gate_idle_decode_en = 1'b0;
    logic [15:0] runctrl_seen_mask_q = '0;
    logic [7:0]  emulator_rc_seen_mask_q = '0;
    logic [1:0]  hitstack_input_rc_seen_mask_q = '0;
    logic [1:0]  frame_dp_rc_seen_mask_q = '0;
    logic [1:0]  frame_xcvr_rc_seen_mask_q = '0;

    function automatic logic gated_decode_valid(
        input logic       valid,
        input logic [8:0] data
    );
        begin
            if (gate_idle_decode_en && valid && (data == IDLE_COMMA)) begin
                gated_decode_valid = 1'b0;
            end else begin
                gated_decode_valid = valid;
            end
        end
    endfunction

    initial begin
        gate_idle_decode_en = $test$plusargs("SOAK_GATE_IDLE_DECODE");
        if (gate_idle_decode_en) begin
            $display("SOAK sidecar: gating idle decoded comma traffic at emulator seam");
        end
    end

    task force_run_control_fanout(
        input logic       valid,
        input logic [8:0] data
    );
        begin
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out0_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out0_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out1_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out1_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out2_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out2_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out3_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out3_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out4_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out4_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out5_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out5_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out6_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out6_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out7_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out7_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out8_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out8_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out9_valid  = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out9_data   = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out10_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out10_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out11_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out11_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out12_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out12_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out13_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out13_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out14_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out14_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out15_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out15_data  = data;

            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out0_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out0_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out1_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out1_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out2_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out2_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out3_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out3_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out4_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out4_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out5_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out5_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out6_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out6_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out7_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out7_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out8_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out8_data  = data;
        end
    endtask

    task force_run_control_sinks(
        input logic       valid,
        input logic [8:0] data
    );
        begin
            force tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_0.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_0.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0.asi_ctrl_valid     = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0.asi_ctrl_data      = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_signal_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_signal_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out0_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out0_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out1_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out1_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out2_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out2_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out3_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out3_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_ctrl_cdc_d2x_out_valid        = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_ctrl_cdc_d2x_out_data         = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_reset_controller_0.asi_runcontrol_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_reset_controller_0.asi_runcontrol_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1.asi_ctrl_valid     = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1.asi_ctrl_data      = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_injector_0.asi_runctl_valid    = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_injector_0.asi_runctl_data     = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_signal_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_signal_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out0_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out0_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out1_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out1_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out2_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out2_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out3_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out3_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_ctrl_cdc_d2x_out_valid        = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_ctrl_cdc_d2x_out_data         = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_1.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_1.asi_ctrl_data  = data;

            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_0.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_0.run_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_1.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_1.run_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_2.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_2.run_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_3.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_3.run_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_4.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_4.run_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_5.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_5.run_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_6.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_6.run_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_7.run_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_7.run_ctrl_data  = data;

            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6.asi_ctrl_data  = data;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7.asi_ctrl_valid = valid;
            force tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7.asi_ctrl_data  = data;
        end
    endtask

    always_comb begin
        rc_all_ready =
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out0_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out1_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out2_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out3_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out4_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out5_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out6_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out7_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out8_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out9_ready  &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out10_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out11_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out12_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out13_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out14_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.run_control_splitter_out15_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out0_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out1_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out2_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out3_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out4_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out5_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out6_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out7_ready &
            tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out8_ready;
    end

    always @(posedge tb_feb_system_v3_soak.clk125 or negedge tb_feb_system_v3_soak.reset_n) begin
        if (!tb_feb_system_v3_soak.reset_n) begin
            rc_phase_q          <= RC_IDLE_STABLE;
            external_rc_active_q <= 1'b0;
            rc_valid_q          <= 1'b0;
            rc_data_q           <= CTRL_IDLE;
            rc_valid_mon_q      <= 1'b0;
            rc_data_mon_q       <= CTRL_IDLE;
            rc_count_q          <= 0;
            runctrl_seen_mask_q <= '0;
            emulator_rc_seen_mask_q <= '0;
            hitstack_input_rc_seen_mask_q <= '0;
            frame_dp_rc_seen_mask_q <= '0;
            frame_xcvr_rc_seen_mask_q <= '0;
        end else begin
            if (!external_rc_active_q && tb_feb_system_v3_soak.external_rc_active) begin
                $display("SOAK sidecar: external RC window opened at %0t", $time);
            end
            if (external_rc_active_q && !tb_feb_system_v3_soak.external_rc_active) begin
                $display("SOAK sidecar: external RC window closing at %0t", $time);
            end
            if (rc_valid_q && (!rc_valid_mon_q || (rc_data_q != rc_data_mon_q))) begin
                $display("SOAK sidecar: RC pulse data=%09b at %0t", rc_data_q, $time);
            end

            rc_valid_mon_q <= rc_valid_q;
            rc_data_mon_q  <= rc_data_q;
            external_rc_active_q <= tb_feb_system_v3_soak.external_rc_active;
            rc_valid_q <= 1'b0;

            if (tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_0.asi_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_0.asi_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[0] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0.asi_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_0.asi_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[1] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_0.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_0.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[2] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_1.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_1.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[3] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_2.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_2.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[4] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_3.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_3.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[5] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_signal_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_signal_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[6] <= 1'b1;
                hitstack_input_rc_seen_mask_q[0] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_reset_controller_0.asi_runcontrol_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_reset_controller_0.asi_runcontrol_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[7] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_4.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_4.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[8] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_5.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_5.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[9] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_6.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_6.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[10] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_7.run_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_datapath_subsystem_7.run_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[11] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1.asi_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mts_preprocessor_1.asi_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[12] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_injector_0.asi_runctl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.mutrig_injector_0.asi_runctl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[13] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_signal_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_signal_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[14] <= 1'b1;
                hitstack_input_rc_seen_mask_q[1] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_1.asi_ctrl_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.histogram_statistics_1.asi_ctrl_data == CTRL_RUNNING)) begin
                runctrl_seen_mask_q[15] <= 1'b1;
            end

            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out1_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out1_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[0] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out2_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out2_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[1] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out3_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out3_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[2] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out4_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out4_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[3] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out5_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out5_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[4] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out6_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out6_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[5] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out7_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out7_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[6] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out8_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_ctrl_splitter_out8_data == CTRL_RUNNING)) begin
                emulator_rc_seen_mask_q[7] <= 1'b1;
            end

            if (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_control_splitter_0_out4_data == CTRL_RUNNING)) begin
                frame_dp_rc_seen_mask_q[0] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_control_splitter_0_out4_data == CTRL_RUNNING)) begin
                frame_dp_rc_seen_mask_q[1] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_ctrl_cdc_d2x_out_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_0.run_ctrl_cdc_d2x_out_data == CTRL_RUNNING)) begin
                frame_xcvr_rc_seen_mask_q[0] <= 1'b1;
            end
            if (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_ctrl_cdc_d2x_out_valid &&
                (tb_feb_system_v3_soak.dut.data_path_subsystem.hit_stack_subsystem_1.run_ctrl_cdc_d2x_out_data == CTRL_RUNNING)) begin
                frame_xcvr_rc_seen_mask_q[1] <= 1'b1;
            end

            if (external_rc_active_q && !tb_feb_system_v3_soak.external_rc_active &&
                (rc_phase_q != RC_TERM_PULSE) &&
                (rc_phase_q != RC_TERM_WAIT) &&
                (rc_phase_q != RC_FINAL_IDLE_PULSE)) begin
                rc_phase_q <= RC_TERM_PULSE;
                rc_data_q  <= CTRL_TERMINATING;
                rc_count_q <= 0;
            end else begin
                case (rc_phase_q)
                    RC_IDLE_STABLE: begin
                        rc_data_q <= CTRL_IDLE;
                        if (!external_rc_active_q && tb_feb_system_v3_soak.external_rc_active) begin
                            rc_phase_q <= RC_PREPARE_PULSE;
                            rc_data_q  <= CTRL_RUN_PREPARE;
                            rc_count_q <= 0;
                        end
                    end

                    RC_PREPARE_PULSE: begin
                        rc_valid_q <= 1'b1;
                        rc_data_q  <= CTRL_RUN_PREPARE;
                        if (rc_all_ready) begin
                            rc_phase_q <= RC_SYNC_PULSE;
                            rc_data_q  <= CTRL_SYNC;
                        end
                    end

                    RC_PREPARE_WAIT: begin
                        rc_phase_q <= RC_SYNC_PULSE;
                        rc_data_q  <= CTRL_SYNC;
                    end

                    RC_SYNC_PULSE: begin
                        rc_valid_q <= 1'b1;
                        rc_data_q  <= CTRL_SYNC;
                        if (rc_all_ready) begin
                            rc_phase_q <= RC_RUNNING_PULSE;
                            rc_data_q  <= CTRL_RUNNING;
                        end
                    end

                    RC_SYNC_WAIT: begin
                        rc_phase_q <= RC_RUNNING_PULSE;
                        rc_data_q  <= CTRL_RUNNING;
                    end

                    RC_RUNNING_PULSE: begin
                        rc_valid_q <= 1'b1;
                        rc_data_q  <= CTRL_RUNNING;
                        if (rc_all_ready) begin
                            rc_phase_q <= RC_RUNNING_WAIT;
                            rc_count_q <= 0;
                        end
                    end

                    RC_RUNNING_WAIT: begin
                        rc_data_q <= CTRL_RUNNING;
                    end

                    RC_TERM_PULSE: begin
                        rc_valid_q <= 1'b1;
                        rc_data_q  <= CTRL_TERMINATING;
                        if (rc_all_ready) begin
                            rc_phase_q <= RC_FINAL_IDLE_PULSE;
                            rc_data_q  <= CTRL_IDLE;
                        end
                    end

                    RC_TERM_WAIT: begin
                        rc_phase_q <= RC_FINAL_IDLE_PULSE;
                        rc_data_q  <= CTRL_IDLE;
                    end

                    RC_FINAL_IDLE_PULSE: begin
                        rc_valid_q <= 1'b1;
                        rc_data_q  <= CTRL_IDLE;
                        if (rc_all_ready) begin
                            rc_phase_q <= RC_IDLE_STABLE;
                            rc_count_q <= 0;
                        end
                    end

                    default: begin
                        rc_phase_q <= RC_IDLE_STABLE;
                        rc_valid_q <= 1'b0;
                        rc_data_q  <= CTRL_IDLE;
                        rc_count_q <= 0;
                    end
                endcase
            end
        end
    end

    always @(*) begin
        force tb_feb_system_v3_soak.runctrl_seen_mask = runctrl_seen_mask_q;
        force tb_feb_system_v3_soak.emulator_rc_seen_mask = emulator_rc_seen_mask_q;
        force tb_feb_system_v3_soak.hitstack_input_rc_seen_mask = hitstack_input_rc_seen_mask_q;
        force tb_feb_system_v3_soak.frame_dp_rc_seen_mask = frame_dp_rc_seen_mask_q;
        force tb_feb_system_v3_soak.frame_xcvr_rc_seen_mask = frame_xcvr_rc_seen_mask_q;
    end

    // Drive the RC fanout at the internal sink seams on clock edges. This is
    // more reliable in the mixed-language full-FEB image than a one-shot Tcl
    // force sequence because the VHDL internal nets are refreshed every cycle.
    always @(negedge tb_feb_system_v3_soak.clk125 or negedge tb_feb_system_v3_soak.reset_n) begin
        if (!tb_feb_system_v3_soak.reset_n) begin
            force_run_control_fanout(1'b0, CTRL_IDLE);
            force_run_control_sinks(1'b0, CTRL_IDLE);
        end else begin
            force_run_control_fanout(rc_valid_q, rc_data_q);
            force_run_control_sinks(rc_valid_q, rc_data_q);
        end
    end

    // Keep the decoded-din seam refreshed from the embedded emulators. This
    // full-FEB mixed-language image does not reliably retrigger the SV
    // combinational path from the VHDL emulator source nets.
    always @(negedge tb_feb_system_v3_soak.clk125) begin
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_031_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_031_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_031_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_031_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_0_tx8b1k_error;

        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_034_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_034_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_034_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_034_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_1_tx8b1k_error;

        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_037_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_037_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_037_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_037_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_2_tx8b1k_error;

        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_040_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_040_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_040_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_040_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_3_tx8b1k_error;

        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_043_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_043_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_043_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_043_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_4_tx8b1k_error;

        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_046_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_046_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_046_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_046_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_5_tx8b1k_error;

        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_049_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_049_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_049_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_049_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_6_tx8b1k_error;

        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_052_out_0_valid   = gated_decode_valid(tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7_tx8b1k_valid, tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7_tx8b1k_data);
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_052_out_0_data    = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7_tx8b1k_data;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_052_out_0_channel = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7_tx8b1k_channel;
        force tb_feb_system_v3_soak.dut.data_path_subsystem.avalon_st_adapter_052_out_0_error   = tb_feb_system_v3_soak.dut.data_path_subsystem.emulator_mutrig_7_tx8b1k_error;
    end

endmodule
