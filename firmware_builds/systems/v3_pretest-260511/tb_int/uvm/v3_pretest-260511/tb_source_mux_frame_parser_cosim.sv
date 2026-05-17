`timescale 1ns/1ps

module tb_source_mux_frame_parser_cosim;
    localparam real CLK_PERIOD_NS = 8.0;

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;

    localparam logic [5:0] EMU_REG_CENTRAL       = 6'h07;
    localparam logic [5:0] EMU_REG_SIGNAL        = 6'h08;
    localparam logic [5:0] EMU_REG_BACKGROUND    = 6'h09;
    localparam logic [5:0] EMU_REG_FORMAT        = 6'h0A;
    localparam logic [5:0] EMU_REG_RATES         = 6'h0B;
    localparam logic [5:0] EMU_REG_CLUSTER_FIX   = 6'h0C;
    localparam logic [5:0] EMU_REG_PRNG_SEED     = 6'h0E;
    localparam logic [5:0] EMU_REG_TIMEBASE_SEED = 6'h0F;
    localparam logic [5:0] EMU_REG_LANE_ENABLE   = 6'h12;

    localparam logic [3:0] MLSM_REG_CONTROL       = 4'h2;
    localparam logic [3:0] MLSM_REG_EMU_BEATS     = 4'h5;
    localparam logic [3:0] MLSM_REG_SELECTED_BEATS= 4'h6;
    localparam logic [3:0] MLSM_REG_EMU_SELECTED  = 4'hD;

    logic clk = 1'b0;
    logic rst = 1'b1;

    logic [8:0]  emu_tx_data;
    logic        emu_tx_valid;
    logic [3:0]  emu_tx_channel;
    logic [2:0]  emu_tx_error;
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
    logic [8:0]  emu_ctrl_data;
    logic        emu_ctrl_valid;
    logic        emu_ctrl_ready;
    logic [5:0]  emu_csr_address;
    logic        emu_csr_read;
    logic        emu_csr_write;
    logic [31:0] emu_csr_writedata;
    logic [31:0] emu_csr_readdata;
    logic        emu_csr_waitrequest;

    logic [3:0]  mux_csr_address;
    logic        mux_csr_read;
    logic        mux_csr_write;
    logic [31:0] mux_csr_writedata;
    logic [31:0] mux_csr_readdata;
    logic        mux_csr_waitrequest;
    logic [8:0]  mux_data;
    logic        mux_valid;
    logic [2:0]  mux_error;
    logic [3:0]  mux_channel;
    logic [8:0]  lane_adapter_024_data;
    logic        lane_adapter_024_valid;
    logic        lane_adapter_024_ready;
    logic [2:0]  lane_adapter_024_error;
    logic [4:0]  lane_adapter_024_channel;
    logic [8:0]  lane_fifo_data;
    logic        lane_fifo_valid;
    logic        lane_fifo_ready;
    logic [2:0]  lane_fifo_error;
    logic [4:0]  lane_fifo_channel;
    logic [8:0]  parser_rx_data;
    logic        parser_rx_valid;
    logic [2:0]  parser_rx_error;
    logic [3:0]  parser_rx_channel;

    logic [3:0]  parser_hit_channel;
    logic        parser_hit_sop;
    logic        parser_hit_eop;
    logic        parser_hit_eor;
    logic [2:0]  parser_hit_error;
    logic [44:0] parser_hit_data;
    logic        parser_hit_valid;
    logic [41:0] parser_headerinfo_data;
    logic        parser_headerinfo_valid;
    logic [3:0]  parser_headerinfo_channel;
    logic [31:0] parser_csr_readdata;
    logic        parser_csr_read;
    logic [1:0]  parser_csr_address;
    logic        parser_csr_waitrequest;
    logic        parser_csr_write;
    logic [31:0] parser_csr_writedata;
    logic [8:0]  parser_ctrl_data;
    logic        parser_ctrl_valid;
    logic        parser_ctrl_ready;
    logic        parser_dbg_enable;
    logic        parser_dbg_receiver_go;
    logic        parser_dbg_receiver_force_go;
    logic        parser_dbg_terminating_pending;
    logic [7:0]  parser_dbg_csr_control;
    logic [7:0]  parser_dbg_csr_status;
    logic [31:0] parser_dbg_crc_err_counter;
    logic [31:0] parser_dbg_frame_counter;
    logic [31:0] parser_dbg_frame_counter_head;
    logic [31:0] parser_dbg_frame_counter_tail;
    logic        parser_dbg_n_new_frame;
    logic        parser_dbg_n_new_word;
    logic        parser_dbg_p_new_word;
    logic [47:0] parser_dbg_n_word;
    logic [47:0] parser_dbg_s_o_word;
    logic [9:0]  parser_dbg_n_word_cnt;
    logic [9:0]  parser_dbg_p_word_cnt;
    logic [9:0]  parser_dbg_n_frame_len;
    logic [9:0]  parser_dbg_p_frame_len;
    logic [15:0] parser_dbg_n_frame_number;
    logic [5:0]  parser_dbg_n_frame_flags;
    logic [5:0]  parser_dbg_p_frame_flags;
    logic        parser_dbg_n_frame_info_ready;
    logic        parser_dbg_n_frame_info_ready_d1;
    logic        parser_dbg_headerinfo_valid_comb;
    logic        parser_dbg_n_crc_error;
    logic [31:0] parser_dbg_p_crc_err_count;

    int unsigned run_cycles;
    int unsigned q16_rate;
    int unsigned mux_control_word;
    longint unsigned cycle_count;
    int unsigned emu_tx_count;
    int unsigned emu_header_count;
    int unsigned mux_selected_count;
    int unsigned parser_rx_count;
    int unsigned parser_header_count;
    int unsigned parser_hit_count;
    int unsigned parser_new_frame_count;
    int unsigned parser_new_word_count;
    logic [41:0] last_headerinfo;
    logic [44:0] last_hit_data;
    logic [31:0] mux_emu_beats_csr;
    logic [31:0] mux_selected_beats_csr;
    logic [31:0] mux_emu_selected_csr;

    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    initial begin
        repeat (12) @(posedge clk);
        rst = 1'b0;
    end

    emulator_mutrig_qsys_lane #(
        .CSR_ADDR_WIDTH(6),
        .ASIC_ID_DEFAULT(4'd0),
        .BYTE_STREAM_ENABLE(1'b1),
        .DEBUG_LEVEL(2)
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

    mutrig_lane_source_mux #(
        .SELECT_EMULATOR(0),
        .FIFO_DEPTH(16),
        .REAL_ALWAYS_VALID(0),
        .INSTANCE_ID(32'h0000_0001)
    ) u_source_mux (
        .clk(clk),
        .rst(rst),
        .avs_csr_address(mux_csr_address),
        .avs_csr_write(mux_csr_write),
        .avs_csr_read(mux_csr_read),
        .avs_csr_writedata(mux_csr_writedata),
        .avs_csr_readdata(mux_csr_readdata),
        .avs_csr_waitrequest(mux_csr_waitrequest),
        .asi_real_data({1'b1, 8'hBC}),
        .asi_real_valid(1'b0),
        .asi_real_error(3'b000),
        .asi_real_channel(4'd0),
        .asi_emu_data(emu_tx_data),
        .asi_emu_valid(emu_tx_valid),
        .asi_emu_error(emu_tx_error),
        .asi_emu_channel(emu_tx_channel),
        .aso_data(mux_data),
        .aso_valid(mux_valid),
        .aso_error(mux_error),
	        .aso_channel(mux_channel)
    );

    feb_system_v3_data_path_subsystem_avalon_st_adapter_024 u_lane_adapter_024 (
        .in_clk_0_clk(clk),
        .in_rst_0_reset(rst),
        .in_0_data(mux_data),
        .in_0_valid(mux_valid),
        .in_0_error(mux_error),
        .in_0_channel(mux_channel),
        .out_0_data(lane_adapter_024_data),
        .out_0_valid(lane_adapter_024_valid),
        .out_0_ready(lane_adapter_024_ready),
        .out_0_error(lane_adapter_024_error),
        .out_0_channel(lane_adapter_024_channel)
    );

    altera_avalon_sc_fifo #(
        .SYMBOLS_PER_BEAT(1),
        .BITS_PER_SYMBOL(9),
        .FIFO_DEPTH(8),
        .CHANNEL_WIDTH(5),
        .ERROR_WIDTH(3),
        .USE_PACKETS(0),
        .USE_FILL_LEVEL(0),
        .EMPTY_LATENCY(3),
        .USE_MEMORY_BLOCKS(0),
        .USE_STORE_FORWARD(0),
        .USE_ALMOST_FULL_IF(0),
        .USE_ALMOST_EMPTY_IF(0)
    ) u_decoded_lane_fifo_0 (
        .clk(clk),
        .reset(rst),
        .in_data(lane_adapter_024_data),
        .in_valid(lane_adapter_024_valid),
        .in_startofpacket(1'b0),
        .in_endofpacket(1'b0),
        .in_empty(1'b0),
        .in_error(lane_adapter_024_error),
        .in_channel(lane_adapter_024_channel),
        .in_ready(lane_adapter_024_ready),
        .out_data(lane_fifo_data),
        .out_valid(lane_fifo_valid),
        .out_startofpacket(),
        .out_endofpacket(),
        .out_empty(),
        .out_error(lane_fifo_error),
        .out_channel(lane_fifo_channel),
        .out_ready(lane_fifo_ready),
        .csr_address(2'b00),
        .csr_write(1'b0),
        .csr_read(1'b0),
        .csr_writedata(32'h0000_0000),
        .csr_readdata(),
        .almost_full_data(),
        .almost_empty_data()
    );

    feb_system_v3_data_path_subsystem_avalon_st_adapter_009 u_lane_adapter_009 (
        .in_clk_0_clk(clk),
        .in_rst_0_reset(rst),
        .in_0_data(lane_fifo_data),
        .in_0_valid(lane_fifo_valid),
        .in_0_ready(lane_fifo_ready),
        .in_0_error(lane_fifo_error),
        .in_0_channel(lane_fifo_channel),
        .out_0_data(parser_rx_data),
        .out_0_valid(parser_rx_valid),
        .out_0_error(parser_rx_error),
        .out_0_channel(parser_rx_channel)
    );

    frame_rcv_ip_dut_sv #(
        .CHANNEL_WIDTH(4),
        .CSR_ADDR_WIDTH(2),
        .MODE_HALT(0),
        .DEBUG_LV(2)
    ) u_parser (
        .asi_rx8b1k_data(parser_rx_data),
        .asi_rx8b1k_valid(parser_rx_valid),
        .asi_rx8b1k_error(parser_rx_error),
        .asi_rx8b1k_channel(parser_rx_channel),
        .aso_hit_type0_channel(parser_hit_channel),
        .aso_hit_type0_startofpacket(parser_hit_sop),
        .aso_hit_type0_endofpacket(parser_hit_eop),
        .aso_hit_type0_endofrun(parser_hit_eor),
        .aso_hit_type0_error(parser_hit_error),
        .aso_hit_type0_data(parser_hit_data),
        .aso_hit_type0_valid(parser_hit_valid),
        .aso_headerinfo_data(parser_headerinfo_data),
        .aso_headerinfo_valid(parser_headerinfo_valid),
        .aso_headerinfo_channel(parser_headerinfo_channel),
        .avs_csr_readdata(parser_csr_readdata),
        .avs_csr_read(parser_csr_read),
        .avs_csr_address(parser_csr_address),
        .avs_csr_waitrequest(parser_csr_waitrequest),
        .avs_csr_write(parser_csr_write),
        .avs_csr_writedata(parser_csr_writedata),
        .asi_ctrl_data(parser_ctrl_data),
        .asi_ctrl_valid(parser_ctrl_valid),
        .asi_ctrl_ready(parser_ctrl_ready),
        .i_rst(rst),
        .i_clk(clk),
        .dbg_enable(parser_dbg_enable),
        .dbg_receiver_go(parser_dbg_receiver_go),
        .dbg_receiver_force_go(parser_dbg_receiver_force_go),
        .dbg_terminating_pending(parser_dbg_terminating_pending),
        .dbg_csr_control(parser_dbg_csr_control),
        .dbg_csr_status(parser_dbg_csr_status),
        .dbg_crc_err_counter(parser_dbg_crc_err_counter),
        .dbg_frame_counter(parser_dbg_frame_counter),
        .dbg_frame_counter_head(parser_dbg_frame_counter_head),
        .dbg_frame_counter_tail(parser_dbg_frame_counter_tail),
        .dbg_n_new_frame(parser_dbg_n_new_frame),
        .dbg_n_new_word(parser_dbg_n_new_word),
        .dbg_p_new_word(parser_dbg_p_new_word),
        .dbg_n_word(parser_dbg_n_word),
        .dbg_s_o_word(parser_dbg_s_o_word),
        .dbg_n_word_cnt(parser_dbg_n_word_cnt),
        .dbg_p_word_cnt(parser_dbg_p_word_cnt),
        .dbg_n_frame_len(parser_dbg_n_frame_len),
        .dbg_p_frame_len(parser_dbg_p_frame_len),
        .dbg_n_frame_number(parser_dbg_n_frame_number),
        .dbg_n_frame_flags(parser_dbg_n_frame_flags),
        .dbg_p_frame_flags(parser_dbg_p_frame_flags),
        .dbg_n_frame_info_ready(parser_dbg_n_frame_info_ready),
        .dbg_n_frame_info_ready_d1(parser_dbg_n_frame_info_ready_d1),
        .dbg_headerinfo_valid_comb(parser_dbg_headerinfo_valid_comb),
        .dbg_n_crc_error(parser_dbg_n_crc_error),
        .dbg_p_crc_err_count(parser_dbg_p_crc_err_count)
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

    task automatic mux_write(input logic [3:0] addr, input logic [31:0] data);
        @(posedge clk);
        mux_csr_address   <= addr;
        mux_csr_writedata <= data;
        mux_csr_write     <= 1'b1;
        mux_csr_read      <= 1'b0;
        @(posedge clk);
        mux_csr_write     <= 1'b0;
    endtask

    task automatic mux_read(input logic [3:0] addr, output logic [31:0] data);
        @(posedge clk);
        mux_csr_address <= addr;
        mux_csr_read    <= 1'b1;
        mux_csr_write   <= 1'b0;
        @(posedge clk);
        data = mux_csr_readdata;
        mux_csr_read <= 1'b0;
    endtask

    task automatic parser_write(input logic [1:0] addr, input logic [31:0] data);
        @(posedge clk);
        parser_csr_address   <= addr;
        parser_csr_writedata <= data;
        parser_csr_write     <= 1'b1;
        parser_csr_read      <= 1'b0;
        @(posedge clk);
        parser_csr_write     <= 1'b0;
    endtask

    task automatic send_run_state(input logic [8:0] state);
        @(posedge clk);
        emu_ctrl_data       <= state;
        emu_ctrl_valid      <= 1'b1;
        parser_ctrl_data    <= state;
        parser_ctrl_valid   <= 1'b1;
        @(posedge clk);
        emu_ctrl_valid      <= 1'b0;
        parser_ctrl_valid   <= 1'b0;
        emu_ctrl_data       <= CTRL_IDLE;
        parser_ctrl_data    <= CTRL_IDLE;
    endtask

    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
            emu_tx_count <= 0;
            emu_header_count <= 0;
            mux_selected_count <= 0;
            parser_rx_count <= 0;
            parser_header_count <= 0;
            parser_hit_count <= 0;
            parser_new_frame_count <= 0;
            parser_new_word_count <= 0;
            last_headerinfo <= '0;
            last_hit_data <= '0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (emu_tx_valid) begin
                emu_tx_count <= emu_tx_count + 1;
                if ((emu_tx_data[8] == 1'b1) && (emu_tx_data[7:0] == 8'h1C)) begin
                    emu_header_count <= emu_header_count + 1;
                end
            end

            if (mux_valid) begin
                mux_selected_count <= mux_selected_count + 1;
                if (mux_selected_count < 12) begin
                    $display("MUX_BEAT cycle=%0d data=0x%03h ch=%0d err=0x%0h", cycle_count, mux_data, mux_channel, mux_error);
                end
            end

            if (parser_rx_valid) begin
                parser_rx_count <= parser_rx_count + 1;
                if (parser_rx_count < 12) begin
                    $display("PARSER_RX_BEAT cycle=%0d data=0x%03h ch=%0d err=0x%0h",
                             cycle_count, parser_rx_data, parser_rx_channel, parser_rx_error);
                end
            end

            if (parser_dbg_n_new_frame) begin
                parser_new_frame_count <= parser_new_frame_count + 1;
            end

            if (parser_dbg_n_new_word) begin
                parser_new_word_count <= parser_new_word_count + 1;
            end

            if (parser_headerinfo_valid) begin
                parser_header_count <= parser_header_count + 1;
                last_headerinfo <= parser_headerinfo_data;
                if (parser_header_count < 8) begin
                    $display("PARSER_HEADER cycle=%0d headerinfo=0x%011h flags=0x%02h len=%0d frame=0x%04h",
                             cycle_count,
                             parser_headerinfo_data,
                             parser_headerinfo_data[5:0],
                             parser_headerinfo_data[15:6],
                             parser_headerinfo_data[41:26]);
                end
            end

            if (parser_hit_valid) begin
                parser_hit_count <= parser_hit_count + 1;
                last_hit_data <= parser_hit_data;
                if (parser_hit_count < 8) begin
                    $display("PARSER_HIT cycle=%0d data=0x%012h sop=%0b eop=%0b err=0x%0h",
                             cycle_count,
                             parser_hit_data,
                             parser_hit_sop,
                             parser_hit_eop,
                             parser_hit_error);
                end
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
        if (!$value$plusargs("MUX_CONTROL=%d", mux_control_word)) begin
            mux_control_word = 3;
        end

        emu_ctrl_data = CTRL_IDLE;
        emu_ctrl_valid = 1'b0;
        emu_csr_address = '0;
        emu_csr_read = 1'b0;
        emu_csr_write = 1'b0;
        emu_csr_writedata = '0;
        mux_csr_address = '0;
        mux_csr_read = 1'b0;
        mux_csr_write = 1'b0;
        mux_csr_writedata = '0;
        parser_csr_address = '0;
        parser_csr_read = 1'b0;
        parser_csr_write = 1'b0;
        parser_csr_writedata = '0;
        parser_ctrl_data = CTRL_IDLE;
        parser_ctrl_valid = 1'b0;

        wait (rst == 1'b0);
        repeat (8) @(posedge clk);

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

        mux_write(MLSM_REG_CONTROL, mux_control_word[31:0]);
        parser_write(2'd0, 32'h0000_0001);

        send_run_state(CTRL_RUN_PREPARE);
        repeat (8) @(posedge clk);
        send_run_state(CTRL_SYNC);
        repeat (8) @(posedge clk);
        send_run_state(CTRL_RUNNING);

        repeat (run_cycles) @(posedge clk);

        mux_read(MLSM_REG_EMU_BEATS, mux_emu_beats_csr);
        mux_read(MLSM_REG_SELECTED_BEATS, mux_selected_beats_csr);
        mux_read(MLSM_REG_EMU_SELECTED, mux_emu_selected_csr);

        $display("SUMMARY run_cycles=%0d q16_rate=%0d mux_control=0x%08h emu_tx_count=%0d emu_header_count=%0d mux_selected_count=%0d parser_rx_count=%0d parser_new_frame_count=%0d parser_header_count=%0d parser_new_word_count=%0d parser_hit_count=%0d parser_enable=%0b receiver_go=%0b parser_csr_control=0x%02h parser_csr_status=0x%02h crc_err=%0d frame_head=%0d frame_tail=%0d mux_csr_emu=%0d mux_csr_selected=%0d mux_csr_emu_selected=%0d last_header=0x%011h last_hit=0x%012h",
                 run_cycles,
                 q16_rate,
                 mux_control_word[31:0],
                 emu_tx_count,
                 emu_header_count,
                 mux_selected_count,
                 parser_rx_count,
                 parser_new_frame_count,
                 parser_header_count,
                 parser_new_word_count,
                 parser_hit_count,
                 parser_dbg_enable,
                 parser_dbg_receiver_go,
                 parser_dbg_csr_control,
                 parser_dbg_csr_status,
                 parser_dbg_crc_err_counter,
                 parser_dbg_frame_counter_head,
                 parser_dbg_frame_counter_tail,
                 mux_emu_beats_csr,
                 mux_selected_beats_csr,
                 mux_emu_selected_csr,
                 last_headerinfo,
                 last_hit_data);

        if (emu_tx_count == 0) begin
            $fatal(1, "emulator tx8b1k produced no valid bytes");
        end
        if (mux_selected_count == 0) begin
            $fatal(1, "source mux produced no selected bytes");
        end
        if (parser_rx_count == 0) begin
            $fatal(1, "generated adapter/FIFO lane chain produced no parser input bytes");
        end
        if (parser_new_frame_count == 0 || parser_header_count == 0) begin
            $fatal(1, "frame parser did not recognize any headers");
        end
        if (parser_hit_count == 0) begin
            $fatal(1, "frame parser saw headers but emitted no hits");
        end

        $display("*** TEST PASSED ***");
        $finish;
    end
endmodule
