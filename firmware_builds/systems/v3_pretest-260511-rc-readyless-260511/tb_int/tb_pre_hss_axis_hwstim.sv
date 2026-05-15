// tb_pre_hss_axis_hwstim.sv
// Directed mirror of the 2026-05-12 pre-HSS STP board stimulus.  It applies
// the exact lane-0 emulator CSR tuple used by the JTAG setup, then checks
// whether the tx8b1k byte-stream valid should assert.

`timescale 1ns/1ps

module tb_pre_hss_axis_hwstim;
    localparam real CLK_PERIOD_NS = 8.0;

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;

    localparam logic [3:0] CSR_CENTRAL       = 4'h7;
    localparam logic [3:0] CSR_SIGNAL        = 4'h8;
    localparam logic [3:0] CSR_BACKGROUND    = 4'h9;
    localparam logic [3:0] CSR_MUTRIG_FORMAT = 4'hA;
    localparam logic [3:0] CSR_RATES         = 4'hB;
    localparam logic [3:0] CSR_CLUSTER_FIX   = 4'hC;
    localparam logic [3:0] CSR_PRNG_SEED     = 4'hE;

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

    int unsigned tx_valid_count;
    int unsigned emu_type0_count;
    int unsigned hit_debug_count;
    time first_tx_time;
    time first_type0_time;

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

    task automatic clear_counts();
        tx_valid_count  = 0;
        emu_type0_count = 0;
        hit_debug_count = 0;
        first_tx_time   = 0;
        first_type0_time = 0;
    endtask

    task automatic csr_write(input logic [3:0] address, input logic [31:0] data);
        @(posedge clk);
        emu_csr_address   <= address;
        emu_csr_writedata <= data;
        emu_csr_write     <= 1'b1;
        @(posedge clk);
        emu_csr_write     <= 1'b0;
        emu_csr_writedata <= 32'h0000_0000;
    endtask

    task automatic send_ctrl(input logic [8:0] state);
        @(posedge clk);
        ctrl_data  <= state;
        ctrl_valid <= 1'b1;
        @(posedge clk);
        ctrl_valid <= 1'b0;
    endtask

    task automatic reset_dut();
        rst = 1'b1;
        ctrl_data         = CTRL_IDLE;
        ctrl_valid        = 1'b0;
        emu_csr_address   = '0;
        emu_csr_read      = 1'b0;
        emu_csr_write     = 1'b0;
        emu_csr_writedata = '0;
        clear_counts();
        repeat (20) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);
    endtask

    task automatic configure_lane(input logic [31:0] signal_word);
        csr_write(CSR_CENTRAL,       32'h0000_0001);
        csr_write(CSR_SIGNAL,        signal_word);
        csr_write(CSR_BACKGROUND,    32'h0000_0000);
        csr_write(CSR_MUTRIG_FORMAT, 32'h0000_0020);
        csr_write(CSR_RATES,         32'h0000_0800);
        csr_write(CSR_CLUSTER_FIX,   32'h0000_4000);
        csr_write(CSR_PRNG_SEED,     32'hDEAD_BEEF);
    endtask

    task automatic start_run();
        send_ctrl(CTRL_RUN_PREPARE);
        repeat (5) @(posedge clk);
        send_ctrl(CTRL_SYNC);
        repeat (5) @(posedge clk);
        send_ctrl(CTRL_RUNNING);
    endtask

    always @(posedge clk) begin
        if (rst) begin
            clear_counts();
        end else begin
            if (tx_valid) begin
                tx_valid_count++;
                if (first_tx_time == 0) first_tx_time = $time;
            end
            if (emu_type0_valid) begin
                emu_type0_count++;
                if (first_type0_time == 0) first_type0_time = $time;
            end
            if (emu_hit_debug_valid) hit_debug_count++;
        end
    end

    initial begin
        reset_dut();
        configure_lane(32'h0000_0001);
        start_run();
        repeat (30000) @(posedge clk);
        $display("PRE_HSS_HWSTIM_EXACT signal=0x1 format=0x20 cluster_fix=0x4000 tx_valid=%0d type0=%0d hit_debug=%0d first_tx_ps=%0t first_type0_ps=%0t final_tx_data=0x%03h",
                 tx_valid_count, emu_type0_count, hit_debug_count, first_tx_time, first_type0_time, tx_data);

        if (tx_valid_count != 0 || emu_type0_count != 0 || hit_debug_count != 0) begin
            $fatal(1, "PRE_HSS_HWSTIM_FAIL: exact board tuple unexpectedly generated hits");
        end

        reset_dut();
        configure_lane(32'h0000_0000);
        start_run();
        repeat (30000) @(posedge clk);
        $display("PRE_HSS_HWSTIM_CONTROL signal=0x0 format=0x20 cluster_fix=0x4000 tx_valid=%0d type0=%0d hit_debug=%0d first_tx_ps=%0t first_type0_ps=%0t final_tx_data=0x%03h",
                 tx_valid_count, emu_type0_count, hit_debug_count, first_tx_time, first_type0_time, tx_data);

        if (tx_valid_count == 0 || emu_type0_count == 0) begin
            $fatal(1, "PRE_HSS_HWSTIM_FAIL: control tuple did not generate byte-stream hits");
        end

        $display("*** PRE_HSS_HWSTIM PASSED: signal=1 reproduces zero tx_valid; signal=0 restores tx_valid ***");
        $finish;
    end
endmodule
