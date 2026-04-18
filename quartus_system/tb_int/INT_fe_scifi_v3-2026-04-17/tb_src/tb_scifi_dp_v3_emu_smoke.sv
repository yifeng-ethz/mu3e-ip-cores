`timescale 1ns/1ps

module tb_scifi_dp_v3_emu_smoke;

    localparam int unsigned AVMM_ACCEPT_TIMEOUT = 512;
    localparam int unsigned AVMM_READ_TIMEOUT   = 4096;
    // The exported AVMM bridge is word-addressed, while Platform Designer
    // reports the map in byte addresses. 0xA000/0xA400 in the system map
    // therefore appears as 0x2800/0x2900 on the 14-bit bench port.
    localparam logic [13:0] HIST0_BIN_BASE      = 14'h2800;
    localparam logic [13:0] HIST0_CSR_BASE      = 14'h2900;
    // histogram_statistics_v2 now exposes the standard UID/META header at
    // words 0..1, so the legacy alive CSR offsets must be shifted by +2.
    localparam logic [13:0] HIST0_CSR_CONTROL   = HIST0_CSR_BASE + 14'd2;
    localparam logic [13:0] HIST0_CSR_LEFT      = HIST0_CSR_BASE + 14'd3;
    localparam logic [13:0] HIST0_CSR_BIN_WIDTH = HIST0_CSR_BASE + 14'd5;
    localparam logic [13:0] HIST0_CSR_KEY_LOC   = HIST0_CSR_BASE + 14'd6;
    localparam logic [13:0] HIST0_CSR_KEY_VALUE = HIST0_CSR_BASE + 14'd7;
    localparam logic [13:0] HIST0_CSR_UNDERFLOW = HIST0_CSR_BASE + 14'd8;
    localparam logic [13:0] HIST0_CSR_OVERFLOW  = HIST0_CSR_BASE + 14'd9;
    localparam logic [13:0] HIST0_CSR_INTERVAL  = HIST0_CSR_BASE + 14'd10;
    localparam logic [13:0] HIST0_CSR_BANK      = HIST0_CSR_BASE + 14'd11;
    localparam logic [13:0] HIST0_CSR_TOTAL     = HIST0_CSR_BASE + 14'd13;
    localparam logic [13:0] HIST0_CSR_DROPPED   = HIST0_CSR_BASE + 14'd14;
    localparam time         STARTUP_SETTLE      = 20us;
    localparam int unsigned RATE_HIST_ADDR_W    = 8;
    localparam int unsigned LAT_HIST_ADDR_W     = 11;
    localparam int unsigned LAT_HIST_BINS       = 2048;
    localparam time         MEAS_TICK_8NS       = 8ns;

    localparam logic [4:0]  HIST_CSR_CONTROL    = 5'd2;
    localparam logic [4:0]  HIST_CSR_LEFT       = 5'd3;
    localparam logic [4:0]  HIST_CSR_BIN_WIDTH  = 5'd5;
    localparam logic [4:0]  HIST_CSR_KEY_LOC    = 5'd6;
    localparam logic [4:0]  HIST_CSR_INTERVAL   = 5'd10;
    localparam logic [4:0]  HIST_CSR_BANK       = 5'd11;
    localparam logic [4:0]  HIST_CSR_PORT       = 5'd12;
    localparam logic [4:0]  HIST_CSR_TOTAL      = 5'd13;
    localparam logic [4:0]  HIST_CSR_DROPPED    = 5'd14;
    localparam logic [4:0]  HIST_CSR_COAL       = 5'd15;
    localparam logic [4:0]  HIST_CSR_UNDERFLOW  = 5'd8;
    localparam logic [4:0]  HIST_CSR_OVERFLOW   = 5'd9;

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;
    localparam logic [8:0] CTRL_TERMINATING = 9'b000010000;

    localparam logic [1:0] HIT_MODE_POISSON = 2'b00;
    localparam int unsigned EMU_L2_DEPTH    = 256;
    localparam int unsigned EMU_TS_MOD_1N6  = 32767;
    localparam int unsigned TRACE_MISMATCH_DEFAULT = 64;
    localparam logic [3:0]  FA_FS_PACK      = 4'd4;
    localparam time        TB_WATCHDOG      = 2s;

    logic clk_125 = 1'b0;
    logic clk_50  = 1'b0;

    logic        avmm_rst;
    logic        counter_sclr;
    logic        monitor_rst_n;
    logic        xcvr_rst_n;

    logic [8:0] runctl_data;
    logic       runctl_valid;
    wire        runctl_ready;

    logic  [8:0] avmm_burstcount;
    logic [31:0] avmm_writedata;
    logic [13:0] avmm_address;
    logic        avmm_write;
    logic        avmm_read;
    logic  [3:0] avmm_byteenable;
    logic        avmm_debugaccess;
    wire         avmm_waitrequest;
    wire [31:0]  avmm_readdata;
    wire         avmm_readdatavalid;

    logic [RATE_HIST_ADDR_W-1:0]  rate_hist_bin_address;
    logic [RATE_HIST_ADDR_W:0]    rate_hist_bin_burstcount;
    logic [31:0]                  rate_hist_bin_writedata;
    logic                         rate_hist_bin_read;
    logic                         rate_hist_bin_write;
    wire [31:0]                   rate_hist_bin_readdata;
    wire                          rate_hist_bin_waitrequest;
    wire                          rate_hist_bin_readdatavalid;
    wire                          rate_hist_bin_writerespvalid;
    wire [1:0]                    rate_hist_bin_response;
    logic [4:0]                   rate_hist_csr_address;
    logic                         rate_hist_csr_read;
    logic                         rate_hist_csr_write;
    logic [31:0]                  rate_hist_csr_writedata;
    wire [31:0]                   rate_hist_csr_readdata;
    wire                          rate_hist_csr_waitrequest;

    logic [LAT_HIST_ADDR_W-1:0]   lat_hist_bin_address;
    logic [LAT_HIST_ADDR_W:0]     lat_hist_bin_burstcount;
    logic [31:0]                  lat_hist_bin_writedata;
    logic                         lat_hist_bin_read;
    logic                         lat_hist_bin_write;
    wire [31:0]                   lat_hist_bin_readdata;
    wire                          lat_hist_bin_waitrequest;
    wire                          lat_hist_bin_readdatavalid;
    wire                          lat_hist_bin_writerespvalid;
    wire [1:0]                    lat_hist_bin_response;
    logic [4:0]                   lat_hist_csr_address;
    logic                         lat_hist_csr_read;
    logic                         lat_hist_csr_write;
    logic [31:0]                  lat_hist_csr_writedata;
    wire [31:0]                   lat_hist_csr_readdata;
    wire                          lat_hist_csr_waitrequest;

    wire [35:0] hit_lower_data;
    wire        hit_lower_valid;
    wire        hit_lower_sop;
    wire        hit_lower_eop;
    wire [35:0] hit_upper_data;
    wire        hit_upper_valid;
    wire        hit_upper_sop;
    wire        hit_upper_eop;
    wire        inject_pulse;
    wire        lvds_outclock;
    wire [1:0]  mutrig_reset;
    wire [8:0]  rstlink_data;
    wire [3:0]  rstlink_channel;
    wire [2:0]  rstlink_error;

    int hit_lower_count;
    int hit_upper_count;
    int hit_lower_packets;
    int hit_upper_packets;
    int ext_emu_word_count;
    int dp_hit0_word_count;
    int dp_hit0_payload_fire_count;
    int mts_type1_word_count;
    int hit_stack_ingress_word_count;
    int hit_stack_ingress_payload_word_count;
    int emu_lat_hist_drive_count;
    int hit_stack_ingress_payload_clean_word_count;
    int hit_stack_ingress_payload_error_word_count;
    int hist_total_hits;
    int hist_active_bins;
    int hist_min_nonzero;
    int hist_max_nonzero;
    logic [31:0] hist_ctrl_word;
    logic [31:0] hist_bank_status;
    logic [31:0] hist_total_status;
    logic [31:0] hist_dropped_status;
    logic [31:0] hist_underflow_status;
    logic [31:0] hist_overflow_status;
    int rate_hist_total_hits;
    int rate_hist_active_bins;
    int rate_hist_min_nonzero;
    int rate_hist_max_nonzero;
    int rate_hist_peak_bin;
    logic [31:0] rate_hist_ctrl_word;
    logic [31:0] rate_hist_total_status;
    logic [31:0] rate_hist_dropped_status;
    logic [31:0] rate_hist_underflow_status;
    logic [31:0] rate_hist_overflow_status;
    int lat_hist_total_hits;
    int lat_hist_active_bins;
    int lat_hist_min_nonzero;
    int lat_hist_max_nonzero;
    int lat_hist_peak_bin;
    logic [31:0] lat_hist_ctrl_word;
    logic [31:0] lat_hist_total_status;
    logic [31:0] lat_hist_dropped_status;
    logic [31:0] lat_hist_underflow_status;
    logic [31:0] lat_hist_overflow_status;
    logic [7:0]  pre_rbcam_hist_stream_valid;
    logic [7:0]  pre_rbcam_hist_stream_sop;
    logic [7:0]  pre_rbcam_hist_stream_eop;
    logic [(8*5)-1:0]  pre_rbcam_hist_stream_data;
    logic [(8*1)-1:0]  pre_rbcam_hist_stream_channel;
    wire  [7:0]  pre_rbcam_hist_stream_ready;
    logic [7:0]  emu_lat_hist_stream_valid;
    logic [7:0]  emu_lat_hist_stream_sop;
    logic [7:0]  emu_lat_hist_stream_eop;
    logic [(8*16)-1:0] emu_lat_hist_stream_data;
    logic [(8*1)-1:0]  emu_lat_hist_stream_channel;
    wire  [7:0]        emu_lat_hist_stream_ready;
    longint unsigned   lvds_cycle;
    longint unsigned   emu_live_cycle_q [8][$];
    longint unsigned   emu_frozen_cycle_q [8][$];
    logic [4:0]        pre_rbcam_hist_queue [8][$];
    logic [15:0]       emu_lat_hist_queue [8][$];
    int                emu_lat_underflow_count;
    int                emu_live_depth_max [8];
    int                emu_frozen_depth_max [8];
    int                emu_live_overwrite_count [8];
    bit                pre_rbcam_measure_en;
    int unsigned       measure_run_cycles;
    logic [15:0]       measure_hit_rate;
    logic [15:0]       measure_noise_rate;
    bit                measure_short_mode;
    string             measure_report_dir;
    logic [15:0]       measure_hit_rate_lane [8];
    logic [15:0]       measure_noise_rate_lane [8];
    logic [1:0]        measure_hit_mode_lane [8];
    logic [4:0]        measure_burst_size_lane [8];
    logic [4:0]        measure_burst_center_lane [8];
    string             rate_hist_csv_path;
    string             lat_hist_csv_path;
    int pass_count;
    int fail_count;
    bit                trace_ts_enable;
    int unsigned       trace_mismatch_limit;
    longint unsigned   trace_next_hit_id;
    string             trace_detail_path;
    int                trace_detail_fd;
    int                trace_gen_mod_mismatch_count;
    int                trace_type0_underflow_count;
    int                trace_type0_mismatch_count;
    int                trace_mts_input_underflow_count;
    int                trace_mts_input_mismatch_count;
    int                trace_mts_output_underflow_count;
    int                trace_mts_output_channel_mismatch_count;
    int                trace_mts_output_tcc_mismatch_count;
    int                trace_mts_output_delta_mismatch_count;
    int                trace_mts_output_error_mismatch_count;
    int                trace_mismatch_print_count;
    longint signed     trace_bank_gts_skew_max;
    longint signed     trace_gen_mod_offset_first;
    bit                trace_gen_mod_offset_seen;
    bit                lfsr_step_valid [0:32767];
    int unsigned       lfsr_step_lut [0:32767];

    typedef struct {
        longint unsigned hit_id;
        longint unsigned gen_lvds_cycle;
        longint unsigned gen_gts8n;
        logic [47:0]     raw_word;
        logic [44:0]     type0_word;
        logic [3:0]      asic;
        logic [4:0]      channel;
        logic [14:0]     tcc_dark;
        logic [14:0]     ecc_dark;
        logic [4:0]      t_fine;
        logic            e_flag;
        int unsigned     tcc_white_1n6_mod;
        int unsigned     ecc_white_1n6_mod;
        int unsigned     bank;
    } trace_hit_t;

    trace_hit_t emu_live_trace_q [8][$];
    trace_hit_t emu_frozen_trace_q [8][$];
    trace_hit_t type0_trace_q [8][$];
    trace_hit_t mts_trace_q [8][$];

    wire [7:0] emu_hit_wr_en = {
        dut_wrap.dut.emulator_mutrig_7.u_hit_gen.hit_wr_en,
        dut_wrap.dut.emulator_mutrig_6.u_hit_gen.hit_wr_en,
        dut_wrap.dut.emulator_mutrig_5.u_hit_gen.hit_wr_en,
        dut_wrap.dut.emulator_mutrig_4.u_hit_gen.hit_wr_en,
        dut_wrap.dut.emulator_mutrig_3.u_hit_gen.hit_wr_en,
        dut_wrap.dut.emulator_mutrig_2.u_hit_gen.hit_wr_en,
        dut_wrap.dut.emulator_mutrig_1.u_hit_gen.hit_wr_en,
        dut_wrap.dut.emulator_mutrig_0.u_hit_gen.hit_wr_en
    };
    wire [7:0] emu_frame_start = {
        dut_wrap.dut.emulator_mutrig_7.frame_start,
        dut_wrap.dut.emulator_mutrig_6.frame_start,
        dut_wrap.dut.emulator_mutrig_5.frame_start,
        dut_wrap.dut.emulator_mutrig_4.frame_start,
        dut_wrap.dut.emulator_mutrig_3.frame_start,
        dut_wrap.dut.emulator_mutrig_2.frame_start,
        dut_wrap.dut.emulator_mutrig_1.frame_start,
        dut_wrap.dut.emulator_mutrig_0.frame_start
    };
    wire [7:0] emu_hit_dispatch = {
        lane_type0_fire(7),
        lane_type0_fire(6),
        lane_type0_fire(5),
        lane_type0_fire(4),
        lane_type0_fire(3),
        lane_type0_fire(2),
        lane_type0_fire(1),
        lane_type0_fire(0)
    };
    always #4ns  clk_125 = ~clk_125;
    always #10ns clk_50  = ~clk_50;

    function automatic logic [14:0] prbs15_step_tb(input logic [14:0] state);
        return {state[13:0], ~(state[14] ^ state[13])};
    endfunction

    function automatic longint unsigned measure_tick_8ns();
        return $time / MEAS_TICK_8NS;
    endfunction

    function automatic logic [3:0] lane_asic_id(input int unsigned lane);
        case (lane)
            0: return dut_wrap.dut.emulator_mutrig_0.csr_asic_id;
            1: return dut_wrap.dut.emulator_mutrig_1.csr_asic_id;
            2: return dut_wrap.dut.emulator_mutrig_2.csr_asic_id;
            3: return dut_wrap.dut.emulator_mutrig_3.csr_asic_id;
            4: return dut_wrap.dut.emulator_mutrig_4.csr_asic_id;
            5: return dut_wrap.dut.emulator_mutrig_5.csr_asic_id;
            6: return dut_wrap.dut.emulator_mutrig_6.csr_asic_id;
            7: return dut_wrap.dut.emulator_mutrig_7.csr_asic_id;
            default: return '0;
        endcase
    endfunction

    function automatic logic [2:0] lane_tx_mode(input int unsigned lane);
        case (lane)
            0: return dut_wrap.dut.emulator_mutrig_0.csr_tx_mode;
            1: return dut_wrap.dut.emulator_mutrig_1.csr_tx_mode;
            2: return dut_wrap.dut.emulator_mutrig_2.csr_tx_mode;
            3: return dut_wrap.dut.emulator_mutrig_3.csr_tx_mode;
            4: return dut_wrap.dut.emulator_mutrig_4.csr_tx_mode;
            5: return dut_wrap.dut.emulator_mutrig_5.csr_tx_mode;
            6: return dut_wrap.dut.emulator_mutrig_6.csr_tx_mode;
            7: return dut_wrap.dut.emulator_mutrig_7.csr_tx_mode;
            default: return '0;
        endcase
    endfunction

    function automatic logic [47:0] lane_hit_wr_data(input int unsigned lane);
        case (lane)
            0: return dut_wrap.dut.emulator_mutrig_0.u_hit_gen.hit_wr_data;
            1: return dut_wrap.dut.emulator_mutrig_1.u_hit_gen.hit_wr_data;
            2: return dut_wrap.dut.emulator_mutrig_2.u_hit_gen.hit_wr_data;
            3: return dut_wrap.dut.emulator_mutrig_3.u_hit_gen.hit_wr_data;
            4: return dut_wrap.dut.emulator_mutrig_4.u_hit_gen.hit_wr_data;
            5: return dut_wrap.dut.emulator_mutrig_5.u_hit_gen.hit_wr_data;
            6: return dut_wrap.dut.emulator_mutrig_6.u_hit_gen.hit_wr_data;
            7: return dut_wrap.dut.emulator_mutrig_7.u_hit_gen.hit_wr_data;
            default: return '0;
        endcase
    endfunction

    function automatic longint unsigned lane_true_gts8n(input int unsigned lane);
        case (lane)
            0: return dut_wrap.dut.emulator_mutrig_0.u_hit_gen.debug_hit_gen_gts_8n;
            1: return dut_wrap.dut.emulator_mutrig_1.u_hit_gen.debug_hit_gen_gts_8n;
            2: return dut_wrap.dut.emulator_mutrig_2.u_hit_gen.debug_hit_gen_gts_8n;
            3: return dut_wrap.dut.emulator_mutrig_3.u_hit_gen.debug_hit_gen_gts_8n;
            4: return dut_wrap.dut.emulator_mutrig_4.u_hit_gen.debug_hit_gen_gts_8n;
            5: return dut_wrap.dut.emulator_mutrig_5.u_hit_gen.debug_hit_gen_gts_8n;
            6: return dut_wrap.dut.emulator_mutrig_6.u_hit_gen.debug_hit_gen_gts_8n;
            7: return dut_wrap.dut.emulator_mutrig_7.u_hit_gen.debug_hit_gen_gts_8n;
            default: return 64'd0;
        endcase
    endfunction

    function automatic bit lane_type0_fire(input int unsigned lane);
        case (lane)
            0: return dut_wrap.dut.mutrig_datapath_subsystem_0_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_0_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_0_hit_type0_out_endofpacket;
            1: return dut_wrap.dut.mutrig_datapath_subsystem_1_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_1_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_1_hit_type0_out_endofpacket;
            2: return dut_wrap.dut.mutrig_datapath_subsystem_2_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_2_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_2_hit_type0_out_endofpacket;
            3: return dut_wrap.dut.mutrig_datapath_subsystem_3_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_3_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_3_hit_type0_out_endofpacket;
            4: return dut_wrap.dut.mutrig_datapath_subsystem_4_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_4_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_4_hit_type0_out_endofpacket;
            5: return dut_wrap.dut.mutrig_datapath_subsystem_5_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_5_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_5_hit_type0_out_endofpacket;
            6: return dut_wrap.dut.mutrig_datapath_subsystem_6_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_6_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_6_hit_type0_out_endofpacket;
            7: return dut_wrap.dut.mutrig_datapath_subsystem_7_hit_type0_out_valid
                    && dut_wrap.dut.mutrig_datapath_subsystem_7_hit_type0_out_ready
                    && !dut_wrap.dut.mutrig_datapath_subsystem_7_hit_type0_out_endofpacket;
            default: return 1'b0;
        endcase
    endfunction

    function automatic logic [44:0] lane_type0_data(input int unsigned lane);
        case (lane)
            0: return dut_wrap.dut.mutrig_datapath_subsystem_0_hit_type0_out_data;
            1: return dut_wrap.dut.mutrig_datapath_subsystem_1_hit_type0_out_data;
            2: return dut_wrap.dut.mutrig_datapath_subsystem_2_hit_type0_out_data;
            3: return dut_wrap.dut.mutrig_datapath_subsystem_3_hit_type0_out_data;
            4: return dut_wrap.dut.mutrig_datapath_subsystem_4_hit_type0_out_data;
            5: return dut_wrap.dut.mutrig_datapath_subsystem_5_hit_type0_out_data;
            6: return dut_wrap.dut.mutrig_datapath_subsystem_6_hit_type0_out_data;
            7: return dut_wrap.dut.mutrig_datapath_subsystem_7_hit_type0_out_data;
            default: return '0;
        endcase
    endfunction

    function automatic bit mts_input_fire(input int unsigned bank);
        case (bank)
            0: return dut_wrap.dut.mux_mutrig2processor_out_valid
                    && dut_wrap.dut.mux_mutrig2processor_out_ready
                    && !dut_wrap.dut.mux_mutrig2processor_out_endofpacket;
            1: return dut_wrap.dut.mux_mutrig2processor_0_out_valid
                    && dut_wrap.dut.mux_mutrig2processor_0_out_ready
                    && !dut_wrap.dut.mux_mutrig2processor_0_out_endofpacket;
            default: return 1'b0;
        endcase
    endfunction

    function automatic logic [44:0] mts_input_data(input int unsigned bank);
        case (bank)
            0: return dut_wrap.dut.mux_mutrig2processor_out_data;
            1: return dut_wrap.dut.mux_mutrig2processor_0_out_data;
            default: return '0;
        endcase
    endfunction

    function automatic bit mts_output_fire(input int unsigned bank);
        case (bank)
            0: return dut_wrap.dut.mts_preprocessor_0_hit_type1_out_valid
                    && dut_wrap.dut.mts_preprocessor_0_hit_type1_out_ready
                    && !dut_wrap.dut.mts_preprocessor_0_hit_type1_out_endofpacket;
            1: return dut_wrap.dut.mts_preprocessor_1_hit_type1_out_valid
                    && dut_wrap.dut.mts_preprocessor_1_hit_type1_out_ready
                    && !dut_wrap.dut.mts_preprocessor_1_hit_type1_out_endofpacket;
            default: return 1'b0;
        endcase
    endfunction

    function automatic logic [38:0] mts_output_data(input int unsigned bank);
        case (bank)
            0: return dut_wrap.dut.mts_preprocessor_0_hit_type1_out_data;
            1: return dut_wrap.dut.mts_preprocessor_1_hit_type1_out_data;
            default: return '0;
        endcase
    endfunction

    function automatic bit mts_output_error(input int unsigned bank);
        case (bank)
            0: return dut_wrap.dut.mts_preprocessor_0_hit_type1_out_error;
            1: return dut_wrap.dut.mts_preprocessor_1_hit_type1_out_error;
            default: return 1'b0;
        endcase
    endfunction

    function automatic longint unsigned bank_gts8n(input int unsigned bank);
        case (bank)
            0: return dut_wrap.dut.mts_preprocessor_0.counter_gts_8n;
            1: return dut_wrap.dut.mts_preprocessor_1.counter_gts_8n;
            default: return 64'd0;
        endcase
    endfunction

    function automatic longint signed mts_debug_delta(input int unsigned bank);
        logic signed [15:0] delta_v;
        begin
            case (bank)
                0: delta_v = dut_wrap.dut.mts_preprocessor_0.int_aso_debug_ts_data;
                1: delta_v = dut_wrap.dut.mts_preprocessor_1.int_aso_debug_ts_data;
                default: delta_v = '0;
            endcase
            return longint'(delta_v);
        end
    endfunction

    function automatic logic [44:0] build_expected_type0(
        input logic [3:0]  asic,
        input logic [2:0]  tx_mode,
        input logic [47:0] raw_word
    );
        if (tx_mode == 3'b100) begin
            // frame_rcv_ip short-mode contract:
            //   type0.T_CC   <= short_hit[21:7]  = fifo_data[20:6]
            //   type0.T_Fine <= short_hit[6:2]   = fifo_data[5:1]
            //   type0.E_CC   <= 0
            //   type0.E_Flag <= short_hit[1]     = fifo_data[0]
            return {asic, raw_word[47:43], raw_word[20:6], raw_word[5:1], 15'b0, raw_word[0]};
        end

        // frame_rcv_ip long-mode contract compacts the received 48-bit word to
        // {ASIC, channel, T_CC, T_Fine, E_CC, E_Flag} as:
        //   T_CC   <= s_o_word[41:27]
        //   T_Fine <= s_o_word[26:22]
        //   E_CC   <= s_o_word[19:5]
        //   E_Flag <= s_o_word[20]
        return {asic, raw_word[47:43], raw_word[41:27], raw_word[26:22], raw_word[19:5], raw_word[20]};
    endfunction

    function automatic int unsigned dark_to_white_mod_1n6(input logic [14:0] dark_ts);
        if (!lfsr_step_valid[dark_ts])
            return '1;
        return lfsr_step_lut[dark_ts] % EMU_TS_MOD_1N6;
    endfunction

    function automatic longint unsigned true_mod_1n6_from_gts(input longint unsigned gts8n);
        return (gts8n * 5) % EMU_TS_MOD_1N6;
    endfunction

    initial begin : init_trace_lut
        logic [14:0] lfsr_state_v;

        for (int idx = 0; idx < 32768; idx++) begin
            lfsr_step_valid[idx] = 1'b0;
            lfsr_step_lut[idx]   = 0;
        end

        lfsr_state_v = 15'h0001;
        for (int step = 0; step < EMU_TS_MOD_1N6; step++) begin
            lfsr_step_valid[lfsr_state_v] = 1'b1;
            lfsr_step_lut[lfsr_state_v]   = step;
            lfsr_state_v                  = prbs15_step_tb(lfsr_state_v);
        end
    end

    task automatic force_run_control_ready_paths;
        begin
            force dut_wrap.dut.run_control_splitter_out0_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out1_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out2_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out3_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out4_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out5_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out6_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out7_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out8_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out9_ready  = 1'b1;
            force dut_wrap.dut.run_control_splitter_out10_ready = 1'b1;
            force dut_wrap.dut.run_control_splitter_out11_ready = 1'b1;
            force dut_wrap.dut.run_control_splitter_out12_ready = 1'b1;
            force dut_wrap.dut.run_control_splitter_out13_ready = 1'b1;
            force dut_wrap.dut.run_control_splitter_out14_ready = 1'b1;
            force dut_wrap.dut.run_control_splitter_out15_ready = 1'b1;
            force dut_wrap.dut.runctl_mgmt_host_ready           = 1'b1;
        end
    endtask

    task automatic force_run_control_fanout;
        begin
            // The generated splitter network goes X in this live synthesis
            // model. Drive the fanout seams directly here and keep the real RC
            // transport coverage in the dedicated FEB integration bench.
            force dut_wrap.dut.run_control_splitter_out0_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out0_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out1_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out1_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out2_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out2_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out3_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out3_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out4_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out4_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out5_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out5_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out6_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out6_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out7_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out7_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out8_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out8_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out9_valid  = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out9_data   = runctl_data;
            force dut_wrap.dut.run_control_splitter_out10_valid = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out10_data  = runctl_data;
            force dut_wrap.dut.run_control_splitter_out11_valid = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out11_data  = runctl_data;
            force dut_wrap.dut.run_control_splitter_out12_valid = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out12_data  = runctl_data;
            force dut_wrap.dut.run_control_splitter_out13_valid = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out13_data  = runctl_data;
            force dut_wrap.dut.run_control_splitter_out14_valid = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out14_data  = runctl_data;
            force dut_wrap.dut.run_control_splitter_out15_valid = runctl_valid;
            force dut_wrap.dut.run_control_splitter_out15_data  = runctl_data;

            force dut_wrap.dut.emulator_ctrl_splitter_out0_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out0_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out1_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out1_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out2_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out2_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out3_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out3_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out4_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out4_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out5_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out5_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out6_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out6_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out7_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out7_data  = runctl_data;
            force dut_wrap.dut.emulator_ctrl_splitter_out8_valid = runctl_valid;
            force dut_wrap.dut.emulator_ctrl_splitter_out8_data  = runctl_data;
        end
    endtask

    task automatic force_histogram_ready_paths;
        begin
            force dut_wrap.dut.histogram_statistics_0_fill_out_ready = 1'b1;
            force dut_wrap.dut.hist_rate_splitter_1_out0_ready       = 1'b1;
            force dut_wrap.dut.hist_rate_splitter_2_out0_ready       = 1'b1;
            force dut_wrap.dut.hist_rate_splitter_3_out0_ready       = 1'b1;
            force dut_wrap.dut.hist_rate_splitter_4_out0_ready       = 1'b1;
            force dut_wrap.dut.hist_rate_splitter_5_out0_ready       = 1'b1;
            force dut_wrap.dut.hist_rate_splitter_6_out0_ready       = 1'b1;
            force dut_wrap.dut.hist_rate_splitter_7_out0_ready       = 1'b1;
        end
    endtask

    task automatic force_datapath_local_csr_idle;
        begin
            // Keep the generated AVMM slave seams explicitly idle. Forcing the
            // subsystem instance ports directly is not enough in this mixed
            // SV/VHDL image because the top-level interconnect nets remain X.
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_0_csr_writedata                   = 32'h0000_0000;

            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_1_csr_writedata                   = 32'h0000_0000;

            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_2_csr_writedata                   = 32'h0000_0000;

            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_3_csr_writedata                   = 32'h0000_0000;

            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_4_csr_writedata                   = 32'h0000_0000;

            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_5_csr_writedata                   = 32'h0000_0000;

            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_6_csr_writedata                   = 32'h0000_0000;

            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_backpressure_fifo_csr_address   = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_backpressure_fifo_csr_read      = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_backpressure_fifo_csr_write     = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_backpressure_fifo_csr_writedata = 32'h0000_0000;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_csr_address                     = 2'b00;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_csr_read                        = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_csr_write                       = 1'b0;
            force dut_wrap.dut.mm_interconnect_1_mutrig_datapath_subsystem_7_csr_writedata                   = 32'h0000_0000;
        end
    endtask

    task automatic force_avmm_idle_seams;
        begin
            // The generated clock-crossing/MM bridge keeps sideband signals X
            // while read/write are idle-low. That leaks into the interconnect
            // decoder in simulation, so pin the idle command bus explicitly.
            force dut_wrap.dut.mm_pipeline_avmm_lvds_m0_address     = 14'h0000;
            force dut_wrap.dut.mm_pipeline_avmm_lvds_m0_burstcount  = 9'h001;
            force dut_wrap.dut.mm_pipeline_avmm_lvds_m0_byteenable  = 4'hf;
            force dut_wrap.dut.mm_pipeline_avmm_lvds_m0_writedata   = 32'h0000_0000;
            force dut_wrap.dut.mm_pipeline_avmm_lvds_m0_debugaccess = 1'b0;
            force dut_wrap.dut.mm_pipeline_avmm_lvds_m0_read        = 1'b0;
            force dut_wrap.dut.mm_pipeline_avmm_lvds_m0_write       = 1'b0;
        end
    endtask

    task force_emulator_local_csr_lane(
        input int unsigned lane,
        input logic [3:0]  addr,
        input logic        read_en,
        input logic        write_en,
        input logic [31:0] write_data
    );
        begin
            case (lane)
                0: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_0_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_0_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_0_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_0_csr_writedata = write_data;
                end
                1: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_1_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_1_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_1_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_1_csr_writedata = write_data;
                end
                2: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_2_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_2_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_2_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_2_csr_writedata = write_data;
                end
                3: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_3_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_3_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_3_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_3_csr_writedata = write_data;
                end
                4: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_4_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_4_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_4_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_4_csr_writedata = write_data;
                end
                5: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_5_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_5_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_5_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_5_csr_writedata = write_data;
                end
                6: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_6_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_6_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_6_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_6_csr_writedata = write_data;
                end
                7: begin
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_7_csr_address   = addr;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_7_csr_read      = read_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_7_csr_write     = write_en;
                    force dut_wrap.dut.mm_interconnect_1_emulator_mutrig_7_csr_writedata = write_data;
                end
                default: $fatal(1, "Invalid emulator lane %0d", lane);
            endcase
        end
    endtask

    task force_emulator_local_csr_idle;
        begin
            for (int lane = 0; lane < 8; lane++)
                force_emulator_local_csr_lane(lane, 4'h0, 1'b0, 1'b0, 32'h0000_0000);
        end
    endtask

    task automatic read_emulator_local_waitrequest(
        input  int unsigned lane,
        output logic        waitrequest
    );
        begin
            case (lane)
                0: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_0_csr_waitrequest;
                1: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_1_csr_waitrequest;
                2: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_2_csr_waitrequest;
                3: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_3_csr_waitrequest;
                4: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_4_csr_waitrequest;
                5: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_5_csr_waitrequest;
                6: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_6_csr_waitrequest;
                7: waitrequest = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_7_csr_waitrequest;
                default: begin
                    waitrequest = 1'b1;
                    $fatal(1, "Invalid emulator lane %0d", lane);
                end
            endcase
        end
    endtask

    task automatic read_emulator_local_readdata(
        input  int unsigned lane,
        output logic [31:0] data
    );
        begin
            case (lane)
                0: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_0_csr_readdata;
                1: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_1_csr_readdata;
                2: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_2_csr_readdata;
                3: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_3_csr_readdata;
                4: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_4_csr_readdata;
                5: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_5_csr_readdata;
                6: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_6_csr_readdata;
                7: data = dut_wrap.dut.mm_interconnect_1_emulator_mutrig_7_csr_readdata;
                default: begin
                    data = '0;
                    $fatal(1, "Invalid emulator lane %0d", lane);
                end
            endcase
        end
    endtask

    task automatic force_datapath_hit0_ready_paths;
        begin
            force dut_wrap.dut.mutrig_datapath_subsystem_0_hit_type0_out_ready = 1'b1;
            force dut_wrap.dut.mutrig_datapath_subsystem_1_hit_type0_out_ready = 1'b1;
            force dut_wrap.dut.mutrig_datapath_subsystem_2_hit_type0_out_ready = 1'b1;
            force dut_wrap.dut.mutrig_datapath_subsystem_3_hit_type0_out_ready = 1'b1;
            force dut_wrap.dut.mutrig_datapath_subsystem_4_hit_type0_out_ready = 1'b1;
            force dut_wrap.dut.mutrig_datapath_subsystem_5_hit_type0_out_ready = 1'b1;
            force dut_wrap.dut.mutrig_datapath_subsystem_6_hit_type0_out_ready = 1'b1;
            force dut_wrap.dut.mutrig_datapath_subsystem_7_hit_type0_out_ready = 1'b1;
        end
    endtask

    task automatic force_lvds_decode_lanes_off;
        begin
            // Disable the broken generated LVDS decode leg in simulation.
            force dut_wrap.dut.avalon_st_adapter_029_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_029_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_029_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_029_out_0_error   = 3'b000;
            force dut_wrap.dut.avalon_st_adapter_032_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_032_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_032_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_032_out_0_error   = 3'b000;
            force dut_wrap.dut.avalon_st_adapter_035_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_035_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_035_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_035_out_0_error   = 3'b000;
            force dut_wrap.dut.avalon_st_adapter_038_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_038_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_038_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_038_out_0_error   = 3'b000;
            force dut_wrap.dut.avalon_st_adapter_041_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_041_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_041_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_041_out_0_error   = 3'b000;
            force dut_wrap.dut.avalon_st_adapter_044_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_044_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_044_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_044_out_0_error   = 3'b000;
            force dut_wrap.dut.avalon_st_adapter_047_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_047_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_047_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_047_out_0_error   = 3'b000;
            force dut_wrap.dut.avalon_st_adapter_050_out_0_valid   = 1'b0;
            force dut_wrap.dut.avalon_st_adapter_050_out_0_data    = 9'h000;
            force dut_wrap.dut.avalon_st_adapter_050_out_0_channel = 4'h0;
            force dut_wrap.dut.avalon_st_adapter_050_out_0_error   = 3'b000;
        end
    endtask

    task automatic bus_idle;
        begin
            avmm_burstcount  = 9'd1;
            avmm_writedata   = '0;
            avmm_address     = '0;
            avmm_write       = 1'b0;
            avmm_read        = 1'b0;
            avmm_byteenable  = 4'hf;
            avmm_debugaccess = 1'b0;
        end
    endtask

    task automatic reset_counters;
        begin
            hit_lower_count          = 0;
            hit_upper_count          = 0;
            hit_lower_packets        = 0;
            hit_upper_packets        = 0;
            ext_emu_word_count       = 0;
            dp_hit0_word_count       = 0;
            dp_hit0_payload_fire_count = 0;
            mts_type1_word_count     = 0;
            hit_stack_ingress_word_count = 0;
            hit_stack_ingress_payload_word_count = 0;
            emu_lat_hist_drive_count = 0;
            hit_stack_ingress_payload_clean_word_count = 0;
            hit_stack_ingress_payload_error_word_count = 0;
            hist_total_hits          = 0;
            hist_active_bins         = 0;
            hist_min_nonzero         = 0;
            hist_max_nonzero         = 0;
            rate_hist_total_hits     = 0;
            rate_hist_active_bins    = 0;
            rate_hist_min_nonzero    = 0;
            rate_hist_max_nonzero    = 0;
            rate_hist_peak_bin       = -1;
            lat_hist_total_hits      = 0;
            lat_hist_active_bins     = 0;
            lat_hist_min_nonzero     = 0;
            lat_hist_max_nonzero     = 0;
            lat_hist_peak_bin        = -1;
            emu_lat_underflow_count  = 0;
            trace_next_hit_id        = 0;
            trace_gen_mod_mismatch_count = 0;
            trace_type0_underflow_count = 0;
            trace_type0_mismatch_count = 0;
            trace_mts_input_underflow_count = 0;
            trace_mts_input_mismatch_count = 0;
            trace_mts_output_underflow_count = 0;
            trace_mts_output_channel_mismatch_count = 0;
            trace_mts_output_tcc_mismatch_count = 0;
            trace_mts_output_delta_mismatch_count = 0;
            trace_mts_output_error_mismatch_count = 0;
            trace_mismatch_print_count = 0;
            trace_bank_gts_skew_max = 0;
            trace_gen_mod_offset_first = 0;
            trace_gen_mod_offset_seen = 1'b0;
            pre_rbcam_hist_stream_valid   = '0;
            pre_rbcam_hist_stream_sop     = '0;
            pre_rbcam_hist_stream_eop     = '0;
            pre_rbcam_hist_stream_data    = '0;
            pre_rbcam_hist_stream_channel = '0;
            emu_lat_hist_stream_valid     = '0;
            emu_lat_hist_stream_sop       = '0;
            emu_lat_hist_stream_eop       = '0;
            emu_lat_hist_stream_data      = '0;
            emu_lat_hist_stream_channel   = '0;
            for (int lane = 0; lane < 8; lane++) begin
                emu_live_depth_max[lane]      = 0;
                emu_frozen_depth_max[lane]    = 0;
                emu_live_overwrite_count[lane] = 0;
                pre_rbcam_hist_queue[lane].delete();
                emu_lat_hist_queue[lane].delete();
                emu_live_trace_q[lane].delete();
                emu_frozen_trace_q[lane].delete();
                type0_trace_q[lane].delete();
                mts_trace_q[lane].delete();
            end
        end
    endtask

    task automatic avmm_write32(
        input logic [13:0] addr,
        input logic [31:0] data
    );
        int unsigned cycles;
        begin
            @(posedge clk_50);
            avmm_address    <= addr;
            avmm_writedata  <= data;
            avmm_write      <= 1'b1;
            avmm_read       <= 1'b0;
            avmm_byteenable <= 4'hf;
            avmm_burstcount <= 9'd1;

            cycles = 0;
            while (1'b1) begin
                @(posedge clk_50);
                if (avmm_waitrequest === 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_ACCEPT_TIMEOUT)
                    $fatal(1, "AVMM write accept timeout addr=0x%04h data=0x%08h", addr, data);
            end

            avmm_write     <= 1'b0;
            avmm_address   <= '0;
            avmm_writedata <= '0;
            @(posedge clk_50);
        end
    endtask

    task automatic avmm_read32(
        input  logic [13:0] addr,
        output logic [31:0] data
    );
        int unsigned cycles;
        begin
            @(posedge clk_50);
            avmm_address    <= addr;
            avmm_read       <= 1'b1;
            avmm_write      <= 1'b0;
            avmm_byteenable <= 4'hf;
            avmm_burstcount <= 9'd1;

            cycles = 0;
            while (1'b1) begin
                @(posedge clk_50);
                if (avmm_waitrequest === 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_ACCEPT_TIMEOUT)
                    $fatal(1, "AVMM read accept timeout addr=0x%04h", addr);
            end

            avmm_read    <= 1'b0;
            avmm_address <= '0;

            cycles = 0;
            while (1'b1) begin
                @(posedge clk_50);
                if (avmm_readdatavalid === 1'b1)
                    break;
                cycles++;
                if (cycles > AVMM_READ_TIMEOUT)
                    $fatal(1, "AVMM read data timeout addr=0x%04h", addr);
            end

            data = avmm_readdata;
        end
    endtask

    task automatic avmm_try_read32(
        input  logic [13:0] addr,
        output logic [31:0] data,
        output bit          ok
    );
        int unsigned cycles;
        begin
            ok = 1'b0;
            data = '0;

            @(posedge clk_50);
            avmm_address    <= addr;
            avmm_read       <= 1'b1;
            avmm_write      <= 1'b0;
            avmm_byteenable <= 4'hf;
            avmm_burstcount <= 9'd1;

            cycles = 0;
            while (1'b1) begin
                @(posedge clk_50);
                if (avmm_waitrequest === 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_ACCEPT_TIMEOUT) begin
                    avmm_read    <= 1'b0;
                    avmm_address <= '0;
                    return;
                end
            end

            avmm_read    <= 1'b0;
            avmm_address <= '0;

            cycles = 0;
            while (1'b1) begin
                @(posedge clk_50);
                if (avmm_readdatavalid === 1'b1) begin
                    data = avmm_readdata;
                    ok = 1'b1;
                    break;
                end
                cycles++;
                if (cycles > AVMM_READ_TIMEOUT)
                    return;
            end
        end
    endtask

    task automatic emu_write32_local(
        input int unsigned lane,
        input logic [3:0]  addr,
        input logic [31:0] data
    );
        begin
            @(posedge lvds_outclock);
            force_emulator_local_csr_lane(lane, addr, 1'b0, 1'b1, data);
            @(posedge lvds_outclock);
            force_emulator_local_csr_lane(lane, 4'h0, 1'b0, 1'b0, 32'h0000_0000);
            @(posedge lvds_outclock);
        end
    endtask

    task automatic emu_read32_local(
        input  int unsigned lane,
        input  logic [3:0]  addr,
        output logic [31:0] data
    );
        begin
            @(posedge lvds_outclock);
            force_emulator_local_csr_lane(lane, addr, 1'b1, 1'b0, 32'h0000_0000);
            @(posedge lvds_outclock);
            @(posedge lvds_outclock);
            read_emulator_local_readdata(lane, data);
            force_emulator_local_csr_lane(lane, 4'h0, 1'b0, 1'b0, 32'h0000_0000);
            @(posedge lvds_outclock);
        end
    endtask

    task automatic check(input string name, input bit cond);
        begin
            if (cond) begin
                $display("[PASS] %s", name);
                pass_count++;
            end else begin
                $display("[FAIL] %s", name);
                fail_count++;
            end
        end
    endtask

    task automatic send_run_state(input logic [8:0] state);
        begin
            @(posedge clk_125);
            runctl_data  <= state;
            runctl_valid <= 1'b1;
            repeat (2) @(posedge clk_125);
            runctl_valid <= 1'b0;
            @(posedge clk_125);
        end
    endtask

    task automatic enter_running;
        begin
            send_run_state(CTRL_IDLE);
            repeat (32) @(posedge clk_125);
            send_run_state(CTRL_RUN_PREPARE);
            repeat (64) @(posedge clk_125);
            send_run_state(CTRL_SYNC);
            repeat (32) @(posedge clk_125);
            send_run_state(CTRL_RUNNING);
            repeat (64) @(posedge clk_125);
        end
    endtask

    task automatic leave_running;
        begin
            send_run_state(CTRL_TERMINATING);
            repeat (128) @(posedge clk_125);
            send_run_state(CTRL_IDLE);
            repeat (32) @(posedge clk_125);
        end
    endtask

    task automatic leave_running_with_drain(input int unsigned drain_lvds_cycles);
        begin
            send_run_state(CTRL_TERMINATING);
            repeat (drain_lvds_cycles) @(posedge lvds_outclock);
            send_run_state(CTRL_IDLE);
            repeat (32) @(posedge clk_125);
        end
    endtask

    task automatic configure_emulator(
        input int unsigned index,
        input logic [15:0] hit_rate,
        input logic [15:0] noise_rate,
        input bit          short_mode,
        input logic [1:0]  hit_mode,
        input logic [4:0]  burst_size,
        input logic [4:0]  burst_center
    );
        logic [31:0] control_word;
        logic [31:0] tx_word;
        logic [31:0] burst_word;
        begin
            control_word = {28'h0, short_mode, hit_mode, 1'b1};
            burst_word   = {19'h0, burst_center, 3'h0, burst_size};
            tx_word      = {24'h0, index[3:0], 1'b0, 3'b000};

            emu_write32_local(index, 4'd0, control_word);
            emu_write32_local(index, 4'd1, {noise_rate, hit_rate});
            emu_write32_local(index, 4'd2, burst_word);
            emu_write32_local(index, 4'd3, 32'h1bad_f00d ^ index);
            emu_write32_local(index, 4'd4, tx_word);
        end
    endtask

    task automatic configure_all_emulators_rate(
        input logic [15:0] hit_rate,
        input logic [15:0] noise_rate,
        input bit          short_mode
    );
        int i;
        begin
            for (i = 0; i < 8; i++)
                configure_emulator(i, hit_rate, noise_rate, short_mode, HIT_MODE_POISSON, 5'd4, 5'd16);
        end
    endtask

    task automatic configure_all_emulators_profile;
        int i;
        begin
            for (i = 0; i < 8; i++) begin
                configure_emulator(
                    i,
                    measure_hit_rate_lane[i],
                    measure_noise_rate_lane[i],
                    measure_short_mode,
                    measure_hit_mode_lane[i],
                    measure_burst_size_lane[i],
                    measure_burst_center_lane[i]
                );
            end
        end
    endtask

    task automatic hist0_ctrl_read(
        output logic [31:0] data
    );
        begin
            avmm_read32(HIST0_CSR_CONTROL, data);
        end
    endtask

    task automatic configure_hist_channel_rate(
        input logic [31:0] interval_clocks
    );
        begin
            avmm_write32(HIST0_CSR_LEFT,      32'h0000_0000);
            avmm_write32(HIST0_CSR_BIN_WIDTH, 32'h0000_0001);
            avmm_write32(HIST0_CSR_KEY_LOC,   32'h2828_2424);
            avmm_write32(HIST0_CSR_KEY_VALUE, 32'h0000_0000);
            avmm_write32(HIST0_CSR_INTERVAL,  interval_clocks);
            avmm_write32(HIST0_CSR_CONTROL,   32'h0000_0101);
        end
    endtask

    task automatic read_hist0_status(
        output logic [31:0] bank_status,
        output logic [31:0] total_hits,
        output logic [31:0] dropped_hits,
        output logic [31:0] underflow_hits,
        output logic [31:0] overflow_hits
    );
        begin
            avmm_read32(HIST0_CSR_BANK,      bank_status);
            avmm_read32(HIST0_CSR_TOTAL,     total_hits);
            avmm_read32(HIST0_CSR_DROPPED,   dropped_hits);
            avmm_read32(HIST0_CSR_UNDERFLOW, underflow_hits);
            avmm_read32(HIST0_CSR_OVERFLOW,  overflow_hits);
        end
    endtask

    task automatic wait_hist0_cfg_applied;
        int unsigned cycles;
        logic [31:0] value;
        begin
            cycles = 0;
            while (1'b1) begin
                hist0_ctrl_read(value);
                if (value[1] == 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_READ_TIMEOUT)
                    $fatal(1, "Histogram cfg_apply_pending stuck high ctrl=0x%08h", value);
            end

            if (value[24] == 1'b1)
                $fatal(1, "Histogram configuration error ctrl=0x%08h", value);
        end
    endtask

    task automatic clear_hist0;
        begin
            avmm_write32(HIST0_BIN_BASE, 32'h0000_0000);
        end
    endtask

    task automatic hist0_summary(
        output int unsigned total_hits,
        output int unsigned active_bins,
        output int unsigned min_nonzero,
        output int unsigned max_nonzero
    );
        logic [31:0] value;
        begin
            total_hits  = 0;
            active_bins = 0;
            min_nonzero = '1;
            max_nonzero = 0;
            for (int idx = 0; idx < 256; idx++) begin
                avmm_read32(HIST0_BIN_BASE + idx[13:0], value);
                total_hits += value;
                if (value != 0) begin
                    active_bins++;
                    if (value < min_nonzero)
                        min_nonzero = value;
                    if (value > max_nonzero)
                        max_nonzero = value;
                end
            end
            if (active_bins == 0)
                min_nonzero = 0;
        end
    endtask

    task automatic wait_for_hist_total_at_least(
        input int unsigned min_total,
        input int unsigned min_active_bins,
        input time         timeout_window,
        input time         poll_period
    );
        time waited;
        begin
            waited = 0ns;
            while (waited < timeout_window) begin
                hist0_summary(hist_total_hits, hist_active_bins, hist_min_nonzero, hist_max_nonzero);
                if ((hist_total_hits >= min_total) && (hist_active_bins >= min_active_bins))
                    return;
                #(poll_period);
                waited += poll_period;
            end

            $fatal(
                1,
                "Histogram alive threshold not reached within %0t: total=%0d active=%0d min_nonzero=%0d max_nonzero=%0d",
                timeout_window,
                hist_total_hits,
                hist_active_bins,
                hist_min_nonzero,
                hist_max_nonzero
            );
        end
    endtask

    task automatic local_hist_idle;
        begin
            rate_hist_bin_address    = '0;
            rate_hist_bin_burstcount = '0;
            rate_hist_bin_writedata  = '0;
            rate_hist_bin_read       = 1'b0;
            rate_hist_bin_write      = 1'b0;
            rate_hist_csr_address    = '0;
            rate_hist_csr_read       = 1'b0;
            rate_hist_csr_write      = 1'b0;
            rate_hist_csr_writedata  = '0;

            lat_hist_bin_address     = '0;
            lat_hist_bin_burstcount  = '0;
            lat_hist_bin_writedata   = '0;
            lat_hist_bin_read        = 1'b0;
            lat_hist_bin_write       = 1'b0;
            lat_hist_csr_address     = '0;
            lat_hist_csr_read        = 1'b0;
            lat_hist_csr_write       = 1'b0;
            lat_hist_csr_writedata   = '0;
        end
    endtask

    task automatic local_hist_csr_write(
        input bit         rate_sel,
        input logic [4:0] addr,
        input logic [31:0] data
    );
        int unsigned cycles;
        begin
            if (rate_sel) @(posedge lvds_outclock);
            else          @(posedge clk_125);
            if (rate_sel) begin
                rate_hist_csr_address   <= addr;
                rate_hist_csr_writedata <= data;
                rate_hist_csr_write     <= 1'b1;
                rate_hist_csr_read      <= 1'b0;
            end else begin
                lat_hist_csr_address    <= addr;
                lat_hist_csr_writedata  <= data;
                lat_hist_csr_write      <= 1'b1;
                lat_hist_csr_read       <= 1'b0;
            end

            cycles = 0;
            while (1'b1) begin
                if (rate_sel) @(posedge lvds_outclock);
                else          @(posedge clk_125);
                if ((rate_sel ? rate_hist_csr_waitrequest : lat_hist_csr_waitrequest) === 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_ACCEPT_TIMEOUT)
                    $fatal(1, "Local histogram CSR write accept timeout rate_sel=%0d addr=%0d data=0x%08h", rate_sel, addr, data);
            end

            if (rate_sel) begin
                rate_hist_csr_write     <= 1'b0;
                rate_hist_csr_address   <= '0;
                rate_hist_csr_writedata <= '0;
            end else begin
                lat_hist_csr_write      <= 1'b0;
                lat_hist_csr_address    <= '0;
                lat_hist_csr_writedata  <= '0;
            end
            if (rate_sel) @(posedge lvds_outclock);
            else          @(posedge clk_125);
        end
    endtask

    task automatic local_hist_csr_read(
        input  bit         rate_sel,
        input  logic [4:0] addr,
        output logic [31:0] data
    );
        int unsigned cycles;
        begin
            if (rate_sel) @(posedge lvds_outclock);
            else          @(posedge clk_125);
            if (rate_sel) begin
                rate_hist_csr_address <= addr;
                rate_hist_csr_read    <= 1'b1;
                rate_hist_csr_write   <= 1'b0;
            end else begin
                lat_hist_csr_address  <= addr;
                lat_hist_csr_read     <= 1'b1;
                lat_hist_csr_write    <= 1'b0;
            end

            cycles = 0;
            while (1'b1) begin
                if (rate_sel) @(posedge lvds_outclock);
                else          @(posedge clk_125);
                if ((rate_sel ? rate_hist_csr_waitrequest : lat_hist_csr_waitrequest) === 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_ACCEPT_TIMEOUT)
                    $fatal(1, "Local histogram CSR read accept timeout rate_sel=%0d addr=%0d", rate_sel, addr);
            end

            if (rate_sel) begin
                rate_hist_csr_read    <= 1'b0;
                rate_hist_csr_address <= '0;
            end else begin
                lat_hist_csr_read     <= 1'b0;
                lat_hist_csr_address  <= '0;
            end

            if (rate_sel) @(posedge lvds_outclock);
            else          @(posedge clk_125);
            data = rate_sel ? rate_hist_csr_readdata : lat_hist_csr_readdata;
        end
    endtask

    task automatic local_hist_bin_write(
        input bit          rate_sel,
        input int unsigned addr,
        input logic [31:0] data
    );
        int unsigned cycles;
        begin
            if (rate_sel) @(posedge lvds_outclock);
            else          @(posedge clk_125);
            if (rate_sel) begin
                rate_hist_bin_address    <= RATE_HIST_ADDR_W'(addr);
                rate_hist_bin_writedata  <= data;
                rate_hist_bin_burstcount <= 'd1;
                rate_hist_bin_write      <= 1'b1;
                rate_hist_bin_read       <= 1'b0;
            end else begin
                lat_hist_bin_address     <= LAT_HIST_ADDR_W'(addr);
                lat_hist_bin_writedata   <= data;
                lat_hist_bin_burstcount  <= 'd1;
                lat_hist_bin_write       <= 1'b1;
                lat_hist_bin_read        <= 1'b0;
            end

            cycles = 0;
            while (1'b1) begin
                if (rate_sel) @(posedge lvds_outclock);
                else          @(posedge clk_125);
                if ((rate_sel ? rate_hist_bin_waitrequest : lat_hist_bin_waitrequest) === 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_ACCEPT_TIMEOUT)
                    $fatal(1, "Local histogram bin write accept timeout rate_sel=%0d addr=%0d data=0x%08h", rate_sel, addr, data);
            end

            if (rate_sel) begin
                rate_hist_bin_write      <= 1'b0;
                rate_hist_bin_address    <= '0;
                rate_hist_bin_writedata  <= '0;
                rate_hist_bin_burstcount <= '0;
            end else begin
                lat_hist_bin_write       <= 1'b0;
                lat_hist_bin_address     <= '0;
                lat_hist_bin_writedata   <= '0;
                lat_hist_bin_burstcount  <= '0;
            end
            if (rate_sel) @(posedge lvds_outclock);
            else          @(posedge clk_125);
        end
    endtask

    task automatic local_hist_bin_read(
        input  bit          rate_sel,
        input  int unsigned addr,
        output logic [31:0] data
    );
        int unsigned cycles;
        begin
            if (rate_sel) @(posedge lvds_outclock);
            else          @(posedge clk_125);
            if (rate_sel) begin
                rate_hist_bin_address    <= RATE_HIST_ADDR_W'(addr);
                rate_hist_bin_burstcount <= 'd1;
                rate_hist_bin_read       <= 1'b1;
                rate_hist_bin_write      <= 1'b0;
            end else begin
                lat_hist_bin_address     <= LAT_HIST_ADDR_W'(addr);
                lat_hist_bin_burstcount  <= 'd1;
                lat_hist_bin_read        <= 1'b1;
                lat_hist_bin_write       <= 1'b0;
            end

            cycles = 0;
            while (1'b1) begin
                if (rate_sel) @(posedge lvds_outclock);
                else          @(posedge clk_125);
                if ((rate_sel ? rate_hist_bin_waitrequest : lat_hist_bin_waitrequest) === 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_ACCEPT_TIMEOUT)
                    $fatal(1, "Local histogram bin read accept timeout rate_sel=%0d addr=%0d", rate_sel, addr);
            end

            if (rate_sel) begin
                rate_hist_bin_read       <= 1'b0;
                rate_hist_bin_address    <= '0;
                rate_hist_bin_burstcount <= '0;
            end else begin
                lat_hist_bin_read        <= 1'b0;
                lat_hist_bin_address     <= '0;
                lat_hist_bin_burstcount  <= '0;
            end

            cycles = 0;
            while (1'b1) begin
                if (rate_sel) @(posedge lvds_outclock);
                else          @(posedge clk_125);
                if ((rate_sel ? rate_hist_bin_readdatavalid : lat_hist_bin_readdatavalid) === 1'b1)
                    break;
                cycles++;
                if (cycles > AVMM_READ_TIMEOUT)
                    $fatal(1, "Local histogram bin read data timeout rate_sel=%0d addr=%0d", rate_sel, addr);
            end

            data = rate_sel ? rate_hist_bin_readdata : lat_hist_bin_readdata;
        end
    endtask

    task automatic wait_local_hist_cfg_applied(input bit rate_sel);
        int unsigned cycles;
        logic [31:0] value;
        begin
            cycles = 0;
            while (1'b1) begin
                local_hist_csr_read(rate_sel, HIST_CSR_CONTROL, value);
                if (value[1] == 1'b0)
                    break;
                cycles++;
                if (cycles > AVMM_READ_TIMEOUT)
                    $fatal(1, "Local histogram cfg_apply_pending stuck high rate_sel=%0d ctrl=0x%08h", rate_sel, value);
            end

            if (value[24] == 1'b1)
                $fatal(1, "Local histogram configuration error rate_sel=%0d ctrl=0x%08h", rate_sel, value);
        end
    endtask

    task automatic configure_rate_hist(input logic [31:0] interval_clocks);
        begin
            local_hist_csr_write(1'b1, HIST_CSR_LEFT,      32'h0000_0000);
            local_hist_csr_write(1'b1, HIST_CSR_BIN_WIDTH, 32'h0000_0001);
            local_hist_csr_write(1'b1, HIST_CSR_KEY_LOC,   32'h0400_0400);
            local_hist_csr_write(1'b1, HIST_CSR_INTERVAL,  32'h0000_0000);
            local_hist_csr_write(1'b1, HIST_CSR_CONTROL,   32'h0000_0101);
        end
    endtask

    task automatic configure_latency_hist(input logic [31:0] interval_clocks);
        begin
            local_hist_csr_write(1'b0, HIST_CSR_LEFT,      32'h0000_0000);
            local_hist_csr_write(1'b0, HIST_CSR_BIN_WIDTH, 32'h0000_0001);
            local_hist_csr_write(1'b0, HIST_CSR_KEY_LOC,   32'h0F00_0F00);
            local_hist_csr_write(1'b0, HIST_CSR_INTERVAL,  32'h0000_0000);
            local_hist_csr_write(1'b0, HIST_CSR_CONTROL,   32'h0000_0101);
        end
    endtask

    task automatic clear_local_hist(input bit rate_sel);
        begin
            local_hist_bin_write(rate_sel, '0, 32'h0000_0000);
        end
    endtask

    task automatic wait_local_hist_quiescent(
        input bit          rate_sel,
        input int unsigned max_polls
    );
        logic [31:0] bank_status;
        logic [31:0] port_status;
        logic [31:0] coal_status;
        int unsigned polls;
        begin
            polls = 0;
            while (1'b1) begin
                local_hist_csr_read(rate_sel, HIST_CSR_BANK, bank_status);
                local_hist_csr_read(rate_sel, HIST_CSR_PORT, port_status);
                local_hist_csr_read(rate_sel, HIST_CSR_COAL, coal_status);
                if ((bank_status[1] == 1'b0) && (port_status[7:0] == 8'hff) && (coal_status[7:0] == 8'h00))
                    break;
                polls++;
                if (polls > max_polls) begin
                    $fatal(
                        1,
                        "Local histogram quiescent timeout rate_sel=%0d bank=0x%08h port=0x%08h coal=0x%08h",
                        rate_sel,
                        bank_status,
                        port_status,
                        coal_status
                    );
                end
            end
        end
    endtask

    task automatic freeze_local_hist(input bit rate_sel);
        begin
            local_hist_csr_write(rate_sel, HIST_CSR_CONTROL, 32'h0000_0000);
            wait_local_hist_cfg_applied(rate_sel);
        end
    endtask

    task automatic wait_local_hist_drained(
        input bit          rate_sel,
        input int unsigned max_polls
    );
        logic [31:0] port_status;
        logic [31:0] coal_status;
        int unsigned polls;
        begin
            polls = 0;
            while (1'b1) begin
                local_hist_csr_read(rate_sel, HIST_CSR_PORT, port_status);
                local_hist_csr_read(rate_sel, HIST_CSR_COAL, coal_status);
                if (port_status[7:0] == 8'hff && coal_status[7:0] == 8'h00)
                    break;
                polls++;
                if (polls > max_polls)
                    $fatal(1, "Local histogram drain timeout rate_sel=%0d port=0x%08h coal=0x%08h", rate_sel, port_status, coal_status);
            end
        end
    endtask

    task automatic local_hist_read_status(
        input  bit          rate_sel,
        output logic [31:0] ctrl_word,
        output logic [31:0] total_hits,
        output logic [31:0] dropped_hits,
        output logic [31:0] underflow_hits,
        output logic [31:0] overflow_hits
    );
        begin
            local_hist_csr_read(rate_sel, HIST_CSR_CONTROL,   ctrl_word);
            local_hist_csr_read(rate_sel, HIST_CSR_TOTAL,     total_hits);
            local_hist_csr_read(rate_sel, HIST_CSR_DROPPED,   dropped_hits);
            local_hist_csr_read(rate_sel, HIST_CSR_UNDERFLOW, underflow_hits);
            local_hist_csr_read(rate_sel, HIST_CSR_OVERFLOW,  overflow_hits);
        end
    endtask

    task automatic local_hist_summary(
        input  bit          rate_sel,
        input  int unsigned n_bins,
        output int unsigned total_hits,
        output int unsigned active_bins,
        output int unsigned min_nonzero,
        output int unsigned max_nonzero,
        output int          peak_bin
    );
        logic [31:0] value;
        begin
            total_hits  = 0;
            active_bins = 0;
            min_nonzero = '1;
            max_nonzero = 0;
            peak_bin    = -1;
            for (int idx = 0; idx < n_bins; idx++) begin
                local_hist_bin_read(rate_sel, idx, value);
                total_hits += value;
                if (value != 0) begin
                    active_bins++;
                    if (value < min_nonzero)
                        min_nonzero = value;
                    if (value > max_nonzero) begin
                        max_nonzero = value;
                        peak_bin    = idx;
                    end
                end
            end
            if (active_bins == 0)
                min_nonzero = 0;
        end
    endtask

    task automatic dump_rate_hist_csv(input string path);
        int fd;
        logic [31:0] value;
        begin
            fd = $fopen(path, "w");
            if (fd == 0)
                $fatal(1, "Failed to open rate histogram CSV %s", path);
            $fwrite(fd, "bin,asic,channel,count\n");
            for (int idx = 0; idx < 256; idx++) begin
                local_hist_bin_read(1'b1, idx, value);
                $fwrite(fd, "%0d,%0d,%0d,%0d\n", idx, (idx >> 5) & 3'h7, idx & 5'h1f, value);
            end
            $fclose(fd);
        end
    endtask

    task automatic dump_latency_hist_csv(input string path);
        int fd;
        logic [31:0] value;
        begin
            fd = $fopen(path, "w");
            if (fd == 0)
                $fatal(1, "Failed to open latency histogram CSV %s", path);
            $fwrite(fd, "latency_cycles,count\n");
            for (int idx = 0; idx < LAT_HIST_BINS; idx++) begin
                local_hist_bin_read(1'b0, idx, value);
                $fwrite(fd, "%0d,%0d\n", idx, value);
            end
            $fclose(fd);
        end
    endtask

    task automatic flush_pre_rbcam_hist_shadow(input int unsigned max_cycles);
        int unsigned cycles;
        int unsigned rr_lane;
        bit          drained;
        logic [4:0]  channel_v;
        begin
            cycles  = 0;
            rr_lane = 0;
            while (1'b1) begin
                drained = 1'b1;
                for (int lane = 0; lane < 8; lane++) begin
                    if (pre_rbcam_hist_queue[lane].size() != 0)
                        drained = 1'b0;
                end
                if (drained)
                    break;

                @(negedge lvds_outclock);
                pre_rbcam_hist_stream_valid   = '0;
                pre_rbcam_hist_stream_sop     = '0;
                pre_rbcam_hist_stream_eop     = '0;
                pre_rbcam_hist_stream_data    = '0;
                pre_rbcam_hist_stream_channel = '0;
                for (int ofs = 0; ofs < 8; ofs++) begin
                    int lane;
                    lane = (rr_lane + ofs) % 8;
                    if (pre_rbcam_hist_queue[lane].size() != 0) begin
                        channel_v = pre_rbcam_hist_queue[lane].pop_front();
                        pre_rbcam_hist_stream_valid[lane] = 1'b1;
                        pre_rbcam_hist_stream_data[(lane*5) +: 5] = channel_v;
                        rr_lane = (lane + 1) % 8;
                        break;
                    end
                end

                cycles++;
                if (cycles > max_cycles)
                    $fatal(1, "Pre-RBCAM histogram shadow flush timeout after %0d cycles", cycles);
            end

            @(negedge lvds_outclock);
            pre_rbcam_hist_stream_valid   = '0;
            pre_rbcam_hist_stream_sop     = '0;
            pre_rbcam_hist_stream_eop     = '0;
            pre_rbcam_hist_stream_data    = '0;
            pre_rbcam_hist_stream_channel = '0;
        end
    endtask

    task automatic flush_latency_hist_shadow(input int unsigned max_cycles);
        int unsigned cycles;
        int unsigned rr_lane;
        bit          drained;
        logic [15:0] latency_v;
        begin
            cycles  = 0;
            rr_lane = 0;
            while (1'b1) begin
                drained = 1'b1;
                for (int lane = 0; lane < 8; lane++) begin
                    if (emu_lat_hist_queue[lane].size() != 0)
                        drained = 1'b0;
                end
                if (drained)
                    break;

                @(negedge clk_125);
                emu_lat_hist_stream_valid   = '0;
                emu_lat_hist_stream_sop     = '0;
                emu_lat_hist_stream_eop     = '0;
                emu_lat_hist_stream_data    = '0;
                emu_lat_hist_stream_channel = '0;
                for (int ofs = 0; ofs < 8; ofs++) begin
                    int lane;
                    lane = (rr_lane + ofs) % 8;
                    if (emu_lat_hist_queue[lane].size() != 0) begin
                        latency_v = emu_lat_hist_queue[lane].pop_front();
                        emu_lat_hist_stream_valid[lane] = 1'b1;
                        emu_lat_hist_stream_data[(lane*16) +: 16] = latency_v;
                        rr_lane = (lane + 1) % 8;
                        break;
                    end
                end

                cycles++;
                if (cycles > max_cycles)
                    $fatal(1, "Latency histogram shadow flush timeout after %0d cycles", cycles);
            end

            @(negedge clk_125);
            emu_lat_hist_stream_valid   = '0;
            emu_lat_hist_stream_sop     = '0;
            emu_lat_hist_stream_eop     = '0;
            emu_lat_hist_stream_data    = '0;
            emu_lat_hist_stream_channel = '0;
        end
    endtask

    task automatic report_emulator_status(input string tag);
        int i;
        logic [31:0] status_word;
        logic [15:0] frame_count_word;
        logic [9:0]  event_count_word;
        begin
            for (i = 0; i < 8; i++) begin
                emu_read32_local(i, 4'd5, status_word);
                frame_count_word = status_word[15:0];
                event_count_word = status_word[25:16];
                $display(
                    "TB_EMU_STATUS %s lane=%0d frame_count=%0d event_count=%0d status=0x%08h",
                    tag, i, frame_count_word, event_count_word, status_word
                );
            end
        end
    endtask

    scifi_dp_emu_live_wrapper_v3 dut_wrap (
        .lvds_pll_inclock_clk           (clk_125),
        .osc_clock_50_in_clk            (clk_50),
        .avmm_clk_clk                   (clk_50),
        .monitor_clock_125_in_clk       (clk_125),
        .xcvr_clock_clk                 (clk_125),

        .avmm_rst_reset                 (avmm_rst),
        .counter_sclr_reset             (counter_sclr),
        .monitor_reset_in_reset_reset_n (monitor_rst_n),
        .xcvr_reset_reset_n             (xcvr_rst_n),

        .serial_data                    (9'b0),
        .redriver_losn                  (9'h1FF),

        .runctl_mgmt_host_data          (runctl_data),
        .runctl_mgmt_host_valid         (runctl_valid),
        .runctl_mgmt_host_ready         (runctl_ready),

        .hit_type3_lower_data           (hit_lower_data),
        .hit_type3_lower_valid          (hit_lower_valid),
        .hit_type3_lower_ready          (1'b1),
        .hit_type3_lower_startofpacket  (hit_lower_sop),
        .hit_type3_lower_endofpacket    (hit_lower_eop),
        .hit_type3_upper_data           (hit_upper_data),
        .hit_type3_upper_valid          (hit_upper_valid),
        .hit_type3_upper_ready          (1'b1),
        .hit_type3_upper_startofpacket  (hit_upper_sop),
        .hit_type3_upper_endofpacket    (hit_upper_eop),

        .inject_pulse                   (inject_pulse),
        .lvds_outclock_clk              (lvds_outclock),
        .mutrig_reset_reset             (mutrig_reset),
        .rstlink_data                   (rstlink_data),
        .rstlink_channel                (rstlink_channel),
        .rstlink_error                  (rstlink_error),

        .avmm_port_waitrequest          (avmm_waitrequest),
        .avmm_port_readdata             (avmm_readdata),
        .avmm_port_readdatavalid        (avmm_readdatavalid),
        .avmm_port_burstcount           (avmm_burstcount),
        .avmm_port_writedata            (avmm_writedata),
        .avmm_port_address              (avmm_address),
        .avmm_port_write                (avmm_write),
        .avmm_port_read                 (avmm_read),
        .avmm_port_byteenable           (avmm_byteenable),
        .avmm_port_debugaccess          (avmm_debugaccess)
    );

    tb_int_histogram_wrap #(
        .G_UPDATE_KEY_BIT_HI         (4),
        .G_UPDATE_KEY_BIT_LO         (0),
        .G_UPDATE_KEY_REPRESENTATION ("UNSIGNED"),
        .G_FILTER_KEY_BIT_HI         (4),
        .G_FILTER_KEY_BIT_LO         (0),
        .G_SAR_TICK_WIDTH            (16),
        .G_SAR_KEY_WIDTH             (5),
        .G_N_BINS                    (256),
        .G_DEF_LEFT_BOUND            (0),
        .G_DEF_BIN_WIDTH             (1),
        .G_AVS_ADDR_WIDTH            (RATE_HIST_ADDR_W),
        .G_N_PORTS                   (8),
        .G_CHANNELS_PER_PORT         (32),
        .G_COAL_QUEUE_DEPTH          (256),
        .G_ENABLE_PINGPONG           (1'b0),
        .G_DEF_INTERVAL_CLOCKS       (0),
        .G_AVST_DATA_WIDTH           (5),
        .G_AVST_CHANNEL_WIDTH        (1),
        .G_SNOOP_EN                  (1'b0),
        .G_ENABLE_PACKET             (1'b0)
    ) u_pre_rbcam_rate_hist (
        .i_clk                       (lvds_outclock),
        .i_rst                       (avmm_rst || !xcvr_rst_n),
        .i_interval_reset            (1'b0),
        .i_stream_valid              (pre_rbcam_hist_stream_valid),
        .i_stream_sop                (pre_rbcam_hist_stream_sop),
        .i_stream_eop                (pre_rbcam_hist_stream_eop),
        .i_stream_data               (pre_rbcam_hist_stream_data),
        .i_stream_channel            (pre_rbcam_hist_stream_channel),
        .o_stream_ready              (pre_rbcam_hist_stream_ready),
        .avs_hist_bin_readdata       (rate_hist_bin_readdata),
        .avs_hist_bin_read           (rate_hist_bin_read),
        .avs_hist_bin_address        (rate_hist_bin_address),
        .avs_hist_bin_waitrequest    (rate_hist_bin_waitrequest),
        .avs_hist_bin_write          (rate_hist_bin_write),
        .avs_hist_bin_writedata      (rate_hist_bin_writedata),
        .avs_hist_bin_burstcount     (rate_hist_bin_burstcount),
        .avs_hist_bin_readdatavalid  (rate_hist_bin_readdatavalid),
        .avs_hist_bin_writerespvalid (rate_hist_bin_writerespvalid),
        .avs_hist_bin_response       (rate_hist_bin_response),
        .avs_csr_readdata            (rate_hist_csr_readdata),
        .avs_csr_read                (rate_hist_csr_read),
        .avs_csr_address             (rate_hist_csr_address),
        .avs_csr_waitrequest         (rate_hist_csr_waitrequest),
        .avs_csr_write               (rate_hist_csr_write),
        .avs_csr_writedata           (rate_hist_csr_writedata)
    );

    tb_int_histogram_wrap #(
        .G_UPDATE_KEY_BIT_HI         (15),
        .G_UPDATE_KEY_BIT_LO         (0),
        .G_UPDATE_KEY_REPRESENTATION ("UNSIGNED"),
        .G_FILTER_KEY_BIT_HI         (15),
        .G_FILTER_KEY_BIT_LO         (0),
        .G_SAR_TICK_WIDTH            (16),
        .G_SAR_KEY_WIDTH             (16),
        .G_N_BINS                    (LAT_HIST_BINS),
        .G_DEF_LEFT_BOUND            (0),
        .G_DEF_BIN_WIDTH             (1),
        .G_AVS_ADDR_WIDTH            (LAT_HIST_ADDR_W),
        .G_N_PORTS                   (8),
        .G_CHANNELS_PER_PORT         (1),
        .G_COAL_QUEUE_DEPTH          (256),
        .G_ENABLE_PINGPONG           (1'b0),
        .G_DEF_INTERVAL_CLOCKS       (0),
        .G_AVST_DATA_WIDTH           (16),
        .G_AVST_CHANNEL_WIDTH        (1),
        .G_SNOOP_EN                  (1'b0),
        .G_ENABLE_PACKET             (1'b0)
    ) u_emu_latency_hist (
        .i_clk                       (clk_125),
        .i_rst                       (avmm_rst || !xcvr_rst_n),
        .i_interval_reset            (1'b0),
        .i_stream_valid              (emu_lat_hist_stream_valid),
        .i_stream_sop                (emu_lat_hist_stream_sop),
        .i_stream_eop                (emu_lat_hist_stream_eop),
        .i_stream_data               (emu_lat_hist_stream_data),
        .i_stream_channel            (emu_lat_hist_stream_channel),
        .o_stream_ready              (emu_lat_hist_stream_ready),
        .avs_hist_bin_readdata       (lat_hist_bin_readdata),
        .avs_hist_bin_read           (lat_hist_bin_read),
        .avs_hist_bin_address        (lat_hist_bin_address),
        .avs_hist_bin_waitrequest    (lat_hist_bin_waitrequest),
        .avs_hist_bin_write          (lat_hist_bin_write),
        .avs_hist_bin_writedata      (lat_hist_bin_writedata),
        .avs_hist_bin_burstcount     (lat_hist_bin_burstcount),
        .avs_hist_bin_readdatavalid  (lat_hist_bin_readdatavalid),
        .avs_hist_bin_writerespvalid (lat_hist_bin_writerespvalid),
        .avs_hist_bin_response       (lat_hist_bin_response),
        .avs_csr_readdata            (lat_hist_csr_readdata),
        .avs_csr_read                (lat_hist_csr_read),
        .avs_csr_address             (lat_hist_csr_address),
        .avs_csr_waitrequest         (lat_hist_csr_waitrequest),
        .avs_csr_write               (lat_hist_csr_write),
        .avs_csr_writedata           (lat_hist_csr_writedata)
    );

    always @(negedge lvds_outclock or posedge avmm_rst or negedge xcvr_rst_n) begin
        if (avmm_rst || !xcvr_rst_n) begin
            pre_rbcam_hist_stream_valid   <= '0;
            pre_rbcam_hist_stream_sop     <= '0;
            pre_rbcam_hist_stream_eop     <= '0;
            pre_rbcam_hist_stream_data    <= '0;
            pre_rbcam_hist_stream_channel <= '0;
            for (int lane = 0; lane < 8; lane++)
                pre_rbcam_hist_queue[lane].delete();
        end else begin
            logic [3:0] asic_v;
            logic [4:0] channel_v;

            if (dut_wrap.dut.mts_preprocessor_0_hit_type1_out_valid
             && dut_wrap.dut.mts_preprocessor_0_hit_type1_out_ready
             && !dut_wrap.dut.mts_preprocessor_0_hit_type1_out_endofpacket) begin
                asic_v = dut_wrap.dut.mts_preprocessor_0_hit_type1_out_data[38:35];
                channel_v = dut_wrap.dut.mts_preprocessor_0_hit_type1_out_data[34:30];
                if (asic_v < 8)
                    pre_rbcam_hist_queue[asic_v].push_back(channel_v);
            end

            if (dut_wrap.dut.mts_preprocessor_1_hit_type1_out_valid
             && dut_wrap.dut.mts_preprocessor_1_hit_type1_out_ready
             && !dut_wrap.dut.mts_preprocessor_1_hit_type1_out_endofpacket) begin
                asic_v = dut_wrap.dut.mts_preprocessor_1_hit_type1_out_data[38:35];
                channel_v = dut_wrap.dut.mts_preprocessor_1_hit_type1_out_data[34:30];
                if (asic_v < 8)
                    pre_rbcam_hist_queue[asic_v].push_back(channel_v);
            end

        end
    end

    always @(negedge lvds_outclock or posedge avmm_rst or negedge xcvr_rst_n) begin
        if (avmm_rst || !xcvr_rst_n) begin
            lvds_cycle               <= 0;
            for (int lane = 0; lane < 8; lane++) begin
                emu_live_cycle_q[lane].delete();
                emu_frozen_cycle_q[lane].delete();
                emu_live_depth_max[lane]       <= 0;
                emu_frozen_depth_max[lane]     <= 0;
                emu_live_overwrite_count[lane] <= 0;
            end
        end else begin
            int             live_depth_v;
            int             frozen_depth_v;
            longint signed  bank_gts_skew_v;
            longint unsigned next_hit_id_v;
            longint unsigned current_tick_v;
            trace_hit_t     trace_hit_v;
            longint unsigned expected_mod_v;

            lvds_cycle                 <= lvds_cycle + 1;
            current_tick_v             = measure_tick_8ns();

            bank_gts_skew_v = $signed(bank_gts8n(0)) - $signed(bank_gts8n(1));
            if (bank_gts_skew_v < 0)
                bank_gts_skew_v = -bank_gts_skew_v;
            if (bank_gts_skew_v > trace_bank_gts_skew_max)
                trace_bank_gts_skew_max = bank_gts_skew_v;

            next_hit_id_v = trace_next_hit_id;

            for (int lane = 0; lane < 8; lane++) begin
                if (emu_frame_start[lane]) begin
                    emu_frozen_cycle_q[lane] = emu_live_cycle_q[lane];
                    emu_frozen_trace_q[lane] = emu_live_trace_q[lane];
                    emu_live_cycle_q[lane].delete();
                    emu_live_trace_q[lane].delete();
                end

                if (emu_hit_wr_en[lane]) begin
                    if (emu_live_cycle_q[lane].size() >= EMU_L2_DEPTH) begin
                        void'(emu_live_cycle_q[lane].pop_front());
                        void'(emu_live_trace_q[lane].pop_front());
                        emu_live_overwrite_count[lane] <= emu_live_overwrite_count[lane] + 1;
                    end
                    emu_live_cycle_q[lane].push_back(current_tick_v);

                    trace_hit_v.hit_id            = next_hit_id_v;
                    trace_hit_v.gen_lvds_cycle    = lvds_cycle;
                    trace_hit_v.gen_gts8n         = lane_true_gts8n(lane);
                    trace_hit_v.raw_word          = lane_hit_wr_data(lane);
                    trace_hit_v.asic             = lane_asic_id(lane);
                    trace_hit_v.channel          = trace_hit_v.raw_word[47:43];
                    trace_hit_v.tcc_dark         = trace_hit_v.raw_word[41:27];
                    trace_hit_v.ecc_dark         = trace_hit_v.raw_word[20:6];
                    trace_hit_v.t_fine           = trace_hit_v.raw_word[26:22];
                    trace_hit_v.e_flag           = trace_hit_v.raw_word[0];
                    trace_hit_v.bank             = (lane < 4) ? 0 : 1;
                    trace_hit_v.type0_word       = build_expected_type0(
                        trace_hit_v.asic,
                        lane_tx_mode(lane),
                        trace_hit_v.raw_word
                    );
                    trace_hit_v.tcc_white_1n6_mod = dark_to_white_mod_1n6(trace_hit_v.tcc_dark);
                    trace_hit_v.ecc_white_1n6_mod = dark_to_white_mod_1n6(trace_hit_v.ecc_dark);
                    emu_live_trace_q[lane].push_back(trace_hit_v);
                    next_hit_id_v                = next_hit_id_v + 1;
                    if (trace_detail_fd != 0) begin
                        $fdisplay(
                            trace_detail_fd,
                            "GEN,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%012h",
                            lane,
                            trace_hit_v.asic,
                            trace_hit_v.hit_id,
                            trace_hit_v.channel,
                            trace_hit_v.gen_lvds_cycle,
                            trace_hit_v.gen_gts8n,
                            trace_hit_v.tcc_dark,
                            trace_hit_v.ecc_dark,
                            trace_hit_v.t_fine,
                            trace_hit_v.raw_word
                        );
                    end

                    expected_mod_v = true_mod_1n6_from_gts(trace_hit_v.gen_gts8n);
                    if (trace_hit_v.tcc_white_1n6_mod != expected_mod_v
                     || trace_hit_v.ecc_white_1n6_mod != expected_mod_v) begin
                        trace_gen_mod_mismatch_count = trace_gen_mod_mismatch_count + 1;
                        if (!trace_gen_mod_offset_seen) begin
                            trace_gen_mod_offset_seen  = 1'b1;
                            trace_gen_mod_offset_first = $signed(trace_hit_v.tcc_white_1n6_mod) - $signed(expected_mod_v);
                        end
                        if (trace_ts_enable && (trace_mismatch_print_count < trace_mismatch_limit)) begin
                            trace_mismatch_print_count = trace_mismatch_print_count + 1;
                            $display(
                                "TB_TS_TRACE GEN_MOD lane=%0d hit_id=%0d gen_gts=%0d exp_mod=%0d tcc_mod=%0d ecc_mod=%0d raw=0x%012h",
                                lane,
                                trace_hit_v.hit_id,
                                trace_hit_v.gen_gts8n,
                                expected_mod_v,
                                trace_hit_v.tcc_white_1n6_mod,
                                trace_hit_v.ecc_white_1n6_mod,
                                trace_hit_v.raw_word
                            );
                            if (trace_detail_fd != 0) begin
                                $fdisplay(
                                    trace_detail_fd,
                                    "GEN_MOD,%0d,%0d,%0d,%0d,%0d,%0d,0x%012h",
                                    lane,
                                    trace_hit_v.hit_id,
                                    trace_hit_v.gen_gts8n,
                                    expected_mod_v,
                                    trace_hit_v.tcc_white_1n6_mod,
                                    trace_hit_v.ecc_white_1n6_mod,
                                    trace_hit_v.raw_word
                                );
                            end
                        end
                    end
                end

                live_depth_v = emu_live_cycle_q[lane].size();
                if (live_depth_v > emu_live_depth_max[lane])
                    emu_live_depth_max[lane] <= live_depth_v;

                frozen_depth_v = emu_frozen_cycle_q[lane].size();
                if (frozen_depth_v > emu_frozen_depth_max[lane])
                    emu_frozen_depth_max[lane] <= frozen_depth_v;
            end

            trace_next_hit_id = next_hit_id_v;
        end
    end

    always @(posedge clk_125 or posedge avmm_rst or negedge xcvr_rst_n) begin
        if (avmm_rst || !xcvr_rst_n) begin
            emu_lat_underflow_count     <= 0;
            for (int lane = 0; lane < 8; lane++)
                emu_lat_hist_queue[lane].delete();
        end else begin
            int unsigned    latency_cycles_v;
            trace_hit_t     expect_hit_v;
            logic [44:0]    actual_type0_v;
            logic [44:0]    mts_in_data_v;
            logic [38:0]    mts_out_data_v;
            int unsigned    lane_from_asic_v;
            longint unsigned bank_gts_v;
            longint signed  expected_delta_v;
            logic [3:0]     out_asic_v;
            logic [4:0]     out_channel_v;
            logic [12:0]    out_tcc8n_v;
            logic [2:0]     out_tcc1n6_v;
            longint unsigned current_tick_v;

            current_tick_v              = measure_tick_8ns();

            for (int lane = 0; lane < 8; lane++) begin
                if (lane_type0_fire(lane)) begin
                    if (emu_frozen_cycle_q[lane].size() == 0) begin
                        emu_lat_underflow_count <= emu_lat_underflow_count + 1;
                    end else begin
                        latency_cycles_v = current_tick_v - emu_frozen_cycle_q[lane].pop_front();
                        emu_lat_hist_queue[lane].push_back(latency_cycles_v[15:0]);
                        emu_lat_hist_drive_count = emu_lat_hist_drive_count + 1;
                    end
                end

                if (lane_type0_fire(lane)) begin
                    actual_type0_v = lane_type0_data(lane);
                    if (emu_frozen_trace_q[lane].size() == 0) begin
                        trace_type0_underflow_count = trace_type0_underflow_count + 1;
                        if (trace_detail_fd != 0) begin
                            $fdisplay(
                                trace_detail_fd,
                                "TYPE0_UNDER,%0d,%0d,%0d,0x%012h",
                                lane,
                                lane_asic_id(lane),
                                emu_frozen_trace_q[lane].size(),
                                actual_type0_v
                            );
                        end
                    end else begin
                        expect_hit_v = emu_frozen_trace_q[lane].pop_front();
                        if (trace_detail_fd != 0) begin
                            $fdisplay(
                                trace_detail_fd,
                                "TYPE0,%0d,%0d,%0d,0x%012h,0x%012h,%0d,%0d",
                                lane,
                                expect_hit_v.asic,
                                expect_hit_v.hit_id,
                                actual_type0_v,
                                expect_hit_v.type0_word,
                                expect_hit_v.channel,
                                expect_hit_v.gen_gts8n
                            );
                        end
                        if (actual_type0_v != expect_hit_v.type0_word) begin
                            trace_type0_mismatch_count = trace_type0_mismatch_count + 1;
                            if (trace_ts_enable && (trace_mismatch_print_count < trace_mismatch_limit)) begin
                                trace_mismatch_print_count = trace_mismatch_print_count + 1;
                                $display(
                                    "TB_TS_TRACE TYPE0 lane=%0d hit_id=%0d actual=0x%012h expect=0x%012h",
                                    lane,
                                    expect_hit_v.hit_id,
                                    actual_type0_v,
                                    expect_hit_v.type0_word
                                );
                                if (trace_detail_fd != 0) begin
                                    $fdisplay(
                                        trace_detail_fd,
                                        "TYPE0,%0d,%0d,0x%012h,0x%012h",
                                        lane,
                                        expect_hit_v.hit_id,
                                        actual_type0_v,
                                        expect_hit_v.type0_word
                                    );
                                end
                            end
                        end
                        type0_trace_q[lane].push_back(expect_hit_v);
                    end
                end
            end

            for (int bank = 0; bank < 2; bank++) begin
                if (mts_input_fire(bank)) begin
                    mts_in_data_v    = mts_input_data(bank);
                    lane_from_asic_v = mts_in_data_v[44:41];
                    if (lane_from_asic_v >= 8 || type0_trace_q[lane_from_asic_v].size() == 0) begin
                        trace_mts_input_underflow_count = trace_mts_input_underflow_count + 1;
                        if (trace_detail_fd != 0) begin
                            $fdisplay(
                                trace_detail_fd,
                                "MTS_IN_UNDER,%0d,%0d,%0d,0x%012h",
                                bank,
                                lane_from_asic_v,
                                (lane_from_asic_v < 8) ? type0_trace_q[lane_from_asic_v].size() : 0,
                                mts_in_data_v
                            );
                        end
                    end else begin
                        expect_hit_v = type0_trace_q[lane_from_asic_v].pop_front();
                        if (trace_detail_fd != 0) begin
                            $fdisplay(
                                trace_detail_fd,
                                "MTS_IN,%0d,%0d,%0d,0x%012h,0x%012h,%0d,%0d",
                                bank,
                                lane_from_asic_v,
                                expect_hit_v.hit_id,
                                mts_in_data_v,
                                expect_hit_v.type0_word,
                                expect_hit_v.channel,
                                expect_hit_v.gen_gts8n
                            );
                        end
                        if (mts_in_data_v != expect_hit_v.type0_word) begin
                            trace_mts_input_mismatch_count = trace_mts_input_mismatch_count + 1;
                            if (trace_ts_enable && (trace_mismatch_print_count < trace_mismatch_limit)) begin
                                trace_mismatch_print_count = trace_mismatch_print_count + 1;
                                $display(
                                    "TB_TS_TRACE MTS_IN bank=%0d lane=%0d hit_id=%0d actual=0x%012h expect=0x%012h",
                                    bank,
                                    lane_from_asic_v,
                                    expect_hit_v.hit_id,
                                    mts_in_data_v,
                                    expect_hit_v.type0_word
                                );
                                if (trace_detail_fd != 0) begin
                                    $fdisplay(
                                        trace_detail_fd,
                                        "MTS_IN,%0d,%0d,%0d,0x%012h,0x%012h",
                                        bank,
                                        lane_from_asic_v,
                                        expect_hit_v.hit_id,
                                        mts_in_data_v,
                                        expect_hit_v.type0_word
                                    );
                                end
                            end
                        end
                        mts_trace_q[lane_from_asic_v].push_back(expect_hit_v);
                    end
                end

                if (mts_output_fire(bank)) begin
                    mts_out_data_v    = mts_output_data(bank);
                    out_asic_v        = mts_out_data_v[38:35];
                    out_channel_v     = mts_out_data_v[34:30];
                    out_tcc8n_v       = mts_out_data_v[29:17];
                    out_tcc1n6_v      = mts_out_data_v[16:14];
                    lane_from_asic_v  = out_asic_v;
                    if (lane_from_asic_v >= 8 || mts_trace_q[lane_from_asic_v].size() == 0) begin
                        trace_mts_output_underflow_count = trace_mts_output_underflow_count + 1;
                        if (trace_detail_fd != 0) begin
                            $fdisplay(
                                trace_detail_fd,
                                "MTS_OUT_UNDER,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                                bank,
                                out_asic_v,
                                out_channel_v,
                                out_tcc8n_v,
                                out_tcc1n6_v,
                                mts_debug_delta(bank),
                                mts_output_error(bank)
                            );
                        end
                    end else begin
                        expect_hit_v     = mts_trace_q[lane_from_asic_v].pop_front();
                        bank_gts_v       = bank_gts8n(bank);
                        expected_delta_v = $signed(bank_gts_v) - $signed(expect_hit_v.gen_gts8n);
                        if (trace_detail_fd != 0) begin
                            $fdisplay(
                                trace_detail_fd,
                                "MTS_OUT,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                                bank,
                                out_asic_v,
                                expect_hit_v.hit_id,
                                out_channel_v,
                                expect_hit_v.channel,
                                out_tcc8n_v,
                                expect_hit_v.gen_gts8n[12:0],
                                out_tcc1n6_v,
                                mts_debug_delta(bank),
                                expected_delta_v,
                                mts_output_error(bank),
                                !((expected_delta_v > 0) && (expected_delta_v < 2000))
                            );
                        end

                        if (out_channel_v != expect_hit_v.channel)
                            trace_mts_output_channel_mismatch_count = trace_mts_output_channel_mismatch_count + 1;
                        if (out_tcc8n_v != expect_hit_v.gen_gts8n[12:0] || out_tcc1n6_v != 3'd0)
                            trace_mts_output_tcc_mismatch_count = trace_mts_output_tcc_mismatch_count + 1;
                        if (mts_debug_delta(bank) != expected_delta_v)
                            trace_mts_output_delta_mismatch_count = trace_mts_output_delta_mismatch_count + 1;
                        if (mts_output_error(bank) != !((expected_delta_v > 0) && (expected_delta_v < 2000)))
                            trace_mts_output_error_mismatch_count = trace_mts_output_error_mismatch_count + 1;

                        if (trace_ts_enable
                         && (trace_mismatch_print_count < trace_mismatch_limit)
                         && (
                                (out_channel_v != expect_hit_v.channel)
                             || (out_tcc8n_v != expect_hit_v.gen_gts8n[12:0])
                             || (out_tcc1n6_v != 3'd0)
                             || (mts_debug_delta(bank) != expected_delta_v)
                             || (mts_output_error(bank) != !((expected_delta_v > 0) && (expected_delta_v < 2000)))
                            )) begin
                            trace_mismatch_print_count = trace_mismatch_print_count + 1;
                            $display(
                                "TB_TS_TRACE MTS_OUT bank=%0d lane=%0d hit_id=%0d ch_act=%0d ch_exp=%0d tcc8n_act=%0d tcc8n_exp=%0d tcc1n6=%0d delta_act=%0d delta_exp=%0d err_act=%0d err_exp=%0d",
                                bank,
                                lane_from_asic_v,
                                expect_hit_v.hit_id,
                                out_channel_v,
                                expect_hit_v.channel,
                                out_tcc8n_v,
                                expect_hit_v.gen_gts8n[12:0],
                                out_tcc1n6_v,
                                mts_debug_delta(bank),
                                expected_delta_v,
                                mts_output_error(bank),
                                !((expected_delta_v > 0) && (expected_delta_v < 2000))
                            );
                            if (trace_detail_fd != 0) begin
                                $fdisplay(
                                    trace_detail_fd,
                                    "MTS_OUT,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                                    bank,
                                    lane_from_asic_v,
                                    expect_hit_v.hit_id,
                                    out_channel_v,
                                    expect_hit_v.channel,
                                    out_tcc8n_v,
                                    expect_hit_v.gen_gts8n[12:0],
                                    out_tcc1n6_v,
                                    mts_debug_delta(bank),
                                    expected_delta_v,
                                    mts_output_error(bank),
                                    !((expected_delta_v > 0) && (expected_delta_v < 2000))
                                );
                            end
                        end
                    end
                end
            end
        end
    end

    always @(negedge clk_125 or posedge avmm_rst or negedge xcvr_rst_n) begin
        if (avmm_rst || !xcvr_rst_n) begin
            emu_lat_hist_stream_valid   <= '0;
            emu_lat_hist_stream_sop     <= '0;
            emu_lat_hist_stream_eop     <= '0;
            emu_lat_hist_stream_data    <= '0;
            emu_lat_hist_stream_channel <= '0;
        end
    end

    // Keep the decoded-din seam refreshed from the embedded emulators. This
    // mixed-language image does not retrigger SV combinational logic on the
    // VHDL source nets reliably, so refresh the force every half cycle.
    always @(negedge clk_125) begin
        force dut_wrap.dut.avalon_st_adapter_031_out_0_valid   = dut_wrap.dut.emulator_mutrig_0_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_031_out_0_data    = dut_wrap.dut.emulator_mutrig_0_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_031_out_0_channel = dut_wrap.dut.emulator_mutrig_0_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_031_out_0_error   = dut_wrap.dut.emulator_mutrig_0_tx8b1k_error;
        force dut_wrap.dut.avalon_st_adapter_034_out_0_valid   = dut_wrap.dut.emulator_mutrig_1_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_034_out_0_data    = dut_wrap.dut.emulator_mutrig_1_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_034_out_0_channel = dut_wrap.dut.emulator_mutrig_1_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_034_out_0_error   = dut_wrap.dut.emulator_mutrig_1_tx8b1k_error;
        force dut_wrap.dut.avalon_st_adapter_037_out_0_valid   = dut_wrap.dut.emulator_mutrig_2_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_037_out_0_data    = dut_wrap.dut.emulator_mutrig_2_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_037_out_0_channel = dut_wrap.dut.emulator_mutrig_2_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_037_out_0_error   = dut_wrap.dut.emulator_mutrig_2_tx8b1k_error;
        force dut_wrap.dut.avalon_st_adapter_040_out_0_valid   = dut_wrap.dut.emulator_mutrig_3_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_040_out_0_data    = dut_wrap.dut.emulator_mutrig_3_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_040_out_0_channel = dut_wrap.dut.emulator_mutrig_3_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_040_out_0_error   = dut_wrap.dut.emulator_mutrig_3_tx8b1k_error;
        force dut_wrap.dut.avalon_st_adapter_043_out_0_valid   = dut_wrap.dut.emulator_mutrig_4_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_043_out_0_data    = dut_wrap.dut.emulator_mutrig_4_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_043_out_0_channel = dut_wrap.dut.emulator_mutrig_4_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_043_out_0_error   = dut_wrap.dut.emulator_mutrig_4_tx8b1k_error;
        force dut_wrap.dut.avalon_st_adapter_046_out_0_valid   = dut_wrap.dut.emulator_mutrig_5_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_046_out_0_data    = dut_wrap.dut.emulator_mutrig_5_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_046_out_0_channel = dut_wrap.dut.emulator_mutrig_5_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_046_out_0_error   = dut_wrap.dut.emulator_mutrig_5_tx8b1k_error;
        force dut_wrap.dut.avalon_st_adapter_049_out_0_valid   = dut_wrap.dut.emulator_mutrig_6_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_049_out_0_data    = dut_wrap.dut.emulator_mutrig_6_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_049_out_0_channel = dut_wrap.dut.emulator_mutrig_6_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_049_out_0_error   = dut_wrap.dut.emulator_mutrig_6_tx8b1k_error;
        force dut_wrap.dut.avalon_st_adapter_052_out_0_valid   = dut_wrap.dut.emulator_mutrig_7_tx8b1k_valid;
        force dut_wrap.dut.avalon_st_adapter_052_out_0_data    = dut_wrap.dut.emulator_mutrig_7_tx8b1k_data;
        force dut_wrap.dut.avalon_st_adapter_052_out_0_channel = dut_wrap.dut.emulator_mutrig_7_tx8b1k_channel;
        force dut_wrap.dut.avalon_st_adapter_052_out_0_error   = dut_wrap.dut.emulator_mutrig_7_tx8b1k_error;

    end

    always_ff @(posedge clk_125) begin
        if (hit_lower_valid) begin
            hit_lower_count <= hit_lower_count + 1;
            if (hit_lower_sop)
                hit_lower_packets <= hit_lower_packets + 1;
        end
        if (hit_upper_valid) begin
            hit_upper_count <= hit_upper_count + 1;
            if (hit_upper_sop)
                hit_upper_packets <= hit_upper_packets + 1;
        end
        ext_emu_word_count <= ext_emu_word_count
                            + (dut_wrap.dut.emulator_mutrig_0_tx8b1k_valid ? 1 : 0)
                            + (dut_wrap.dut.emulator_mutrig_1_tx8b1k_valid ? 1 : 0)
                            + (dut_wrap.dut.emulator_mutrig_2_tx8b1k_valid ? 1 : 0)
                            + (dut_wrap.dut.emulator_mutrig_3_tx8b1k_valid ? 1 : 0)
                            + (dut_wrap.dut.emulator_mutrig_4_tx8b1k_valid ? 1 : 0)
                            + (dut_wrap.dut.emulator_mutrig_5_tx8b1k_valid ? 1 : 0)
                            + (dut_wrap.dut.emulator_mutrig_6_tx8b1k_valid ? 1 : 0)
                            + (dut_wrap.dut.emulator_mutrig_7_tx8b1k_valid ? 1 : 0);
        dp_hit0_word_count <= dp_hit0_word_count
                            + (dut_wrap.dut.mutrig_datapath_subsystem_0_hit_type0_out_valid ? 1 : 0)
                            + (dut_wrap.dut.mutrig_datapath_subsystem_1_hit_type0_out_valid ? 1 : 0)
                            + (dut_wrap.dut.mutrig_datapath_subsystem_2_hit_type0_out_valid ? 1 : 0)
                            + (dut_wrap.dut.mutrig_datapath_subsystem_3_hit_type0_out_valid ? 1 : 0)
                            + (dut_wrap.dut.mutrig_datapath_subsystem_4_hit_type0_out_valid ? 1 : 0)
                            + (dut_wrap.dut.mutrig_datapath_subsystem_5_hit_type0_out_valid ? 1 : 0)
                            + (dut_wrap.dut.mutrig_datapath_subsystem_6_hit_type0_out_valid ? 1 : 0)
                            + (dut_wrap.dut.mutrig_datapath_subsystem_7_hit_type0_out_valid ? 1 : 0);
        dp_hit0_payload_fire_count <= dp_hit0_payload_fire_count
                                    + (lane_type0_fire(0) ? 1 : 0)
                                    + (lane_type0_fire(1) ? 1 : 0)
                                    + (lane_type0_fire(2) ? 1 : 0)
                                    + (lane_type0_fire(3) ? 1 : 0)
                                    + (lane_type0_fire(4) ? 1 : 0)
                                    + (lane_type0_fire(5) ? 1 : 0)
                                    + (lane_type0_fire(6) ? 1 : 0)
                                    + (lane_type0_fire(7) ? 1 : 0);
        mts_type1_word_count <= mts_type1_word_count
                              + (dut_wrap.dut.mts_preprocessor_0_hit_type1_out_valid ? 1 : 0)
                              + (dut_wrap.dut.mts_preprocessor_1_hit_type1_out_valid ? 1 : 0);
        hit_stack_ingress_word_count <= hit_stack_ingress_word_count
                                      + ((dut_wrap.dut.mts_preprocessor_0_hit_type1_out_valid
                                       && dut_wrap.dut.mts_preprocessor_0_hit_type1_out_ready) ? 1 : 0)
                                      + ((dut_wrap.dut.mts_preprocessor_1_hit_type1_out_valid
                                       && dut_wrap.dut.mts_preprocessor_1_hit_type1_out_ready) ? 1 : 0);
        hit_stack_ingress_payload_word_count <= hit_stack_ingress_payload_word_count
                                              + ((dut_wrap.dut.mts_preprocessor_0_hit_type1_out_valid
                                               && dut_wrap.dut.mts_preprocessor_0_hit_type1_out_ready
                                               && !dut_wrap.dut.mts_preprocessor_0_hit_type1_out_endofpacket) ? 1 : 0)
                                              + ((dut_wrap.dut.mts_preprocessor_1_hit_type1_out_valid
                                               && dut_wrap.dut.mts_preprocessor_1_hit_type1_out_ready
                                               && !dut_wrap.dut.mts_preprocessor_1_hit_type1_out_endofpacket) ? 1 : 0);
        hit_stack_ingress_payload_clean_word_count <= hit_stack_ingress_payload_clean_word_count
                                                    + ((dut_wrap.dut.mts_preprocessor_0_hit_type1_out_valid
                                                     && dut_wrap.dut.mts_preprocessor_0_hit_type1_out_ready
                                                     && !dut_wrap.dut.mts_preprocessor_0_hit_type1_out_endofpacket
                                                     && !dut_wrap.dut.mts_preprocessor_0_hit_type1_out_error) ? 1 : 0)
                                                    + ((dut_wrap.dut.mts_preprocessor_1_hit_type1_out_valid
                                                     && dut_wrap.dut.mts_preprocessor_1_hit_type1_out_ready
                                                     && !dut_wrap.dut.mts_preprocessor_1_hit_type1_out_endofpacket
                                                     && !dut_wrap.dut.mts_preprocessor_1_hit_type1_out_error) ? 1 : 0);
        hit_stack_ingress_payload_error_word_count <= hit_stack_ingress_payload_error_word_count
                                                    + ((dut_wrap.dut.mts_preprocessor_0_hit_type1_out_valid
                                                     && dut_wrap.dut.mts_preprocessor_0_hit_type1_out_ready
                                                     && !dut_wrap.dut.mts_preprocessor_0_hit_type1_out_endofpacket
                                                     && dut_wrap.dut.mts_preprocessor_0_hit_type1_out_error) ? 1 : 0)
                                                    + ((dut_wrap.dut.mts_preprocessor_1_hit_type1_out_valid
                                                     && dut_wrap.dut.mts_preprocessor_1_hit_type1_out_ready
                                                     && !dut_wrap.dut.mts_preprocessor_1_hit_type1_out_endofpacket
                                                     && dut_wrap.dut.mts_preprocessor_1_hit_type1_out_error) ? 1 : 0);
    end

    initial begin
        #(TB_WATCHDOG);
        $fatal(1, "DP E2E smoke watchdog expired");
    end

    initial begin
        avmm_rst      = 1'b1;
        counter_sclr  = 1'b0;
        monitor_rst_n = 1'b0;
        xcvr_rst_n    = 1'b0;
        runctl_data   = CTRL_IDLE;
        runctl_valid  = 1'b0;
        pass_count    = 0;
        fail_count    = 0;
        pre_rbcam_measure_en = $test$plusargs("TB_DP_PRE_RBCAM_MEAS");
        measure_run_cycles   = 125000000;
        measure_hit_rate     = 16'h1000;
        measure_noise_rate   = 16'h0000;
        measure_short_mode   = 1'b1;
        measure_report_dir   = ".";
        trace_ts_enable      = $test$plusargs("TB_DP_TS_TRACE");
        trace_mismatch_limit = TRACE_MISMATCH_DEFAULT;
        trace_detail_fd      = 0;
        if (!$value$plusargs("TB_DP_RUN_CYCLES=%d", measure_run_cycles))
            measure_run_cycles = 125000000;
        if (!$value$plusargs("TB_DP_HIT_RATE=%h", measure_hit_rate))
            measure_hit_rate = 16'h1000;
        if (!$value$plusargs("TB_DP_NOISE_RATE=%h", measure_noise_rate))
            measure_noise_rate = 16'h0000;
        void'($value$plusargs("TB_DP_SHORT_MODE=%d", measure_short_mode));
        void'($value$plusargs("TB_DP_REPORT_DIR=%s", measure_report_dir));
        void'($value$plusargs("TB_DP_TS_TRACE_MAX_MISMATCH=%d", trace_mismatch_limit));
        for (int lane = 0; lane < 8; lane++) begin
            string hit_rate_arg;
            string noise_rate_arg;
            string hit_mode_arg;
            string burst_size_arg;
            string burst_center_arg;

            measure_hit_rate_lane[lane]    = measure_hit_rate;
            measure_noise_rate_lane[lane]  = measure_noise_rate;
            measure_hit_mode_lane[lane]    = HIT_MODE_POISSON;
            measure_burst_size_lane[lane]  = 5'd4;
            measure_burst_center_lane[lane]= 5'd16;

            hit_rate_arg     = $sformatf("TB_DP_HIT_RATE_LANE%0d=%%h", lane);
            noise_rate_arg   = $sformatf("TB_DP_NOISE_RATE_LANE%0d=%%h", lane);
            hit_mode_arg     = $sformatf("TB_DP_HIT_MODE_LANE%0d=%%d", lane);
            burst_size_arg   = $sformatf("TB_DP_BURST_SIZE_LANE%0d=%%d", lane);
            burst_center_arg = $sformatf("TB_DP_BURST_CENTER_LANE%0d=%%d", lane);

            void'($value$plusargs(hit_rate_arg, measure_hit_rate_lane[lane]));
            void'($value$plusargs(noise_rate_arg, measure_noise_rate_lane[lane]));
            void'($value$plusargs(hit_mode_arg, measure_hit_mode_lane[lane]));
            void'($value$plusargs(burst_size_arg, measure_burst_size_lane[lane]));
            void'($value$plusargs(burst_center_arg, measure_burst_center_lane[lane]));
        end
        rate_hist_csv_path = $sformatf("%s/pre_rbcam_rate_hist.csv", measure_report_dir);
        lat_hist_csv_path  = $sformatf("%s/emulator_dispatch_latency_hist.csv", measure_report_dir);
        trace_detail_path  = $sformatf("%s/emulator_timestamp_trace.csv", measure_report_dir);
        if (trace_ts_enable) begin
            trace_detail_fd = $fopen(trace_detail_path, "w");
            if (trace_detail_fd == 0)
                $fatal(1, "Failed to open trace detail file %s", trace_detail_path);
            $fdisplay(trace_detail_fd, "kind,scope0,scope1,hit_id,field0,field1,field2,field3,field4,field5,field6,field7");
        end

        bus_idle();
        local_hist_idle();
        force_run_control_ready_paths();
        force_run_control_fanout();
        force_histogram_ready_paths();
        force_avmm_idle_seams();
        force_emulator_local_csr_idle();
        force_datapath_local_csr_idle();
        force_datapath_hit0_ready_paths();
        force_lvds_decode_lanes_off();
        reset_counters();

        repeat (32) @(posedge clk_125);
        avmm_rst      = 1'b0;
        monitor_rst_n = 1'b1;
        xcvr_rst_n    = 1'b1;
        repeat (64) @(posedge clk_125);
        #(STARTUP_SETTLE);

        if (pre_rbcam_measure_en) begin
            configure_all_emulators_profile();
            configure_rate_hist(measure_run_cycles);
            wait_local_hist_cfg_applied(1'b1);
            clear_local_hist(1'b1);
            wait_local_hist_quiescent(1'b1, 8192);
            configure_latency_hist(measure_run_cycles);
            wait_local_hist_cfg_applied(1'b0);
            clear_local_hist(1'b0);
            wait_local_hist_quiescent(1'b0, 16384);
            reset_counters();
            enter_running();
            repeat (measure_run_cycles) @(posedge lvds_outclock);
            leave_running_with_drain(measure_short_mode ? 2048 : 4096);
            flush_pre_rbcam_hist_shadow(1_000_000);
            flush_latency_hist_shadow(1_000_000);
            freeze_local_hist(1'b1);
            freeze_local_hist(1'b0);
            wait_local_hist_quiescent(1'b1, 8192);
            wait_local_hist_quiescent(1'b0, 16384);
            wait_local_hist_drained(1'b1, 8192);
            wait_local_hist_drained(1'b0, 8192);

            local_hist_summary(
                1'b1,
                256,
                rate_hist_total_hits,
                rate_hist_active_bins,
                rate_hist_min_nonzero,
                rate_hist_max_nonzero,
                rate_hist_peak_bin
            );
            local_hist_read_status(
                1'b1,
                rate_hist_ctrl_word,
                rate_hist_total_status,
                rate_hist_dropped_status,
                rate_hist_underflow_status,
                rate_hist_overflow_status
            );
            local_hist_summary(
                1'b0,
                LAT_HIST_BINS,
                lat_hist_total_hits,
                lat_hist_active_bins,
                lat_hist_min_nonzero,
                lat_hist_max_nonzero,
                lat_hist_peak_bin
            );
            local_hist_read_status(
                1'b0,
                lat_hist_ctrl_word,
                lat_hist_total_status,
                lat_hist_dropped_status,
                lat_hist_underflow_status,
                lat_hist_overflow_status
            );
            dump_rate_hist_csv(rate_hist_csv_path);
            dump_latency_hist_csv(lat_hist_csv_path);

            report_emulator_status("PRE_RBCAM_MEAS");
            $display(
                "TB_MEAS run_cycles=%0d hit_rate=0x%04h noise_rate=0x%04h short_mode=%0d frame_cycles=%0d",
                measure_run_cycles,
                measure_hit_rate,
                measure_noise_rate,
                measure_short_mode,
                measure_short_mode ? 910 : 1550
            );
            for (int lane = 0; lane < 8; lane++) begin
                $display(
                    "TB_MEAS_CFG lane=%0d hit_rate=0x%04h noise_rate=0x%04h hit_mode=%0d burst_size=%0d burst_center=%0d",
                    lane,
                    measure_hit_rate_lane[lane],
                    measure_noise_rate_lane[lane],
                    measure_hit_mode_lane[lane],
                    measure_burst_size_lane[lane],
                    measure_burst_center_lane[lane]
                );
            end
            $display("TB_MEAS ext_emu_word_count=%0d", ext_emu_word_count);
            $display("TB_MEAS dp_hit0_word_count=%0d", dp_hit0_word_count);
            $display("TB_MEAS dp_hit0_payload_fire_count=%0d", dp_hit0_payload_fire_count);
            $display("TB_MEAS mts_type1_word_count=%0d", mts_type1_word_count);
            $display("TB_MEAS hit_stack_ingress_word_count=%0d", hit_stack_ingress_word_count);
            $display("TB_MEAS hit_stack_ingress_payload_word_count=%0d", hit_stack_ingress_payload_word_count);
            $display("TB_MEAS emu_lat_hist_drive_count=%0d", emu_lat_hist_drive_count);
            $display(
                "TB_MEAS_DROP payload_clean=%0d payload_error=%0d",
                hit_stack_ingress_payload_clean_word_count,
                hit_stack_ingress_payload_error_word_count
            );
            $display(
                "TB_MEAS_RATE total=%0d active=%0d min_nonzero=%0d max_nonzero=%0d peak_bin=%0d peak_asic=%0d peak_channel=%0d csv=%s",
                rate_hist_total_hits,
                rate_hist_active_bins,
                rate_hist_min_nonzero,
                rate_hist_max_nonzero,
                rate_hist_peak_bin,
                (rate_hist_peak_bin >> 5) & 3'h7,
                rate_hist_peak_bin & 5'h1f,
                rate_hist_csv_path
            );
            $display(
                "TB_MEAS_RATE_STATUS ctrl=0x%08h total=0x%08h dropped=0x%08h under=0x%08h over=0x%08h",
                rate_hist_ctrl_word,
                rate_hist_total_status,
                rate_hist_dropped_status,
                rate_hist_underflow_status,
                rate_hist_overflow_status
            );
            $display(
                "TB_MEAS_LAT total=%0d active=%0d min_nonzero=%0d max_nonzero=%0d peak_bin=%0d csv=%s underflow_events=%0d",
                lat_hist_total_hits,
                lat_hist_active_bins,
                lat_hist_min_nonzero,
                lat_hist_max_nonzero,
                lat_hist_peak_bin,
                lat_hist_csv_path,
                emu_lat_underflow_count
            );
            $display(
                "TB_MEAS_LAT_STATUS ctrl=0x%08h total=0x%08h dropped=0x%08h under=0x%08h over=0x%08h",
                lat_hist_ctrl_word,
                lat_hist_total_status,
                lat_hist_dropped_status,
                lat_hist_underflow_status,
                lat_hist_overflow_status
            );
            for (int lane = 0; lane < 8; lane++) begin
                $display(
                    "TB_MEAS_LAT_QUEUE lane=%0d live_max=%0d frozen_max=%0d live_residual=%0d frozen_residual=%0d overwrites=%0d",
                    lane,
                    emu_live_depth_max[lane],
                    emu_frozen_depth_max[lane],
                    emu_live_cycle_q[lane].size(),
                    emu_frozen_cycle_q[lane].size(),
                    emu_live_overwrite_count[lane]
                );
            end

            check("Pre-RBCAM measurement produced type0 dispatch words", dp_hit0_word_count > 0);
            check("Pre-RBCAM measurement produced accepted type1 words", hit_stack_ingress_word_count > 0);
            check("Pre-RBCAM rate histogram CSR reported no configuration error", rate_hist_ctrl_word[24] == 1'b0);
            check("Pre-RBCAM latency histogram CSR reported no configuration error", lat_hist_ctrl_word[24] == 1'b0);
            if (rate_hist_total_hits != hit_stack_ingress_payload_word_count) begin
                $display(
                    "TB_MEAS_NOTE rate_hist_total=%0d payload_ingress=%0d all_ingress=%0d",
                    rate_hist_total_hits,
                    hit_stack_ingress_payload_word_count,
                    hit_stack_ingress_word_count
                );
            end
            if (lat_hist_total_hits != dp_hit0_payload_fire_count) begin
                $display(
                    "TB_MEAS_NOTE lat_hist_total=%0d type0_dispatch=%0d lat_hist_drive=%0d",
                    lat_hist_total_hits,
                    dp_hit0_payload_fire_count,
                    emu_lat_hist_drive_count
                );
            end
            if (rate_hist_dropped_status != 0)
                $display("TB_MEAS_NOTE rate_hist_dropped=0x%08h", rate_hist_dropped_status);
            if (lat_hist_dropped_status != 0)
                $display("TB_MEAS_NOTE lat_hist_dropped=0x%08h", lat_hist_dropped_status);
            if (emu_lat_underflow_count != 0)
                $display("TB_MEAS_NOTE latency_underflow_events=%0d", emu_lat_underflow_count);
        end else begin
            configure_all_emulators_rate(16'h1000, 16'h0000, 1'b0);
            configure_hist_channel_rate(32'd8192);
            wait_hist0_cfg_applied();
            clear_hist0();
            reset_counters();
            enter_running();
            wait_for_hist_total_at_least(32, 4, 5ms, 100us);
            leave_running();
            hist0_summary(hist_total_hits, hist_active_bins, hist_min_nonzero, hist_max_nonzero);
            hist0_ctrl_read(hist_ctrl_word);
            read_hist0_status(
                hist_bank_status,
                hist_total_status,
                hist_dropped_status,
                hist_underflow_status,
                hist_overflow_status
            );

            report_emulator_status("SMOKE");
            $display("TB_SMOKE ext_emu_word_count=%0d", ext_emu_word_count);
            $display("TB_SMOKE dp_hit0_word_count=%0d", dp_hit0_word_count);
            $display("TB_SMOKE mts_type1_word_count=%0d", mts_type1_word_count);
            $display("TB_SMOKE hit_stack_ingress_word_count=%0d", hit_stack_ingress_word_count);
            $display(
                "TB_HIST total=%0d active=%0d min_nonzero=%0d max_nonzero=%0d",
                hist_total_hits, hist_active_bins, hist_min_nonzero, hist_max_nonzero
            );
            $display(
                "TB_HIST_STATUS ctrl=0x%08h bank=0x%08h total=0x%08h dropped=0x%08h under=0x%08h over=0x%08h",
                hist_ctrl_word,
                hist_bank_status,
                hist_total_status,
                hist_dropped_status,
                hist_underflow_status,
                hist_overflow_status
            );
            $display(
                "TB_SUMMARY lower_words=%0d upper_words=%0d lower_packets=%0d upper_packets=%0d",
                hit_lower_count, hit_upper_count, hit_lower_packets, hit_upper_packets
            );

            check("DP E2E external emulators produced words", ext_emu_word_count > 0);
            check("DP E2E datapath observed type0 words", dp_hit0_word_count > 0);
            check("DP E2E MTS produced type1 words", mts_type1_word_count > 0);
            check("DP E2E hit stack ingress accepted words", hit_stack_ingress_word_count > 0);
            check("DP E2E histogram CSR reported no configuration error", hist_ctrl_word[24] == 1'b0);
            check("DP E2E histogram accumulated hits", hist_total_hits >= 32);
            check("DP E2E histogram covered multiple bins", hist_active_bins >= 4);
        end

        $display(
            "TB_TS_TRACE_SUMMARY enabled=%0d gen_mod=%0d type0_under=%0d type0_mismatch=%0d mts_in_under=%0d mts_in_mismatch=%0d mts_out_under=%0d mts_out_channel=%0d mts_out_tcc=%0d mts_out_delta=%0d mts_out_error=%0d bank_gts_skew_max=%0d first_gen_offset=%0d trace_csv=%s",
            trace_ts_enable,
            trace_gen_mod_mismatch_count,
            trace_type0_underflow_count,
            trace_type0_mismatch_count,
            trace_mts_input_underflow_count,
            trace_mts_input_mismatch_count,
            trace_mts_output_underflow_count,
            trace_mts_output_channel_mismatch_count,
            trace_mts_output_tcc_mismatch_count,
            trace_mts_output_delta_mismatch_count,
            trace_mts_output_error_mismatch_count,
            trace_bank_gts_skew_max,
            trace_gen_mod_offset_first,
            trace_ts_enable ? trace_detail_path : ""
        );
        if (trace_detail_fd != 0)
            $fclose(trace_detail_fd);

        $display("Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1, "DP E2E smoke failed");

        $finish;
    end

endmodule
