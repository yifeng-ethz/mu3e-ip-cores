`timescale 1ns/1ps

module tb_type0_arb_mts_hist_cosim;
    localparam real CLK_PERIOD_NS = 8.0;

`ifndef TYPE0_ARB_FIFO_DEPTH
`define TYPE0_ARB_FIFO_DEPTH 2
`endif
`ifndef TYPE0_ARB_COUNTER_PROFILE
`define TYPE0_ARB_COUNTER_PROFILE 1
`endif
`ifndef TYPE0_ARB_DEBUG_LEVEL
`define TYPE0_ARB_DEBUG_LEVEL 0
`endif
`ifndef TYPE0_MUX_FIFO_DEPTH
`define TYPE0_MUX_FIFO_DEPTH 16
`endif
`ifndef TYPE0_MUX_DEBUG_LEVEL
`define TYPE0_MUX_DEBUG_LEVEL 0
`endif
`ifndef TYPE0_EMU_DEBUG_LEVEL
`define TYPE0_EMU_DEBUG_LEVEL 0
`endif
`ifndef TYPE0_MTS_DEBUG
`define TYPE0_MTS_DEBUG 0
`endif

    localparam int unsigned ARB_FIFO_DEPTH_CONST      = `TYPE0_ARB_FIFO_DEPTH;
    localparam int unsigned ARB_COUNTER_PROFILE_CONST = `TYPE0_ARB_COUNTER_PROFILE;
    localparam int unsigned ARB_DEBUG_LEVEL_CONST     = `TYPE0_ARB_DEBUG_LEVEL;
    localparam int unsigned MUX_FIFO_DEPTH_CONST      = `TYPE0_MUX_FIFO_DEPTH;
    localparam int unsigned MUX_DEBUG_LEVEL_CONST     = `TYPE0_MUX_DEBUG_LEVEL;
    localparam int unsigned EMU_DEBUG_LEVEL_CONST     = `TYPE0_EMU_DEBUG_LEVEL;
    localparam int unsigned MTS_DEBUG_CONST           = `TYPE0_MTS_DEBUG;
    localparam bit ARB_TRIM3_COUNTERS                 = (ARB_COUNTER_PROFILE_CONST == 1);
    localparam bit DEBUG_METADATA_ENABLE              =
        (ARB_DEBUG_LEVEL_CONST >= 2) && (MUX_DEBUG_LEVEL_CONST >= 2) && (MTS_DEBUG_CONST >= 2);

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;
    localparam logic [8:0] CTRL_TERMINATING = 9'b000010000;
    localparam logic [8:0] CTRL_RESET       = 9'b010000000;

    localparam logic [5:0] EMU_REG_CENTRAL       = 6'h07;
    localparam logic [5:0] EMU_REG_SIGNAL        = 6'h08;
    localparam logic [5:0] EMU_REG_BACKGROUND    = 6'h09;
    localparam logic [5:0] EMU_REG_FORMAT        = 6'h0A;
    localparam logic [5:0] EMU_REG_RATES         = 6'h0B;
    localparam logic [5:0] EMU_REG_CLUSTER_FIX   = 6'h0C;
    localparam logic [5:0] EMU_REG_PRNG_SEED     = 6'h0E;
    localparam logic [5:0] EMU_REG_TIMEBASE_SEED = 6'h0F;
    localparam logic [5:0] EMU_REG_LANE_ENABLE   = 6'h12;

    localparam logic [4:0] ARB_REG_UID              = 5'h00;
    localparam logic [4:0] ARB_REG_CONTROL          = 5'h02;
    localparam logic [4:0] ARB_REG_STATUS           = 5'h03;
    localparam logic [4:0] ARB_REG_WATCHDOG         = 5'h04;
    localparam logic [4:0] ARB_REG_INGRESS_REAL     = 5'h0A;
    localparam logic [4:0] ARB_REG_INGRESS_EMU      = 5'h0C;
    localparam logic [4:0] ARB_REG_DROPS_REAL       = 5'h0E;
    localparam logic [4:0] ARB_REG_DROPS_EMU        = 5'h10;
    localparam logic [4:0] ARB_REG_EGRESS_REAL      = 5'h12;
    localparam logic [4:0] ARB_REG_EGRESS_EMU       = 5'h14;
    localparam logic [1:0] ARB_MODE_REAL            = 2'd0;
    localparam logic [1:0] ARB_MODE_EMU             = 2'd1;

    localparam int unsigned HIST_CSR_CONTROL      = 2;
    localparam int unsigned HIST_CSR_LEFT_BOUND   = 3;
    localparam int unsigned HIST_CSR_BIN_WIDTH    = 5;
    localparam int unsigned HIST_CSR_INTERVAL     = 10;
    localparam int unsigned HIST_CSR_BANK_STATUS  = 11;
    localparam int unsigned HIST_CSR_PORT_STATUS  = 12;
    localparam int unsigned HIST_CSR_TOTAL_HITS   = 13;
    localparam int unsigned HIST_CSR_DROPPED_HITS = 14;

    localparam logic [31:0] HIST_CONTROL_APPLY        = 32'h0000_0001;
    localparam logic [31:0] HIST_CONTROL_IN_PORT_EXT0 = 32'h0000_0004;
    localparam logic [31:0] HIST_CONTROL_KEY_UNSIGNED = 32'h0000_0100;
    localparam logic [31:0] HIST_CONTROL_MODE_LATENCY = 32'h0000_0010;

    logic clk = 1'b0;
    logic rst = 1'b1;

    logic [44:0] emu_hit_data;
    logic        emu_hit_valid;
    logic [2:0]  emu_hit_error;
    logic [3:0]  emu_hit_channel;
    logic        emu_hit_sop;
    logic        emu_hit_eop;
    logic        emu_hit_eor;
    logic [15:0] emu_debug_fifo_fill;
    logic [63:0] emu_debug_hit_metadata;
    logic        emu_debug_hit_metadata_valid;
    logic [63:0] emu_hit_debug_data;
    logic        emu_hit_debug_valid;
    logic [3:0]  emu_hit_debug_channel;
    logic        emu_hit_debug_sop;
    logic        emu_hit_debug_eop;
    logic        emu_hit_debug_eor;
    logic [8:0]  emu_tx_data;
    logic        emu_tx_valid;
    logic [3:0]  emu_tx_channel;
    logic [2:0]  emu_tx_error;
    logic [8:0]  emu_ctrl_data;
    logic        emu_ctrl_valid;
    logic        emu_ctrl_ready;
    logic [5:0]  emu_csr_address;
    logic        emu_csr_read;
    logic        emu_csr_write;
    logic [31:0] emu_csr_writedata;
    logic [31:0] emu_csr_readdata;
    logic        emu_csr_waitrequest;

    logic [44:0] real_hit_data;
    logic        real_hit_valid;
    logic [2:0]  real_hit_error;
    logic [3:0]  real_hit_channel;
    logic        real_hit_sop;
    logic        real_hit_eop;
    logic        real_hit_eor;
    logic [63:0] real_hit_metadata;
    logic        real_hit_metadata_valid;
    logic        real_source_enable;

    logic [4:0]  arb_csr_address;
    logic        arb_csr_read;
    logic        arb_csr_write;
    logic [31:0] arb_csr_writedata;
    logic [31:0] arb_csr_readdata;
    logic        arb_csr_waitrequest;
    logic [8:0]  arb_ctrl_data;
    logic        arb_ctrl_valid;
    logic [44:0] arb_hit_data;
    logic        arb_hit_valid;
    logic [2:0]  arb_hit_error;
    logic [3:0]  arb_hit_channel;
    logic        arb_hit_sop;
    logic        arb_hit_eop;
    logic        arb_hit_eor;
    logic [4:0]  arb_debug_real_fifo_level;
    logic [4:0]  arb_debug_emu_fifo_level;
    logic [7:0]  arb_debug_fifo_flags;
    logic [63:0] arb_debug_selected_metadata;
    logic        arb_debug_selected_metadata_valid;

    logic [44:0] mux_out_data;
    logic        mux_out_valid;
    logic [2:0]  mux_out_error;
    logic [5:0]  mux_out_channel;
    logic        mux_out_sop;
    logic        mux_out_eop;
    logic        mux_out_eor;
    logic [63:0] mux_selected_metadata;
    logic        mux_selected_metadata_valid;

    logic [31:0] mts_csr_readdata;
    logic        mts_csr_read;
    logic [2:0]  mts_csr_address;
    logic        mts_csr_waitrequest;
    logic        mts_csr_write;
    logic [31:0] mts_csr_writedata;
    logic        mts_hit0_ready;
    logic [3:0]  mts_type1_channel;
    logic        mts_type1_sop;
    logic        mts_type1_eop;
    logic [38:0] mts_type1_data;
    logic        mts_type1_valid;
    logic        mts_type1_empty;
    logic        mts_type1_error;
    logic [86:0] mts_ext0_data;
    logic        mts_ext0_valid;
    logic [86:0] mts_ext1_data;
    logic        mts_ext1_valid;
    logic        mts_debug_ts_valid;
    logic [15:0] mts_debug_ts_data;
    logic        mts_debug_burst_valid;
    logic [15:0] mts_debug_burst_data;
    logic        mts_ts_delta_valid;
    logic [15:0] mts_ts_delta_data;
    logic [31:0] mts_debug_status_data;
    logic [63:0] mts_type1_sidecar_data;
    logic        mts_type1_sidecar_valid;
    logic [8:0]  mts_hist_ctrl_data;
    logic        mts_hist_ctrl_valid;

    logic [31:0] hist_bin_readdata;
    logic        hist_bin_read;
    logic [7:0]  hist_bin_address;
    logic        hist_bin_waitrequest;
    logic        hist_bin_write;
    logic [31:0] hist_bin_writedata;
    logic [8:0]  hist_bin_burstcount;
    logic        hist_bin_readdatavalid;
    logic        hist_bin_writeresponsevalid;
    logic [1:0]  hist_bin_response;
    logic [31:0] hist_csr_readdata;
    logic        hist_csr_read;
    logic [4:0]  hist_csr_address;
    logic        hist_csr_waitrequest;
    logic        hist_csr_write;
    logic [31:0] hist_csr_writedata;
    logic        hist_fill_ready;
    logic        hist_fill_out_valid;
    logic [38:0] hist_fill_out_data;
    logic        hist_fill_out_sop;
    logic        hist_fill_out_eop;
    logic [3:0]  hist_fill_out_channel;

    int unsigned run_cycles;
    int unsigned q16_rate;
    int unsigned drain_cycles;
    int unsigned hist_interval_cycles;
    int unsigned hist_mode;
    int unsigned lane_scale;
    int unsigned check_theory;
    int unsigned do_switch_test;
    int unsigned real_period_cycles;
    int unsigned real_hits_per_frame;
    real rate_tolerance_pct;
    real expected_lane_hits;
    real expected_scaled_hits;
    real expected_delta;
    real expected_abs_delta;
    real expected_tolerance;

    longint unsigned cycle_count;
    int unsigned emu_hit_count;
    int unsigned emu_tx_count;
    int unsigned real_hit_count;
    int unsigned arb_selected_count;
    int unsigned arb_selected_emu_count;
    int unsigned arb_selected_real_count;
    int unsigned arb_metadata_count;
    int unsigned arb_metadata_emu_count;
    int unsigned arb_metadata_real_count;
    int unsigned arb_metadata_bad_count;
    int unsigned metadata_alignment_errors;
    int unsigned mux_out_count;
    int unsigned mts_type1_count;
    int unsigned mts_ext0_count;
    int unsigned mts_sidecar_count;
    int unsigned mts_sidecar_emu_count;
    int unsigned mts_sidecar_real_count;
    int unsigned hist_ext0_count;
    logic [31:0] arb_uid_csr;
    logic [31:0] arb_status_csr;
    logic [31:0] arb_status_after_prep_csr;
    logic [31:0] arb_status_after_reset_csr;
    logic [31:0] arb_status_after_hardreset_csr;
    logic [31:0] arb_ingress_real_csr;
    logic [31:0] arb_ingress_emu_csr;
    logic [31:0] arb_drops_real_csr;
    logic [31:0] arb_drops_emu_csr;
    logic [31:0] arb_egress_real_csr;
    logic [31:0] arb_egress_emu_csr;
    logic [31:0] hist_total_hits_csr;
    logic [31:0] hist_bank_status_csr;
    logic [31:0] hist_port_status_csr;
    logic [31:0] hist_dropped_hits_csr;

    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    initial begin
        repeat (12) @(posedge clk);
        rst = 1'b0;
    end

    function automatic logic [44:0] pack_hit_type0(
        input logic [3:0]  asic_id,
        input logic [4:0]  channel,
        input logic [14:0] tcc,
        input logic [4:0]  t_fine,
        input logic [14:0] ecc,
        input logic        e_flag
    );
        pack_hit_type0 = {asic_id, channel, tcc, t_fine, ecc, e_flag};
    endfunction

    emulator_mutrig_qsys_lane #(
        .CSR_ADDR_WIDTH(6),
        .ASIC_ID_DEFAULT(4'd0),
        .CLUSTER_LANE_INDEX_DEFAULT(4'd0),
        .CLUSTER_LANE_COUNT_DEFAULT(4'd8),
        .BYTE_STREAM_ENABLE(1'b0),
        .DEBUG_LEVEL(EMU_DEBUG_LEVEL_CONST)
    ) u_emulator (
        .i_clk(clk),
        .i_rst(rst),
        .aso_hit_type0_data(emu_hit_data),
        .aso_hit_type0_valid(emu_hit_valid),
        .aso_hit_type0_error(emu_hit_error),
        .aso_hit_type0_channel(emu_hit_channel),
        .aso_hit_type0_startofpacket(emu_hit_sop),
        .aso_hit_type0_endofpacket(emu_hit_eop),
        .aso_hit_type0_endofrun(emu_hit_eor),
        .coe_debug_fifo_fill_level(emu_debug_fifo_fill),
        .coe_debug_hit_metadata(emu_debug_hit_metadata),
        .coe_debug_hit_metadata_valid(emu_debug_hit_metadata_valid),
        .aso_hit_debug_data(emu_hit_debug_data),
        .aso_hit_debug_valid(emu_hit_debug_valid),
        .aso_hit_debug_channel(emu_hit_debug_channel),
        .aso_hit_debug_startofpacket(emu_hit_debug_sop),
        .aso_hit_debug_endofpacket(emu_hit_debug_eop),
        .aso_hit_debug_endofrun(emu_hit_debug_eor),
        .aso_tx8b1k_data(emu_tx_data),
        .aso_tx8b1k_valid(emu_tx_valid),
        .aso_tx8b1k_channel(emu_tx_channel),
        .aso_tx8b1k_error(emu_tx_error),
        .asi_ctrl_data(emu_ctrl_data),
        .asi_ctrl_valid(emu_ctrl_valid),
        .asi_ctrl_ready(emu_ctrl_ready),
        .coe_inject_pulse(1'b0),
        .coe_inject_masked_pulse(1'b0),
        .avs_csr_address(emu_csr_address),
        .avs_csr_read(emu_csr_read),
        .avs_csr_write(emu_csr_write),
        .avs_csr_writedata(emu_csr_writedata),
        .avs_csr_readdata(emu_csr_readdata),
        .avs_csr_waitrequest(emu_csr_waitrequest)
    );

    arb_hit_type0 #(
        .MODE_DEFAULT(1),
        .FIFO_DEPTH(ARB_FIFO_DEPTH_CONST),
        .COUNTER_PROFILE(ARB_COUNTER_PROFILE_CONST),
        .DEBUG_LEVEL(ARB_DEBUG_LEVEL_CONST),
        .WATCHDOG_DEFAULT(0),
        .INSTANCE_ID(0)
    ) u_arb (
        .clk(clk),
        .rst(rst),
        .avs_csr_address(arb_csr_address),
        .avs_csr_write(arb_csr_write),
        .avs_csr_read(arb_csr_read),
        .avs_csr_writedata(arb_csr_writedata),
        .avs_csr_readdata(arb_csr_readdata),
        .avs_csr_waitrequest(arb_csr_waitrequest),
        .asi_ctrl_data(arb_ctrl_data),
        .asi_ctrl_valid(arb_ctrl_valid),
        .asi_real_data(real_hit_data),
        .asi_real_valid(real_hit_valid),
        .asi_real_error(real_hit_error),
        .asi_real_channel(real_hit_channel),
        .asi_real_startofpacket(real_hit_sop),
        .asi_real_endofpacket(real_hit_eop),
        .asi_real_endofrun(real_hit_eor),
        .asi_emu_data(emu_hit_data),
        .asi_emu_valid(emu_hit_valid),
        .asi_emu_error(emu_hit_error),
        .asi_emu_channel(emu_hit_channel),
        .asi_emu_startofpacket(emu_hit_sop),
        .asi_emu_endofpacket(emu_hit_eop),
        .asi_emu_endofrun(emu_hit_eor),
        .aso_data(arb_hit_data),
        .aso_valid(arb_hit_valid),
        .aso_error(arb_hit_error),
        .aso_channel(arb_hit_channel),
        .aso_startofpacket(arb_hit_sop),
        .aso_endofpacket(arb_hit_eop),
        .aso_endofrun(arb_hit_eor),
        .coe_debug_real_fifo_level(arb_debug_real_fifo_level),
        .coe_debug_emu_fifo_level(arb_debug_emu_fifo_level),
        .coe_debug_fifo_flags(arb_debug_fifo_flags),
        .coe_debug_real_hit_metadata(real_hit_metadata),
        .coe_debug_real_hit_metadata_valid(real_hit_metadata_valid),
        .coe_debug_emu_hit_metadata(emu_debug_hit_metadata),
        .coe_debug_emu_hit_metadata_valid(emu_debug_hit_metadata_valid),
        .coe_debug_selected_hit_metadata(arb_debug_selected_metadata),
        .coe_debug_selected_hit_metadata_valid(arb_debug_selected_metadata_valid)
    );

    hit_type0_readyless_mux4 #(
        .FIFO_DEPTH(MUX_FIFO_DEPTH_CONST),
        .DEBUG_LEVEL(MUX_DEBUG_LEVEL_CONST)
    ) u_type0_bank_mux (
        .clk(clk),
        .rst(rst),
        .asi_in0_data(arb_hit_data),
        .asi_in0_valid(arb_hit_valid),
        .asi_in0_error(arb_hit_error),
        .asi_in0_channel(arb_hit_channel),
        .asi_in0_startofpacket(arb_hit_sop),
        .asi_in0_endofpacket(arb_hit_eop),
        .asi_in0_endofrun(arb_hit_eor),
        .asi_in0_metadata(arb_debug_selected_metadata),
        .asi_in0_metadata_valid(arb_debug_selected_metadata_valid),
        .asi_in1_data(45'd0),
        .asi_in1_valid(1'b0),
        .asi_in1_error(3'd0),
        .asi_in1_channel(4'd1),
        .asi_in1_startofpacket(1'b0),
        .asi_in1_endofpacket(1'b0),
        .asi_in1_endofrun(1'b0),
        .asi_in1_metadata(64'd0),
        .asi_in1_metadata_valid(1'b0),
        .asi_in2_data(45'd0),
        .asi_in2_valid(1'b0),
        .asi_in2_error(3'd0),
        .asi_in2_channel(4'd2),
        .asi_in2_startofpacket(1'b0),
        .asi_in2_endofpacket(1'b0),
        .asi_in2_endofrun(1'b0),
        .asi_in2_metadata(64'd0),
        .asi_in2_metadata_valid(1'b0),
        .asi_in3_data(45'd0),
        .asi_in3_valid(1'b0),
        .asi_in3_error(3'd0),
        .asi_in3_channel(4'd3),
        .asi_in3_startofpacket(1'b0),
        .asi_in3_endofpacket(1'b0),
        .asi_in3_endofrun(1'b0),
        .asi_in3_metadata(64'd0),
        .asi_in3_metadata_valid(1'b0),
        .aso_out_data(mux_out_data),
        .aso_out_valid(mux_out_valid),
        .aso_out_error(mux_out_error),
        .aso_out_channel(mux_out_channel),
        .aso_out_startofpacket(mux_out_sop),
        .aso_out_endofpacket(mux_out_eop),
        .aso_out_endofrun(mux_out_eor),
        .coe_selected_metadata(mux_selected_metadata),
        .coe_selected_metadata_valid(mux_selected_metadata_valid)
    );

    mts_processor #(
        .BANK("UP"),
        .ENABLED_CHANNEL_HI(3),
        .ENABLED_CHANNEL_LO(0),
        .DEBUG(MTS_DEBUG_CONST)
    ) u_mts (
        .avs_csr_readdata(mts_csr_readdata),
        .avs_csr_read(mts_csr_read),
        .avs_csr_address(mts_csr_address),
        .avs_csr_waitrequest(mts_csr_waitrequest),
        .avs_csr_write(mts_csr_write),
        .avs_csr_writedata(mts_csr_writedata),

        .asi_hit_type0_channel(mux_out_channel),
        .asi_hit_type0_startofpacket(mux_out_sop),
        .asi_hit_type0_endofpacket(mux_out_eop),
        .asi_hit_type0_endofrun(mux_out_eor),
        .asi_hit_type0_error(mux_out_error),
        .asi_hit_type0_data(mux_out_data),
        .asi_hit_type0_valid(mux_out_valid),
        .asi_hit_type0_ready(mts_hit0_ready),
        .coe_hit_type0_sidecar_data(mux_selected_metadata),
        .coe_hit_type0_sidecar_valid(mux_selected_metadata_valid),

        .aso_hit_type1_channel(mts_type1_channel),
        .aso_hit_type1_startofpacket(mts_type1_sop),
        .aso_hit_type1_endofpacket(mts_type1_eop),
        .aso_hit_type1_data(mts_type1_data),
        .aso_hit_type1_valid(mts_type1_valid),
        .aso_hit_type1_ready(1'b1),
        .aso_hit_type1_empty(mts_type1_empty),
        .aso_hit_type1_error(mts_type1_error),

        .aso_hit_type1_extended_0_data(mts_ext0_data),
        .aso_hit_type1_extended_0_valid(mts_ext0_valid),
        .aso_hit_type1_extended_1_data(mts_ext1_data),
        .aso_hit_type1_extended_1_valid(mts_ext1_valid),

        .asi_ctrl_data(mts_hist_ctrl_data),
        .asi_ctrl_valid(mts_hist_ctrl_valid),

        .aso_debug_ts_valid(mts_debug_ts_valid),
        .aso_debug_ts_data(mts_debug_ts_data),
        .aso_debug_burst_valid(mts_debug_burst_valid),
        .aso_debug_burst_data(mts_debug_burst_data),
        .aso_ts_delta_valid(mts_ts_delta_valid),
        .aso_ts_delta_data(mts_ts_delta_data),
        .coe_debug_status_data(mts_debug_status_data),
        .coe_hit_type1_sidecar_data(mts_type1_sidecar_data),
        .coe_hit_type1_sidecar_valid(mts_type1_sidecar_valid),

        .i_rst(rst),
        .i_clk(clk)
    );

    histogram_statistics_v2 #(
        .DEF_LEFT_BOUND(0),
        .DEF_BIN_WIDTH(16),
        .AVS_ADDR_WIDTH(8),
        .N_PORTS(1),
        .FIFO_ADDR_WIDTH(8),
        .ENABLE_PINGPONG(1'b1),
        .DEF_INTERVAL_CLOCKS(125000000),
        .AVST_DATA_WIDTH(39),
        .AVST_CHANNEL_WIDTH(4),
        .N_DEBUG_INTERFACE(0),
        .SNOOP_EN(1'b0),
        .ENABLE_PACKET(1'b0),
        .DEBUG(0)
    ) u_hist (
        .avs_hist_bin_readdata(hist_bin_readdata),
        .avs_hist_bin_read(hist_bin_read),
        .avs_hist_bin_address(hist_bin_address),
        .avs_hist_bin_waitrequest(hist_bin_waitrequest),
        .avs_hist_bin_write(hist_bin_write),
        .avs_hist_bin_writedata(hist_bin_writedata),
        .avs_hist_bin_burstcount(hist_bin_burstcount),
        .avs_hist_bin_readdatavalid(hist_bin_readdatavalid),
        .avs_hist_bin_writeresponsevalid(hist_bin_writeresponsevalid),
        .avs_hist_bin_response(hist_bin_response),

        .avs_csr_readdata(hist_csr_readdata),
        .avs_csr_read(hist_csr_read),
        .avs_csr_address(hist_csr_address),
        .avs_csr_waitrequest(hist_csr_waitrequest),
        .avs_csr_write(hist_csr_write),
        .avs_csr_writedata(hist_csr_writedata),

        .asi_hist_fill_in_ready(hist_fill_ready),
        .asi_hist_fill_in_valid(1'b0),
        .asi_hist_fill_in_data(39'd0),
        .asi_hist_fill_in_startofpacket(1'b0),
        .asi_hist_fill_in_endofpacket(1'b0),
        .asi_hist_fill_in_channel(4'd0),

        .asi_fill_in_1_ready(),
        .asi_fill_in_1_valid(1'b0),
        .asi_fill_in_1_data(39'd0),
        .asi_fill_in_1_startofpacket(1'b0),
        .asi_fill_in_1_endofpacket(1'b0),
        .asi_fill_in_1_channel(4'd0),
        .asi_fill_in_2_ready(),
        .asi_fill_in_2_valid(1'b0),
        .asi_fill_in_2_data(39'd0),
        .asi_fill_in_2_startofpacket(1'b0),
        .asi_fill_in_2_endofpacket(1'b0),
        .asi_fill_in_2_channel(4'd0),
        .asi_fill_in_3_ready(),
        .asi_fill_in_3_valid(1'b0),
        .asi_fill_in_3_data(39'd0),
        .asi_fill_in_3_startofpacket(1'b0),
        .asi_fill_in_3_endofpacket(1'b0),
        .asi_fill_in_3_channel(4'd0),
        .asi_fill_in_4_ready(),
        .asi_fill_in_4_valid(1'b0),
        .asi_fill_in_4_data(39'd0),
        .asi_fill_in_4_startofpacket(1'b0),
        .asi_fill_in_4_endofpacket(1'b0),
        .asi_fill_in_4_channel(4'd0),
        .asi_fill_in_5_ready(),
        .asi_fill_in_5_valid(1'b0),
        .asi_fill_in_5_data(39'd0),
        .asi_fill_in_5_startofpacket(1'b0),
        .asi_fill_in_5_endofpacket(1'b0),
        .asi_fill_in_5_channel(4'd0),
        .asi_fill_in_6_ready(),
        .asi_fill_in_6_valid(1'b0),
        .asi_fill_in_6_data(39'd0),
        .asi_fill_in_6_startofpacket(1'b0),
        .asi_fill_in_6_endofpacket(1'b0),
        .asi_fill_in_6_channel(4'd0),
        .asi_fill_in_7_ready(),
        .asi_fill_in_7_valid(1'b0),
        .asi_fill_in_7_data(39'd0),
        .asi_fill_in_7_startofpacket(1'b0),
        .asi_fill_in_7_endofpacket(1'b0),
        .asi_fill_in_7_channel(4'd0),

        .asi_hit_type1_extended_0_valid(mts_ext0_valid),
        .asi_hit_type1_extended_0_data(mts_ext0_data),
        .asi_hit_type1_extended_1_valid(mts_ext1_valid),
        .asi_hit_type1_extended_1_data(mts_ext1_data),

        .aso_hist_fill_out_ready(1'b1),
        .aso_hist_fill_out_valid(hist_fill_out_valid),
        .aso_hist_fill_out_data(hist_fill_out_data),
        .aso_hist_fill_out_startofpacket(hist_fill_out_sop),
        .aso_hist_fill_out_endofpacket(hist_fill_out_eop),
        .aso_hist_fill_out_channel(hist_fill_out_channel),

        .asi_ctrl_data(mts_hist_ctrl_data),
        .asi_ctrl_valid(mts_hist_ctrl_valid),

        .asi_debug_1_valid(1'b0),
        .asi_debug_1_data(16'd0),
        .asi_debug_2_valid(1'b0),
        .asi_debug_2_data(16'd0),
        .asi_debug_3_valid(1'b0),
        .asi_debug_3_data(16'd0),
        .asi_debug_4_valid(1'b0),
        .asi_debug_4_data(16'd0),
        .asi_debug_5_valid(1'b0),
        .asi_debug_5_data(16'd0),
        .asi_debug_6_valid(1'b0),
        .asi_debug_6_data(16'd0),

        .i_interval_reset(1'b0),
        .i_rst(rst),
        .i_clk(clk)
    );

    task automatic emu_write(input logic [5:0] addr, input logic [31:0] data);
        @(posedge clk);
        emu_csr_address   <= addr;
        emu_csr_writedata <= data;
        emu_csr_write     <= 1'b1;
        emu_csr_read      <= 1'b0;
        @(posedge clk);
        emu_csr_write     <= 1'b0;
    endtask

    task automatic arb_write(input logic [4:0] addr, input logic [31:0] data);
        @(posedge clk);
        arb_csr_address   <= addr;
        arb_csr_writedata <= data;
        arb_csr_write     <= 1'b1;
        arb_csr_read      <= 1'b0;
        @(posedge clk);
        arb_csr_write     <= 1'b0;
    endtask

    task automatic arb_read(input logic [4:0] addr, output logic [31:0] data);
        @(posedge clk);
        arb_csr_address <= addr;
        arb_csr_read    <= 1'b1;
        arb_csr_write   <= 1'b0;
        @(posedge clk);
        #1ps;
        data = arb_csr_readdata;
        arb_csr_read <= 1'b0;
    endtask

    task automatic hist_csr_bus_write(input int unsigned addr, input logic [31:0] data);
        @(posedge clk);
        hist_csr_address   <= addr[4:0];
        hist_csr_writedata <= data;
        hist_csr_write     <= 1'b1;
        hist_csr_read      <= 1'b0;
        @(posedge clk);
        hist_csr_write     <= 1'b0;
    endtask

    task automatic hist_csr_bus_read(input int unsigned addr, output logic [31:0] data);
        @(posedge clk);
        hist_csr_address <= addr[4:0];
        hist_csr_read    <= 1'b1;
        hist_csr_write   <= 1'b0;
        @(posedge clk);
        #1ps;
        data = hist_csr_readdata;
        hist_csr_read <= 1'b0;
    endtask

    task automatic send_run_state(input logic [8:0] state);
        @(posedge clk);
        emu_ctrl_data       <= state;
        emu_ctrl_valid      <= 1'b1;
        arb_ctrl_data       <= state;
        arb_ctrl_valid      <= 1'b1;
        mts_hist_ctrl_data  <= state;
        mts_hist_ctrl_valid <= 1'b1;
        @(posedge clk);
        emu_ctrl_valid      <= 1'b0;
        arb_ctrl_valid      <= 1'b0;
        mts_hist_ctrl_valid <= 1'b0;
        emu_ctrl_data       <= CTRL_IDLE;
        arb_ctrl_data       <= CTRL_IDLE;
        mts_hist_ctrl_data  <= CTRL_IDLE;
    endtask

    task automatic send_arb_run_state(input logic [8:0] state);
        @(posedge clk);
        arb_ctrl_data  <= state;
        arb_ctrl_valid <= 1'b1;
        @(posedge clk);
        arb_ctrl_valid <= 1'b0;
        arb_ctrl_data  <= CTRL_IDLE;
    endtask

    task automatic send_emu_run_state(input logic [8:0] state);
        @(posedge clk);
        emu_ctrl_data  <= state;
        emu_ctrl_valid <= 1'b1;
        @(posedge clk);
        emu_ctrl_valid <= 1'b0;
        emu_ctrl_data  <= CTRL_IDLE;
    endtask

    always_ff @(posedge clk) begin : real_type0_source
        static int unsigned period_ctr = 0;
        static int unsigned frame_idx = 0;
        static int unsigned real_seq = 0;
        static logic        frame_active = 1'b0;
        static logic [14:0] tcc_base = 15'd1000;
        static logic [14:0] ecc_base = 15'd1008;

        if (rst) begin
            real_hit_data <= '0;
            real_hit_valid <= 1'b0;
            real_hit_error <= 3'd0;
            real_hit_channel <= 4'd0;
            real_hit_sop <= 1'b0;
            real_hit_eop <= 1'b0;
            real_hit_eor <= 1'b0;
            real_hit_metadata <= 64'd0;
            real_hit_metadata_valid <= 1'b0;
            period_ctr = 0;
            frame_idx = 0;
            real_seq = 0;
            frame_active = 1'b0;
            tcc_base = 15'd1000;
            ecc_base = 15'd1008;
        end else begin
            real_hit_valid <= 1'b0;
            real_hit_sop <= 1'b0;
            real_hit_eop <= 1'b0;
            real_hit_eor <= 1'b0;
            real_hit_metadata_valid <= 1'b0;

            if (real_source_enable) begin
                if (!frame_active) begin
                    if (period_ctr >= real_period_cycles) begin
                        period_ctr = 0;
                        frame_idx = 0;
                        frame_active = 1'b1;
                    end else begin
                        period_ctr = period_ctr + 1;
                    end
                end

                if (frame_active) begin
                    real_hit_valid <= 1'b1;
                    real_hit_sop <= (frame_idx == 0);
                    real_hit_eop <= (frame_idx == (real_hits_per_frame - 1));
                    real_hit_error <= 3'd0;
                    real_hit_channel <= 4'd0;
                    real_hit_data <= pack_hit_type0(
                        4'd0,
                        frame_idx[4:0],
                        tcc_base + frame_idx[14:0],
                        frame_idx[4:0],
                        ecc_base + frame_idx[14:0],
                        1'b0
                    );
                    real_hit_metadata <= {
                        cycle_count[31:0],
                        4'h2,
                        4'd0,
                        real_seq[23:0]
                    };
                    real_hit_metadata_valid <= 1'b1;
                    real_seq = real_seq + 1;

                    if (frame_idx == (real_hits_per_frame - 1)) begin
                        frame_active = 1'b0;
                        frame_idx = 0;
                        tcc_base = tcc_base + 15'd32;
                        ecc_base = ecc_base + 15'd32;
                    end else begin
                        frame_idx = frame_idx + 1;
                    end
                end
            end else begin
                period_ctr = 0;
                frame_idx = 0;
                frame_active = 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
            emu_hit_count <= 0;
            emu_tx_count <= 0;
            real_hit_count <= 0;
            arb_selected_count <= 0;
            arb_selected_emu_count <= 0;
            arb_selected_real_count <= 0;
            arb_metadata_count <= 0;
            arb_metadata_emu_count <= 0;
            arb_metadata_real_count <= 0;
            arb_metadata_bad_count <= 0;
            metadata_alignment_errors <= 0;
            mux_out_count <= 0;
            mts_type1_count <= 0;
            mts_ext0_count <= 0;
            mts_sidecar_count <= 0;
            mts_sidecar_emu_count <= 0;
            mts_sidecar_real_count <= 0;
            hist_ext0_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (emu_hit_valid) begin
                emu_hit_count <= emu_hit_count + 1;
            end

            if (emu_tx_valid) begin
                emu_tx_count <= emu_tx_count + 1;
            end

            if (real_hit_valid) begin
                real_hit_count <= real_hit_count + 1;
            end

            if (arb_hit_valid) begin
                arb_selected_count <= arb_selected_count + 1;
                if (DEBUG_METADATA_ENABLE &&
                    arb_debug_selected_metadata_valid && arb_debug_selected_metadata[31:28] == 4'h1) begin
                    arb_selected_emu_count <= arb_selected_emu_count + 1;
                end else if (DEBUG_METADATA_ENABLE &&
                             arb_debug_selected_metadata_valid && arb_debug_selected_metadata[31:28] == 4'h2) begin
                    arb_selected_real_count <= arb_selected_real_count + 1;
                end
            end

            if (DEBUG_METADATA_ENABLE && arb_debug_selected_metadata_valid) begin
                arb_metadata_count <= arb_metadata_count + 1;
                if (!arb_hit_valid) begin
                    metadata_alignment_errors <= metadata_alignment_errors + 1;
                end

                case (arb_debug_selected_metadata[31:28])
                    4'h1: arb_metadata_emu_count <= arb_metadata_emu_count + 1;
                    4'h2: arb_metadata_real_count <= arb_metadata_real_count + 1;
                    default: arb_metadata_bad_count <= arb_metadata_bad_count + 1;
                endcase
            end else if (DEBUG_METADATA_ENABLE && arb_hit_valid && !arb_hit_eor) begin
                metadata_alignment_errors <= metadata_alignment_errors + 1;
            end

            if (mux_out_valid) begin
                mux_out_count <= mux_out_count + 1;
            end

            if (mts_type1_valid) begin
                mts_type1_count <= mts_type1_count + 1;
            end

            if (mts_ext0_valid) begin
                mts_ext0_count <= mts_ext0_count + 1;
            end

            if (mts_type1_sidecar_valid) begin
                mts_sidecar_count <= mts_sidecar_count + 1;
                case (mts_type1_sidecar_data[31:28])
                    4'h1: mts_sidecar_emu_count <= mts_sidecar_emu_count + 1;
                    4'h2: mts_sidecar_real_count <= mts_sidecar_real_count + 1;
                    default: begin
                    end
                endcase
            end

            if (mts_ext0_valid) begin
                hist_ext0_count <= hist_ext0_count + 1;
            end
        end
    end

    initial begin : runbench
        if (!$value$plusargs("RUN_CYCLES=%d", run_cycles)) begin
            run_cycles = 200000;
        end
        if (!$value$plusargs("Q16_RATE=%d", q16_rate)) begin
            q16_rate = 52;
        end
        if (!$value$plusargs("DRAIN_CYCLES=%d", drain_cycles)) begin
            drain_cycles = 4096;
        end
        if (!$value$plusargs("HIST_MODE=%d", hist_mode)) begin
            hist_mode = 1;
        end
        if (!$value$plusargs("LANE_SCALE=%d", lane_scale)) begin
            lane_scale = 1;
        end
        if (!$value$plusargs("CHECK_THEORY=%d", check_theory)) begin
            check_theory = 0;
        end
        if (!$value$plusargs("DO_SWITCH_TEST=%d", do_switch_test)) begin
            do_switch_test = 1;
        end
        if (!$value$plusargs("REAL_PERIOD_CYCLES=%d", real_period_cycles)) begin
            real_period_cycles = 256;
        end
        if (!$value$plusargs("REAL_HITS_PER_FRAME=%d", real_hits_per_frame)) begin
            real_hits_per_frame = 8;
        end
        if (!$value$plusargs("RATE_TOLERANCE_PCT=%f", rate_tolerance_pct)) begin
            rate_tolerance_pct = 5.0;
        end

        if (real_hits_per_frame == 0) begin
            real_hits_per_frame = 1;
        end
        hist_interval_cycles = run_cycles + drain_cycles + 10000;

        emu_ctrl_data = CTRL_IDLE;
        emu_ctrl_valid = 1'b0;
        emu_csr_address = '0;
        emu_csr_read = 1'b0;
        emu_csr_write = 1'b0;
        emu_csr_writedata = '0;
        arb_ctrl_data = CTRL_IDLE;
        arb_ctrl_valid = 1'b0;
        arb_csr_address = '0;
        arb_csr_read = 1'b0;
        arb_csr_write = 1'b0;
        arb_csr_writedata = '0;
        real_source_enable = 1'b0;
        mts_csr_address = '0;
        mts_csr_read = 1'b0;
        mts_csr_write = 1'b0;
        mts_csr_writedata = '0;
        mts_hist_ctrl_data = CTRL_IDLE;
        mts_hist_ctrl_valid = 1'b0;
        hist_bin_address = '0;
        hist_bin_read = 1'b0;
        hist_bin_write = 1'b0;
        hist_bin_writedata = '0;
        hist_bin_burstcount = 9'd1;
        hist_csr_address = '0;
        hist_csr_read = 1'b0;
        hist_csr_write = 1'b0;
        hist_csr_writedata = '0;

        wait (rst == 1'b0);
        repeat (8) @(posedge clk);

        hist_csr_bus_write(HIST_CSR_LEFT_BOUND, 32'h0000_0000);
        hist_csr_bus_write(HIST_CSR_BIN_WIDTH, 32'h0000_0010);
        hist_csr_bus_write(HIST_CSR_INTERVAL, hist_interval_cycles);
        hist_csr_bus_write(
            HIST_CSR_CONTROL,
            HIST_CONTROL_APPLY |
            HIST_CONTROL_IN_PORT_EXT0 |
            HIST_CONTROL_KEY_UNSIGNED |
            (hist_mode ? HIST_CONTROL_MODE_LATENCY : 32'h0000_0000)
        );
        repeat (16) @(posedge clk);

        emu_write(EMU_REG_CENTRAL, 32'h0000_0000);
        emu_write(EMU_REG_BACKGROUND, 32'h0000_0000);
        emu_write(EMU_REG_SIGNAL, 32'h0000_0002);
        emu_write(EMU_REG_FORMAT, 32'h0000_0033);
        emu_write(EMU_REG_RATES, {16'h0000, q16_rate[15:0]});
        emu_write(EMU_REG_CLUSTER_FIX, 32'h0000_4F80);
        emu_write(EMU_REG_PRNG_SEED, 32'hDEAD_BEEF);
        emu_write(EMU_REG_TIMEBASE_SEED, 32'h0001_0001);
        emu_write(EMU_REG_LANE_ENABLE, 32'h0000_0001);
        emu_write(EMU_REG_CENTRAL, 32'h0000_0001);

        arb_read(ARB_REG_UID, arb_uid_csr);
        if (arb_uid_csr != 32'h4148_5430) begin
            $fatal(1, "arb_hit_type0 UID mismatch: 0x%08h", arb_uid_csr);
        end

        arb_write(ARB_REG_WATCHDOG, 32'h0000_0000);
        arb_write(ARB_REG_CONTROL, {30'd0, ARB_MODE_EMU});
        repeat (8) @(posedge clk);
        send_arb_run_state(CTRL_RUN_PREPARE);
        repeat (8) @(posedge clk);
        arb_read(ARB_REG_STATUS, arb_status_after_prep_csr);
        if (arb_status_after_prep_csr[1:0] != ARB_MODE_EMU) begin
            $fatal(1, "arb mode changed on RUN_PREPARE: status=0x%08h", arb_status_after_prep_csr);
        end

        send_run_state(CTRL_RUN_PREPARE);
        repeat (8) @(posedge clk);
        send_run_state(CTRL_SYNC);
        repeat (8) @(posedge clk);
        send_run_state(CTRL_RUNNING);

        if (do_switch_test != 0) begin
            repeat (run_cycles / 3) @(posedge clk);
            real_source_enable = 1'b1;
            arb_write(ARB_REG_CONTROL, {30'd0, ARB_MODE_REAL});
            repeat (run_cycles / 3) @(posedge clk);
            real_source_enable = 1'b0;
            arb_write(ARB_REG_CONTROL, {30'd0, ARB_MODE_EMU});
            repeat (run_cycles - 2 * (run_cycles / 3)) @(posedge clk);
        end else begin
            repeat (run_cycles) @(posedge clk);
        end

        send_emu_run_state(CTRL_TERMINATING);
        repeat (drain_cycles) @(posedge clk);
        send_emu_run_state(CTRL_IDLE);
        repeat (1024) @(posedge clk);

        arb_read(ARB_REG_STATUS, arb_status_csr);
        arb_read(ARB_REG_INGRESS_REAL, arb_ingress_real_csr);
        arb_read(ARB_REG_INGRESS_EMU, arb_ingress_emu_csr);
        arb_read(ARB_REG_DROPS_REAL, arb_drops_real_csr);
        arb_read(ARB_REG_DROPS_EMU, arb_drops_emu_csr);
        arb_read(ARB_REG_EGRESS_REAL, arb_egress_real_csr);
        arb_read(ARB_REG_EGRESS_EMU, arb_egress_emu_csr);
        hist_csr_bus_read(HIST_CSR_TOTAL_HITS, hist_total_hits_csr);
        hist_csr_bus_read(HIST_CSR_BANK_STATUS, hist_bank_status_csr);
        hist_csr_bus_read(HIST_CSR_PORT_STATUS, hist_port_status_csr);
        hist_csr_bus_read(HIST_CSR_DROPPED_HITS, hist_dropped_hits_csr);

        expected_lane_hits = (real'(run_cycles) * real'(q16_rate) * 32.0) / 65536.0;
        expected_scaled_hits = expected_lane_hits * real'(lane_scale);
        expected_delta = real'(hist_total_hits_csr) - expected_lane_hits;
        expected_abs_delta = (expected_delta < 0.0) ? -expected_delta : expected_delta;
        expected_tolerance = expected_lane_hits * rate_tolerance_pct / 100.0;
        if (expected_tolerance < 8.0) begin
            expected_tolerance = 8.0;
        end

        $display("SUMMARY config arb_fifo_depth=%0d arb_counter_profile=%0d arb_debug_level=%0d mux_fifo_depth=%0d mux_debug_level=%0d emu_debug_level=%0d mts_debug=%0d",
                 ARB_FIFO_DEPTH_CONST,
                 ARB_COUNTER_PROFILE_CONST,
                 ARB_DEBUG_LEVEL_CONST,
                 MUX_FIFO_DEPTH_CONST,
                 MUX_DEBUG_LEVEL_CONST,
                 EMU_DEBUG_LEVEL_CONST,
                 MTS_DEBUG_CONST);
        $display("SUMMARY run_cycles=%0d q16_rate=%0d drain_cycles=%0d hist_interval_cycles=%0d hist_mode=%0d lane_scale=%0d do_switch_test=%0d expected_lane_hits=%0.3f expected_scaled_hits=%0.3f emu_hit_count=%0d emu_tx_count=%0d real_hit_count=%0d arb_selected_count=%0d arb_selected_emu=%0d arb_selected_real=%0d arb_metadata=%0d arb_metadata_emu=%0d arb_metadata_real=%0d arb_metadata_bad=%0d metadata_alignment_errors=%0d mux_out_count=%0d mts_type1_count=%0d mts_ext0_count=%0d mts_sidecar_count=%0d mts_sidecar_emu=%0d mts_sidecar_real=%0d hist_total_hits=%0d hist_bank_status=0x%08h hist_port_status=0x%08h hist_dropped_hits=%0d arb_status=0x%08h arb_ingress_real=%0d arb_ingress_emu=%0d arb_drops_real=%0d arb_drops_emu=%0d arb_egress_total_or_real=%0d arb_egress_emu=%0d",
                 run_cycles,
                 q16_rate,
                 drain_cycles,
                 hist_interval_cycles,
                 hist_mode,
                 lane_scale,
                 do_switch_test,
                 expected_lane_hits,
                 expected_scaled_hits,
                 emu_hit_count,
                 emu_tx_count,
                 real_hit_count,
                 arb_selected_count,
                 arb_selected_emu_count,
                 arb_selected_real_count,
                 arb_metadata_count,
                 arb_metadata_emu_count,
                 arb_metadata_real_count,
                 arb_metadata_bad_count,
                 metadata_alignment_errors,
                 mux_out_count,
                 mts_type1_count,
                 mts_ext0_count,
                 mts_sidecar_count,
                 mts_sidecar_emu_count,
                 mts_sidecar_real_count,
                 hist_total_hits_csr,
                 hist_bank_status_csr,
                 hist_port_status_csr,
                 hist_dropped_hits_csr,
                 arb_status_csr,
                 arb_ingress_real_csr,
                 arb_ingress_emu_csr,
                 arb_drops_real_csr,
                 arb_drops_emu_csr,
                 arb_egress_real_csr,
                 arb_egress_emu_csr);

        if (emu_tx_count != 0) begin
            $fatal(1, "BYTE_STREAM_ENABLE=0 contract violated: emulator tx8b1k emitted %0d beats", emu_tx_count);
        end
        if (emu_hit_count == 0) begin
            $fatal(1, "emulator hit_type0 output produced no valid hits");
        end
        if ((do_switch_test != 0) && (real_hit_count == 0)) begin
            $fatal(1, "directed real post-deassembly source produced no valid hits");
        end
        if (arb_selected_count == 0) begin
            $fatal(1, "arb_hit_type0 produced no selected hits");
        end
        if (DEBUG_METADATA_ENABLE &&
            (do_switch_test != 0) && (arb_selected_real_count == 0 || arb_selected_emu_count == 0)) begin
            $fatal(1, "mid-run arb switching did not select both sources: emu=%0d real=%0d",
                   arb_selected_emu_count, arb_selected_real_count);
        end
        if (DEBUG_METADATA_ENABLE &&
            (metadata_alignment_errors != 0 || arb_metadata_bad_count != 0)) begin
            $fatal(1, "DEBUG_LEVEL=2 metadata scoreboard failed: align_errors=%0d bad_tags=%0d",
                   metadata_alignment_errors, arb_metadata_bad_count);
        end
        if (DEBUG_METADATA_ENABLE && (arb_metadata_count != arb_selected_count)) begin
            $fatal(1, "arb metadata count %0d did not match selected hits %0d",
                   arb_metadata_count, arb_selected_count);
        end
        if (mux_out_count == 0 || mux_out_count != arb_selected_count) begin
            $fatal(1, "readyless mux count mismatch: mux=%0d arb=%0d",
                   mux_out_count, arb_selected_count);
        end
        if (mts_type1_count == 0 || mts_ext0_count == 0) begin
            $fatal(1, "MTS emitted no Type-1 or extended histogram-plane hits");
        end
        if (DEBUG_METADATA_ENABLE && (mts_sidecar_count == 0)) begin
            $fatal(1, "MTS DEBUG sidecar did not observe per-hit metadata");
        end
        if (hist_total_hits_csr == 0) begin
            $fatal(1, "histogram_statistics_v2 TOTAL_HITS stayed zero");
        end
        if (hist_total_hits_csr != hist_ext0_count) begin
            $fatal(1,
                   "histogram_statistics_v2 TOTAL_HITS (%0d) did not match MTS extended-plane count (%0d)",
                   hist_total_hits_csr,
                   hist_ext0_count);
        end
        if (hist_dropped_hits_csr != 0) begin
            $fatal(1, "histogram_statistics_v2 dropped %0d hits", hist_dropped_hits_csr);
        end
        if (ARB_TRIM3_COUNTERS) begin
            if (arb_drops_real_csr != 0 || arb_drops_emu_csr != 0 || arb_egress_emu_csr != 0) begin
                $fatal(1,
                       "trim3 removed-counter CSRs did not read zero: drops_real=%0d drops_emu=%0d egress_emu=%0d",
                       arb_drops_real_csr,
                       arb_drops_emu_csr,
                       arb_egress_emu_csr);
            end
            if (arb_egress_real_csr != arb_selected_count) begin
                $fatal(1,
                       "trim3 total egress counter %0d did not match selected hits %0d",
                       arb_egress_real_csr,
                       arb_selected_count);
            end
            if ((do_switch_test == 0) && (arb_ingress_emu_csr != emu_hit_count)) begin
                $fatal(1,
                       "trim3 emulator ingress counter %0d did not match produced hits %0d",
                       arb_ingress_emu_csr,
                       emu_hit_count);
            end
        end else begin
            if ((do_switch_test == 0) && (arb_drops_real_csr != 0 || arb_drops_emu_csr != 0)) begin
                $fatal(1, "arb_hit_type0 reported drops: real=%0d emu=%0d",
                       arb_drops_real_csr, arb_drops_emu_csr);
            end
            if ((do_switch_test != 0) && (arb_drops_real_csr != 0)) begin
                $fatal(1, "arb_hit_type0 dropped selected real-source hits during the switch window: real=%0d",
                       arb_drops_real_csr);
            end
            if ((do_switch_test != 0) &&
                ((arb_ingress_emu_csr + arb_drops_emu_csr) != emu_hit_count)) begin
                $fatal(1,
                       "arb emulator ingress accounting mismatch: accepted=%0d dropped=%0d produced=%0d",
                       arb_ingress_emu_csr,
                       arb_drops_emu_csr,
                       emu_hit_count);
            end
        end
        if ((do_switch_test == 0) && check_theory && (expected_abs_delta > expected_tolerance)) begin
            $fatal(1,
                   "single-lane histogram count %0d differs from 32-channel rate theory %0.3f by %0.3f hits, tolerance %0.3f",
                   hist_total_hits_csr,
                   expected_lane_hits,
                   expected_delta,
                   expected_tolerance);
        end

        arb_write(ARB_REG_CONTROL, {30'd0, ARB_MODE_REAL});
        repeat (8) @(posedge clk);
        send_arb_run_state(CTRL_RESET);
        repeat (8) @(posedge clk);
        arb_read(ARB_REG_STATUS, arb_status_after_reset_csr);
        if (arb_status_after_reset_csr[1:0] != ARB_MODE_EMU) begin
            $fatal(1, "arb mode did not reset to default EMU on run-control RESET: status=0x%08h",
                   arb_status_after_reset_csr);
        end

        arb_write(ARB_REG_CONTROL, {30'd0, ARB_MODE_REAL});
        repeat (8) @(posedge clk);
        rst = 1'b1;
        repeat (8) @(posedge clk);
        rst = 1'b0;
        repeat (8) @(posedge clk);
        arb_read(ARB_REG_STATUS, arb_status_after_hardreset_csr);
        if (arb_status_after_hardreset_csr[1:0] != ARB_MODE_EMU) begin
            $fatal(1, "arb mode did not reset to default EMU on hard reset: status=0x%08h",
                   arb_status_after_hardreset_csr);
        end

        $display("*** TEST PASSED ***");
        $finish;
    end
endmodule
