`timescale 1ns/1ps

`ifndef MLSM_REAL_ALWAYS_VALID
`define MLSM_REAL_ALWAYS_VALID 1
`endif

`ifndef MLSM_FIFO_DEPTH
`define MLSM_FIFO_DEPTH 16
`endif

module mlsm_downstream_input_probe (
    input  logic        clk,
    input  logic        rst,
    input  logic        clear,
    input  logic [8:0]  aso_data,
    input  logic        aso_valid,
    input  logic [2:0]  aso_error,
    input  logic [3:0]  aso_channel,
    output logic [31:0] valid_count,
    output logic [8:0]  last_data,
    output logic [2:0]  last_error,
    output logic [3:0]  last_channel
);
    localparam logic [8:0] RUNNING_CTRL_WORD_CONST = 9'b000001000;

    logic [3:0] downstream_start_count = 4'd0;
    logic       downstream_ctrl_valid;
    logic       downstream_rst;

    always_ff @(posedge clk or posedge rst or posedge clear) begin : probe_reg
        if (rst || clear) begin
            valid_count     <= 32'd0;
            last_data       <= 9'd0;
            last_error      <= 3'd0;
            last_channel    <= 4'd0;
        end else if (aso_valid) begin
            valid_count     <= valid_count + 32'd1;
            last_data       <= aso_data;
            last_error      <= aso_error;
            last_channel    <= aso_channel;
        end
    end

    always_ff @(posedge clk or posedge rst) begin : downstream_start_reg
        if (rst) begin
            downstream_start_count <= 4'd0;
        end else if (downstream_start_count != 4'hf) begin
            downstream_start_count <= downstream_start_count + 4'd1;
        end
    end

    assign downstream_ctrl_valid = (downstream_start_count == 4'hf);
    assign downstream_rst        = rst || !downstream_ctrl_valid;

    property selected_stream_is_known;
        @(posedge clk) disable iff (rst)
            aso_valid |-> !$isunknown({aso_data, aso_error, aso_channel});
    endproperty

    assert property (selected_stream_is_known)
        else $error("selected mux output contains X/Z while valid");

    frame_rcv_ip_dut_sv #(
        .CHANNEL_WIDTH(4),
        .CSR_ADDR_WIDTH(2),
        .MODE_HALT(0),
        .DEBUG_LV(0)
    ) downstream_input_contract (
        .asi_rx8b1k_data(aso_data),
        .asi_rx8b1k_valid(aso_valid),
        .asi_rx8b1k_error(aso_error),
        .asi_rx8b1k_channel(aso_channel),
        .aso_hit_type0_channel(),
        .aso_hit_type0_startofpacket(),
        .aso_hit_type0_endofpacket(),
        .aso_hit_type0_endofrun(),
        .aso_hit_type0_error(),
        .aso_hit_type0_data(),
        .aso_hit_type0_valid(),
        .aso_headerinfo_data(),
        .aso_headerinfo_valid(),
        .aso_headerinfo_channel(),
        .avs_csr_readdata(),
        .avs_csr_read(1'b0),
        .avs_csr_address(2'd0),
        .avs_csr_waitrequest(),
        .avs_csr_write(1'b0),
        .avs_csr_writedata(32'd0),
        .asi_ctrl_data(RUNNING_CTRL_WORD_CONST),
        .asi_ctrl_valid(downstream_ctrl_valid),
        .asi_ctrl_ready(),
        .i_rst(downstream_rst),
        .i_clk(clk),
        .dbg_enable(),
        .dbg_receiver_go(),
        .dbg_receiver_force_go(),
        .dbg_terminating_pending(),
        .dbg_csr_control(),
        .dbg_csr_status(),
        .dbg_crc_err_counter(),
        .dbg_frame_counter(),
        .dbg_frame_counter_head(),
        .dbg_frame_counter_tail(),
        .dbg_n_new_frame(),
        .dbg_n_new_word(),
        .dbg_p_new_word(),
        .dbg_n_word(),
        .dbg_s_o_word(),
        .dbg_n_word_cnt(),
        .dbg_p_word_cnt(),
        .dbg_n_frame_len(),
        .dbg_p_frame_len(),
        .dbg_n_frame_number(),
        .dbg_n_frame_flags(),
        .dbg_p_frame_flags(),
        .dbg_n_frame_info_ready(),
        .dbg_n_frame_info_ready_d1(),
        .dbg_headerinfo_valid_comb(),
        .dbg_n_crc_error(),
        .dbg_p_crc_err_count()
    );
endmodule

module tb_top;
    import uvm_pkg::*;
    import mlsm_env_pkg::*;

    localparam int REAL_ALWAYS_VALID_CONST = `MLSM_REAL_ALWAYS_VALID;
    localparam int FIFO_DEPTH_CONST        = `MLSM_FIFO_DEPTH;

    logic clk = 1'b0;

    always #4 clk = ~clk;

    mlsm_if mif(clk);

    mutrig_lane_source_mux #(
        .SELECT_EMULATOR(0),
        .FIFO_DEPTH(FIFO_DEPTH_CONST),
        .REAL_ALWAYS_VALID(REAL_ALWAYS_VALID_CONST),
        .VERSION_PATCH(1),
        .BUILD(503),
        .VERSION_DATE(20260503),
        .INSTANCE_ID(16'h51A0)
    ) dut (
        .clk(clk),
        .rst(mif.rst),
        .avs_csr_address(mif.avs_csr_address),
        .avs_csr_write(mif.avs_csr_write),
        .avs_csr_read(mif.avs_csr_read),
        .avs_csr_writedata(mif.avs_csr_writedata),
        .avs_csr_readdata(mif.avs_csr_readdata),
        .avs_csr_waitrequest(mif.avs_csr_waitrequest),
        .asi_real_data(mif.asi_real_data),
        .asi_real_valid(mif.asi_real_valid),
        .asi_real_error(mif.asi_real_error),
        .asi_real_channel(mif.asi_real_channel),
        .asi_emu_data(mif.asi_emu_data),
        .asi_emu_valid(mif.asi_emu_valid),
        .asi_emu_error(mif.asi_emu_error),
        .asi_emu_channel(mif.asi_emu_channel),
        .aso_data(mif.aso_data),
        .aso_valid(mif.aso_valid),
        .aso_error(mif.aso_error),
        .aso_channel(mif.aso_channel)
    );

    mlsm_downstream_input_probe probe (
        .clk(clk),
        .rst(mif.rst),
        .clear(mif.probe_clear),
        .aso_data(mif.aso_data),
        .aso_valid(mif.aso_valid),
        .aso_error(mif.aso_error),
        .aso_channel(mif.aso_channel),
        .valid_count(mif.probe_valid_count),
        .last_data(mif.probe_last_data),
        .last_error(mif.probe_last_error),
        .last_channel(mif.probe_last_channel)
    );

    initial begin : uvm_boot
        uvm_config_db#(virtual mlsm_if)::set(null, "*", "vif", mif);
        uvm_config_db#(int)::set(null, "*", "real_always_valid", REAL_ALWAYS_VALID_CONST);
        uvm_config_db#(int)::set(null, "*", "fifo_depth", FIFO_DEPTH_CONST);
        run_test();
    end
endmodule
