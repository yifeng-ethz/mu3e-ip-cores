`timescale 1ns/1ps

interface phase4_5_fail_mode_if(
    input logic clk
);
    localparam int unsigned NUM_LANES = 8;
    localparam int unsigned NUM_CHANNELS = 32;

    localparam logic [8:0] RC_IDLE        = 9'h001;
    localparam logic [8:0] RC_PREPARING   = 9'h002;
    localparam logic [8:0] RC_SYNCING     = 9'h004;
    localparam logic [8:0] RC_RUNNING     = 9'h008;
    localparam logic [8:0] RC_TERMINATING = 9'h010;
    localparam logic [8:0] RC_RESETTING   = 9'h080;

    localparam logic [3:0] EMU_CSR_CENTRAL       = 4'h7;
    localparam logic [3:0] EMU_CSR_SIGNAL        = 4'h8;
    localparam logic [3:0] EMU_CSR_BACKGROUND    = 4'h9;
    localparam logic [3:0] EMU_CSR_MUTRIG_FORMAT = 4'hA;
    localparam logic [3:0] EMU_CSR_RATES         = 4'hB;
    localparam logic [3:0] EMU_CSR_CLUSTER_FIX   = 4'hC;
    localparam logic [3:0] EMU_CSR_CLUSTER_RAND  = 4'hD;
    localparam logic [3:0] EMU_CSR_PRNG_SEED     = 4'hE;
    localparam logic [3:0] EMU_CSR_TIMEBASE_SEED = 4'hF;

    localparam logic [4:0] ARB_CSR_MODE          = 5'h02;
    localparam logic [4:0] ARB_CSR_WATCHDOG      = 5'h04;
    localparam logic [4:0] ARB_CSR_EGRESS_EMU_LO = 5'h14;

    localparam logic [1:0] ARB_MODE_REAL = 2'd0;
    localparam logic [1:0] ARB_MODE_EMU  = 2'd1;

    logic rst;

    logic [8:0] ctrl_data;
    logic       ctrl_valid;

    logic [3:0]  emu_csr_address;
    logic        emu_csr_read;
    logic        emu_csr_write;
    logic [31:0] emu_csr_writedata;
    logic [31:0] emu_csr_readdata;
    logic        emu_csr_waitrequest;

    logic [NUM_LANES-1:0][4:0]  arb_csr_address;
    logic [NUM_LANES-1:0]       arb_csr_read;
    logic [NUM_LANES-1:0]       arb_csr_write;
    logic [NUM_LANES-1:0][31:0] arb_csr_writedata;
    logic [NUM_LANES-1:0][31:0] arb_csr_readdata;
    logic [NUM_LANES-1:0]       arb_csr_waitrequest;

    logic capture_enable;
    logic clear_counts;
    logic [63:0] emu_tx_count;
    logic [63:0] lane_selected_count [NUM_LANES];
    logic [63:0] lane_payload_hist [NUM_LANES][NUM_CHANNELS];

    logic        dbg_run_generating;
    logic        dbg_run_draining;
    logic [63:0] dbg_emulator_lane_frames;
    logic [63:0] dbg_emulator_lane_hits;
    logic [9:0]  dbg_emulator_l2_level;
    logic [3:0]  dbg_emulator_ticket_level;
    logic [15:0] dbg_ticket_overflow_count;

    task automatic init_bus();
        rst               <= 1'b1;
        ctrl_data         <= RC_IDLE;
        ctrl_valid        <= 1'b0;
        emu_csr_address   <= '0;
        emu_csr_read      <= 1'b0;
        emu_csr_write     <= 1'b0;
        emu_csr_writedata <= '0;
        capture_enable    <= 1'b0;
        clear_counts      <= 1'b0;
        for (int lane = 0; lane < NUM_LANES; lane++) begin
            arb_csr_address[lane]   <= '0;
            arb_csr_read[lane]      <= 1'b0;
            arb_csr_write[lane]     <= 1'b0;
            arb_csr_writedata[lane] <= '0;
        end
    endtask

    task automatic wait_cycles(input int unsigned cycle_count);
        repeat (cycle_count) @(posedge clk);
    endtask

    task automatic pulse_clear_counts();
        @(negedge clk);
        clear_counts <= 1'b1;
        @(negedge clk);
        clear_counts <= 1'b0;
    endtask

    task automatic hard_reset();
        capture_enable <= 1'b0;
        ctrl_valid     <= 1'b0;
        ctrl_data      <= RC_IDLE;
        rst            <= 1'b1;
        wait_cycles(32);
        rst            <= 1'b0;
        wait_cycles(32);
        pulse_clear_counts();
    endtask

    task automatic emu_write32(
        input logic [3:0]  address,
        input logic [31:0] data
    );
        @(negedge clk);
        emu_csr_address   <= address;
        emu_csr_writedata <= data;
        emu_csr_write     <= 1'b1;
        emu_csr_read      <= 1'b0;
        @(negedge clk);
        emu_csr_write     <= 1'b0;
        emu_csr_writedata <= 32'h0000_0000;
    endtask

    task automatic arb_write32(
        input int unsigned lane,
        input logic [4:0]  address,
        input logic [31:0] data
    );
        if (lane >= NUM_LANES) begin
            $fatal(1, "arb_write32 lane %0d out of range", lane);
        end
        @(negedge clk);
        arb_csr_address[lane]   <= address;
        arb_csr_writedata[lane] <= data;
        arb_csr_write[lane]     <= 1'b1;
        arb_csr_read[lane]      <= 1'b0;
        @(negedge clk);
        arb_csr_write[lane]     <= 1'b0;
        arb_csr_writedata[lane] <= 32'h0000_0000;
    endtask

    task automatic arb_read32(
        input  int unsigned lane,
        input  logic [4:0]  address,
        output logic [31:0] data
    );
        if (lane >= NUM_LANES) begin
            $fatal(1, "arb_read32 lane %0d out of range", lane);
        end
        @(negedge clk);
        arb_csr_address[lane] <= address;
        arb_csr_read[lane]    <= 1'b1;
        arb_csr_write[lane]   <= 1'b0;
        @(posedge clk);
        #1ps;
        data = arb_csr_readdata[lane];
        @(negedge clk);
        arb_csr_read[lane] <= 1'b0;
    endtask

    task automatic drive_ctrl_word(input logic [8:0] word);
        @(negedge clk);
        ctrl_data  <= word;
        ctrl_valid <= 1'b1;
        @(negedge clk);
        ctrl_valid <= 1'b0;
    endtask

    task automatic drive_prepare_sync();
        // Host 0x10/0x11/0x12/0x13 are decoded upstream before reaching
        // emulator_mutrig and arb_hit_type0. These are the downstream
        // one-hot states consumed by the source RTL under test.
        drive_ctrl_word(RC_PREPARING);
        wait_cycles(16);
        drive_ctrl_word(RC_SYNCING);
        wait_cycles(16);
    endtask

    task automatic drive_running_terminate_1ms();
        drive_ctrl_word(RC_RUNNING);
        wait_cycles(125000);
        drive_ctrl_word(RC_TERMINATING);
        wait_cycles(2048);
        drive_ctrl_word(RC_IDLE);
        wait_cycles(128);
    endtask

    task automatic drive_run_window_1ms();
        drive_prepare_sync();
        drive_running_terminate_1ms();
    endtask

    task automatic configure_emulator_common(input logic [31:0] mutrig_format);
        emu_write32(EMU_CSR_CENTRAL,       32'h0000_0001);
        emu_write32(EMU_CSR_SIGNAL,        32'h0000_0000);
        emu_write32(EMU_CSR_BACKGROUND,    32'h0000_0000);
        emu_write32(EMU_CSR_MUTRIG_FORMAT, mutrig_format);
        emu_write32(EMU_CSR_RATES,         32'h0000_0800);
        emu_write32(EMU_CSR_CLUSTER_FIX,   32'h0000_4180);
        emu_write32(EMU_CSR_CLUSTER_RAND,  32'h0001_0204);
        emu_write32(EMU_CSR_PRNG_SEED,     32'h45A5_4EED);
        emu_write32(EMU_CSR_TIMEBASE_SEED, 32'h0001_0001);
    endtask

    task automatic configure_all_arb_modes(input int selected_lane);
        logic [31:0] mode_word;

        for (int lane = 0; lane < NUM_LANES; lane++) begin
            mode_word = (selected_lane < 0 || lane == selected_lane) ?
                {30'd0, ARB_MODE_EMU} : {30'd0, ARB_MODE_REAL};
            arb_write32(lane, ARB_CSR_MODE, mode_word);
            arb_write32(lane, ARB_CSR_WATCHDOG, 32'h0000_0000);
        end
        wait_cycles(16);
    endtask
endinterface
