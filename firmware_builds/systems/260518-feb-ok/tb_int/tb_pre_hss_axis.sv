// tb_pre_hss_axis.sv
// Focused mixed-language smoke for the current Phase-4 pre-HSS gap:
// one generated emulator lane wrapper with BYTE_STREAM_ENABLE=1 drives the
// current frame_rcv_ip byte-stream sink. This does not model the full Qsys
// fabric; it only checks whether the source bytes are decodable before STP.

`timescale 1ns/1ps

module tb_pre_hss_axis;
    localparam real CLK_PERIOD_NS = 8.0;

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;

    logic clk = 1'b0;
    logic rst = 1'b1;

    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    logic [8:0]  tx_data;
    logic        tx_valid;
    logic [3:0]  tx_channel;
    logic [2:0]  tx_error;

    logic [44:0] emu_type0_data;
    logic        emu_type0_valid;
    logic [2:0]  emu_type0_error;
    logic [3:0]  emu_type0_channel;
    logic        emu_type0_sop;
    logic        emu_type0_eop;
    logic        emu_type0_eor;
    logic [15:0] emu_debug_fill;
    logic [63:0] emu_debug_hit_data;
    logic        emu_debug_hit_valid;
    logic [63:0] emu_hit_debug_data;
    logic        emu_hit_debug_valid;
    logic [3:0]  emu_hit_debug_channel;
    logic        emu_hit_debug_sop;
    logic        emu_hit_debug_eop;
    logic        emu_hit_debug_eor;

    logic [8:0]  ctrl_data;
    logic        ctrl_valid;
    logic        ctrl_ready;

    logic [3:0]  emu_csr_address;
    logic        emu_csr_read;
    logic        emu_csr_write;
    logic [31:0] emu_csr_writedata;
    logic [31:0] emu_csr_readdata;
    logic        emu_csr_waitrequest;

    logic [3:0]  parser_hit_channel;
    logic        parser_hit_sop;
    logic        parser_hit_eop;
    logic        parser_hit_eor;
    logic [2:0]  parser_hit_error;
    logic [44:0] parser_hit_data;
    logic        parser_hit_valid;
    logic [41:0] parser_header_data;
    logic        parser_header_valid;
    logic [3:0]  parser_header_channel;
    logic [31:0] parser_csr_readdata;
    logic        parser_csr_waitrequest;
    logic [31:0] parser_debug_fill;
    logic [63:0] parser_debug_hit_data;
    logic        parser_debug_hit_valid;

    int unsigned tx_valid_count;
    int unsigned emu_type0_count;
    int unsigned parser_header_count;
    int unsigned parser_hit_count;

    emulator_mutrig_qsys_lane #(
        .CSR_ADDR_WIDTH     (4),
        .ASIC_ID_DEFAULT    (4'd0),
        .BYTE_STREAM_ENABLE (1'b1),
        .DEBUG_LEVEL        (1)
    ) u_emu (
        .i_clk                         (clk),
        .i_rst                         (rst),
        .aso_hit_type0_data            (emu_type0_data),
        .aso_hit_type0_valid           (emu_type0_valid),
        .aso_hit_type0_error           (emu_type0_error),
        .aso_hit_type0_channel         (emu_type0_channel),
        .aso_hit_type0_startofpacket   (emu_type0_sop),
        .aso_hit_type0_endofpacket     (emu_type0_eop),
        .aso_hit_type0_endofrun        (emu_type0_eor),
        .coe_debug_fifo_fill_level     (emu_debug_fill),
        .coe_debug_hit_metadata        (emu_debug_hit_data),
        .coe_debug_hit_metadata_valid  (emu_debug_hit_valid),
        .aso_hit_debug_data            (emu_hit_debug_data),
        .aso_hit_debug_valid           (emu_hit_debug_valid),
        .aso_hit_debug_channel         (emu_hit_debug_channel),
        .aso_hit_debug_startofpacket   (emu_hit_debug_sop),
        .aso_hit_debug_endofpacket     (emu_hit_debug_eop),
        .aso_hit_debug_endofrun        (emu_hit_debug_eor),
        .aso_tx8b1k_data               (tx_data),
        .aso_tx8b1k_valid              (tx_valid),
        .aso_tx8b1k_channel            (tx_channel),
        .aso_tx8b1k_error              (tx_error),
        .asi_ctrl_data                 (ctrl_data),
        .asi_ctrl_valid                (ctrl_valid),
        .asi_ctrl_ready                (ctrl_ready),
        .coe_inject_pulse              (1'b0),
        .coe_inject_masked_pulse       (1'b0),
        .avs_csr_address               (emu_csr_address),
        .avs_csr_read                  (emu_csr_read),
        .avs_csr_write                 (emu_csr_write),
        .avs_csr_writedata             (emu_csr_writedata),
        .avs_csr_readdata              (emu_csr_readdata),
        .avs_csr_waitrequest           (emu_csr_waitrequest)
    );

    frame_rcv_ip #(
        .CHANNEL_WIDTH  (4),
        .CSR_ADDR_WIDTH (2),
        .MODE_HALT      (0),
        .DEBUG_LV       (1)
    ) u_parser (
        .asi_rx8b1k_data               (tx_data),
        .asi_rx8b1k_valid              (tx_valid),
        .asi_rx8b1k_error              (tx_error),
        .asi_rx8b1k_channel            (tx_channel),
        .aso_hit_type0_channel         (parser_hit_channel),
        .aso_hit_type0_startofpacket   (parser_hit_sop),
        .aso_hit_type0_endofpacket     (parser_hit_eop),
        .aso_hit_type0_endofrun        (parser_hit_eor),
        .aso_hit_type0_error           (parser_hit_error),
        .aso_hit_type0_data            (parser_hit_data),
        .aso_hit_type0_valid           (parser_hit_valid),
        .aso_headerinfo_data           (parser_header_data),
        .aso_headerinfo_valid          (parser_header_valid),
        .aso_headerinfo_channel        (parser_header_channel),
        .avs_csr_readdata              (parser_csr_readdata),
        .avs_csr_read                  (1'b0),
        .avs_csr_address               (2'b00),
        .avs_csr_waitrequest           (parser_csr_waitrequest),
        .avs_csr_write                 (1'b0),
        .avs_csr_writedata             (32'h0000_0000),
        .asi_ctrl_data                 (ctrl_data),
        .asi_ctrl_valid                (ctrl_valid),
        .coe_debug_fifo_fill_levels    (parser_debug_fill),
        .coe_debug_hit_metadata        (parser_debug_hit_data),
        .coe_debug_hit_metadata_valid  (parser_debug_hit_valid),
        .i_rst                         (rst),
        .i_clk                         (clk)
    );

    task automatic send_ctrl(input logic [8:0] state);
        @(posedge clk);
        ctrl_data  <= state;
        ctrl_valid <= 1'b1;
        @(posedge clk);
        ctrl_valid <= 1'b0;
    endtask

    always_ff @(posedge clk) begin
        if (rst) begin
            tx_valid_count      <= 0;
            emu_type0_count     <= 0;
            parser_header_count <= 0;
            parser_hit_count    <= 0;
        end else begin
            if (tx_valid)            tx_valid_count++;
            if (emu_type0_valid)     emu_type0_count++;
            if (parser_header_valid) parser_header_count++;
            if (parser_hit_valid)    parser_hit_count++;
        end
    end

    initial begin
        ctrl_data         = CTRL_IDLE;
        ctrl_valid        = 1'b0;
        emu_csr_address   = '0;
        emu_csr_read      = 1'b0;
        emu_csr_write     = 1'b0;
        emu_csr_writedata = '0;

        repeat (20) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        send_ctrl(CTRL_RUN_PREPARE);
        repeat (5) @(posedge clk);
        send_ctrl(CTRL_SYNC);
        repeat (5) @(posedge clk);
        send_ctrl(CTRL_RUNNING);

        repeat (30000) @(posedge clk);

        $display("PRE_HSS_AXIS_COUNTS tx_valid=%0d emu_type0=%0d parser_headers=%0d parser_hits=%0d",
                 tx_valid_count, emu_type0_count, parser_header_count, parser_hit_count);

        if (tx_valid_count == 0) begin
            $fatal(1, "PRE_HSS_AXIS_FAIL: emulator tx8b1k never asserted valid");
        end
        if (emu_type0_count == 0) begin
            $fatal(1, "PRE_HSS_AXIS_FAIL: emulator direct type0 path stayed dark");
        end
        if (parser_header_count == 0 || parser_hit_count == 0) begin
            $fatal(1, "PRE_HSS_AXIS_FAIL: frame_rcv_ip did not decode enabled byte stream");
        end

        $display("*** PRE_HSS_AXIS PASSED ***");
        $finish;
    end
endmodule
