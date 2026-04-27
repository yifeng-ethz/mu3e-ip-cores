// emulator_mutrig.sv
// Top-level MuTRiG 3 ASIC emulator for FPGA
//
// Emulates the digital output of a single MuTRiG 3 ASIC:
//   - PRBS-15 LFSR coarse timestamp (matching real MuTRiG TDC)
//   - Configurable hit generation (Poisson, burst, noise, mixed)
//   - Frame assembly with CRC-16 matching real MuTRiG format
//   - 8b/1k parallel output (bypasses 8b10b + serializer for FPGA-internal use)
//   - Optional charge-injection pulse hook for datapath-aligned burst stimuli
//
// Interfaces:
//   - Avalon-MM slave for configuration (CSR)
//   - Avalon-ST source for 8b/1k data (feeds frame_rcv_ip directly)
//   - Avalon-ST sink for run control timing (from run-control_mgmt)
//   - Conduit input for charge-injection pulses (from mutrig_injector datapath IP)
//
// Author: Yifeng Wang
// Version : 26.1.8
// Date    : 20260418
// Change  : Keep the single-lane wrapper aligned with the compact 8-lane bank
//           while adding a dedicated masked-trigger conduit and per-channel
//           injection mask CSR for frame-marker-aligned latency studies.

module emulator_mutrig
    import emulator_mutrig_pkg::*;
#(
    parameter int         FIFO_DEPTH       = RAW_FIFO_DEPTH,
    parameter int         CSR_ADDR_WIDTH   = 4,
    // Reset value of csr_asic_id. Used when a testbench needs each emulator
    // instance to stamp a unique lane identifier into the downstream hit
    // stream without having to issue an AVMM configuration write.
    parameter logic [3:0] ASIC_ID_DEFAULT  = 4'd0,
    // Optional multi-ASIC cluster-domain defaults. When enabled, neighbouring
    // emulator instances that share the same seed/rate configuration can each
    // emit their local 32-channel slice of one shared global cluster.
    parameter logic       CLUSTER_CROSS_ASIC_DEFAULT   = 1'b0,
    parameter logic [7:0] CLUSTER_CENTER_GLOBAL_DEFAULT = 8'd16,
    parameter logic [3:0] CLUSTER_LANE_INDEX_DEFAULT    = 4'd0,
    parameter logic [3:0] CLUSTER_LANE_COUNT_DEFAULT    = 4'd1
)(
    // Clock and reset
    input  logic        i_clk,
    input  logic        i_rst,

    // Avalon-ST source [tx8b1k] — output to frame_rcv_ip
    output logic [8:0]  aso_tx8b1k_data,     // {is_k, data[7:0]}
    output logic        aso_tx8b1k_valid,
    output logic [3:0]  aso_tx8b1k_channel,  // ASIC ID for downstream
    output logic [2:0]  aso_tx8b1k_error,

    // Avalon-ST sink [ctrl] — run control timing
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    output logic        asi_ctrl_ready,

    // Conduit [inject] — datapath charge-injection pulse
    input  logic        coe_inject_pulse,
    input  logic        coe_inject_masked_pulse,

    // Avalon-MM slave [csr] — configuration registers
    input  logic [CSR_ADDR_WIDTH-1:0] avs_csr_address,
    input  logic        avs_csr_read,
    input  logic        avs_csr_write,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest
);

    function automatic logic [3:0] clamp_asic_id(input logic [3:0] raw_asic_id);
        return {1'b0, raw_asic_id[2:0]};
    endfunction

    // ========================================
    // Run control state decode
    // ========================================
    // Run control bus uses 9-bit one-hot encoding:
    //   bit[0]=IDLE, bit[1]=RUN_PREPARE, bit[2]=SYNC, bit[3]=RUNNING,
    //   bit[4]=TERMINATING, bit[5]=LINK_TEST, bit[6]=SYNC_TEST,
    //   bit[7]=RESET, bit[8]=OUT_OF_DAQ

    logic [8:0] ctrl_state_q;   // last accepted run-control word
    logic       run_generating; // allow new hit commits into the FIFO
    logic       run_draining;   // keep buffered hits draining downstream
    logic       emu_rst;        // session reset on cold reset / RUN_PREPARE / RESET
    logic       frame_rst;      // frame-generator reset outside the active drain window
    logic [1:0] inject_sync;
    logic [1:0] inject_masked_sync;
    logic       inject_pulse_clk;
    logic       inject_masked_pulse_clk;

    // Latch the last accepted one-hot run state. New hit generation is only
    // allowed in RUNNING, but the buffered FIFO contents must survive into
    // TERMINATING so the downstream chain can drain.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            ctrl_state_q <= 9'b0_0000_0001;  // IDLE
        end else if (asi_ctrl_valid) begin
            ctrl_state_q <= asi_ctrl_data;
        end
    end
    assign asi_ctrl_ready = 1'b1;

    // RUNNING allows new hit commits. TERMINATING lets an already-open frame
    // finish draining, but it must not open a fresh header from the idle state.
    // The datapath timestamp epoch must reset on the same SYNC boundary as the
    // downstream MTS processor. RUN_PREPARE can still flush local state via
    // frame_rst, but the dark coarse counter must not start early.
    assign run_generating = ctrl_state_q[3];
    assign run_draining   = ctrl_state_q[3] | ctrl_state_q[4];
    assign emu_rst        = i_rst | (asi_ctrl_valid && (asi_ctrl_data[2] | asi_ctrl_data[7]));
    assign frame_rst      = emu_rst | ~run_draining;

    // The injector can source pulses from either the datapath clock domain or
    // the 50 MHz async mode, so resynchronize before consuming the edge.
    always_ff @(posedge i_clk) begin
        if (emu_rst)
            inject_sync <= 2'b00;
        else
            inject_sync <= {inject_sync[0], coe_inject_pulse};
    end

    assign inject_pulse_clk = inject_sync[0] & ~inject_sync[1];

    always_ff @(posedge i_clk) begin
        if (emu_rst)
            inject_masked_sync <= 2'b00;
        else
            inject_masked_sync <= {inject_masked_sync[0], coe_inject_masked_pulse};
    end

    assign inject_masked_pulse_clk = inject_masked_sync[0] & ~inject_masked_sync[1];

    // ========================================
    // CSR registers
    // ========================================
    // Addr 0: Control
    //   [0]     enable (1=enabled)
    //   [2:1]   hit_mode
    //             00 = legacy folded Poisson
    //             01 = burst / injected cluster replay
    //             10 = folded per-channel IID Poisson
    //             11 = folded per-channel periodic
    //   [3]     short_mode (1=short, 0=long)
    //   [7:4]   reserved
    // Addr 1: Hit rate (16-bit, 8.8 fixed-point)
    //   [15:0]  hit_rate
    //   [31:16] noise_rate
    // Addr 2: Burst config
    //   [4:0]   burst_size
    //   [12:8]  burst_center_local
    //   [13]    cluster_cross_asic
    //   [21:14] cluster_center_global
    //   [25:22] cluster_lane_index
    //   [29:26] cluster_lane_count
    // Addr 3: PRNG seed
    //   [31:0]  seed
    // Addr 4: TX mode / ASIC ID
    //   [2:0]   tx_mode
    //   [3]     gen_idle
    //   [7:4]   asic_id (channel tag for downstream)
    // Addr 5: Status (read-only)
    //   [15:0]  frame_count
    //   [25:16] last_event_count
    // Addr 6: Inject mask
    //   [31:0] inject_channel_mask (1=channel participates in masked trigger)

    logic        csr_enable;
    logic [1:0]  csr_hit_mode;
    logic        csr_short_mode;
    logic [15:0] csr_hit_rate;
    logic [15:0] csr_noise_rate;
    logic [4:0]  csr_burst_size;
    logic [4:0]  csr_burst_center;
    logic        csr_cluster_cross_asic;
    logic [7:0]  csr_cluster_center_global;
    logic [3:0]  csr_cluster_lane_index;
    logic [3:0]  csr_cluster_lane_count;
    logic [31:0] csr_prng_seed;
    logic [2:0]  csr_tx_mode;
    logic        csr_gen_idle;
    logic [3:0]  csr_asic_id;
    logic [31:0] csr_inject_channel_mask;
    logic [31:0] csr_readdata_comb;

    // Status
    logic [15:0] status_frame_count;
    logic [9:0]  status_event_count;

    always_comb begin
        unique case (avs_csr_address)
            'd0: csr_readdata_comb = {28'b0, csr_short_mode, csr_hit_mode, csr_enable};
            'd1: csr_readdata_comb = {csr_noise_rate, csr_hit_rate};
            'd2: csr_readdata_comb = {2'b0, csr_cluster_lane_count, csr_cluster_lane_index, csr_cluster_center_global, csr_cluster_cross_asic, csr_burst_center, 3'b0, csr_burst_size};
            'd3: csr_readdata_comb = csr_prng_seed;
            'd4: csr_readdata_comb = {24'b0, csr_asic_id, csr_gen_idle, csr_tx_mode};
            'd5: csr_readdata_comb = {6'b0, status_event_count, status_frame_count};
            'd6: csr_readdata_comb = csr_inject_channel_mask;
            default: csr_readdata_comb = '0;
        endcase
    end

    assign avs_csr_readdata    = csr_readdata_comb;
    assign avs_csr_waitrequest = 1'b0;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            csr_enable       <= 1'b1;
            csr_hit_mode     <= 2'b00;    // Poisson
            csr_short_mode   <= 1'b0;     // long mode
            csr_hit_rate     <= 16'h0800; // ~8 hits/frame
            csr_noise_rate   <= 16'h0100; // ~1 noise/frame
            csr_burst_size           <= 5'd4;
            csr_burst_center         <= 5'd16;
            csr_cluster_cross_asic   <= CLUSTER_CROSS_ASIC_DEFAULT;
            csr_cluster_center_global <= CLUSTER_CENTER_GLOBAL_DEFAULT;
            csr_cluster_lane_index    <= CLUSTER_LANE_INDEX_DEFAULT;
            csr_cluster_lane_count    <= CLUSTER_LANE_COUNT_DEFAULT;
            csr_prng_seed            <= 32'hDEAD_BEEF;
            csr_tx_mode      <= 3'b000;   // long mode
            csr_gen_idle     <= 1'b1;
            csr_asic_id      <= clamp_asic_id(ASIC_ID_DEFAULT);
            csr_inject_channel_mask <= 32'hFFFF_FFFF;
        end else begin
            if (avs_csr_write) begin
                case (avs_csr_address)
                    'd0: begin
                        csr_enable     <= avs_csr_writedata[0];
                        csr_hit_mode   <= avs_csr_writedata[2:1];
                        csr_short_mode <= avs_csr_writedata[3];
                    end
                    'd1: begin
                        csr_hit_rate   <= avs_csr_writedata[15:0];
                        csr_noise_rate <= avs_csr_writedata[31:16];
                    end
                    'd2: begin
                        csr_burst_size           <= avs_csr_writedata[4:0];
                        csr_burst_center         <= avs_csr_writedata[12:8];
                        csr_cluster_cross_asic   <= avs_csr_writedata[13];
                        csr_cluster_center_global <= avs_csr_writedata[21:14];
                        csr_cluster_lane_index    <= avs_csr_writedata[25:22];
                        csr_cluster_lane_count    <= avs_csr_writedata[29:26];
                    end
                    'd3: begin
                        csr_prng_seed <= avs_csr_writedata;
                    end
                    'd4: begin
                        csr_tx_mode  <= avs_csr_writedata[2:0];
                        csr_gen_idle <= avs_csr_writedata[3];
                        csr_asic_id  <= clamp_asic_id(avs_csr_writedata[7:4]);
                    end
                    'd6: begin
                        csr_inject_channel_mask <= avs_csr_writedata;
                    end
                    default: ;
                endcase
            end
        end
    end

    // ========================================
    // PRBS-15 coarse counters
    // ========================================
    // Two independent LFSRs: one for T (time), one for E (energy)
    // They free-run between run-control resets so the dark timestamp epoch
    // stays aligned with the downstream MTS processor.
    logic [14:0] tcc_lfsr, ecc_lfsr;
    logic [14:0] tcc_lfsr_commit, ecc_lfsr_commit;
    logic        lfsr_en;
    logic [10:0] frame_interval_cnt;
    logic [10:0] frame_interval_max;
    logic        frame_start_req;
`ifndef SYNTHESIS
    logic [47:0] true_gts_8n;
`endif
    assign lfsr_en = ~emu_rst;
    assign frame_interval_max = csr_short_mode ? 11'(FRAME_INTERVAL_SHORT) : 11'(FRAME_INTERVAL_LONG);

    always_ff @(posedge i_clk) begin
        if (frame_rst) begin
            frame_interval_cnt <= frame_interval_max - 11'd1;
            frame_start_req    <= 1'b0;
        end else begin
            if (frame_interval_cnt == '0) begin
                frame_interval_cnt <= frame_interval_max - 11'd1;
                frame_start_req    <= 1'b1;
            end else begin
                frame_interval_cnt <= frame_interval_cnt - 11'd1;
                frame_start_req    <= 1'b0;
            end
        end
    end

    prbs15_lfsr #(
        .STEP_COUNT (MUTRIG_COARSE_STEPS_PER_CYCLE)
    ) u_tcc_lfsr (
        .clk      (i_clk),
        .rst      (emu_rst),
        .en       (lfsr_en),
        .lfsr_out (tcc_lfsr)
    );

    // E coarse counter: offset by half period from T
    // (In real MuTRiG, ECC is from a separate TDC measurement triggered by energy discriminator)
    // For emulation: use same LFSR with different phase
    prbs15_lfsr #(
        .STEP_COUNT (MUTRIG_COARSE_STEPS_PER_CYCLE)
    ) u_ecc_lfsr (
        .clk      (i_clk),
        .rst      (emu_rst),
        .en       (lfsr_en),
        .lfsr_out (ecc_lfsr)
    );

    // The MuTRiG timestamps must reflect the coarse counter value of the
    // cycle that commits the hit, not the pre-edge register image.
    assign tcc_lfsr_commit = lfsr_en ? prbs15_step_n(tcc_lfsr, MUTRIG_COARSE_STEPS_PER_CYCLE) : tcc_lfsr;
    assign ecc_lfsr_commit = lfsr_en ? prbs15_step_n(ecc_lfsr, MUTRIG_COARSE_STEPS_PER_CYCLE) : ecc_lfsr;

`ifndef SYNTHESIS
    always_ff @(posedge i_clk) begin
        if (emu_rst)
            true_gts_8n <= '0;
        else if (lfsr_en)
            true_gts_8n <= true_gts_8n + 48'd1;
    end
`endif

    // ========================================
    // Hit generator
    // ========================================
    logic        fifo_rd_en;
    logic [47:0] fifo_data;
    logic [9:0]  event_count;
    logic        fifo_empty, fifo_full, fifo_almost_full;
    logic        frame_start;

    hit_generator #(
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_hit_gen (
        .clk             (i_clk),
        .rst             (emu_rst),
        .enable          (run_generating & csr_enable),
        .cfg_hit_mode    (csr_hit_mode),
        .cfg_hit_rate    (csr_hit_rate),
        .cfg_burst_size         (csr_burst_size),
        .cfg_burst_center       (csr_burst_center),
        .cfg_cluster_cross_asic (csr_cluster_cross_asic),
        .cfg_cluster_center_global(csr_cluster_center_global),
        .cfg_cluster_lane_index (csr_cluster_lane_index),
        .cfg_cluster_lane_count (csr_cluster_lane_count),
        .cfg_noise_rate         (csr_noise_rate),
        .cfg_prng_seed   (csr_prng_seed),
        .cfg_short_mode  (csr_short_mode),
        .inject_pulse    (inject_pulse_clk),
        .inject_masked_pulse(inject_masked_pulse_clk),
        .cfg_inject_channel_mask(csr_inject_channel_mask),
        .sim_offer_valid (1'b0),
        .sim_offer_word  ('0),
        .sim_offer_ready (),
        .tcc_lfsr        (tcc_lfsr_commit),
        .ecc_lfsr        (ecc_lfsr_commit),
        .fifo_rd_en      (fifo_rd_en),
        .fifo_data       (fifo_data),
        .event_count     (event_count),
        .fifo_empty      (fifo_empty),
        .fifo_full       (fifo_full),
        .fifo_almost_full(fifo_almost_full)
    );

    // ========================================
    // Frame assembler
    // ========================================
    logic [8:0] tx_data_int;
    logic       tx_valid_int;

    frame_assembler u_frame_asm (
        .clk            (i_clk),
        .rst            (frame_rst),
        .frame_start_req(frame_start_req & run_generating & csr_enable),
        .cfg_short_mode (csr_short_mode),
        .cfg_gen_idle   (csr_gen_idle),
        .cfg_tx_mode    (csr_tx_mode),
        .fifo_rd_en     (fifo_rd_en),
        .fifo_data      (fifo_data),
        .event_count    (event_count),
        .fifo_empty     (fifo_empty),
        .fifo_almost_full(fifo_almost_full),
        .frame_start    (frame_start),
        .tx_data        (tx_data_int),
        .tx_valid       (tx_valid_int)
    );

    // ========================================
    // Output assignment
    // ========================================
    // When not enabled or outside the active run/drain window, output idle comma
    always_comb begin
        if (run_draining && csr_enable) begin
            aso_tx8b1k_data  = tx_data_int;
            aso_tx8b1k_valid = tx_valid_int;
        end else begin
            aso_tx8b1k_data  = {1'b1, K28_5};  // idle comma
            aso_tx8b1k_valid = 1'b1;
        end
        aso_tx8b1k_channel = csr_asic_id;
        aso_tx8b1k_error   = 3'b000;
    end

    // Status capture
    always_ff @(posedge i_clk) begin
        if (emu_rst) begin
            status_frame_count <= '0;
            status_event_count <= '0;
        end else if (frame_start) begin
            status_frame_count <= status_frame_count + 16'd1;
            status_event_count <= event_count;
        end
    end

endmodule
